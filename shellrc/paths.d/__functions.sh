#! /usr/bin/env bash

path_append() {
  if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="${PATH:+"$PATH:"}$1"
  fi
}

path_prepend() {
  if [ -d "$1" ]; then
    # Remove from PATH if already present (ensures it moves to front)
    PATH="${PATH//$1:/}"
    PATH="${PATH//:$1/}"
    PATH="$1${PATH:+":$PATH"}"
  fi
}
