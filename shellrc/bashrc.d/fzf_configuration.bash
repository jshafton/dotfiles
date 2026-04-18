#! /usr/bin/env bash

if hash bat 2>/dev/null; then
  export _fzf_preview_command='bat {} --color=always --paging=never --style=numbers'
else
  export _fzf_preview_command='cat {}'
fi

export FZF_DEFAULT_OPTS="
  --preview '$_fzf_preview_command'
  --bind '?:toggle-preview'
  --bind 'ctrl-u:page-up'
  --bind 'ctrl-d:page-down'
  --bind 'ctrl-f:preview-page-down'
  --bind 'ctrl-b:preview-page-up'
"
# --preview-window 'right:60%:hidden'
#   ctrl-b:preview-page-up,ctrl-f:preview-page-down, \
#   ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down, \
#   shift-up:preview-top,shift-down:preview-bottom, \
#   alt-up:half-page-up,alt-down:half-page-down

# token-dark color scheme
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
  --color=dark
  --color=fg:#e8e4dc,bg:#262624,hl:#d97757
  --color=fg+:#e8e4dc,bg+:#3a3a37,hl+:#d97757
  --color=border:#5a5955,header:#7b9ebd,gutter:#262624
  --color=spinner:#c4956a,info:#938e87
  --color=pointer:#d97757,marker:#7da47a,prompt:#d97757
'

# ctrl-r (shell history) has no file to preview
export FZF_CTRL_R_OPTS="--preview ''"

# alt-c (cd) - preview directory contents instead of trying to bat a dir
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

# ALT-C - cd into the selected directory
# NOTE: "ç" is what WezTerm sends for Alt-C with send_composed_key enabled.
# The readline macro must match what `fzf --bash` uses for "\ec".
bind -m emacs-standard '"ç": " \C-b\C-k \C-u`__fzf_cd__`\e\C-e\C-\e(\C-m\C-y\C-h\e \C-y\ey\C-x\C-x\C-d\C-y\ey\C-_"'
bind -m vi-command '"ç": "\C-z\ec\C-z"'
bind -m vi-insert '"ç": "\C-z\ec\C-z"'
