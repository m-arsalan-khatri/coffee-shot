#!/bin/bash
# Coffee Shot installer.
#
#   curl -fsSL https://raw.githubusercontent.com/m-arsalan-khatri/coffee-shot/v1.0.2/install.sh | bash
#
# Downloads the source, builds it locally with the Xcode Command Line Tools and
# installs the app. Building locally is deliberate: apps compiled on your own
# machine are never quarantined, so there's no Gatekeeper warning to click
# through the way there would be with a downloaded binary.
set -euo pipefail

REPO="m-arsalan-khatri/coffee-shot"
APP_NAME="Coffee Shot"

# Pinned to an immutable release tag, never to a branch.
#
# The published one-liner fetches *this script* from the same tag, so the
# installer and the source it builds come from one reviewed point in history.
# If either followed main, then anyone who gained push access, for however few
# minutes, would run code as you on every machine that installed in that
# window: `curl | bash` hands them a shell, and a locally built app is never
# quarantined, so Gatekeeper never gets a look either.
#
# A tag can still be force-moved by whoever holds the account, so tags in this
# repository are covered by a ruleset forbidding updates and deletion. That is
# what makes a pinned URL keep returning the same bytes.
#
# Releasing means: bump this, update the one-liner in README.md and
# docs/index.html, commit, then tag.
VERSION="v1.0.2"

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
# refs/tags, not refs/heads. No checksum is pinned beside it on purpose:
# GitHub builds these tarballs on demand and has changed their byte output
# before, silently breaking every hardcoded hash that relied on them. The
# integrity guarantee here is the protected tag, not a digest.
if ! curl -fsSL "https://github.com/${REPO}/archive/refs/tags/${VERSION}.tar.gz" \
	| tar xz -C "$TMP" --strip-components=1; then
	die "Could not download ${VERSION}. See https://github.com/${REPO}/releases"
fi

say "Pulling the shot…"
# Quiet on success, but keep the log: a build failure here is the most likely
# way this script fails, and "it didn't work" with no output is useless.
if ! ( cd "$TMP" && ./build.sh ) >"$TMP/build.log" 2>&1; then
	cat "$TMP/build.log" >&2
	die "Build failed — the output above should say why."
fi

# Nothing below this point is reversible, so confirm the build actually produced
# something before going near an existing install.
[ -d "$TMP/build/${APP_NAME}.app" ] || die "Build finished but produced no app bundle."

# Replacing a running app leaves a zombie in the menu bar, so quit it first.
# "Caffeinate Toggle" is this app's former name — clear it out too, so upgraders
# don't end up with two mugs. Patterns are full bundle paths rather than bare
# binary names: pkill -f matches whole command lines, and a bare name would also
# match, say, an editor that happens to have the file open.
for APP in "${APP_NAME}.app/Contents/MacOS/CoffeeShot" \
           "Caffeinate Toggle.app/Contents/MacOS/CaffeinateToggle"; do
	if pgrep -f "$APP" >/dev/null 2>&1; then
		pkill -f "$APP" || true
		sleep 1
	fi
done

for DIR in "${DEST:?}" "${HOME:?}/Applications"; do
	rm -rf "${DIR}/Caffeinate Toggle.app"
done

say "Serving…"
rm -rf "${DEST:?}/${APP_NAME}.app"
cp -R "$TMP/build/${APP_NAME}.app" "$DEST/"
open "$DEST/${APP_NAME}.app"

printf '\n\033[1;32mOrder up.\033[0m Look for the mug in your menu bar.\n'
printf 'Click it and order a shot.\n\n'
