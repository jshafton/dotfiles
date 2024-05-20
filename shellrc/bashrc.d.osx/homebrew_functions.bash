if hash fzf 2>/dev/null; then
  # Install (one or multiple) selected application(s)
  # using "brew search" as source input
  # mnemonic [B]rew [I]nstall [P]lugin
  bip() {
    local inst=$(brew search $1 | fzf -m --preview 'brew info {}')

    if [[ $inst ]]; then
      for prog in $(echo $inst); do
        echo "Installing package $prog..."
        brew install $prog
      done
    fi
  }
  # Update (one or multiple) selected application(s)
  # mnemonic [B]rew [U]pdate [P]lugin
  bup() {
    local upd=$(brew outdated | fzf -m --reverse --preview 'brew info {}')

    if [[ $upd ]]; then
      for prog in $(echo $upd); do
        echo "Upgrading package $prog..."
        brew upgrade $prog
      done
    fi
  }
  # Delete (one or multiple) selected application(s)
  # mnemonic [B]rew [C]lean [P]lugin (e.g. uninstall)
  bcp() {
    local uninst=$(brew leaves | fzf -m --preview 'brew info {}')

    if [[ $uninst ]]; then
      for prog in $(echo $uninst); do
        echo "Uninstalling package $prog..."
        brew uninstall $prog
      done
    fi
  }
fi
