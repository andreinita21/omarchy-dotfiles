#!/usr/bin/env bash

input=$(cat)
# Debug: keep a copy of the most recent statusline input for troubleshooting.
echo "$input" > "$HOME/.claude/statusline-last-input.json" 2>/dev/null

# --- Theme colors ---------------------------------------------------------
# Every colour below is derived from the ACTIVE Omarchy theme rather than being
# hardcoded, so the statusline retints along with `omarchy theme set`. The
# palette is read through omarchy-theme-color, the same resolver Omarchy uses
# to generate the themed configs, so aliases/derived shades resolve identically
# (~8ms, cheap enough to do per render). If Omarchy isn't present the built-in
# purple fallbacks below are used unchanged.
SL_THEME_COLORS="${SL_THEME_COLORS:-$HOME/.local/state/omarchy/current/theme/colors.toml}"

# Fallbacks (the original hardcoded purple scheme), used when no theme is found.
SL_PRIMARY="175;135;255"   # folder, model, healthy tier
SL_ACCENT="215;95;255"     # git branch
SL_ACCENT2="215;135;255"   # effort
SL_TEXT="175;175;215"      # percentage labels
SL_MUTED="95;0;175"        # separator, time remaining
SL_BAR_LO="135;95;215"     # bar gradient: dim end
SL_BAR_HI="255;95;255"     # bar gradient: hot end
SL_TRACK="72;62;96"        # bar empty cells
SL_WARN="245;194;0"        # >=60%
SL_ALERT="255;135;70"      # >=70%
SL_CRIT="255;83;69"        # >=80%

