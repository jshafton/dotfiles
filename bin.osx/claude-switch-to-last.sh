#!/bin/bash
# Switch to last Claude pane - used by hotkey and notification click
# All errors suppressed to avoid dialogs

WEZTERM_PATH="/opt/homebrew/bin/wezterm"
STATE_FILE="$HOME/.claude/last-notification-pane"

osascript -e 'tell application "WezTerm" to activate' 2>/dev/null

if [[ -f "$STATE_FILE" ]]; then
  VALUE=$(cat "$STATE_FILE" 2>/dev/null)
  [[ -z "$VALUE" ]] && exit 0

  if [[ "$VALUE" =~ ^[0-9]+$ ]]; then
    PANE_ID="$VALUE"
  else
    sleep 0.1
    PANE_ID=$("$WEZTERM_PATH" cli list 2>/dev/null | awk -v s="$VALUE:" 'index($6, s) == 1 {print $3; exit}')
  fi

  [[ "$PANE_ID" =~ ^[0-9]+$ ]] && "$WEZTERM_PATH" cli activate-pane --pane-id "$PANE_ID" 2>/dev/null
fi

exit 0
