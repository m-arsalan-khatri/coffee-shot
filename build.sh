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

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Swift 6 language mode: the app touches AppKit from timer and process-exit
# callbacks, and this makes the compiler prove those hops are correct rather
# than trusting that they are. Needs Swift 6.0+ (Xcode 16 tools or newer).
#
# Both architectures are built and lipo'd together so the same bundle runs on
# Apple Silicon and Intel.
for ARCH in arm64 x86_64; do
	swiftc \
		-O \
		-swift-version 6 \
		-target "${ARCH}-apple-macos13.0" \
		-framework AppKit \
		-o "$TMP/$BIN-$ARCH" \
		Sources/main.swift
done

lipo -create -output "$BUNDLE/Contents/MacOS/$BIN" "$TMP/$BIN-arm64" "$TMP/$BIN-x86_64"

cp Info.plist "$BUNDLE/Contents/Info.plist"

# lipo strips the per-slice signatures swiftc applied, and macOS refuses to run
# an unsigned binary on Apple Silicon. This has to succeed — a silent failure
# here produces a bundle that simply will not launch.
codesign --force --sign - "$BUNDLE"
codesign --verify --strict "$BUNDLE"

echo "Built $BUNDLE"
