---
name: screenshot-workspaces
description: Use Hyprland workspaces 4 and 5 when taking desktop screenshots on this machine
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8435e878-0293-43fa-a623-9579906cb0c2
  modified: 2026-09-14T20:01:42.441Z
---

When taking desktop screenshots on this machine, use workspaces 4 and 5 — they are
kept empty. Workspaces 1-3 hold the user's live apps (editor, browser, Claude Code
sessions).

**Why:** A first attempt captured the user's actual session — their editor, source
code, and a running Claude Code terminal — which would have been published to a
public repo. The user then specified workspaces 4 and 5 explicitly.

**How to apply:** Switch with `hyprctl dispatch 'hl.dsp.focus({ workspace = "4" })'`
(see [[hyprctl-lua-dispatch]]), spawn the windows there, and verify via
`hyprctl clients -j` that every window on the target workspace belongs to a PID you
spawned before calling `grim`. Also avoid issuing unrelated shell commands during a
capture run — terminal activation pulls focus back to the session's own workspace.
For fastfetch, give it the full screen alone: the user has a custom fastfetch icon
they want visible.
