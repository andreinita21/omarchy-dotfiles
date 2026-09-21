# ble.sh configuration — completion + command syntax highlighting
# Loaded by ~/.bashrc via: source ~/.local/share/blesh/ble.sh --noattach --rcfile ~/.config/blesh/init.sh
#
# Colors are ANSI indices 0-15 on purpose: they resolve through the terminal
# palette, so `omarchy theme set <name>` restyles the highlighting automatically.
#
#   0 bg     1 red     2 green   3 yellow   4 blue   5 magenta   6 cyan   7 fg
#   8 muted  9 red+   10 green+ 11 yellow+ 12 blue+ 13 magenta+ 14 cyan+ 15 fg+

# ---------------------------------------------------------------- completion
bleopt complete_auto_complete=1          # ghost-text suggestion as you type
bleopt complete_auto_delay=1             # ms before the suggestion appears
bleopt complete_ambiguous=1              # "gr/f" -> "grep/file", partial-word matching
bleopt complete_menu_complete=1          # repeated TAB cycles candidates
bleopt complete_menu_filter=1            # keep typing to narrow an open menu
bleopt complete_menu_style=align-nowrap  # compact aligned grid
bleopt complete_menu_color=on            # colorize candidates by type
bleopt complete_menu_color_match=on      # highlight the matched substring
bleopt complete_skip_matched=on
bleopt complete_contract_function_names=1
bleopt complete_limit_auto=2000          # don't auto-suggest past this many matches
bleopt complete_timeout_auto=5000

# ------------------------------------------------------------- highlighting
bleopt highlight_syntax=1                # shell grammar
bleopt highlight_filename=1              # existing paths vs. typos
bleopt highlight_variable=1              # $VAR state (set/unset/array/...)
bleopt highlight_timeout_sync=50
bleopt highlight_timeout_async=5000
[[ ${LS_COLORS-} ]] && bleopt filename_ls_colors="$LS_COLORS"

# --------------------------------------------------------- command coloring
# The point of this block: a command you can actually run is green; a name
# that resolves to nothing is flagged red *before* you press Enter.
ble-face command_file=fg=10              # external binary found on PATH
ble-face command_builtin=fg=14           # cd, echo, export, ...
ble-face command_builtin_dot=fg=14       # . and :
ble-face command_alias=fg=12             # shell alias
ble-face command_function=fg=13          # shell function
ble-face command_keyword=fg=5            # if, then, for, while, case
ble-face command_directory=fg=12,underline
ble-face command_jobs=fg=11
ble-face command_suffix=fg=0,bg=2
ble-face command_suffix_new=fg=0,bg=9

# ------------------------------------------------------------ shell grammar
ble-face syntax_default=none
ble-face syntax_command=fg=10
ble-face syntax_error=fg=0,bg=9          # unknown command / broken syntax
ble-face syntax_quoted=fg=2              # 'string' "string"
ble-face syntax_quotation=fg=2           # the quote characters themselves
ble-face syntax_escape=fg=14             # \n, \t, \$
ble-face syntax_varname=fg=11            # $VAR
ble-face syntax_param_expansion=fg=11    # ${VAR%.txt}
ble-face syntax_expr=fg=12               # $(( 1 + 2 ))
ble-face syntax_delimiter=fg=15          # | && || ; > <
ble-face syntax_comment=fg=8
ble-face syntax_glob=fg=13               # * ? [abc]
ble-face syntax_brace=fg=6               # {a,b,c}
ble-face syntax_tilde=fg=6               # ~ ~user
ble-face syntax_document=fg=3            # heredoc body
ble-face syntax_document_begin=fg=3
ble-face syntax_history_expansion=fg=0,bg=11
ble-face argument_option=fg=3            # -v --verbose
ble-face argument_error=fg=0,bg=11

# ----------------------------------------------------------------- filenames
ble-face filename_directory=fg=12,underline
ble-face filename_directory_sticky=fg=0,bg=12,underline
ble-face filename_executable=fg=10,underline
ble-face filename_link=fg=14,underline
ble-face filename_orphan=fg=0,bg=9,underline   # broken symlink
ble-face filename_warning=fg=9,underline
ble-face filename_url=fg=12,underline
ble-face filename_other=underline
ble-face filename_socket=fg=13,underline
ble-face filename_pipe=fg=11,underline
ble-face filename_setuid=fg=0,bg=9,underline
ble-face filename_setgid=fg=0,bg=11,underline

# ----------------------------------------------------------------- variables
ble-face varname_unset=fg=8
ble-face varname_empty=fg=6
ble-face varname_number=fg=2
ble-face varname_expr=fg=13
ble-face varname_array=fg=11
ble-face varname_hash=fg=10
ble-face varname_readonly=fg=9
ble-face varname_export=fg=13
ble-face varname_transform=fg=6
ble-face varname_new=fg=2

