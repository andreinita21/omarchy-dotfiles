-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- SUPER+SHIFT+W was Omawrite by default; use it for WhatsApp instead.
hl.unbind("SUPER + SHIFT + W")
-- Match the Chromium app window by its exact window class. The { focus = true } sugar
-- would match the description ("WhatsApp") against every window CLASS *and TITLE*, so
-- any terminal/editor whose title happens to contain "WhatsApp" wins and gets focused.
o.bind("SUPER + SHIFT + W", "WhatsApp",
  "omarchy-launch-or-focus-webapp chrome-web.whatsapp.com__-Default 'https://web.whatsapp.com/'")

-- SUPER+SHIFT+C was Calendar by default; use it for a Claude Code terminal instead.
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Claude Code", {
  launch = "foot --app-id=org.omarchy.claude -D $HOME -e bash -lc 'claude --dangerously-skip-permissions'",
})

-- Zed. `-n/--new` asks the running Zed for an additional window, so every
-- press opens another one instead of focusing the existing window.
o.bind("SUPER + SHIFT + Z", "Zed", { launch = "zeditor --new" })

-- SUPER+SHIFT+M was Spotify; use the Apple Music web player instead.
-- Matched on the Chromium app window class rather than the description, so a
-- terminal or editor whose title contains "Apple Music" can't hijack it.
hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Apple Music",
  "omarchy-launch-or-focus-webapp chrome-music.apple.com__-Default 'https://music.apple.com/'")

-- Preinstalled app/webapp bindings I don't use.
hl.unbind("SUPER + SHIFT + E") -- was Email (HEY)
hl.unbind("SUPER + SHIFT + O") -- was Obsidian
hl.unbind("SUPER + SHIFT + P") -- was Google Photos
hl.unbind("SUPER + SHIFT + S") -- was Google Maps
hl.unbind("SUPER + SHIFT + D") -- was Docker TUI
hl.unbind("SUPER + SHIFT + G") -- was Signal
-- Note: SUPER+SHIFT+H was never bound by Omarchy, so there is nothing to remove.

-- SUPER+SHIFT+N was Omarchy's generic "Editor", which follows
-- ~/.local/state/omarchy/defaults/editor (currently zeditor). Bind it straight
-- to Neovim instead so it always opens LazyVim in a terminal, regardless of
-- what the system default editor is set to.
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Neovim", { tui = "nvim" })

-- Screenshot on SUPER+SHIFT+S since this keyboard has no PrtSc key
-- (SUPER+SHIFT+S was Google Maps, unbound above). Screensaver moves to
-- SUPER+CTRL+SHIFT+S. SUPER+SHIFT+L had no default binding; SUPER+CTRL+L
-- still locks too.
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")
o.bind("SUPER + CTRL + SHIFT + S", "Screensaver", "omarchy-launch-screensaver force")
o.bind("SUPER + SHIFT + L", "Lock screen", "omarchy-system-lock")

-- omadrop:bindings:start
hl.unbind("SUPER + SHIFT + V")
hl.unbind("SUPER + ALT + V")
o.bind("SUPER + SHIFT + V", "Omadrop", "/home/andrei/.local/bin/omadrop")
o.bind("SUPER + ALT + V", "Toggle Omadrop secondary display", "/home/andrei/.local/bin/omadrop --toggle-secondary")
o.window("projectm-ascii-live", { idle_inhibit = "always" })
-- omadrop:bindings:end

-- Cursor zoom bindings I don't use.
hl.unbind("SUPER + CTRL + Z")       -- was Zoom in
hl.unbind("SUPER + CTRL + ALT + Z") -- was Reset zoom

-- Cycle themes without opening the theme switcher. SUPER+SHIFT+CTRL+SPACE
-- still opens the theme menu; neither arrow combo was bound before.
o.bind("SUPER + CTRL + SHIFT + RIGHT", "Next theme", "/home/andrei/.local/bin/omarchy-theme-cycle next")
o.bind("SUPER + CTRL + SHIFT + LEFT", "Previous theme", "/home/andrei/.local/bin/omarchy-theme-cycle prev")

-- Cycle the current theme's wallpapers. SUPER+CTRL+LEFT/RIGHT was "Move grouped
-- window focus left/right" by default.
hl.unbind("SUPER + CTRL + RIGHT")
hl.unbind("SUPER + CTRL + LEFT")
o.bind("SUPER + CTRL + RIGHT", "Next wallpaper", "/home/andrei/.local/bin/omarchy-bg-cycle next")
o.bind("SUPER + CTRL + LEFT", "Previous wallpaper", "/home/andrei/.local/bin/omarchy-bg-cycle prev")

-- Cycle the top bar between transparent / blur / OLED black. Neither combo was
-- bound before (SUPER+UP/DOWN and SUPER+SHIFT+UP/DOWN keep their defaults).
o.bind("SUPER + CTRL + UP", "Next bar mode", "/home/andrei/.local/bin/omarchy-bar-mode next")
o.bind("SUPER + CTRL + DOWN", "Previous bar mode", "/home/andrei/.local/bin/omarchy-bar-mode prev")

-- SUPER+SHIFT+SPACE toggles the bar through omarchy-bar-toggle, which pushes
-- the new state to the bar directly; the stock omarchy-toggle-bar relies on a
-- file probe that could get out of sync on rapid presses.
hl.unbind("SUPER + SHIFT + SPACE")
o.bind("SUPER + SHIFT + SPACE", "Toggle top bar", "/home/andrei/.local/bin/omarchy-bar-toggle")
