# Append to the Bash history file, rather than overwriting it
shopt -s histappend
# Attempt to save all lines of a multiple-line command in the same entry
shopt -s cmdhist

# Larger bash history (allow 32³ entries; default is 500)
# export HISTSIZE=-1
export HISTSIZE=32768
export HISTFILESIZE=$HISTSIZE
export HISTFILE=$HOME/.history

# Ignore lines starting with a whitespace, as well as duplicates
export HISTCONTROL=ignoredups:ignorespace

# After each command, append to the history file and reread it
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}history -a"
