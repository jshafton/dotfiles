#!/usr/bin/env sh

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

  # Parse our custom options before ssh args
  _tmux_session="remote"
  _skip_tmux=0
  _ssh_args=""

  while [ $# -gt 0 ]; do
    case "$1" in
    --session)
      # Our custom flag: specify tmux session name
      shift
      if [ $# -eq 0 ]; then
        echo "ssh: --session requires an argument" >&2
        return 1
      fi
      _tmux_session="$1"
      shift
      ;;
    --session=*)
      # Handle --session=value form
      _tmux_session="${1#--session=}"
      shift
      ;;
    --no-tmux)
      # Skip tmux entirely, just connect normally
      _skip_tmux=1
      shift
      ;;
    *)
      # Accumulate all other args for ssh
      _ssh_args="$_ssh_args $(printf '%q' "$1")"
      shift
      ;;
    esac
  done

  # If no args left after parsing, show usage hint
  if [ -z "$_ssh_args" ]; then
    echo "Usage: ssh [--session NAME] [--no-tmux] [ssh-options] destination" >&2
    return 1
  fi

  # Handle kitty terminal compatibility
  _term_override=""
  if [ "$TERM" = "xterm-kitty" ]; then
    _term_override="TERM=xterm-256color"
  fi

  # If --no-tmux was specified, just run plain ssh
  if [ "$_skip_tmux" -eq 1 ]; then
    if [ -n "$_term_override" ]; then
      eval "env $_term_override /usr/bin/ssh $_ssh_args"
    else
      eval "/usr/bin/ssh $_ssh_args"
    fi
    return $?
  fi

  # Build the remote script with the specified session name
  _script="
if command -v tmux-next >/dev/null 2>&1; then
  exec tmux-next new-session -A -s $_tmux_session
elif command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s $_tmux_session
fi
"

  # Execute SSH with the script, but don't fail if tmux isn't available
  if [ -n "$_term_override" ]; then
    eval "env $_term_override /usr/bin/ssh -t $_ssh_args \"bash -c '\$_script' || true; exec \\\$SHELL -l\""
  else
    eval "/usr/bin/ssh -t $_ssh_args \"bash -c '\$_script' || true; exec \\\$SHELL -l\""
  fi
}