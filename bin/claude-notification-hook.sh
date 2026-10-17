#!/bin/bash
# Claude notification hook - works local and remote via OSC 1337.
# Sends notification data to WezTerm through tmux passthrough. Wired to Stop,
# PermissionRequest and Notification; reads the hook's JSON input on stdin.
#
# Every tmux lookup targets $TMUX_PANE (the pane Claude runs in). Without -t,
# tmux answers for whatever pane the user is looking at.

# Skip if not in tmux
[[ -z "$TMUX" || -z "$TMUX_PANE" ]] && exit 0

mkdir -p "$HOME/.claude" 2>/dev/null
LOG="$HOME/.claude/notification-debug.log"
# Keep the log small: start over once it passes 1 MB, keeping one old copy.
[[ $(stat -c %s "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]] && mv -f "$LOG" "$LOG.1"
log() { echo "$(date '+%F %T') $TMUX_PANE: $*" >> "$LOG"; }

INPUT=$(cat)
EVENT=$(jq -r '.hook_event_name // ""' <<<"$INPUT" 2>/dev/null)
NOTIFICATION_TYPE=$(jq -r '.notification_type // ""' <<<"$INPUT" 2>/dev/null)

# Skip notifications that repeat one already sent:
#   permission_prompt follows PermissionRequest a few seconds later.
#   idle_prompt follows Stop about 60 seconds later.
case "$NOTIFICATION_TYPE" in
  permission_prompt) log "SKIPPED $EVENT/$NOTIFICATION_TYPE - PermissionRequest already notified"; exit 0 ;;
  idle_prompt)       log "SKIPPED $EVENT/$NOTIFICATION_TYPE - Stop already notified"; exit 0 ;;
esac

# Stop fires at the end of every turn, including turns where Claude is only
# waiting for background work (subagents, shells, scheduled wakeups) to wake
# it again. That agent doesn't need you yet.
if [[ "$EVENT" == "Stop" ]]; then
  PENDING=$(jq '(.background_tasks // []) + (.session_crons // []) | length' <<<"$INPUT" 2>/dev/null)
  if [[ "${PENDING:-0}" -gt 0 ]]; then
    log "SKIPPED Stop - waiting on $PENDING background task(s)"
    exit 0
  fi
fi

IFS=$'\t' read -r TMUX_SESSION TMUX_WINDOW PANE_TTY PANE_ACTIVE WINDOW_ACTIVE PANE_TITLE < <(
  tmux display-message -t "$TMUX_PANE" -p \
    $'#{session_name}\t#{window_index}\t#{pane_tty}\t#{pane_active}\t#{window_active}\t#{pane_title}' 2>/dev/null
)
# Claude prefixes its pane title with a spinner glyph. sed rather than ${//},
# which mishandles these multibyte glyphs when the hook's locale is not UTF-8.
# shellcheck disable=SC2001
PANE_TITLE=$(sed 's/^[✳⠂⠐ ]*//' <<<"$PANE_TITLE")

case "$EVENT" in
  PermissionRequest) REASON="Needs permission: $(jq -r '.tool_name // "tool"' <<<"$INPUT" 2>/dev/null)" ;;
  Notification)      REASON=$(jq -r '.message // ""' <<<"$INPUT" 2>/dev/null) ;;
  Stop)              REASON="Finished" ;;
  *)                 REASON="" ;;
esac
MESSAGE="${REASON:-Needs your attention}${PANE_TITLE:+ · $PANE_TITLE}"

# Check if the user is looking at this pane. Dead `et` connections can stay
# attached to the session with stale flags, so read the client with the most
# recent activity.
CLIENT_FLAGS=$(tmux list-clients -t "$TMUX_SESSION" -F '#{client_activity} #{client_flags}' 2>/dev/null |
  sort -rn | head -1 | cut -d' ' -f2)

STASHED=$(tmux show-options -w -v -t "$TMUX_PANE" '@claude_original_name' 2>/dev/null)

if [[ "$CLIENT_FLAGS" == *"focused"* && "$PANE_ACTIVE" == "1" && "$WINDOW_ACTIVE" == "1" ]]; then
  # User is looking — clear any attention marker, then skip the notification.
  if [[ -n "$STASHED" ]]; then
    ORIG_AUTO=$(tmux show-options -w -v -t "$TMUX_PANE" '@claude_original_auto_rename' 2>/dev/null || echo "on")
    tmux rename-window -t "$TMUX_PANE" "$STASHED" 2>/dev/null
    tmux set-option -w -t "$TMUX_PANE" automatic-rename "$ORIG_AUTO" 2>/dev/null
    tmux set-option -wu -t "$TMUX_PANE" '@claude_original_name' 2>/dev/null
    tmux set-option -wu -t "$TMUX_PANE" '@claude_original_auto_rename' 2>/dev/null
    log "CLEARED marker on focus (restored '$STASHED', auto-rename=$ORIG_AUTO)"
  fi
  log "SKIPPED $EVENT - focused"
  exit 0
fi

# Not focused — set the attention marker on the tmux window title.
if [[ -z "$STASHED" ]]; then
  CURRENT_NAME=$(tmux display-message -t "$TMUX_PANE" -p '#W' 2>/dev/null)
  ORIG_AUTO=$(tmux show-options -w -v -t "$TMUX_PANE" automatic-rename 2>/dev/null || echo "on")
  tmux set-option -w -t "$TMUX_PANE" '@claude_original_name' "$CURRENT_NAME" 2>/dev/null
  tmux set-option -w -t "$TMUX_PANE" '@claude_original_auto_rename' "$ORIG_AUTO" 2>/dev/null
  tmux set-option -w -t "$TMUX_PANE" automatic-rename off 2>/dev/null
  tmux rename-window -t "$TMUX_PANE" "🤖 $CURRENT_NAME" 2>/dev/null
  log "SET marker (stashed '$CURRENT_NAME', auto-rename was $ORIG_AUTO)"
fi

JSON=$(jq -nc \
  --arg project "$(basename "$PWD")" \
  --arg branch "$(git branch --show-current 2>/dev/null)" \
  --arg message "$MESSAGE" \
  --arg hostname "$(hostname -s 2>/dev/null)" \
  --arg tmux_session "$TMUX_SESSION" \
  --arg tmux_window "$TMUX_WINDOW" \
  --arg tmux_pane "$TMUX_PANE" \
  '$ARGS.named')
B64=$(printf '%s' "$JSON" | base64 -w0)

# tmux drops passthrough from panes that are not on screen unless the pane
# allows `all`. Set it on this pane only, not server-wide.
tmux set-option -p -t "$TMUX_PANE" allow-passthrough all 2>/dev/null

if [[ -n "$PANE_TTY" && -w "$PANE_TTY" ]]; then
  # The trailing \033\\ is the escape sequence terminator, not a quoting slip.
  # shellcheck disable=SC1003
  printf '\033Ptmux;\033\033]1337;SetUserVar=%s=%s\007\033\\' \
    "claude_notify" "$B64" > "$PANE_TTY" 2>/dev/null
  log "SENT $EVENT to $TMUX_SESSION:$TMUX_WINDOW via $PANE_TTY: $JSON"
else
  log "TTY not writable: '$PANE_TTY'"
fi
