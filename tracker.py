#!/usr/bin/env python3
"""Omaclippy Tracker Daemon for Omarchy / Hyprland.

Streams real-time pointer coordinates, window moves, clicks, AI agent events,
battery status, and user inactivity/sleep states to stdout as JSON lines:
  {"cursor": {"x": 1234, "y": 567}}
  {"window_moved": true, "rect": {"x": 12, "y": 38, "width": 1342, "height": 718}}
  {"click": true, "btn": "left", "x": 1234, "y": 567}
  {"agent_event": "blocked", "agent": "worker-1", "message": "..."}
  {"system_event": "low_battery", "percentage": 12, "message": "..."}
  {"system_event": "charger_connected", "message": "..."}
  {"system_event": "idle_sleep"}
  {"system_event": "user_wake"}

Security Hardening:
- Raw /dev/input device monitoring is DISABLED by default (opt-in via --enable-raw-input).
- When raw input is enabled, keyboard devices are strictly excluded via ioctl capability inspection.
- Executables (herdr) are resolved once from an allowlist of trusted absolute paths and fail closed.
- Bounded process output, bounded sysfs reads, bounded socket buffers, and strict schema validation.
"""

import argparse
import errno
import fcntl
import glob
import json
import os
import select
import signal
import socket
import struct
import subprocess
import sys
import threading
import time

# --- Constants & Evdev Definitions ---
EV_KEY = 0x01
EV_REL = 0x02
EV_ABS = 0x03

BTN_LEFT = 0x110
BTN_RIGHT = 0x111
BTN_MIDDLE = 0x112
BTN_SIDE = 0x113
BTN_EXTRA = 0x114
BTN_TOUCH = 0x14A
BTN_TOOL_FINGER = 0x145
BTN_TOOL_DOUBLETAP = 0x14D
BTN_TOOL_TRIPLETAP = 0x14F

ABS_X = 0x00
ABS_Y = 0x01
ABS_MT_POSITION_X = 0x35
ABS_MT_POSITION_Y = 0x36

# Common keyboard keys used to detect and exclude keyboard devices
# (KEY_ESC=1, KEY_1=2, KEY_Q=16, KEY_ENTER=28, KEY_A=30, KEY_SPACE=57, KEY_Z=44)
KEYBOARD_PROBE_KEYS = [1, 2, 16, 28, 30, 44, 57]

# struct input_event
FMT = "llHHi" if struct.calcsize("i") == 4 else "llHHI"
SIZE = struct.calcsize(FMT)

BUTTON_NAMES = {
    BTN_LEFT: "left",
    BTN_RIGHT: "right",
    BTN_MIDDLE: "middle",
    BTN_SIDE: "side",
    BTN_EXTRA: "extra",
}

VALID_AGENT_STATUSES = {"idle", "working", "blocked", "done", "unknown"}
MAX_HERDR_BYTES = 65536
MAX_AGENTS_CARDINALITY = 50
MAX_SOCKET_BUFFER_BYTES = 16384

TRUSTED_DIRS = ("/usr/bin", "/usr/local/bin", "/usr/share/omarchy/bin", "/bin")

running = True
stdout_lock = threading.Lock()
last_activity_time = time.monotonic()
is_user_asleep = False


def resolve_trusted_executable(candidates):
    """Resolves an executable from a strict allowlist of paths and fails closed."""
    for cand in candidates:
        if not cand or not os.path.isabs(cand):
            continue
        try:
            real = os.path.realpath(cand)
            if any(real.startswith(d + "/") or real == d for d in TRUSTED_DIRS):
                if os.path.isfile(real) and os.access(real, os.X_OK):
                    return real
        except (OSError, ValueError):
            continue
    return None


HERDR_BIN = resolve_trusted_executable(["/usr/bin/herdr", "/usr/local/bin/herdr"])


def _signal_handler(_sig, _frame):
    global running
    running = False
    sys.exit(0)


signal.signal(signal.SIGINT, _signal_handler)
signal.signal(signal.SIGTERM, _signal_handler)
signal.signal(signal.SIGHUP, _signal_handler)


def sanitize_str(val, max_len=200):
    if val is None:
        return ""
    val = str(val).strip()
    return val[:max_len]


def emit(data):
    with stdout_lock:
        try:
            sys.stdout.write(json.dumps(data) + "\n")
            sys.stdout.flush()
        except (BrokenPipeError, IOError):
            sys.exit(0)


def record_activity():
    global last_activity_time, is_user_asleep
    last_activity_time = time.monotonic()
    if is_user_asleep:
        is_user_asleep = False
        emit({"system_event": "user_wake", "message": "Estou de volta!"})


