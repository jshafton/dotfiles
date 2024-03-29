#! /usr/bin/env bash

if [ ! -f "$HOME/.liquidprompt/liquidprompt" ]; then
  exit
fi

#############
# BEHAVIOUR #
#############

# Display the battery level in more urgent color when the level is below this threshold.
# Recommended value is 75
export LP_BATTERY_THRESHOLD=75

# Display the load average over the past minute when above this threshold.
# This value is scaled per CPU, so on a quad-core machine, the load average
# would need to be 2.40 or greater to be displayed.
# Recommended value is 0.60
export LP_LOAD_THRESHOLD=0.60

# Display the temperature when the temperate is above this threshold (in
# degrees Celsius).
# Recommended value is 60
export LP_TEMP_THRESHOLD=60

# Use the shorten path feature if the path is too long to fit in the prompt
# line.
# Recommended value is 1
export LP_ENABLE_SHORTEN_PATH=1

# The maximum percentage of the screen width used to display the path before
# removing the center portion of the path and replacing with '...'.
# Recommended value is 35
export LP_PATH_LENGTH=35

# The number of directories (including '/') to keep at the beginning of a
# shortened path.
# Recommended value is 2
export LP_PATH_KEEP=2

# Determine if the hostname should always be displayed, even if not connecting
# through network.
# Defaults to 0 (do not display hostname when locally connected)
# set to 1 if you want to always see the hostname
# set to -1 if you want to never see the hostname
export LP_HOSTNAME_ALWAYS=0

# Use the fully qualified domain name (FQDN) instead of the short hostname when
# the hostname is displayed
export LP_ENABLE_FQDN=0

# When to display the user name:
# 1: always display the user name
# 0: hide the logged user (always display different users)
# -1: never display the user name
# Default value is 1
export LP_USER_ALWAYS=0

# Display the actual values of load/batteries along with their
# corresponding marks. Set to 0 to only print the colored marks.
# Defaults to 1 (display percentages)
export LP_PERCENTS_ALWAYS=1

# Use the permissions feature and display a red ':' before the prompt to show
# when you don't have write permission to the current directory.
# Recommended value is 1
export LP_ENABLE_PERM=1

# Enable the proxy detection feature.
# Recommended value is 1
export LP_ENABLE_PROXY=1

# Enable the jobs feature.
# Recommended value is 1
export LP_ENABLE_JOBS=1

# Enable the detached sessions feature.
# Default value is 1
export LP_ENABLE_DETACHED_SESSIONS=0

# Enable the load feature.
# Recommended value is 1
export LP_ENABLE_LOAD=1

# Enable the battery feature.
# Recommended value is 1
export LP_ENABLE_BATT=1

# Enable the 'sudo credentials' feature.
# Be warned that this may pollute the syslog if you don't have sudo
# credentials, and the sysadmin might hate you.
export LP_ENABLE_SUDO=0

# Enable the directory stack support.
export LP_ENABLE_DIRSTACK=0

# Enable the VCS features with the root account.
# Recommended value is 0
export LP_ENABLE_VCS_ROOT=0

# Enable the Git special features.
# Recommended value is 1
export LP_ENABLE_GIT=1

# Enable the Subversion special features.
# Recommended value is 1
export LP_ENABLE_SVN=1

# Enable the Mercurial special features.
# Recommended value is 1
export LP_ENABLE_HG=1

# Enable the Fossil special features.
# Recommended value is 1
export LP_ENABLE_FOSSIL=1

# Enable the Bazaar special features.
# Recommanded value is 1
export LP_ENABLE_BZR=1

# Show time of when the current prompt was displayed.
export LP_ENABLE_TIME=1

# Show runtime of the previous command if over LP_RUNTIME_THRESHOLD
# Recommended value is 0
export LP_ENABLE_RUNTIME=0

# Minimal runtime (in seconds) before the runtime will be displayed
# Recommended value is 2
export LP_RUNTIME_THRESHOLD=2

# Ring the terminal bell if the runtime of the previous command exceeded
# LP_RUNTIME_BELL_THRESHOLD
# Recommended value is 0
export LP_ENABLE_RUNTIME_BELL=0

# Minimal runtime (in seconds) before the terminal bell will be rung.
# Recommended value is 10
export LP_RUNTIME_BELL_THRESHOLD=10

# Display the virtualenv that is currently activated, if any
# Recommended value is 1
export LP_ENABLE_VIRTUALENV=1

# Display the ruby virtual env that is currently activated, if any
# Recommended value is 1
export LP_ENABLE_RUBY_VENV=1

# If using RVM, personalize the rvm-prompt.
# see http://rvm.io/workflow/prompt for details.
# Warning, this variable must be a shell array.
# export LP_RUBY_RVM_PROMPT_OPTIONS=(i v g s)

# Display the terraform workspace that is currently activated, if any
# Recommended value is 0
export LP_ENABLE_TERRAFORM=1

# Display the enabled software collections, if any
# Recommended value is 1
export LP_ENABLE_SCLS=1

# Show current Kubernetes kubectl context
export LP_ENABLE_KUBECONTEXT=1

# Delimiter to shorten kubectl context by removing a suffix.
# E.g. when your context names are dev-cluster and test-cluster, set to "-"
# in order to output "dev" and "test" in prompt.
export LP_DELIMITER_KUBECONTEXT_SUFFIX=

# Delimiter to shorten kubectl context by removing a prefix.
# E.g. when your context names are like
# arn:aws:eks:$REGION:$ACCOUNT_ID:cluster/$CLUSTER_NAME, set to "/"
# in order to output "$CLUSTER_NAME" in prompt.
export LP_DELIMITER_KUBECONTEXT_PREFIX=

# Display the current active AWS_PROFILE, if any
# Recommended value is 1
export LP_ENABLE_AWS_PROFILE=1

# Show highest system temperature
export LP_ENABLE_TEMP=0

# When showing the time, use an analog clock instead of numeric values.
# Recommended value is 0
export LP_TIME_ANALOG=0

# Use the prompt as the title of the terminal window
# Recommended value is 0
export LP_ENABLE_TITLE=0

# Enable Title for screen, byobu, and tmux
export LP_ENABLE_SCREEN_TITLE=1

# Use different colors for the different hosts you SSH to
export LP_ENABLE_SSH_COLORS=0

# Show the error code of the last command if it was not 0
export LP_ENABLE_ERROR=1

# Specify an array of absolute paths in which all vcs will be disabled.
# Ex: ("/root" "/home/me/large-remove-svn-repo")
export LP_DISABLED_VCS_PATHS=()

# Show the value of $SHLVL, which is the number of nested shells.
export LP_ENABLE_SHLVL=0

# Put the command prompt on a newline
export LP_MARK_PREFIX=$' \n'

# Use a local liquidpromptrc if it exists.
# Can be helpful if you sync your primary config across machines, or if
# there's a system-wide config at /etc/liquidpromptrc from which you'd
# like to make only minor deviations.
#LOCAL_RCFILE=$HOME/.liquidpromptrc.local
#[ -f "$LOCAL_RCFILE" ] && source "$LOCAL_RCFILE"

# vim: set et sts=4 sw=4 tw=120 ft=sh:

source "$HOME/.liquidprompt/liquidprompt"
