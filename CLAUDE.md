# Coffee Shot

Menu-bar-only macOS app that keeps the Mac awake for a fixed stretch — 6 or 10
hours — aimed at long unattended agent runs, builds and test suites that idle
sleep would otherwise kill mid-flight.

## Commands

```bash
./build.sh     # universal, ad-hoc signed bundle -> build/Coffee Shot.app
./test.sh      # what CI runs: shell lint, Swift 6 warnings-as-errors, bundle checks
./install.sh   # build from source and install to /Applications
```

## Layout

```
Sources/main.swift   the entire app (~230 lines of AppKit)
Info.plist           LSUIElement — no Dock icon, no window
build.sh test.sh install.sh
.github/workflows/ci.yml
```

No Xcode project, no package manager, no dependencies. Command Line Tools only
(version 16+, since the app builds in Swift 6 language mode).

## Invariants — don't break these

These each have a reason that isn't obvious from the code alone.

1. **`caffeinate` is always spawned with `-w <our pid>`.** macOS then releases
   the power assertion even if the app is `SIGKILL`ed, which makes an orphaned
   process silently keeping the Mac awake impossible. Verified by test, and the
   single most important property here.

2. **Expiry is owned by the app's timer, not `caffeinate -t`** — so the
   countdown shown in the menu and the real assertion cannot drift apart.

3. **The expiry timer fires once, scheduled against a wall-clock `Date`.** Do
   not reintroduce a one-second repeating timer: it woke the CPU ~36,000 times
   per double shot to redraw an unchanged icon, which is indefensible in an app
   about power management. Scheduling by date also means sleeping through a
   deadline still ends the session on the next wake. The one-second tick exists
   only while the menu is open (`menuWillOpen` / `menuDidClose`).

4. **Swift 6 language mode.** The class is `@MainActor`; timer and process-exit
   callbacks hop via `Task { @MainActor in }`. Building in Swift 5 mode fails —
   top-level code is only MainActor-isolated under Swift 6.

5. **`codesign` after `lipo` must succeed.** `lipo` strips the per-slice
   signatures `swiftc` applies, and macOS refuses to run an unsigned binary on
   Apple Silicon. A silent failure here ships a bundle that simply won't launch,
   which is why it is fatal rather than `|| true`.

## Distribution

Install is `curl … install.sh | bash`, which **builds on the user's machine**.
That is deliberate: locally built apps are never quarantined, so there is no
Gatekeeper warning and no paid Apple Developer account needed. Do not replace
this with a prebuilt binary in a Release without first solving notarization.

`raw.githubusercontent.com` caches for a few minutes, so the one-liner can serve
a stale `install.sh` immediately after a push.

## Testing

`test.sh` is static only — a menu bar app needs a logged-in GUI session, which
CI does not have.

To verify behaviour, build an instrumented copy of `Sources/main.swift`:
compress the presets from hours to seconds and auto-order a shot on launch, then
watch `pmset -g assertions`. Worth confirming: the assertion is taken with the
right flags, released at expiry, leaves no orphan after `kill -9` on the app,
and that the app survives its `caffeinate` being killed out from under it.

## Conventions

- **Barista voice in user-facing strings** — Decaf, One Shot, Double Shot, Cut
  Me Off, Buzzing. Code comments stay plain and technical; nobody should have to
  decode a pun while debugging a power assertion.
- Comments explain *why*, not *what*.
- **Scope is the feature.** One thing, one menu. No preferences window, no
  dependencies, nothing that doesn't fit on the existing dropdown.

## Known limitation

`caffeinate` prevents *idle* sleep, not *lid-close* sleep. Closing the lid still
sleeps the Mac, Apple Silicon especially. This is a macOS constraint, not a bug
to fix.
