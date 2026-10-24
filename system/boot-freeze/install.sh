#!/bin/bash
# Installs boot-freeze and freezes the current boot chain. Run it only while
# the machine is booted from a boot chain known to work.
set -euo pipefail
cd "$(dirname "$0")"
sudo install -Dm755 boot-freeze /usr/local/sbin/boot-freeze
sudo install -Dm644 00-boot-freeze-guard.hook /etc/pacman.d/hooks/00-boot-freeze-guard.hook
sudo install -Dm644 zz-boot-freeze-enforce.hook /etc/pacman.d/hooks/zz-boot-freeze-enforce.hook
[[ -d /var/lib/boot-freeze/golden ]] || sudo /usr/local/sbin/boot-freeze save
sudo /usr/local/sbin/boot-freeze status
