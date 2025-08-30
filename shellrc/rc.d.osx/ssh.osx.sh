#!/usr/bin/env sh

# Create the remote script that will run on the server
SCRIPT='
if command -v tmux-next >/dev/null 2>&1; then
  exec tmux-next new-session -A -s remote
elif command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s remote
fi
'

# Define the ssh wrapper function
ssh() {
  local term_override=""

  # Handle kitty terminal compatibility
  if [ "$TERM" = "xterm-kitty" ]; then
    term_override="TERM=xterm-256color"
  fi

  # Execute SSH with the script, but don't fail if tmux isn't available
  if [ -n "$term_override" ]; then
    env $term_override /usr/bin/ssh -t "$@" "bash -c '$SCRIPT' || true; exec \$SHELL -l"
  else
    /usr/bin/ssh -t "$@" "bash -c '$SCRIPT' || true; exec \$SHELL -l"
  fi
}
