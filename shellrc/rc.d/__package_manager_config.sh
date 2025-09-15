#! /usr/bin/env bash

if [[ -d /home/linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if command -v asdf >/dev/null 2>&1; then
  if [ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]; then
    path_prepend "${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
  fi

  eval "$(asdf completion bash)"
fi
