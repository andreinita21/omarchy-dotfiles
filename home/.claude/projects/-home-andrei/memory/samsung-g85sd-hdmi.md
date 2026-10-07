---
name: samsung-g85sd-hdmi
description: "Samsung Odyssey G85SD (34\" 3440x1440) on the T14 Gen 5 HDMI port needs a custom modeline; its EDID only lists 16:9 modes"
metadata:
  node_type: memory
  type: project
  originSessionId: af0a3f64-f211-4381-95e4-eebaf00295d0
  modified: 2026-10-07T13:58:18.872Z
---

The user's Samsung Odyssey G85SD ultrawide is on HDMI-A-1 of the ThinkPad T14 Gen 5. Over
HDMI its EDID tops out at 2560x1440, so 3440x1440 is set with a custom reduced-blanking modeline
(`modeline 542.78 3440 3488 3520 3600 1440 1443 1448 1510 +hsync -vsync`, ~99.7 Hz) in
~/.config/hypr/monitors.lua. `3440x1440@100` as a plain mode is rejected (falls back to
2560x1440@120); ~100 Hz is the ceiling under the 600 MHz HDMI TMDS limit. 120 Hz+ needs USB-C to DP.

As of 2026-10-07, the omamonitor plugin ([[omarchy-shell-plugin-dev]]) emits a CVT-RB modeline
from `modeString()` in Model.js for any mode missing from the EDID list, and write-monitors.py accepts it.

**Why:** Theme changes reload Hyprland, so any monitors.lua that lacks the modeline makes the monitor stretched again.

**How to apply:** Keep the modeline in monitors.lua; the monitor goes black for a few seconds while it syncs a new mode.
