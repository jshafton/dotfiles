#!/usr/bin/env bash
# Claude Code lifecycle hook -> tmux pane state.
# Sets @agent_state on the pane Claude runs in, then re-aggregates the
# window's dot. Event mapping:
#   SessionStart/UserPromptSubmit/PostToolUse -> working
#   Stop/StopFailure                          -> idle
#   PermissionRequest                         -> blocked (approval waiting)
#   SubagentStart/SubagentStop                -> ignored (don't own the pane)
# PostToolUse clears a `blocked` set by PermissionRequest once the approved
# tool actually runs, so the dot doesn't stay red while the agent is working.
# Runs only when Claude is inside a tmux pane (TMUX_PANE set).
set -euo pipefail

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

event="${1:-}"
case "$event" in
  SessionStart|UserPromptSubmit|PostToolUse) state="working" ;;
  Stop|StopFailure)              state="idle" ;;
  PermissionRequest)             state="blocked" ;;
  SubagentStart|SubagentStop)    exit 0 ;;
  *)                             exit 0 ;;
esac

tmux set-option -p -t "$TMUX_PANE" @agent_state "$state" 2>/dev/null || exit 0
# Re-aggregate the window dot from pane states.
exec /home/shafjac/bin/tmux-agent-aggregate.sh
