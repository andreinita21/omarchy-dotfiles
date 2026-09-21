-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })

-- Restore normal Caps Lock.
-- Omarchy's default is kb_options = "compose:caps,shift:both_capslock_cancel",
-- which turns the Caps Lock key into the Compose key. Clearing it gives the
-- key back its normal behavior.
hl.config({
  input = {
    kb_options = "",
  },
})

-- ── Trackpad ────────────────────────────────────────────────────────────────
--
-- Back on libinput's stock acceleration. A hand-written `custom` curve was
-- tried here and made things worse, and it had a hidden cost: libinput
-- IGNORES `sensitivity` while a custom profile is active, so the one obvious
-- speed dial silently did nothing. With the stock profile it works again,
-- and it is the only knob you should normally need.
--
--   SENSITIVITY: -1.0 (slowest) .. 0.0 (libinput default) .. 1.0 (fastest)
--   Windows' pointer-speed slider is the same idea. Change it, save, done --
--   Hyprland hot-reloads. Move in steps of 0.1; the range is small but the
--   effect is not.
local sensitivity = 0.0

-- ACCEL PROFILE -- the two models worth trying. Swap which line is commented.
--
--   "adaptive"  libinput's default. Cursor speed rises with finger speed, so
--               a slow drag is precise and a quick flick crosses the screen.
--               This is the closest relative of what Windows does with
--               "Enhance pointer precision" left ON (its default).
--
--   "flat"      No acceleration at all. Distance moved is strictly
--               proportional to finger distance, every single time. This is
--               Windows with "Enhance pointer precision" turned OFF. Try it
--               if the complaint is "I can never predict where it lands" --
--               it trades reach for total consistency, and you will probably
--               want sensitivity around 0.3-0.5 to compensate.
local accel_profile = "adaptive"

hl.device({
  name = "elan0676:00-04f3:3195-touchpad",

  accel_profile = accel_profile,
  sensitivity = sensitivity,

  -- Content follows your fingers.
  natural_scroll = true,

  -- 1.0 = raw libinput scroll, no multiplier. This is exactly what Mutter
  -- does on your Ubuntu install -- GNOME has no scroll-speed setting at all,
  -- it just passes libinput's values straight through. Omarchy ships 0.4,
  -- which is why scrolling felt heavier here than there.
  scroll_factor = 1.0,

  -- Two-finger click = right click, anywhere on the pad, not a corner zone.
  clickfinger_behavior = true,

  tap_to_click = true,
  tap_and_drag = true,

  -- Back ON (libinput's default). This was switched off earlier to chase a
  -- macOS-like feel, but it is a real jitter source on a clickpad: with it
  -- off, a thumb or palm resting near the pad while you type registers as
  -- motion and the cursor twitches. Leave it on unless the pad going dead
  -- right after a keystroke bothers you more than the twitching does.
  disable_while_typing = true,
})

-- Same values globally, so behaviour degrades gracefully if the device name
-- ever changes (new kernel naming, external pad) and the block above stops
-- matching.
hl.config({
  input = {
    sensitivity = sensitivity,
    accel_profile = accel_profile,

    -- Mouse wheel. Hyprland's default is 1.0; slightly under gives finer
    -- steps without feeling slow.
    scroll_factor = 0.7,

    touchpad = {
      natural_scroll = true,
      scroll_factor = 1.0,
      clickfinger_behavior = true,
      disable_while_typing = true,
    },
  },
})

-- Terminals need a longer throw to move a useful number of lines. Omarchy
-- already sets scroll_touchpad for them; this covers the mouse wheel. Note a
-- per-window rule *replaces* the global factor above, it does not multiply it.
o.window("(Alacritty|kitty|foot)", { scroll_mouse = 1.0 })
