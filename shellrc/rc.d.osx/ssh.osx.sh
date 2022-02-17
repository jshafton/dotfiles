#! /usr/bin/env sh

if [ "$TERM" = "xterm-kitty" ]; then
  # https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
  ssh() {
    kitty +kitten ssh -t "$@" tmux new -A -s remote
  }
else
  ssh() {
    /usr/bin/ssh -t "$@" tmux new -A -s remote
  }
fi
