#! /usr/bin/env bash

if ! hash asdf 2>/dev/null; then
  return
fi

if [ -d "${ASDF_DATA_DIR:-$HOME/.asdf}/shims" ]; then
  path_prepend "${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
fi

. <(asdf completion bash)
