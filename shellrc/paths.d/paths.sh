# Add `~/bin` to the `$PATH`
path_prepend "$HOME/bin"

if [ -d "$HOME/.local/bin" ]; then
  path_prepend "$HOME/.local/bin"
fi

if [ -d "$HOME/.rd/bin" ]; then
  path_prepend "$HOME/.rd/bin"
fi
