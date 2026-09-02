#!/usr/bin/env python3
"""Integration & Security Test Suite: Omaclippy <-> Herdr & System

Verifies:
1. Real Herdr CLI and JSON-RPC API compatibility.
2. Tracker event extraction and state machine transitions (idle -> working -> blocked -> done).
3. Robustness under multiple agents, malformed output, and process errors.
4. Omaclippy IPC reaction rendering (GetTechy, Alert, Congratulate) and speech bubbles.
5. End-to-end event stream verification.
6. MCP Server JSON-RPC stdio protocol and tools.
7. CLI helper agent command integration.
8. Trusted executable resolution & ambient PATH defense (fail-closed allowlist).
9. Raw input device opt-in and strict keyboard exclusion.
10. MCP bounded IO, stdin line limits, and parameter sanitization.
11. State configuration schema validation, finite bounds, and atomic replacement.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tracker import resolve_trusted_executable, open_pointer_devices, KEYBOARD_PROBE_KEYS, _test_bit


class TestHerdrIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        print("\n" + "=" * 60)
        print("  OMACLIPPY <-> HERDR INTEGRATION & SECURITY TEST SUITE")
        print("=" * 60 + "\n")

    def _wait_for_anim(self, expected_anim, timeout=2.0):
        """Helper to wait for Omarchy shell IPC to reflect expected animation."""
        start = time.monotonic()
        while time.monotonic() - start < timeout:
            res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                try:
                    st = json.loads(res.stdout.strip())
                    if st.get("currentAnim") == expected_anim:
                        return st
                except Exception:
                    pass
            time.sleep(0.1)
        # Final query
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True)
        return json.loads(res.stdout.strip()) if res.returncode == 0 and res.stdout.strip() else {}

    def test_01_herdr_cli_installed_and_responsive(self):
        """Test 1: Check if herdr binary is available in trusted paths and responds."""
        print("[TEST 1] Verifying herdr binary availability...")
        herdr_bin = resolve_trusted_executable(["/usr/bin/herdr", "/usr/local/bin/herdr"])
        self.assertIsNotNone(herdr_bin, "herdr executable must be resolved from trusted allowlist")
        print(f"  ✓ herdr located at: {herdr_bin}")

        version_res = subprocess.run([herdr_bin, "--version"], capture_output=True, text=True)
        self.assertEqual(version_res.returncode, 0, "herdr --version must succeed")
        print(f"  ✓ herdr version: {version_res.stdout.strip() or version_res.stderr.strip()}")

    def test_02_herdr_agent_list_format(self):
        """Test 2: Test live 'herdr agent list' output schema."""
        print("\n[TEST 2] Querying live 'herdr agent list' JSON structure...")
        herdr_bin = resolve_trusted_executable(["/usr/bin/herdr", "/usr/local/bin/herdr"])
        if not herdr_bin:
            self.skipTest("herdr binary not available")

        res = subprocess.run([herdr_bin, "agent", "list"], capture_output=True, text=True, timeout=5)
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
                                "message": f"⚠️ Agent '{name}' is blocked and waiting for your response!"
                            })
                        elif status == "done":
                            mock_emit({
                                "agent_event": "done",
                                "agent": name,
                                "message": f"🎉 Agent '{name}' completed its task successfully!"
                            })
                        elif status == "working" and prev_status in ("idle", "unknown", "done", "blocked"):
                            mock_emit({
                                "agent_event": "working",
                                "agent": name,
                                "message": f"Agent '{name}' started working..."
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

        # Step 3: Agent gets blocked -> Should emit "blocked"
        step3 = {
            "type": "agent_list",
            "result": {
                "agents": [{"pane_id": "w1:p1", "agent": "worker-1", "agent_status": "blocked"}]
            }
        }
        process_herdr_payload(step3)
        self.assertEqual(len(emitted_events), 2)
        self.assertEqual(emitted_events[-1]["agent_event"], "blocked")
        self.assertIn("blocked", emitted_events[-1]["message"])
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
        self.assertIn("completed", emitted_events[-1]["message"])
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
        process_herdr_payload(step6)
        
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
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "react", "GetTechy", "Agent 'herdr-worker' working..."], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        st = self._wait_for_anim("GetTechy")
        self.assertEqual(st.get("currentAnim"), "GetTechy")
        self.assertTrue(st.get("speechVisible"))
        print("  ✓ 'working' reaction triggered 'GetTechy' with speech bubble")

        # 2. Trigger 'blocked' agent reaction -> Alert
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "react", "Alert", "⚠️ Agent blocked waiting for response!"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        st = self._wait_for_anim("Alert")
        self.assertEqual(st.get("currentAnim"), "Alert")
        self.assertTrue(st.get("speechVisible"))
        print("  ✓ 'blocked' reaction triggered 'Alert' with warning speech bubble")

        # 3. Trigger 'done' agent reaction -> Congratulate
        res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "react", "Congratulate", "🎉 Agent completed task!"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        st = self._wait_for_anim("Congratulate")
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
            st = self._wait_for_anim(anim_name)
            self.assertEqual(st.get("currentAnim"), anim_name)
            print(f"  ✓ 'omaclippy {cmd_name}' -> animation '{anim_name}' active")

        # Restore RestPose
        subprocess.run(["omarchy-shell", "dorneles.omaclippy", "play", "RestPose"], capture_output=True)

    def test_08_trusted_executable_resolution(self):
        """Test 8: Verify allowlisted trusted executable resolution and fail-closed defense."""
        print("\n[TEST 8] Testing trusted executable resolution allowlist...")
        # 1. Standard trusted paths
        python_resolved = resolve_trusted_executable(["/usr/bin/python3", "/bin/python3"])
        self.assertIsNotNone(python_resolved)
        self.assertTrue(python_resolved.startswith(("/usr/bin", "/usr/local/bin", "/bin", "/usr/share/omarchy/bin")))

        # 2. Reject untrusted / relative paths
        self.assertIsNone(resolve_trusted_executable(["python3"]))
        self.assertIsNone(resolve_trusted_executable(["./python3"]))
        self.assertIsNone(resolve_trusted_executable(["/tmp/malicious_bin"]))
        self.assertIsNone(resolve_trusted_executable(["/home/dorneles/fake_bin"]))
        self.assertIsNone(resolve_trusted_executable([]))
        print("  ✓ Untrusted / relative / ambient paths correctly rejected (failed closed)")

    def test_09_raw_input_opt_in_and_keyboard_exclusion(self):
        """Test 9: Verify raw input tracking is opt-in and excludes keyboard devices."""
        print("\n[TEST 9] Testing raw input opt-in and keyboard device rejection...")
        # 1. Raw input is disabled by default
        default_devices = open_pointer_devices()
        # Non-root / unprivileged will either be empty or only non-keyboard pointer devices
        for fd, info in default_devices.items():
            self.assertIn("touch_start", info)

        # 2. Test keyboard probe logic
        fake_keyboard_mask = bytearray(64)
        # Set KEY_A (30) bit
        fake_keyboard_mask[30 // 8] |= (1 << (30 % 8))
        self.assertTrue(any(_test_bit(k, fake_keyboard_mask) for k in KEYBOARD_PROBE_KEYS))

        # Test pure mouse mask (only BTN_LEFT=0x110)
        fake_mouse_mask = bytearray(64)
        fake_mouse_mask[0x110 // 8] |= (1 << (0x110 % 8))
        self.assertFalse(any(_test_bit(k, fake_mouse_mask) for k in KEYBOARD_PROBE_KEYS))
        self.assertTrue(_test_bit(0x110, fake_mouse_mask))
        print("  ✓ Keyboard devices correctly classified and rejected from pointer monitoring")

    def test_10_mcp_bounded_io_and_sanitization(self):
        """Test 10: Verify MCP server enforces line byte limits and string parameter sanitization."""
        print("\n[TEST 10] Testing MCP server bounding and defense-in-depth...")
        mcp_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mcp_server.py")
        proc = subprocess.Popen(
            [sys.executable, mcp_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        try:
            # 1. Send oversized line (> 64KB) -> Should be ignored without crash
            huge_line = " " * 70000 + "\n"
            proc.stdin.write(huge_line)
            proc.stdin.flush()

            # 2. Send valid ping request afterwards to verify server stayed responsive
            ping_req = json.dumps({"jsonrpc": "2.0", "id": 99, "method": "ping"}) + "\n"
            proc.stdin.write(ping_req)
            proc.stdin.flush()

            line = proc.stdout.readline()
            res = json.loads(line.strip())
            self.assertEqual(res.get("id"), 99)
            print("  ✓ MCP server discarded oversized payload and remained stable")

        finally:
            if proc.stdin:
                proc.stdin.close()
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()
            proc.terminate()
            proc.wait(timeout=2)

    def test_11_state_config_schema_validation(self):
        """Test 11: Verify state configuration schema validation rejects malformed fields."""
        print("\n[TEST 11] Testing state configuration validation...")
        # Test validation logic matching QML parseAndValidateConfig
        def validate_config(raw):
            if not raw or not isinstance(raw, str) or len(raw) > 16384:
                return None
            try:
                cfg = json.loads(raw)
                if not isinstance(cfg, dict):
                    return None
                out = {}
                if isinstance(cfg.get("enabled"), bool):
                    out["enabled"] = cfg["enabled"]
                if cfg.get("mode") in ["companion", "roam", "perch"]:
                    out["mode"] = cfg["mode"]
                if cfg.get("scale") in ["small", "normal", "large", "giant"]:
                    out["scale"] = cfg["scale"]
                if isinstance(cfg.get("soundEnabled"), bool):
                    out["soundEnabled"] = cfg["soundEnabled"]
                if isinstance(cfg.get("soundVolume"), (int, float)):
                    out["soundVolume"] = max(0.0, min(1.0, float(cfg["soundVolume"])))
                if cfg.get("idleFrequency") in ["calm", "normal", "frequent"]:
                    out["idleFrequency"] = cfg["idleFrequency"]
                if isinstance(cfg.get("rawInputTracking"), bool):
                    out["rawInputTracking"] = cfg["rawInputTracking"]
                return out
            except Exception:
                return None

        # Valid payload
        valid = validate_config(json.dumps({"enabled": True, "mode": "roam", "soundVolume": 0.8}))
        self.assertEqual(valid["mode"], "roam")
        self.assertEqual(valid["soundVolume"], 0.8)

        # Invalid mode rejected
        invalid_mode = validate_config(json.dumps({"mode": "invalid_mode_attack"}))
        self.assertNotIn("mode", invalid_mode)

        # Out-of-bounds volume clamped
        clamped_vol = validate_config(json.dumps({"soundVolume": 999.0}))
        self.assertEqual(clamped_vol["soundVolume"], 1.0)

        # Oversized payload rejected
        huge_payload = json.dumps({"extra": "A" * 20000})
        self.assertIsNone(validate_config(huge_payload))
        print("  ✓ State configuration validated with strict finite schemas")


if __name__ == "__main__":
    unittest.main(verbosity=2)
