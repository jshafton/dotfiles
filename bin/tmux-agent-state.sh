#!/usr/bin/env bash
# Claude Code lifecycle hook -> tmux pane state.
# Sets @agent_state on the pane Claude runs in, then re-aggregates the
# window's dot. Event mapping:
#   SessionStart/UserPromptSubmit/PostToolUse -> working
#   Stop/StopFailure                          -> idle
#     (Stop with background work pending       -> working)
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

# A Stop while background work is pending (subagents, shells, scheduled
# wakeups) is a pause, not the end: Claude resumes when that work reports back.
if [ "$event" = "Stop" ]; then
  pending="$(jq '(.background_tasks // []) + (.session_crons // []) | length' 2>/dev/null || echo 0)"
  [ "${pending:-0}" -gt 0 ] && state="working"
fi

prev="$(tmux display-message -p -t "$TMUX_PANE" '#{@agent_state}' 2>/dev/null || true)"
tmux set-option -p -t "$TMUX_PANE" @agent_state "$state" 2>/dev/null || exit 0
# @agent_since: when the pane entered its current state. tmux-agent-next.sh
# uses it to jump to the agent that has waited longest.
if [ "$prev" != "$state" ]; then
  tmux set-option -p -t "$TMUX_PANE" @agent_since "$(date +%s)" 2>/dev/null || true
fi
# Re-aggregate the window dot from pane states.
exec /home/shafjac/bin/tmux-agent-aggregate.sh
