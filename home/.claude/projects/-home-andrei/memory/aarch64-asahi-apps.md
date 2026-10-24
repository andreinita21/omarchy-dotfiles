---
name: aarch64-asahi-apps
description: "Machine is aarch64 Asahi (ARM Mac) — no native Discord etc.; Chromium web-app windows get class \"Chromium\", match by title"
metadata:
  node_type: memory
  type: project
  originSessionId: 7acf021e-7842-4456-b5c0-eabbf7adce96
  modified: 2026-10-18T17:54:12.154Z
---

This Omarchy install (host markIV) is aarch64 on Asahi Linux. x86-only apps such as native Discord have no package at all (not in extra or AUR for aarch64), so the package search comes back empty.

**Why:** On 2026-10-18 the Discord install failed for this reason, and SUPER+D was switched to the discord.com/app web app.

**How to apply:** Run `uname -m` before installing a proprietary app, and offer a web app or an ARM-native client instead. Chromium `--app` windows open inside the running browser process with class "Chromium", not `chrome-<host>__-Default`, so `omarchy-launch-or-focus-webapp` must match by title (see the Discord bind in hypr/bindings.lua). The WhatsApp and Apple Music class-based binds probably never focus for the same reason. User doesn't use 1Password, so its shortcut was removed. Related: [[dotfiles-repo]]

GTK4 GPU rendering is broken on the experimental asahi_m4 driver (Vulkan hangs in drm_syncobj wait; GL fails DRM_IOCTL_ASAHI_QUEUE_CREATE). Fixed 2026-10-18 by forcing software rendering in ~/.config/hypr/hyprland.lua: GSK_RENDERER=cairo, GDK_DISABLE=gl,vulkan. Symptom: GTK4 app (e.g. Nautilus) process runs but never shows a window.
