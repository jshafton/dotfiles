#!/bin/bash

if hash direnv >/dev/null 2>&1; then
  _direnv_hook() {
    local previous_exit_status=$?
    trap -- '' SIGINT
    eval "$("direnv" export bash)"
    trap - SIGINT
    return $previous_exit_status
  }
  if ! [[ "${PROMPT_COMMAND:-}" =~ _direnv_hook ]]; then
    PROMPT_COMMAND="_direnv_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
  fi
fi
