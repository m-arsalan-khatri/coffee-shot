#!/bin/bash
# Packages the built app into a zip suitable for sending to someone else.
# Uses `ditto` rather than `zip` because it preserves bundle structure,
# resource forks and the code signature intact.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Caffeinate Toggle"
BUNDLE="build/${APP_NAME}.app"
ZIP="build/${APP_NAME}.zip"

[ -d "$BUNDLE" ] || { echo "No build found — run ./build.sh first."; exit 1; }

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$ZIP"

echo "Created $ZIP"
echo
echo "The recipient will be blocked by Gatekeeper the first time, because this"
echo "app is ad-hoc signed rather than notarized by Apple. Tell them to either:"
echo
echo "  1. Open it, dismiss the warning, then go to"
echo "     System Settings > Privacy & Security > 'Open Anyway'."
echo "     (On macOS 15+ the old Control-click > Open shortcut no longer works.)"
echo
echo "  2. Or run, after moving it to /Applications:"
echo "     xattr -dr com.apple.quarantine \"/Applications/${APP_NAME}.app\""
