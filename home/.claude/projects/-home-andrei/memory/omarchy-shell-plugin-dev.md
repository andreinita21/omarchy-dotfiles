---
name: omarchy-shell-plugin-dev
description: "Gotchas when developing Omarchy shell (Quickshell) plugins on this machine - Lua config rejects hyprctl keyword, hot reload keeps old widget instances"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a54976e-e84b-4858-af6a-1e3361dc76dd
  modified: 2026-09-24T07:53:01.660Z
---

Hyprland here (0.56.x) uses the Lua config, so `hyprctl keyword ...` fails with
"keyword can't work with non-legacy parsers. Use eval." Live monitor changes go
through `hyprctl eval '(function() hl.monitor({...}) ... return "ok" end)()'`.
`hl.monitor` accepts output, mode, position, scale, transform, disabled.

Saving a user plugin under ~/.config/omarchy/plugins/ logs "Local plugin
changed, reloading" but open bar panels keep running the OLD code (IPC state
and screenshots still showed the previous version). `omarchy restart shell`
is needed to actually see changes.

The Display bar widget is the user's clone `andrei.display` (cloned from
`omarchy.monitor`, IPC target stays `omarchy.monitor`). It has a drag canvas
for monitor arrangement; every change applies immediately and rewrites
~/.config/hypr/monitors.lua (the panel owns that file). Connected displays
are auto-enabled except the laptop panel while the lid is closed (Omarchy's
clamshell toggle file holds it off) and outputs written as `disabled = true`.
The user wants no scrolling in that panel and smooth, predictable drags.

**Why:** Both cost real debugging time; the stock omarchy.monitor panel's
own toggleDisplay still uses `hyprctl keyword`, so it is broken here too.

**How to apply:** Use eval for any live Hyprland change from a plugin; after
editing plugin QML, restart the shell before judging the result. See
[[dotfiles-repo]] for where the config actually lives.

**Lock screen:** the user's custom lock is `andrei.lock` (clone of `omarchy.lock`,
2026-09-24): OLED black, "ANDREI NITA" block art shown as `logo.png` (the
exact wallpaper render, glow included: user wants lock and wallpaper
identical), gradient field border. Colors were deepened on user request
because light lilac looked white on low-end monitors: violet #7c3aed →
purple #9d4edd → fuchsia #c026d3, accent #9d4edd; avoid pastel/near-white
accents. Theme `andrei-nita` (~/.config/omarchy/themes/andrei-nita, active)
uses the same gradient as hyprland_active_border. Plymouth boot logo is the
same render at 1048px (`omarchy plymouth set '#000000' '#9d4edd' ...`).
Preview safely with `omarchy-shell lock preview` / `hidePreview`. After any
LockView edit, check `journalctl --user` for QML errors: a syntax error makes
the lock fail to load at all (the plugin is keepLoaded, so restart the shell).
`omarchy plymouth preview` opens a fullscreen imv and blocks until closed.

**Published setup repo:** github.com/andreinita21/omarchy-andrei-nita (public,
local ~/Projects/omarchy-andrei-nita) holds theme, lock, screensaver, boot
logo, install.sh and art/render.sh. The user wants to be the sole author:
commit as `Nita Andrei <61935070+andreinita21@users.noreply.github.com>`
with NO Claude co-author/attribution lines. Keep repo and live copies in sync.

**Screensaver:** purple/pink via `andrei.idle` (clone of omarchy.idle, changed
to run `andrei-launch-screensaver`; since 2026-10-04 it also holds a logind
handle-lid-switch inhibitor while Stay Awake/coffee is on, and bindings.lua
routes the lid to ~/.local/bin/andrei-lid-close/-open, which blank the panel
so agents keep running with the lid shut; shipped in both repos) + ~/.local/bin scripts
`andrei-launch-screensaver` (sed-wraps Omarchy's launcher) and
`andrei-screensaver` (per-effect ttfx colors). Shadowing omarchy-screensaver
on PATH does NOT work: the session PATH puts /usr/share/omarchy/bin first.
Danger: the screensaver exits via `pkill -f org.omarchy.screensaver`, which
kills any process whose command line contains that string, including a Bash
tool call. Put such steps in a script file and kill windows by PID.

**Hyprland 0.56 Lua dispatch:** `hyprctl dispatch workspace +1` no longer
works — args are evaluated as Lua. Use `hyprctl dispatch 'hl.dsp.focus({ workspace = "e+1" })'`,
`hl.dsp.workspace.toggle_special("scratchpad")`, `hl.dsp.window.move({ workspace = "+1" })`,
`hl.dsp.window.cycle_next()`, `hl.dsp.window.fullscreen({ mode = "fullscreen" })`,
`hl.dsp.window.float({ action = "toggle" })`, `hl.dsp.window.close()`. Verified 2026-09-22.

**Omamonitor per-app scaling (2026-10-08, v1.2.0):** lists open windows
(hyprctl clients → /proc exe/maps → desktop entry). Browsers: flags file
(omarchy-launch-browser uses only the first word of Exec). Others: override in
~/.local/share/applications with `Exec=omamonitor-scale-run --scale=X --kind=K ...`
(qt QT_SCALE_FACTOR, gtk3 GDK_DPI_SCALE, chromium flag, terminals font size).
The Omarchy launcher runs `uwsm-app -- gtk-launch <id>.desktop`, so overrides apply.
Measured: GTK 4 ignores GDK_DPI_SCALE/GDK_SCALE (unsupported); Chromium on Wayland
DPR = monitor scale × flag, under XWayland the flag is absolute. ~/.local/bin is
AFTER /usr/bin in PATH, so shadowing binaries there does not work.
v1.3.0: foot resized live via `hl.dsp.send_key_state({mods="CTRL", key="equal", state="down"/"up", window="address:0x.."})`
(works unfocused; foot step 0.5pt = 0.667px); other apps get a relaunch button (close windows one at a
time — Xournal++ ignores a close while its transient 2nd window is up — never kill if a window stays;
browsers SIGTERM + `--restore-last-session`, verified tabs return).
Commits to omamonitor: user as sole author, no Claude lines.
