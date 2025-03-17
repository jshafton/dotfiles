#! /usr/bin/env bash

if ! hash git 2>/dev/null; then
  return
fi

__git_shortcut() {
  alias "$1"="git $2 $3"
  __git_complete "$1" "git_$2"
}

alias g="git"
__git_complete g git
__git_complete git __git_main

# Alias and set up tab completion
__git_shortcut ga add
__git_shortcut gb branch
__git_shortcut gbd branch -D
__git_shortcut gco checkout
__git_shortcut gd diff
__git_shortcut gf fetch
__git_shortcut gl log
__git_shortcut glp log -p
__git_shortcut gls log --stat
__git_shortcut gp push
__git_shortcut gpf push --force

# No completion for these
alias gs='git status'
alias gc='git commit'
alias gpr='git pull --rebase'
alias gin='git fetch; git whatchanged ..origin'
alias gout='git fetch; git whatchanged origin..'
alias gpsu='git push -u origin `git rev-parse --abbrev-ref HEAD`'
alias gfa='git fetch --all'
alias gcom='git checkout master'
alias gcomp='git checkout master && git pull'
alias gc-='git checkout -'
alias gdm='git diff master'
alias gdu='git diff @{upstream}'
alias gru='git reset @{upstream} --hard'
alias newbranch='git checkout master && git pull && git checkout -b '
