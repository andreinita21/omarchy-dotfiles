#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc
if [[ -r "$HOME/.cargo/env" ]]; then . "$HOME/.cargo/env"; fi
