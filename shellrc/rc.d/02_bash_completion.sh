#!/usr/bin/env bash

# Bash-only: skip if not running in bash
[[ -z "$BASH_VERSION" ]] && return 0

# Load bash-completion library
# Prefer homebrew's newer version (has _comp_initialize), fall back to system
if [[ -n "$HOMEBREW_PREFIX" && -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
  source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
elif [[ -f /etc/bash_completion ]]; then
  source /etc/bash_completion
fi

if type aws_completer &>/dev/null; then
  complete -C "aws_completer" aws
fi
