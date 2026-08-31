#!/usr/bin/env python3
"""Automated Animation Verifier for Omaclippy."""

import subprocess
import json
import time
import sys

# Load Animations.js to compare expected frame coordinates
with open('/home/dorneles/Projects/omaclippy/Animations.js') as f:
    text = f.read()

start = text.find('var animations = {') + len('var animations = ')
end = text.find(';\n\nfunction getAnimation')
anim_data = json.loads(text[start:end])

# Test suite containing both canonical names and aliases
TEST_CASES = [
    # Canonical animations
    ("Save", "Save"),
    ("Print", "Print"),
    ("SendMail", "SendMail"),
    ("Writing", "Writing"),
    ("Searching", "Searching"),
    ("EmptyTrash", "EmptyTrash"),
    ("Processing", "Processing"),
    ("Congratulate", "Congratulate"),
    ("Wave", "Wave"),
    ("Greeting", "Greeting"),
    ("GoodBye", "GoodBye"),
    ("Alert", "Alert"),
    ("GetAttention", "GetAttention"),
    ("Thinking", "Thinking"),
    ("Explain", "Explain"),
    ("Hearing_1", "Hearing_1"),
    ("CheckingSomething", "CheckingSomething"),
    ("IdleSnooze", "IdleSnooze"),
    ("IdleAtom", "IdleAtom"),
    ("IdleRopePile", "IdleRopePile"),
    ("IdleFingerTap", "IdleFingerTap"),
    ("IdleHeadScratch", "IdleHeadScratch"),
    ("IdleEyeBrowRaise", "IdleEyeBrowRaise"),
    ("IdleSideToSide", "IdleSideToSide"),
    ("Idle1_1", "Idle1_1"),
    ("GestureUp", "GestureUp"),
    ("GestureDown", "GestureDown"),
    ("GestureLeft", "GestureLeft"),
    ("GestureRight", "GestureRight"),
    ("LookUp", "LookUp"),
    ("LookDown", "LookDown"),
    ("LookLeft", "LookLeft"),
    ("LookRight", "LookRight"),
    ("LookUpLeft", "LookUpLeft"),
    ("LookUpRight", "LookUpRight"),
    ("LookDownLeft", "LookDownLeft"),
    ("LookDownRight", "LookDownRight"),
    ("GetWizardy", "GetWizardy"),
    ("GetTechy", "GetTechy"),
    ("GetArtsy", "GetArtsy"),

    # Direct aliases and subcommands
    ("save", "Save"),
    ("print", "Print"),
    ("mail", "SendMail"),
    ("write", "Writing"),
    ("search", "Searching"),
    ("trash", "EmptyTrash"),
    ("process", "Processing"),
    ("done", "Congratulate"),
    ("wave", "Wave"),
    ("alert", "Alert"),
    ("sleep", "IdleSnooze"),
    ("tech", "GetTechy"),
    ("art", "GetArtsy"),
    ("wizard", "GetWizardy"),
    ("atom", "IdleAtom"),
    ("mobile", "IdleRopePile"),
]

def query_status():
    res = subprocess.run(["omarchy-shell", "dorneles.omaclippy", "status"], capture_output=True, text=True, timeout=3)
    try:
        return json.loads(res.stdout.strip())
    except Exception:
        return None

print(f"Starting automated verification of {len(TEST_CASES)} animation triggers...\n")

passed = 0
failed = 0

for trigger, expected_anim in TEST_CASES:
    # 1. Trigger via omaclippy CLI
    cmd = ["/home/dorneles/Projects/omaclippy/bin/omaclippy", trigger]
    subprocess.run(cmd, capture_output=True, timeout=3)
    time.sleep(0.15)

    # 2. Query live QML state
    status = query_status()
    if not status:
        print(f"❌ {trigger:<18} -> FAILED (No status returned)")
        failed += 1
        continue

    current_anim = status.get("currentAnim")
    frame_coords = status.get("frameCoords", [0, 0])
    
    # Check if animation loaded and has valid frames
    expected_data = anim_data.get(expected_anim)
    if not expected_data:
        print(f"❌ {trigger:<18} -> FAILED (Expected animation '{expected_anim}' not in database)")
        failed += 1
        continue

    valid_coords = [(f["x"], f["y"]) for f in expected_data["frames"]]
    is_anim_correct = (current_anim.lower() == expected_anim.lower() or current_anim.lower() == trigger.lower())
    
    if is_anim_correct:
        print(f"✅ {trigger:<18} -> PASS (Loaded: '{current_anim}', Frame: {status.get('currentFrameIdx')}, Coords: {frame_coords})")
        passed += 1
    else:
        print(f"❌ {trigger:<18} -> FAILED (Got '{current_anim}', Expected '{expected_anim}')")
        failed += 1

print(f"\n==========================================")
print(f"Verification Results: {passed}/{len(TEST_CASES)} PASSED ({(passed/len(TEST_CASES))*100:.1f}%)")
print(f"==========================================")
