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

## Branches

Each machine has its own branch. Every branch has the same configs, but its
package lists, services, `/etc` files and desktop state come from that one
machine.

| Branch | Machine | Notes |
|--------|---------|-------|
| [`main`](../../tree/main) | Apple M4 Mac (Asahi / Apple Silicon) | asahi packages, gravity kernel, m1n1/U-Boot |
| [`thinkpad-t14-gen5`](../../tree/thinkpad-t14-gen5) | Lenovo ThinkPad T14 Gen 5 (x86, Omarchy 4.5) | Intel packages; stock Omarchy lock/idle/background; safe `./restore` |

Rules of thumb:

- **Clone the branch for the machine you are on.** Running `./dot sync` writes
  *that machine's* package and service lists, so syncing on the wrong branch
  overwrites the other machine's snapshot.
- **Shared config fixes go to both.** Make the change on one branch, then
  `git cherry-pick` it onto the other. Never merge one machine branch into
  another, because that mixes their package lists.
- **New hardware means a new branch.** Branch from whichever machine is
  closest, set up with `./restore` (or `./dot install`), then run `./dot sync`
  and push the branch.

## Highlights

- **Custom Omarchy shell.** A forked status bar with transparent, blur and OLED
  modes; custom workspaces; gaps and rounding/blur plugins; a heavy
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
# pick the branch for your machine (see Branches above)
git clone -b thinkpad-t14-gen5 https://github.com/andreinita21/omarchy-dotfiles.git ~/dotfiles
~/dotfiles/dot install
```

On this branch `./dot install` runs [`./restore`](restore), which restores
exactly this ThinkPad setup and nothing else:

- configs and scripts from `links.txt` (Hyprland, terminals, nvim, bash, ...)
- shell plugins `andrei.bar`, `andrei.workspaces`, `andrei.gaps`,
  `andrei.rounding-blur`, `andreinita21.omamonitor`, `custom.media`
- themes `andrei-nita`, `cookie-monster`, `neon-purple`, `ocult-records`,
  `osaka-jade` (kept here because Omarchy 4.5 replaced it with Jade Horse),
  `matrix`, `neon-dusk` and the stock `jade-horse`, `starship`, `tokyo-night`;
  every other stock theme is hidden via pacman `NoExtract`
- ble.sh for terminal autosuggestions

Packages, dev tooling (mise, rustup) and dconf are asked about, default no.

### Safety: never get locked out again

This machine was locked out three times by earlier restores, so `./restore`:

- keeps **Omarchy's own lock, idle and background** in charge (the old
  `andrei.lock` / `andrei.idle` / `andrei.background` forks are gone);
- never touches SDDM, the vault, boot-freeze or `/etc` tweaks;
- archives your existing configs to `~/.local/state/dotfiles-safety/` first;
- links [`rescue`](rescue) to `~/desktop-rescue.sh`;
- **checks the login path before you reboot**: `~/.profile` must source cleanly
  under `/bin/sh` (uwsm does this at login; one failing line, like sourcing a
  missing `~/.cargo/env`, sends you straight back to the SDDM login screen in a
  loop), bash must start, and Hyprland must report no config errors.

If login ever loops anyway: press **CTRL+ALT+F3**, log in, run
`~/desktop-rescue.sh` (or `~/desktop-rescue.sh --full` to undo everything),
then `sudo reboot`.

After it finishes, test the lock with SUPER+CTRL+L before rebooting. The vault
is never restored automatically; run `./dot vault restore` yourself.

## Everyday use

Because configs are symlinks, edits land in the repository as you make them.
To also capture package and system changes and publish them:

```bash
cd ~/dotfiles
./dot sync                      # snapshot packages, services, GTK + Omarchy state
git add -A && git commit -m "Describe the change"
git push                        # pushes the current machine's branch
```

On the same machine after a reinstall: clone this branch and run `./dot install`.

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
./dot vault restore         # download, decrypt and restore (never automatic)
```

The vault is encrypted with GPG (AES256, a passphrase you choose) **and** stored
in a private repo. Each save replaces the previous snapshot instead of adding to
git history. Close your browser before saving. Bluetooth pairings only work
again on the same machine, because the keys are tied to the adapter.

### Commands

| Command | Description |
|---------|-------------|
| `./dot install` | Runs `./restore`: safe, re-runnable restore of this setup |
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
├── restore              # safe restore of this setup (run by ./dot install)
├── rescue               # TTY rescue for login loops (~/desktop-rescue.sh)
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

Each branch describes one machine (see [Branches](#branches)). On different
hardware, review:

- **`home/.config/hypr/monitors.lua`**: output names, resolutions and scaling.
- **Platform packages** in `packages/pacman.txt`: `asahi-*` on `main`,
  `intel-ucode`, `vulkan-intel`, `intel-lpmd` and `thermald` on
  `thinkpad-t14-gen5`. Swap them for your platform's equivalents.

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
| [ble.sh](https://github.com/akinomyoga/ble.sh) | akinomyoga |

Each remains under its own license.
