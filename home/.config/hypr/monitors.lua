-- Monitor layout written by the Display panel (andrei.display shell plugin).
-- Pressing Apply in the panel regenerates this whole file, so hand edits
-- made here are lost on the next Apply.
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Any monitor not listed below (one plugged in later) gets sane defaults.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Chimei Innolux Corporation 0x1471
hl.monitor({ output = "eDP-1", mode = "1920x1200@60.00", position = "853x1440", scale = 1.25, transform = 0 })

-- Samsung Electric Company Odyssey G85SD H1AK500000
hl.monitor({ output = "HDMI-A-1", mode = "modeline 542.02 3440 3488 3520 3600 1440 1443 1448 1510 +hsync -vsync", position = "0x0", scale = 1, transform = 0 })
