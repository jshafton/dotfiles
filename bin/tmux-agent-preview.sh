#!/usr/bin/env bash
# Preview renderer for the agent popup (tmux-agent-sidebar.sh).
# Captures the target pane and prints its agent output with the Claude input
# box + status bar at the bottom trimmed off, so the last message — or whatever
# the agent is blocked on — is what you see, not the "> " prompt and
# "Model: … / bypass permissions" chrome. Agent panes are full terminal width
# and the popup wraps their lines, so only the trailing lines that fit the
# preview box once wrapped (FZF_PREVIEW_LINES x FZF_PREVIEW_COLUMNS) are
# printed: the latest status shows without scrolling. Wide characters such as
# emoji count as one column, so the box can still overflow slightly; the
# popup's preview-bottom binding keeps the end in view when it does.
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
    if (end == 0) exit

    # Keep the trailing lines whose wrapped height fits the preview box. Run
    # outside fzf (no size set), print everything.
    rows = ENVIRON["FZF_PREVIEW_LINES"] + 0
    cols = ENVIRON["FZF_PREVIEW_COLUMNS"] + 0
    start = 1
    if (rows > 0 && cols > 0) {
      used = 0
      for (i = end; i >= 1; i--) {
        h = int((length(a[i]) + cols - 1) / cols)
        if (h < 1) h = 1
        if (used + h > rows) break
        used += h
      }
      start = i + 1
      if (start > end) start = end   # one line taller than the box: show it anyway
      while (start < end && isblank(a[start])) start++
    }
    for (i = start; i <= end; i++) print a[i]
  }
'
