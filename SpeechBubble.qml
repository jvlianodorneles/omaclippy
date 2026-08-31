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

  // Interactive AI & Prompt features
  property bool isPromptMode: false
  property var actionButtons: [] // e.g. [{"label": "Aprovar", "action": "approve"}]

  signal dismissed()
  signal promptSubmitted(string prompt)
  signal actionTriggered(string action, string label)

  // -------------------------------------------------------------
  // Instant C++ Text Metrics (Guaranteed non-zero, no scene lag)
  // -------------------------------------------------------------
  TextMetrics {
    id: textMetrics
    font.pixelSize: 12
    font.weight: Font.Medium
    text: root.isPromptMode ? "Digite sua pergunta para o agente do sistema..." : root.fullText
  }

  readonly property real measuredLines: textMetrics.width > 200
    ? Math.max(2, Math.ceil(textMetrics.width / 200))
    : 1

  readonly property real calculatedWidth: root.isPromptMode
    ? 320
    : (textMetrics.width > 200
      ? 280
      : Math.max(150, Math.min(280, Math.round(textMetrics.width + 52))))

  readonly property real calculatedHeight: root.isPromptMode
    ? 60
    : (root.actionButtons && root.actionButtons.length > 0
      ? (Math.max(46, Math.round(measuredLines * 18 + 26)) + 30)
      : (textMetrics.width > 200
        ? Math.max(46, Math.round(measuredLines * 18 + 26))
        : 44))

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
  // Visual Bubble Rectangle (Nostalgic warm yellow)
  // -------------------------------------------------------------
  Rectangle {
    id: bubbleRect
    anchors.fill: parent
    radius: 8
    color: "#fef9c3" // Classic nostalgic warm yellow
    border.color: "#ca8a04" // Golden amber border
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

      x: root.placeLeft ? 20 : (parent.width - 32)
      y: root.placeBelow ? -6 : (parent.height - 6)
    }

    // Interior cover so the tail's internal border is hidden
    Rectangle {
      z: 0
      color: "#fef9c3"
      width: 16
      height: 6
      x: root.placeLeft ? 18 : (parent.width - 34)
      y: root.placeBelow ? 0 : (parent.height - 6)
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 8
      anchors.topMargin: 8
      anchors.bottomMargin: 8
      spacing: 6

      // Top Row: Content & Close Button
      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        // Mini Prompt Input Field
        Rectangle {
          visible: root.isPromptMode
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 6
          color: "#ffffff"
          border.color: "#d97706"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Text {
              text: "📎"
              font.pixelSize: 11
              Layout.alignment: Qt.AlignVCenter
            }

            TextInput {
              id: promptInput
              Layout.fillWidth: true
              Layout.fillHeight: true
              verticalAlignment: Text.AlignVCenter
              color: "#1e293b"
              font.pixelSize: 11
              font.weight: Font.Medium
              clip: true
              selectByMouse: true

              Text {
                text: "Pergunte ao Agente... (Enter para enviar)"
                color: "#94a3b8"
                font.pixelSize: 11
                font.italic: true
                visible: !promptInput.text && !promptInput.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
              }

              onAccepted: {
                if (text.trim().length > 0) {
                  var p = text.trim()
                  text = ""
                  root.promptSubmitted(p)
                }
              }

              Keys.onEscapePressed: root.hide()
            }
          }
        }

        // Standard Message Text
        Text {
          id: messageText
          visible: !root.isPromptMode
          text: root.displayedText
          textFormat: Text.PlainText
          color: "#1e293b"
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

      // Bottom Row: Action Buttons (if any)
      RowLayout {
        visible: !root.isPromptMode && root.actionButtons && root.actionButtons.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        spacing: 6

        Repeater {
          model: root.actionButtons || []

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            radius: 5
            color: btnMouse.containsMouse ? (modelData.color ? Qt.darker(modelData.color, 1.1) : "#fde047") : (modelData.color || "#fef08a")
            border.color: modelData.borderColor || "#ca8a04"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: modelData.label || ""
              color: modelData.textColor || "#854d0e"
              font.pixelSize: 11
              font.bold: true
            }

            MouseArea {
              id: btnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.actionTriggered(modelData.action || "", modelData.label || "")
                root.hide()
              }
            }
          }
        }
      }
    }
  }
}
