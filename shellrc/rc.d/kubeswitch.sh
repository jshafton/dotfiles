#!/usr/bin/env bash

if ! hash switcher 2>/dev/null; then
  return
fi

has_prefix() { case $2 in "$1"*) true ;; *) false ;; esac }
function switch() {
  #  if the executable path is not set, the switcher binary has to be on the path
  # this is the case when installing it via homebrew

  local DEFAULT_EXECUTABLE_PATH="switcher"
  declare -a opts

  while test $# -gt 0; do
    case "$1" in
    --executable-path)
      EXECUTABLE_PATH="$1"
      ;;
    completion)
      opts+=("$1" --cmd switch)
      ;;
    *)
      opts+=("$1")
      ;;
    esac
    shift
  done

  if [ -z "$EXECUTABLE_PATH" ]; then
    EXECUTABLE_PATH="$DEFAULT_EXECUTABLE_PATH"
  fi

  RESPONSE="$($EXECUTABLE_PATH "${opts[@]}")"
  if [ $? -ne 0 -o -z "$RESPONSE" ]; then
    printf "%s\n" "$RESPONSE"
    return $?
  fi

  # switcher returns a response that contains a kubeconfig path with a prefix "__ " to be able to
  # distinguish it from other responses which just need to write to STDOUT
  prefix="__ "
  if ! has_prefix "$prefix" "$RESPONSE"; then
    printf "%s\n" "$RESPONSE"
    return
  fi

  # remove prefix
  RESPONSE=${RESPONSE#"$prefix"}

  #the response form the switcher binary is "kubeconfig_path,selected_context"
  remainder="$RESPONSE"
  KUBECONFIG_PATH="${remainder%%,*}"
  remainder="${remainder#*,}"
  SELECTED_CONTEXT="${remainder%%,*}"
  remainder="${remainder#*,}"

  if [ -z ${KUBECONFIG_PATH+x} ]; then
    # KUBECONFIG_PATH is not set
    printf "%s\n" "$RESPONSE"
    return
  fi

  if [ -z ${SELECTED_CONTEXT+x} ]; then
    # SELECTED_CONTEXT is not set
    printf "%s\n" "$RESPONSE"
    return
  fi

  # cleanup old temporary kubeconfig file
  local switchTmpDirectory="$HOME/.kube/.switch_tmp/config"
  if [[ -n "$KUBECONFIG" && "$KUBECONFIG" == *"$switchTmpDirectory"* ]]; then
    \rm -f "$KUBECONFIG"
  fi

  export KUBECONFIG="$KUBECONFIG_PATH"
  printf "switched to context %s\n" "$SELECTED_CONTEXT"
}
# bash completion for switcher                             -*- shell-script -*-

