-- Bar appearance mode, cycled with SUPER+CTRL+UP/DOWN by omarchy-bar-mode.
--
-- The bar itself paints its own background (see the cloned andrei.bar plugin);
-- the only part Hyprland owns is whether it blurs what is behind the bar's
-- layer surface. Layer rules are re-evaluated on config reload rather than on
-- the fly, so omarchy-bar-mode writes the state file below and then reloads,
-- which lands here. Reading the file at parse time also means the rule is
-- restored by any other reload instead of silently dropping out.

local mode = "transparent"
local handle = io.open(os.getenv("HOME") .. "/.local/state/omarchy/bar-mode", "r")

if handle then
  mode = handle:read("l") or mode
  handle:close()
end

if mode == "blur" then
  hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true })
end
