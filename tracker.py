#!/usr/bin/env python3
"""Omaclippy Tracker Daemon for Omarchy / Hyprland.

Streams real-time pointer coordinates, window moves, and clicks from Hyprland IPC
and pointer input devices to stdout as JSON lines:
  {"cursor": {"x": 1234, "y": 567}}
  {"window_moved": true, "rect": {"x": 12, "y": 38, "width": 1342, "height": 718}}
  {"click": true, "btn": "left", "x": 1234, "y": 567}
"""

import errno
import fcntl
import glob
import json
import os
import select
import signal
import socket
import struct
import sys
import time

EV_KEY = 0x01
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

running = True


def _signal_handler(_sig, _frame):
    global running
    running = False
    sys.exit(0)


signal.signal(signal.SIGINT, _signal_handler)
signal.signal(signal.SIGTERM, _signal_handler)
signal.signal(signal.SIGHUP, _signal_handler)


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
        s.settimeout(0.04)
        s.connect(sock_path)
        s.sendall(b"cursorpos")
        data = s.recv(128).decode("utf-8", errors="ignore").strip()
        s.close()
        if "," in data:
            parts = data.split(",")
            return int(parts[0].strip()), int(parts[1].strip())
    except Exception:
        pass
    return None


def query_activewindow(sock_path):
    if not sock_path or not os.path.exists(sock_path):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.06)
        s.connect(sock_path)
        s.sendall(b"j/activewindow")
        data = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
        s.close()
        win = json.loads(data.decode("utf-8", errors="ignore"))
        at = win.get("at")
        size = win.get("size")
        if at and size and len(at) >= 2 and len(size) >= 2:
            return {
                "x": at[0],
                "y": at[1],
                "width": size[0],
                "height": size[1],
            }
    except Exception:
        pass
    return None


def open_pointer_devices():
    devices = {}
    for path in glob.glob("/dev/input/event*"):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            ev_mask = bytearray(8)
            try:
                fcntl.ioctl(fd, 0x80084520, ev_mask)  # EVIOCGBIT(0, 8)
                has_key = bool(ev_mask[0] & (1 << EV_KEY))
                has_abs = bool(ev_mask[0] & (1 << EV_ABS))
            except Exception:
                has_key, has_abs = True, True

            if has_key or has_abs:
                devices[fd] = {
                    "path": path,
                    "touch_start": 0.0,
                    "touch_moved": False,
                    "finger_count": 1,
                }
            else:
                os.close(fd)
        except (PermissionError, OSError):
            continue
    return devices


def emit(data):
    try:
        sys.stdout.write(json.dumps(data) + "\n")
        sys.stdout.flush()
    except (BrokenPipeError, IOError):
        sys.exit(0)


def main():
    cmd_sock, event_sock = get_hyprland_socket_paths()
    devices = open_pointer_devices()

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
                            lines = event_buf.split("\n")
                            event_buf = lines[-1]
                            window_event = False
                            for line in lines[:-1]:
                                if line.startswith(("movewindow", "activewindow", "openwindow", "closewindow")):
                                    window_event = True
                                    break
                            if window_event:
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
                emit({"window_moved": True, "rect": win})


if __name__ == "__main__":
    main()
