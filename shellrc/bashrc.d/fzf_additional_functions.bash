#! /usr/bin/env bash

###############################################################################
# GIT
###############################################################################

# fco - checkout git branch/tag
fco() {
  local tags branches target
  tags=$(
    git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
  branches=$(
    git branch --all | grep -v HEAD             |
    sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
    sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
  target=$(
    (echo "$tags"; echo "$branches") |
    fzf --no-hscroll --ansi +m -d "\t" -n 2) || return
  git checkout $(echo "$target" | awk '{print $2}')
}

# fcoc - checkout commit by sha/comment
fcoc() {
  local commits commit
  commits=$(git log --pretty=oneline --abbrev-commit --reverse) &&
  commit=$(echo "$commits" | fzf --tac +s +m -e) &&
  git checkout $(echo "$commit" | sed "s/ .*//")
}

# fshow - git commit browser
fshow() {
  # param validation
  if [[ ! `git log -n 1 $@ | head -n 1` ]] ;then
    return
  fi

  # filter by file string
  local filter
  # param existed, git log for file if existed
  if [ -n $@ ] && [ -f $@ ]; then
    filter="-- $@"
  fi

  local pager
  if hash delta 2>/dev/null; then
    pager="delta --paging always"
  else
    pager="less -R"
  fi

  git log \
    --graph \
    --color=always \
    --abbrev=7 \
    --format='%C(auto)%h %an %C(blue)%s %C(yellow)%cr' \
    $@ \
  | fzf \
    --ansi --no-sort --reverse --tiebreak=index \
    --preview "f() { set -- \$(echo -- \$@ | grep -o '[a-f0-9]\{7\}'); [ \$# -eq 0 ] || git show \$1 $filter | $pager; }; f {}" \
    --bind "ctrl-q:abort,∆:down,˚:up,ctrl-m:execute: \
                (grep -o '[a-f0-9]\{7\}' | head -1 | \
                xargs -I % sh -c 'git show --color=always % $filter | $pager') << 'FZF-EOF'
                {}
                FZF-EOF"
}

###############################################################################
# search code
###############################################################################
fag() {
  if hash bat 2>/dev/null; then
    local preview_cmd='search={};file=$(echo $search | cut -d':' -f 1 );'
    preview_cmd+='line=$(echo $search | cut -d':' -f 2 );'
    preview_cmd+='bat $file --paging=never --color=always --highlight-line $line'

    ag --nobreak --noheading . | fzf -0 -1 --preview "$preview_cmd" --delimiter : --nth 4..
  else
    ag --nobreak --noheading . | fzf -0 -1 --delimiter : --nth 4..
  fi
}
