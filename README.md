# Omaclippy 📎

> **The nostalgic Microsoft Clippy companion for Omarchy Linux & Hyprland.**

![Omaclippy Preview](preview.png)

Omaclippy brings the iconic 1997 Microsoft Office Assistant back to life as a modern, interactive desktop companion integrated with the [Omarchy](https://omarchy.org/) desktop shell.

---

## ✨ Features

- 📎 **Authentic Sprite Animations:** Over 40 full animations parsed from the original Microsoft Agent Clippy sprite sheet (`Wave`, `Thinking`, `Explain`, `GetWizardy`, `GetArtsy`, `GetTechy`, `Writing`, `Print`, `Save`, `SendMail`, `Congratulate`, `IdleAtom`, `IdleRopePile`, `IdleFingerTap`, and many more).
- 🔊 **Sound Effects:** Complete collection of 15 classic sound effects synchronized with animations using `pw-play` (PipeWire).
- 💬 **Retro Speech Balloons:** Expressive speech bubble with typewriter animation, customizable durations, and built-in Omarchy tips and retro quotes.
- 🖱️ **Interactive Drag & Drop:** Click and drag Clippy anywhere across your multi-monitor desktop. 100% click-through mask ensures your underlying windows and desktop remain completely usable.
- 🎯 **Hyprland & Cursor Awareness:** Glances in the direction of your mouse pointer, reacts when windows move or when clicked nearby.
- 📊 **Status Bar Widget & Control Center:** Dedicated Omarchy Bar Widget with quick-actions, volume sliders, scale selectors, animation launcher grid, and speech prompt.
- ⚡ **Full IPC Surface:** Control Clippy directly from terminal scripts, hotkeys, or shell hooks via `omarchy-shell`.

---

## 📦 Requirements & Dependencies

Omaclippy runs out-of-the-box on Omarchy Linux with zero third-party package compilation:
- **Omarchy Shell & Hyprland:** Native Quickshell runtime environment.
- **PipeWire (`pw-play`):** Standard system audio utility for synchronized retro sound effects.
- **Python 3:** Standard library only (no `pip` packages required; powers background tracker and MCP server).

---

## 🚀 Installation

### 1. Clone the plugin to your Omarchy plugins directory:

```bash
git clone https://github.com/jvlianodorneles/omaclippy.git ~/.config/omarchy/plugins/dorneles.omaclippy
```

### 2. Rescan or Restart the Omarchy Shell:

```bash
omarchy-shell shell rescanPlugins
# or
omarchy restart shell
```

### 3. Add to Status Bar (Recommended):

Add `{"id": "dorneles.omaclippy"}` to your `bar.layout` in `~/.config/omarchy/shell.json` or run:

```bash
omarchy bar move dorneles.omaclippy --section right
```

---

## 🗑️ Uninstallation

If you ever wish to remove Omaclippy:

### 1. Remove from Status Bar:

```bash
omarchy bar remove dorneles.omaclippy
```
*(Or remove `"dorneles.omaclippy"` from `bar.layout` in `~/.config/omarchy/shell.json`)*

### 2. Delete the plugin directory:

```bash
rm -rf ~/.config/omarchy/plugins/dorneles.omaclippy
```

### 3. Clean up saved state & configuration (Optional):

```bash
rm -rf ~/.local/state/omarchy/omaclippy
```

### 4. Reload Omarchy Shell:

```bash
omarchy-shell shell rescanPlugins
# or
omarchy restart shell
```

---

## 🎮 Desktop Interactions

| Action | Result |
|---|---|
| **Left Click on Clippy** | Plays a random fun animation + sound effect |
| **Click & Drag** | Moves Clippy anywhere across your screens |
| **Right Click on Clippy** | Shows a speech balloon with a random tip or quote |
| **Click Bar Widget** | Opens the rich Control Center & Animation Picker |
| **Right Click Bar Widget** | Instantly toggles Clippy On / Off |
| **Middle Click Bar Widget** | Triggers a quick random animation |

---

## 🤖 AI Agents & System Integration

Omaclippy transforms Clippy into an interactive visual companion for AI coding assistants (**Google Antigravity**, **Claude Code**, **Herdr**) and development workflows.

### 🧠 1. Model Context Protocol (MCP) Server (Antigravity & Claude)

Omaclippy includes a built-in MCP server (`mcp_server.py`) exposing tools for AI agents:
- `clippy_react(animation, message)`: Visual thought/action reaction + balloon.
- `clippy_speak(message)`: Typewriter speech balloon on screen.
- `clippy_animate(animation)`: Play authentic animation + retro sound.
- `clippy_status()`: Get live coordinates, mode, and visibility.

#### 🔧 Configure in Claude Code / Claude Desktop:

Add to your `~/.claude/mcp.json` or run:

```bash
claude mcp add omaclippy python3 ~/.config/omarchy/plugins/dorneles.omaclippy/mcp_server.py
```

#### 🔧 Configure in Antigravity / Gemini CLI:

Add to your MCP settings or plugin configuration:

```json
{
  "mcpServers": {
    "omaclippy": {
      "command": "python3",
      "args": ["/home/dorneles/.config/omarchy/plugins/dorneles.omaclippy/mcp_server.py"]
    }
  }
}
```

---

### 🐝 2. Herdr Autonomous Agents Integration

Omaclippy monitors [Herdr](https://github.com/fabean/herdr) agent states in real time:
- **Agent `working`:** Clippy plays `GetTechy` / `Writing` animation.
- **Agent `blocked` (needs user input):** Clippy plays `Alert` with retro warning sound and displays: *"⚠️ Agent 'worker-1' is blocked and waiting for your response!"*.
- **Agent `done` (completed task):** Clippy plays `Congratulate` / `Wave` with celebration audio: *"🎉 Agent 'worker-1' completed task successfully!"*.

*Toggle this feature on/off anytime in the Control Panel under Settings ➔ "AI Agents (Herdr)".*

---

### 💬 3. Interactive Floating AI Prompt & Native System Agent

Ask questions directly to your default coding agent (`agy` / `claude` / `herdr`) without switching windows:
- **Double Click Clippy** (or run `omaclippy prompt`) to open the retro floating prompt directly on screen.
- Type your prompt and press **Enter**:
  - Clippy morphs into `Thinking` mode.
  - Forwards the request seamlessly to Omarchy's native agent system (`omarchy agent prompt "<PROMPT>"`).

---

### ⚡ 4. Hardware & Inactivity Reactivity

Omaclippy monitors your system hardware and desktop activity in the background:
- **🔋 Low Battery Alert:** Warns with `Alert` when battery drops below 15% on discharge.
- **⚡ Charger Plugged In:** Celebrates with `Congratulate` when connected to power.
- **💤 Inactivity Sleep:** After 5 minutes without mouse/keyboard activity, Clippy falls asleep (`IdleSnooze` with *Zzz*).
- **👋 User Return:** Upon moving the mouse or typing, Clippy wakes up cheerfully (`Greeting`).

---

### 🧲 5. Window Magnetism & Spring Physics

- **Window Title Snapping:** When dragging Clippy near an active window titlebar in `companion` or `perch` mode, he magnetically snaps onto the window corner.
- **Edge Snapping:** Snaps cleanly to monitor borders within 28px.
- **Elastic Bounce Animation:** Physics-based spring animations (`Easing.OutBack`) for natural, playful movement.

---

### 💻 6. CLI Helper (`omaclippy`)

You can control Clippy directly from terminal commands or scripts:

```bash
# Interactive AI Prompt
omaclippy prompt

# Quick agent status triggers
omaclippy thinking "Analyzing project dependencies..."
omaclippy writing "Refactoring QML components..."
omaclippy techy "Running automated test suites..."
omaclippy wizard "Executing database migrations..."
omaclippy alert "Test failure detected!"
omaclippy done "Build completed successfully!"

# Speech & animations
omaclippy speak "It looks like you're coding on Arch Linux!"
omaclippy play Congratulate
omaclippy tip
```

---

### 🪝 7. Git & Terminal Shell Hooks

Ready-to-use hooks are provided in the `hooks/` directory:

1. **Git Post-Commit Hook (`hooks/git-post-commit`):**
   - Plays the `Save` animation and shows your commit message.
   - Copy to `.git/hooks/post-commit` or configure globally.

2. **Git Pre-Push Hook (`hooks/git-pre-push`):**
   - Plays the `SendMail` (paper airplane) animation when pushing code.
   - Copy to `.git/hooks/pre-push`.

3. **Zsh Long Command Timer (`hooks/zsh-command-hook.zsh`):**
   - Automatically notifies you via Clippy when long-running builds, downloads, or test suites (> 8s) finish or fail.
   - Add to your `~/.zshrc`:
     ```bash
     source ~/.config/omarchy/plugins/dorneles.omaclippy/hooks/zsh-command-hook.zsh
     ```

---

## 🛠️ CLI & IPC Commands

Control Clippy from any script, keybinding, or terminal:

```bash
# Play specific animations
omarchy-shell dorneles.omaclippy play Wave
omarchy-shell dorneles.omaclippy play Thinking
omarchy-shell dorneles.omaclippy play GetWizardy
omarchy-shell dorneles.omaclippy play GetTechy
omarchy-shell dorneles.omaclippy play Writing

# Make Clippy speak custom text in a balloon
omarchy-shell dorneles.omaclippy speak "Hello from the Arch Linux terminal!"

# Trigger a random tip
omarchy-shell dorneles.omaclippy tip

# Toggle Clippy on / off
omarchy-shell dorneles.omaclippy toggle
omarchy-shell dorneles.omaclippy on
omarchy-shell dorneles.omaclippy off

# Change size (small, normal, large, giant)
omarchy-shell dorneles.omaclippy setScale large

# Change mode (companion, roam, perch)
omarchy-shell dorneles.omaclippy setMode roam

# Reset position to default corner
omarchy-shell dorneles.omaclippy resetPosition

# Check status
omarchy-shell dorneles.omaclippy status
```

---

## 🎭 Complete Animation Catalogue (43 Total)

Below is the complete, frame-by-frame verified catalogue of all 43 authentic Microsoft Clippy animations, including direct CLI commands, durations, audio effects, and exact visual behaviors on screen:

### 📦 1. Tools, Actions & Transformations

| CLI Command | Canonical Name | Aliases | Duration | Audio | Exact Visual Behavior |
|---|---|---|:---:|:---:|---|
| `omaclippy save [msg]` | `Save` | `disk`, `floppy` | 5.53s | 🔊 | Morphs into a **wire document holder with a lined notebook page** sliding in and out. |
| `omaclippy print [msg]` | `Print` | `printer` | 8.40s | 🔊 | Morphs into a **lined sheet of paper rolling and waving** as if through a paper press. |
| `omaclippy mail [msg]` | `SendMail` | `email`, `airplane` | 6.80s | 🔊 | Folds into a **paper airplane** and flies off across the screen. |
| `omaclippy write [msg]` | `Writing` | `notepad` | 8.40s | 🔊 | Holds a **yellow notepad pad** and writes rapidly with a red pen/pencil. |
| `omaclippy search [msg]` | `Searching` | `find`, `look` | 8.10s | 🔊 | Pulls out a **vintage spyglass / telescope on a stand** and peers through it. |
| `omaclippy trash [msg]` | `EmptyTrash` | `delete` | 5.00s | 🔊 | Spins into a **wire tornado / spiral vortex** that shreds and swallows a paper page. |
| `omaclippy process [msg]` | `Processing` | `gear` | 3.80s | 🔊 | Morphs into a **scoop / paddle** that juggles and catches a small paper cup. |
| `omaclippy done [msg]` | `Congratulate` | `congrats`, `celebrate`, `ok`, `success`, `finish` | 3.68s | 🔊 | Unfolds and morphs into a **glowing green Checkmark (V)** with magical twinkling sparkles. |

---

### 👋 2. Greetings, Expressions & Alarms

| CLI Command | Canonical Name | Aliases | Duration | Audio | Exact Visual Behavior |
|---|---|---|:---:|:---:|---|
| `omaclippy wave [msg]` | `Wave` | - | 4.90s | 🔊 | Smiles and **happily waves a hand** to the user. |
| `omaclippy greeting [msg]` | `Greeting` | `greet`, `hi`, `hello` | 4.45s | 🔊 | Spins in from a **spiral and unfolds** onto the screen as Clippy. |
| `omaclippy goodbye [msg]` | `GoodBye` | `bye` | 4.45s | 🔊 | **Waves farewell and vanishes** by spinning out of the screen. |
| `omaclippy alert [msg]` | `Alert` | `warn`, `warning` | 2.40s | 🔊 | **Repeatedly knocks with both hands on the glass screen** demanding urgent attention. |
| `omaclippy attention [msg]` | `GetAttention` | - | 2.65s | 🔊 | Leans down on a **yellow paper mat** and taps head/eyes to be noticed. |
| `omaclippy thinking [msg]` | `Thinking` | `think` | 4.50s | 🔊 | Morphs body into an **atomic model with 3 orbital rings and spinning electrons**. |
| `omaclippy explain [msg]` | `Explain` | - | 1.50s | - | Opens both arms wide gesturing as if explaining a concept. |
| `omaclippy hearing [msg]` | `Hearing_1` | `listen` | 5.40s | 🔊 | Places a **cupped hand behind the ear** listening attentively. |
| `omaclippy check [msg]` | `CheckingSomething` | - | 6.64s | 🔊 | Leans forward and **curiously inspects the desktop floor**. |

---

### ⏳ 3. Idles & Postures

| CLI Command | Canonical Name | Aliases | Duration | Audio | Exact Visual Behavior |
|---|---|---|:---:|:---:|---|
| `omaclippy sleep [msg]` | `IdleSnooze` | `snooze`, `zzz` | 13.60s | - | Rests head on hands, **falls fast asleep, and snores with floating (*Zzz*)**. |
| `omaclippy atom [msg]` | `IdleAtom` | - | 4.50s | - | Transforms into the **atom with 3 rotating orbital rings**. |
| `omaclippy mobile [msg]` | `IdleRopePile` | `rope` | 7.50s | - | Unravels into a **hanging mobile of loose wire strings** and pulls itself back up. |
| `omaclippy tap [msg]` | `IdleFingerTap` | - | 1.15s | - | Impatiently taps fingers on the ground. |
| `omaclippy scratch [msg]` | `IdleHeadScratch` | - | 1.90s | - | Scratches the top of the head with a puzzled look. |
| `omaclippy eyebrow [msg]` | `IdleEyeBrowRaise`| - | 1.50s | - | Inquisitively raises the left eyebrow. |
| `omaclippy sidetoside [msg]` | `IdleSideToSide` | - | 5.60s | - | Gently sways body and eyes from side to side. |
| `omaclippy idle [msg]` | `Idle1_1` | - | 7.30s | - | Natural breathing and eye blinking. |
| `omaclippy rest` | `RestPose` | - | 0.10s | - | Classic neutral resting posture. |

---

### 👉 4. Gestures & Pointers

| CLI Command | Canonical Name | Duration | Exact Visual Behavior |
|---|---|:---:|---|
| `omaclippy play GestureUp` | `GestureUp` | 2.80s | Extends arm and points upward. |
| `omaclippy play GestureDown` | `GestureDown` | 2.25s | Extends arm and points downward. |
| `omaclippy play GestureLeft` | `GestureLeft` | 3.05s | Extends arm and points to the left. |
| `omaclippy play GestureRight` | `GestureRight` | 3.25s | Extends arm and points to the right. |

---

### 👀 5. Directional Cursor Look Glances (8 Directions)

| CLI Command | Canonical Name | Duration | Exact Visual Behavior |
|---|---|:---:|---|
| `omaclippy play LookUp` | `LookUp` | 1.80s | Glances toward the top of the screen. |
| `omaclippy play LookDown` | `LookDown` | 1.80s | Glances toward the bottom of the screen. |
| `omaclippy play LookRight` | `LookRight` | 1.80s | Glances toward the left side of the screen. |
| `omaclippy play LookLeft` | `LookLeft` | 1.80s | Glances toward the right side of the screen. |
| `omaclippy play LookUpRight` | `LookUpRight` | 1.80s | Glances toward the top-left diagonal of the screen. |
| `omaclippy play LookUpLeft` | `LookUpLeft` | 1.80s | Glances toward the top-right diagonal of the screen. |
| `omaclippy play LookDownRight` | `LookDownRight` | 1.80s | Glances toward the bottom-left diagonal of the screen. |
| `omaclippy play LookDownLeft` | `LookDownLeft` | 1.80s | Glances toward the bottom-right diagonal of the screen. |

---

### 🎭 6. Legacy MS Agent API Names & Transitions

| CLI Command | Canonical Name | Aliases | Duration | Audio | Exact Visual Behavior |
|---|---|---|:---:|:---:|---|
| `omaclippy wizard [msg]` | `GetWizardy` | `wizardry`, `magic`, `merlin` | 3.68s | 🔊 | *(Legacy API name)* Unfolds into the glowing green checkmark with magical sparkles. |
| `omaclippy tech [msg]` | `GetTechy` | `techy`, `gettech` | 4.50s | 🔊 | *(Legacy API name)* Morphs into the atom with technology sound effect. |
| `omaclippy art [msg]` | `GetArtsy` | `artsy`, `getart`, `painter` | 4.90s | 🔊 | *(Legacy API name)* Unravels into the hanging mobile of loose wire strings. |
| `omaclippy play Hide` | `Hide` | - | 0.05s | - | Quick transition collapsing and hiding. |
| `omaclippy play Show` | `Show` | - | 0.05s | - | Quick transition expanding and appearing. |

---

## 📜 Acknowledgments & Credits

- Inspired by [modern-clippy](https://github.com/vchaindz/modern-clippy) by vchaindz.
- Original Microsoft Agent Clippy graphics & sound effects (Microsoft Office 1997-2003).
- Inspired by the classic [clippy.js](https://github.com/smore-inc/clippy.js).

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
