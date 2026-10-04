<div align="center">

# omarchy-dotfiles

**A reproducible [Omarchy](https://omarchy.org) desktop, from a fresh install to a finished setup with one command.**

![Omarchy](https://img.shields.io/badge/Omarchy-4.x-7aa2f7?style=flat-square)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-Lua_config-58E1FF?style=flat-square)
![Shell](https://img.shields.io/badge/installer-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)

</div>

---

## Overview

This repository holds the complete configuration of my Omarchy workstation:
settings, installed software, system tweaks and desktop state. A single
idempotent script, [`dot`](dot), restores all of it on another machine and keeps
multiple machines in sync.

Configuration files are **symlinked** from this repository into `$HOME`, so an
edit made anywhere is already under version control. Anything that can't be
symlinked (packages, services, `/etc` files, GTK settings, the active theme) is
**snapshotted** into plain-text lists that the installer replays.

## Highlights

- **Custom Omarchy shell.** A forked status bar with transparent, blur and OLED
  modes; custom workspaces; background, gaps and rounding/blur plugins; a heavy
  ExtraBold UI font for the bar and launcher.
- **Custom themes.** `neon-purple` and `cookie-monster`, plus a user-defined theme
  order, theme and wallpaper cycling keybinds, and animated transitions.
- **Tuned Hyprland.** Keybindings, input curve, multi-monitor layout, hyprsunset
  and workspace layouts.
- **Shell.** Bash with [ble.sh](https://github.com/akinomyoga/ble.sh)
  autosuggestions, a theme-aware Starship prompt, and a fastfetch greeting that
  picks a random ASCII logo tinted to the active theme.
- **Tooling.** Neovim (LazyVim), Zed, Ghostty, Kitty, Alacritty and Foot, lazygit,
  tmux, and mise-managed runtimes and AI coding agents.
- **Lean system.** Unused default apps, web apps and stock themes are removed,
  and they stay removed after updates.

## Quick start

On a freshly installed Omarchy system, signed in as your normal user:

```bash
git clone https://github.com/andreinita21/omarchy-dotfiles.git ~/dotfiles
~/dotfiles/dot install
```

You'll be asked for your `sudo` password once. The installer is **idempotent**:
if a step fails (a network hiccup, a mirror timeout), just run it again. When it
finishes it prints the few steps that can't be automated. Reboot afterwards.

### What `install` does

| # | Step | Source |
|---|------|--------|
| 1 | Hides the removed stock themes via pacman `NoExtract` and deletes them | `omarchy/themes-remove.txt` |
| 2 | Installs every explicitly installed package, official and AUR | `packages/pacman.txt`, `packages/aur.txt` |
| 3 | Uninstalls the Omarchy defaults that were removed | `packages/remove.txt` |
| 4 | Restores tracked `/etc` files and enables system services | `system/` |
| 5 | Symlinks every tracked config into `$HOME`, backing up what was there | `links.txt` → `home/` |
| 6 | Rewrites absolute home paths if your username differs | `.source-home` |
| 7 | Clones third-party themes and shell plugins, builds the AirPods daemon | `omarchy/git-clones.txt` |
| 8 | Installs mise tools, ble.sh, rustup and omadrop | [`dot`](dot) |
| 9 | Removes the deleted default web apps, loads GTK settings, applies theme and wallpaper | `omarchy/apps-remove.txt`, `dconf.ini`, `state/` |
| 10 | Offers to restore the encrypted private vault (see below) | private repo `omarchy-vault` |

Files replaced during linking are moved to
`~/.local/state/dotfiles-backup/<timestamp>/`. Nothing is overwritten in place.

## Everyday use

Because configs are symlinks, edits land in the repository as you make them.
To also capture package and system changes and publish them:

```bash
cd ~/dotfiles
./dot sync                      # snapshot packages, services, GTK + Omarchy state
git add -A && git commit -m "Describe the change"
git push
```

On another machine: `git pull && ./dot install`.

## Private vault (accounts and sessions)

Everything that can't be public lives in an **encrypted vault** kept in a
separate *private* repository (`andreinita21/omarchy-vault`). This repository
only holds the lists of what goes in it (`vault/`).

| In the vault | Why |
|---|---|
| GNOME keyring | GitHub CLI token, Chromium's cookie key, Zed login |
| Chromium profile (minus caches) | logged-in sites, saved passwords, tabs, history, extensions, WhatsApp Web |
| Claude Code, Codex, Hermes, Pi | logins, conversation history, plugins |
| `~/.ssh`, `~/.gnupg`, `.netrc`, cloud CLIs | keys and tokens, when present |
| Zed, LocalSend, zoxide, bash history | app state and sessions |
| Wi-Fi networks, Bluetooth pairings | from `/etc` and `/var/lib` (needs sudo) |
| List of git repos in `$HOME` | lets `./dot vault repos` re-clone your projects (no local files are stored) |

```bash
./dot vault save            # pack, encrypt (asks for a passphrase), push
./dot vault save /mnt/usb   # or write to a directory instead
./dot vault restore         # download, decrypt and restore (run by install)
```

The vault is encrypted with GPG (AES256, a passphrase you choose) **and** stored
in a private repo. Each save replaces the previous snapshot instead of adding to
git history. Close your browser before saving. Bluetooth pairings only work
again on the same machine, because the keys are tied to the adapter.

### Commands

| Command | Description |
|---------|-------------|
| `./dot install` | Full, re-runnable restore on a fresh Omarchy machine |
| `./dot sync` | Refresh all snapshots, repair broken links, run the secret scan |
| `./dot link` | (Re)create the symlinks only |
| `./dot adopt` | Start tracking a new path: add it to `links.txt`, then run this |
| `./dot status` | Show linked, missing or diverged paths and pending changes |
| `./dot vault save\|restore\|repos` | Encrypted private state (see above) |

> Some applications save by replacing a file instead of writing through the
> symlink. `./dot sync` detects this, pulls the newer file into the repository
> and restores the link.

## Repository layout

```text
.
├── dot                  # installer / sync tool
├── links.txt            # paths symlinked from home/ into $HOME
├── home/                # mirror of $HOME for everything in links.txt
│   ├── .config/hypr/        Hyprland: bindings, input, monitors, look & feel
│   ├── .config/omarchy/     shell.json, menu, plugins, hooks, themes, backgrounds
│   ├── .config/…            terminals, editors, prompt, CLI tools
│   └── .local/bin/          personal scripts used by keybinds and the menu
├── packages/            # pacman.txt · aur.txt · remove.txt
├── omarchy/             # git-cloned extras · removed launchers · hidden themes
├── state/               # active theme, wallpaper, bar mode, transitions
├── system/              # enabled systemd units and tracked /etc files
└── dconf.ini            # GTK / GNOME settings
```

## Adapting to your hardware

A few files describe this specific machine (a Lenovo ThinkPad T14 Gen 5) and
should be reviewed on different hardware:

- **`home/.config/hypr/monitors.lua`**: output names, resolutions and scaling.
- **`system/etc/nbfc/`**: fan-control profile for the T14 Gen 5. Pick another
  profile with `nbfc config -s` or remove the file.
- **CPU and GPU packages** (`intel-ucode`, `vulkan-intel`, `intel-lpmd`,
  `thermald`): swap them for your platform's equivalents in `packages/pacman.txt`.

## Security

This repository is public and contains **no credentials**. SSH and GPG keys,
browser profiles, and CLI logins (GitHub, Claude, Codex) live only in the
encrypted private vault described above.

`./dot sync` scans every tracked file for token and private-key patterns and
fails loudly if it finds one. Files that must stay local inside a tracked
directory can be listed in the secrets section of the generated `.gitignore`
(defined in `dot`).

## Credits

Built on [Omarchy](https://github.com/basecamp/omarchy) by DHH and contributors.
Third-party pieces installed by the setup script:

| Project | Author |
|---------|--------|
| [omarchy-matrix-theme](https://github.com/BVisagie/omarchy-matrix-theme) | BVisagie |
| [omarchy-neon-dusk-theme](https://github.com/daniel-felipe/omarchy-neon-dusk-theme) | daniel-felipe |
| [omarchy-omablur](https://github.com/Charlieras262/omarchy-omablur) | Charlieras262 |
| [Omarchy-music-flow](https://github.com/Clifford-Baidoo/Omarchy-music-flow) | Clifford-Baidoo |
| [omarchy-pods](https://github.com/thisisgm/omarchy-pods) | thisisgm |
| [omarchy-nbfc-linux-plugin](https://github.com/kshatriya-abhay/omarchy-nbfc-linux-plugin) | kshatriya-abhay |
| [omadrop](https://github.com/btsouth/omadrop) | btsouth |
| [ble.sh](https://github.com/akinomyoga/ble.sh) | akinomyoga |

Each remains under its own license.
