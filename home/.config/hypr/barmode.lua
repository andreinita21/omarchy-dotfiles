-- Bar appearance mode, cycled with SUPER+CTRL+UP/DOWN by omarchy-bar-mode.
--
-- The bar paints its own background (see the andrei.bar plugin); Hyprland only
-- blurs what is behind it. The rule is always on and keyed on alpha instead of
-- on the mode, so switching modes never needs a `hyprctl reload` (a reload
-- re-applies monitors and workspaces, which made the whole screen jump):
--   transparent  background alpha 0     -> below ignore_alpha, no blur
--   blur         dark scrim, alpha 0.45 -> blurred
--   oled         opaque black           -> nothing shows through anyway
hl.layer_rule({
  match = { namespace = "^omarchy-bar$" },
  blur = true,
  ignore_alpha = 0.3,
})
