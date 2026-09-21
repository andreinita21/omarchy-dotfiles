-- Per-monitor workspaces.
--
-- Each external monitor owns its own block of 5 workspaces, and SUPER+1..5
-- always means "workspace 1..5 of the monitor I'm on":
--
--   DP-3     (Dell G2724D, right/main)  SUPER+1..5 -> workspaces 1-5
--   HDMI-A-1 (Dell U2412M, left)        SUPER+1..5 -> workspaces 6-10
--
-- SUPER+6..0 reaches the other monitor's workspaces (on DP-3 they are 6-10,
-- on HDMI they are 1-5). On any other screen (the laptop panel when undocked)
-- SUPER+1..0 map straight to workspaces 1-10, so everything stays reachable.
--
-- Unplugging a monitor lets Hyprland gather its workspaces onto whatever
-- screen remains. When the monitor comes back, every workspace that still
-- exists is moved back onto the monitor that owns it, and each monitor
-- returns to the workspace it was showing before it was unplugged.

local per_monitor = 5
local total = 10

local owners = {
  { monitor = "DP-3", first = 1 },
  { monitor = "HDMI-A-1", first = 6 },
}

local owner_of = {} -- workspace id -> monitor name
local first_of = {} -- monitor name -> first workspace id

for _, owner in ipairs(owners) do
  first_of[owner.monitor] = owner.first
  for id = owner.first, owner.first + per_monitor - 1 do
    owner_of[id] = owner.monitor
    hl.workspace_rule({ workspace = tostring(id), monitor = owner.monitor, default = id == owner.first })
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

-- Remember which workspace each owned monitor was showing, so it can be
-- restored after an unplug/replug.
-- Empty workspaces aren't worth returning to, and recording is paused while a
-- replug is being restored so the placeholder workspace a reconnected monitor
-- starts on doesn't overwrite the one it was showing.
local last_active = {}
local restoring = false

local function remember_active()
  if restoring then
    return
  end

  for _, monitor in ipairs(hl.get_monitors()) do
    local workspace = first_of[monitor.name] and hl.get_active_workspace(monitor.name)
    if workspace and workspace.windows > 0 and owner_of[workspace.id] == monitor.name then
      last_active[monitor.name] = workspace.id
    end
  end
end

remember_active()
hl.on("workspace.active", remember_active)

local function connected(name)
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name == name then
      return true
    end
  end
  return false
end

local function restore_workspaces()
  local focused = hl.get_active_monitor()
  local moved = {}

  for _, workspace in ipairs(hl.get_workspaces()) do
    local owner = owner_of[workspace.id]
    if owner and connected(owner) and workspace.monitor and workspace.monitor.name ~= owner then
      hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(workspace.id), monitor = owner }))
      moved[owner] = true
    end
  end

  if not next(moved) then
    return
  end

  for name in pairs(moved) do
    local id = last_active[name]
    local workspace = id and hl.get_workspace(tostring(id))
    if workspace and workspace.monitor and workspace.monitor.name == name then
      hl.dispatch(hl.dsp.focus({ workspace = tostring(id) }))
    end
  end

  if focused and connected(focused.name) then
    hl.dispatch(hl.dsp.focus({ monitor = focused.name }))
  end
end

-- Omarchy's clamshell handling toggles the laptop panel for a few seconds
-- after a hotplug, so restore once it has settled and again as a backstop.
hl.on("monitor.added", function()
  restoring = true
  hl.timer(restore_workspaces, { timeout = 1500, type = "oneshot" })
  hl.timer(function()
    restore_workspaces()
    restoring = false
    remember_active()
  end, { timeout = 8000, type = "oneshot" })
end)
