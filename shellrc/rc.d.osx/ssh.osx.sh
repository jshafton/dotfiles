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
  # Detect if SSH is being called by git or other non-interactive tools
  # Git calls ssh with a command as the last argument containing git-*-pack
  # Also check if parent process is git, or if this is non-interactive
  _is_git_ssh=0

  # Check if any argument contains git commands
  for _arg in "$@"; do
    case "$_arg" in
    *git-upload-pack* | *git-receive-pack* | *git-upload-archive*)
      _is_git_ssh=1
      break
      ;;
    esac
  done

  # Check if GIT_SSH or similar env vars are set (git calling us)
  if [ -n "$GIT_SSH_COMMAND" ] || [ -n "$GIT_SSH" ]; then
    _is_git_ssh=1
  fi

  # Check if stdin is not a terminal (non-interactive use)
  if ! [ -t 0 ]; then
    _is_git_ssh=1
  fi

  # If this is a git/non-interactive operation, just pass through to real ssh
  if [ "$_is_git_ssh" -eq 1 ]; then
    /usr/bin/ssh "$@"
    return $?
  fi

  _term_override=""

  # Handle kitty terminal compatibility
  if [ "$TERM" = "xterm-kitty" ]; then
    _term_override="TERM=xterm-256color"
  fi

  # Execute SSH with the script, but don't fail if tmux isn't available
  if [ -n "$_term_override" ]; then
    env $_term_override /usr/bin/ssh -t "$@" "bash -c '$SCRIPT' || true; exec \$SHELL -l"
  else
    /usr/bin/ssh -t "$@" "bash -c '$SCRIPT' || true; exec \$SHELL -l"
  fi
}
