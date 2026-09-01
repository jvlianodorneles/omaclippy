import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
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

  readonly property real tailHeight: 9

  readonly property real contentBodyHeight: root.isPromptMode
    ? 60
    : (root.actionButtons && root.actionButtons.length > 0
      ? (Math.max(46, Math.round(measuredLines * 18 + 26)) + 30)
      : (textMetrics.width > 200
        ? Math.max(46, Math.round(measuredLines * 18 + 26))
        : 44))

  readonly property real calculatedHeight: contentBodyHeight + tailHeight

  implicitWidth: calculatedWidth
  implicitHeight: calculatedHeight
  width: calculatedWidth
  height: calculatedHeight

  visible: opacity > 0.01
  opacity: active ? 1.0 : 0.0
  scale: active ? 1.0 : 0.85
  transformOrigin: root.placeBelow
    ? (root.placeLeft ? Item.TopLeft : Item.TopRight)
    : (root.placeLeft ? Item.BottomLeft : Item.BottomRight)

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
  // Visual Bubble Vector Shape (Continuous path with integrated pointer)
  // -------------------------------------------------------------
  // Soft Drop Shadow Shape (exact contour match)
  Shape {
    id: shadowShape
    anchors.fill: parent
    anchors.topMargin: root.placeBelow ? -2 : 2
    anchors.bottomMargin: root.placeBelow ? 2 : -2
    anchors.leftMargin: 1
    anchors.rightMargin: -1
    opacity: 0.16
    z: -1

    readonly property real r: 8
    readonly property real tw: 14
    readonly property real th: root.tailHeight
    readonly property real w: width
    readonly property real h: height
    readonly property real bodyTop: root.placeBelow ? th : 0
    readonly property real bodyBot: root.placeBelow ? h : (h - th)

    readonly property real tailX1: root.placeLeft ? 18 : (w - 18 - tw)
    readonly property real tailTipX: root.placeLeft ? 22 : (w - 22)
    readonly property real tailX2: root.placeLeft ? (18 + tw) : (w - 18)

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: "#000000"
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap

      startX: shadowShape.r
      startY: shadowShape.bodyTop

      PathLine { x: root.placeBelow ? shadowShape.tailX1 : (shadowShape.w - shadowShape.r); y: shadowShape.bodyTop }
      PathLine { x: root.placeBelow ? shadowShape.tailTipX : (shadowShape.w - shadowShape.r); y: root.placeBelow ? 0 : shadowShape.bodyTop }
      PathLine { x: root.placeBelow ? shadowShape.tailX2 : (shadowShape.w - shadowShape.r); y: shadowShape.bodyTop }
      PathLine { x: shadowShape.w - shadowShape.r; y: shadowShape.bodyTop }

      PathArc { x: shadowShape.w; y: shadowShape.bodyTop + shadowShape.r; radiusX: shadowShape.r; radiusY: shadowShape.r; direction: PathArc.Clockwise }
      PathLine { x: shadowShape.w; y: shadowShape.bodyBot - shadowShape.r }
      PathArc { x: shadowShape.w - shadowShape.r; y: shadowShape.bodyBot; radiusX: shadowShape.r; radiusY: shadowShape.r; direction: PathArc.Clockwise }

      PathLine { x: !root.placeBelow ? shadowShape.tailX2 : shadowShape.r; y: shadowShape.bodyBot }
      PathLine { x: !root.placeBelow ? shadowShape.tailTipX : shadowShape.r; y: !root.placeBelow ? shadowShape.h : shadowShape.bodyBot }
      PathLine { x: !root.placeBelow ? shadowShape.tailX1 : shadowShape.r; y: shadowShape.bodyBot }
      PathLine { x: shadowShape.r; y: shadowShape.bodyBot }

      PathArc { x: 0; y: shadowShape.bodyBot - shadowShape.r; radiusX: shadowShape.r; radiusY: shadowShape.r; direction: PathArc.Clockwise }
      PathLine { x: 0; y: shadowShape.bodyTop + shadowShape.r }
      PathArc { x: shadowShape.r; y: shadowShape.bodyTop; radiusX: shadowShape.r; radiusY: shadowShape.r; direction: PathArc.Clockwise }
    }
  }

  // Main Speech Bubble Shape
  Shape {
    id: bubbleShape
    anchors.fill: parent
    z: 0

    readonly property real r: 8
    readonly property real tw: 14
    readonly property real th: root.tailHeight
    readonly property real w: width
    readonly property real h: height
    readonly property real bodyTop: root.placeBelow ? th : 0
    readonly property real bodyBot: root.placeBelow ? h : (h - th)

    readonly property real tailX1: root.placeLeft ? 18 : (w - 18 - tw)
    readonly property real tailTipX: root.placeLeft ? 22 : (w - 22)
    readonly property real tailX2: root.placeLeft ? (18 + tw) : (w - 18)

    // Main Bubble Vector Outline & Fill
    ShapePath {
      strokeWidth: 1.5
      strokeColor: "#ca8a04" // Golden amber border
      fillColor: "#fef9c3"   // Nostalgic warm yellow
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap

      startX: bubbleShape.r
      startY: bubbleShape.bodyTop

      // Top edge (incorporates tail when pointing UP to Clippy)
      PathLine { x: root.placeBelow ? bubbleShape.tailX1 : (bubbleShape.w - bubbleShape.r); y: bubbleShape.bodyTop }
      PathLine { x: root.placeBelow ? bubbleShape.tailTipX : (bubbleShape.w - bubbleShape.r); y: root.placeBelow ? 0 : bubbleShape.bodyTop }
      PathLine { x: root.placeBelow ? bubbleShape.tailX2 : (bubbleShape.w - bubbleShape.r); y: bubbleShape.bodyTop }
      PathLine { x: bubbleShape.w - bubbleShape.r; y: bubbleShape.bodyTop }

      // Top-right corner
      PathArc { x: bubbleShape.w; y: bubbleShape.bodyTop + bubbleShape.r; radiusX: bubbleShape.r; radiusY: bubbleShape.r; direction: PathArc.Clockwise }

      // Right edge
      PathLine { x: bubbleShape.w; y: bubbleShape.bodyBot - bubbleShape.r }

      // Bottom-right corner
      PathArc { x: bubbleShape.w - bubbleShape.r; y: bubbleShape.bodyBot; radiusX: bubbleShape.r; radiusY: bubbleShape.r; direction: PathArc.Clockwise }

      // Bottom edge (incorporates tail when pointing DOWN to Clippy)
      PathLine { x: !root.placeBelow ? bubbleShape.tailX2 : bubbleShape.r; y: bubbleShape.bodyBot }
      PathLine { x: !root.placeBelow ? bubbleShape.tailTipX : bubbleShape.r; y: !root.placeBelow ? bubbleShape.h : bubbleShape.bodyBot }
      PathLine { x: !root.placeBelow ? bubbleShape.tailX1 : bubbleShape.r; y: bubbleShape.bodyBot }
      PathLine { x: bubbleShape.r; y: bubbleShape.bodyBot }

      // Bottom-left corner
      PathArc { x: 0; y: bubbleShape.bodyBot - bubbleShape.r; radiusX: bubbleShape.r; radiusY: bubbleShape.r; direction: PathArc.Clockwise }

      // Left edge
      PathLine { x: 0; y: bubbleShape.bodyTop + bubbleShape.r }

      // Top-left corner
      PathArc { x: bubbleShape.r; y: bubbleShape.bodyTop; radiusX: bubbleShape.r; radiusY: bubbleShape.r; direction: PathArc.Clockwise }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 8
    anchors.topMargin: root.placeBelow ? (8 + root.tailHeight) : 8
    anchors.bottomMargin: !root.placeBelow ? (8 + root.tailHeight) : 8
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
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 0

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
              focus: root.isPromptMode

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
