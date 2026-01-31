#!/bin/bash
# Claude notification hook - works local and remote via OSC 1337
# Sends notification data to WezTerm through tmux passthrough

# Skip if not in tmux
[[ -z "$TMUX" ]] && exit 0

# Ensure log directory exists
mkdir -p "$HOME/.claude" 2>/dev/null
LOG="$HOME/.claude/notification-debug.log"

# Gather context
PROJECT=$(basename "$PWD")
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
PANE_TITLE=$(tmux display-message -p '#{pane_title}' 2>/dev/null | sed 's/^[✳⠂⠐ ]*//')
MESSAGE="${PANE_TITLE:-Needs your attention}"
HOSTNAME=$(hostname -s 2>/dev/null || echo "")
TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "")
TMUX_WINDOW=$(tmux display-message -p '#I' 2>/dev/null || echo "")
# TMUX_PANE is already set by tmux

# Check if user is focused on this pane
CLIENT_FLAGS=$(tmux display-message -p '#{client_flags}' 2>/dev/null)
PANE_ACTIVE=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_active}' 2>/dev/null)
WINDOW_ACTIVE=$(tmux display-message -t "$TMUX_PANE" -p '#{window_active}' 2>/dev/null)

echo "$(date): flags=$CLIENT_FLAGS pane=$PANE_ACTIVE window=$WINDOW_ACTIVE" >> "$LOG"

if [[ "$CLIENT_FLAGS" == *"focused"* && "$PANE_ACTIVE" == "1" && "$WINDOW_ACTIVE" == "1" ]]; then
  echo "$(date): SKIPPED - focused" >> "$LOG"
  exit 0
fi

# Build JSON (escape quotes)
PROJECT_ESC="${PROJECT//\"/\\\"}"
BRANCH_ESC="${BRANCH//\"/\\\"}"
MESSAGE_ESC="${MESSAGE//\"/\\\"}"
HOSTNAME_ESC="${HOSTNAME//\"/\\\"}"
TMUX_SESSION_ESC="${TMUX_SESSION//\"/\\\"}"
TMUX_WINDOW_ESC="${TMUX_WINDOW//\"/\\\"}"
TMUX_PANE_ESC="${TMUX_PANE//\"/\\\"}"

JSON=$(printf '{"project":"%s","branch":"%s","message":"%s","hostname":"%s","tmux_session":"%s","tmux_window":"%s","tmux_pane":"%s"}' \
  "$PROJECT_ESC" "$BRANCH_ESC" "$MESSAGE_ESC" "$HOSTNAME_ESC" "$TMUX_SESSION_ESC" "$TMUX_WINDOW_ESC" "$TMUX_PANE_ESC")

B64=$(echo -n "$JSON" | base64 | tr -d '\n')

echo "$(date): JSON=$JSON" >> "$LOG"
echo "$(date): B64=$B64" >> "$LOG"

# Get the actual tty
TTY_PATH=$(tty 2>/dev/null)
PANE_TTY=$(tmux display-message -p '#{pane_tty}' 2>/dev/null)
echo "$(date): tty=$TTY_PATH pane_tty=$PANE_TTY" >> "$LOG"

# Send OSC 1337 with tmux passthrough (try pane_tty first, then /dev/tty)
TARGET_TTY="${PANE_TTY:-/dev/tty}"
if [[ -w "$TARGET_TTY" ]]; then
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    "claude_notify" "$B64" > "$TARGET_TTY" 2>/dev/null
  echo "$(date): SENT to $TARGET_TTY" >> "$LOG"
else
  echo "$(date): TTY not writable: $TARGET_TTY" >> "$LOG"
fi
