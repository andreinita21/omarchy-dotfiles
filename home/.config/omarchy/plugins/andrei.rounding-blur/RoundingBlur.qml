import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Popup version of the charlieras262.omablur bar panel: presets, a master
// switch, and sliders for corner rounding and blur intensity. Summoned from
// the Omarchy menu via `omarchy-shell shell summon andrei.rounding-blur '{}'`.
// Dragging applies live via `hyprctl eval`; releasing persists into the same
// marked block Omablur uses in ~/.config/hypr/looknfeel.lua, so both share
// one source of truth.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: "andrei.rounding-blur"
  // Marker id of the looknfeel.lua block; kept as Omablur's so existing
  // settings are replaced rather than duplicated.
  readonly property string blockId: "charlieras262.omablur"
  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    if (u.indexOf("file://") === 0) u = u.slice(7)
    if (u.length > 1 && u.charAt(u.length - 1) === "/") u = u.slice(0, u.length - 1)
    return u
  }

  property string fontFamily: Style.font.menuFamily
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))

  // PanelSlider/PanelSeparator take their colors from a bar object.
  QtObject {
    id: palette
    property color foreground: root.foreground
    property color background: root.background
    property string fontFamily: root.fontFamily
  }

  // ---------------------------------------------------------------- state
  property int rounding: 8
  property bool blurEnabled: true
  property int blurPercent: 50

  function clampInt(value, min, max, fallback) {
    var n = Math.round(Number(value))
    if (!isFinite(n)) return fallback
    return Math.max(min, Math.min(max, n))
  }
  function blurSizeFor(percent) { return clampInt(1 + (percent / 100) * 19, 1, 20, 8) }
  function blurPassesFor(percent) {
    var p = clampInt(percent, 0, 100, 50)
    if (p < 34) return 1
    if (p < 67) return 2
    return 3
  }
  function percentForBlurSize(size) { return clampInt(((size - 1) / 19) * 100, 0, 100, 50) }

  // -------------------------------------------------------------- presets
  readonly property var presets: ({
    "default": { rounding: 8, blurPercent: 40 },
    "minimum": { rounding: 2, blurPercent: 10 },
    "medium": { rounding: 14, blurPercent: 70 }
  })
  property string activePreset: "default"

  function detectPreset() {
    if (!root.blurEnabled) return "custom"
    for (var name in root.presets) {
      var p = root.presets[name]
      if (root.rounding === p.rounding && root.blurPercent === p.blurPercent) return name
    }
    return "custom"
  }

  function applyPreset(name) {
    if (name === "custom") { root.activePreset = "custom"; return }
    var p = root.presets[name]
    if (!p) return
    root.activePreset = name
    root.rounding = p.rounding
    root.blurPercent = p.blurPercent
    root.blurEnabled = true
    applyLive(root.rounding, true, root.blurPercent)
    persistNow()
  }

  // Master switch flattens to rounding=0 / blur off, remembering the previous
  // values for this session so switching back on restores them.
  readonly property bool masterEnabled: root.rounding > 0 || root.blurEnabled
  property int savedRounding: 8
  property int savedBlurPercent: 40
  property string savedPreset: "default"

  function toggleMaster() {
    if (root.masterEnabled) {
      root.savedRounding = root.rounding
      root.savedBlurPercent = root.blurPercent
      root.savedPreset = root.activePreset
      root.rounding = 0
      root.blurEnabled = false
      applyLive(0, false, root.blurPercent)
    } else {
      root.rounding = root.savedRounding
      root.blurPercent = root.savedBlurPercent
      root.blurEnabled = true
      root.activePreset = root.savedPreset
      applyLive(root.rounding, true, root.blurPercent)
    }
    persistNow()
  }

  // Same shared shell-opacity token Omablur drives; a no-op when absent.
  readonly property real shellBlurOpacity: 0.62
  function setShellOpacity(value) {
    if (typeof Style.shellOpacity !== "number") return
    Style.shellOpacity = value ? root.shellBlurOpacity : 1
  }
  onBlurEnabledChanged: if (loaded) root.setShellOpacity(root.blurEnabled)

  // ------------------------------------------------------------ open/close
  function open(payloadJson) {
    root.opened = true
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // ---------------------------------------------------------------- probes
  property bool roundingLoaded: false
  property bool blurEnabledLoaded: false
  property bool blurSizeLoaded: false
  readonly property bool loaded: roundingLoaded && blurEnabledLoaded && blurSizeLoaded
  onLoadedChanged: if (loaded) root.activePreset = root.detectPreset()

  function refresh() {
    roundingLoaded = false
    blurEnabledLoaded = false
    blurSizeLoaded = false
    roundingProbe.running = true
    blurEnabledProbe.running = true
    blurSizeProbe.running = true
  }

  Process {
    id: roundingProbe
    command: ["hyprctl", "-j", "getoption", "decoration:rounding"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.rounding = root.clampInt(JSON.parse(text).int, 0, 20, root.rounding) } catch (e) {}
        root.roundingLoaded = true
      }
    }
  }

  Process {
    id: blurEnabledProbe
    command: ["hyprctl", "-j", "getoption", "decoration:blur:enabled"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.blurEnabled = parsed.bool !== undefined ? !!parsed.bool : !!parsed.int
        } catch (e) {}
        root.blurEnabledLoaded = true
      }
    }
  }

  Process {
    id: blurSizeProbe
    command: ["hyprctl", "-j", "getoption", "decoration:blur:size"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.blurPercent = root.percentForBlurSize(root.clampInt(JSON.parse(text).int, 1, 20, 8)) } catch (e) {}
        root.blurSizeLoaded = true
      }
    }
  }

  // ------------------------------------------------------------ live apply
  property bool applyQueued: false
  property int queuedRounding: rounding
  property bool queuedBlurEnabled: blurEnabled
  property int queuedBlurPercent: blurPercent

  function applyLive(r, enabled, percent) {
    queuedRounding = root.clampInt(r, 0, 20, root.rounding)
    queuedBlurEnabled = !!enabled
    queuedBlurPercent = root.clampInt(percent, 0, 100, root.blurPercent)
    if (applyProc.running) { applyQueued = true; return }
    runApply()
  }

  function runApply() {
    applyQueued = false
    applyProc.command = ["hyprctl", "eval", root.decorationConfig(queuedRounding, queuedBlurEnabled,
      blurSizeFor(queuedBlurPercent), blurPassesFor(queuedBlurPercent))]
    applyProc.running = true
  }

  Process {
    id: applyProc
    onExited: {
      Style.refresh()
      if (root.applyQueued) root.runApply()
    }
  }

  // --------------------------------------------------------------- persist
  function decorationConfig(rounding, blurEnabled, size, passes) {
    return "hl.config({\n"
      + "  decoration = {\n"
      + "    rounding = " + rounding + ",\n"
      + "    blur = {\n"
      + "      enabled = " + (blurEnabled ? "true" : "false") + ",\n"
      + "      size = " + size + ",\n"
      + "      passes = " + passes + ",\n"
      + "      new_optimizations = true,\n"
      + "      ignore_opacity = true,\n"
      + "    },\n"
      + "  },\n"
      + "})"
  }

  function persistNow() {
    var block = root.decorationConfig(root.rounding, root.blurEnabled,
      blurSizeFor(root.blurPercent), blurPassesFor(root.blurPercent)) + "\n"
    persistProc.command = ["python3", root.pluginDir + "/install-looknfeel.py", root.blockId, block]
    persistProc.running = true
  }

  Process { id: persistProc }

  function setRounding(v) {
    root.rounding = root.clampInt(v, 0, 20, root.rounding)
    root.blurEnabled = true
    applyLive(root.rounding, true, root.blurPercent)
    persistNow()
  }

  function setBlurPercent(v) {
    root.blurPercent = root.clampInt(v, 0, 100, root.blurPercent)
    root.blurEnabled = true
    applyLive(root.rounding, true, root.blurPercent)
    persistNow()
  }

  // -------------------------------------------------------------------- UI
  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    // No scrim, so the windows behind stay visible while tuning.
    color: "transparent"
    WlrLayershell.namespace: "andrei-rounding-blur"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(360), panel.width - Style.gapsOut * 2)
      height: column.implicitHeight + card.contentTopInset + card.contentBottomInset
      radius: Style.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.dismiss()
            event.accepted = true
          }
        }
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.space(16)
        enabled: root.loaded
        opacity: root.loaded ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // ---------------------------------------------------------- header
        Item {
          width: parent.width
          height: Math.max(headerText.implicitHeight, masterToggle.implicitHeight)

          Column {
            id: headerText
            anchors.left: parent.left
            anchors.right: masterToggle.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: "Rounding & Blur"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              text: "WINDOW DECORATIONS"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          ToggleSwitch {
            id: masterToggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.masterEnabled
            foreground: root.foreground
            onToggled: root.toggleMaster()
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // --------------------------------------------------------- presets
        Column {
          width: parent.width
          spacing: Style.space(8)
          enabled: root.masterEnabled
          opacity: root.masterEnabled ? 1 : 0.45
          Behavior on opacity { NumberAnimation { duration: 120 } }

          PanelSectionHeader {
            text: "PRESET"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Grid {
            id: presetGrid
            width: parent.width
            columns: 4
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

            Repeater {
              model: [
                { key: "default", label: "Default" },
                { key: "minimum", label: "Minimum" },
                { key: "medium", label: "Medium" },
                { key: "custom", label: "Custom" }
              ]
              Button {
                required property var modelData
                text: modelData.label
                width: presetGrid.cellWidth
                bordered: true
                active: root.activePreset === modelData.key
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                horizontalPadding: Style.spacing.sm
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.applyPreset(modelData.key)
              }
            }
          }

          // ------------------------------------------------------ sliders
          Column {
            width: parent.width
            spacing: Style.space(14)
            visible: root.activePreset === "custom"

            Item { width: 1; height: Style.space(2) }

            Column {
              width: parent.width
              spacing: Style.space(6)
              Row {
                width: parent.width
                Text {
                  id: roundingHeader
                  text: "CORNER ROUNDING"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Item { width: parent.width - roundingHeader.implicitWidth - roundingValue.implicitWidth; height: 1 }
                Text {
                  id: roundingValue
                  text: Math.round(roundingSlider.dragging ? roundingSlider.liveValue : root.rounding) + "px"
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
              PanelSlider {
                id: roundingSlider
                bar: palette
                width: parent.width
                height: Style.space(20)
                minimum: 0
                maximum: 20
                step: 1
                integer: true
                value: root.rounding
                onMoved: function(v) { root.applyLive(v, true, root.blurPercent) }
                onReleased: function(v) { root.setRounding(v) }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(6)
              Row {
                width: parent.width
                Text {
                  id: intensityHeader
                  text: "BLUR INTENSITY"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Item { width: parent.width - intensityHeader.implicitWidth - intensityValue.implicitWidth; height: 1 }
                Text {
                  id: intensityValue
                  text: Math.round(blurSlider.dragging ? blurSlider.liveValue : root.blurPercent) + "%"
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
              PanelSlider {
                id: blurSlider
                bar: palette
                width: parent.width
                height: Style.space(20)
                minimum: 0
                maximum: 100
                step: 1
                integer: true
                value: root.blurPercent
                onMoved: function(v) { root.applyLive(root.rounding, true, v) }
                onReleased: function(v) { root.setBlurPercent(v) }
              }
            }
          }
        }
      }
    }
  }
}
