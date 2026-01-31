#!/usr/bin/env bash

# mise - polyglot runtime manager
# https://mise.jdx.dev/

if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
  eval "$(mise completion bash)"

  # mp - mise prod: run mise tasks in production environment
  mp() {
    mise -E prod run "$@"
  }

  # Completion wrapper for mp
  _mp() {
    local prefix="mise -E prod run "
    COMP_LINE="${prefix}${COMP_LINE#mp }"
    COMP_POINT=$((COMP_POINT + ${#prefix} - 3)) # -3 for "mp "
    COMP_WORDS=(mise -E prod run "${COMP_WORDS[@]:1}")
    COMP_CWORD=$((COMP_CWORD + 3))
    _mise
  }
  complete -o bashdefault -o nosort -o nospace -F _mp mp
fi
