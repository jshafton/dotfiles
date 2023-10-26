# Add `~/bin` to the `$PATH`
path_prepend "$HOME/bin"

if [ -d "$HOME/.rd/bin" ]; then
  path_prepend "$HOME/.rd/bin"
fi

# asdf sets up necessary shims for paths and completions
if [ -f "${HOME}/.asdf/asdf.sh" ]; then
  . "${HOME}/.asdf/asdf.sh"
fi

if [ -f "$HOME/.asdf/completions/asdf.bash" ]; then
  . "$HOME/.asdf/completions/asdf.bash"
fi
