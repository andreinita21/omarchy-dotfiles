import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Popup with two sliders: outer margins (general:gaps_out) and the space
// between windows (general:gaps_in). Summoned from the Omarchy menu via
// `omarchy-shell shell summon andrei.gaps '{}'`. Dragging applies live via
// `hyprctl eval`; releasing persists a marked block in ~/.config/hypr/looknfeel.lua.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: "andrei.gaps"
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

  readonly property int maxOuter: 60
  readonly property int maxInner: 40
  readonly property int defaultOuter: 10
  readonly property int defaultInner: 5

  property int gapsOut: defaultOuter
  property int gapsIn: defaultInner

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

  function clampInt(value, min, max, fallback) {
    var n = Math.round(Number(value))
    if (!isFinite(n)) return fallback
    return Math.max(min, Math.min(max, n))
  }

  // hyprctl reports gaps as a CSS-style "top right bottom left" string.
  function parseGap(text, max, fallback) {
    try {
      var parsed = JSON.parse(text)
      if (parsed.css !== undefined) return clampInt(String(parsed.css).split(" ")[0], 0, max, fallback)
      if (parsed.int !== undefined) return clampInt(parsed.int, 0, max, fallback)
    } catch (e) {}
    return fallback
  }

  // ------------------------------------------------------------------ probes
  property bool outLoaded: false
  property bool inLoaded: false
  readonly property bool loaded: outLoaded && inLoaded

  function refresh() {
    outLoaded = false
    inLoaded = false
    outProbe.running = true
    inProbe.running = true
  }

  Process {
    id: outProbe
    command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.gapsOut = root.parseGap(text, root.maxOuter, root.gapsOut)
        root.outLoaded = true
      }
    }
  }

  Process {
    id: inProbe
    command: ["hyprctl", "-j", "getoption", "general:gaps_in"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.gapsIn = root.parseGap(text, root.maxInner, root.gapsIn)
        root.inLoaded = true
      }
    }
  }

  // -------------------------------------------------------------- live apply
  property bool applyQueued: false
  property int queuedOut: gapsOut
  property int queuedIn: gapsIn

  function gapsConfig(outer, inner) {
    return "hl.config({\n"
      + "  general = {\n"
      + "    gaps_out = " + outer + ",\n"
      + "    gaps_in = " + inner + ",\n"
      + "  },\n"
      + "})"
  }

  function applyLive(outer, inner) {
    queuedOut = clampInt(outer, 0, maxOuter, gapsOut)
    queuedIn = clampInt(inner, 0, maxInner, gapsIn)
    if (applyProc.running) { applyQueued = true; return }
    runApply()
  }

  function runApply() {
    applyQueued = false
    applyProc.command = ["hyprctl", "eval", gapsConfig(queuedOut, queuedIn)]
    applyProc.running = true
  }

  Process {
    id: applyProc
    onExited: if (root.applyQueued) root.runApply()
  }

  function persistNow() {
    persistProc.command = ["python3", root.pluginDir + "/install-looknfeel.py", root.pluginId,
      gapsConfig(root.gapsOut, root.gapsIn) + "\n"]
    persistProc.running = true
  }

  Process { id: persistProc }

  function setGaps(outer, inner) {
    root.gapsOut = clampInt(outer, 0, maxOuter, root.gapsOut)
    root.gapsIn = clampInt(inner, 0, maxInner, root.gapsIn)
    applyLive(root.gapsOut, root.gapsIn)
    persistNow()
  }

  // ---------------------------------------------------------------------- UI
  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    // No scrim, so the windows behind stay visible while tuning.
    color: "transparent"
    WlrLayershell.namespace: "andrei-gaps"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(340), panel.width - Style.gapsOut * 2)
      height: column.implicitHeight + card.contentTopInset + card.contentBottomInset
      radius: Style.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      // Esc closes; arrows nudge (Up/Down = margins, Left/Right = spacing).
      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.dismiss()
          } else if (event.key === Qt.Key_Up) {
            root.setGaps(root.gapsOut + 1, root.gapsIn)
          } else if (event.key === Qt.Key_Down) {
            root.setGaps(root.gapsOut - 1, root.gapsIn)
          } else if (event.key === Qt.Key_Right) {
            root.setGaps(root.gapsOut, root.gapsIn + 1)
          } else if (event.key === Qt.Key_Left) {
            root.setGaps(root.gapsOut, root.gapsIn - 1)
          } else {
            return
          }
          event.accepted = true
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
        spacing: Style.space(14)
        enabled: root.loaded
        opacity: root.loaded ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Column {
          width: parent.width
          spacing: Style.space(2)
          Text {
            text: "Window Gaps"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Text {
            text: "MARGINS & SPACING"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        // Outer margins
        Column {
          width: parent.width
          spacing: Style.space(6)
          Row {
            width: parent.width
            Text {
              id: outHeader
              text: "SCREEN MARGINS"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { width: parent.width - outHeader.implicitWidth - outValue.implicitWidth; height: 1 }
            Text {
              id: outValue
              text: Math.round(outSlider.dragging ? outSlider.liveValue : root.gapsOut) + "px"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
          PanelSlider {
            id: outSlider
            bar: palette
            width: parent.width
            height: Style.space(20)
            minimum: 0
            maximum: root.maxOuter
            step: 1
            integer: true
            value: root.gapsOut
            onMoved: function(v) { root.applyLive(v, root.gapsIn) }
            onReleased: function(v) { root.setGaps(v, root.gapsIn) }
          }
        }

        // Space between windows
        Column {
          width: parent.width
          spacing: Style.space(6)
          Row {
            width: parent.width
            Text {
              id: inHeader
              text: "SPACE BETWEEN WINDOWS"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Item { width: parent.width - inHeader.implicitWidth - inValue.implicitWidth; height: 1 }
            Text {
              id: inValue
              // gaps_in applies to each side, so the visible gap is double.
              text: Math.round(inSlider.dragging ? inSlider.liveValue : root.gapsIn) * 2 + "px"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
          PanelSlider {
            id: inSlider
            bar: palette
            width: parent.width
            height: Style.space(20)
            minimum: 0
            maximum: root.maxInner
            step: 1
            integer: true
            value: root.gapsIn
            onMoved: function(v) { root.applyLive(root.gapsOut, v) }
            onReleased: function(v) { root.setGaps(root.gapsOut, v) }
          }
        }

        Button {
          text: "Reset to default"
          width: parent.width
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          horizontalPadding: Style.spacing.sm
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: root.setGaps(root.defaultOuter, root.defaultInner)
        }
      }
    }
  }
}
