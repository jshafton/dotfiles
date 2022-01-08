#! /usr/bin/env bash

# libpq includes psql and other utils
if [ -d "${HOMEBREW_PREFIX}/opt/libpq/bin" ]; then
  path_prepend "${HOMEBREW_PREFIX}/opt/libpq/bin"
fi;

# TODO: remove this? make it not-OS-specific?
if [ -d ${HOMEBREW_PREFIX}/opt/coreutils/libexec ]; then
  export GNU_COREUTILS_PATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin"
  export GNU_COREUTILS_MANPATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnuman"
fi;

if [ -d $GNU_COREUTILS_PATH ]; then
  path_prepend "$GNU_COREUTILS_PATH"
fi;

if [ -d $GNU_COREUTILS_MANPATH ]; then
  export MANPATH="$GNU_COREUTILS_MANPATH:$PATH"
fi;
