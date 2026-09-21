import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1
  // Per-transition sync across monitors: the reveal starts only once every
  // screen has decoded the incoming image, and the transition is torn down
  // only once every screen's base image has reloaded.
  property int readyPanels: 0
  property int settledPanels: 0

  // ------------------------------------------------------------ transitions
  //
  // Theme changes and wallpaper changes each have their own effect, picked
  // from Omarchy menu > Style > Transitions (omarchy-transition). The choice
  // lives in ~/.local/state/omarchy/transition-{theme,background}, outside any
  // theme, so it holds for every theme.
  readonly property var effects: ["fade", "blinds", "wipe", "circle", "clock", "slide", "zoom", "tiles", "bars"]
  readonly property var maskEffects: ["blinds", "wipe", "circle", "clock", "tiles", "bars"]
  readonly property var effectDurations: ({
    fade: 600, blinds: 700, wipe: 520, circle: 650, clock: 750,
    slide: 650, zoom: 650, tiles: 900, bars: 800
  })
  property string themeEffect: "blinds"
  property string backgroundEffect: "blinds"
  property string activeEffect: "blinds"
  property real transitionSeed: 0
  readonly property bool maskEffect: maskEffects.indexOf(activeEffect) !== -1

  function resolveEffect(kind) {
    var chosen = kind === "theme" ? themeEffect : backgroundEffect
    if (chosen === "random") return effects[Math.floor(Math.random() * effects.length)]
    if (chosen === "none" || effects.indexOf(chosen) !== -1) return chosen
    return "blinds"
  }

  function setTransition(kind, effect) {
    effect = String(effect || "").trim()
    if (effect !== "none" && effect !== "random" && effects.indexOf(effect) === -1) return
    if (kind === "theme") themeEffect = effect
    else if (kind === "background") backgroundEffect = effect
  }

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false, "background")
  }

  function transitionBackground(fromPath, path, finalPath, instant, force, kind) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    startRevealFallback.stop()
    settleFallback.stop()
    finishingTransition = false
    readyPanels = 0
    settledPanels = 0

    if (!instant) {
      activeEffect = resolveEffect(kind)
      if (activeEffect === "none") instant = true
    }
    transitionSeed = Math.random() * 1000

    if (instant || !displayedBackground) {
      oldBackground = ""
      incomingBackground = ""
      displayedBackground = path
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    // Background polling can advance backgroundVersion while a theme switch is
    // pending; the latest theme payload should still apply.
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Color.loadColors(pendingColorsRaw)
    // Color.loadShell also refreshes Style so the type scale flips with the
    // background reveal instead of waiting for a separate reload path.
    Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true, "theme")
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function panelReady() {
    readyPanels += 1
    if (readyPanels >= Quickshell.screens.length) startReveal()
    else if (!startRevealFallback.running) startRevealFallback.restart()
  }

  function startReveal() {
    startRevealFallback.stop()
    if (!incomingBackground) return
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function panelSettled() {
    settledPanels += 1
    if (settledPanels >= Quickshell.screens.length) finishTransition()
    else if (!settleFallback.running) settleFallback.restart()
  }

  function finishTransition() {
    settleFallback.stop()
    if (!finishingTransition) return
    incomingBackground = ""
    oldBackground = ""
    finishingTransition = false
  }

  function openSelector() {
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(/home/andrei/.local/bin/omarchy-theme-switcher-ordered); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshBackground()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  IpcHandler {
    target: "background"

    function refresh(): void {
      root.refreshBackground()
    }

    function set(path: string): void {
      root.setBackground(path, false)
    }

    function setInstant(path: string): void {
      root.setBackground(path, true)
    }

    function transition(fromPath: string, path: string): void {
      root.transitionBackground(fromPath, path, path, false, false, "background")
    }

    function setTransition(kind: string, effect: string): void {
      root.setTransition(kind, effect)
    }

    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  // Don't let one slow screen stall the others forever.
  Timer {
    id: startRevealFallback
    interval: 1500
    repeat: false
    onTriggered: root.startReveal()
  }

  Timer {
    id: settleFallback
    interval: 1500
    repeat: false
    onTriggered: root.finishTransition()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: root.effectDurations[root.activeEffect] || 700
    easing.type: root.activeEffect === "slide" || root.activeEffect === "zoom" ? Easing.OutCubic
      : root.activeEffect === "tiles" ? Easing.Linear : Easing.InOutQuad
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Process {
    id: transitionProbe
    running: true
    command: ["bash", "-c", "for k in theme background; do printf '%s %s\\n' $k \"$(cat \"$HOME/.local/state/omarchy/transition-$k\" 2>/dev/null)\"; done"]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line || "").trim().split(/\s+/)
        if (parts.length === 2) root.setTransition(parts[0], parts[1])
      }
    }
  }

  Component.onCompleted: refreshBackground()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "transparent"
      // Keep render updates enabled. The background layer has been observed to
      // lose its committed buffer while parked with updatesEnabled=false,
      // leaving a black desktop until omarchy-shell is restarted. The wallpaper
      // itself is static, so this favors correctness over a small render-loop
      // optimization.
      updatesEnabled: true

      property bool maskReady: false
      property bool settled: false

      function maybeStartReveal() {
        if (!root.incomingBackground || maskReady) return
        if (incomingFrame.status !== Image.Ready) return
        Qt.callLater(function() {
          if (!root.incomingBackground || maskReady) return
          if (incomingFrame.status !== Image.Ready) return
          // Even if another screen already started the reveal, join it with
          // the mask instead of staying hidden until the animation ends.
          maskReady = true
          root.panelReady()
        })
      }

      function maybeSettle() {
        if (!root.finishingTransition || settled) return
        if (base.status !== Image.Ready || base.source != root.imageUrl(root.displayedBackground)) return
        settled = true
        root.panelSettled()
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Image {
        id: base
        anchors.fill: parent
        source: root.imageUrl(root.displayedBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: {
          panel.maybeSettle()
        }
      }

      Image {
        id: oldFrame
        anchors.fill: parent
        source: root.imageUrl(root.oldBackground)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: root.oldBackground !== "" && root.revealProgress < 1
        transform: Translate {
          x: root.activeEffect === "slide" ? -panel.width * 0.35 * root.revealProgress : 0
        }
        onStatusChanged: panel.maybeStartReveal()
      }

      Item {
        id: incomingLayer
        anchors.fill: parent
        visible: root.incomingBackground !== "" && incomingFrame.status === Image.Ready && (root.revealProgress >= 1 || panel.maskReady)
        layer.enabled: root.maskEffect && root.incomingBackground !== "" && root.revealProgress < 1
        layer.smooth: true
        opacity: root.activeEffect === "fade" || root.activeEffect === "zoom" ? root.revealProgress : 1
        transform: [
          Scale {
            origin.x: incomingLayer.width / 2
            origin.y: incomingLayer.height / 2
            xScale: root.activeEffect === "zoom" ? 1.12 - 0.12 * root.revealProgress : 1
            yScale: xScale
          },
          Translate {
            x: root.activeEffect === "slide" ? incomingLayer.width * (1 - root.revealProgress) : 0
          }
        ]
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: revealMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
        }

        Image {
          id: incomingFrame
          anchors.fill: parent
          source: root.imageUrl(root.incomingBackground)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          smooth: true
          mipmap: true
          onStatusChanged: panel.maybeStartReveal()
        }
      }

      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real p: root.revealProgress
        readonly property real diagonal: Math.sqrt(width * width + height * height)

        function clamp01(v) { return Math.max(0, Math.min(1, v)) }
        // Same seed on every screen, so the pattern matches across monitors.
        function hash(i) {
          var v = Math.sin(i * 12.9898 + root.transitionSeed * 78.233) * 43758.5453
          return v - Math.floor(v)
        }

        Loader {
          anchors.fill: parent
          active: root.maskEffect
          sourceComponent: {
            switch (root.activeEffect) {
            case "wipe": return wipeMask
            case "circle": return circleMask
            case "clock": return clockMask
            case "tiles": return tilesMask
            case "bars": return barsMask
            default: return blindsMask
            }
          }
        }

        // Diagonal blinds: slanted slats that each widen from their own centre
        // line until they meet and the new background is fully revealed.
        Component {
          id: blindsMask

          Item {
            id: blinds
            readonly property real slant: -0.18
            readonly property int visibleBars: 6
            readonly property real slice: revealMask.width / visibleBars
            // Because every slat leans by the same amount, the screen corners fall
            // outside the on-screen slats; extend the run past both edges by the
            // lean so no strip of the old background survives the reveal.
            readonly property real lean: Math.abs(slant) * revealMask.height / 2
            readonly property int bars: Math.ceil((revealMask.width + 2 * lean) / slice)
            // Half-width at full progress must exceed half a slice, or hairline
            // seams show between neighbouring slats.
            readonly property real spread: (slice / 2 + 2) * revealMask.p

            Repeater {
              model: blinds.bars

              Shape {
                id: slat
                required property int index

                readonly property real center: -blinds.lean + (index + 0.5) * blinds.slice
                readonly property real centerTop: center - blinds.slant * revealMask.height / 2
                readonly property real centerBottom: center + blinds.slant * revealMask.height / 2

                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "white"
                  strokeColor: "transparent"
                  startX: slat.centerTop - blinds.spread; startY: 0
                  PathLine { x: slat.centerTop + blinds.spread; y: 0 }
                  PathLine { x: slat.centerBottom + blinds.spread; y: revealMask.height }
                  PathLine { x: slat.centerBottom - blinds.spread; y: revealMask.height }
                  PathLine { x: slat.centerTop - blinds.spread; y: 0 }
                }
              }
            }
          }
        }

        // Omarchy's stock effect: one slanted band opening from the centre.
        Component {
          id: wipeMask

          Shape {
            id: wipe
            readonly property real slant: -0.18
            readonly property real centerTop: revealMask.width / 2 - slant * revealMask.height / 2
            readonly property real centerBottom: revealMask.width / 2 + slant * revealMask.height / 2
            readonly property real reach: revealMask.width / 2 + Math.abs(slant) * revealMask.height / 2 + 4
            readonly property real spread: reach * revealMask.p

            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: "white"
              strokeColor: "transparent"
              startX: wipe.centerTop - wipe.spread; startY: 0
              PathLine { x: wipe.centerTop + wipe.spread; y: 0 }
              PathLine { x: wipe.centerBottom + wipe.spread; y: revealMask.height }
              PathLine { x: wipe.centerBottom - wipe.spread; y: revealMask.height }
              PathLine { x: wipe.centerTop - wipe.spread; y: 0 }
            }
          }
        }

        // Iris: a circle growing from the centre of the screen.
        Component {
          id: circleMask

          Item {
            Rectangle {
              anchors.centerIn: parent
              width: (revealMask.diagonal + 8) * revealMask.p
              height: width
              radius: width / 2
              color: "white"
              antialiasing: true
            }
          }
        }

        // Clock: a radial sweep round the centre, starting at twelve o'clock.
        Component {
          id: clockMask

          Shape {
            id: clock
            readonly property real cx: revealMask.width / 2
            readonly property real cy: revealMask.height / 2
            readonly property real radius: revealMask.diagonal / 2 + 4

            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: "white"
              strokeColor: "transparent"
              startX: clock.cx; startY: clock.cy
              PathAngleArc {
                centerX: clock.cx; centerY: clock.cy
                radiusX: clock.radius; radiusY: clock.radius
                startAngle: -90
                sweepAngle: 360 * revealMask.p
                moveToStart: false
              }
              PathLine { x: clock.cx; y: clock.cy }
            }
          }
        }

        // Tiles: a grid of squares popping in at random.
        Component {
          id: tilesMask

          Item {
            id: tiles
            readonly property int cols: 16
            readonly property real size: revealMask.width / cols
            readonly property int rows: Math.ceil(revealMask.height / size)

            Repeater {
              model: tiles.cols * tiles.rows

              Rectangle {
                required property int index
                readonly property real delay: revealMask.hash(index) * 0.6

                x: (index % tiles.cols) * tiles.size
                y: Math.floor(index / tiles.cols) * tiles.size
                // One pixel of overlap hides seams between neighbours.
                width: tiles.size + 1
                height: tiles.size + 1
                color: "white"
                scale: revealMask.clamp01((revealMask.p - delay) / 0.4)
              }
            }
          }
        }

        // Bars: vertical strips dropping in left to right, alternating
        // between falling from the top and rising from the bottom.
        Component {
          id: barsMask

          Item {
            id: strips
            readonly property int count: 12
            readonly property real barWidth: revealMask.width / count

            Repeater {
              model: strips.count

              Rectangle {
                required property int index
                readonly property real delay: index / strips.count * 0.5

                x: index * strips.barWidth
                width: strips.barWidth + 1
                height: revealMask.height * revealMask.clamp01((revealMask.p - delay) / 0.5)
                y: index % 2 === 0 ? 0 : revealMask.height - height
                color: "white"
              }
            }
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          panel.maybeStartReveal()
        }
        function onFinishingTransitionChanged() {
          panel.settled = false
          // The base may already hold the new image (cache hit, no status change).
          Qt.callLater(panel.maybeSettle)
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onDoubleClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }
      }
    }
  }
}
