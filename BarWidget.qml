import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Clippy Bar Widget: Displays an interactive Nerd Font paperclip button in the Omarchy status bar,
// reflects live active/paused state, and summons the Clippy control panel.
BarWidget {
  id: root
  moduleName: "dorneles.omaclippy"

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/omaclippy"
  readonly property string stateFilePath: stateDir + "/config.json"

  // Mirrored state
  property bool clippyEnabled: true
  property string clippyMode: "companion"
  property string clippyScale: "normal"

  // Panel lifecycle forwarding (Omarchy popout coordinator contract)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.slotSize
  readonly property real openPanelIndicatorHeight: button.slotSize

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    root.injectPanel()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    root.injectPanel()
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  Component.onCompleted: Qt.callLater(injectPanel)

  // Watch state file for changes
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
          }
        }
      } catch (e) {}
    }
  }

  function toggleClippy() {
    var willEnable = !root.clippyEnabled
    root.clippyEnabled = willEnable
    if (willEnable) {
      Quickshell.execDetached(["omarchy-shell", "dorneles.omaclippy", "on"])
    } else {
      Quickshell.execDetached(["omarchy-shell", "dorneles.omaclippy", "off"])
    }
  }

  function playRandom() {
    Quickshell.execDetached(["omarchy-shell", "dorneles.omaclippy", "play", "random"])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf0c6" // Nerd Font paperclip icon (nf-fa-paperclip)
    active: root.opened
    dimmed: !root.clippyEnabled

    tooltipText: root.clippyEnabled
      ? "Clippy Companion \u2014 Active (" + root.clippyMode + ")\n\u2022 Click: Open Control Panel\n\u2022 Right-click: Turn Off\n\u2022 Middle-click: Play Animation"
      : "Clippy Companion \u2014 Paused\n\u2022 Click: Open Control Panel\n\u2022 Right-click: Turn On"

    onPressed: function(btnCode) {
      if (btnCode === Qt.RightButton) {
        root.toggleClippy()
      } else if (btnCode === Qt.MiddleButton && root.clippyEnabled) {
        root.playRandom()
      } else {
        root.toggle()
      }
    }
  }

  // Control Panel Loader
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }
}
