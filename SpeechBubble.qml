import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
  id: root

  // -------------------------------------------------------------
  // Public Properties
  // -------------------------------------------------------------
  property string fullText: ""
  property string displayedText: ""
  property bool active: false
  property real clippyScale: 1.0
  property bool placeBelow: false
  property bool placeLeft: false

  signal dismissed()

  implicitWidth: bubbleRect.implicitWidth
  implicitHeight: bubbleRect.implicitHeight

  visible: opacity > 0.01
  opacity: active ? 1.0 : 0.0
  scale: active ? 1.0 : 0.85

  Behavior on opacity {
    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
  }
  Behavior on scale {
    NumberAnimation { duration: 250; easing.type: Easing.OutBack }
  }

  function speak(text, durationMs) {
    fullText = text
    displayedText = ""
    active = true
    typewriterIndex = 0
    typewriterTimer.restart()

    var autoDuration = durationMs || Math.max(4500, text.length * 90)
    autoCloseTimer.interval = autoDuration
    autoCloseTimer.restart()
  }

  function hide() {
    active = false
    typewriterTimer.stop()
    autoCloseTimer.stop()
    root.dismissed()
  }

  // Typewriter effect
  property int typewriterIndex: 0
  Timer {
    id: typewriterTimer
    interval: 22
    repeat: true
    running: false
    onTriggered: {
      if (root.typewriterIndex < root.fullText.length) {
        root.typewriterIndex += 1
        root.displayedText = root.fullText.substring(0, root.typewriterIndex)
      } else {
        typewriterTimer.stop()
      }
    }
  }

  Timer {
    id: autoCloseTimer
    repeat: false
    running: false
    onTriggered: root.hide()
  }

  // -------------------------------------------------------------
  // Visual Bubble
  // -------------------------------------------------------------
  Rectangle {
    id: bubbleRect
    anchors.left: parent.left
    anchors.top: parent.top
    implicitWidth: Math.min(300, Math.max(150, messageText.implicitWidth + 36))
    implicitHeight: Math.max(46, messageText.implicitHeight + 24)
    radius: 10
    color: "#fffbeb" // Classic soft warm parchment yellow
    border.color: "#d97706"
    border.width: 1.5

    // Subtle drop shadow look
    Rectangle {
      z: -1
      anchors.fill: parent
      anchors.margins: -1
      anchors.topMargin: root.placeBelow ? -2 : 2
      anchors.bottomMargin: root.placeBelow ? 2 : -2
      radius: parent.radius
      color: "#000000"
      opacity: 0.15
    }

    // Speech Tail
    Item {
      id: tail
      width: 14
      height: 10
      anchors.bottom: root.placeBelow ? undefined : parent.bottom
      anchors.top: root.placeBelow ? parent.top : undefined
      anchors.bottomMargin: root.placeBelow ? 0 : -8
      anchors.topMargin: root.placeBelow ? -8 : 0
      anchors.right: root.placeLeft ? undefined : parent.right
      anchors.left: root.placeLeft ? parent.left : undefined
      anchors.rightMargin: root.placeLeft ? 0 : 24
      anchors.leftMargin: root.placeLeft ? 24 : 0

      // Tail triangle drawn with Canvas
      Canvas {
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d")
          ctx.clearRect(0, 0, width, height)
          ctx.beginPath()
          if (root.placeBelow) {
            // Point UP
            ctx.moveTo(0, height)
            ctx.lineTo(width, height)
            ctx.lineTo(width / 2, 0)
          } else {
            // Point DOWN
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
          }
          ctx.closePath()
          ctx.fillStyle = "#fffbeb"
          ctx.fill()
          ctx.strokeStyle = "#d97706"
          ctx.lineWidth = 1.5
          ctx.stroke()
        }
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: 8
      spacing: 6

      Text {
        id: messageText
        text: root.displayedText
        color: "#1e293b"
        font.pixelSize: 12
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      // Close '✕' button
      Rectangle {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        radius: 9
        color: closeMouse.containsMouse ? "#fde68a" : "transparent"

        Text {
          anchors.centerIn: parent
          text: "✕"
          color: "#78350f"
          font.pixelSize: 10
          font.bold: true
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.hide()
        }
      }
    }
  }
}
