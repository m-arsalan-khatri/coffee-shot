#!/bin/bash
# Caffeinate Toggle installer.
#
#   curl -fsSL https://raw.githubusercontent.com/arsalaniqbal-dl/caffeinate-toggle/main/install.sh | bash
#
# Downloads the source, builds it locally with the Xcode Command Line Tools and
# installs the app. Building locally is deliberate: apps compiled on your own
# machine are never quarantined, so there's no Gatekeeper warning to click
# through the way there would be with a downloaded binary.
set -euo pipefail

REPO="arsalaniqbal-dl/caffeinate-toggle"
APP_NAME="Caffeinate Toggle"

say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "Caffeinate Toggle is macOS only."

if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
	say "The Xcode Command Line Tools are required but not installed."
	say "Starting the installer — rerun this command once it finishes."
	xcode-select --install >/dev/null 2>&1 || true
	exit 1
fi

# Install somewhere writable without needing sudo.
if [ -w /Applications ]; then
	DEST="/Applications"
else
	DEST="$HOME/Applications"
	mkdir -p "$DEST"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say "Downloading source…"
curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" \
	| tar xz -C "$TMP" --strip-components=1

say "Building…"
( cd "$TMP" && ./build.sh >/dev/null )

# Replacing a running app leaves a zombie in the menu bar, so quit it first.
if pgrep -f 'MacOS/CaffeinateToggle' >/dev/null 2>&1; then
	say "Quitting the running copy…"
	pkill -f 'MacOS/CaffeinateToggle' || true
	sleep 1
fi

say "Installing to ${DEST}…"
rm -rf "${DEST:?}/${APP_NAME}.app"
cp -R "$TMP/build/${APP_NAME}.app" "$DEST/"

say "Launching…"
open "$DEST/${APP_NAME}.app"

printf '\n\033[1;32mDone.\033[0m Look for the mug icon in your menu bar.\n'
printf 'Click it and pick "Keep Awake for 6 Hours" to start.\n\n'
