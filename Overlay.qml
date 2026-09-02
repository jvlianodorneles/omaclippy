import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import "Animations.js" as AnimData

PanelWindow {
  id: root

  // -------------------------------------------------------------
  // Screen Selection & Window Anchors
  // -------------------------------------------------------------
  screen: {
    var best = null
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (!best || screens[i].width * screens[i].height > best.width * best.height)
        best = screens[i]
    }
    return best
  }

  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.namespace: "omaclippy"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: root.promptActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // Input mask covers the companion area (enclosing Clippy and Speech Bubble)
  mask: Region {
    item: root.clippyEnabled ? companionArea : null
  }

  // -------------------------------------------------------------
  // Settings & Configuration
  // -------------------------------------------------------------
  property bool clippyEnabled: true
  property string clippyMode: "companion" // "companion" | "roam" | "perch"
  property string clippyScale: "normal"  // "small" | "normal" | "large" | "giant"
  property bool soundEnabled: true
  property real soundVolume: 0.5
  property string idleFrequency: "normal" // "calm" | "normal" | "frequent"
  property bool speechBubbles: true
  property string balloonSkin: "classic" // "classic" | "glass" | "terminal"
  property bool reactToCursor: true
  property bool reactToWindows: true
  property bool reactToAgents: true
  property bool reactToSystem: true
  property bool rawInputTracking: false

  // State Persistence & Trusted Path Bounds
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omaclippy"
  readonly property string stateFilePath: stateDir + "/config.json"
  readonly property string dirFs: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property string soundsDir: Qt.resolvedUrl("assets/sounds/").toString().replace("file://", "")

  // Trusted Absolute Binaries
  readonly property string pythonBin: "/usr/bin/python3"
  readonly property string pwPlayBin: "/usr/bin/pw-play"
  readonly property string omarchyBin: "/usr/share/omarchy/bin/omarchy"
  readonly property string omarchyShellBin: "/usr/share/omarchy/bin/omarchy-shell"

  // Scale Factors
  readonly property real scaleFactor: {
    switch (root.clippyScale) {
      case "small": return 0.75;
      case "large": return 1.5;
      case "giant": return 2.0;
      case "normal":
      default: return 1.0;
    }
  }

  readonly property real clippyWidth: Math.round(124 * root.scaleFactor)
  readonly property real clippyHeight: Math.round(93 * root.scaleFactor)

  // Smart Speech Bubble Orientation
  readonly property bool showSpeechBelow: root.posY < 130
  readonly property bool showSpeechLeft: root.posX < 180

  // -------------------------------------------------------------
  // Position & Movement State (with Spring Physics & Magnetism)
  // -------------------------------------------------------------
  property real posX: 350
  property real posY: 350
  property real targetPosX: 350
  property real targetPosY: 350
  property bool isDragging: false
  property bool isMoving: false

  property real pointerX: 0
  property real pointerY: 0
  property double lastCursorLookTime: 0
  property var lastWindowRect: null

  // Dynamic Bounding Geometry for Companion Area
  readonly property real bubbleW: bubbleItem.width
  readonly property real bubbleH: bubbleItem.height
  readonly property bool speechActive: root.speechVisible || (bubbleItem && bubbleItem.visible)

  readonly property real areaX: root.speechActive
    ? (root.showSpeechLeft ? root.posX : (root.posX - Math.max(0, root.bubbleW - root.clippyWidth)))
    : root.posX

  readonly property real areaY: root.speechActive
    ? (root.showSpeechBelow ? root.posY : (root.posY - root.bubbleH - 8))
    : root.posY

  readonly property real areaWidth: root.speechActive
    ? Math.max(root.clippyWidth, root.bubbleW)
    : root.clippyWidth

  readonly property real areaHeight: root.speechActive
    ? (root.clippyHeight + root.bubbleH + 8)
    : root.clippyHeight

  // -------------------------------------------------------------
  // Centralized Animation Engine with Loop Bounding
  // -------------------------------------------------------------
  property string currentAnim: "RestPose"
  property var currentAnimObj: AnimData.getAnimation("RestPose")
  property int currentFrameIdx: 0
  property real currentFrameX: 0
  property real currentFrameY: 0
  property bool isCustomPlaying: false
  property int animLoopCount: 0
  property int maxAnimLoops: 2

  // -------------------------------------------------------------
  // Centralized Speech Bubble State & Interactive AI
  // -------------------------------------------------------------
  property string speechFullText: ""
  property string speechDisplayedText: ""
  property bool speechVisible: false
  property int speechTypewriterIdx: 0
  property bool promptActive: false
  property var currentActionButtons: []

  function playSound(soundId) {
    if (!root.soundEnabled || root.soundVolume <= 0 || !soundId) return
    var safeSoundId = String(soundId).trim()
    if (!/^[a-zA-Z0-9_-]+$/.test(safeSoundId) || safeSoundId.length > 20) return
    var filePath = root.soundsDir + safeSoundId + ".mp3"
    Quickshell.execDetached([root.pwPlayBin, "--volume", root.soundVolume.toFixed(2), filePath])
  }

  function applyFrame(idx) {
    if (!root.currentAnimObj || !root.currentAnimObj.frames || root.currentAnimObj.frames.length === 0) return
    if (idx < 0 || idx >= root.currentAnimObj.frames.length) return

    var f = root.currentAnimObj.frames[idx]
    root.currentFrameX = f.x
    root.currentFrameY = f.y

    if (f.sound) {
      root.playSound(f.sound)
    }

    var dur = f.duration > 0 ? f.duration : 100
    frameTimer.interval = dur
    frameTimer.restart()
  }

  function advanceFrame() {
    if (!root.currentAnimObj || !root.currentAnimObj.frames || root.currentAnimObj.frames.length === 0) return

    var cur = root.currentAnimObj.frames[root.currentFrameIdx]
    var nextIdx = root.currentFrameIdx + 1

    if (cur.branching && cur.branching.branches && cur.branching.branches.length > 0) {
      if (root.animLoopCount < root.maxAnimLoops) {
        var roll = Math.random() * 100
        var accum = 0
        for (var i = 0; i < cur.branching.branches.length; i++) {
          var branch = cur.branching.branches[i]
          accum += (branch.weight || 0)
          if (roll <= accum) {
            if (branch.frameIndex <= root.currentFrameIdx) {
              root.animLoopCount += 1
            }
            nextIdx = branch.frameIndex
            break
          }
        }
      } else {
        if (cur.exitBranch !== null && cur.exitBranch !== undefined) {
          nextIdx = cur.exitBranch
        } else {
          nextIdx = root.currentFrameIdx + 1
        }
      }
    }

    if (nextIdx >= root.currentAnimObj.frames.length) {
      root.isCustomPlaying = false
      root.currentAnim = "RestPose"
      root.currentAnimObj = AnimData.getAnimation("RestPose")
      root.currentFrameIdx = 0
      root.animLoopCount = 0
      safetyTimer.stop()
      root.applyFrame(0)
    } else {
      root.currentFrameIdx = nextIdx
      root.applyFrame(root.currentFrameIdx)
    }
  }

  Timer {
    id: frameTimer
    interval: 100
    repeat: false
    running: false
    onTriggered: root.advanceFrame()
  }

  Timer {
    id: safetyTimer
    interval: 10000
    repeat: false
    running: false
    onTriggered: {
      if (root.currentAnim !== "RestPose") {
        root.isCustomPlaying = false
        root.currentAnim = "RestPose"
        root.currentAnimObj = AnimData.getAnimation("RestPose")
        root.currentFrameIdx = 0
        root.animLoopCount = 0
        root.applyFrame(0)
      }
    }
  }

  function playAnimation(animName) {
    var safeName = String(animName || "").trim().substring(0, 40)
    var anim = AnimData.getAnimation(safeName)
    if (!anim || !anim.frames || anim.frames.length === 0) {
      root.currentAnim = "RestPose"
      root.currentAnimObj = AnimData.getAnimation("RestPose")
      root.currentFrameIdx = 0
      root.animLoopCount = 0
      safetyTimer.stop()
      root.applyFrame(0)
      return
    }

    root.animLoopCount = 0
    root.isCustomPlaying = (safeName !== "RestPose")
    root.currentAnim = anim.name || safeName
    root.currentAnimObj = anim
    root.currentFrameIdx = 0
    root.applyFrame(0)

    if (safeName !== "RestPose") {
      var timeout = Math.max(8000, (anim.totalDuration || 3000) * 2.5)
      safetyTimer.interval = timeout
      safetyTimer.restart()
    } else {
      safetyTimer.stop()
    }
  }

  function playRandomAction() {
    var anim = AnimData.getRandomActionAnimation()
    root.playAnimation(anim)
  }

  function playRandomIdle() {
    if (root.isCustomPlaying || root.isDragging) return
    var anim = AnimData.getRandomIdleAnimation()
    root.playAnimation(anim)
  }

  // -------------------------------------------------------------
  // Speech & Interactive AI Prompt Functions
  // -------------------------------------------------------------
  function speak(text, durationMs, buttons) {
    if (!root.clippyEnabled || !root.speechBubbles) return
    var cleanText = String(text || "").substring(0, 500)
    root.promptActive = false
    bubbleItem.isPromptMode = false
    
    // Cardinality limit on buttons (max 5)
    var cleanButtons = []
    if (Array.isArray(buttons)) {
      for (var i = 0; i < Math.min(5, buttons.length); i++) {
        var b = buttons[i]
        if (b && typeof b === "object") {
          cleanButtons.push({
            label: String(b.label || "").substring(0, 40),
            action: String(b.action || "").substring(0, 40),
            color: b.color ? String(b.color).substring(0, 20) : null
          })
        }
      }
    }
    root.currentActionButtons = cleanButtons
    root.speechFullText = cleanText
    root.speechDisplayedText = ""
    root.speechVisible = true
    root.speechTypewriterIdx = 0
    typewriterTimer.restart()

    var autoDuration = Math.min(30000, Math.max(500, Number(durationMs) || Math.max(4500, cleanText.length * 90)))
    autoCloseSpeechTimer.interval = autoDuration
    autoCloseSpeechTimer.restart()

    if (!root.isCustomPlaying) {
      root.playAnimation("Explain")
    }
  }

  function openPrompt() {
    if (!root.clippyEnabled) return
    root.currentActionButtons = []
    root.speechFullText = ""
    root.speechDisplayedText = ""
    root.speechVisible = true
    root.promptActive = true
    bubbleItem.isPromptMode = true
    autoCloseSpeechTimer.stop()
    typewriterTimer.stop()
    root.playAnimation("Hearing_1")
  }

  function sendToNativeAgent(promptText) {
    root.promptActive = false
    bubbleItem.isPromptMode = false
    var cleanPrompt = String(promptText || "").substring(0, 500)
    root.playAnimation("Thinking")
    root.speak("Sending to agent: " + cleanPrompt, 4000)
    Quickshell.execDetached([root.omarchyBin, "agent", "prompt", cleanPrompt])
  }

  function hideSpeech() {
    root.speechVisible = false
    root.promptActive = false
    bubbleItem.isPromptMode = false
    root.currentActionButtons = []
    typewriterTimer.stop()
    autoCloseSpeechTimer.stop()
  }

  function showRandomTip() {
    var tip = AnimData.getRandomTip()
    root.speak(tip)
  }

  Timer {
    id: typewriterTimer
    interval: 22
    repeat: true
    running: false
    onTriggered: {
      if (root.speechTypewriterIdx < root.speechFullText.length) {
        root.speechTypewriterIdx += 1
        root.speechDisplayedText = root.speechFullText.substring(0, root.speechTypewriterIdx)
      } else {
        typewriterTimer.stop()
      }
    }
  }

  Timer {
    id: autoCloseSpeechTimer
    repeat: false
    running: false
    onTriggered: root.hideSpeech()
  }

  // -------------------------------------------------------------
  // Hardened Config Persistence & Schema Validation
  // -------------------------------------------------------------
  Process {
    id: ensureStateDirProc
    command: ["bash", "-c", "mkdir -p -m 0700 \"$1\" && if [[ -L \"$2\" ]]; then rm -f \"$2\"; fi && if [[ -f \"$2\" ]]; then chmod 0600 \"$2\"; fi", "--", root.stateDir, root.stateFilePath]
  }

  function parseAndValidateConfig(raw) {
    if (!raw || typeof raw !== "string" || raw.length > 16384) return null
    try {
      var cfg = JSON.parse(raw)
      if (!cfg || typeof cfg !== "object" || Array.isArray(cfg)) return null
      var out = {}
      if (typeof cfg.enabled === "boolean") out.enabled = cfg.enabled
      if (["companion", "roam", "perch"].indexOf(cfg.mode) !== -1) out.mode = cfg.mode
      if (["small", "normal", "large", "giant"].indexOf(cfg.scale) !== -1) out.scale = cfg.scale
      if (typeof cfg.soundEnabled === "boolean") out.soundEnabled = cfg.soundEnabled
      if (typeof cfg.soundVolume === "number" && isFinite(cfg.soundVolume)) {
        out.soundVolume = Math.max(0.0, Math.min(1.0, cfg.soundVolume))
      }
      if (["calm", "normal", "frequent"].indexOf(cfg.idleFrequency) !== -1) out.idleFrequency = cfg.idleFrequency
      if (typeof cfg.speechBubbles === "boolean") out.speechBubbles = cfg.speechBubbles
      if (["classic", "glass", "terminal"].indexOf(cfg.balloonSkin) !== -1) out.balloonSkin = cfg.balloonSkin
      if (typeof cfg.reactToCursor === "boolean") out.reactToCursor = cfg.reactToCursor
      if (typeof cfg.reactToWindows === "boolean") out.reactToWindows = cfg.reactToWindows
      if (typeof cfg.reactToAgents === "boolean") out.reactToAgents = cfg.reactToAgents
      if (typeof cfg.reactToSystem === "boolean") out.reactToSystem = cfg.reactToSystem
      if (typeof cfg.rawInputTracking === "boolean") out.rawInputTracking = cfg.rawInputTracking
      if (typeof cfg.posX === "number" && isFinite(cfg.posX)) out.posX = Math.max(0, Math.min(32767, Math.round(cfg.posX)))
      if (typeof cfg.posY === "number" && isFinite(cfg.posY)) out.posY = Math.max(0, Math.min(32767, Math.round(cfg.posY)))
      return out
    } catch (e) {
      return null
    }
  }

  FileView {
    id: configFile
    path: root.stateFilePath
    watchChanges: true
    atomicWrites: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: {
      var cfg = root.parseAndValidateConfig(text())
      if (cfg) {
        if (cfg.enabled !== undefined) root.clippyEnabled = cfg.enabled
        if (cfg.mode !== undefined) root.clippyMode = cfg.mode
        if (cfg.scale !== undefined) root.clippyScale = cfg.scale
        if (cfg.soundEnabled !== undefined) root.soundEnabled = cfg.soundEnabled
        if (cfg.soundVolume !== undefined) root.soundVolume = cfg.soundVolume
        if (cfg.idleFrequency !== undefined) root.idleFrequency = cfg.idleFrequency
        if (cfg.speechBubbles !== undefined) root.speechBubbles = cfg.speechBubbles
        if (cfg.balloonSkin !== undefined) root.balloonSkin = cfg.balloonSkin
        if (cfg.reactToCursor !== undefined) root.reactToCursor = cfg.reactToCursor
        if (cfg.reactToWindows !== undefined) root.reactToWindows = cfg.reactToWindows
        if (cfg.reactToAgents !== undefined) root.reactToAgents = cfg.reactToAgents
        if (cfg.reactToSystem !== undefined) root.reactToSystem = cfg.reactToSystem
        if (cfg.rawInputTracking !== undefined) root.rawInputTracking = cfg.rawInputTracking
        if (cfg.posX !== undefined && !root.isDragging) root.posX = cfg.posX
        if (cfg.posY !== undefined && !root.isDragging) root.posY = cfg.posY
      }
    }
  }

  function saveConfig() {
    try {
      var cfg = {
        enabled: Boolean(root.clippyEnabled),
        mode: String(root.clippyMode),
        scale: String(root.clippyScale),
        soundEnabled: Boolean(root.soundEnabled),
        soundVolume: Number(Math.max(0, Math.min(1, root.soundVolume))),
        idleFrequency: String(root.idleFrequency),
        speechBubbles: Boolean(root.speechBubbles),
        balloonSkin: String(root.balloonSkin),
        reactToCursor: Boolean(root.reactToCursor),
        reactToWindows: Boolean(root.reactToWindows),
        reactToAgents: Boolean(root.reactToAgents),
        reactToSystem: Boolean(root.reactToSystem),
        rawInputTracking: Boolean(root.rawInputTracking),
        posX: Math.round(root.posX),
        posY: Math.round(root.posY)
      }
      configFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    } catch (e) {}
  }

  // Handle Idle Animation Timer
  Timer {
    id: idleTimer
    interval: {
      switch (root.idleFrequency) {
        case "calm": return 22000 + Math.random() * 18000;
        case "frequent": return 6000 + Math.random() * 6000;
        case "normal":
        default: return 12000 + Math.random() * 10000;
      }
    }
    running: root.clippyEnabled && !root.isDragging && !root.promptActive
    repeat: true
    onTriggered: {
      if (root.clippyMode === "roam" && Math.random() < 0.45) {
        pickRoamTarget()
      } else {
        root.playRandomIdle()
      }
    }
  }

  // -------------------------------------------------------------
  // Window Magnetism, Edge Snapping & Spring Physics
  // -------------------------------------------------------------
  function snapToMagneticTargets() {
    var finalX = root.posX
    var finalY = root.posY

    // Screen Edge Snapping (within 28px)
    if (finalX < 28) finalX = 12
    else if (finalX > root.width - root.clippyWidth - 28) finalX = root.width - root.clippyWidth - 12

    if (finalY < 28) finalY = 12
    else if (finalY > root.height - root.clippyHeight - 28) finalY = root.height - root.clippyHeight - 12

    // Window Top/Titlebar Snapping (if window nearby)
    if (root.lastWindowRect && (root.clippyMode === "perch" || root.clippyMode === "companion")) {
      var w = root.lastWindowRect
      var winSnapX = w.x + w.width - root.clippyWidth - 20
      var winSnapY = Math.max(10, w.y - root.clippyHeight + 10)

      if (Math.hypot(finalX - winSnapX, finalY - winSnapY) < 70) {
        finalX = winSnapX
        finalY = winSnapY
      }
    }

    if (finalX !== root.posX || finalY !== root.posY) {
      springMoveX.to = finalX
      springMoveY.to = finalY
      springMoveAnim.restart()
    } else {
      root.saveConfig()
    }
  }

  ParallelAnimation {
    id: springMoveAnim
    NumberAnimation {
      id: springMoveX
      target: root
      property: "posX"
      duration: 380
      easing.type: Easing.OutBack
    }
    NumberAnimation {
      id: springMoveY
      target: root
      property: "posY"
      duration: 380
      easing.type: Easing.OutBack
    }
    onFinished: root.saveConfig()
  }

  function pickRoamTarget() {
    var margin = 60
    var maxX = root.width - root.clippyWidth - margin
    var maxY = root.height - root.clippyHeight - margin
    var minX = margin
    var minY = margin

    root.targetPosX = minX + Math.random() * Math.max(10, maxX - minX)
    root.targetPosY = minY + Math.random() * Math.max(10, maxY - minY)
    root.isMoving = true
    moveAnimX.to = root.targetPosX
    moveAnimY.to = root.targetPosY
    moveAnim.restart()
  }

  ParallelAnimation {
    id: moveAnim
    NumberAnimation {
      id: moveAnimX
      target: root
      property: "posX"
      duration: 2500
      easing.type: Easing.InOutQuad
    }
    NumberAnimation {
      id: moveAnimY
      target: root
      property: "posY"
      duration: 2500
      easing.type: Easing.InOutQuad
    }
    onFinished: {
      root.isMoving = false
      root.saveConfig()
    }
  }

  property string lastLookDirection: ""

  function updatePointer(x, y) {
    if (!isFinite(x) || !isFinite(y)) return
    root.pointerX = x
    root.pointerY = y

    if (!root.reactToCursor || !root.clippyEnabled || root.isDragging || root.isCustomPlaying || root.promptActive) return

    var centerX = root.posX + root.clippyWidth / 2
    var centerY = root.posY + root.clippyHeight / 2
    var dx = x - centerX
    var dy = y - centerY
    var dist = Math.hypot(dx, dy)

    // Ignore if cursor is beyond 950px
    if (dist > 950) return

    // Determine target look direction from angle (adjusted for sprite screen perspective)
    var targetAnim = "RestPose"
    if (dist >= 30) {
      if (Math.abs(dx) > Math.abs(dy) * 1.8) {
        targetAnim = dx < 0 ? "LookRight" : "LookLeft"
      } else if (Math.abs(dy) > Math.abs(dx) * 1.8) {
        targetAnim = dy < 0 ? "LookUp" : "LookDown"
      } else {
        if (dx < 0 && dy < 0) targetAnim = "LookUpRight"
        else if (dx > 0 && dy < 0) targetAnim = "LookUpLeft"
        else if (dx < 0 && dy > 0) targetAnim = "LookDownRight"
        else targetAnim = "LookDownLeft"
      }
    }

    var now = Date.now()
    // Trigger glance when direction changes or after 1.5s of continuous focus
    if (targetAnim !== "RestPose" && (targetAnim !== root.lastLookDirection || now - root.lastCursorLookTime > 1500)) {
      root.lastLookDirection = targetAnim
      root.lastCursorLookTime = now
      root.playAnimation(targetAnim)
    }
  }

  function onWindowMoved(rect) {
    if (!rect || !isFinite(rect.x) || !isFinite(rect.y) || !isFinite(rect.width) || !isFinite(rect.height)) return
    root.lastWindowRect = rect
    if (!root.reactToWindows || !root.clippyEnabled || root.isDragging) return
    if (root.clippyMode === "perch") {
      var targetX = rect.x + Math.max(10, rect.width - root.clippyWidth - 30)
      var targetY = Math.max(20, rect.y - root.clippyHeight + 10)
      root.targetPosX = Math.max(10, Math.min(root.width - root.clippyWidth - 10, targetX))
      root.targetPosY = Math.max(20, Math.min(root.height - root.clippyHeight - 10, targetY))
      moveAnimX.to = root.targetPosX
      moveAnimY.to = root.targetPosY
      moveAnim.restart()
    }
  }

  function onScreenClick(btn, clickX, clickY) {
    if (!root.rawInputTracking || !root.reactToCursor || !root.clippyEnabled || root.isDragging || root.isCustomPlaying || root.promptActive) return
    if (!isFinite(clickX) || !isFinite(clickY)) return
    var dx = clickX - (root.posX + root.clippyWidth / 2)
    var dy = clickY - (root.posY + root.clippyHeight / 2)
    if (Math.hypot(dx, dy) < 180 && Math.random() < 0.25) {
      root.playAnimation("Alert")
    }
  }

  // -------------------------------------------------------------
  // Background Tracker Process (Bounded SplitParser & Validated Absolute Path)
  // -------------------------------------------------------------
  Process {
    id: trackerProc
    command: [root.pythonBin, root.dirFs + "tracker.py"].concat(root.rawInputTracking ? ["--enable-raw-input"] : [])
    running: root.clippyEnabled

    stdout: SplitParser {
      onRead: function(line) {
        var raw = String(line || "").trim()
        if (raw.length === 0 || raw.length > 4096 || !raw.startsWith("{")) return
        try {
          var data = JSON.parse(raw)
          if (!data || typeof data !== "object") return

          if (data.cursor && isFinite(data.cursor.x) && isFinite(data.cursor.y)) {
            root.updatePointer(data.cursor.x, data.cursor.y)
          }
          if (data.window_moved && data.rect) {
            root.onWindowMoved(data.rect)
          }
          if (data.click && typeof data.btn === "string" && isFinite(data.x) && isFinite(data.y)) {
            root.onScreenClick(data.btn, data.x, data.y)
          }
          if (data.agent_event && root.reactToAgents && root.clippyEnabled) {
            var msg = String(data.message || "").substring(0, 300)
            if (data.agent_event === "blocked") {
              root.playAnimation("Alert")
              root.speak(msg || "Agent needs attention!", 6000)
            } else if (data.agent_event === "done") {
              root.playAnimation("Congratulate")
              root.speak(msg || "Agent finished successfully!", 6000)
            } else if (data.agent_event === "working") {
              root.playAnimation("GetTechy")
            }
          }
          if (data.system_event && root.reactToSystem && root.clippyEnabled) {
            var sysMsg = String(data.message || "").substring(0, 300)
            if (data.system_event === "low_battery") {
              root.playAnimation("Alert")
              root.speak(sysMsg || "Low battery!", 6000)
            } else if (data.system_event === "charger_connected") {
              root.playAnimation("Congratulate")
              root.speak(sysMsg || "Charger connected!", 4000)
            } else if (data.system_event === "idle_sleep") {
              root.playAnimation("IdleSnooze")
            } else if (data.system_event === "user_wake") {
              root.playAnimation("Greeting")
            }
          }
        } catch (e) {}
      }
    }

    onExited: function(exitCode, exitStatus) {
      if (root.clippyEnabled) trackerRestartTimer.restart()
    }
  }

  Timer {
    id: trackerRestartTimer
    interval: 2000
    repeat: false
    onTriggered: {
      if (root.clippyEnabled && !trackerProc.running) trackerProc.running = true
    }
  }

  // -------------------------------------------------------------
  // Public IPC Handler (Strict Input Bounding)
  // -------------------------------------------------------------
  IpcHandler {
    target: "dorneles.omaclippy"

    function toggle(): string {
      root.clippyEnabled = !root.clippyEnabled
      root.saveConfig()
      return root.clippyEnabled ? "on" : "off"
    }

    function on(): string {
      root.clippyEnabled = true
      root.saveConfig()
      return "ok"
    }

    function off(): string {
      root.clippyEnabled = false
      root.saveConfig()
      return "ok"
    }

    function play(animName: string): string {
      var clean = String(animName || "").trim().substring(0, 40)
      if (!clean || clean === "random") {
        root.playRandomAction()
        return "playing random"
      }
      root.playAnimation(clean)
      return "playing " + clean
    }

    function react(animName: string, msg: string): string {
      var cleanAnim = String(animName || "Explain").trim().substring(0, 40)
      var cleanMsg = String(msg || "").substring(0, 500)
      root.playAnimation(cleanAnim || "Explain")
      if (cleanMsg.trim().length > 0) {
        root.speechFullText = cleanMsg
        root.speechDisplayedText = ""
        root.speechVisible = true
        root.speechTypewriterIdx = 0
        typewriterTimer.restart()
        var autoDuration = Math.min(30000, Math.max(500, cleanMsg.length * 90))
        autoCloseSpeechTimer.interval = autoDuration
        autoCloseSpeechTimer.restart()
      }
      return "reacting"
    }

    function speak(msg: string): string {
      root.speak(String(msg || "Hello!").substring(0, 500))
      return "speaking"
    }

    function prompt(): string {
      root.openPrompt()
      return "prompt opened"
    }

    function tip(): string {
      root.showRandomTip()
      return "tip shown"
    }

    function hide(): string {
      root.hideSpeech()
      return "hidden"
    }

    function hideSpeech(): string {
      root.hideSpeech()
      return "hidden"
    }

    function setMode(val: string): string {
      if (["companion", "roam", "perch"].indexOf(val) !== -1) {
        root.clippyMode = val
        root.saveConfig()
        return "ok"
      }
      return "invalid mode"
    }

    function setScale(val: string): string {
      if (["small", "normal", "large", "giant"].indexOf(val) !== -1) {
        root.clippyScale = val
        root.saveConfig()
        return "ok"
      }
      return "invalid scale"
    }

    function setSound(val: string): string {
      root.soundEnabled = (val === "true" || val === "1" || val === "on")
      root.saveConfig()
      return "ok"
    }

    function setVolume(val: string): string {
      var v = parseFloat(val)
      if (!isNaN(v) && isFinite(v) && v >= 0 && v <= 1.0) {
        root.soundVolume = v
        root.saveConfig()
        return "ok"
      }
      return "invalid volume"
    }

    function setSkin(val: string): string {
      if (["classic", "glass", "terminal"].indexOf(val) !== -1) {
        root.balloonSkin = val
        root.saveConfig()
        return "ok"
      }
      return "invalid skin"
    }

    function setRawInput(val: string): string {
      root.rawInputTracking = (val === "true" || val === "1" || val === "on")
      root.saveConfig()
      if (trackerProc.running) {
        trackerProc.running = false
        trackerRestartTimer.restart()
      }
      return "ok"
    }

    function resetPosition(): string {
      root.posX = root.width - root.clippyWidth - 80
      root.posY = root.height - root.clippyHeight - 120
      root.saveConfig()
      return "ok"
    }

    function status(): string {
      return JSON.stringify({
        enabled: root.clippyEnabled,
        mode: root.clippyMode,
        scale: root.clippyScale,
        soundEnabled: root.soundEnabled,
        soundVolume: root.soundVolume,
        rawInputTracking: root.rawInputTracking,
        currentAnim: root.currentAnim,
        currentFrameIdx: root.currentFrameIdx,
        frameCoords: [root.currentFrameX, root.currentFrameY],
        isCustomPlaying: root.isCustomPlaying,
        pos: [Math.round(root.posX), Math.round(root.posY)],
        speechVisible: root.speechVisible,
        promptActive: root.promptActive
      })
    }
  }

  // -------------------------------------------------------------
  // Visual Item Hierarchy
  // -------------------------------------------------------------
  Item {
    id: companionArea
    visible: root.clippyEnabled
    x: Math.max(0, Math.min(root.width - root.areaWidth, root.areaX))
    y: Math.max(0, Math.min(root.height - root.areaHeight, root.areaY))
    width: root.areaWidth
    height: root.areaHeight

    // Speech Bubble positioned relative to companionArea
    SpeechBubble {
      id: bubbleItem
      clippyScale: root.scaleFactor
      skin: root.balloonSkin
      fullText: root.speechFullText
      displayedText: root.speechDisplayedText
      active: root.speechVisible
      placeBelow: root.showSpeechBelow
      placeLeft: root.showSpeechLeft
      isPromptMode: root.promptActive
      actionButtons: root.currentActionButtons

      x: root.showSpeechLeft
         ? 0
         : (parent.width - width)
      y: root.showSpeechBelow
         ? (root.clippyHeight + 8)
         : 0

      onDismissed: root.hideSpeech()
      onPromptSubmitted: function(promptText) {
        root.sendToNativeAgent(promptText)
      }
    }

    // Clippy Body Container & Interaction
    Item {
      id: clippyContainer
      x: root.showSpeechLeft
         ? 0
         : (parent.width - root.clippyWidth)
      y: (root.speechActive && !root.showSpeechBelow)
         ? (root.bubbleH + 8)
         : 0
      width: root.clippyWidth
      height: root.clippyHeight

      // Clippy Sprite rendering current frame
      Item {
        anchors.fill: parent
        clip: true

        Image {
          id: spriteMap
          source: Qt.resolvedUrl("assets/map.png")
          x: -Math.round(root.currentFrameX * root.scaleFactor)
          y: -Math.round(root.currentFrameY * root.scaleFactor)
          width: Math.round(3348 * root.scaleFactor)
          height: Math.round(3162 * root.scaleFactor)
          smooth: true
          mipmap: true
          fillMode: Image.Stretch
        }
      }

      // Drag, Click, & Double-Click Interaction Area
      MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        property real grabDx: 0
        property real grabDy: 0
        property real pressGlobalX: 0
        property real pressGlobalY: 0
        property bool dragging: false

        onPressed: function(mouse) {
          var p = mapToItem(root.contentItem, mouse.x, mouse.y)
          pressGlobalX = p.x
          pressGlobalY = p.y
          grabDx = p.x - root.posX
          grabDy = p.y - root.posY
          dragging = false
        }

        onPositionChanged: function(mouse) {
          if (!pressed || mouse.buttons !== Qt.LeftButton) return
          var p = mapToItem(root.contentItem, mouse.x, mouse.y)
          if (!dragging) {
            if (Math.abs(p.x - pressGlobalX) > 6 && Math.abs(p.y - pressGlobalY) > 6) {
              dragging = true
              root.isDragging = true
              root.hideSpeech()
            }
          }
          root.posX = Math.max(0, Math.min(root.width - root.clippyWidth, p.x - grabDx))
          root.posY = Math.max(0, Math.min(root.height - root.clippyHeight, p.y - grabDy))
        }

        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.LeftButton) {
            root.openPrompt()
          }
        }

        onReleased: function(mouse) {
          if (dragging) {
            dragging = false
            root.isDragging = false
            root.snapToMagneticTargets()
          } else {
            if (mouse.button === Qt.RightButton) {
              root.showRandomTip()
            } else {
              root.playRandomAction()
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    ensureStateDirProc.running = true
    if (root.posX === 350 && root.posY === 350) {
      var w = root.width > 0 ? root.width : 1920
      var h = root.height > 0 ? root.height : 1080
      root.posX = w - root.clippyWidth - 90
      root.posY = h - root.clippyHeight - 130
    }
    root.applyFrame(0)
    Qt.callLater(function() {
      root.playAnimation("Greeting")
    })
  }
}
