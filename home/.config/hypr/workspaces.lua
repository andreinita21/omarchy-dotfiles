-- Per-monitor workspaces.
--
-- Workspaces come in two blocks of 5 (1-5 and 6-10), and SUPER+1..5 always
-- means "workspace 1..5 of the monitor I'm on". SUPER+6..0 reaches the other
-- block. Blocks belong to monitors, not ports, so a monitor keeps its block
-- whichever USB-C/HDMI port it is plugged into:
--
--   Main monitor (Dell G2724D or Samsung G85SD)  -> workspaces 1-5
--   Second monitor (Dell U2412M)                  -> workspaces 6-10
--
-- Any other external monitor takes the first free block, and while docked
-- the laptop panel takes whatever block is left. With no external monitor
-- the laptop has no block and SUPER+1..0 map straight to workspaces 1-10.
--
-- Whenever a monitor comes or goes the blocks are handed out again: every
-- workspace that still exists moves to the monitor that owns it, a monitor
-- showing a workspace it does not own (a stray one Hyprland made for it)
-- switches to its own, and each monitor returns to the workspace it was
-- showing before it was unplugged.

local per_monitor = 5
local total = 10
local blocks = { 1, 6 }

-- Monitor description -> preferred first workspace. Ties (both main
-- monitors connected at once) go to whichever is further left.
local preferred = {
  ["Dell Inc. DELL G2724D FS5B4V3"] = 1,
  ["Samsung Electric Company Odyssey G85SD H1AK500000"] = 1,
  ["Dell Inc. DELL U2412M 0FFXD46G5CHS"] = 6,
}

local owner_of = {} -- workspace id -> monitor name
local first_of = {} -- monitor name -> first workspace id
local rules = {} -- workspace rules currently in force
local assigned = nil -- signature of the current assignment

local function is_internal(name)
  return name:match("^eDP%-") or name:match("^LVDS%-") or name:match("^DSI%-")
end

local function connected(name)
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name == name then
      return true
    end
  end
  return false
end

