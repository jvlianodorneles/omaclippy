import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Animations.js" as AnimData

// Clippy Companion Control Center Popup Panel
Panel {
  id: root
  moduleName: "dorneles.omaclippy"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omaclippy"
  readonly property string stateFilePath: stateDir + "/config.json"

  // Live state
  property bool clippyEnabled: true
  property string clippyMode: "companion"
  property string clippyScale: "normal"
  property bool soundEnabled: true
  property real soundVolume: 0.5
  property string idleFrequency: "normal"
  property bool speechBubbles: true
  property bool reactToCursor: true
  property bool reactToWindows: true

  property bool tipFeedback: false

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    root.opened ? root.close() : root.open()
  }

  function closeForPopoutSwitch() {
    root.close()
  }

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
        reactToWindows: root.reactToWindows
      }
      configFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    } catch (e) {}
  }

  function callClippy(cmd, arg) {
    var argv = ["omarchy-shell", "dorneles.omaclippy", cmd]
    if (arg !== undefined && arg !== null && String(arg).length > 0) {
      argv.push(String(arg))
    }
    Quickshell.execDetached(argv)
  }

  function toggleClippy() {
    var willEnable = !root.clippyEnabled
    root.clippyEnabled = willEnable
    if (willEnable) {
      callClippy("on")
    } else {
      callClippy("off")
    }
  }

  function triggerTip() {
    root.tipFeedback = true
    tipTimer.restart()
    callClippy("tip")
  }

  Timer {
    id: tipTimer
    interval: 800
    repeat: false
    onTriggered: root.tipFeedback = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem || (hostWidget ? hostWidget : null)
    owner: root.barIdentity
    bar: root.bar || (hostWidget ? hostWidget.bar : null)
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    Column {
      id: mainColumn
      width: parent.width
      spacing: Style.space(10)

      // -------------------------------------------------------------
      // Header
      // -------------------------------------------------------------
      Item {
        width: parent.width
        height: Style.space(26)

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(8)

          Image {
            source: Qt.resolvedUrl("assets/icon.svg")
            Layout.preferredWidth: Style.space(22)
            Layout.preferredHeight: Style.space(22)
            fillMode: Image.PreserveAspectFit
            smooth: true
          }

          Text {
            text: "CLIPPY COMPANION"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
          }

          Item { Layout.fillWidth: true }

          // Status indicator badge
          Rectangle {
            Layout.preferredHeight: Style.space(22)
            Layout.preferredWidth: statusText.implicitWidth + Style.space(16)
            radius: 11
            color: root.clippyEnabled ? Util.alpha(Color.accent, 0.15) : Util.alpha(root.foreground, 0.1)
            border.color: root.clippyEnabled ? Color.accent : Util.alpha(root.foreground, 0.25)
            border.width: 1

            Text {
              id: statusText
              anchors.centerIn: parent
              text: root.clippyEnabled ? "ACTIVE" : "PAUSED"
              color: root.clippyEnabled ? Color.accent : Util.alpha(root.foreground, 0.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // Close button
          Rectangle {
            Layout.preferredWidth: Style.space(22)
            Layout.preferredHeight: Style.space(22)
            radius: 4
            color: closeMouse.pressed
              ? Util.alpha(root.foreground, 0.18)
              : (closeMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: Color.popups.text
              font.pixelSize: 11
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }
      }

      // -------------------------------------------------------------
      // Main Action Card: On/Off, Tip & Reset
      // -------------------------------------------------------------
      Rectangle {
        width: parent.width
        height: actionRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
        color: Util.alpha(root.foreground, 0.04)
        border.color: Util.alpha(root.foreground, 0.08)
        border.width: 1

        RowLayout {
          id: actionRow
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          Button {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(34)
            text: root.clippyEnabled ? "Pause Clippy" : "Activate Clippy"
            active: root.clippyEnabled
            bordered: true
            onClicked: root.toggleClippy()
          }

          Button {
            Layout.preferredWidth: Style.space(100)
            Layout.preferredHeight: Style.space(34)
            text: root.tipFeedback ? "💡 Reading..." : "💡 Get Tip"
            accent: "#f59e0b"
            bordered: true
            active: root.tipFeedback
            enabled: root.clippyEnabled
            opacity: root.clippyEnabled ? 1.0 : 0.5
            onClicked: root.triggerTip()
          }

          Button {
            Layout.preferredWidth: Style.space(40)
            Layout.preferredHeight: Style.space(34)
            text: "📍"
            bordered: true
            enabled: root.clippyEnabled
            opacity: root.clippyEnabled ? 1.0 : 0.5
            onClicked: root.callClippy("resetPosition")
          }
        }
      }

      // -------------------------------------------------------------
      // Quick Animation Triggers Card
      // -------------------------------------------------------------
      Rectangle {
        width: parent.width
        height: animCol.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
        color: Util.alpha(root.foreground, 0.04)
        border.color: Util.alpha(root.foreground, 0.08)
        border.width: 1

        ColumnLayout {
          id: animCol
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          Text {
            text: "PLAY ANIMATIONS"
            color: Util.alpha(root.foreground, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: Style.space(4)
            columnSpacing: Style.space(4)

            Repeater {
              model: [
                { id: "Wave", label: "👋 Wave" },
                { id: "Thinking", label: "🤔 Thinking" },
                { id: "Explain", label: "💬 Explain" },
                { id: "GetWizardy", label: "🧙 Wizard" },
                { id: "GetArtsy", label: "🎨 Artsy" },
                { id: "GetTechy", label: "💻 Techy" },
                { id: "Writing", label: "✍️ Writing" },
                { id: "Congratulate", label: "🎉 Celebrate" },
                { id: "IdleSnooze", label: "💤 Snooze" }
              ]

              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                text: modelData.label
                bordered: true
                enabled: root.clippyEnabled
                opacity: root.clippyEnabled ? 1.0 : 0.5
                onClicked: root.callClippy("play", modelData.id)
              }
            }
          }
        }
      }

      // -------------------------------------------------------------
      // Speech Input Card
      // -------------------------------------------------------------
      Rectangle {
        width: parent.width
        height: speakCol.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
        color: Util.alpha(root.foreground, 0.04)
        border.color: Util.alpha(root.foreground, 0.08)
        border.width: 1

        ColumnLayout {
          id: speakCol
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          Text {
            text: "SAY SOMETHING"
            color: Util.alpha(root.foreground, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(32)
              radius: 4
              color: Util.alpha(root.foreground, 0.06)
              border.color: customTextInput.activeFocus ? Color.accent : Util.alpha(root.foreground, 0.15)
              border.width: 1

              TextInput {
                id: customTextInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Color.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                clip: true
                selectByMouse: true

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  text: "Type a message for Clippy..."
                  color: Util.alpha(root.foreground, 0.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  visible: !customTextInput.text && !customTextInput.activeFocus
                }

                onAccepted: {
                  if (text.trim().length > 0) {
                    root.callClippy("speak", text.trim())
                    text = ""
                  }
                }
              }
            }

            Button {
              Layout.preferredWidth: Style.space(70)
              Layout.preferredHeight: Style.space(32)
              text: "Speak"
              bordered: true
              accent: Color.accent
              enabled: root.clippyEnabled && customTextInput.text.trim().length > 0
              opacity: (root.clippyEnabled && customTextInput.text.trim().length > 0) ? 1.0 : 0.5
              onClicked: {
                if (customTextInput.text.trim().length > 0) {
                  root.callClippy("speak", customTextInput.text.trim())
                  customTextInput.text = ""
                }
              }
            }
          }
        }
      }

      // -------------------------------------------------------------
      // Mode & Size Settings Card
      // -------------------------------------------------------------
      Rectangle {
        width: parent.width
        height: modeCol.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
        color: Util.alpha(root.foreground, 0.04)
        border.color: Util.alpha(root.foreground, 0.08)
        border.width: 1

        ColumnLayout {
          id: modeCol
          anchors.fill: parent
          anchors.margins: Style.space(8)
          spacing: Style.space(8)

          // Mode
          Text {
            text: "COMPANION MODE"
            color: Util.alpha(root.foreground, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Repeater {
              model: [
                { id: "companion", label: "Stationary" },
                { id: "roam", label: "Roam" },
                { id: "perch", label: "Perch" }
              ]

              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                text: modelData.label
                selected: root.clippyMode === modelData.id
                bordered: true
                onClicked: {
                  root.clippyMode = modelData.id
                  root.saveConfig()
                  root.callClippy("setMode", modelData.id)
                }
              }
            }
          }

          // Size
          Text {
            text: "CLIPPY SIZE"
            color: Util.alpha(root.foreground, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.topMargin: Style.space(4)
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Repeater {
              model: [
                { id: "small", label: "Small" },
                { id: "normal", label: "Normal" },
                { id: "large", label: "Large" },
                { id: "giant", label: "Giant" }
              ]

              delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                text: modelData.label
                selected: root.clippyScale === modelData.id
                bordered: true
                onClicked: {
                  root.clippyScale = modelData.id
                  root.saveConfig()
                  root.callClippy("setScale", modelData.id)
                }
              }
            }
          }
        }
      }

      // -------------------------------------------------------------
      // Behavior & Audio Toggles Card
      // -------------------------------------------------------------
      Rectangle {
        width: parent.width
        height: behaviorCol.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
        color: Util.alpha(root.foreground, 0.04)
        border.color: Util.alpha(root.foreground, 0.08)
        border.width: 1

        Column {
          id: behaviorCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(6)

          Text {
            text: "BEHAVIORS & AUDIO"
            color: Util.alpha(root.foreground, 0.7)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            bottomPadding: Style.space(2)
          }

          Toggle {
            width: behaviorCol.width
            label: "Sound Effects"
            description: "Play classic sound effects with animations"
            checked: root.soundEnabled
            onClicked: {
              root.soundEnabled = !root.soundEnabled
              root.saveConfig()
              root.callClippy("setSound", root.soundEnabled ? "1" : "0")
            }
          }

          Toggle {
            width: behaviorCol.width
            label: "Speech Bubbles"
            description: "Show retro speech balloons with tips"
            checked: root.speechBubbles
            onClicked: {
              root.speechBubbles = !root.speechBubbles
              root.saveConfig()
            }
          }

          Toggle {
            width: behaviorCol.width
            label: "React to Pointer"
            description: "Glances in the direction of mouse movement"
            checked: root.reactToCursor
            onClicked: {
              root.reactToCursor = !root.reactToCursor
              root.saveConfig()
            }
          }

          Toggle {
            width: behaviorCol.width
            label: "React to Windows"
            description: "Perches on top of moving windows"
            checked: root.reactToWindows
            onClicked: {
              root.reactToWindows = !root.reactToWindows
              root.saveConfig()
            }
          }
        }
      }
    }
  }
}
