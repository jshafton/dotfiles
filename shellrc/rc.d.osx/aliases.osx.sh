#! /usr/bin/env sh

if [ "$TERM" = "xterm-kitty" ]; then
  # https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
  alias ssh="kitty +kitten ssh"
fi
