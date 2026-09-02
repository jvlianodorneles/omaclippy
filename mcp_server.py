#!/usr/bin/env python3
"""
Omaclippy MCP Server
Exposes Clippy desktop companion actions (animations, speech balloons, status)
to AI models (Google Antigravity, Claude Code, Claude Desktop, etc.) via the
Model Context Protocol (JSON-RPC 2.0 stdio).

Security Hardening:
- Resolves omarchy-shell from a validated allowlist of trusted absolute paths and fails closed.
- Enforces strict byte/line limits on stdin (rejects unbounded payloads before JSON parsing).
- Clamps parameter strings, duration timers, and command arguments to finite safe bounds.
"""

import sys
import json
import os
import subprocess

SERVER_NAME = "omaclippy"
SERVER_VERSION = "1.0.0"

MAX_STDIN_LINE_BYTES = 65536
MAX_MESSAGE_CHARS = 500
MAX_OUTPUT_BYTES = 16384

TRUSTED_DIRS = ("/usr/bin", "/usr/local/bin", "/usr/share/omarchy/bin", "/bin")


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


OMARCHY_SHELL_BIN = resolve_trusted_executable([
    "/usr/share/omarchy/bin/omarchy-shell",
    "/usr/bin/omarchy-shell",
    "/usr/local/bin/omarchy-shell"
])

TOOLS = [
    {
        "name": "clippy_react",
        "description": "Trigger an animation and optional speech balloon on the desktop Clippy companion to reflect the AI agent's current thought, action, or status.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "animation": {
                    "type": "string",
                    "description": "Animation name (e.g. 'Thinking', 'Writing', 'GetTechy', 'GetWizardy', 'GetArtsy', 'Congratulate', 'Alert', 'Wave', 'Explain', 'Searching', 'Processing', 'IdleSnooze', 'RestPose').",
                    "default": "Explain"
                },
                "message": {
                    "type": "string",
                    "description": "Optional message text to display inside the retro yellow speech balloon above/below Clippy."
                },
                "duration_ms": {
                    "type": "integer",
                    "description": "Optional speech balloon display duration in milliseconds (bounded between 500 and 30000ms).",
                    "default": 5000
                }
            },
            "required": ["animation"]
        }
    },
    {
        "name": "clippy_speak",
        "description": "Display a message in Clippy's yellow retro speech balloon with typewriter effect on the user's desktop.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {
                    "type": "string",
                    "description": "The text message to display in the speech balloon."
                },
                "duration_ms": {
                    "type": "integer",
                    "description": "Display duration in milliseconds (bounded between 500 and 30000ms).",
                    "default": 5000
                }
            },
            "required": ["message"]
        }
    },
    {
        "name": "clippy_animate",
        "description": "Play a specific authentic Microsoft Clippy animation on screen with classic sound effects.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "animation": {
                    "type": "string",
                    "description": "Animation name to play (e.g. Wave, Thinking, Explain, GetWizardy, GetArtsy, GetTechy, Writing, Print, Save, SendMail, Congratulate, Alert, Searching, Processing, IdleSnooze)."
                }
            },
            "required": ["animation"]
        }
    },
    {
        "name": "clippy_status",
        "description": "Get current status, screen coordinates, mode, and visibility of the desktop Clippy companion.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    }
]


def run_omarchy_cmd(*args):
    """Executes a command via trusted omarchy-shell binary."""
    if OMARCHY_SHELL_BIN is None:
        return "error: omarchy-shell binary not found in trusted directories"

    cmd = [OMARCHY_SHELL_BIN, "dorneles.omaclippy"] + [str(a)[:500] for a in args]
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout_data, _ = proc.communicate(timeout=5)
        if len(stdout_data) > MAX_OUTPUT_BYTES:
            stdout_data = stdout_data[:MAX_OUTPUT_BYTES]
        return stdout_data.strip()
    except Exception as e:
        return f"error: {e}"


def sanitize_str(val, max_len=MAX_MESSAGE_CHARS):
    if val is None:
        return ""
    val = str(val).strip()
    # Filter out non-printable ASCII/Unicode control characters except newline and tab
    cleaned = "".join(c for c in val if c in ("\n", "\t") or (ord(c) >= 32 and ord(c) != 127))
    return cleaned[:max_len]


def sanitize_anim(val):
    if not val:
        return "Explain"
    val = str(val).strip()
    cleaned = "".join(c for c in val if c.isalnum() or c in ("_", "-"))
    return cleaned[:40] or "Explain"


def clamp_duration(val, default=5000):
    try:
        dur = int(val)
        return max(500, min(30000, dur))
    except (ValueError, TypeError):
        return default


def handle_call_tool(name, arguments):
    if not isinstance(arguments, dict):
        arguments = {}

    if name == "clippy_react":
        anim = sanitize_anim(arguments.get("animation", "Explain"))
        msg = sanitize_str(arguments.get("message"))
        
        # Atomic react invocation
        run_omarchy_cmd("react", anim, msg)
        if msg:
            return {"content": [{"type": "text", "text": f"Clippy is now playing '{anim}' and saying: \"{msg}\""}]}
        return {"content": [{"type": "text", "text": f"Clippy is now playing '{anim}'"}]}

    elif name == "clippy_speak":
        msg = sanitize_str(arguments.get("message", "Hello!"))
        run_omarchy_cmd("speak", msg)
        return {"content": [{"type": "text", "text": f"Clippy is now speaking: \"{msg}\""}]}

    elif name == "clippy_animate":
        anim = sanitize_anim(arguments.get("animation", "Wave"))
        res = run_omarchy_cmd("play", anim)
        return {"content": [{"type": "text", "text": f"Clippy animation result: {res}"}]}

    elif name == "clippy_status":
        raw = run_omarchy_cmd("status")
        return {"content": [{"type": "text", "text": raw or "{}"}]}

    else:
        return {"isError": True, "content": [{"type": "text", "text": f"Unknown tool: {name}"}]}


def send_response(response):
    payload = json.dumps(response)
    sys.stdout.write(payload + "\n")
    sys.stdout.flush()


def main():
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            if len(line.encode("utf-8")) > MAX_STDIN_LINE_BYTES:
                # Reject line exceeding bounded byte limit before parsing
                continue

            line = line.strip()
            if not line:
                continue

            try:
                req = json.loads(line)
            except Exception:
                continue

            if not isinstance(req, dict):
                continue

            req_id = req.get("id")
            method = req.get("method")
            params = req.get("params", {})
            if not isinstance(params, dict):
                params = {}

            if method == "initialize":
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "serverInfo": {
                            "name": SERVER_NAME,
                            "version": SERVER_VERSION
                        },
                        "capabilities": {
                            "tools": {}
                        }
                    }
                })
            elif method == "notifications/initialized":
                pass
            elif method == "tools/list":
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {
                        "tools": TOOLS
                    }
                })
            elif method == "tools/call":
                tool_name = params.get("name")
                tool_args = params.get("arguments", {})
                res = handle_call_tool(tool_name, tool_args)
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": res
                })
            elif method == "ping":
                send_response({
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "result": {}
                })
            else:
                if req_id is not None:
                    send_response({
                        "jsonrpc": "2.0",
                        "id": req_id,
                        "error": {
                            "code": -32601,
                            "message": f"Method '{method}' not found"
                        }
                    })
        except (KeyboardInterrupt, BrokenPipeError):
            break
        except Exception:
            continue


if __name__ == "__main__":
    main()
