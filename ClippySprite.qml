import QtQuick
import Quickshell
import "Animations.js" as AnimData

Item {
  id: root

  // -------------------------------------------------------------
  // Public Properties
  // -------------------------------------------------------------
  property string currentAnimation: "RestPose"
  property real scaleFactor: 1.0
  property bool soundEnabled: true
  property real soundVolume: 0.5
  property bool loop: false
  property bool playing: true

  // Current frame coordinates
  property real frameX: 0
  property real frameY: 0
  property int currentFrameIndex: 0

  readonly property real baseWidth: 124
  readonly property real baseHeight: 93
  readonly property string pwPlayBin: "/usr/bin/pw-play"

  implicitWidth: Math.round(baseWidth * scaleFactor)
  implicitHeight: Math.round(baseHeight * scaleFactor)
  clip: true

  signal animationFinished(string name)
  signal frameChanged(int index, string soundId)

  // -------------------------------------------------------------
  // Animation Control
  // -------------------------------------------------------------
  property var animObject: AnimData.getAnimation(currentAnimation)
  readonly property string soundsDir: Qt.resolvedUrl("assets/sounds/").toString().replace("file://", "")

  function play(animName, shouldLoop) {
    var safeName = String(animName || "").trim().substring(0, 40)
    var anim = AnimData.getAnimation(safeName)
    if (!anim || !anim.frames || anim.frames.length === 0) {
      currentAnimation = "RestPose"
      animObject = AnimData.getAnimation("RestPose")
      currentFrameIndex = 0
      applyFrame(0)
      return
    }

    currentAnimation = safeName
    animObject = anim
    loop = (shouldLoop === true)
    currentFrameIndex = 0
    playing = true
    applyFrame(0)
  }

  function playSound(soundId) {
    if (!soundEnabled || soundVolume <= 0 || !soundId) return
    var safeSoundId = String(soundId).trim()
    if (!/^[a-zA-Z0-9_-]+$/.test(safeSoundId) || safeSoundId.length > 20) return
    var filePath = soundsDir + safeSoundId + ".mp3"
    Quickshell.execDetached([pwPlayBin, "--volume", soundVolume.toFixed(2), filePath])
  }

  function applyFrame(idx) {
    if (!animObject || !animObject.frames || animObject.frames.length === 0) return
    if (idx < 0 || idx >= animObject.frames.length) return

    var f = animObject.frames[idx]
    root.frameX = f.x
    root.frameY = f.y

    if (f.sound) {
      playSound(f.sound)
    }

    root.frameChanged(idx, f.sound || "")

    // Set interval for next frame
    var dur = f.duration > 0 ? f.duration : 100
    frameTimer.interval = dur
    if (playing) {
      frameTimer.restart()
    }
  }

  function advanceFrame() {
    if (!animObject || !animObject.frames || animObject.frames.length === 0) return

    var cur = animObject.frames[currentFrameIndex]
    var nextIdx = currentFrameIndex + 1

    // Check branching if present
    if (cur.branching && cur.branching.branches && cur.branching.branches.length > 0) {
      var roll = Math.random() * 100
      var accum = 0
      for (var i = 0; i < cur.branching.branches.length; i++) {
        var branch = cur.branching.branches[i]
        accum += (branch.weight || 0)
        if (roll <= accum) {
          nextIdx = branch.frameIndex
          break
        }
      }
    }

    if (nextIdx >= animObject.frames.length) {
      if (loop) {
        currentFrameIndex = 0
        applyFrame(0)
      } else {
        playing = false
        frameTimer.stop()
        var finishedName = currentAnimation
        root.animationFinished(finishedName)
      }
    } else {
      currentFrameIndex = nextIdx
      applyFrame(currentFrameIndex)
    }
  }

  Timer {
    id: frameTimer
    interval: 100
    repeat: false
    running: false
    onTriggered: {
      if (root.playing) {
        root.advanceFrame()
      }
    }
  }

  // -------------------------------------------------------------
  // Sprite Sheet Image
  // -------------------------------------------------------------
  Image {
    id: spriteMap
    source: Qt.resolvedUrl("assets/map.png")
    x: -Math.round(root.frameX * root.scaleFactor)
    y: -Math.round(root.frameY * root.scaleFactor)
    width: Math.round(3348 * root.scaleFactor)
    height: Math.round(3162 * root.scaleFactor)
    smooth: true
    mipmap: true
    fillMode: Image.Stretch
  }

  Component.onCompleted: {
    applyFrame(0)
  }
}