def system_hardware_watcher():
    """Background thread monitoring Herdr agents, battery, and sleep/wake cycles."""
    global is_user_asleep
    known_herdr_states = {}
    last_ac_state = None
    low_battery_warned = False
    time.sleep(1.0)

    while running:
        # 1. Herdr Agent Watcher (Executed only via validated absolute path)
        if HERDR_BIN is not None:
            try:
                proc = subprocess.Popen(
                    [HERDR_BIN, "agent", "list"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                )
                try:
                    stdout_data, _ = proc.communicate(timeout=3.0)
                    if stdout_data and len(stdout_data) <= MAX_HERDR_BYTES:
                        payload = json.loads(stdout_data.strip())
                        if isinstance(payload, dict):
                            result_obj = payload.get("result", {})
                            if isinstance(result_obj, dict):
                                agents = result_obj.get("agents", [])
                                if isinstance(agents, list):
                                    for a in agents[:MAX_AGENTS_CARDINALITY]:
                                        if not isinstance(a, dict):
                                            continue
                                        raw_key = a.get("pane_id") or a.get("name") or "Agent"
                                        key = sanitize_str(raw_key, max_len=64)
                                        raw_name = a.get("name") or a.get("agent") or a.get("pane_id") or "Agent"
                                        name = sanitize_str(raw_name, max_len=64)
                                        raw_status = a.get("agent_status", "unknown")
                                        status = raw_status if raw_status in VALID_AGENT_STATUSES else "unknown"
                                        prev_status = known_herdr_states.get(key)

                                        if prev_status is not None and prev_status != status:
                                            if status == "blocked":
                                                emit({
                                                    "agent_event": "blocked",
                                                    "agent": name,
                                                    "message": f"⚠️ Agente '{name}' está bloqueado e aguarda sua resposta!"[:200]
                                                })
                                            elif status == "done":
                                                emit({
                                                    "agent_event": "done",
                                                    "agent": name,
                                                    "message": f"🎉 Agente '{name}' concluiu sua tarefa com sucesso!"[:200]
                                                })
                                            elif status == "working" and prev_status in ("idle", "unknown", "done", "blocked"):
                                                emit({
                                                    "agent_event": "working",
                                                    "agent": name,
                                                    "message": f"Agente '{name}' começou a trabalhar..."[:200]
                                                })

                                        known_herdr_states[key] = status
                except (subprocess.TimeoutExpired, json.JSONDecodeError, Exception):
                    proc.kill()
            except Exception:
                pass

        # 2. Battery & AC Power Monitor (Bounded sysfs file reads)
        try:
            ac_online = None
            for ac_path in glob.glob("/sys/class/power_supply/AC*/online"):
                try:
                    with open(ac_path, "r") as f:
                        raw = f.read(64).strip()
                        if raw.isdigit():
                            ac_online = int(raw)
                            break
                except Exception:
                    pass

            if ac_online is not None:
                if last_ac_state is not None and last_ac_state == 0 and ac_online == 1:
                    low_battery_warned = False
                    emit({"system_event": "charger_connected", "message": "⚡ Carregador conectado!"})
                last_ac_state = ac_online

            # Check Battery Level & Discharge
            for bat_path in glob.glob("/sys/class/power_supply/BAT*/capacity"):
                try:
                    with open(bat_path, "r") as f:
                        raw_cap = f.read(64).strip()
                        if not raw_cap.isdigit():
                            continue
                        cap = max(0, min(100, int(raw_cap)))

                    status_path = bat_path.replace("capacity", "status")
                    stat = "Discharging"
                    if os.path.exists(status_path):
                        with open(status_path, "r") as f:
                            stat = f.read(64).strip()

                    if cap <= 15 and stat == "Discharging":
                        if not low_battery_warned:
                            low_battery_warned = True
                            emit({
                                "system_event": "low_battery",
                                "percentage": cap,
                                "message": f"⚠️ Bateria fraca ({cap}%)! Conecte o carregador."
                            })
                    elif cap > 20:
                        low_battery_warned = False
                    break
                except Exception:
                    pass
        except Exception:
            pass

        # 3. User Inactivity / Sleep Cycle (5 minutes = 300s)
        idle_duration = time.monotonic() - last_activity_time
        if idle_duration > 300 and not is_user_asleep:
            is_user_asleep = True
            emit({"system_event": "idle_sleep", "message": "Zzz..."})

        time.sleep(2.5)


def get_hyprland_socket_paths():
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    cmd_sock = f"{runtime}/hypr/{sig}/.socket.sock" if sig else None
    event_sock = f"{runtime}/hypr/{sig}/.socket2.sock" if sig else None

    if not cmd_sock or not os.path.exists(cmd_sock):
        matches = glob.glob(f"{runtime}/hypr/*/.socket.sock")
        if matches:
            cmd_sock = matches[0]
            event_sock = cmd_sock.replace(".socket.sock", ".socket2.sock")

    return cmd_sock, event_sock


def query_cursorpos(sock_path):
    if not sock_path or not os.path.exists(sock_path):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.settimeout(0.04)
            s.connect(sock_path)
            s.sendall(b"cursorpos")
            data = s.recv(128).decode("utf-8", errors="ignore").strip()
            if "," in data:
                parts = data.split(",")
                px = int(parts[0].strip())
                py = int(parts[1].strip())
                if -10000 <= px <= 50000 and -10000 <= py <= 50000:
                    return px, py
        finally:
            s.close()
    except Exception:
        pass
    return None


def query_activewindow(sock_path):
    if not sock_path or not os.path.exists(sock_path):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            s.settimeout(0.06)
            s.connect(sock_path)
            s.sendall(b"j/activewindow")
            data = b""
            while len(data) < MAX_SOCKET_BUFFER_BYTES:
                chunk = s.recv(4096)
                if not chunk:
                    break
                data += chunk
            win = json.loads(data.decode("utf-8", errors="ignore"))
            if isinstance(win, dict):
                at = win.get("at")
                size = win.get("size")
                if isinstance(at, list) and isinstance(size, list) and len(at) >= 2 and len(size) >= 2:
                    wx, wy = int(at[0]), int(at[1])
                    ww, wh = int(size[0]), int(size[1])
                    if -10000 <= wx <= 50000 and -10000 <= wy <= 50000 and 0 <= ww <= 50000 and 0 <= wh <= 50000:
                        return {"x": wx, "y": wy, "width": ww, "height": wh}
        finally:
            s.close()
    except Exception:
        pass
    return None


def _test_bit(bit, byte_array):
    return bool(byte_array[bit // 8] & (1 << (bit % 8)))


def open_pointer_devices():
    """Narrowly scopes device opening to pointer/mouse/touchpad devices ONLY.
    
    Excludes any device that emits standard keyboard keys to prevent unauthorized
    keystroke monitoring.
    """
    devices = {}
    for path in glob.glob("/dev/input/event*"):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            try:
                ev_mask = bytearray(8)
                fcntl.ioctl(fd, 0x80084520, ev_mask)  # EVIOCGBIT(0, 8)
                has_key = bool(ev_mask[0] & (1 << EV_KEY))
                has_rel = bool(ev_mask[0] & (1 << EV_REL))
                has_abs = bool(ev_mask[0] & (1 << EV_ABS))

                if not (has_rel or has_abs):
                    os.close(fd)
                    continue

                key_mask = bytearray(64)
                if has_key:
                    fcntl.ioctl(fd, 0x80404521, key_mask)  # EVIOCGBIT(EV_KEY, 64)

                # Strict Keyboard Exclusion: if device has standard keyboard keys, close it immediately
                if any(_test_bit(k, key_mask) for k in KEYBOARD_PROBE_KEYS):
                    os.close(fd)
                    continue

                # Must have pointer buttons or touch capability
                has_mouse_btn = (
                    _test_bit(BTN_LEFT, key_mask)
                    or _test_bit(BTN_TOUCH, key_mask)
                    or _test_bit(BTN_TOOL_FINGER, key_mask)
                )

                if has_mouse_btn or (has_rel and not has_key):
                    devices[fd] = {
                        "path": path,
                        "touch_start": 0.0,
                        "touch_moved": False,
                        "finger_count": 1,
                    }
                else:
                    os.close(fd)
            except Exception:
                os.close(fd)
        except (PermissionError, OSError):
            continue
    return devices


def main():
    parser = argparse.ArgumentParser(description="Omaclippy Tracker Daemon")
    parser.add_argument(
        "--enable-raw-input",
        action="store_true",
        default=False,
        help="Explicit opt-in to monitor hardware pointer click devices (/dev/input). Keyboards are never opened."
    )
    args, _ = parser.parse_known_args()

    # Start background watcher
    watcher_thread = threading.Thread(target=system_hardware_watcher, daemon=True)
    watcher_thread.start()

    cmd_sock, event_sock = get_hyprland_socket_paths()
    
    # Open pointer devices only upon informed opt-in
    devices = open_pointer_devices() if args.enable_raw_input else {}

    last_x, last_y = -9999, -9999
    last_win = None
    idle_count = 0

    s_event = None
    event_buf = ""
    if event_sock and os.path.exists(event_sock):
        try:
            s_event = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s_event.connect(event_sock)
            s_event.setblocking(False)
        except Exception:
            s_event = None

    pos = query_cursorpos(cmd_sock)
    if pos:
        last_x, last_y = pos
        emit({"cursor": {"x": last_x, "y": last_y}})

    init_win = query_activewindow(cmd_sock)
    if init_win:
        last_win = init_win
        emit({"window_moved": True, "rect": init_win})

    last_win_poll = time.monotonic()

    while running:
        r_list = list(devices.keys())
        if s_event:
            r_list.append(s_event)

        if r_list:
            try:
                r_fds, _, _ = select.select(r_list, [], [], 0.0)
                for fd in r_fds:
                    if fd == s_event:
                        try:
                            chunk = s_event.recv(4096).decode("utf-8", errors="ignore")
                            if not chunk:
                                s_event.close()
                                s_event = None
                                continue
                            event_buf += chunk
                            if len(event_buf) > MAX_SOCKET_BUFFER_BYTES:
                                event_buf = event_buf[-4096:]
                            lines = event_buf.split("\n")
                            event_buf = lines[-1]
                            window_event = False
                            for line in lines[:-1]:
                                if line.startswith(("movewindow", "activewindow", "openwindow", "closewindow")):
                                    window_event = True
                                    break
                            if window_event:
                                record_activity()
                                win = query_activewindow(cmd_sock)
                                if win and win != last_win:
                                    last_win = win
                                    emit({"window_moved": True, "rect": win})
                        except Exception:
                            pass
                        continue

                    dev = devices.get(fd)
                    if not dev:
                        continue
                    while True:
                        try:
                            raw = os.read(fd, SIZE * 16)
                            if not raw or len(raw) < SIZE:
                                break
                            for offset in range(0, len(raw) - SIZE + 1, SIZE):
                                chunk = raw[offset : offset + SIZE]
                                _, _, ev_type, ev_code, ev_value = struct.unpack(FMT, chunk)

                                if ev_type == EV_KEY:
                                    record_activity()
                                    if ev_code in BUTTON_NAMES:
                                        btn_name = BUTTON_NAMES[ev_code]
                                        if ev_value == 1:
                                            emit({"click": True, "btn": btn_name, "x": last_x, "y": last_y})
                                    elif ev_code == BTN_TOOL_FINGER:
                                        dev["finger_count"] = 1
                                    elif ev_code == BTN_TOOL_DOUBLETAP:
                                        dev["finger_count"] = 2
                                    elif ev_code == BTN_TOOL_TRIPLETAP:
                                        dev["finger_count"] = 3
                                    elif ev_code == BTN_TOUCH:
                                        if ev_value == 1:
                                            dev["touch_start"] = time.monotonic()
                                            dev["touch_moved"] = False
                                        elif ev_value == 0 and dev["touch_start"] > 0:
                                            duration = time.monotonic() - dev["touch_start"]
                                            dev["touch_start"] = 0.0
                                            if duration < 0.22 and not dev["touch_moved"]:
                                                btn = "left"
                                                if dev["finger_count"] == 2:
                                                    btn = "right"
                                                elif dev["finger_count"] == 3:
                                                    btn = "middle"
                                                emit({"click": True, "btn": btn, "x": last_x, "y": last_y})

                                elif ev_type == EV_ABS:
                                    if ev_code in (ABS_X, ABS_Y, ABS_MT_POSITION_X, ABS_MT_POSITION_Y):
                                        if dev["touch_start"] > 0:
                                            dev["touch_moved"] = True
                        except (BlockingIOError, InterruptedError):
                            break
                        except OSError as e:
                            if e.errno in (errno.ENODEV, errno.EBADF):
                                try:
                                    os.close(fd)
                                except Exception:
                                    pass
                                devices.pop(fd, None)
                            break
            except Exception:
                pass

        pos = query_cursorpos(cmd_sock)
        if pos:
            x, y = pos
            if x != last_x or y != last_y:
                last_x, last_y = x, y
                record_activity()
                emit({"cursor": {"x": x, "y": y}})
                idle_count = 0
                time.sleep(0.012)
            else:
                idle_count += 1
                if idle_count < 10:
                    time.sleep(0.016)
                else:
                    time.sleep(0.040)
        else:
            time.sleep(0.1)
            cmd_sock, event_sock = get_hyprland_socket_paths()

        now = time.monotonic()
        if now - last_win_poll > 0.6:
            last_win_poll = now
            win = query_activewindow(cmd_sock)
            if win and win != last_win:
                last_win = win
                record_activity()
                emit({"window_moved": True, "rect": win})


if __name__ == "__main__":
    main()
