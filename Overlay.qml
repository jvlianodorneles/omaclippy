import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import "Animations.js" as AnimData

Item {
  id: root

  // -------------------------------------------------------------
  // Settings & Configuration
  // -------------------------------------------------------------
  property bool clippyEnabled: true
  property string clippyMode: "companion" // "companion" | "roam" | "follow_cursor"
  property string clippyScale: "normal"  // "small" | "normal" | "large" | "giant"
  property bool soundEnabled: true
  property real soundVolume: 0.5
  property string idleFrequency: "normal" // "calm" | "normal" | "frequent"
  property bool speechBubbles: true
  property bool reactToCursor: true
  property bool reactToWindows: true

  // State Persistence
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omaclippy"
  readonly property string stateFilePath: stateDir + "/config.json"
  readonly property string dirFs: Qt.resolvedUrl(".").toString().replace("file://", "")

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

  property string currentAnim: "RestPose"
  property bool isCustomPlaying: false

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
        posX: Math.round(root.posX),
        posY: Math.round(root.posY)
      }
      configFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    } catch (e) {}
  }

  // -------------------------------------------------------------
  // Animation & Speech Control
  // -------------------------------------------------------------
  function playAnimation(animName) {
    root.isCustomPlaying = true
    root.currentAnim = animName
    clippySprite.play(animName, false)
  }

  function playRandomAction() {
    var anim = AnimData.getRandomActionAnimation()
    playAnimation(anim)
  }

  function playRandomIdle() {
    if (root.isCustomPlaying || root.isDragging) return
    var anim = AnimData.getRandomIdleAnimation()
    root.currentAnim = anim
    clippySprite.play(anim, false)
  }

  function speak(text, durationMs) {
    if (!root.clippyEnabled || !root.speechBubbles) return
    speechBubble.speak(text, durationMs)
    if (!root.isCustomPlaying) {
      playAnimation("Explain")
    }
  }

  function showRandomTip() {
    var tip = AnimData.getRandomTip()
    speak(tip)
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
    var screens = Quickshell.screens
    if (!screens || screens.length === 0) return
    var sc = screens[0]
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (root.posX >= s.x && root.posX <= s.x + s.width) { sc = s; break }
    }

    var margin = 60
    var maxX = sc.x + sc.width - root.clippyWidth - margin
    var maxY = sc.y + sc.height - root.clippyHeight - margin
    var minX = sc.x + margin
    var minY = sc.y + margin

    root.targetPosX = minX + Math.random() * (maxX - minX)
    root.targetPosY = minY + Math.random() * (maxY - minY)
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

    if (dist > 80 && dist < 700 && Math.random() < 0.12) {
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
      playAnimation(lookAnim)
    }
  }

  function onWindowMoved(rect) {
    if (!root.reactToWindows || !root.clippyEnabled || root.isDragging) return
    if (root.clippyMode === "perch") {
      root.targetPosX = rect.x + Math.max(20, rect.width - root.clippyWidth - 40)
      root.targetPosY = Math.max(30, rect.y - root.clippyHeight + 10)
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
      playAnimation("Alert")
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

    function speak(msg: string): string {
      root.speak(msg || "Hello!")
      return "speaking"
    }

    function tip(): string {
      root.showRandomTip()
      return "tip shown"
    }

    function setMode(val: string): string {
      if (["companion", "roam", "follow_cursor", "perch"].indexOf(val) !== -1) {
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
      var screens = Quickshell.screens
      if (screens && screens.length > 0) {
        var sc = screens[0]
        root.posX = sc.x + sc.width - root.clippyWidth - 80
        root.posY = sc.y + sc.height - root.clippyHeight - 120
        root.saveConfig()
      }
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
        speechVisible: speechBubble.active
      })
    }
  }

  // -------------------------------------------------------------
  // Desktop Layer-Shell Overlay Windows (Per Screen)
  // -------------------------------------------------------------
  Variants {
    model: Quickshell.screens

    Scope {
      id: screenScope
      required property var modelData

      readonly property real localX: root.posX - modelData.x
      readonly property real localY: root.posY - modelData.y

      readonly property bool onThisScreen: root.clippyEnabled &&
        (root.posX + root.clippyWidth >= modelData.x) &&
        (root.posX <= modelData.x + modelData.width) &&
        (root.posY + root.clippyHeight >= modelData.y) &&
        (root.posY <= modelData.y + modelData.height)

      PanelWindow {
        id: win
        screen: screenScope.modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.namespace: "omaclippy"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Mask covers only Clippy and Speech Bubble for click/drag interactivity,
        // leaving the entire desktop 100% click-through!
        mask: Region {
          item: screenScope.onThisScreen ? clippyWrapper : null
        }

        Item {
          anchors.fill: parent

          Item {
            id: clippyWrapper
            visible: screenScope.onThisScreen
            x: screenScope.localX
            y: screenScope.localY
            width: root.clippyWidth
            height: root.clippyHeight

            // Speech Bubble floating above Clippy
            SpeechBubble {
              id: speechBubble
              clippyScale: root.scaleFactor
              anchors.bottom: clippyContainer.top
              anchors.bottomMargin: 8
              anchors.right: clippyContainer.right
              anchors.rightMargin: 10
            }

            // Clippy Body Container & Interaction
            Item {
              id: clippyContainer
              anchors.fill: parent

              ClippySprite {
                id: clippySprite
                anchors.centerIn: parent
                scaleFactor: root.scaleFactor
                soundEnabled: root.soundEnabled
                soundVolume: root.soundVolume

                onAnimationFinished: function(animName) {
                  root.isCustomPlaying = false
                  root.currentAnim = "RestPose"
                  clippySprite.play("RestPose", true)
                }
              }

              // Drag & Click Interaction Area
              MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                property real pressGlobalX: 0
                property real pressGlobalY: 0
                property real grabDx: 0
                property real grabDy: 0

                onPressed: function(mouse) {
                  var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                  pressGlobalX = p.x
                  pressGlobalY = p.y
                  grabDx = p.x - screenScope.localX
                  grabDy = p.y - screenScope.localY
                }

                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  var p = mapToItem(win.contentItem, mouse.x, mouse.y)
                  if (!root.isDragging) {
                    if (Math.abs(p.x - pressGlobalX) > 6 || Math.abs(p.y - pressGlobalY) > 6) {
                      root.isDragging = true
                      speechBubble.hide()
                    }
                  }
                  if (root.isDragging) {
                    root.posX = screenScope.modelData.x + (p.x - grabDx)
                    root.posY = screenScope.modelData.y + (p.y - grabDy)
                  }
                }

                onReleased: function(mouse) {
                  if (root.isDragging) {
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
        }
      }
    }
  }

  Component.onCompleted: {
    var screens = Quickshell.screens
    if (screens && screens.length > 0) {
      var sc = screens[0]
      if (root.posX === 350 && root.posY === 350) {
        root.posX = sc.x + sc.width - root.clippyWidth - 90
        root.posY = sc.y + sc.height - root.clippyHeight - 130
      }
    }
    // Greet user on first load
    Qt.callLater(function() {
      root.playAnimation("Greeting")
    })
  }
}
