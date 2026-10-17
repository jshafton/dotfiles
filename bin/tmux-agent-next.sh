#!/usr/bin/env bash
# Jump to the next agent waiting on you, across all sessions. Bound to prefix+a.
#   1. blocked agents (approval or question pending)
#   2. idle agents whose window still has the 🤖 marker from
#      claude-notification-hook.sh (finished, and you haven't looked yet)
# Within each group, the agent that has waited longest comes first
# (@agent_since, set by tmux-agent-state.sh). The current pane is skipped so
# repeated presses move on to the next one.
# $1: client name, $2: current pane id (passed by the binding, because
# run-shell has no reliable "current" client or pane of its own).
set -euo pipefail

client="${1:?client name required}"
current="${2:-}"

target="$(tmux list-panes -a -F '#{pane_id}|#{@agent_state}|#{@agent_since}|#{@claude_original_name}' 2>/dev/null |
  awk -F'|' -v cur="$current" '
    $1 == cur { next }
    $2 == "blocked"             { print 0, $3 + 0, $1; next }
    $2 == "idle" && $4 != ""    { print 1, $3 + 0, $1 }' |
  sort -n -k1,1 -k2,2 | head -1 | cut -d' ' -f3)"

if [ -z "$target" ]; then
  tmux display-message -c "$client" "No agents waiting"
  exit 0
fi

# switch-client to a pane also makes its window and pane current.
tmux switch-client -c "$client" -t "$target"
