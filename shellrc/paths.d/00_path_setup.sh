#!/usr/bin/env bash
# Centralized PATH setup for interactive bash shells.
#
# Desired order:
#   1. ~/.local/bin
#   2. ~/bin
#   3. ~/dotfiles/fzf/bin
#   4. mise shims
#   5. Homebrew (bin, sbin, and opt paths)
#   6. ~/.cargo/bin
#   7. system paths

# Append existing directories to PATH, skipping duplicates.
path_append() {
  local dir
  for dir; do
    [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] || continue
    PATH="${PATH:+"$PATH:"}$dir"
  done
}

# Detect Homebrew prefix across platforms.
HOMEBREW_PREFIX=""
if [ -d /home/linuxbrew/.linuxbrew ]; then
  HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
elif [ -d /opt/homebrew ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
elif [ -d /usr/local/Homebrew ]; then
  HOMEBREW_PREFIX="/usr/local"
fi

# Export Homebrew env vars and add it to PATH so the mise binary is found.
if [ -n "$HOMEBREW_PREFIX" ]; then
  export HOMEBREW_PREFIX
  export HOMEBREW_CELLAR="${HOMEBREW_PREFIX}/Cellar"
  export HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  [ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
  export INFOPATH="${HOMEBREW_PREFIX}/share/info:${INFOPATH:-}"
  path_append "${HOMEBREW_PREFIX}/sbin" "${HOMEBREW_PREFIX}/bin"

  # GNU coreutils and findutils (override system versions).
  if [ -d "${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin" ]; then
    export GNU_COREUTILS_PATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin"
    export GNU_COREUTILS_MANPATH="${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnuman"
  fi
  if [ -d "${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin" ]; then
    export GNU_FINDUTILS_PATH="${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin"
  fi
fi

# Activate mise on the inherited PATH. Clear stale state so mise recaptures
# the current base instead of reusing a cached order from a previous session.
if command -v mise &>/dev/null; then
  unset __MISE_ORIG_PATH __MISE_SESSION __MISE_DIFF
  eval "$(mise activate bash)"
  # Materialize shims immediately rather than waiting for the first prompt.
  if [[ $(type -t _mise_hook) == function ]]; then
    _mise_hook
  fi
fi

# Split current PATH into mise shims and the non-mise remainder.
MISE_PATH=$(echo "$PATH" | tr ':' '\n' | grep '/mise/' | tr '\n' ':' | sed 's/:$//')
NON_MISE_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/mise/' | tr '\n' ':' | sed 's/:$//')

# Drop directories we'll place explicitly so the final order is deterministic.
for d in "$HOME/.local/bin" "$HOME/bin" "$HOME/dotfiles/fzf/bin" \
         "$HOME/.cargo/bin" "$HOME/.rd/bin" \
         "${HOMEBREW_PREFIX}/sbin" "${HOMEBREW_PREFIX}/bin" \
         "${HOMEBREW_PREFIX}/opt/libpq/bin" \
         "${HOMEBREW_PREFIX}/opt/openjdk/bin" \
         "${GNU_COREUTILS_PATH:-}" "${GNU_FINDUTILS_PATH:-}"; do
  [ -n "$d" ] || continue
  NON_MISE_PATH="${NON_MISE_PATH//$d:/}"
  NON_MISE_PATH="${NON_MISE_PATH//:$d/}"
  NON_MISE_PATH="${NON_MISE_PATH/#$d/}"
done

# Reconstruct PATH in the exact desired order.
PATH=""
IFS=: read -ra MISE_DIRS <<< "$MISE_PATH"
IFS=: read -ra TAIL_DIRS <<< "$NON_MISE_PATH"
path_append \
  "$HOME/.local/bin" \
  "$HOME/bin" \
  "$HOME/dotfiles/fzf/bin" \
  "${MISE_DIRS[@]}" \
  "${HOMEBREW_PREFIX}/sbin" \
  "${HOMEBREW_PREFIX}/bin" \
  "${HOMEBREW_PREFIX}/opt/libpq/bin" \
  "${HOMEBREW_PREFIX}/opt/openjdk/bin" \
  "${GNU_COREUTILS_PATH:-}" \
  "${GNU_FINDUTILS_PATH:-}" \
  "$HOME/.cargo/bin" \
  "$HOME/.rd/bin" \
  "${TAIL_DIRS[@]}"
