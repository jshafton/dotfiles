#!/bin/bash

WEZTERM_PATH="/opt/homebrew/bin/wezterm"
NOTIFIER_PATH="/opt/homebrew/bin/terminal-notifier"
CLAUDE_ICON="$HOME/.claude/assets/claude.png"
STATE_FILE="$HOME/.claude/last-notification-pane"

# Gather context
PROJECT=$(basename "$PWD")
GIT_BRANCH=$(git branch --show-current 2>/dev/null)
TMUX_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
PANE_TITLE=$(tmux display-message -p '#{pane_title}' 2>/dev/null | sed 's/^[✳⠂⠐ ]*//')

# Build notification text
TITLE="Claude Code"
SUBTITLE="$PROJECT"
[[ -n "$GIT_BRANCH" ]] && SUBTITLE="$SUBTITLE ($GIT_BRANCH)"
MESSAGE="${PANE_TITLE:-Needs your attention}"

# Get pane ID
PANE_ID=""
if [[ -n "$TMUX_SESSION" ]]; then
  WEZTERM_LIST=$($WEZTERM_PATH cli list 2>/dev/null)
  PANE_ID=$(echo "$WEZTERM_LIST" | awk -v s="$TMUX_SESSION:" 'index($6, s) == 1 {print $3; exit}')
fi

if [[ -z "$PANE_ID" && -n "$WEZTERM_PANE" ]]; then
  PANE_ID="$WEZTERM_PANE"
fi

if [[ -z "$PANE_ID" ]]; then
  WEZTERM_LIST=$($WEZTERM_PATH cli list 2>/dev/null)
  CWD_ENCODED="file://${PWD}"
  PANE_ID=$(echo "$WEZTERM_LIST" | grep -F "$CWD_ENCODED" | awk '{print $3}' | head -1)
fi

# Check if user is already focused on this pane (exit before writing state file)
if [[ -n "$TMUX_SESSION" ]]; then
  CLIENT_FLAGS=$(tmux display-message -p '#{client_flags}' 2>/dev/null)
  PANE_ACTIVE=$(tmux display-message -p '#{pane_active}' 2>/dev/null)
  WINDOW_ACTIVE=$(tmux display-message -p '#{window_active}' 2>/dev/null)

  if [[ "$CLIENT_FLAGS" == *"focused"* && "$PANE_ACTIVE" == "1" && "$WINDOW_ACTIVE" == "1" ]]; then
    exit 0
  fi
fi

# Save session name for hotkey switching (atomic write in same dir to avoid races)
if [[ -n "$TMUX_SESSION" ]]; then
  TMP=$(mktemp "${STATE_FILE}.XXXXXX") && echo "$TMUX_SESSION" >"$TMP" && mv "$TMP" "$STATE_FILE"
elif [[ -n "$PANE_ID" ]]; then
  TMP=$(mktemp "${STATE_FILE}.XXXXXX") && echo "$PANE_ID" >"$TMP" && mv "$TMP" "$STATE_FILE"
fi

# Icon
ICON_ARGS=""
[[ -f "$CLAUDE_ICON" ]] && ICON_ARGS="-contentImage $CLAUDE_ICON"

# Send notification - clicking executes the switch script
$NOTIFIER_PATH \
  -title "$TITLE" \
  -subtitle "$SUBTITLE" \
  -message "$MESSAGE" \
  $ICON_ARGS \
  -execute "$HOME/bin/claude-switch-to-last.sh" \
  -timeout 0 \
  -sound Pop