-- The bar's workspace widget (andrei.workspaces) numbers each monitor's
-- buttons from this file: monitor name -> offset of its block.
local function publish()
  local runtime = os.getenv("XDG_RUNTIME_DIR")
  if not runtime then
    return
  end
  local parts = {}
  for name, first in pairs(first_of) do
    parts[#parts + 1] = string.format("%q:%d", name, first - 1)
  end
  local path = runtime .. "/omarchy-workspace-blocks.json"
  local file = io.open(path .. ".tmp", "w")
  if not file then
    return
  end
  file:write("{" .. table.concat(parts, ",") .. "}\n")
  file:close()
  os.rename(path .. ".tmp", path)
end

local function assign()
  local monitors = hl.get_monitors()
  local externals, internals = {}, {}
  for _, monitor in ipairs(monitors) do
    if is_internal(monitor.name) then
      internals[#internals + 1] = monitor
    else
      externals[#externals + 1] = monitor
    end
  end
  table.sort(externals, function(a, b)
    if a.x ~= b.x then
      return a.x < b.x
    end
    return a.name < b.name
  end)

  local taken = {}
  first_of = {}
  local function give(monitor, first)
    first_of[monitor.name] = first
    taken[first] = true
  end
  local function free_block()
    for _, first in ipairs(blocks) do
      if not taken[first] then
        return first
      end
    end
  end

  for _, monitor in ipairs(externals) do
    local want = preferred[monitor.description or ""]
    if want and not taken[want] then
      give(monitor, want)
    end
  end
  for _, monitor in ipairs(externals) do
    local first = not first_of[monitor.name] and free_block()
    if first then
      give(monitor, first)
    end
  end
  if #externals > 0 then
    for _, monitor in ipairs(internals) do
      local first = free_block()
      if first then
        give(monitor, first)
      end
    end
  end

  local names = {}
  for name, first in pairs(first_of) do
    names[#names + 1] = name .. "=" .. first
  end
  table.sort(names)
  local signature = table.concat(names, ",")
  if signature == assigned then
    return
  end
  assigned = signature
  publish()

  for _, rule in ipairs(rules) do
    rule:set_enabled(false)
  end
  rules = {}
  owner_of = {}
  for name, first in pairs(first_of) do
    for id = first, first + per_monitor - 1 do
      owner_of[id] = name
      rules[#rules + 1] = hl.workspace_rule({ workspace = tostring(id), monitor = name, default = id == first })
    end
  end
end

-- Key N (1..10) on the focused monitor -> real workspace id.
local function target(key)
  local monitor = hl.get_active_monitor()
  local offset = monitor and first_of[monitor.name] and first_of[monitor.name] - 1 or 0
  return tostring((offset + key - 1) % total + 1)
end

for key = 1, total do
  local code = "code:" .. tostring(key + 9)
  local label = key % total

  hl.unbind("SUPER + " .. code)
  hl.unbind("SUPER + SHIFT + " .. code)
  hl.unbind("SUPER + SHIFT + ALT + " .. code)

  o.bind("SUPER + " .. code, "Switch to monitor workspace " .. label, function()
    hl.dispatch(hl.dsp.focus({ workspace = target(key) }))
  end)
  o.bind("SUPER + SHIFT + " .. code, "Move window to monitor workspace " .. label, function()
    hl.dispatch(hl.dsp.window.move({ workspace = target(key) }))
  end)
  o.bind("SUPER + SHIFT + ALT + " .. code, "Move window silently to monitor workspace " .. label, function()
    hl.dispatch(hl.dsp.window.move({ workspace = target(key), follow = false }))
  end)
end

-- Remember which workspace each monitor was showing (keyed by description,
-- so it survives a port change), to restore it after an unplug/replug.
-- Empty workspaces aren't worth returning to, and recording is paused while
-- a replug is being restored so the placeholder workspace a reconnected
-- monitor starts on doesn't overwrite the one it was showing.
local last_active = {}
local restoring = false

local function remember_active()
  if restoring then
    return
  end

  for _, monitor in ipairs(hl.get_monitors()) do
    local workspace = first_of[monitor.name] and hl.get_active_workspace(monitor.name)
    if workspace and workspace.windows > 0 and owner_of[workspace.id] == monitor.name then
      last_active[monitor.description or monitor.name] = workspace.id
    end
  end
end

local function restore_workspaces()
  assign()
  local focused = hl.get_active_monitor()

  for _, workspace in ipairs(hl.get_workspaces()) do
    local owner = owner_of[workspace.id]
    if owner and connected(owner) and workspace.monitor and workspace.monitor.name ~= owner then
      hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(workspace.id), monitor = owner }))
    end
  end

  -- Each monitor with a block shows one of its own workspaces.
  for _, monitor in ipairs(hl.get_monitors()) do
    local first = first_of[monitor.name]
    local active = first and hl.get_active_workspace(monitor.name)
    if first and not (active and owner_of[active.id] == monitor.name) then
      local id = last_active[monitor.description or monitor.name]
      if not (id and owner_of[id] == monitor.name) then
        id = first
      end
      hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
      hl.dispatch(hl.dsp.focus({ workspace = tostring(id) }))
    end
  end

  if focused and connected(focused.name) then
    hl.dispatch(hl.dsp.focus({ monitor = focused.name }))
  end
end

assign()
remember_active()
hl.on("workspace.active", remember_active)

-- Omarchy's clamshell handling toggles the laptop panel for a few seconds
-- after a hotplug, so restore once it has settled and again as a backstop.
local function on_monitors_changed()
  restoring = true
  hl.timer(restore_workspaces, { timeout = 1500, type = "oneshot" })
  hl.timer(function()
    restore_workspaces()
    restoring = false
    remember_active()
  end, { timeout = 8000, type = "oneshot" })
end

hl.on("monitor.added", on_monitors_changed)
hl.on("monitor.removed", on_monitors_changed)

-- Also settle right away after a config reload (this file runs again then).
hl.timer(restore_workspaces, { timeout = 500, type = "oneshot" })
