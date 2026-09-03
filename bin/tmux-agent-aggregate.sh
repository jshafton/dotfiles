#!/usr/bin/env bash
# Recompute each window's @win_state from its panes' @agent_state
# (blocked > working > idle), then refresh the status bar. Called after any
# pane state change. Windows with no agent-state panes get no @win_state,
# so the status format renders no dot for them.
set -euo pipefail

command -v tmux >/dev/null 2>&1 || exit 0

# All sessions, all windows: aggregate pane states per (session, window).
tmux list-panes -a -F "#{session_name}|#{window_index}|#{@agent_state}" 2>/dev/null |
  awk -F'|' '
    $3 != "" {
      key = $1 ":" $2;
      if (key in best) {
        prev = best[key];
        if ($3 == "blocked") best[key] = "blocked";
        else if ($3 == "working" && prev != "blocked") best[key] = "working";
        else if (prev == "") best[key] = $3;
      } else {
        best[key] = $3;
      }
    }
    END { for (k in best) print k " " best[k] }' |
  while read -r key state; do
    session="${key%%:*}"
    win="${key##*:}"
    tmux set-option -w -t "$session:$win" @win_state "$state" 2>/dev/null || true
  done

tmux refresh-client -S 2>/dev/null || true
# wake any agent-sidebar panes so they re-render immediately
tmux wait-for -S agent-state-changed 2>/dev/null || true
