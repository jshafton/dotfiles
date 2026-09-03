#!/usr/bin/env bash
# Toggle the persistent agent-sidebar pane in the current session.
# If a sidebar pane exists (marked @agent_sidebar=1), kill it; otherwise
# split a 34-col right pane running the render loop.
set -euo pipefail

session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"
[ -n "$session" ] || exit 0

# find an existing sidebar pane in this session
existing="$(tmux list-panes -a -F "#{session_name}|#{pane_id}|#{@agent_sidebar}" 2>/dev/null | awk -F'|' -v s="$session" '$1==s && $3=="1" {print $2; exit}')"

if [ -n "$existing" ]; then
  tmux kill-pane -t "$existing" 2>/dev/null || true
else
  # -P prints the new pane id; target the session explicitly so the split
  # lands in the right session even when run from outside a tmux pane
  newpane="$(tmux split-window -P -t "$session" -h -l 34 -c /home/shafjac \
    "TMUX_AGENT_SIDEBAR_SESSION=$session /home/shafjac/bin/tmux-agent-sidebar-pane.sh" 2>/dev/null || true)"
  [ -n "$newpane" ] && tmux set-option -p -t "$newpane" @agent_sidebar 1 2>/dev/null || true
fi
