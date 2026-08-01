#!/bin/bash
# Verifies a built bundle is actually shippable. Run by CI on every push, and
# worth running before opening a PR.
#
# These are static checks only: a menu bar app needs a logged-in GUI session to
# run, which CI doesn't have. The manual checks in CONTRIBUTING.md cover
# behaviour.
# No -e: a failing check should be reported and counted, not abort the run.
set -uo pipefail

# Which means cd needs its own guard — without one, a failure here would run
# every check against the wrong directory and cheerfully pass.
cd "$(dirname "$0")" || exit 1

APP_NAME="Coffee Shot"
BUNDLE="build/${APP_NAME}.app"
BIN="CoffeeShot"

PASS=0
FAIL=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "Shell scripts"
for script in build.sh install.sh test.sh; do
	check "$script parses" "bash -n '$script'"
done
if command -v shellcheck >/dev/null 2>&1; then
	for script in build.sh install.sh test.sh; do
		check "$script passes shellcheck" "shellcheck -S warning '$script'"
	done
else
	printf '  \033[33m–\033[0m shellcheck not installed, skipping lint\n'
fi

echo
echo "Compiler"
check "compiles with no warnings under Swift 6" \
	"swiftc -swift-version 6 -warnings-as-errors -target arm64-apple-macos13.0 -framework AppKit -o /dev/null Sources/main.swift"

echo
echo "Bundle"
if [ ! -d "$BUNDLE" ]; then
	bad "$BUNDLE missing — run ./build.sh first"
else
	ok "bundle exists"
	check "binary is present and executable" "[ -x '$BUNDLE/Contents/MacOS/$BIN' ]"
	check "binary is universal (arm64 + x86_64)" \
		"lipo -archs '$BUNDLE/Contents/MacOS/$BIN' | grep -q arm64 && lipo -archs '$BUNDLE/Contents/MacOS/$BIN' | grep -q x86_64"
	check "code signature is valid" "codesign --verify --strict '$BUNDLE'"

	PLIST="$BUNDLE/Contents/Info.plist"
	check "Info.plist is well formed" "plutil -lint '$PLIST'"
	# A mismatch here builds cleanly and then fails to launch, so it is worth
	# asserting rather than eyeballing.
	check "CFBundleExecutable matches the binary on disk" \
		"[ \"\$(plutil -extract CFBundleExecutable raw '$PLIST')\" = '$BIN' ]"
	check "LSUIElement is set (no Dock icon)" \
		"[ \"\$(plutil -extract LSUIElement raw '$PLIST')\" = 'true' ]"
	check "CFBundleIdentifier is set" \
		"[ -n \"\$(plutil -extract CFBundleIdentifier raw '$PLIST')\" ]"
fi

echo
if [ "$FAIL" -gt 0 ]; then
	printf '\033[31m%d failed\033[0m, %d passed\n' "$FAIL" "$PASS"
	exit 1
fi
printf '\033[32mAll %d checks passed.\033[0m\n' "$PASS"
