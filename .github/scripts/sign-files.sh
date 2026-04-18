#!/usr/bin/env bash
# sign-files.sh – Sign a single file with GPG and verify the signature.
#
# Usage:
#   sign-files.sh <file>
#
# Environment variables:
#   GPG_PASSPHRASE  – passphrase for the GPG key (required in CI)
#   GPG_KEY_ID      – (optional) key fingerprint / email to use for signing;
#                     defaults to the first available secret key

set -euo pipefail

FILE="$1"

if [ -z "$FILE" ]; then
  echo "Usage: $0 <file>" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE" >&2
  exit 1
fi

# Check .gpg-ignore patterns
IGNORE_FILE="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")/.gpg-ignore"
if [ -f "$IGNORE_FILE" ]; then
  while IFS= read -r pattern; do
    # Skip blank lines and comments
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    # shellcheck disable=SC2254
    case "$FILE" in
      $pattern)
        echo "Skipping ignored file: $FILE"
        exit 0
        ;;
    esac
  done < "$IGNORE_FILE"
fi

SIG_FILE="${FILE}.gpg.sig"

# Build the gpg signing command
GPG_ARGS=(
  --batch
  --yes
  --armor
  --detach-sign
  --output "$SIG_FILE"
)

if [ -n "${GPG_KEY_ID:-}" ]; then
  GPG_ARGS+=(--local-user "$GPG_KEY_ID")
fi

if [ -n "${GPG_PASSPHRASE:-}" ]; then
  GPG_ARGS+=(
    --pinentry-mode loopback
    --passphrase-fd 0
  )
  echo "$GPG_PASSPHRASE" | gpg "${GPG_ARGS[@]}" "$FILE"
else
  gpg "${GPG_ARGS[@]}" "$FILE"
fi

echo "Signed: $FILE -> $SIG_FILE"

# Verify the detached signature immediately after creation
gpg --batch --verify "$SIG_FILE" "$FILE"
echo "Verified: $SIG_FILE"
