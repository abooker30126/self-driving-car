# Security Keys & GPG Signing

This document explains how GPG signatures are used in this repository, how to
set up your local environment, how to verify signatures, and how to configure
the required GitHub Secrets.

---

## Table of Contents

1. [Overview](#overview)
2. [Setting Up GPG Locally](#setting-up-gpg-locally)
3. [Configuring GitHub Secrets](#configuring-github-secrets)
4. [How the Workflow Signs Files](#how-the-workflow-signs-files)
5. [Verifying Signatures](#verifying-signatures)
6. [Troubleshooting](#troubleshooting)

---

## Overview

Every pull request that modifies a `.sh`, `.py`, `.yml`, or `.tf` file
automatically triggers the **GPG Sign Modified Files** workflow
(`.github/workflows/gpg-sign-files.yml`).

The workflow:
- Detects which files were changed in the PR.
- Creates a detached ASCII-armored GPG signature (`<file>.gpg.sig`) for each
  modified file.
- Commits the `.gpg.sig` files back to the PR branch.
- Posts a signature report as a PR comment.

---

## Setting Up GPG Locally

Run the helper script once on your machine:

```bash
chmod +x .github/scripts/setup-gpg.sh
.github/scripts/setup-gpg.sh
```

The script will:
1. Verify that `gpg` is installed (and guide you to install it if not).
2. List your existing secret keys.
3. Help you generate a new RSA 4096-bit key if you don't have one.
4. Export your private key to `/tmp/gpg-private-key.asc` so you can upload it
   to GitHub Secrets.
5. Export your public key to `/tmp/gpg-public-key.asc` for distribution.
6. Optionally configure `git` to sign all commits automatically.

### Manual key generation

```bash
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, expiry as desired
```

### View existing keys

```bash
gpg --list-secret-keys --keyid-format=long
```

---

## Configuring GitHub Secrets

Two secrets must be added to your repository before the workflow can sign files:

| Secret name       | Value |
| ----------------- | ----- |
| `GPG_PRIVATE_KEY` | ASCII-armored private key (`gpg --armor --export-secret-keys <KEY_ID>`) |
| `GPG_PASSPHRASE`  | The passphrase protecting your private key |

### Steps

1. Navigate to your repository on GitHub.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret** and add each secret listed above.

---

## How the Workflow Signs Files

1. The workflow imports `GPG_PRIVATE_KEY` into a temporary GPG keyring.
2. It determines the set of modified files using
   `git diff --name-only <base>..<head>`, filtered for `.sh`, `.py`, `.yml`,
   and `.tf` extensions.
3. For each file, `.github/scripts/sign-files.sh` is called, which:
   - Checks `.gpg-ignore` for exclusion patterns.
   - Creates a detached, ASCII-armored signature with
     `gpg --armor --detach-sign`.
   - Immediately verifies the new signature with `gpg --verify`.
4. All new `*.gpg.sig` files are committed back to the PR branch.

### Skipping files

Add file path patterns to `.gpg-ignore` (one pattern per line, supports shell
globbing) to prevent specific files from being signed:

```
# Example .gpg-ignore
*.generated.sh
vendor/**
```

---

## Verifying Signatures

Anyone with the signer's public key can verify a signature.

### Import the signer's public key

```bash
gpg --import gpg-public-key.asc
```

Or fetch it from a key server if available:

```bash
gpg --recv-keys <KEY_ID>
```

### Verify a single file

```bash
gpg --verify path/to/file.sh.gpg.sig path/to/file.sh
```

A successful verification looks like:

```
gpg: Signature made ...
gpg: Good signature from "Anthony Booker <...>"
```

### Verify all signatures in the repository

```bash
find . -name '*.gpg.sig' | while read sig; do
  original="${sig%.gpg.sig}"
  echo "Verifying: $original"
  gpg --verify "$sig" "$original"
done
```

---

## Troubleshooting

| Problem | Solution |
| ------- | -------- |
| `gpg: no secret key` in CI | Ensure `GPG_PRIVATE_KEY` secret is set and contains the full ASCII-armored key |
| `Bad passphrase` in CI | Verify `GPG_PASSPHRASE` matches the passphrase on the imported key |
| Signature verification fails after file edit | Re-sign the file; any change invalidates the existing signature |
| Key expired | Generate a new key (or extend expiry) and update GitHub Secrets |
