#!/bin/bash
# Coffee Shot installer.
#
#   curl -fsSL https://raw.githubusercontent.com/arsalaniqbal-dl/coffee-shot/main/install.sh | bash
#
# Downloads the source, builds it locally with the Xcode Command Line Tools and
# installs the app. Building locally is deliberate: apps compiled on your own
# machine are never quarantined, so there's no Gatekeeper warning to click
# through the way there would be with a downloaded binary.
set -euo pipefail

REPO="arsalaniqbal-dl/coffee-shot"
APP_NAME="Coffee Shot"

say() { printf '\033[1m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "Coffee Shot is macOS only."

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

say "Sourcing the beans…"
curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" \
	| tar xz -C "$TMP" --strip-components=1

say "Pulling the shot…"
( cd "$TMP" && ./build.sh >/dev/null )

# Replacing a running app leaves a zombie in the menu bar, so quit it first.
# CaffeinateToggle is this app's former name — clear it out so upgraders don't
# end up with two icons in the menu bar.
for PROC in CoffeeShot CaffeinateToggle; do
	if pgrep -f "MacOS/${PROC}" >/dev/null 2>&1; then
		pkill -f "MacOS/${PROC}" || true
		sleep 1
	fi
done
rm -rf "${DEST}/Caffeinate Toggle.app" "$HOME/Applications/Caffeinate Toggle.app"

say "Serving…"
rm -rf "${DEST:?}/${APP_NAME}.app"
cp -R "$TMP/build/${APP_NAME}.app" "$DEST/"
open "$DEST/${APP_NAME}.app"

printf '\n\033[1;32mOrder up.\033[0m Look for the mug in your menu bar.\n'
printf 'Click it and order a shot.\n\n'
