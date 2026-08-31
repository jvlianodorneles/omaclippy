#!/usr/bin/env python3
"""
Omaclippy MCP Server
Exposes Clippy desktop companion actions (animations, speech balloons, status)
to AI models (Google Antigravity, Claude Code, Claude Desktop, etc.) via the
Model Context Protocol (JSON-RPC 2.0 stdio).
"""

import sys
import json
import subprocess
import shutil

SERVER_NAME = "omaclippy"
SERVER_VERSION = "1.0.0"

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
                    "description": "Optional speech balloon display duration in milliseconds (defaults to auto-calculated based on text length).",
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
                    "description": "Display duration in milliseconds.",
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
    """Executes an omarchy-shell command targeting dorneles.omaclippy."""
    cmd = ["omarchy-shell", "dorneles.omaclippy"] + list(args)
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return res.stdout.strip()
    except Exception as e:
        return f"error: {e}"

def handle_call_tool(name, arguments):
    if name == "clippy_react":
        anim = arguments.get("animation", "Explain")
        msg = arguments.get("message")
        
        # Play animation
        run_omarchy_cmd("play", anim)
        
        # Speak if message provided
        if msg:
            run_omarchy_cmd("speak", msg)
            return {"content": [{"type": "text", "text": f"Clippy is now playing '{anim}' and saying: \"{msg}\""}]}
        return {"content": [{"type": "text", "text": f"Clippy is now playing '{anim}'"}]}

    elif name == "clippy_speak":
        msg = arguments.get("message", "Hello!")
        run_omarchy_cmd("speak", msg)
        return {"content": [{"type": "text", "text": f"Clippy is now speaking: \"{msg}\""}]}

    elif name == "clippy_animate":
        anim = arguments.get("animation", "Wave")
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
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue

        req_id = req.get("id")
        method = req.get("method")
        params = req.get("params", {})

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

if __name__ == "__main__":
    main()
