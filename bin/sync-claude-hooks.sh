#!/usr/bin/env bash
# Idempotently merge this dotfiles' personal Claude Code hooks into
# ~/.claude/settings.json.
#
# Claude Code loads hooks ONLY from settings.json (there is no hooks.d/ or
# include mechanism), and that file is also written to by Claude Code itself
# and by other tools (e.g. orca) — so we can't just symlink it. Instead this
# script syncs OUR hook entries into it and leaves everyone else's alone.
#
# Source of truth: .claude/hooks.json (beside the dotfiles root). "Ours" =
# any entry whose command references one of our scripts (see $re). Each run
# strips our old entries and re-adds the current set, so re-running converges
# with no duplicates. dotbot runs this on install; run it by hand after editing
# .claude/hooks.json.
set -euo pipefail

self="$(readlink -f "$0")"
dotfiles="$(cd "$(dirname "$self")/.." && pwd)"
frag="${CLAUDE_HOOKS_FRAGMENT:-$dotfiles/.claude/hooks.json}"
settings="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# Entries whose command mentions one of these scripts are ours to replace.
re='tmux-agent-state\.sh|claude-clear-attention\.sh|claude-notification-hook\.sh|sensitive-file-guard\.sh'

command -v jq >/dev/null 2>&1 || { echo "sync-claude-hooks: jq is required" >&2; exit 1; }
[ -f "$frag" ] || { echo "sync-claude-hooks: fragment not found: $frag" >&2; exit 1; }

mkdir -p "$(dirname "$settings")"
[ -s "$settings" ] || echo '{}' >"$settings"

tmp="$(mktemp "${settings}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

# For each event in the fragment: keep the entries that aren't ours, then
# append ours. Events (and tool-managed entries) not in the fragment are
# left exactly as they were.
jq --slurpfile frag "$frag" --arg re "$re" '
  ($frag[0]) as $F
  | .hooks = (.hooks // {})
  | reduce ($F | keys_unsorted[]) as $e (.;
      .hooks[$e] =
        (((.hooks[$e] // [])
           | map(select(((.hooks // []) | map(.command // "" | test($re)) | any) | not)))
         + $F[$e]))
' "$settings" >"$tmp"

jq -e . "$tmp" >/dev/null   # validate before replacing
mv "$tmp" "$settings"
trap - EXIT

echo "sync-claude-hooks: synced $(jq '[.[][]] | length' "$frag") personal hook entries into $settings"
