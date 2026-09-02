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
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omaclippy"
  readonly property string stateFilePath: stateDir + "/config.json"
  readonly property string omarchyShellBin: "/usr/share/omarchy/bin/omarchy-shell"
  readonly property string pwPlayBin: "/usr/bin/pw-play"
  readonly property string soundsDir: Qt.resolvedUrl("assets/sounds/").toString().replace("file://", "")

  // Live state
  property bool clippyEnabled: true
  property string clippyMode: "companion"
  property string clippyScale: "normal"
  property bool soundEnabled: true
  property real soundVolume: 0.5
  property string idleFrequency: "normal"
  property bool speechBubbles: true
  property string balloonSkin: "classic"
  property bool reactToCursor: true
  property bool reactToWindows: true
  property bool reactToAgents: true
  property bool reactToSystem: true
  property bool rawInputTracking: false

  property string currentTab: "actions" // "actions" | "settings"
  property bool tipFeedback: false

  // Animation browser state
  property string animSearchText: ""
  property string animCategoryFilter: "work" // "work" | "emotes" | "idles" | "gestures"
  readonly property var allAnimations: AnimData.getAnimationCatalog()

  function getFilteredAnimations() {
    var list = root.allAnimations || []
    var cat = root.animCategoryFilter || "work"
    var q = root.animSearchText.trim().toLowerCase()
    var out = []
    for (var i = 0; i < list.length; i++) {
      var a = list[i]
      // Ensure the animation actually exists in the Clippy sprite sheet
      var realAnim = AnimData.getAnimation(a.id)
      if (!realAnim || !realAnim.frames || realAnim.frames.length === 0) continue

      if (q.length === 0 && a.category !== cat) continue
      if (q.length > 0) {
        var matchId = a.id.toLowerCase().indexOf(q) !== -1
        var matchLabel = a.label.toLowerCase().indexOf(q) !== -1
        var matchDesc = (a.description || "").toLowerCase().indexOf(q) !== -1
        if (!matchId && !matchLabel && !matchDesc) continue
      }
      out.push(a)
    }
    return out
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
        rawInputTracking: Boolean(root.rawInputTracking)
      }
      configFile.setText(JSON.stringify(cfg, null, 2) + "\n")
    } catch (e) {}
  }

  function callClippy(cmd, arg) {
    var safeCmd = String(cmd || "").trim().substring(0, 40)
    var argv = [root.omarchyShellBin, "dorneles.omaclippy", safeCmd]
    if (arg !== undefined && arg !== null && String(arg).length > 0) {
      argv.push(String(arg).substring(0, 500))
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

  function testSoundEffect() {
    if (!root.soundEnabled || root.soundVolume <= 0) return
    var filePath = root.soundsDir + "Greeting.mp3"
    Quickshell.execDetached([root.pwPlayBin, "--volume", root.soundVolume.toFixed(2), filePath])
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
    contentWidth: panel.fittedContentWidth(Style.space(370))
    contentHeight: panel.fittedContentHeight(Math.min(Style.space(520), containerCol.implicitHeight))

    onOpenChanged: {
      if (open) {
        root.animCategoryFilter = "work"
      }
    }

    Column {
      id: containerCol
      width: parent.width
      spacing: Style.space(8)

      // -------------------------------------------------------------
      // Header
      // -------------------------------------------------------------
      Item {
        width: parent.width
        height: Style.space(24)

        RowLayout {
          anchors.fill: parent
          spacing: Style.space(6)

          Text {
            text: "\uf0c6"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.icon
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
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
            Layout.preferredHeight: Style.space(20)
            Layout.preferredWidth: statusText.implicitWidth + Style.space(14)
            radius: 10
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
            Layout.preferredWidth: Style.space(20)
            Layout.preferredHeight: Style.space(20)
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
      // Tab Bar Selector
      // -------------------------------------------------------------
      RowLayout {
        width: parent.width
        spacing: Style.space(4)

        Button {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(26)
          text: "🎭 Actions"
          selected: root.currentTab === "actions"
          bordered: true
          onClicked: root.currentTab = "actions"
        }

        Button {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(26)
          text: "⚙️ Settings"
          selected: root.currentTab === "settings"
          bordered: true
          onClicked: root.currentTab = "settings"
        }
      }

      // -------------------------------------------------------------
      // Scrollable Content View
      // -------------------------------------------------------------
      Flickable {
        id: scrollArea
        width: parent.width
        height: Math.min(Style.space(460), tabContent.implicitHeight)
        contentWidth: width
        contentHeight: tabContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Item {
          id: tabContent
          width: scrollArea.width
          implicitHeight: root.currentTab === "actions" ? actionsCol.implicitHeight : settingsCol.implicitHeight

          // =========================================================
          // TAB 1: ACTIONS & FULL ANIMATION BROWSER
          // =========================================================
          Column {
            id: actionsCol
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "actions"

            // Main Action Card: On/Off, Tip & Reset
            Rectangle {
              width: parent.width
              height: actionRow.implicitHeight + Style.space(12)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.foreground, 0.08)
              border.width: 1

              RowLayout {
                id: actionRow
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(6)

                Button {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(30)
                  text: root.clippyEnabled ? "Pause Clippy" : "Activate Clippy"
                  active: root.clippyEnabled
                  bordered: true
                  onClicked: root.toggleClippy()
                }

                Button {
                  Layout.preferredWidth: Style.space(90)
                  Layout.preferredHeight: Style.space(30)
                  text: root.tipFeedback ? "💡 Tip..." : "💡 Get Tip"
                  accent: "#f59e0b"
                  bordered: true
                  active: root.tipFeedback
                  enabled: root.clippyEnabled
                  opacity: root.clippyEnabled ? 1.0 : 0.5
                  onClicked: root.triggerTip()
                }

                Button {
                  Layout.preferredWidth: Style.space(34)
                  Layout.preferredHeight: Style.space(30)
                  text: "📍"
                  bordered: true
                  enabled: root.clippyEnabled
                  opacity: root.clippyEnabled ? 1.0 : 0.5
                  onClicked: root.callClippy("resetPosition")
                }
              }
            }

            // Full Animation Browser Card with Search & Categories
            Rectangle {
              width: parent.width
              height: animBrowserCol.implicitHeight + Style.space(14)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.foreground, 0.08)
              border.width: 1

              ColumnLayout {
                id: animBrowserCol
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(6)

                // Header with Count
                RowLayout {
                  Layout.fillWidth: true

                  Text {
                    text: "ANIMATION GALLERY"
                    color: Util.alpha(root.foreground, 0.7)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    text: root.getFilteredAnimations().length + " of " + root.allAnimations.length
                    color: Util.alpha(root.foreground, 0.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                // Instant Search Bar
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(26)
                  radius: 4
                  color: Util.alpha(root.foreground, 0.06)
                  border.color: searchInput.activeFocus ? Color.accent : Util.alpha(root.foreground, 0.15)
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: Style.space(4)

                    Text {
                      text: "🔍"
                      font.pixelSize: 11
                    }

                    TextInput {
                      id: searchInput
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      verticalAlignment: TextInput.AlignVCenter
                      color: Color.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      clip: true
                      selectByMouse: true
                      maximumLength: 40

                      Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search animations (e.g. atom, wave, mail)..."
                        color: Util.alpha(root.foreground, 0.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        visible: !searchInput.text && !searchInput.activeFocus
                      }

                      onTextChanged: {
                        root.animSearchText = text
                      }
                    }

                    Rectangle {
                      Layout.preferredWidth: 16
                      Layout.preferredHeight: 16
                      radius: 8
                      visible: searchInput.text.length > 0
                      color: clearMouse.containsMouse ? Util.alpha(root.foreground, 0.15) : "transparent"

                      Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 10
                        color: Util.alpha(root.foreground, 0.6)
                      }

                      MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          searchInput.text = ""
                          root.animSearchText = ""
                        }
                      }
                    }
                  }
                }

                // Category Filter Pills
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(3)

                  Repeater {
                    model: [
                      { id: "work", label: "🛠️ Work (8)" },
                      { id: "emotes", label: "🎭 Emotes (12)" },
                      { id: "idles", label: "💤 Idles (11)" },
                      { id: "gestures", label: "👉 Gestures (12)" }
                    ]

                    delegate: Button {
                      required property var modelData
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(22)
                      text: modelData.label
                      selected: root.animCategoryFilter === modelData.id
                      bordered: true
                      onClicked: root.animCategoryFilter = modelData.id
                    }
                  }
                }

                // Animation Buttons Grid
                GridLayout {
                  id: animGrid
                  Layout.fillWidth: true
                  columns: 3
                  rowSpacing: Style.space(4)
                  columnSpacing: Style.space(4)

                  Repeater {
                    model: root.getFilteredAnimations()

                    delegate: Button {
                      required property var modelData
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(26)
                      text: modelData.label + (modelData.hasSound ? " 🔊" : "")
                      bordered: true
                      enabled: root.clippyEnabled
                      opacity: root.clippyEnabled ? 1.0 : 0.5
                      tooltipText: modelData.description || modelData.id
                      onClicked: root.callClippy("play", modelData.id)
                    }
                  }
                }

                // Empty state if no animations match search
                Text {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(30)
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: "No animations match '" + root.animSearchText + "'"
                  color: Util.alpha(root.foreground, 0.45)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.italic: true
                  visible: root.getFilteredAnimations().length === 0
                }
              }
            }

            // Speech Input Card
            Rectangle {
              width: parent.width
              height: speakCol.implicitHeight + Style.space(12)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.foreground, 0.08)
              border.width: 1

              ColumnLayout {
                id: speakCol
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(4)

                Text {
                  text: "SAY SOMETHING"
                  color: Util.alpha(root.foreground, 0.7)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(28)
                    radius: 4
                    color: Util.alpha(root.foreground, 0.06)
                    border.color: customTextInput.activeFocus ? Color.accent : Util.alpha(root.foreground, 0.15)
                    border.width: 1

                    TextInput {
                      id: customTextInput
                      anchors.fill: parent
                      anchors.leftMargin: 6
                      anchors.rightMargin: 6
                      verticalAlignment: TextInput.AlignVCenter
                      color: Color.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      clip: true
                      selectByMouse: true
                      maximumLength: 500

                      Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Type a message..."
                        color: Util.alpha(root.foreground, 0.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
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
                    Layout.preferredWidth: Style.space(60)
                    Layout.preferredHeight: Style.space(28)
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
          }

          // =========================================================
          // TAB 2: SETTINGS, AUDIO & BEHAVIORS
          // =========================================================
          Column {
            id: settingsCol
            width: parent.width
            spacing: Style.space(8)
            visible: root.currentTab === "settings"

            // Mode & Size Settings Card
            Rectangle {
              width: parent.width
              height: modeCol.implicitHeight + Style.space(12)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.foreground, 0.08)
              border.width: 1

              ColumnLayout {
                id: modeCol
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(6)

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
                      Layout.preferredHeight: Style.space(26)
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
                  Layout.topMargin: Style.space(2)
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
                      Layout.preferredHeight: Style.space(26)
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

                // Speech Bubble Skin Selector
                Text {
                  text: "SPEECH BUBBLE THEME"
                  color: Util.alpha(root.foreground, 0.7)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  Layout.topMargin: Style.space(2)
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(4)

                  Repeater {
                    model: [
                      { id: "classic", label: "Classic Yellow" },
                      { id: "glass", label: "Omarchy Glass" },
                      { id: "terminal", label: "Retro Terminal" }
                    ]

                    delegate: Button {
                      required property var modelData
                      Layout.fillWidth: true
                      Layout.preferredHeight: Style.space(26)
                      text: modelData.label
                      selected: root.balloonSkin === modelData.id
                      bordered: true
                      onClicked: {
                        root.balloonSkin = modelData.id
                        root.saveConfig()
                        root.callClippy("setSkin", modelData.id)
                      }
                    }
                  }
                }
              }
            }

            // Audio & Sound Volume Card
            Rectangle {
              width: parent.width
              height: audioCol.implicitHeight + Style.space(12)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.foreground, 0.08)
              border.width: 1

              ColumnLayout {
                id: audioCol
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(6)

                Text {
                  text: "AUDIO & SOUND EFFECTS"
                  color: Util.alpha(root.foreground, 0.7)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Toggle {
                  Layout.fillWidth: true
                  label: "Sound Effects"
                  description: "Play classic synchronized sound effects"
                  checked: root.soundEnabled
                  onClicked: {
                    root.soundEnabled = !root.soundEnabled
                    root.saveConfig()
                    root.callClippy("setSound", root.soundEnabled ? "1" : "0")
                  }
                }

                // Volume Level Control Row
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)
                  visible: root.soundEnabled

                  Text {
                    text: "Volume: " + Math.round(root.soundVolume * 100) + "%"
                    color: Color.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    Layout.preferredWidth: Style.space(90)
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(3)

                    Repeater {
                      model: [
                        { label: "25%", val: 0.25 },
                        { label: "50%", val: 0.50 },
                        { label: "75%", val: 0.75 },
                        { label: "100%", val: 1.00 }
                      ]

                      delegate: Button {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(24)
                        text: modelData.label
                        selected: Math.abs(root.soundVolume - modelData.val) < 0.05
                        bordered: true
                        onClicked: {
                          root.soundVolume = modelData.val
                          root.saveConfig()
                          root.callClippy("setVolume", modelData.val.toFixed(2))
                        }
                      }
                    }
                  }

                  Button {
                    Layout.preferredWidth: Style.space(65)
                    Layout.preferredHeight: Style.space(24)
                    text: "🔊 Test"
                    bordered: true
                    accent: Color.accent
                    onClicked: root.testSoundEffect()
                  }
                }
              }
            }

            // Behavior Toggles Card
            Rectangle {
              width: parent.width
              height: behaviorCol.implicitHeight + Style.space(12)
              radius: Style.cornerRadius > 0 ? Style.cornerRadius : 6
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.foreground, 0.08)
              border.width: 1

              Column {
                id: behaviorCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(4)

                Text {
                  text: "BEHAVIORS & REACTIVITY"
                  color: Util.alpha(root.foreground, 0.7)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  bottomPadding: Style.space(2)
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
                  description: "Glances at mouse movement via Hyprland socket"
                  checked: root.reactToCursor
                  onClicked: {
                    root.reactToCursor = !root.reactToCursor
                    root.saveConfig()
                  }
                }

                Toggle {
                  width: behaviorCol.width
                  label: "React to Windows"
                  description: "Perches on top of active windows via Hyprland socket"
                  checked: root.reactToWindows
                  onClicked: {
                    root.reactToWindows = !root.reactToWindows
                    root.saveConfig()
                  }
                }

                Toggle {
                  width: behaviorCol.width
                  label: "AI Agents (Herdr)"
                  description: "Alerts when AI agents finish or get blocked"
                  checked: root.reactToAgents
                  onClicked: {
                    root.reactToAgents = !root.reactToAgents
                    root.saveConfig()
                  }
                }

                Toggle {
                  width: behaviorCol.width
                  label: "Hardware & Sleep Reactivity"
                  description: "Battery alerts, charger celebrations, and sleep/wake cycles"
                  checked: root.reactToSystem
                  onClicked: {
                    root.reactToSystem = !root.reactToSystem
                    root.saveConfig()
                  }
                }

                Toggle {
                  width: behaviorCol.width
                  label: "Hardware Pointer Clicks (/dev/input)"
                  description: "Low-level pointer click monitoring. Keyboards are never opened."
                  checked: root.rawInputTracking
                  onClicked: {
                    root.rawInputTracking = !root.rawInputTracking
                    root.saveConfig()
                    root.callClippy("setRawInput", root.rawInputTracking ? "1" : "0")
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
