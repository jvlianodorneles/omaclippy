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
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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
  property bool reactToCursor: true
  property bool reactToWindows: true
  property bool reactToAgents: true

  // State Persistence
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omaclippy"
  readonly property string stateFilePath: stateDir + "/config.json"
  readonly property string dirFs: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property string soundsDir: Qt.resolvedUrl("assets/sounds/").toString().replace("file://", "")

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
  // Position & Movement State
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

  // Dynamic Bounding Geometry for Companion Area
  readonly property real bubbleW: bubbleItem.width
  readonly property real bubbleH: bubbleItem.height

  readonly property real areaX: root.speechVisible
    ? (root.showSpeechLeft ? root.posX : (root.posX - Math.max(0, root.bubbleW - root.clippyWidth)))
    : root.posX

  readonly property real areaY: root.speechVisible
    ? (root.showSpeechBelow ? root.posY : (root.posY - root.bubbleH - 8))
    : root.posY

  readonly property real areaWidth: root.speechVisible
    ? Math.max(root.clippyWidth, root.bubbleW)
    : root.clippyWidth

  readonly property real areaHeight: root.speechVisible
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
  // Centralized Speech Bubble State
  // -------------------------------------------------------------
  property string speechFullText: ""
  property string speechDisplayedText: ""
  property bool speechVisible: false
  property int speechTypewriterIdx: 0

  function playSound(soundId) {
    if (!root.soundEnabled || root.soundVolume <= 0 || !soundId) return
    var safeSoundId = String(soundId).trim()
    if (!/^[a-zA-Z0-9_-]+$/.test(safeSoundId)) return
    var filePath = root.soundsDir + safeSoundId + ".mp3"
    Quickshell.execDetached(["pw-play", "--volume", root.soundVolume.toFixed(2), filePath])
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
      // If loop limit hasn't been exceeded, allow branching
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
        // Loop limit reached: force forward progression or exitBranch
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

  // Safety timer to prevent any unexpected hang
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
    var anim = AnimData.getAnimation(animName)
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
    root.isCustomPlaying = (animName !== "RestPose")
    root.currentAnim = animName
    root.currentAnimObj = anim
    root.currentFrameIdx = 0
    root.applyFrame(0)

    if (animName !== "RestPose") {
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
  // Speech Functions
  // -------------------------------------------------------------
  function speak(text, durationMs) {
    if (!root.clippyEnabled || !root.speechBubbles) return
    root.speechFullText = text
    root.speechDisplayedText = ""
    root.speechVisible = true
    root.speechTypewriterIdx = 0
    typewriterTimer.restart()

    var autoDuration = durationMs || Math.max(5000, text.length * 90)
    autoCloseSpeechTimer.interval = autoDuration
    autoCloseSpeechTimer.restart()

    if (!root.isCustomPlaying) {
      root.playAnimation("Explain")
    }
  }

  function hideSpeech() {
    root.speechVisible = false
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
  // Config Persistence
  // -------------------------------------------------------------
  FileView {
    id: configFile
    path: root.stateFilePath
    watchChanges: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: {
      try {
        var raw = text()
        if (raw && raw.trim().length > 0) {
          var cfg = JSON.parse(raw)
          if (cfg) {
            if (cfg.enabled !== undefined) root.clippyEnabled = Boolean(cfg.enabled)
            if (cfg.mode !== undefined) root.clippyMode = String(cfg.mode)
            if (cfg.scale !== undefined) root.clippyScale = String(cfg.scale)
            if (cfg.soundEnabled !== undefined) root.soundEnabled = Boolean(cfg.soundEnabled)
            if (cfg.soundVolume !== undefined) root.soundVolume = Number(cfg.soundVolume)
            if (cfg.idleFrequency !== undefined) root.idleFrequency = String(cfg.idleFrequency)
            if (cfg.speechBubbles !== undefined) root.speechBubbles = Boolean(cfg.speechBubbles)
            if (cfg.reactToCursor !== undefined) root.reactToCursor = Boolean(cfg.reactToCursor)
            if (cfg.reactToWindows !== undefined) root.reactToWindows = Boolean(cfg.reactToWindows)
            if (cfg.reactToAgents !== undefined) root.reactToAgents = Boolean(cfg.reactToAgents)
            if (cfg.posX !== undefined && !root.isDragging) root.posX = Number(cfg.posX)
            if (cfg.posY !== undefined && !root.isDragging) root.posY = Number(cfg.posY)
          }
        }
      } catch (e) {}
    }
  }

  function saveConfig() {
    try {
      var cfg = {
        enabled: root.clippyEnabled,
        mode: root.clippyMode,
        scale: root.clippyScale,
        soundEnabled: root.soundEnabled,
        soundVolume: root.soundVolume,
        idleFrequency: root.idleFrequency,
        speechBubbles: root.speechBubbles,
        reactToCursor: root.reactToCursor,
        reactToWindows: root.reactToWindows,
        reactToAgents: root.reactToAgents,
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
    running: root.clippyEnabled && !root.isDragging
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
  // Roaming & Movement Physics
  // -------------------------------------------------------------
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

  // -------------------------------------------------------------
  // Cursor Interaction & Look Directions
  // -------------------------------------------------------------
  function updatePointer(x, y) {
    root.pointerX = x
    root.pointerY = y

    if (!root.reactToCursor || !root.clippyEnabled || root.isDragging || root.isCustomPlaying) return

    var now = Date.now()
    if (now - root.lastCursorLookTime < 4500) return

    var centerX = root.posX + root.clippyWidth / 2
    var centerY = root.posY + root.clippyHeight / 2
    var dx = x - centerX
    var dy = y - centerY
    var dist = Math.hypot(dx, dy)

    if (dist > 80 && dist < 700 && Math.random() < 0.14) {
      root.lastCursorLookTime = now
      var lookAnim = "RestPose"
      if (Math.abs(dx) > Math.abs(dy) * 1.5) {
        lookAnim = dx < 0 ? "LookLeft" : "LookRight"
      } else if (Math.abs(dy) > Math.abs(dx) * 1.5) {
        lookAnim = dy < 0 ? "LookUp" : "LookDown"
      } else {
        if (dx < 0 && dy < 0) lookAnim = "LookUpLeft"
        else if (dx > 0 && dy < 0) lookAnim = "LookUpRight"
        else if (dx < 0 && dy > 0) lookAnim = "LookDownLeft"
        else lookAnim = "LookDownRight"
      }
      root.playAnimation(lookAnim)
    }
  }

  function onWindowMoved(rect) {
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
    if (!root.reactToCursor || !root.clippyEnabled || root.isDragging || root.isCustomPlaying) return
    var dx = clickX - (root.posX + root.clippyWidth / 2)
    var dy = clickY - (root.posY + root.clippyHeight / 2)
    if (Math.hypot(dx, dy) < 180 && Math.random() < 0.25) {
      root.playAnimation("Alert")
    }
  }

  // -------------------------------------------------------------
  // Background Tracker Process
  // -------------------------------------------------------------
  Process {
    id: trackerProc
    command: ["python3", root.dirFs + "tracker.py"]
    running: root.clippyEnabled

    stdout: SplitParser {
      onRead: function(line) {
        var raw = String(line || "").trim()
        if (!raw.startsWith("{")) return
        try {
          var data = JSON.parse(raw)
          if (data.cursor) {
            root.updatePointer(data.cursor.x, data.cursor.y)
          }
          if (data.window_moved && data.rect) {
            root.onWindowMoved(data.rect)
          }
          if (data.click) {
            root.onScreenClick(data.btn, data.x, data.y)
          }
          if (data.agent_event && root.reactToAgents && root.clippyEnabled) {
            if (data.agent_event === "blocked") {
              root.playAnimation("Alert")
              root.speak(data.message || "Agent needs attention!")
            } else if (data.agent_event === "done") {
              root.playAnimation("Congratulate")
              root.speak(data.message || "Agent finished successfully!")
            } else if (data.agent_event === "working") {
              root.playAnimation("GetTechy")
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
  // Public IPC Handler
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
      if (!animName || animName === "random") {
        root.playRandomAction()
        return "playing random"
      }
      root.playAnimation(animName)
      return "playing " + animName
    }

    function react(animName: string, msg: string): string {
      root.playAnimation(animName || "Explain")
      if (msg && String(msg).trim().length > 0) {
        root.speechFullText = String(msg)
        root.speechDisplayedText = ""
        root.speechVisible = true
        root.speechTypewriterIdx = 0
        typewriterTimer.restart()
        var autoDuration = Math.max(5000, msg.length * 90)
        autoCloseSpeechTimer.interval = autoDuration
        autoCloseSpeechTimer.restart()
      }
      return "reacting"
    }

    function speak(msg: string): string {
      root.speak(msg || "Hello!")
      return "speaking"
    }

    function tip(): string {
      root.showRandomTip()
      return "tip shown"
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
      if (!isNaN(v) && v >= 0 && v <= 1.0) {
        root.soundVolume = v
        root.saveConfig()
        return "ok"
      }
      return "invalid volume"
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
        currentAnim: root.currentAnim,
        pos: [Math.round(root.posX), Math.round(root.posY)],
        speechVisible: root.speechVisible
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
      fullText: root.speechFullText
      displayedText: root.speechDisplayedText
      active: root.speechVisible
      placeBelow: root.showSpeechBelow
      placeLeft: root.showSpeechLeft

      x: root.showSpeechLeft
         ? 0
         : (parent.width - width)
      y: root.showSpeechBelow
         ? (root.clippyHeight + 8)
         : 0

      onDismissed: root.hideSpeech()
    }

    // Clippy Body Container & Interaction
    Item {
      id: clippyContainer
      x: root.showSpeechLeft
         ? 0
         : (parent.width - root.clippyWidth)
      y: (root.speechVisible && !root.showSpeechBelow)
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

      // Drag & Click Interaction Area
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

        onReleased: function(mouse) {
          if (dragging) {
            dragging = false
            root.isDragging = false
            root.saveConfig()
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
