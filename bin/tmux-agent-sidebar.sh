#!/usr/bin/env bash
# "Agent sidebar" for tmux: fzf popup listing every pane in the session that
# reports an agent state (blocked/working/idle), then focuses the selection.
# State comes from per-pane @agent_state / @agent_message, set by agent
# lifecycle hooks. Panes with no agent state (plain shells, editors) are
# omitted — this is an agent jumper, not a general pane picker.
set -euo pipefail
export PATH="$HOME/dotfiles/fzf/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export FZF_DEFAULT_OPTS= FZF_DEFAULT_OPTS_FILE=

# #{session_name} does not expand inside display-popup command strings, so the
# binding passes an empty TMUX_PANE_PICK_SESSION; resolve the session from the
# calling pane instead (display-message works inside a popup).
session="${TMUX_PANE_PICK_SESSION:-}"
[ -n "$session" ] || session="$(tmux display-message -p '#{session_name}' 2>/dev/null)"
[ -n "$session" ] || exit 0

# ANSI SGR codes — fzf --ansi renders these (it does not understand tmux #[...]).
RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; GRY=$'\033[90m'; BOLD=$'\033[1m'; RST=$'\033[0m'

label() {
  case "$1" in
    blocked) printf '%s%s● BLOCKED%s ' "$BOLD" "$RED" "$RST" ;;
    working) printf '%s● working%s ' "$YEL" "$RST" ;;
    idle)    printf '%s● idle%s    ' "$GRN" "$RST" ;;
    *)       printf '%s· unknown%s ' "$GRY" "$RST" ;;
  esac
}

rows() {
  tmux list-panes -a -F "#{session_name}|#{pane_id}|#{window_index}.#{pane_index}|#{window_name}|#{pane_current_command}|#{@agent_state}|#{@agent_message}|#{pane_current_path}|#{@agent_sidebar}" 2>/dev/null | awk -v s="$session" -F'|' '$1==s && $9!="1" && $6!=""' | cut -d'|' -f2-8 | while IFS='|' read -r pid wip wname cmd st msg cwd; do
    [ -n "$pid" ] || continue
    st="${st:-}"
    msglbl=""
    case "$st" in
      blocked) msglbl="${msg:-waiting for input}" ;;
      working|idle) msglbl="${msg:-}" ;;
    esac
    base="$(basename "${cwd:-}" 2>/dev/null || echo "?")"
    # sort key: blocked(0) < working(1) < idle(2) < unknown(3), then window
    case "$st" in
      blocked) u=0 ;;
      working) u=1 ;;
      idle)    u=2 ;;
      *)       u=3 ;;
    esac
    # ANSI-colored display column — fzf --ansi renders SGR codes
    printf '%s\t%s\t%s\t%s\n' "$u" "$pid" "$wip" \
      "$(label "$st")$wip  ${wname:+[$wname] }${cmd:-?}${msglbl:+  · $msglbl}  (${base:-?})"
  done | sort -n -k1,1 -k3,3 | cut -f2-
}

sel="$(rows | fzf \
  --delimiter=$'\t' --with-nth=3 --ansi --no-multi \
  --prompt="agent > " --reverse \
  --color=dark \
  --color=fg:#e8e4dc,bg:#262624,hl:#d97757 \
  --color=fg+:#e8e4dc,bg+:#3a3a37,hl+:#d97757 \
  --color=border:#5a5955,header:#7b9ebd,gutter:#262624 \
  --color=spinner:#c4956a,info:#938e87 \
  --color=pointer:#d97757,marker:#7da47a,prompt:#d97757 \
  --preview '/home/shafjac/bin/tmux-agent-preview.sh {1}' \
  --preview-window='down,65%,border-top,wrap' \
  --bind 'enter:accept,ctrl-\:abort,pgup:preview-page-up,pgdn:preview-page-down,load:preview-bottom,focus:preview-bottom' || true)"
[ -n "${sel:-}" ] || exit 0

pid="$(printf '%s' "$sel" | cut -f1)"
# switch to the pane's window first, then focus the pane (select-pane alone
# does not change windows)
win="$(tmux display-message -p -t "$pid" '#{window_index}' 2>/dev/null)"
[ -n "$win" ] && tmux select-window -t "$session:$win" >/dev/null 2>&1
tmux select-pane -t "$pid" >/dev/null 2>&1 || true
