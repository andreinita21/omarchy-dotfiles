-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- BEGIN andrei.gaps
hl.config({
  general = {
    gaps_out = 4,
    gaps_in = 2,
  },
})
-- END andrei.gaps

-- BEGIN andrei.columns
-- Columns for the ultrawide: 1 window = full, 2 = halves, 3 = thirds,
-- 4 = quarters. Past 4 windows a new row starts, with windows spread evenly
-- across rows (5 = 3+2, 6 = 3+3, 7 = 4+3, 8 = 4+4, 9+ = 3 rows).
--
-- Columns start out equal but can be resized. Hyprland's Lua layouts get no
-- resize callback (only recalculate and layout_msg), so the normal resize
-- dispatcher is silently ignored on tiled windows here. Instead each window
-- keeps a width weight and a height weight, which the "resize dx dy" layout
-- message adjusts; see the resize bindings in bindings.lua.
-- Mouse drag-resize (SUPER + right drag) only works on floating windows.
local max_columns = 4
local min_size = 150 -- px, smallest a resize can make a column or row

local weights = {} -- window address -> { w = width weight, h = height weight }

local function weight(target)
  local address = target.window and target.window.address
  if not address then
    return { w = 1, h = 1 }
  end
  weights[address] = weights[address] or { w = 1, h = 1 }
  return weights[address]
end

-- Rows of target indices; earlier rows take the extra window when n doesn't
-- divide evenly.
local function rows_of(n)
  local count = math.ceil(n / max_columns)
  local rows, i = {}, 1
  for row = 0, count - 1 do
    local cols = math.floor(n / count) + (row < n % count and 1 or 0)
    local members = {}
    for _ = 1, cols do
      members[#members + 1] = i
      i = i + 1
    end
    rows[#rows + 1] = members
  end
  return rows
end

local function row_weight(ctx, members)
  local sum = 0
  for _, i in ipairs(members) do
    sum = sum + weight(ctx.targets[i]).h
  end
  return sum / #members
end

local function place(ctx)
  local n = #ctx.targets
  if n == 0 then
    return
  end

  local area = ctx.area
  local rows = rows_of(n)

  local row_total = 0
  for _, members in ipairs(rows) do
    row_total = row_total + row_weight(ctx, members)
  end

  local y = area.y
  for _, members in ipairs(rows) do
    local h = area.h * row_weight(ctx, members) / row_total

    local col_total = 0
    for _, i in ipairs(members) do
      col_total = col_total + weight(ctx.targets[i]).w
    end

    local x = area.x
    for _, i in ipairs(members) do
      local w = area.w * weight(ctx.targets[i]).w / col_total
      ctx.targets[i]:place({ x = x, y = y, w = w, h = h })
      x = x + w
    end
    y = y + h
  end
end

-- Weight that gives one share `size` px out of `total` px, keeping the other
-- shares' weights (summing to `others`) as they are.
local function solve(size, total, others, count)
  size = math.max(min_size, math.min(size, total - min_size * count))
  return size * others / (total - size)
end

local function resize(ctx, dx, dy)
  local active
  for i, target in ipairs(ctx.targets) do
    if target.window and target.window.active then
      active = i
    end
  end
  if not active then
    return false
  end

  local area = ctx.area
  local rows = rows_of(#ctx.targets)

  for r, members in ipairs(rows) do
    for _, i in ipairs(members) do
      if i == active then
        if dx ~= 0 and #members > 1 then
          local mine, others = weight(ctx.targets[i]).w, 0
          for _, j in ipairs(members) do
            if j ~= i then
              others = others + weight(ctx.targets[j]).w
            end
          end
          local current = area.w * mine / (mine + others)
          weight(ctx.targets[i]).w = solve(current + dx, area.w, others, #members - 1)
        end

        if dy ~= 0 and #rows > 1 then
          local mine, others = row_weight(ctx, members), 0
          for k, other in ipairs(rows) do
            if k ~= r then
              others = others + row_weight(ctx, other)
            end
          end
          local current = area.h * mine / (mine + others)
          local new = solve(current + dy, area.h, others, #rows - 1)
          for _, j in ipairs(members) do
            weight(ctx.targets[j]).h = new
          end
        end
      end
    end
  end

  place(ctx)
  return true
end

hl.layout.register("columns", {
  recalculate = place,

  -- "resize <dx> <dy>"  grow (+) or shrink (-) the active window, in px
  -- "reset"             back to equal columns and rows on this workspace
  layout_msg = function(ctx, msg)
    local dx, dy = msg:match("^resize%s+(-?%d+)%s+(-?%d+)$")
    if dx then
      return resize(ctx, tonumber(dx), tonumber(dy))
    end
    if msg == "reset" then
      for _, target in ipairs(ctx.targets) do
        if target.window then
          weights[target.window.address] = nil
        end
      end
      place(ctx)
      return true
    end
    return "columns: unknown message '" .. msg .. "'"
  end,
})

hl.config({
  general = {
    layout = "lua:columns",
  },
})
-- END andrei.columns
