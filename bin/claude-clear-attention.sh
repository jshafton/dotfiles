#!/bin/bash
# Clears the 🤖 tmux window-title marker set by claude-notification-hook.sh.
# Triggered from: UserPromptSubmit, SessionStart (source=clear), tmux pane-focus-in.
# $1: trigger name for logging (e.g. "user-prompt", "session-clear", "focus").

TRIGGER="${1:-unknown}"

[[ -z "$TMUX" ]] && exit 0
[[ -z "$TMUX_PANE" ]] && exit 0

LOG="$HOME/.claude/notification-debug.log"
mkdir -p "$HOME/.claude" 2>/dev/null

STASHED=$(tmux show-options -w -v -t "$TMUX_PANE" '@claude_original_name' 2>/dev/null)
[[ -z "$STASHED" ]] && exit 0

ORIG_AUTO=$(tmux show-options -w -v -t "$TMUX_PANE" '@claude_original_auto_rename' 2>/dev/null || echo "on")
tmux rename-window -t "$TMUX_PANE" "$STASHED" 2>/dev/null
tmux set-option -w -t "$TMUX_PANE" automatic-rename "$ORIG_AUTO" 2>/dev/null
tmux set-option -wu -t "$TMUX_PANE" '@claude_original_name' 2>/dev/null
tmux set-option -wu -t "$TMUX_PANE" '@claude_original_auto_rename' 2>/dev/null

echo "$(date): CLEARED marker via $TRIGGER (restored '$STASHED', auto-rename=$ORIG_AUTO)" >> "$LOG" 2>/dev/null
exit 0
