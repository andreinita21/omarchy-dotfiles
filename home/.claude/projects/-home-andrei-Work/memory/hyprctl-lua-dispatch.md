---
name: hyprctl-lua-dispatch
description: "hyprctl dispatch on this machine takes Lua, not classic dispatcher syntax"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8435e878-0293-43fa-a623-9579906cb0c2
  modified: 2026-09-14T20:01:49.480Z
---

This machine's Hyprland (Omarchy 4.x) uses a Lua config, so `hyprctl dispatch` parses
its argument as Lua. Classic syntax like `hyprctl dispatch workspace 5` fails with
`')' expected near '5'` — and when the output is discarded it fails *silently*, leaving
the workspace unchanged.

Correct forms:

```bash
hyprctl dispatch 'hl.dsp.focus({ workspace = "5" })'
hyprctl dispatch 'hl.dsp.focus({ direction = "l" })'
```

**Why:** Cost a full round of broken desktop captures that silently ran against the
wrong workspace — see [[screenshot-workspaces]].

**How to apply:** Never discard stderr from `hyprctl dispatch`; check it succeeded.
Grep `/usr/share/omarchy/default/hypr/bindings/*.lua` for the right `hl.dsp.*` call.
