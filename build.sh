#!/bin/bash
# Pulls a fresh shot: builds "Coffee Shot.app" into ./build. Requires only the
# Xcode Command Line Tools — no Xcode project, no dependencies.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Coffee Shot"
BUNDLE="build/${APP_NAME}.app"
BIN="CoffeeShot"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

# Build both architectures and lipo them together, so the same .app runs on
# Apple Silicon and Intel Macs when shared.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for ARCH in arm64 x86_64; do
	swiftc \
		-O \
		-target "${ARCH}-apple-macos13.0" \
		-framework AppKit \
		-o "$TMP/$BIN-$ARCH" \
		Sources/main.swift
done

lipo -create -output "$BUNDLE/Contents/MacOS/$BIN" "$TMP/$BIN-arm64" "$TMP/$BIN-x86_64"

cp Info.plist "$BUNDLE/Contents/Info.plist"

# Ad-hoc signature: gives the app a stable identity so macOS remembers its
# permissions and doesn't re-prompt on every rebuild.
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "Built $BUNDLE"
