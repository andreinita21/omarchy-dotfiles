-- Monitor layout written by the Display panel (andrei.display shell plugin).
-- Pressing Apply in the panel regenerates this whole file, so hand edits
-- made here are lost on the next Apply.
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Any monitor not listed below (one plugged in later) gets sane defaults.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Dell Inc. DELL U2412M 0FFXD46G5CHS
hl.monitor({ output = "HDMI-A-1", mode = "1920x1200@59.95", position = "0x0", scale = 1, transform = 3 })

-- Samsung Electric Company Odyssey G85SD H1AK500000
hl.monitor({ output = "DP-1", mode = "3440x1440@174.96", position = "1200x0", scale = 1.25, transform = 0 })

-- Chimei Innolux Corporation 0x1471 (laptop panel; managed by the lid, rule kept as is)
hl.monitor({ output = "eDP-1", mode = "1920x1200@60.00", position = "1003x1152", scale = 1.25, transform = 0 })
