#!/usr/bin/env bash
# sensitive-file-guard.sh — PreToolUse hook
#
# Protects credential files, .env secrets, and cloud key vaults.
#
# Credential files (.pgpass, .ssh/id_*, .aws/credentials): HARD BLOCK
# .env files: block full reads, allow key listing & non-sensitive lookups
# Cloud vaults (az keyvault, gcloud secrets, aws secretsmanager): BLOCK
#
# Safe .env variants (.env.example, .env.sample, .env.template): ALLOWED

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Fast exit for tools that don't access files
case "$TOOL_NAME" in
  Read|Edit|Write|Bash) ;;
  *) exit 0 ;;
esac

# Sensitive key patterns — blocked when looking up .env values
SENSITIVE_KEY_RE='(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APIKEY|PRIVATE_KEY|CREDENTIAL|CONNECTION_STRING|DATABASE_URL|ENCRYPTION|CLIENT_SECRET|ACCESS_KEY|SIGNING_KEY|WEBHOOK_SECRET|JWT|SESSION_SECRET|MASTER_KEY|SENTRY_DSN|AUTH_TOKEN|BEARER)'

# Credential file substrings — any path containing these is blocked
CRED_PATTERNS=(
  '.pgpass'
  '.netrc'
  '.my.cnf'
  '.aws/credentials'
  'application_default_credentials.json'
  '.ssh/id_rsa'
  '.ssh/id_ed25519'
  '.ssh/id_ecdsa'
  '.ssh/id_dsa'
  '.gnupg/private-keys'
  '.gnupg/secring'
)

block() {
  local reason="$1"
  # Escape double quotes and backslashes for valid JSON
  reason="${reason//\\/\\\\}"
  reason="${reason//\"/\\\"}"
  printf '{"permissionDecision":"block","reason":"%s"}\n' "$reason"
  exit 0
}

# ─── Helper: is this a real .env file (not .env.example)? ───
is_sensitive_env() {
  local base
  base=$(basename "$1")
  [[ "$base" =~ ^\.env(\..*)?$ ]] || return 1
  [[ "$base" =~ \.(example|sample|template|test|defaults)$ ]] && return 1
  return 0
}

# ═══════════════════════════════════════════════════════════
# Read / Edit / Write — check the file_path
# ═══════════════════════════════════════════════════════════
if [[ "$TOOL_NAME" =~ ^(Read|Edit|Write)$ ]]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
  [[ -z "$FILE_PATH" ]] && exit 0

  # Credential files — hard block
  for pat in "${CRED_PATTERNS[@]}"; do
    [[ "$FILE_PATH" == *"$pat"* ]] && block "Blocked: credential file. Use implicitly (e.g. pgpass), never read directly."
  done

  # .env files — block Read, redirect to safe Bash patterns
  if [[ "$TOOL_NAME" == "Read" ]] && is_sensitive_env "$FILE_PATH"; then
    block "Cannot read .env directly. Use Bash instead:  List keys: grep -o '^[^#=]*' $FILE_PATH | grep .    Specific value: grep '^KEY_NAME=' $FILE_PATH"
  fi

  exit 0
fi

# ═══════════════════════════════════════════════════════════
# Bash — inspect the command
# ═══════════════════════════════════════════════════════════
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

# Credential file references in any command
for pat in "${CRED_PATTERNS[@]}"; do
  [[ "$COMMAND" == *"$pat"* ]] && block "Blocked: command references credential file ($pat)."
done

# Cloud key vault / secret manager reads
echo "$COMMAND" | grep -qP 'az\s+keyvault\s+secret\s+(show|download|backup)' \
  && block "Blocked: Azure Key Vault secret access. Use Azure Portal or run az CLI directly."
echo "$COMMAND" | grep -qP 'gcloud\s+secrets\s+versions\s+access' \
  && block "Blocked: GCP Secret Manager access."
echo "$COMMAND" | grep -qP 'aws\s+secretsmanager\s+get-secret-value' \
  && block "Blocked: AWS Secrets Manager access."
echo "$COMMAND" | grep -qP 'aws\s+ssm\s+get-parameter.*--with-decryption' \
  && block "Blocked: AWS SSM parameter with decryption."

# ─── .env file handling (nuanced) ───
# Only proceed if the command references a .env file
if echo "$COMMAND" | grep -qP '\.env(?:\.\w+)?(?=\s|"|'"'"'|$|;|\|)'; then

  # Skip safe variants (.env.example, .env.sample, etc.)
  if echo "$COMMAND" | grep -qP '\.env\.(example|sample|template|test|defaults)'; then
    exit 0
  fi

  # ALLOW: key-listing patterns (extract key names only, no values)
  #   cut -d= -f1, awk -F= '{print $1}', sed 's/=.*//', grep -o '^[^=]*'
  if echo "$COMMAND" | grep -qP '(cut\s+-d.?=.?\s+-f\s*1|awk\s+-F\s*.?=.*print\s+\$1|sed\s.*s/=\.\*//|grep\s+-o)'; then
    exit 0
  fi

  # ALLOW: specific key lookup via grep, but BLOCK if the key is sensitive
  #   Matches: grep '^KEY_NAME=' or grep "^KEY_NAME="
  KEY=""
  if echo "$COMMAND" | grep -qoP "grep\s+['\"]?\^[A-Z_]+="; then
    KEY=$(echo "$COMMAND" | grep -oP "\^([A-Z_]+)=" | head -1 | sed 's/^\^//;s/=$//')
  fi

  if [[ -n "$KEY" ]]; then
    if echo "$KEY" | grep -qiP "$SENSITIVE_KEY_RE"; then
      block "Blocked: '$KEY' matches a sensitive key pattern. Do not read secrets from .env files."
    fi
    exit 0  # Non-sensitive key lookup — allowed
  fi

  # BLOCK: commands that dump full .env contents
  #   cat, less, more, head, tail, bat, source, .
  if echo "$COMMAND" | grep -qP '(^|\s|;|&&|\|)\s*(cat|less|more|head|tail|bat|view|source|\.)\s'; then
    block "Blocked: cannot dump .env contents. Use:  grep -o '^[^#=]*' FILE to list keys, or  grep '^KEY_NAME=' FILE for a specific non-sensitive value."
  fi
fi

exit 0
