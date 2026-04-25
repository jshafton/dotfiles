#! /usr/bin/env bash

# Homebrew on Linux - set env vars manually and append to PATH so mise tools stay in front
if [[ -d /home/linuxbrew ]]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
  export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
  [ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
  export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}"
  path_append "/home/linuxbrew/.linuxbrew/bin"
  path_append "/home/linuxbrew/.linuxbrew/sbin"
fi

# mise is configured in rc.d/mise.sh
