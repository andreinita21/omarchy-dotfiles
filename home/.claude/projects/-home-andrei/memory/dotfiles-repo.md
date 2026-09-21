---
name: dotfiles-repo
description: ~/dotfiles (public GitHub andreinita21/omarchy-dotfiles) replicates this Omarchy setup; most configs are symlinks into it
metadata:
  type: project
---
Since 2026-09-21, ~/dotfiles holds the user's full Omarchy setup (public repo andreinita21/omarchy-dotfiles). Paths in `links.txt` (~/.config/hypr, ~/.config/omarchy, terminals, ~/.local/bin scripts, .bashrc, Claude settings/memory…) are symlinks into `home/`. `./dot sync` snapshots packages/services/dconf/Omarchy state and scans for secrets; `./dot install` restores on a fresh Omarchy machine.

**Why:** the user wants to replicate this exact machine on other Omarchy installs.
**How to apply:** after changing configs or installing/removing packages, suggest `cd ~/dotfiles && ./dot sync && git commit -am … && git push`. New config dirs must be added to `links.txt` + `./dot adopt`. Secrets inside tracked dirs go in the secrets section of `write_gitignore` in `dot`.
**Public repo:** never track anything private (credentials, private-project notes); run ./dot sync's secret scan before every push.
