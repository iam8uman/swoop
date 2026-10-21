#!/bin/bash
# Swoop installer: downloads the latest release from GitHub and puts it in Applications.
#   curl -fsSL https://swoop-mac.vercel.app/install.sh | bash
# Source: https://github.com/iam8uman/swoop
set -euo pipefail

URL="https://github.com/iam8uman/swoop/releases/latest/download/Swoop.zip"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Swoop is a Mac app. Run this on macOS 13 or later." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Downloading the latest Swoop…"
curl -fsSL "$URL" -o "$TMP/Swoop.zip"
ditto -x -k "$TMP/Swoop.zip" "$TMP"

DEST="/Applications"
if [[ ! -w "$DEST" ]]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

# Quit a running copy before replacing it.
pkill -x Swoop 2>/dev/null || true
sleep 0.5

rm -rf "$DEST/Swoop.app"
ditto "$TMP/Swoop.app" "$DEST/Swoop.app"

# The file came straight from GitHub, so clear the "downloaded from the internet" flag.
# This is what skips the "Apple could not verify" popup.
xattr -dr com.apple.quarantine "$DEST/Swoop.app" 2>/dev/null || true

# A new build needs a fresh Accessibility entry; the old one silently stops working.
tccutil reset Accessibility com.iam8uman.swoop >/dev/null 2>&1 || true

echo "✓ Installed to $DEST/Swoop.app"
echo
echo "Last step: when macOS asks, turn Swoop on in"
echo "  System Settings → Privacy & Security → Accessibility"
echo
echo "Then hold Left ⌥ (Option) and flick your mouse. Enjoy!"

open "$DEST/Swoop.app"
