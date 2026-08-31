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
- **Agent `blocked` (needs user input):** Clippy plays `Alert` with retro warning sound and displays: *"⚠️ Agente 'worker-1' está bloqueado e aguarda sua resposta!"*.
- **Agent `done` (completed task):** Clippy plays `Congratulate` / `Wave` with celebration audio: *"🎉 Agente 'worker-1' concluiu sua tarefa com sucesso!"*.

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
omaclippy thinking "Analisando dependências do projeto..."
omaclippy writing "Refatorando arquivos QML..."
omaclippy techy "Executando testes automatizados..."
omaclippy wizard "Executando migração de banco de dados..."
omaclippy alert "Erro encontrado nos testes!"
omaclippy done "Build finalizado com sucesso!"

# Speech & animations
omaclippy speak "Parece que você está codificando no Arch Linux!"
omaclippy play Congratulate
omaclippy tip
```

---

### 🪝 7. Git & Terminal Shell Hooks

Ready-to-use hooks are provided in the `hooks/` directory:

1. **Git Post-Commit Hook (`hooks/git-post-commit`):**
   - Plays the `Save` (floppy disk) animation and shows your commit message.
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

| CLI Command | Canonical Name | Aliases | Duração | Áudio | Comportamento Visual Exato |
|---|---|---|:---:|:---:|---|
| `omaclippy save [msg]` | `Save` | `disk`, `floppy` | 5.53s | 🔊 | Transforma-se em um **suporte de arame com folha de caderno pautada** que desliza para dentro e para fora. |
| `omaclippy print [msg]` | `Print` | `printer` | 8.40s | 🔊 | Transforma-se em uma **folha pautada que rola e ondula** como se passasse por uma prensa de papel. |
| `omaclippy mail [msg]` | `SendMail` | `email`, `airplane` | 6.80s | 🔊 | Dobra-se em formato de um **pequeno aviãozinho de papel** e voa para fora da tela. |
| `omaclippy write [msg]` | `Writing` | `notepad` | 8.40s | 🔊 | Segura uma **folhinha amarela** e anota rapidamente com uma caneta/lápis vermelho. |
| `omaclippy search [msg]` | `Searching` | `find`, `look` | 8.10s | 🔊 | Puxa uma **luneta / telescópio retrô com suporte** e espia através dela inspecionando a tela. |
| `omaclippy trash [msg]` | `EmptyTrash` | `delete` | 5.00s | 🔊 | Transforma-se em um **redemoinho / tornado de arame em espiral** que suga e tritura uma folha de papel. |
| `omaclippy process [msg]` | `Processing` | `gear` | 3.80s | 🔊 | Transforma-se em uma **pázinha/concha** que joga e apara um potinho de papel. |
| `omaclippy done [msg]` | `Congratulate` | `congrats`, `celebrate`, `ok`, `success`, `finish` | 3.68s | 🔊 | Desdobra-se e transforma-se no **símbolo de V / Checkmark verde brilhante** com faíscas estelares mágicas. |

---

### 👋 2. Greetings, Expressions & Alarms

| CLI Command | Canonical Name | Aliases | Duração | Áudio | Comportamento Visual Exato |
|---|---|---|:---:|:---:|---|
| `omaclippy wave [msg]` | `Wave` | - | 4.90s | 🔊 | Sorri e **acena alegremente com a mão** para o usuário. |
| `omaclippy greeting [msg]` | `Greeting` | `greet`, `hi`, `hello` | 4.45s | 🔊 | Surge **girando em espiral e se desdobra** na tela como Clippy. |
| `omaclippy goodbye [msg]` | `GoodBye` | `bye` | 4.45s | 🔊 | **Acena em despedida e desaparece** girando para fora da tela. |
| `omaclippy alert [msg]` | `Alert` | `warn`, `warning` | 2.40s | 🔊 | **Bate repetidamente com as duas mãos no vidro da tela** chamando atenção urgente. |
| `omaclippy attention [msg]` | `GetAttention` | - | 2.65s | 🔊 | Inclina-se sobre um **tapete/folha amarela** e bate com a cabeça e os olhos. |
| `omaclippy thinking [msg]` | `Thinking` | `think` | 4.50s | 🔊 | Transforma o corpo em um **modelo atômico com 3 anéis orbitais e elétrons girando**. |
| `omaclippy explain [msg]` | `Explain` | - | 1.50s | - | Abre os dois braços lateralmente gesticulando como quem explica. |
| `omaclippy hearing [msg]` | `Hearing_1` | `listen` | 5.40s | 🔊 | Coloca a **mão curvada atrás da orelha** para escutar com atenção. |
| `omaclippy check [msg]` | `CheckingSomething` | - | 6.64s | 🔊 | Inclina-se para a frente e **examina o chão/mesa com curiosidade**. |

---

### ⏳ 3. Idles & Postures

| CLI Command | Canonical Name | Aliases | Duração | Áudio | Comportamento Visual Exato |
|---|---|---|:---:|:---:|---|
| `omaclippy sleep [msg]` | `IdleSnooze` | `snooze`, `zzz` | 13.60s | - | Apoia a cabeça, **dorme profundamente e solta letras (*Zzz*)**. |
| `omaclippy atom [msg]` | `IdleAtom` | - | 4.50s | - | Transforma-se no **átomo com 3 anéis giratórios**. |
| `omaclippy mobile [msg]` | `IdleRopePile` | `rope` | 7.50s | - | Desmancha-se como um **móbile / novelo de cordas soltas penduradas** e se puxa de volta. |
| `omaclippy tap [msg]` | `IdleFingerTap` | - | 1.15s | - | Bate os dedos no chão impacientemente. |
| `omaclippy scratch [msg]` | `IdleHeadScratch` | - | 1.90s | - | Coça o topo da cabeça com expressão de dúvida. |
| `omaclippy eyebrow [msg]` | `IdleEyeBrowRaise`| - | 1.50s | - | Ergue a sobrancelha esquerda desconfiado. |
| `omaclippy sidetoside [msg]` | `IdleSideToSide` | - | 5.60s | - | Balança suavemente o corpo e os olhos de um lado para o outro. |
| `omaclippy idle [msg]` | `Idle1_1` | - | 7.30s | - | Respiração natural e piscar de olhos. |
| `omaclippy rest` | `RestPose` | - | 0.10s | - | Pose neutra clássica de repouso. |

---

### 👉 4. Gestos e Apontadores

| CLI Command | Canonical Name | Duração | Comportamento Visual |
|---|---|:---:|---|
| `omaclippy play GestureUp` | `GestureUp` | 2.80s | Estica o braço e aponta para cima. |
| `omaclippy play GestureDown` | `GestureDown` | 2.25s | Estica o braço e aponta para baixo. |
| `omaclippy play GestureLeft` | `GestureLeft` | 3.05s | Estica o braço e aponta para a esquerda. |
| `omaclippy play GestureRight` | `GestureRight` | 3.25s | Estica o braço e aponta para a direita. |

---

### 👀 5. Rastreamento de Olhar do Cursor (8 Direções)

| CLI Command | Canonical Name | Duração | Comportamento Visual |
|---|---|:---:|---|
| `omaclippy play LookUp` | `LookUp` | 1.80s | Olha para cima na tela. |
| `omaclippy play LookDown` | `LookDown` | 1.80s | Olha para baixo na tela. |
| `omaclippy play LookRight` | `LookRight` | 1.80s | Olha para o lado esquerdo da tela. |
| `omaclippy play LookLeft` | `LookLeft` | 1.80s | Olha para o lado direito da tela. |
| `omaclippy play LookUpRight` | `LookUpRight` | 1.80s | Olha para a diagonal superior esquerda. |
| `omaclippy play LookUpLeft` | `LookUpLeft` | 1.80s | Olha para a diagonal superior direita. |
| `omaclippy play LookDownRight` | `LookDownRight` | 1.80s | Olha para a diagonal inferior esquerda. |
| `omaclippy play LookDownLeft` | `LookDownLeft` | 1.80s | Olha para a diagonal inferior direita. |

---

### 🎭 6. Nomes Herdados da API MS Agent & Transições

| CLI Command | Canonical Name | Aliases | Duração | Áudio | Comportamento Visual |
|---|---|---|:---:|:---:|---|
| `omaclippy wizard [msg]` | `GetWizardy` | `wizardry`, `magic`, `merlin` | 3.68s | 🔊 | *(Nome herdado da API)* Transforma-se no Checkmark mágico com faíscas. |
| `omaclippy tech [msg]` | `GetTechy` | `techy`, `gettech` | 4.50s | 🔊 | *(Nome herdado da API)* Transforma-se no átomo com efeito sonoro de tecnologia. |
| `omaclippy art [msg]` | `GetArtsy` | `artsy`, `getart`, `painter` | 4.90s | 🔊 | *(Nome herdado da API)* Desmancha-se como móbile / novelo de cordas. |
| `omaclippy play Hide` | `Hide` | - | 0.05s | - | Transição de recolher e ocultar. |
| `omaclippy play Show` | `Show` | - | 0.05s | - | Transição de desdobrar e surgir. |

---

## 📜 Acknowledgments & Credits

- Inspired by [modern-clippy](https://github.com/vchaindz/modern-clippy) by vchaindz.
- Original Microsoft Agent Clippy graphics & sound effects (Microsoft Office 1997-2003).
- Inspired by the classic [clippy.js](https://github.com/smore-inc/clippy.js).

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
