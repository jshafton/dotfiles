#!/usr/bin/env bash

# Load system bash completion first
[ -f /etc/bash_completion ] && source /etc/bash_completion

# Add in all the completions installed with homebrew
if type brew &>/dev/null; then
  if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
      [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
    done
  fi
fi

if type aws_completer &>/dev/null; then
  complete -C "aws_completer" aws
fi
