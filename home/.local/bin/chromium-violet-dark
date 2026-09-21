#!/bin/bash
# Pin Chromium/Chrome's browser colour scheme to Dark.
#
# Omarchy writes {"BrowserThemeColor": ..., "BrowserColorScheme": "device"} into
# the managed-policy dir, but BrowserColorScheme is NOT a Chrome policy -- only
# BrowserThemeColor is (see components/policy/resources/templates/
# policy_definitions/Miscellaneous/). Chromium silently ignores the key.
#
# The real switch is the profile pref browser.theme.color_scheme2
# (chrome/common/pref_names.h: kBrowserColorScheme), with values from
# ThemeService::BrowserColorScheme -- kSystem=0, kLight=1, kDark=2.
#
# Chromium rewrites Preferences on exit, so it must not be running.

set -euo pipefail

DARK=2

if pgrep -x chromium >/dev/null || pgrep -x chrome >/dev/null; then
  echo "Chromium is running -- close it completely first, then re-run." >&2
  exit 1
fi

shopt -s nullglob
profiles=("$HOME"/.config/chromium/*/Preferences "$HOME"/.config/google-chrome/*/Preferences)

if [[ ${#profiles[@]} -eq 0 ]]; then
  echo "No Chromium/Chrome profile found." >&2
  exit 1
fi

for prefs in "${profiles[@]}"; do
  python3 - "$prefs" "$DARK" <<'PY'
import json, shutil, sys

path, dark = sys.argv[1], int(sys.argv[2])
with open(path) as f:
    d = json.load(f)

theme = d.setdefault("browser", {}).setdefault("theme", {})
before = (theme.get("color_scheme"), theme.get("color_scheme2"))
# color_scheme2 is the live pref; color_scheme is the deprecated twin, kept in
# sync so a profile migration can't quietly hand back the old value.
theme["color_scheme"] = dark
theme["color_scheme2"] = dark

if before == (dark, dark):
    print(f"{path}: already dark")
else:
    shutil.copy2(path, path + ".bak")
    with open(path, "w") as f:
        json.dump(d, f, separators=(",", ":"))
    print(f"{path}: {before} -> ({dark}, {dark})  [backup: {path}.bak]")
PY
done

echo "Done. Relaunch Chromium."
