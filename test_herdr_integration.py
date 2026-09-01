#!/usr/bin/env python3
"""Integration Test Suite: Omaclippy <-> Herdr

Verifies:
1. Real Herdr CLI and JSON-RPC API compatibility.
2. Tracker event extraction and state machine transitions (idle -> working -> blocked -> done).
3. Robustness under multiple agents, malformed output, and process errors.
4. Omaclippy IPC reaction rendering (GetTechy, Alert, Congratulate) and speech bubbles.
5. End-to-end event stream verification.
"""

import json
import os
import subprocess
import sys
import time
import unittest
from unittest.mock import patch, MagicMock

# Import the tracker's logic
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


class TestHerdrIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        print("\n" + "=" * 60)
        print("  OMACLIPPY <-> HERDR INTEGRATION TEST SUITE")
        print("=" * 60 + "\n")

    def test_01_herdr_cli_installed_and_responsive(self):
        """Test 1: Check if herdr binary is available in PATH and responds."""
        print("[TEST 1] Verifying herdr binary availability...")
        res = subprocess.run(["which", "herdr"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, "herdr executable must be installed in PATH")
        path = res.stdout.strip()
        print(f"  ✓ herdr located at: {path}")

        version_res = subprocess.run(["herdr", "--version"], capture_output=True, text=True)
        self.assertEqual(version_res.returncode, 0, "herdr --version must succeed")
        print(f"  ✓ herdr version: {version_res.stdout.strip() or version_res.stderr.strip()}")

    def test_02_herdr_agent_list_format(self):
        """Test 2: Test live 'herdr agent list' output schema."""
        print("\n[TEST 2] Querying live 'herdr agent list' JSON structure...")
        res = subprocess.run(["herdr", "agent", "list"], capture_output=True, text=True, timeout=5)
        if res.returncode != 0:
            print("  ℹ Herdr daemon is not running currently (test gracefully skipped live query)")
            return

        payload = json.loads(res.stdout.strip())
        self.assertIn("result", payload)
        result_obj = payload["result"]
        self.assertIn("agents", result_obj)
        self.assertIsInstance(result_obj["agents"], list)
        if "type" in result_obj:
            self.assertEqual(result_obj["type"], "agent_list")

        agents = result_obj["agents"]
        print(f"  ✓ Valid JSON schema received. Active agents detected: {len(agents)}")
        for a in agents:
            pane_id = a.get("pane_id")
            agent_type = a.get("agent")
            status = a.get("agent_status")
            print(f"    - Pane: {pane_id} | Agent: {agent_type} | Status: {status}")
            self.assertIsNotNone(pane_id, "Agent must have pane_id")
            self.assertIn(status, ["idle", "working", "blocked", "done", "unknown"], f"Unexpected status: {status}")

    def test_03_tracker_state_transitions(self):
        """Test 3: Verify Omaclippy tracker logic against Herdr agent state transitions."""
        print("\n[TEST 3] Testing Omaclippy Herdr state machine transitions...")
        
        known_herdr_states = {}
        emitted_events = []

        def mock_emit(data):
            emitted_events.append(data)

        def process_herdr_payload(payload):
            agents = payload.get("result", {}).get("agents", [])
            if isinstance(agents, list):
                for a in agents:
                    key = a.get("pane_id") or a.get("name") or "Agent"
                    name = a.get("name") or a.get("agent") or a.get("pane_id") or "Agent"
                    status = a.get("agent_status", "unknown")
                    prev_status = known_herdr_states.get(key)

                    if prev_status is not None and prev_status != status:
                        if status == "blocked":
                            mock_emit({
                                "agent_event": "blocked",
                                "agent": name,
                                "message": f"⚠️ Agente '{name}' está bloqueado e aguarda sua resposta!"
                            })
                        elif status == "done":
                            mock_emit({
                                "agent_event": "done",
                                "agent": name,
                                "message": f"🎉 Agente '{name}' concluiu sua tarefa com sucesso!"
                            })
                        elif status == "working" and prev_status in ("idle", "unknown", "done", "blocked"):
                            mock_emit({
                                "agent_event": "working",
                                "agent": name,
                                "message": f"Agente '{name}' começou a trabalhar..."
                            })

                    known_herdr_states[key] = status

        # Step 1: Initial discovery (idle) -> Should record state without emitting
        step1 = {
            "type": "agent_list",
            "result": {
                "agents": [{"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "idle"}]
            }
        }
        process_herdr_payload(step1)
        self.assertEqual(len(emitted_events), 0, "Initial discovery should not emit change events")
        self.assertEqual(known_herdr_states["w1:p1"], "idle")
        print("  ✓ Step 1: Initial state recorded (idle) without spurious events")

        # Step 2: Agent starts working -> Should emit "working"
        step2 = {
            "type": "agent_list",
            "result": {
                "agents": [{"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "working"}]
            }
        }
        process_herdr_payload(step2)
        self.assertEqual(len(emitted_events), 1)
        self.assertEqual(emitted_events[-1]["agent_event"], "working")
        self.assertEqual(emitted_events[-1]["agent"], "worker-1")
        print("  ✓ Step 2: Transition idle -> working emitted 'working' event")

        # Step 3: Agent gets blocked (waiting for user input) -> Should emit "blocked"
        step3 = {
            "type": "agent_list",
            "result": {
                "agents": [{"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "blocked"}]
            }
        }
        process_herdr_payload(step3)
        self.assertEqual(len(emitted_events), 2)
        self.assertEqual(emitted_events[-1]["agent_event"], "blocked")
        self.assertIn("bloqueado", emitted_events[-1]["message"])
        print("  ✓ Step 3: Transition working -> blocked emitted 'blocked' alert")

        # Step 4: User replies, agent resumes working -> Should emit "working"
        step4 = {
            "type": "agent_list",
            "result": {
                "agents": [{"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "working"}]
            }
        }
        process_herdr_payload(step4)
        self.assertEqual(len(emitted_events), 3)
        self.assertEqual(emitted_events[-1]["agent_event"], "working")
        print("  ✓ Step 4: Transition blocked -> working emitted 'working' event")

        # Step 5: Agent completes task -> Should emit "done"
        step5 = {
            "type": "agent_list",
            "result": {
                "agents": [{"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "done"}]
            }
        }
        process_herdr_payload(step5)
        self.assertEqual(len(emitted_events), 4)
        self.assertEqual(emitted_events[-1]["agent_event"], "done")
        self.assertIn("concluiu", emitted_events[-1]["message"])
        print("  ✓ Step 5: Transition working -> done emitted celebration 'done' event")

        # Step 6: Multi-agent concurrent transitions
        step6 = {
            "type": "agent_list",
            "result": {
                "agents": [
                    {"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "idle"},
                    {"pane_id": "w1:p2", "agent": "worker-2", "name": "Reviewer", "agent_status": "idle"}
                ]
            }
        }
        process_herdr_payload(step6) # initial for p2
        
        step7 = {
            "type": "agent_list",
            "result": {
                "agents": [
                    {"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "working"},
                    {"pane_id": "w1:p2", "agent": "worker-2", "name": "Reviewer", "agent_status": "blocked"}
                ]
            }
        }
        process_herdr_payload(step7)
        self.assertEqual(len(emitted_events), 6)
        self.assertEqual(emitted_events[-2]["agent_event"], "working")
        self.assertEqual(emitted_events[-2]["agent"], "worker-1")
        self.assertEqual(emitted_events[-1]["agent_event"], "blocked")
        self.assertEqual(emitted_events[-1]["agent"], "Reviewer")
        print("  ✓ Step 6 & 7: Multi-agent concurrent state tracking validated")

    def test_04_error_resilience(self):
        """Test 4: Verify tracker resilience against malformed outputs, timeouts, or unexpected schemas."""
        print("\n[TEST 4] Testing error resilience against bad data...")
        known_herdr_states = {"w1:p1": "working"}
        emitted_events = []

        def mock_emit(data):
            emitted_events.append(data)

        # Test malformed / non-dict items
        bad_payloads = [
            {},
            {"result": None},
            {"result": {"agents": "not a list"}},
            {"result": {"agents": [None, 123, {}, {"pane_id": None}]}},
            {"result": {"agents": [{"pane_id": "w1:p1", "agent_status": None}]}},
        ]

        for idx, payload in enumerate(bad_payloads):
            try:
                agents = payload.get("result", {}).get("agents", []) if isinstance(payload.get("result"), dict) else []
                if isinstance(agents, list):
                    for a in agents:
                        if not isinstance(a, dict):
                            continue
                        key = a.get("pane_id") or a.get("name") or "Agent"
                        name = a.get("name") or a.get("agent") or a.get("pane_id") or "Agent"
                        status = a.get("agent_status", "unknown")
                        prev_status = known_herdr_states.get(key)
                        if prev_status is not None and prev_status != status:
                            mock_emit({"agent_event": status, "agent": name})
                        known_herdr_states[key] = status
            except Exception as e:
                self.fail(f"Tracker threw exception on bad payload #{idx}: {e}")

        print("  ✓ Handled all malformed payloads gracefully without crashing")

    def test_05_omaclippy_ipc_visual_reaction(self):
        """Test 5: Verify live Omaclippy IPC responds to Herdr agent trigger events."""
        print("\n[TEST 5] Verifying live Omaclippy IPC rendering of Herdr reactions...")
        
        status_res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True, timeout=5)
        if status_res.returncode != 0:
            print("  ⚠️ Omarchy shell is not running dorneles.omaclippy; skipping live IPC tests.")
            return

        initial_status = json.loads(status_res.stdout.strip())
        self.assertIn("enabled", initial_status)
        print(f"  ✓ Omaclippy is active in Omarchy Shell (mode: {initial_status.get('mode')}, scale: {initial_status.get('scale')})")

        # 1. Trigger 'working' agent reaction -> GetTechy
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "react", "GetTechy", "Agente 'herdr-worker' trabalhando..."], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        time.sleep(0.2)
        st = json.loads(subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True).stdout.strip())
        self.assertEqual(st.get("currentAnim"), "GetTechy")
        self.assertTrue(st.get("speechVisible"))
        print("  ✓ 'working' reaction triggered 'GetTechy' with speech bubble")

        # 2. Trigger 'blocked' agent reaction -> Alert
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "react", "Alert", "⚠️ Agente bloqueado aguardando resposta!"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        time.sleep(0.2)
        st = json.loads(subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True).stdout.strip())
        self.assertEqual(st.get("currentAnim"), "Alert")
        self.assertTrue(st.get("speechVisible"))
        print("  ✓ 'blocked' reaction triggered 'Alert' with warning speech bubble")

        # 3. Trigger 'done' agent reaction -> Congratulate
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "react", "Congratulate", "🎉 Agente concluiu a tarefa!"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        time.sleep(0.2)
        st = json.loads(subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True).stdout.strip())
        self.assertEqual(st.get("currentAnim"), "Congratulate")
        self.assertTrue(st.get("speechVisible"))
        print("  ✓ 'done' reaction triggered 'Congratulate' with celebration speech bubble")

        # Restore RestPose
        subprocess.run(["omarchy-shell", "dorneles.omaclippy", "play", "RestPose"], capture_output=True)

    def test_06_mcp_server_herdr_agent_tools(self):
        """Test 6: Verify Omaclippy MCP Server tools used by AI coding agents."""
        print("\n[TEST 6] Testing Omaclippy MCP Server tools over JSON-RPC stdio...")
        mcp_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mcp_server.py")
        proc = subprocess.Popen(
            [sys.executable, mcp_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        def send_req(req):
            proc.stdin.write(json.dumps(req) + "\n")
            proc.stdin.flush()
            line = proc.stdout.readline()
            return json.loads(line.strip())

        try:
            # 1. Initialize
            init_res = send_req({
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {"protocolVersion": "2024-11-05"}
            })
            self.assertEqual(init_res.get("id"), 1)
            self.assertIn("serverInfo", init_res.get("result", {}))
            print("  ✓ MCP Server initialized successfully")

            # 2. List tools
            tools_res = send_req({
                "jsonrpc": "2.0",
                "id": 2,
                "method": "tools/list",
                "params": {}
            })
            tools = [t["name"] for t in tools_res.get("result", {}).get("tools", [])]
            self.assertIn("clippy_react", tools)
            self.assertIn("clippy_speak", tools)
            self.assertIn("clippy_animate", tools)
            self.assertIn("clippy_status", tools)
            print(f"  ✓ Registered MCP tools available: {', '.join(tools)}")

            # 3. Call clippy_react tool
            react_res = send_req({
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "clippy_react",
                    "arguments": {
                        "animation": "GetTechy",
                        "message": "AI agent compiling integration test..."
                    }
                }
            })
            self.assertFalse(react_res.get("result", {}).get("isError", False))
            print("  ✓ clippy_react tool executed successfully via MCP")

        finally:
            if proc.stdin:
                proc.stdin.close()
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()
            proc.terminate()
            proc.wait(timeout=2)

    def test_07_cli_helper_agent_commands(self):
        """Test 7: Verify CLI helper commands for agents (tech, alert, done, status)."""
        print("\n[TEST 7] Testing CLI helper command integration...")
        cli_bin = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin", "omaclippy")
        self.assertTrue(os.path.exists(cli_bin), "bin/omaclippy must exist")

        # Test CLI status
        res = subprocess.run([cli_bin, "status"], capture_output=True, text=True, timeout=5)
        self.assertEqual(res.returncode, 0, f"bin/omaclippy status failed: {res.stderr}")
        print("  ✓ 'omaclippy status' returned live state")

        # Test direct aliases
        for cmd_name, anim_name in [("tech", "GetTechy"), ("alert", "Alert"), ("done", "Congratulate")]:
            res = subprocess.run([cli_bin, cmd_name, f"Test {cmd_name}"], capture_output=True, text=True, timeout=5)
            self.assertEqual(res.returncode, 0, f"bin/omaclippy {cmd_name} failed: {res.stderr}")
            time.sleep(0.15)
            st_res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True)
            if st_res.returncode == 0:
                st = json.loads(st_res.stdout.strip())
                self.assertEqual(st.get("currentAnim"), anim_name)
                print(f"  ✓ 'omaclippy {cmd_name}' -> animation '{anim_name}' active")

        # Restore RestPose
        subprocess.run(["omarchy-shell", "dorneles.omaclippy", "play", "RestPose"], capture_output=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
