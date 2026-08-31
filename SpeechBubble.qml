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

  // -------------------------------------------------------------
  // Pre-calculated Dimensions using full text in advance
  // -------------------------------------------------------------
  Text {
    id: measureText
    opacity: 0
    visible: true
    text: root.fullText
    font.pixelSize: 12
    font.weight: Font.Medium
    wrapMode: Text.WordWrap
    width: 220
  }

  // Pre-calculated target dimensions
  readonly property real bubbleContentWidth: measureText.paintedWidth > 180
    ? 220
    : Math.max(100, Math.min(220, measureText.paintedWidth))
  readonly property real bubbleContentHeight: Math.max(24, measureText.paintedHeight)

  readonly property real calculatedWidth: bubbleContentWidth + 48
  readonly property real calculatedHeight: bubbleContentHeight + 24

  implicitWidth: calculatedWidth
  implicitHeight: calculatedHeight
  width: calculatedWidth
  height: calculatedHeight

  visible: opacity > 0.01
  opacity: active ? 1.0 : 0.0
  scale: active ? 1.0 : 0.85

  Behavior on opacity {
    NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
  }
  Behavior on scale {
    NumberAnimation { duration: 220; easing.type: Easing.OutBack }
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
  // Visual Bubble Rectangle (Rich nostalgic warm yellow)
  // -------------------------------------------------------------
  Rectangle {
    id: bubbleRect
    anchors.fill: parent
    radius: 8
    color: "#fef9c3" // Classic nostalgic vibrant warm yellow
    border.color: "#ca8a04" // Crisp golden amber border
    border.width: 1.5

    // Subtle drop shadow
    Rectangle {
      z: -2
      anchors.fill: parent
      anchors.margins: -1
      anchors.topMargin: root.placeBelow ? -2 : 2
      anchors.bottomMargin: root.placeBelow ? 2 : -2
      radius: parent.radius
      color: "#000000"
      opacity: 0.18
    }

    // Speech Tail (Arrow) pointing towards Clippy
    Rectangle {
      id: tailRect
      z: -1
      width: 12
      height: 12
      rotation: 45
      color: "#fef9c3"
      border.color: "#ca8a04"
      border.width: 1.5

      anchors.bottom: root.placeBelow ? undefined : parent.bottom
      anchors.top: root.placeBelow ? parent.top : undefined
      anchors.bottomMargin: root.placeBelow ? 0 : -6
      anchors.topMargin: root.placeBelow ? -6 : 0

      anchors.right: root.placeLeft ? undefined : parent.right
      anchors.left: root.placeLeft ? parent.left : undefined
      anchors.rightMargin: root.placeLeft ? 0 : 24
      anchors.leftMargin: root.placeLeft ? 24 : 0
    }

    // Interior cover so the tail's internal border is hidden
    Rectangle {
      z: 0
      color: "#fef9c3"
      width: 16
      height: 6
      anchors.bottom: root.placeBelow ? undefined : parent.bottom
      anchors.top: root.placeBelow ? parent.top : undefined
      anchors.bottomMargin: root.placeBelow ? 0 : 1
      anchors.topMargin: root.placeBelow ? 1 : 0
      anchors.right: root.placeLeft ? undefined : parent.right
      anchors.left: root.placeLeft ? parent.left : undefined
      anchors.rightMargin: root.placeLeft ? 0 : 22
      anchors.leftMargin: root.placeLeft ? 22 : 0
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 6
      anchors.topMargin: 6
      anchors.bottomMargin: 6
      spacing: 6

      Text {
        id: messageText
        text: root.displayedText
        color: "#1e293b" // Crisp dark readable text
        font.pixelSize: 12
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter
        verticalAlignment: Text.AlignVCenter
      }

      // Close '✕' button
      Rectangle {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        Layout.alignment: Qt.AlignTop | Qt.AlignRight
        radius: 9
        color: closeMouse.containsMouse ? "#fde047" : "transparent"

        Text {
          anchors.centerIn: parent
          text: "✕"
          color: "#854d0e"
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
