import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property bool suspended: false
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
  readonly property string currentThemeBackgrounds: stateHome + "/omarchy/current/theme/backgrounds"

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  // A theme switch names its next background before it has staged the rest of
  // the theme, so the incoming frame can decode while that work runs. A large
  // WebP takes ~130ms to decode at any sourceSize, which the reveal would
  // otherwise wait out after the transition arrives.
  property string preparedBackground: ""
  // The prepare and transition calls travel as separate IPC clients, so a
  // prepare can land after its transition. The path it names then must not be
  // decoded again.
  property string lastTransitionPath: ""
  // Native pixel size per wallpaper path, read from the file header before
  // the image loads. Decoding at screen size only saves memory for wallpapers
  // at least as large as the screen: with PreserveAspectCrop Qt scales the
  // decode up to cover sourceSize, so a smaller wallpaper would cost the
  // screen's worth of pixels instead of its own.
  property var nativeSizes: ({})
  property var sizeQueue: []
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int reloadVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1
  readonly property bool ready: {
    if (isVideo(displayedBackground)) return true
    if (backgrounds.instances.length === 0) return false
    for (var panel of backgrounds.instances) {
      if (!panel.backgroundReady) return false
    }
    return true
  }

  // ------------------------------------------------------------ transitions
  //
  // Theme changes and wallpaper changes each have their own effect, picked
  // from Omarchy menu > Style > Transitions (omarchy-transition). The choice
  // lives in ~/.local/state/omarchy/transition-{theme,background}, outside any
  // theme, so it holds for every theme.
  readonly property var effects: ["fade", "blinds", "wipe", "circle", "clock", "slide", "zoom", "tiles", "bars"]
  readonly property var effectDurations: ({
    fade: 600, blinds: 700, wipe: 520, circle: 650, clock: 750,
    slide: 650, zoom: 650, tiles: 900, bars: 800
  })
  property string themeEffect: "blinds"
  property string backgroundEffect: "blinds"
  property string activeEffect: "blinds"
  property real transitionSeed: 0
  readonly property int effectId: Math.max(0, effects.indexOf(activeEffect))

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

  function isVideo(path) {
    return Util.isVideoPath(path)
  }

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  // The desktop must never be left without a wallpaper. A path that stops
  // loading, say one that ran through a theme since replaced, is resolved
  // again from the background link, which a theme switch always repoints.
  // Only a different path is taken, so a file that is there but unreadable
  // cannot loop. Resolving runs out of process, so a background chosen in the
  // meantime wins over what it finds; if that one fails too, it is resolved
  // in turn once the running lookup is done.
  property string failedBackground: ""
  property int recoverVersion: -1

  function recoverBackground(failedPath) {
    if (!failedPath || failedPath !== displayedBackground) return
    // A theme switch deletes the outgoing wallpaper while the transition
    // away from it is still running; the Hyprland reload it triggers then
    // makes the hidden desktop image reload that path and fail. The
    // transition already replaces it, so recovering would only cut it short.
    if (incomingBackground) return
    failedBackground = failedPath
    if (recoverProc.running) return
    recoverVersion = backgroundVersion
    recoverProc.running = true
  }

  function finishRecovery(path) {
    path = String(path || "").trim()
    var failedPath = failedBackground
    failedBackground = ""
    if (recoverVersion !== backgroundVersion) {
      recoverBackground(failedPath)
      return
    }
    if (!path || path === failedPath) return
    setBackground(path, true)
  }

  function setBackground(path, instant) {
    // Settling on the wallpaper a running transition is already heading to
    // would only cut it short.
    if (incomingBackground && String(path || "").trim() === currentBackground) return
    if (instant) reloadVersion += 1
    transitionBackground("", path, path, instant, instant, "background")
  }

  function transitionBackground(fromPath, path, finalPath, instant, force, kind) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    if (path !== preparedBackground) preparedBackground = ""
    preparedBackgroundTimer.stop()
    lastTransitionPath = path
    // The incoming frame gates the reveal, so its size is read first.
    requestNativeSize(path)
    requestNativeSize(fromPath || displayedBackground)
    requestNativeSize(finalPath)
    currentBackground = finalPath
    backgroundVersion += 1
    failedBackground = ""
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false

    if (!instant) {
      activeEffect = resolveEffect(kind)
      if (activeEffect === "none") instant = true
    }
    transitionSeed = Math.random() * 1000

    // Video frames are not fed through the image-only reveal stack. Switching
    // instantly also avoids decoding two full videos during a transition.
    if (instant || !displayedBackground || isVideo(path) || isVideo(displayedBackground)) {
      oldBackground = ""
      incomingBackground = ""
      preparedBackground = ""
      displayedBackground = finalPath
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
    Commons.Color.loadColors(pendingColorsRaw)
    // Commons.Color.loadShell also refreshes Style so the type scale flips with the
    // background reveal instead of waiting for a separate reload path.
    Commons.Color.loadShell(pendingShellRaw)
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

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    revealAnimation.restart()
  }

  function prepareBackground(path) {
    path = String(path || "").trim()
    // Only a still that is not already on screen is worth decoding ahead.
    if (!path || isVideo(path) || path === lastTransitionPath || path === displayedBackground) return
    requestNativeSize(path)
    preparedBackground = path
    preparedBackgroundTimer.restart()
  }

  function requestNativeSize(path) {
    if (!path || isVideo(path) || nativeSizes[path] !== undefined || sizeQueue.indexOf(path) !== -1) return
    sizeQueue = sizeQueue.concat([path])
    probeNextSize()
  }

  function probeNextSize() {
    if (sizeProbe.running || sizeQueue.length === 0) return
    sizeProbe.path = sizeQueue[0]
    sizeProbe.command = ["magick", "identify", "-ping", "-format", "%w %h", sizeProbe.path]
    sizeProbe.running = true
  }

  // Each theme switch names fresh snapshot paths, so keep only the sizes of
  // the wallpapers still in play.
  function pruneNativeSizes() {
    var kept = {}
    var paths = [displayedBackground, incomingBackground, oldBackground, preparedBackground]
    for (var i = 0; i < paths.length; i++) {
      if (paths[i] && nativeSizes[paths[i]] !== undefined) kept[paths[i]] = nativeSizes[paths[i]]
    }
    nativeSizes = kept
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
    id: sizeProbe
    property string path: ""
    stdout: StdioCollector { id: sizeProbeOut }
    onExited: function(exitCode) {
      var parts = String(sizeProbeOut.text || "").trim().split(/\s+/)
      var width = exitCode === 0 ? parseInt(parts[0], 10) : 0
      var height = exitCode === 0 ? parseInt(parts[1], 10) : 0
      var known = Object.assign({}, root.nativeSizes)
      // An unreadable header records 0x0, which decodes at screen size.
      known[path] = { width: width > 0 ? width : 0, height: height > 0 ? height : 0 }
      root.nativeSizes = known
      root.sizeQueue = root.sizeQueue.filter(function(queued) { return queued !== sizeProbe.path })
      root.probeNextSize()
    }
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  // The link's target when it exists, or else the theme's first background,
  // so a link left dangling still finds a wallpaper.
  Process {
    id: recoverProc
    command: [
      "bash", "-c",
      'target=$(readlink -f "$1"); if [[ -e $target ]]; then echo "$target"; else ' +
      'find "$2" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) | sort | head -n 1; fi',
      "resolve", root.currentBackgroundLink, root.currentThemeBackgrounds
    ]
    stdout: StdioCollector {
      onStreamFinished: root.finishRecovery(text)
    }
  }

  ShellIpc {
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

    function setSuspended(value: string): void {
      root.suspended = value === "true"
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

    function prepare(path: string): void {
      root.prepareBackground(path)
    }
  }

  // A prepared frame that no transition claims, say from a theme switch that
  // failed after naming it, must not hold its decoded texture indefinitely.
  Timer {
    id: preparedBackgroundTimer
    interval: 5000
    repeat: false
    onTriggered: root.preparedBackground = ""
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  // The reveal follows the wall clock rather than Qt's animation driver,
  // which steps one refresh interval (5.7 ms at 175 Hz) per rendered frame:
  // any frame the GPU drops would otherwise slow the effect down and make it
  // stutter instead of keeping its pace.
  FrameAnimation {
    id: revealAnimation
    property real startedAt: 0
    readonly property real duration: Math.max(1, Style.duration(root.effectDurations[root.activeEffect] || 700))

    function restart() {
      startedAt = 0
      root.revealProgress = 0
      running = true
    }

    function ease(t) {
      if (root.activeEffect === "tiles") return t
      if (root.activeEffect === "slide" || root.activeEffect === "zoom") return 1 - Math.pow(1 - t, 3)
      return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
    }

    onTriggered: {
      var now = Date.now()
      // Time starts at the first frame drawn, not when the call was made.
      if (startedAt === 0) startedAt = now
      var t = Math.min(1, (now - startedAt) / duration)
      root.revealProgress = ease(t)
      if (t < 1) return
      stop()
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
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
    id: backgrounds
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !(remapGuard.remapping && screenMoved) && !root.suspended

      // Omarchy's guard pulses a remap whenever the screen's origin changes,
      // and every Hyprland reload (a theme switch does two) nudges it and
      // puts it back. Remapping then tears the surface down mid-transition,
      // so it is only done when the screen really ended up somewhere else.
      property int mappedX: 0
      property int mappedY: 0
      readonly property bool screenMoved: !!screen && (screen.x !== mappedX || screen.y !== mappedY)

      Connections {
        target: remapGuard
        function onRemappingChanged() {
          if (remapGuard.remapping || !panel.screen) return
          panel.mappedX = panel.screen.x
          panel.mappedY = panel.screen.y
        }
      }
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "transparent"
      // Keep render updates enabled. The background layer has been observed to
      // lose its committed buffer while parked with updatesEnabled=false,
      // leaving a black desktop until omarchy-shell is restarted. A still
      // wallpaper costs nothing to keep enabled. OWE manages video layers.
      updatesEnabled: true

      property bool maskReady: false
      property int readyFrames: 0
      readonly property bool backgroundReady: base.ready && readyFrames >= 2
      readonly property bool framesReady: root.incomingBackground !== ""
        && incomingFrame.status === Image.Ready && oldFrame.status === Image.Ready
      property int warmFrames: 0

      FrameAnimation {
        running: base.ready && panel.readyFrames < 2
        onTriggered: panel.readyFrames += 1
      }

      // The overlay lifts only once the desktop has painted the new wallpaper
      // underneath it, so the last frame of a transition never flashes.
      onBackgroundReadyChanged: {
        if (backgroundReady && root.finishingTransition) {
          root.incomingBackground = ""
          root.oldBackground = ""
          root.preparedBackground = ""
          root.finishingTransition = false
          root.pruneNativeSizes()
        }
      }

      // Both wallpapers are drawn at progress 0 for a few frames before the
      // animation starts, so their textures are uploaded (and a theme's
      // colours applied) before the first moving frame instead of during it.
      FrameAnimation {
        running: panel.maskReady && root.revealProgress === 0 && root.revealStartedVersion !== root.backgroundVersion
        onTriggered: {
          panel.warmFrames += 1
          if (panel.warmFrames >= 3) root.startReveal(panel)
        }
      }

      // Decode the wallpaper at the size this screen can show, not the size
      // it was shipped at. With PreserveAspectCrop Qt takes sourceSize as the
      // area to cover, so this is the smallest decode that still fills the
      // screen. Stock wallpapers go up to 10456x3455 (144 MB as RGBA); a
      // 1080p laptop paid all of that for the 8 MB it can display, and paid
      // it up to three times over during a transition. The images wait for
      // the window's size and the wallpaper's native size so nothing is ever
      // decoded at native size first, and a wallpaper smaller than the screen
      // is decoded at its own size rather than scaled up to cover the screen.
      readonly property bool sized: width > 0 && height > 0
      readonly property int liveDecodeWidth: sized ? Math.ceil(width * screen.devicePixelRatio) : 0
      readonly property int liveDecodeHeight: sized ? Math.ceil(height * screen.devicePixelRatio) : 0
      // A surface being remapped briefly reports no size, and its scale can
      // change on the way back. Following that would drop every decoded
      // wallpaper and decode them again, leaving the desktop black meanwhile,
      // so the size only moves to a real new one, and not mid-transition.
      property int decodeWidth: 0
      property int decodeHeight: 0

      function updateDecodeSize() {
        if (liveDecodeWidth <= 0 || liveDecodeHeight <= 0) return
        if (root.incomingBackground && decodeWidth > 0) return
        decodeWidth = liveDecodeWidth
        decodeHeight = liveDecodeHeight
      }

      onLiveDecodeWidthChanged: updateDecodeSize()
      onLiveDecodeHeightChanged: updateDecodeSize()
      Component.onCompleted: {
        updateDecodeSize()
        if (screen) {
          mappedX = screen.x
          mappedY = screen.y
        }
      }

      function decodeSize(path) {
        if (decodeWidth <= 0 || !path) return Qt.size(0, 0)
        var native = root.nativeSizes[path]
        if (native === undefined) return Qt.size(0, 0)
        if (native.width > 0 && (native.width < decodeWidth || native.height < decodeHeight)) return Qt.size(native.width, native.height)
        return Qt.size(decodeWidth, decodeHeight)
      }

      function maybeStartReveal() {
        if (!framesReady || root.revealProgress !== 0 || maskReady) return
        warmFrames = 0
        maskReady = true
        root.applyPendingTheme()
      }

      onFramesReadyChanged: maybeStartReveal()

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: WlrLayer.Background
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // OWE owns video backgrounds. This layer draws stills, and stays empty
      // behind a video so OWE's own layer shows through.
      BackgroundMedia {
        id: base
        anchors.fill: parent
        path: root.displayedBackground
        version: root.reloadVersion
        // Hidden under a running transition, which already covers the
        // screen: drawing both would cost a second full-screen pass a frame.
        visible: !transitionEffect.visible || root.revealProgress === 0
        cached: true
        constrainDecode: true
        decodeSize: panel.decodeSize(root.displayedBackground)
        onFailedChanged: if (failed) root.recoverBackground(path)
        onReadyChanged: panel.readyFrames = 0
      }

      // The outgoing wallpaper shares the desktop's cached decode when it is
      // the one on screen, so starting a transition decodes only the new one.
      // The choice is fixed when the transition starts: the desktop moves on
      // to the new wallpaper as the reveal ends, and following it would reload
      // this frame while the overlay is still showing it.
      property url oldSource: ""
      property bool oldShared: false

      function pickOldSource() {
        oldShared = root.oldBackground !== "" && root.oldBackground === root.displayedBackground
        oldSource = !root.oldBackground ? "" : oldShared ? base.imageUrl : root.imageUrl(root.oldBackground)
      }

      Image {
        id: oldFrame
        readonly property size decode: panel.decodeSize(root.oldBackground)
        source: decode.width <= 0 ? "" : panel.oldSource
        sourceSize.width: decode.width
        sourceSize.height: decode.height
        asynchronous: true
        cache: panel.oldShared
        visible: false
        onStatusChanged: panel.maybeStartReveal()
      }

      Image {
        id: incomingFrame
        // The same URL and size as a prepared frame keeps its decoded
        // image, so a transition to it can reveal at once.
        readonly property string framePath: root.incomingBackground || root.preparedBackground
        readonly property size decode: panel.decodeSize(framePath)
        source: decode.width > 0 ? root.imageUrl(framePath) : ""
        sourceSize.width: decode.width
        sourceSize.height: decode.height
        asynchronous: true
        cache: false
        visible: false
        onStatusChanged: panel.maybeStartReveal()
      }

      ShaderEffect {
        id: transitionEffect
        anchors.fill: parent
        visible: panel.framesReady && (panel.maskReady || root.revealProgress > 0)

        function cropScale(image) {
          var textureAspect = image.implicitWidth / Math.max(1, image.implicitHeight)
          var itemAspect = width / Math.max(1, height)
          if (!(textureAspect > 0)) return Qt.point(1, 1)
          return textureAspect > itemAspect ? Qt.point(itemAspect / textureAspect, 1) : Qt.point(1, textureAspect / itemAspect)
        }

        property variant fromTex: oldFrame
        property variant toTex: incomingFrame
        property real progress: root.revealProgress
        property real effect: root.effectId
        property real seed: root.transitionSeed
        property point res: Qt.point(width * panel.screen.devicePixelRatio, height * panel.screen.devicePixelRatio)
        property point fromScale: cropScale(oldFrame)
        property point toScale: cropScale(incomingFrame)

        fragmentShader: Qt.resolvedUrl("transition.frag.qsb")
      }

      Connections {
        target: root
        function onOldBackgroundChanged() {
          panel.pickOldSource()
        }
        function onIncomingBackgroundChanged() {
          panel.updateDecodeSize()
          panel.maskReady = false
          panel.maybeStartReveal()
        }
        // A cache hit leaves base.ready true across the swap, so count the
        // frames again from here before lifting the overlay.
        function onFinishingTransitionChanged() {
          if (root.finishingTransition) panel.readyFrames = 0
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
