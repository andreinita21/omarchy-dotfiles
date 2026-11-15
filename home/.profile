# Rust toolchain (rustup), only if installed. A failing line here aborts the
# uwsm session start and drops you back at the SDDM login screen.
if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi
true
