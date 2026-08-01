# Caffeinate Toggle

A menu-bar-only macOS app that keeps your Mac awake for a fixed stretch — built
for long unattended agent runs, builds and test suites that idle-sleep would
otherwise kill mid-flight.

No window, no preferences pane, no Dock icon. Just a mug in the menu bar and a
dropdown.

```
☕ Awake — 5:42:17 left
   ─────────────────────
 ✓ Keep Awake for 6 Hours
   Keep Awake for 10 Hours
   Turn Off
   ─────────────────────
 ✓ Keep Display Awake
   ─────────────────────
   Quit Caffeinate Toggle
```

- Outline mug = sleep allowed. Filled mug = keeping the Mac awake.
- The header counts down live while the menu is open.
- Clicking the preset that's already running turns it off, so the menu doubles
  as the on/off toggle. `Turn Off` appears only while active.
- `Keep Display Awake` is remembered between launches. Toggling it mid-session
  respawns the assertion without losing the time remaining.

## Build and run

Requires only the Xcode Command Line Tools — no Xcode project, no dependencies.

```bash
./build.sh
open "build/Caffeinate Toggle.app"
```

Produces a universal (arm64 + x86_64) ad-hoc signed bundle. Drag it to
`/Applications` to keep it around.

## How it works

The app spawns `/usr/bin/caffeinate` with:

| Flag | Assertion | Effect |
|---|---|---|
| `-i` | `PreventUserIdleSystemSleep` | The Mac won't idle-sleep |
| `-m` | `PreventDiskIdle` | Disks stay spun up |
| `-d` | `PreventUserIdleDisplaySleep` | Display stays on (optional) |
| `-w <pid>` | — | Child exits when the app exits |

Two deliberate choices:

**`-w <our pid>`** means the power assertion is torn down by macOS even if the
app crashes or is force-killed. There's no way to end up with an orphaned
`caffeinate` silently keeping the machine awake forever.

**Expiry is owned by the app's timer, not `caffeinate -t`.** This keeps the
countdown in the menu and the real assertion from ever drifting apart.

Verify what's actually holding the system awake at any time:

```bash
pmset -g assertions
```

### Known limitation

`caffeinate` prevents *idle* sleep, not *lid-close* sleep. Closing the lid on a
laptop still sleeps it, Apple Silicon especially. Leave the lid open or run
clamshell with an external display. Also note `-s` (used by some other tools)
only takes effect on AC power — this app uses `-i`, which works on battery too.

## Sharing it with someone

`./share.sh` packages the app into `build/Caffeinate Toggle.zip`.

The app is **ad-hoc signed, not notarized**, so the recipient hits Gatekeeper on
first launch. Three options, cheapest first:

1. **Send them the zip.** They open it, get blocked, then go to
   *System Settings → Privacy & Security* and click **Open Anyway**. On macOS 15
   and later, the old Control-click → Open shortcut no longer works — it has to
   go through System Settings. Alternatively:
   `xattr -dr com.apple.quarantine "/Applications/Caffeinate Toggle.app"`

2. **Send them this folder instead** and have them run `./build.sh`. Locally
   built apps aren't quarantined, so it just works — best option if they're
   comfortable in a terminal.

3. **Notarize it properly** if you want a clean double-click for anyone. Needs a
   paid Apple Developer account ($99/yr) and a Developer ID Application
   certificate:

   ```bash
   codesign --force --options runtime --timestamp \
     --sign "Developer ID Application: Your Name (TEAMID)" \
     "build/Caffeinate Toggle.app"
   ditto -c -k --keepParent "build/Caffeinate Toggle.app" upload.zip
   xcrun notarytool submit upload.zip --apple-id you@example.com \
     --team-id TEAMID --password "app-specific-password" --wait
   xcrun stapler staple "build/Caffeinate Toggle.app"
   ```