__switcher_debug() {
  if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
    echo "$*" >>"${BASH_COMP_DEBUG_FILE}"
  fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__switcher_init_completion() {
  COMPREPLY=()
  _get_comp_words_by_ref "$@" cur prev words cword
}

__switcher_index_of_word() {
  local w word=$1
  shift
  index=0
  for w in "$@"; do
    [[ $w = "$word" ]] && return
    index=$((index + 1))
  done
  index=-1
}

__switcher_contains_word() {
  local w word=$1
  shift
  for w in "$@"; do
    [[ $w = "$word" ]] && return
  done
  return 1
}

__switcher_handle_go_custom_completion() {
  __switcher_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

  local shellCompDirectiveError=1
  local shellCompDirectiveNoSpace=2
  local shellCompDirectiveNoFileComp=4
  local shellCompDirectiveFilterFileExt=8
  local shellCompDirectiveFilterDirs=16

  local out requestComp lastParam lastChar comp directive args

  # Prepare the command to request completions for the program.
  # Calling ${words[0]} instead of directly switcher allows to handle aliases
  args=("${words[@]:1}")
  # Disable ActiveHelp which is not supported for bash completion v1
  requestComp="SWITCHER_ACTIVE_HELP=0 ${words[0]} __completeNoDesc ${args[*]}"

  lastParam=${words[$((${#words[@]} - 1))]}
  lastChar=${lastParam:$((${#lastParam} - 1)):1}
  __switcher_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

  if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
    # If the last parameter is complete (there is a space following it)
    # We add an extra empty parameter so we can indicate this to the go method.
    __switcher_debug "${FUNCNAME[0]}: Adding extra empty parameter"
    requestComp="${requestComp} \"\""
  fi

  __switcher_debug "${FUNCNAME[0]}: calling ${requestComp}"
  # Use eval to handle any environment variables and such
  out=$(eval "${requestComp}" 2>/dev/null)

  # Extract the directive integer at the very end of the output following a colon (:)
  directive=${out##*:}
  # Remove the directive
  out=${out%:*}
  if [ "${directive}" = "${out}" ]; then
    # There is not directive specified
    directive=0
  fi
  __switcher_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
  __switcher_debug "${FUNCNAME[0]}: the completions are: ${out}"

  if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
    # Error code.  No completion.
    __switcher_debug "${FUNCNAME[0]}: received error from custom completion go code"
    return
  else
    if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
      if [[ $(type -t compopt) = "builtin" ]]; then
        __switcher_debug "${FUNCNAME[0]}: activating no space"
        compopt -o nospace
      fi
    fi
    if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
      if [[ $(type -t compopt) = "builtin" ]]; then
        __switcher_debug "${FUNCNAME[0]}: activating no file completion"
        compopt +o default
      fi
    fi
  fi

  if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
    # File extension filtering
    local fullFilter filter filteringCmd
    # Do not use quotes around the $out variable or else newline
    # characters will be kept.
    for filter in ${out}; do
      fullFilter+="$filter|"
    done

    filteringCmd="_filedir $fullFilter"
    __switcher_debug "File filtering command: $filteringCmd"
    $filteringCmd
  elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
    # File completion for directories only
    local subdir
    # Use printf to strip any trailing newline
    subdir=$(printf "%s" "${out}")
    if [ -n "$subdir" ]; then
      __switcher_debug "Listing directories in $subdir"
      __switcher_handle_subdirs_in_dir_flag "$subdir"
    else
      __switcher_debug "Listing directories in ."
      _filedir -d
    fi
  else
    while IFS='' read -r comp; do
      COMPREPLY+=("$comp")
    done < <(compgen -W "${out}" -- "$cur")
  fi
}

__switcher_handle_reply() {
  __switcher_debug "${FUNCNAME[0]}"
  local comp
  case $cur in
  -*)
    if [[ $(type -t compopt) = "builtin" ]]; then
      compopt -o nospace
    fi
    local allflags
    if [ ${#must_have_one_flag[@]} -ne 0 ]; then
      allflags=("${must_have_one_flag[@]}")
    else
      allflags=("${flags[*]} ${two_word_flags[*]}")
    fi
    while IFS='' read -r comp; do
      COMPREPLY+=("$comp")
    done < <(compgen -W "${allflags[*]}" -- "$cur")
    if [[ $(type -t compopt) = "builtin" ]]; then
      [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
    fi

    # complete after --flag=abc
    if [[ $cur == *=* ]]; then
      if [[ $(type -t compopt) = "builtin" ]]; then
        compopt +o nospace
      fi

      local index flag
      flag="${cur%=*}"
      __switcher_index_of_word "${flag}" "${flags_with_completion[@]}"
      COMPREPLY=()
      if [[ ${index} -ge 0 ]]; then
        PREFIX=""
        cur="${cur#*=}"
        ${flags_completion[${index}]}
        if [ -n "${ZSH_VERSION:-}" ]; then
          # zsh completion needs --flag= prefix
          eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
        fi
      fi
    fi

    if [[ -z "${flag_parsing_disabled}" ]]; then
      # If flag parsing is enabled, we have completed the flags and can return.
      # If flag parsing is disabled, we may not know all (or any) of the flags, so we fallthrough
      # to possibly call handle_go_custom_completion.
      return 0
    fi
    ;;
  esac

  # check if we are handling a flag with special work handling
  local index
  __switcher_index_of_word "${prev}" "${flags_with_completion[@]}"
  if [[ ${index} -ge 0 ]]; then
    ${flags_completion[${index}]}
    return
  fi

  # we are parsing a flag and don't have a special handler, no completion
  if [[ ${cur} != "${words[cword]}" ]]; then
    return
  fi

  local completions
  completions=("${commands[@]}")
  if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
    completions+=("${must_have_one_noun[@]}")
  elif [[ -n "${has_completion_function}" ]]; then
    # if a go completion function is provided, defer to that function
    __switcher_handle_go_custom_completion
  fi
  if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
    completions+=("${must_have_one_flag[@]}")
  fi
  while IFS='' read -r comp; do
    COMPREPLY+=("$comp")
  done < <(compgen -W "${completions[*]}" -- "$cur")

  if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
    while IFS='' read -r comp; do
      COMPREPLY+=("$comp")
    done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
  fi

  if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
    if declare -F __switcher_custom_func >/dev/null; then
      # try command name qualified custom func
      __switcher_custom_func
    else
      # otherwise fall back to unqualified for compatibility
      declare -F __custom_func >/dev/null && __custom_func
    fi
  fi

  # available in bash-completion >= 2, not always present on macOS
  if declare -F __ltrim_colon_completions >/dev/null; then
    __ltrim_colon_completions "$cur"
  fi

  # If there is only 1 completion and it is a flag with an = it will be completed
  # but we don't want a space after the =
  if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
    compopt -o nospace
  fi
}

# The arguments should be in the form "ext1|ext2|extn"
__switcher_handle_filename_extension_flag() {
  local ext="$1"
  _filedir "@(${ext})"
}

__switcher_handle_subdirs_in_dir_flag() {
  local dir="$1"
  pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__switcher_handle_flag() {
  __switcher_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

  # if a command required a flag, and we found it, unset must_have_one_flag()
  local flagname=${words[c]}
  local flagvalue=""
  # if the word contained an =
  if [[ ${words[c]} == *"="* ]]; then
    flagvalue=${flagname#*=} # take in as flagvalue after the =
    flagname=${flagname%=*}  # strip everything after the =
    flagname="${flagname}="  # but put the = back
  fi
  __switcher_debug "${FUNCNAME[0]}: looking for ${flagname}"
  if __switcher_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
    must_have_one_flag=()
  fi

  # if you set a flag which only applies to this command, don't show subcommands
  if __switcher_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
    commands=()
  fi

  # keep flag value with flagname as flaghash
  # flaghash variable is an associative array which is only supported in bash > 3.
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    if [ -n "${flagvalue}" ]; then
      flaghash[${flagname}]=${flagvalue}
    elif [ -n "${words[$((c + 1))]}" ]; then
      flaghash[${flagname}]=${words[$((c + 1))]}
    else
      flaghash[${flagname}]="true" # pad "true" for bool flag
    fi
  fi

  # skip the argument to a two word flag
  if [[ ${words[c]} != *"="* ]] && __switcher_contains_word "${words[c]}" "${two_word_flags[@]}"; then
    __switcher_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
    c=$((c + 1))
    # if we are looking for a flags value, don't show commands
    if [[ $c -eq $cword ]]; then
      commands=()
    fi
  fi

  c=$((c + 1))

}

__switcher_handle_noun() {
  __switcher_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

  if __switcher_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
    must_have_one_noun=()
  elif __switcher_contains_word "${words[c]}" "${noun_aliases[@]}"; then
    must_have_one_noun=()
  fi

  nouns+=("${words[c]}")
  c=$((c + 1))
}

__switcher_handle_command() {
  __switcher_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

  local next_command
  if [[ -n ${last_command} ]]; then
    next_command="_${last_command}_${words[c]//:/__}"
  else
    if [[ $c -eq 0 ]]; then
      next_command="_switcher_root_command"
    else
      next_command="_${words[c]//:/__}"
    fi
  fi
  c=$((c + 1))
  __switcher_debug "${FUNCNAME[0]}: looking for ${next_command}"
  declare -F "$next_command" >/dev/null && $next_command
}

__switcher_handle_word() {
  if [[ $c -ge $cword ]]; then
    __switcher_handle_reply
    return
  fi
  __switcher_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
  if [[ "${words[c]}" == -* ]]; then
    __switcher_handle_flag
  elif __switcher_contains_word "${words[c]}" "${commands[@]}"; then
    __switcher_handle_command
  elif [[ $c -eq 0 ]]; then
    __switcher_handle_command
  elif __switcher_contains_word "${words[c]}" "${command_aliases[@]}"; then
    # aliashash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
      words[c]=${aliashash[${words[c]}]}
      __switcher_handle_command
    else
      __switcher_handle_noun
    fi
  else
    __switcher_handle_noun
  fi
  __switcher_handle_word
}

_switcher_alias_ls() {
  last_command="switcher_alias_ls"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_alias_rm() {
  last_command="switcher_alias_rm"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_alias() {
  last_command="switcher_alias"

  command_aliases=()

  commands=()
  commands+=("ls")
  commands+=("rm")

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_switcher_clean() {
  last_command="switcher_clean"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_completion() {
  last_command="switcher_completion"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--cmd=")
  two_word_flags+=("--cmd")
  two_word_flags+=("-c")
  local_nonpersistent_flags+=("--cmd")
  local_nonpersistent_flags+=("--cmd=")
  local_nonpersistent_flags+=("-c")

  must_have_one_flag=()
  must_have_one_noun=()
  must_have_one_noun+=("bash")
  must_have_one_noun+=("fish")
  must_have_one_noun+=("powershell")
  must_have_one_noun+=("zsh")
  noun_aliases=()
}

_switcher_current-context() {
  last_command="switcher_current-context"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_delete-context() {
  last_command="switcher_delete-context"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_exec() {
  last_command="switcher_exec"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_gardener_controlplane() {
  last_command="switcher_gardener_controlplane"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_switcher_gardener() {
  last_command="switcher_gardener"

  command_aliases=()

  commands=()
  commands+=("controlplane")

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_switcher_help() {
  last_command="switcher_help"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_history() {
  last_command="switcher_history"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_hooks_ls() {
  last_command="switcher_hooks_ls"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_hooks() {
  last_command="switcher_hooks"

  command_aliases=()

  commands=()
  commands+=("ls")

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--hook-name=")
  two_word_flags+=("--hook-name")
  local_nonpersistent_flags+=("--hook-name")
  local_nonpersistent_flags+=("--hook-name=")
  flags+=("--run-immediately")
  local_nonpersistent_flags+=("--run-immediately")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_switcher_init() {
  last_command="switcher_init"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--help")
  flags+=("-h")
  local_nonpersistent_flags+=("--help")
  local_nonpersistent_flags+=("-h")

  must_have_one_flag=()
  must_have_one_noun=()
  must_have_one_noun+=("bash")
  must_have_one_noun+=("fish")
  must_have_one_noun+=("powershell")
  must_have_one_noun+=("zsh")
  noun_aliases=()
}

_switcher_list-contexts() {
  last_command="switcher_list-contexts"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_namespace() {
  last_command="switcher_namespace"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_set-context() {
  last_command="switcher_set-context"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_set-last-context() {
  last_command="switcher_set-last-context"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_set-previous-context() {
  last_command="switcher_set-previous-context"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_unset-context() {
  last_command="switcher_unset-context"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_unset-namespace() {
  last_command="switcher_unset-namespace"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  has_completion_function=1
  noun_aliases=()
}

_switcher_version() {
  last_command="switcher_version"

  command_aliases=()

  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_switcher_root_command() {
  last_command="switcher"

  command_aliases=()

  commands=()
  commands+=("alias")
  commands+=("clean")
  commands+=("completion")
  commands+=("current-context")
  commands+=("delete-context")
  commands+=("exec")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("e")
    aliashash["e"]="exec"
  fi
  commands+=("gardener")
  commands+=("help")
  commands+=("history")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("h")
    aliashash["h"]="history"
    command_aliases+=("history")
    aliashash["history"]="history"
  fi
  commands+=("hooks")
  commands+=("init")
  commands+=("list-contexts")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("ls")
    aliashash["ls"]="list-contexts"
  fi
  commands+=("namespace")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("ns")
    aliashash["ns"]="namespace"
  fi
  commands+=("set-context")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("sc")
    aliashash["sc"]="set-context"
    command_aliases+=("set")
    aliashash["set"]="set-context"
    command_aliases+=("set-context")
    aliashash["set-context"]="set-context"
  fi
  commands+=("set-last-context")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("slc")
    aliashash["slc"]="set-last-context"
  fi
  commands+=("set-previous-context")
  if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
    command_aliases+=("spc")
    aliashash["spc"]="set-previous-context"
  fi
  commands+=("unset-context")
  commands+=("unset-namespace")
  commands+=("version")

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  flags+=("--config-path=")
  two_word_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path")
  local_nonpersistent_flags+=("--config-path=")
  flags+=("--current")
  flags+=("-c")
  local_nonpersistent_flags+=("--current")
  local_nonpersistent_flags+=("-c")
  flags+=("--d")
  flags+=("-d")
  local_nonpersistent_flags+=("--d")
  local_nonpersistent_flags+=("-d")
  flags+=("--debug")
  local_nonpersistent_flags+=("--debug")
  flags+=("--kubeconfig-name=")
  two_word_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name")
  local_nonpersistent_flags+=("--kubeconfig-name=")
  flags+=("--kubeconfig-path=")
  two_word_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path")
  local_nonpersistent_flags+=("--kubeconfig-path=")
  flags+=("--no-index")
  local_nonpersistent_flags+=("--no-index")
  flags+=("--show-preview")
  local_nonpersistent_flags+=("--show-preview")
  flags+=("--state-directory=")
  two_word_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory")
  local_nonpersistent_flags+=("--state-directory=")
  flags+=("--store=")
  two_word_flags+=("--store")
  local_nonpersistent_flags+=("--store")
  local_nonpersistent_flags+=("--store=")
  flags+=("--unset")
  flags+=("-u")
  local_nonpersistent_flags+=("--unset")
  local_nonpersistent_flags+=("-u")
  flags+=("--vault-api-address=")
  two_word_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address")
  local_nonpersistent_flags+=("--vault-api-address=")

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

__start_switcher() {
  local cur prev words cword split
  declare -A flaghash 2>/dev/null || :
  declare -A aliashash 2>/dev/null || :
  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -s || return
  else
    __switcher_init_completion -n "=" || return
  fi

  local c=0
  local flag_parsing_disabled=
  local flags=()
  local two_word_flags=()
  local local_nonpersistent_flags=()
  local flags_with_completion=()
  local flags_completion=()
  local commands=("switcher")
  local command_aliases=()
  local must_have_one_flag=()
  local must_have_one_noun=()
  local has_completion_function=""
  local last_command=""
  local nouns=()
  local noun_aliases=()

  __switcher_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
  complete -o default -F __start_switcher switcher
else
  complete -o default -o nospace -F __start_switcher switcher
fi

alias s=switch
complete -o default -F _switcher s

# ex: ts=4 sw=4 et filetype=sh
