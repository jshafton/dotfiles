#!/usr/bin/env bash
# Persistent "agent sidebar" pane: live list of every pane in the session with
# its reported agent state, highest urgency first. Runs as a loop in a tmux
# pane. Refreshes instantly when the aggregator signals a state change
# (tmux wait-for agent-state-changed), with a 1s fallback poll for changes
# that bypass the aggregator (new panes, renames). State comes from per-pane
# user options:
#   tmux set-option -p @agent_state  working|blocked|idle
#   tmux set-option -p @agent_message "approval: ..."
set -euo pipefail

session="${TMUX_AGENT_SIDEBAR_SESSION:-}"
[ -n "$session" ] || session="$(tmux display-message -p '#{session_name}')"

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; GRY=$'\033[90m'; BOLD=$'\033[1m'; RST=$'\033[0m'

color() {
  case "$1" in
    blocked) printf '%s%s' "$BOLD" "$RED" ;;
    working) printf '%s' "$YEL" ;;
    idle)    printf '%s' "$GRN" ;;
    *)       printf '%s' "$GRY" ;;
  esac
}
label() {
  case "$1" in
    blocked) printf 'BLOCKED ' ;;
    working) printf 'working ' ;;
    idle)    printf 'idle    ' ;;
    *)       printf 'unknown ' ;;
  esac
}

urgency() {
  case "$1" in
    blocked) echo 0 ;;
    working) echo 1 ;;
    idle)    echo 2 ;;
    *)       echo 3 ;;
  esac
}

render() {
  tmux list-panes -a -F "#{session_name}|#{pane_id}|#{window_index}.#{pane_index}|#{pane_current_command}|#{@agent_state}|#{@agent_message}|#{pane_current_path}|#{@agent_sidebar}" 2>/dev/null |
    awk -F'|' -v s="$session" '$1==s && $8!="1"' |
    cut -d'|' -f1-7 |
    while IFS='|' read -r _ pid wip cmd st msg cwd; do
      [ -n "$pid" ] || continue
      st="${st:-}"
      base="$(basename "${cwd:-}" 2>/dev/null || echo '?')"
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(urgency "$st")" "$st" "$wip" "$cmd" "$msg" "$base"
    done |
    sort -n -k1,1 |
    while IFS=$'\t' read -r u st wip cmd msg base; do
      c="$(color "$st")"
      l="$(label "$st")"
      ml=""
      [ "$st" = "blocked" ] && [ -n "$msg" ] && ml="  · $msg"
      printf '%s%s %s  %s%s  (%s)%s\n' "$c" "$l" "$wip" "${cmd:-?}" "$ml" "$base" "$RST"
    done
}

while true; do
  clear
  printf '%s%sAGENTS — %s%s\n' "$BOLD" "$GRY" "$session" "$RST"
  printf '%s──────────────────────────────%s\n' "$GRY" "$RST"
  render
  # wake instantly on a state-change signal, else fall back to a 1s poll
  timeout 1 tmux wait-for agent-state-changed 2>/dev/null || true
done
