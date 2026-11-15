-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.workspaces")
require("hypr.looknfeel")
require("hypr.barmode")
require("hypr.autostart")


-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Heaviest weight of the system font for the Omarchy menu (SUPER+SPACE).
-- JetBrains Mono tops out at ExtraBold (800). "JetBrainsMono Heavy" is a renamed
-- copy of that face (~/.local/share/fonts/JetBrainsMonoHeavy-Regular.ttf), so it
-- is the only weight Qt can pick. Needs `omarchy restart shell` to apply.
hl.env("OMARCHY_MENU_FONT", "JetBrainsMono Heavy")


-- GTK4 GPU rendering is broken on the experimental asahi_m4 GPU driver:
-- Vulkan hangs in a drm_syncobj wait and GL fails DRM_IOCTL_ASAHI_QUEUE_CREATE,
-- so Nautilus and other GTK4 apps never open a window. Render in software.
hl.env("GSK_RENDERER", "cairo")
hl.env("GDK_DISABLE", "gl,vulkan")

-- Browsers stay fully opaque whatever the Rounding & Blur window opacity is:
-- `override` sets the value outright instead of multiplying the global one.
-- Same classes Omarchy tags as browsers in default/hypr/apps/browser.lua.
o.window("((google-)?[cC]hrom(e|ium)|[bB]rave-browser|[mM]icrosoft-edge|Vivaldi-stable|helium|[fF]irefox|zen|librewolf)",
  { opacity = "1.0 override 1.0 override" })
