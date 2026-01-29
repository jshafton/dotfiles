#! /usr/bin/env bash

# mise activation is handled in rc.d/mise.sh

# libpq includes psql and other utils
if [ -d "${HOMEBREW_PREFIX}/opt/libpq/bin" ]; then
  path_prepend "${HOMEBREW_PREFIX}/opt/libpq/bin"
fi;

# Java
if [ -d "${HOMEBREW_PREFIX}/opt/openjdk/bin" ]; then
  path_prepend "${HOMEBREW_PREFIX}/opt/openjdk/bin"
fi;

# GNU coreutils and findutils - prepend to override system versions
if [ -d "${HOMEBREW_PREFIX}/opt/coreutils/libexec" ]; then
  export GNU_COREUTILS_PATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin"
  export GNU_COREUTILS_MANPATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnuman"
  export GNU_FINDUTILS_PATH="${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin"
fi;

if [ -d "$GNU_COREUTILS_PATH" ]; then
  path_prepend "$GNU_COREUTILS_PATH"
fi;

if [ -d "$GNU_FINDUTILS_PATH" ]; then
  path_prepend "$GNU_FINDUTILS_PATH"
fi

if [ -d "$GNU_COREUTILS_MANPATH" ]; then
  export MANPATH="$GNU_COREUTILS_MANPATH:$MANPATH"
fi;
