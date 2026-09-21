-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- HDMI monitor (Dell U2412M, 1920x1200) on the LEFT at 1x.
-- Logical width at 1x = 1920, so the right monitor starts at x=1920.
hl.monitor({ output = "HDMI-A-1", mode = "1920x1200@60", position = "0x0", scale = 1 })

-- USB-C main monitor (Dell G2724D, 2560x1440) on the RIGHT at 1.25x.
hl.monitor({ output = "DP-3", mode = "2560x1440@165", position = "1920x0", scale = 1.25 })
