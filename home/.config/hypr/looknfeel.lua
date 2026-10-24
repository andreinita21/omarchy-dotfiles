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

-- BEGIN charlieras262.omablur
hl.config({
  decoration = {
    rounding = 20,
    active_opacity = 1.00,
    inactive_opacity = 1.00,
    blur = {
      enabled = true,
      size = 9,
      passes = 2,
      new_optimizations = true,
      ignore_opacity = true,
    },
  },
})
-- END charlieras262.omablur
-- BEGIN andrei.gaps
hl.config({
  general = {
    gaps_out = 4,
    gaps_in = 2,
  },
})
-- END andrei.gaps

-- BEGIN andrei.columns
-- Equal-width columns for the ultrawide: 1 window = full, 2 = halves,
-- 3 = thirds, 4 = quarters. Past 4 windows a new row starts, with windows
-- spread evenly across rows (5 = 3+2, 6 = 3+3, 7 = 4+3, 8 = 4+4, 9+ = 3 rows).
local max_columns = 4

hl.layout.register("columns", {
  recalculate = function(ctx)
    local n = #ctx.targets
    if n == 0 then
      return
    end

    local area = ctx.area
    local rows = math.ceil(n / max_columns)
    local row_h = area.h / rows
    local i = 1

    for row = 0, rows - 1 do
      -- Earlier rows take the extra window when n doesn't divide evenly.
      local cols = math.floor(n / rows) + (row < n % rows and 1 or 0)
      local col_w = area.w / cols

      for col = 0, cols - 1 do
        ctx.targets[i]:place({
          x = area.x + col * col_w,
          y = area.y + row * row_h,
          w = col_w,
          h = row_h,
        })
        i = i + 1
      end
    end
  end,
})

hl.config({
  general = {
    layout = "lua:columns",
  },
})
-- END andrei.columns
