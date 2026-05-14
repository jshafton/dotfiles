if hash fzf 2>/dev/null; then
  # [B]rew [I]nstall — fuzzy search and install
  bip() {
    if [[ $# -eq 0 ]]; then
      echo "Usage: bip <search-term>" >&2
      return 1
    fi
    local inst
    inst=$(brew search "$*" | fzf -m \
      --header 'tab: select  ctrl-a: all  enter: install' \
      --preview 'brew info {}' \
      --preview-window 'right:60%' \
      --bind 'ctrl-a:select-all')
    [[ -n "$inst" ]] || return
    while IFS= read -r prog; do
      echo "Installing $prog..."
      brew install "$prog"
    done <<< "$inst"
  }

  # [B]rew [U]pdate — select and upgrade outdated packages
  bup() {
    local upd
    upd=$(brew outdated --greedy | fzf -m \
      --header 'tab: select  ctrl-a: all  enter: upgrade' \
      --preview 'brew info {}' \
      --preview-window 'right:60%' \
      --bind 'ctrl-a:select-all')
    [[ -n "$upd" ]] || return
    while IFS= read -r prog; do
      echo "Upgrading $prog..."
      brew upgrade "$prog"
    done <<< "$upd"
  }

  # [B]rew [C]lean — uninstall any installed package (including deps)
  bcp() {
    local uninst
    uninst=$(brew list | fzf -m \
      --header 'tab: select  ctrl-a: all  enter: uninstall' \
      --preview 'brew info {}' \
      --preview-window 'right:60%' \
      --bind 'ctrl-a:select-all')
    [[ -n "$uninst" ]] || return
    while IFS= read -r prog; do
      echo "Uninstalling $prog..."
      brew uninstall "$prog"
    done <<< "$uninst"
  }

  # [B]rew [M]anage — browse intentionally-installed packages; upgrade or uninstall in place
  # Reads INSTALL_RECEIPT.json directly (glob, not recursive scan) to avoid hanging on binaries
  bm() {
    local prefix
    prefix=$(brew --prefix)
    local list_cmd="{ grep -l '\"installed_on_request\": true' \"${prefix}/Cellar\"/*/*/INSTALL_RECEIPT.json 2>/dev/null | sed 's|.*/Cellar/||;s|/.*||'; brew list --cask 2>/dev/null; } | sort -u"
    eval "$list_cmd" | fzf -m \
      --header 'ctrl-u: upgrade  ctrl-x: uninstall  ctrl-a: select all' \
      --preview 'brew info {}' \
      --preview-window 'right:60%' \
      --bind 'ctrl-a:select-all' \
      --bind "ctrl-u:execute(brew upgrade {+})+reload($list_cmd)" \
      --bind "ctrl-x:execute(brew uninstall {+})+reload($list_cmd)"
  }
fi
