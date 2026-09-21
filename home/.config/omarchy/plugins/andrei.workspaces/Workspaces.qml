import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Per-monitor workspaces, matching ~/.config/hypr/workspaces.lua: each monitor
// shows its own 1-5 (HDMI-A-1's 1-5 are really workspaces 6-10). Workspaces
// from another monitor that landed here after an unplug are shown with the
// number SUPER+number uses to reach them from this monitor (6-0).
BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Keep in sync with `owners` in ~/.config/hypr/workspaces.lua.
  readonly property var offsets: ({ "DP-3": 0, "HDMI-A-1": 5 })
  readonly property int perMonitor: 5
  readonly property int total: 10

  // The bar surface this widget sits on isn't known until it's attached, and
  // QsWindow doesn't notify, so resolve it once the widget is live.
  property string screenName: ""

  function resolveScreen() {
    var window = root.QsWindow ? root.QsWindow.window : null
    var name = window && window.screen ? String(window.screen.name || "") : ""
    if (name !== root.screenName) root.screenName = name
    return name !== ""
  }

  Component.onCompleted: Qt.callLater(root.resolveScreen)
  Window.onWindowChanged: Qt.callLater(root.resolveScreen)

  Timer {
    interval: 250
    repeat: true
    running: root.screenName === ""
    onTriggered: root.resolveScreen()
  }
  readonly property var monitor: {
    var values = Hyprland.monitors.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].name === root.screenName) return values[i]
    }
    return null
  }
  readonly property int offset: offsets[screenName] !== undefined ? offsets[screenName] : 0

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // Real workspace id -> the number SUPER+number uses for it on this monitor.
  function keyFor(id) {
    return ((id - 1 - root.offset) % root.total + root.total) % root.total + 1
  }

  function workspaceIds() {
    var ids = []
    for (var key = 1; key <= root.perMonitor; key++) ids.push(root.offset + key)

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      var id = workspace.id
      var here = workspace.monitor && workspace.monitor.name === root.screenName
      if (id > 0 && id <= root.total && here && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return root.keyFor(left) - root.keyFor(right) })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.monitor && root.monitor.activeWorkspace
          ? root.monitor.activeWorkspace.id === modelData
          : Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property int key: root.keyFor(modelData)

        bar: root.bar
        text: focused ? "󱓻" : String(key % root.total)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
