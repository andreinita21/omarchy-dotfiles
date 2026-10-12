-- Monitor layout written by the Omamonitor panel (andreinita21.omamonitor).
-- Every change in the panel regenerates this whole file, so hand edits
-- made here are lost on the next change. External displays are matched
-- by description (desc:), so each rule follows its monitor, not the port.
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Any monitor not listed below (one plugged in later) gets sane defaults.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Dell Inc. DELL G2724D FS5B4V3
hl.monitor({ output = "desc:Dell Inc. DELL G2724D FS5B4V3", mode = "2560x1440@165.08", position = "0x0", scale = 1.25, transform = 0 })

-- Chimei Innolux Corporation 0x1471
hl.monitor({ output = "eDP-1", mode = "1920x1200@60.00", position = "2048x192", scale = 1.25, transform = 0 })

-- Displays not connected when this was written; kept for when they return.

-- Dell Inc. DELL U2412M 0FFXD46G5CHS
hl.monitor({ output = "desc:Dell Inc. DELL U2412M 0FFXD46G5CHS", mode = "1920x1200@59.95", position = "0x0", scale = 1, transform = 3 })

-- Samsung Electric Company Odyssey G85SD H1AK500000
hl.monitor({ output = "desc:Samsung Electric Company Odyssey G85SD H1AK500000", mode = "3440x1440@174.96", position = "1200x0", scale = 1.25, transform = 0 })
