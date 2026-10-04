---
name: logi-plugin
description: OmaOptions (andrei.omaoptions) omarchy-shell plugin — Logi Options replacement for MX Master 3S + MX Keys Mini; architecture and hardware gotchas
metadata: 
  node_type: memory
  type: project
  originSessionId: 766b6b57-c4c9-4ce1-87ed-fa19988324df
  modified: 2026-09-22T18:54:15.853Z
---

Built 2026-09-22, published 2026-09-23 as **OmaOptions**:
github.com/andreinita21/omaoptions, checked out at
`~/.config/omarchy/plugins/andreinita21.omaoptions` (the plugin folder IS the
git repo, like omamonitor; dotfiles ignores it and lists it in
omarchy/git-clones.txt). Commits authored as "Nita Andrei", no Claude
attribution by the user's explicit request. Config v4 is per device
(`devices.<name>.{settings,slots,custom}`), slots derived from each
device's divertable keys, settings from Solaar's setting list. Backend `bin/omaoptions`
(Python, symlinked to `~/.local/bin/omaoptions`): `get / apply / status /
discover / doctor`. Config `~/.config/omarchy/omaoptions/config.json` →
generates `…/omaoptions/logid.cfg` (logiops) and `~/.config/hypr/omaoptions.lua`
(Hyprland binds, required from `hyprland.lua` via `require_optional`).
**Engine = Solaar, not logiops** (switched 2026-09-22 evening): `bin/omaoptions-daemon`
runs Solaar's listener headless as the user unit `omaoptions.service`; config
is written with `solaar config` into ~/.config/solaar/config.yaml and rules
into ~/.config/solaar/rules.yaml (MouseGesture / Key / Test thumb_wheel_* →
Execute / KeyPress / MouseScroll). Settings for an offline device go to
pending.json and the daemon writes them on reconnect. logid.service is masked.

**Why:** Hardware/software facts that are not obvious from the code:
- Logi Bolt receiver (046d:c548) is NOT in this kernel's hid-logitech-dj alias
  table → stays on hid-generic → no UPower battery. Battery via `solaar show`.
- logiops 0.3.5 is unusable here: it cannot ping devices through the Bolt
  receiver ("timed out, waiting for input"), and while it ran the mouse
  dropped clicks (3 presses per click), scrolled uncontrollably and lost the
  SmartShift transition. Stopping it + resetting the mouse via Solaar fixed it
  instantly. Never re-enable logid on this machine.
- No shell-command action in logiops → compositor actions go through virtual
  keys F13–F19/F24 (+Shift/+Ctrl layers) bound by keycode (`code:191`…).
  F20–F23 avoided (xkb maps them to mic-mute/touchpad keysyms Omarchy binds).
- Solaar fn-swap=**true** = media keys without fn (verified). "Top row: F1–F12"
  sends fn-swap false. Keyboard backlight is a choice setting
  (Automatic/Manual/Disabled) + `backlight_level` (0…≥50 accepted, 99 rejected)
  + `backlight_duration_hands_out/hands_in/powered`. multiplatform choices on
  the MX Keys Mini: Linux, MacOS, iOS, Chrome.
- MX Keys Mini divertable keys: Dictation, Emoji, Screen Capture, Mute
  Microphone, Delete, Backlight Up/Down, media keys. No Mission Control /
  Launchpad / Lock / DND.
- Sliders in a scrollable KeyboardPanel get changed by wheel scrolling → the
  user wants dropdowns only. Bar widget must be ONE BarIconButton with
  `slotSize` from TextMetrics, otherwise the hitbox breaks; expose
  `openPanelIndicatorWidth: button.glyphPaintedWidth` or the bar's open mark
  stays icon-sized.
- HID++ traffic on the Bolt receiver stutters the pointer and drops clicks:
  `solaar show` (~150 requests) polled from the bar made the mouse glitchy.
  Status uses a light Solaar-library probe (name/ping/battery only), polled
  every 120 s (30 s while open), and every Solaar access is serialized with a
  flock — two concurrent HID++ clients read each other's replies (battery=1).
- /etc/polkit-1/rules.d is not readable by users → cannot check the rule file;
  a successful passwordless restart is recorded in state.json instead.
- Solaar `k.flags` is an enum.Flag: test with `KeyFlag.DIVERTABLE in flags`.

**How to apply:** After editing plugin QML restart the shell (hot reload kept
a stale IpcHandler). Test with `omarchy-shell andrei.omaoptions open|tab
keyboard|close` and `grim -g "3440,0 528x1152"` (opens on focused DP-3). See
[[omarchy-shell-plugin-dev]] and [[dotfiles-repo]].
- Scroll speed: vertical = Hyprland per-device `hl.device({ name = "logitech-usb-receiver-mouse", scroll_factor = x })`
  in hypr/omaoptions.lua (default: none → global input.scroll_factor, which the
  user keeps at 0.7). Horizontal = Solaar `Test: [thumb_wheel_up, N]` threshold
  with MouseScroll emulation (0 = native). Apply batches all settings of a device
  in ONE Solaar session (~17 s total); per-setting `solaar config` took minutes.
