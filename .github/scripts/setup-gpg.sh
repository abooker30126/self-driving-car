#!/usr/bin/env bash
# setup-gpg.sh – Configure the local GPG environment for code signing.
#
# Run this script once on your local machine before committing signed files.
# It will:
#   1. Verify that gpg is installed.
#   2. List your existing secret keys so you can choose one.
#   3. Export the chosen public key so you can upload it to GitHub Secrets.
#   4. Optionally configure git to sign commits automatically.
#
# Usage:
#   chmod +x .github/scripts/setup-gpg.sh
#   .github/scripts/setup-gpg.sh

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

# ── 1. Check prerequisites ────────────────────────────────────────────────────

if ! command -v gpg &>/dev/null; then
  error "gpg is not installed. Install it with your OS package manager:
  macOS:  brew install gnupg
  Debian: sudo apt-get install -y gnupg
  Fedora: sudo dnf install -y gnupg2"
fi

GPG_VERSION=$(gpg --version | head -1)
info "Using: $GPG_VERSION"

# ── 2. List available secret keys ────────────────────────────────────────────

info "Your secret GPG keys:"
gpg --list-secret-keys --keyid-format=long || warn "No secret keys found."

echo ""
read -rp "Enter the key ID or email address to use for signing (or press Enter to generate a new key): " KEY_ID

# ── 3. Generate a new key if needed ──────────────────────────────────────────

if [ -z "$KEY_ID" ]; then
  info "Generating a new RSA 4096-bit key..."
  gpg --full-generate-key
  KEY_ID=$(gpg --list-secret-keys --keyid-format=long | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
  info "New key ID: $KEY_ID"
fi

# ── 4. Export the private key for use in GitHub Secrets ──────────────────────

PRIVATE_KEY_FILE="/tmp/gpg-private-key.asc"
info "Exporting private key to $PRIVATE_KEY_FILE ..."
gpg --armor --export-secret-keys "$KEY_ID" > "$PRIVATE_KEY_FILE"
info "Private key exported. Upload the contents of $PRIVATE_KEY_FILE as the"
info "GPG_PRIVATE_KEY secret in your GitHub repository settings."
info ""
info "  GitHub > Settings > Secrets and variables > Actions > New repository secret"
info "  Name:  GPG_PRIVATE_KEY"
info "  Value: <paste contents of $PRIVATE_KEY_FILE>"
echo ""

# ── 5. Export the public key for verification ─────────────────────────────────

PUBLIC_KEY_FILE="/tmp/gpg-public-key.asc"
gpg --armor --export "$KEY_ID" > "$PUBLIC_KEY_FILE"
info "Public key exported to $PUBLIC_KEY_FILE"
info "You can share this file so others can verify your signatures."
echo ""

# ── 6. Configure git to sign commits ─────────────────────────────────────────

read -rp "Configure git to sign all commits with this key? [y/N] " SIGN_COMMITS
if [[ "$SIGN_COMMITS" =~ ^[Yy]$ ]]; then
  git config --global user.signingkey "$KEY_ID"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  info "git configured to sign commits and tags with key $KEY_ID"
fi

# ── 7. Reminder about GPG_PASSPHRASE ─────────────────────────────────────────

echo ""
info "Remember to also add your key passphrase as the GPG_PASSPHRASE secret"
info "in GitHub so the CI workflow can sign files non-interactively."
info ""
info "Setup complete."
