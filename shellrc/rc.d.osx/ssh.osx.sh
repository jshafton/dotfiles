#! /usr/bin/env sh

SCRIPT=$(cat <<'EOF'
  if hash tmux-next >/dev/null; then
    tmux="tmux-next"
  else
    tmux="tmux"
  fi

  $tmux new -A -s remote
EOF
)

if [ "$TERM" = "xterm-kitty" ]; then
  # https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
  ssh() {
    # currently broken with tmux
    # kitty +kitten ssh -t "$@" "$SCRIPT"
    TERM=xterm-256color /usr/bin/ssh -t "$@" "$SCRIPT"
  }
else
  ssh() {
    /usr/bin/ssh -t "$@" "$SCRIPT"
  }
fi
