#!/bin/bash
# share-screenshot.sh - Upload clipboard image to a remote server
# Used by wrapper scripts in private/ - not called directly from Raycast

set -euo pipefail

# Require hostname argument
if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <remote-host>" >&2
  exit 1
fi

# Configuration
REMOTE_HOST="$1"
REMOTE_DIR="${SCREENSHOT_REMOTE_DIR:-screenshots}"
PNGPASTE="${PNGPASTE_PATH:-/opt/homebrew/bin/pngpaste}"

# Validate REMOTE_DIR contains only safe characters (prevent command injection)
if [[ ! "$REMOTE_DIR" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "Error: REMOTE_DIR contains unsafe characters" >&2
  exit 1
fi

# Helper functions
escape_applescript() {
  # Escape backslashes and quotes for AppleScript strings
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  printf '%s' "$str"
}

notify() {
  local title
  local message
  title=$(escape_applescript "$1")
  message=$(escape_applescript "$2")
  osascript -e "display notification \"$message\" with title \"$title\""
}

notify_error() {
  local message
  message=$(escape_applescript "$1")
  osascript -e "display notification \"$message\" with title \"Screenshot Share\" sound name \"Basso\""
}

die() {
  notify_error "$1"
  echo "Error: $1" >&2
  exit 1
}

cleanup() {
  if [[ -n "${TMPFILE:-}" && -f "$TMPFILE" ]]; then
    rm -f "$TMPFILE" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Check dependencies
[[ -x "$PNGPASTE" ]] || die "pngpaste not found at $PNGPASTE"
command -v scp >/dev/null || die "scp not found"
command -v pbcopy >/dev/null || die "pbcopy not found"

# Create temp file
TMPFILE=$(mktemp -t clipboard-screenshot.XXXXXX.png)

# Grab image from clipboard
if ! "$PNGPASTE" "$TMPFILE" 2>/dev/null; then
  die "No image in clipboard"
fi

# Verify we got a valid image
if [[ ! -s "$TMPFILE" ]]; then
  die "Clipboard image is empty"
fi

# Check SSH connectivity (with timeout)
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "true" 2>/dev/null; then
  die "Cannot connect to $REMOTE_HOST"
fi

# Get remote home directory (avoid tilde expansion issues)
REMOTE_HOME=$(ssh -o ConnectTimeout=5 "$REMOTE_HOST" 'printf %s "$HOME"') || die "Failed to get remote home"

# Ensure remote directory exists (using properly escaped path)
REMOTE_FULL_DIR="$REMOTE_HOME/$REMOTE_DIR"
ssh "$REMOTE_HOST" "mkdir -p '$REMOTE_FULL_DIR'" || die "Failed to create remote directory"

# Generate unique filename
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FILENAME="screenshot-$TIMESTAMP.png"
REMOTE_PATH="$REMOTE_FULL_DIR/$FILENAME"

# Upload to remote
if ! scp -q "$TMPFILE" "$REMOTE_HOST:$REMOTE_PATH"; then
  die "Failed to upload screenshot"
fi

# Copy path to clipboard (use ~/ for display, it's more readable)
DISPLAY_PATH="~/$REMOTE_DIR/$FILENAME"
if ! printf '%s' "$DISPLAY_PATH" | pbcopy; then
  die "Failed to copy path to clipboard"
fi

# Success notification
notify "Screenshot Shared" "$DISPLAY_PATH"

echo "Uploaded: $DISPLAY_PATH"
