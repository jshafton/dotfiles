#! /usr/bin/env bash

# Homebrew on Linux
if [[ -d /home/linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# mise is configured in rc.d/mise.sh