# "#rrggbb" -> "R;G;B"
sl_rgb() {
  local h="${1#\#}"
  [[ $h =~ ^[0-9A-Fa-f]{6}$ ]] || return 1
  printf '%d;%d;%d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

# Blend two "#rrggbb" colors: sl_mix <from> <to> <percent-of-to> -> "R;G;B"
sl_mix() {
  local a="${1#\#}" b="${2#\#}" p="$3"
  [[ $a =~ ^[0-9A-Fa-f]{6}$ && $b =~ ^[0-9A-Fa-f]{6}$ ]] || return 1
  local i out=()
  for i in 0 2 4; do
    out+=( $(( (16#${a:$i:2} * (100 - p) + 16#${b:$i:2} * p + 50) / 100 )) )
  done
  printf '%d;%d;%d' "${out[@]}"
}

sl_load_theme() {
  [[ -f $SL_THEME_COLORS ]] || return 1
  command -v omarchy-theme-color >/dev/null 2>&1 || return 1

  local -A c=()
  local key value
  while IFS=$'\t' read -r key value; do
    c[$key]="$value"
  done < <(omarchy-theme-color --file "$SL_THEME_COLORS" --all 2>/dev/null)

  local accent="${c[accent]}" bg="${c[background]}" bright="${c[bright_foreground]}"
  [[ $accent && $bg && $bright ]] || return 1

  # Monochromatic accent ramp for the bar: dimmed accent at the start, accent in
  # the middle, accent lifted toward the theme's brightest foreground at the
  # leading edge. Keeping the ramp within one hue means it reads correctly in
  # every theme, light or dark, instead of colliding with an unrelated palette
  # slot the way a fixed violet->magenta ramp would.
  SL_BAR_LO=$(sl_mix "$accent" "$bg" 45)     || return 1
  SL_BAR_HI=$(sl_mix "$accent" "$bright" 45) || return 1
  SL_TRACK=$(sl_mix "$bg" "${c[foreground]}" 22) || return 1

  SL_PRIMARY=$(sl_rgb "$accent")                                     || return 1
  SL_ACCENT=$(sl_rgb "${c[magenta]:-$accent}")                       || return 1
  SL_ACCENT2=$(sl_rgb "${c[bright_magenta]:-${c[magenta]:-$accent}}") || return 1
  SL_TEXT=$(sl_rgb "${c[light_foreground]:-${c[foreground]}}")       || return 1
  SL_MUTED=$(sl_rgb "${c[muted]:-${c[dark_foreground]}}")            || return 1
  SL_WARN=$(sl_rgb "${c[yellow]}")                                   || return 1
  SL_ALERT=$(sl_rgb "${c[orange]:-${c[yellow]}}")                    || return 1
  SL_CRIT=$(sl_rgb "${c[red]}")                                      || return 1
}

# A partial failure would leave a mix of themed and fallback colors, so restore
# the whole fallback scheme if any lookup came up short.
if ! sl_load_theme; then
  SL_PRIMARY="175;135;255"; SL_ACCENT="215;95;255";  SL_ACCENT2="215;135;255"
  SL_TEXT="175;175;215";    SL_MUTED="95;0;175"
  SL_BAR_LO="135;95;215";   SL_BAR_HI="255;95;255";  SL_TRACK="72;62;96"
  SL_WARN="245;194;0";      SL_ALERT="255;135;70";   SL_CRIT="255;83;69"
fi

fg() { printf '\033[38;2;%sm' "$1"; }

# --- Data extraction ---
# One jq pass for every field. This runs on a refreshInterval timer (see
# statusLine.refreshInterval in settings.json), so the per-render cost matters:
# spawning jq once instead of eight times is most of the script's runtime.
# Fields are read positionally; jq emits "" for a missing one so the positions
# never shift.
# NOTE: the fields are joined with US (0x1f), NOT newline. Newline is an IFS
# *whitespace* character, so bash collapses runs of it into a single delimiter
# and drops leading ones -- any empty field (e.g. .context_window missing on the
# first render of a session) would silently shift every later value left, which
# is how "5h" ended up rendering a unix timestamp as a percentage. 0x1f is not
# whitespace, so empty fields keep their slot.
IFS=$'\x1f' read -r -d '' \
  cwd ctx_used five_pct five_resets_at seven_pct seven_resets_at model_name effort_level \
  < <(printf '%s' "$input" | jq -j '
        [ (.workspace.current_dir // .cwd // "?"),
          (.context_window.used_percentage // ""),
          (.rate_limits.five_hour.used_percentage // ""),
          (.rate_limits.five_hour.resets_at // ""),
          (.rate_limits.seven_day.used_percentage // ""),
          (.rate_limits.seven_day.resets_at // ""),
          (.model.display_name // ""),
          (.effort.level // "")
        ] | map(tostring) | join("\u001f")'; printf '\0')

# Belt and braces: a non-numeric value in a numeric slot means the shape of the
# input changed, so blank it rather than rendering garbage.
for v in ctx_used five_pct five_resets_at seven_pct seven_resets_at; do
  [[ ${!v} =~ ^[0-9]+(\.[0-9]+)?$ ]] || printf -v "$v" '%s' ""
done

folder=$(basename "$cwd")

# Git branch (skip optional locks)
git_branch=""
if git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null); then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# --- Bar renderer ---
# Usage: render_bar <percentage 0-100> <width>
# Always emits exactly <width> cells: █ (filled) + ░ (empty), and carries its
# own color escapes. Filled cells are painted with a TRUE-COLOR (24-bit RGB)
# gradient running from a dimmed theme accent to a brightened one, so the
# further the bar fills, the hotter its leading edge looks.
# NOTE: do NOT use `seq 1 $n` for the loops — on macOS/BSD `seq 1 0` counts
# DOWN and prints "1\n0", which would add 2 stray blocks whenever a count is 0.
# awk's C-style loops iterate zero times when the count is 0, and filled is
# clamped to [0, width] so out-of-range percentages can't change the bar length.
BAR_WIDTH=${BAR_WIDTH:-10}   # bump to 20 for a wider bar

render_bar() {
  local pct="${1:-0}"
  local width="${2:-10}"
  awk -v p="$pct" -v w="$width" -v lo="$SL_BAR_LO" -v hi="$SL_BAR_HI" -v track="$SL_TRACK" 'BEGIN{
    split(lo, a, ";"); split(hi, b, ";");
    f = int(p*w/100 + 0.5); if (f<0) f=0; if (f>w) f=w;
    for (i=0; i<f; i++) {
      t = (w>1) ? i/(w-1) : 0;
      printf "\033[38;2;%d;%d;%dm█",
        int(a[1] + (b[1]-a[1])*t + 0.5),
        int(a[2] + (b[2]-a[2])*t + 0.5),
        int(a[3] + (b[3]-a[3])*t + 0.5);
    }
    printf "\033[38;2;%sm", track;
    for (i=f; i<w; i++) printf "░";
    printf "\033[0m";
  }'
}

# Helper: extract color escape and icon separately.
# Default (healthy) tier is the theme accent; it escalates to the theme's
# yellow -> orange -> blinking red once usage crosses the thresholds, so a high
# bar still stands out.
get_color() {
  local pct="${1:-0}"
  local int_pct=$(printf '%.0f' "$pct")
  if   [ "$int_pct" -ge 80 ]; then printf '\033[5m'; fg "$SL_CRIT"   # blinking
  elif [ "$int_pct" -ge 70 ]; then fg "$SL_ALERT"
  elif [ "$int_pct" -ge 60 ]; then fg "$SL_WARN"
  else                             fg "$SL_PRIMARY"
  fi
}

get_icon() {
  local pct="${1:-0}"
  local int_pct=$(printf '%.0f' "$pct")
  if   [ "$int_pct" -ge 80 ]; then printf '💀 '
  elif [ "$int_pct" -ge 70 ]; then printf '🔶 '
  elif [ "$int_pct" -ge 60 ]; then printf '⚠️  '
  else                              printf ''
  fi
}

# --- Time remaining formatter ---
# Given a unix epoch reset time, output e.g. "2d3h", "1h23m", "45m", or
# "resets soon". Days are shown once the remaining time is >= 24h (used by the
# weekly window); shorter windows fall through to the hours/minutes form.
format_time_remaining() {
  local resets_at="${1:-0}"
  local now
  now=${EPOCHSECONDS:-$(date +%s)}
  local diff=$(( resets_at - now ))
  if [ "$diff" -le 0 ]; then
    printf 'resets soon'
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))
  if [ "$days" -gt 0 ]; then
    printf '%dd%dh' "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf '%dh%02dm' "$hours" "$mins"
  else
    printf '%dm' "$mins"
  fi
}

# --- Assemble parts ---
parts=()

# Folder (bold theme accent — same tone as the model name)
parts+=("$(printf '\033[1m%s%s\033[0m' "$(fg "$SL_PRIMARY")" "$folder")")

# Git branch (theme magenta)
if [ -n "$git_branch" ]; then
  parts+=("$(printf '%s %s\033[0m' "$(fg "$SL_ACCENT")" "$git_branch")")
fi

# Context bar
if [ -n "$ctx_used" ]; then
  bar=$(render_bar "$ctx_used" "$BAR_WIDTH")
  pct_label=$(printf '%.0f' "$ctx_used")
  color=$(get_color "$ctx_used")
  icon=$(get_icon "$ctx_used")
  parts+=("$(printf '%s%scontext %s %s%s%%\033[0m' "$icon" "$color" "$bar" "$(fg "$SL_TEXT")" "$pct_label")")
fi

# 5-hour session bar + time remaining
if [ -n "$five_pct" ]; then
  bar=$(render_bar "$five_pct" "$BAR_WIDTH")
  pct_label=$(printf '%.0f' "$five_pct")
  color=$(get_color "$five_pct")
  icon=$(get_icon "$five_pct")
  time_left=""
  if [ -n "$five_resets_at" ]; then
    time_left=" $(format_time_remaining "$five_resets_at")"
  fi
  parts+=("$(printf '%s%s5h %s %s%s%%%s%s\033[0m' "$icon" "$color" "$bar" "$(fg "$SL_TEXT")" "$pct_label" "$(fg "$SL_MUTED")" "$time_left")")
fi

# 7-day (weekly) session bar + time remaining
if [ -n "$seven_pct" ]; then
  bar=$(render_bar "$seven_pct" "$BAR_WIDTH")
  pct_label=$(printf '%.0f' "$seven_pct")
  color=$(get_color "$seven_pct")
  icon=$(get_icon "$seven_pct")
  time_left=""
  if [ -n "$seven_resets_at" ]; then
    time_left=" $(format_time_remaining "$seven_resets_at")"
  fi
  parts+=("$(printf '%s%s7d %s %s%s%%%s%s\033[0m' "$icon" "$color" "$bar" "$(fg "$SL_TEXT")" "$pct_label" "$(fg "$SL_MUTED")" "$time_left")")
fi

# Model + effort
# Claude Code's statusLine stdin JSON exposes the LIVE effort level
# (.effort.level, as of CLI 2.1.x). Read it directly so in-session /effort
# changes are reflected. The model name is its own segment (theme accent); the
# effort level is a separate segment shown on its own after a "|".
if [ -n "$model_name" ]; then
  parts+=("$(printf '%s%s\033[0m' "$(fg "$SL_PRIMARY")" "$model_name")")

  case "$effort_level" in
    low)    effort="low" ;;
    medium) effort="medium" ;;
    high)   effort="high" ;;
    xhigh)  effort="xhigh" ;;
    max)    effort="max" ;;
    "")     effort="" ;;
    *)      effort="$effort_level" ;;
  esac

  if [ -n "$effort" ]; then
    parts+=("$(printf '%s%s\033[0m' "$(fg "$SL_ACCENT2")" "$effort")")
  fi
fi

# --- Join with separator and print ---
# Separator: theme muted
result=""
sep="$(printf ' %s|\033[0m ' "$(fg "$SL_MUTED")")"
for part in "${parts[@]}"; do
  if [ -z "$result" ]; then
    result="$part"
  else
    result="${result}${sep}${part}"
  fi
done

printf '%s' "$result"
