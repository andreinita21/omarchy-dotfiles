---
name: boot-freeze
description: boot-freeze guards the custom gravity kernel/m1n1/U-Boot boot chain during omarchy update; unlock/lock to change it on purpose
metadata:
  node_type: memory
  type: project
  originSessionId: 4662ff2a-41b3-4b6a-b83b-30cb5a51f255
  modified: 2026-10-19T05:09:29.026Z
---

Since 2026-10-19 `/usr/local/sbin/boot-freeze` (source + install.sh in ~/dotfiles/system/boot-freeze) protects the M4 mini's custom boot chain (linux-gravity-m4, m1n1-gravity, uboot-gravity — not Asahi). `/etc/pacman.d/hooks/00-boot-freeze-guard.hook` aborts any transaction touching linux*/m1n1*/uboot*/mesa-gravity-m4/omarchy-j773g; `zz-boot-freeze-enforce.hook` and `~/.config/omarchy/hooks/post-update.d/boot-freeze.hook` restore frozen files (m1n1 boot.bin, Limine EFI, UKI, /boot vmlinuz+initramfs, /etc/m1n1.conf, limine.conf kernel lines) from `/var/lib/boot-freeze/golden`. IgnorePkg in pacman.conf also pins those packages.

**Why:** Omarchy updates/migrations would otherwise rebuild initramfs/UKI/m1n1 or pull linux-asahi and break the custom drivers.
**How to apply:** to change the kernel, initramfs config or cmdline on purpose: `sudo boot-freeze unlock` → change → reboot-test → `sudo boot-freeze lock` (re-freezes). `sudo boot-freeze status` shows drift. Related: [[dotfiles-repo]], [[aarch64-asahi-apps]].