# ------------------------------------------------------------------ line UI
# Bold is not used as a signal: the terminal font is already at max weight,
# so bold and regular render identically. Everything below leans on color.
ble-face auto_complete=fg=8              # ghost suggestion text
ble-face region=fg=15,bg=8               # selection
ble-face region_insert=fg=12,bg=8
ble-face region_target=fg=0,bg=11
ble-face region_match=fg=0,bg=14         # incremental-search hits
ble-face disabled=fg=8
ble-face overwrite_mode=fg=0,bg=12
ble-face prompt_status_line=fg=15,bg=8
ble-face menu_complete_selected=reverse
ble-face menu_complete_match=fg=11
ble-face menu_filter_input=fg=0,bg=11
ble-face menu_filter_fixed=fg=11
ble-face vbell_flash=fg=0,bg=12
ble-face vbell_erase=bg=8

# --------------------------------------------------------------- exit status
bleopt exec_errexit_mark=$'\e[38;5;9m[exit %d]\e[m'
bleopt exec_elapsed_mark=$'\e[38;5;12m[%s elapsed, CPU %s%%]\e[m'
bleopt exec_elapsed_enabled='usr+sys>=5000'
bleopt exec_exit_mark=

# ------------------------------------------------- fzf as a candidate picker
# Omarchy already wires fzf's own CTRL-T / CTRL-R / ALT-C and the "**<TAB>"
# completion trigger, so only the menu module is loaded here. It is left
# disabled globally (TAB keeps ble.sh's fast inline menu) and reachable on
# its own key -- see the ALT-/ binding set from ~/.bashrc.
# Imported eagerly, not with `ble-import -d`: the delayed form defers to idle
# time, and measurement showed it saves nothing at startup while leaving the
# widget undefined when ~/.bashrc tries to bind it. The module otherwise
# hijacks *every* completion menu, so it is switched off globally -- TAB keeps
# ble.sh's fast inline menu, and ALT-/ reaches for fzf deliberately.
if command -v fzf &>/dev/null; then
  _ble_contrib_fzf_base=/usr/share/fzf
  ble-import contrib/integration/fzf-menu
  bleopt integration_fzf_menu_enabled=
fi

# ------------------------------------------------------------- key bindings
# TAB is a two-stage key:
#
#   TAB (1st)  accept the whole ghost suggestion sitting on the line
#   TAB (2nd)  put back what you had typed and open the menu of the *other*
#              candidates for that word, first one selected
#   TAB (3rd+) walk the menu; typing carries on from the selected
#              candidate and narrows it; C-g backs out of the whole thing
#
# Stage 1 runs in the `auto_complete` keymap, which is only pushed while a
# ghost suggestion is visible. ble.sh defers binds for a keymap that has not
# been defined yet (they land in $_ble_base_run/$$.bind.delay.<keymap> and are
# replayed on load), so binding it here is fine even though neither the keymap
# nor its widgets exist at rc time.
ble-bind -m auto_complete -f TAB tab-accept-suggestion
ble-bind -m auto_complete -f C-i tab-accept-suggestion

# Accepting is ble.sh's own auto_complete/insert; the wrapper only remembers
# the line as it stood before, so stage 2 can offer the alternatives. While
# the suggestion is showing, the ghost text lives in the buffer between point
# and mark -- cut it out to get back what was actually typed.
_tab_accept_str=
_tab_accept_ind=
function ble/widget/tab-accept-suggestion {
  _tab_accept_str=${_ble_edit_str::_ble_edit_ind}${_ble_edit_str:_ble_edit_mark}
  _tab_accept_ind=$_ble_edit_ind
  ble/widget/auto_complete/insert
}

# Stage 2. `ble/widget/complete` already turns a repeated TAB into a menu on
# its own (complete_menu_complete above, via WIDGET == LASTWIDGET); this adds
# the case where the first TAB went to the suggestion instead.
#
# The rewind matters. An accepted suggestion is a finished word with a space
# after it, so completing from there would offer arguments for the *next*
# word -- `ls /etc/pacman.<TAB>` would take pacman.conf and then never show
# you pacman.d. Restoring the typed prefix first makes the second TAB mean
# "not that one, show me the rest", and since the menu re-selects the same
# first candidate the line barely flickers.
function ble/widget/tab-accept-or-menu {
  if [[ $LASTWIDGET == ble/widget/tab-accept-suggestion && $_tab_accept_ind ]]; then
    ble-edit/content/replace 0 "${#_ble_edit_str}" "$_tab_accept_str"
    _ble_edit_ind=$_tab_accept_ind
    _tab_accept_str= _tab_accept_ind=
    ble/widget/complete enter_menu
  else
    ble/widget/complete
  fi
}

# The rest of the `auto_complete` keymap is ble.sh's own and is left alone:
#
#   right / C-f / end / C-e   accept the whole ghost suggestion
#   C-right / M-f             accept one word of it
#   M-right                   accept up to the next word boundary
#   C-g                       dismiss the suggestion
#   S-RET                     accept without running
#
# The emacs-keymap half of TAB is bound after Omarchy's inputrc is applied,
# from ~/.bashrc -- readline's own TAB mapping would otherwise win.
