#! /usr/bin/env bash

# fwt — fzf picker for git worktrees.
#
# enter    cd into the selected worktree in this shell
# ctrl-o   spawn a subshell in the worktree ($SHELL; exit to return)
# ctrl-t   attach tmux session for the worktree (switch-client if already in tmux,
#          else attach; creates the session named <repo>/<branch> on first use)
#
# Bound to Alt-W in readline. WezTerm sends ∑ (U+2211) for Alt-W when
# send_composed_key_when_*_alt_is_pressed = true (see .wezterm.lua).

# __fzf_worktree__ prints a shell command for the readline macro to evaluate,
# or nothing if the picker was dismissed. It never cds itself.
__fzf_worktree__() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'fwt: not a git repository\n' >&2
    return 1
  fi

  local rows selected key path
  rows=$(__fwt_list_worktrees) || return 1
  [[ -z "$rows" ]] && return 1

  if [[ $(printf '%s\n' "$rows" | wc -l) -eq 1 ]]; then
    path=$(printf '%s' "$rows" | cut -f1)
    printf 'fwt: only one worktree: %s\n' "$path" >&2
    return 0
  fi

  selected=$(
    printf '%s\n' "$rows" |
    fzf \
      --ansi \
      --no-sort \
      --delimiter=$'\t' \
      --with-nth=2 \
      --header='enter: cd  ·  ctrl-o: subshell  ·  ctrl-t: tmux' \
      --expect=ctrl-o,ctrl-t \
      --preview='p=$(printf %s {} | cut -f1); git -C "$p" log --oneline --decorate --color=always -20 2>/dev/null; echo; git -C "$p" -c color.status=always status -sb 2>/dev/null' \
      --preview-window='right,50%'
  ) || return 1

  key=$(printf '%s\n' "$selected" | sed -n '1p')
  path=$(printf '%s\n' "$selected" | sed -n '2p' | cut -f1)
  [[ -z "$path" ]] && return 1

  if [[ ! -d "$path" ]]; then
    printf 'fwt: worktree missing on disk: %s\n' "$path" >&2
    printf 'fwt: run `git worktree prune` (or `git worktree remove %q`) to clean up.\n' "$path" >&2
    return 1
  fi

  local session
  case "$key" in
    ctrl-o)
      printf '(builtin cd -- %q && exec "$SHELL")' "$path"
      ;;
    ctrl-t)
      if ! command -v tmux >/dev/null 2>&1; then
        printf 'fwt: tmux is not installed\n' >&2
        return 1
      fi
      session=$(__fwt_tmux_session "$path")
      if [[ -n "$TMUX" ]]; then
        printf '{ tmux has-session -t %q 2>/dev/null || tmux new-session -d -s %q -c %q; } && tmux switch-client -t %q' \
          "$session" "$session" "$path" "$session"
      else
        printf 'tmux attach-session -t %q 2>/dev/null || tmux new-session -s %q -c %q' \
          "$session" "$session" "$path"
      fi
      ;;
    *)
      printf 'builtin cd -- %q' "$path"
      ;;
  esac
}

# __fwt_tmux_session composes a tmux session name for a worktree path:
#   <repo-basename>/<branch-or-path-basename>
# Slashes in the branch are preserved (tmux allows them); `.` and `:` are
# forbidden by tmux and replaced with `_`.
__fwt_tmux_session() {
  local p="$1" main repo branch name
  main=$(git -C "$p" worktree list --porcelain 2>/dev/null \
    | awk '/^worktree /{print substr($0,10); exit}')
  repo=$(basename "${main:-$p}")
  branch=$(git -C "$p" branch --show-current 2>/dev/null)
  [[ -z "$branch" ]] && branch=$(basename "$p")
  name="$repo/$branch"
  name="${name//./_}"
  name="${name//:/_}"
  printf '%s' "$name"
}

# __fwt_list_worktrees prints one row per worktree, formatted as:
#   <raw_path>\t<aligned_display>
# The raw path is kept as field 1 so fzf can hide it from display/search while
# remaining trivially extractable from the selected line.
__fwt_list_worktrees() {
  local current_wt
  current_wt=$(git rev-parse --show-toplevel 2>/dev/null || true)

  git worktree list --porcelain | awk -v current="$current_wt" -v home="$HOME" '
    function flush() {
      if (path == "") return
      if (bare)          label = "(bare)"
      else if (detached) label = "(detached)"
      else if (branch)   label = branch
      else               label = "(unknown)"
      marker = (path == current ? "→" : "·")
      display = path
      sub("^" home, "~", display)
      print path "\t" marker "\t" label "\t" display "\t" sha
      path = ""; branch = ""; sha = ""; bare = 0; detached = 0
    }
    /^worktree /  { flush(); path = substr($0, 10) }
    /^HEAD /      { sha = substr($0, 6, 7) }
    /^branch /    { branch = substr($0, 19) }   # strip "branch refs/heads/"
    /^bare$/      { bare = 1 }
    /^detached$/  { detached = 1 }
    END           { flush() }
  ' | while IFS=$'\t' read -r p m l d s; do
    local dirty=" "
    if [[ ! -d "$p" ]]; then
      m="✗"
    elif [[ "$l" != "(bare)" ]] && [[ -n "$(git -C "$p" status --porcelain 2>/dev/null)" ]]; then
      dirty="●"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$p" "$m" "$l" "$d" "$s" "$dirty"
  done | awk -F'\t' '
    {
      rows[NR] = $0
      if (length($3) > w3) w3 = length($3)
      if (length($4) > w4) w4 = length($4)
      if (length($5) > w5) w5 = length($5)
    }
    END {
      for (i = 1; i <= NR; i++) {
        split(rows[i], f, "\t")
        # raw_path \t  marker branch-pad  path-pad  sha-pad  dirty
        printf "%s\t%s %-*s  %-*s  %-*s  %s\n", \
          f[1], f[2], w3, f[3], w4, f[4], w5, f[5], f[6]
      }
    }
  '
}

# fwt — interactive entry point. Runs the picker and executes its chosen
# command in the current shell.
fwt() {
  local cmd
  cmd=$(__fzf_worktree__) || return
  [[ -n "$cmd" ]] && eval "$cmd"
}

# Alt-W → picker. The readline macro mirrors fzf's stock Alt-C incantation:
# save the current line, insert the command substitution, execute, restore.
# ∑ (U+2211) is what WezTerm sends for Alt-W with send_composed_key enabled.
bind -m emacs-standard '"∑": " \C-b\C-k \C-u`__fzf_worktree__`\e\C-e\C-\e(\C-m\C-y\C-h\e \C-y\ey\C-x\C-x\C-d\C-y\ey\C-_"' 2>/dev/null
bind -m vi-command     '"∑": "\C-z∑\C-z"' 2>/dev/null
bind -m vi-insert      '"∑": "\C-z∑\C-z"' 2>/dev/null
