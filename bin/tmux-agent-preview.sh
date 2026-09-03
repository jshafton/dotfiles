#!/usr/bin/env bash
# Preview renderer for the agent popup (tmux-agent-sidebar.sh).
# Captures the target pane and prints its agent output with the Claude input
# box + status bar at the bottom trimmed off, so the last message — or whatever
# the agent is blocked on — is what you see, not the "> " prompt and
# "Model: … / bypass permissions" chrome. The popup wraps this and auto-scrolls
# to the bottom (focus:preview-bottom), so the latest line shows first; agent
# panes are full terminal width, so wrapping is the only way it all fits.
set -euo pipefail

pane="${1:-}"
[ -n "$pane" ] || exit 0

# The input box is drawn as: full-width rule / prompt line / full-width rule /
# status lines. Find the bottom-most rule and, when it's the closing rule of
# that box, drop from the opening rule down. Permission dialogs use ╭╮╰╯ box
# corners (not a bare rule) and their option lines sit inside those corners, so
# this never eats the thing a blocked agent is waiting on.
tmux capture-pane -p -t "$pane" 2>/dev/null | awk '
  function isrule(x,   nd, ns) {
    nd = x; gsub(/[─━[:space:]]/, "", nd)   # strip rule chars + space
    ns = x; gsub(/[[:space:]]/, "", ns)     # strip space only
    return (ns != "" && nd == "")           # visible content, all of it dashes
  }
  function isprompt(x) { return (x ~ /^[[:space:]]*[❯›]/) }
  function isblank(x)  { return (x ~ /^[[:space:]]*$/) }
  { a[NR] = $0 }
  END {
    r = 0
    for (i = NR; i >= 1; i--) if (isrule(a[i])) { r = i; break }
    if (r == 0) {
      end = NR
    } else {
      cut = r
      if (r - 2 >= 1 && isprompt(a[r-1]) && isrule(a[r-2])) cut = r - 2
      end = cut - 1
    }
    while (end > 0 && isblank(a[end])) end--
    for (i = 1; i <= end; i++) print a[i]
  }
'
