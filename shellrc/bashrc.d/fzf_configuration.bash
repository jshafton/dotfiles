#! /usr/bin/env bash

if hash bat 2>/dev/null; then
  export _fzf_preview_command='bat {} --color=always --paging=never --style=numbers'
else
  export _fzf_preview_command='cat {}'
fi

export FZF_DEFAULT_OPTS="
  --exact
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

# dracula color scheme
export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
  --color=dark
  --color=fg:-1,bg:-1,hl:#5fff87,fg+:-1,bg+:-1,hl+:#ffaf5f
  --color=info:#af87ff,prompt:#5fff87,pointer:#ff87d7,marker:#ff87d7,spinner:#ff87d7
'

# ctrl-r (shell history) has no file to preview
export FZF_CTRL_R_OPTS="--preview ''"

# ALT-C - cd into the selected directory
bind -m emacs-standard '"ç": " \C-b\C-k \C-u`__fzf_cd__`\e\C-e\er\C-m\C-y\C-h\e \C-y\ey\C-x\C-x\C-d"'
bind -m vi-command '"ç": "\C-z\ec\C-z"'
bind -m vi-insert '"ç": "\C-z\ec\C-z"'
