#!/bin/bash
# Switch to last Claude pane - used by hotkey and notification click

# Unset stale socket env var - let wezterm find the current one
unset WEZTERM_UNIX_SOCKET

WEZTERM_PATH="/opt/homebrew/bin/wezterm"
STATE_FILE="$HOME/.claude/last-notification-pane"
LOG="$HOME/.claude/switch-debug.log"

echo "$(date): START" >> "$LOG"

# Activate WezTerm
osascript -e 'tell application "WezTerm" to activate' 2>/dev/null
echo "$(date): activated WezTerm" >> "$LOG"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "$(date): no state file" >> "$LOG"
  exit 0
fi

STATE=$(cat "$STATE_FILE" 2>/dev/null)
echo "$(date): STATE=$STATE" >> "$LOG"

# Parse JSON (simple extraction)
WEZTERM_PANE=$(echo "$STATE" | sed -n 's/.*"wezterm_pane":"\([^"]*\)".*/\1/p')
TMUX_SESSION=$(echo "$STATE" | sed -n 's/.*"tmux_session":"\([^"]*\)".*/\1/p')
TMUX_WINDOW=$(echo "$STATE" | sed -n 's/.*"tmux_window":"\([^"]*\)".*/\1/p')
TMUX_PANE_ID=$(echo "$STATE" | sed -n 's/.*"tmux_pane":"\([^"]*\)".*/\1/p')

echo "$(date): wezterm_pane=$WEZTERM_PANE tmux_session=$TMUX_SESSION tmux_window=$TMUX_WINDOW tmux_pane=$TMUX_PANE_ID" >> "$LOG"

# Switch WezTerm pane
if [[ "$WEZTERM_PANE" =~ ^[0-9]+$ ]]; then
  echo "$(date): activating WezTerm pane $WEZTERM_PANE" >> "$LOG"
  "$WEZTERM_PATH" cli activate-pane --pane-id "$WEZTERM_PANE" 2>&1 >> "$LOG"
fi

# Switch tmux pane (only works for local tmux sessions)
# Must use switch-client with explicit client since we run outside tmux context
if [[ -n "$TMUX_SESSION" ]] && tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
  echo "$(date): local session found: $TMUX_SESSION" >> "$LOG"

  if [[ -n "$TMUX_PANE_ID" ]]; then
    # Check if pane exists locally (remote pane IDs won't exist here)
    if ! tmux list-panes -a -F "#{pane_id}" | grep -q "^${TMUX_PANE_ID}$"; then
      echo "$(date): pane $TMUX_PANE_ID not found locally (remote notification)" >> "$LOG"
    else
      # Get the attached client for this session
      CLIENT=$(tmux list-clients -t "$TMUX_SESSION" -F "#{client_tty}" | head -1)
      echo "$(date): client=$CLIENT, switching to pane $TMUX_PANE_ID" >> "$LOG"

      if [[ -n "$CLIENT" ]]; then
        # switch-client works from outside tmux by explicitly targeting the client
        tmux switch-client -c "$CLIENT" -t "$TMUX_PANE_ID" 2>&1 >> "$LOG"
        echo "$(date): switch-client exit=$?" >> "$LOG"
      else
        echo "$(date): no client attached to session" >> "$LOG"
      fi
    fi
  fi
else
  echo "$(date): session '$TMUX_SESSION' not found locally (probably remote)" >> "$LOG"
fi

echo "$(date): DONE" >> "$LOG"
exit 0
