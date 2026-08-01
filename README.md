# Caffeinate Toggle

A menu-bar-only macOS app that keeps your Mac awake for a fixed stretch — built
for long unattended agent runs, builds and test suites that idle sleep would
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

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/arsalaniqbal-dl/caffeinate-toggle/main/install.sh | bash
```

That's it — the app is installed and running in your menu bar.

The installer builds from source on your machine rather than downloading a
binary. That's deliberate: locally built apps are never quarantined, so there's
no Gatekeeper warning to click through. It needs the Xcode Command Line Tools
(`xcode-select --install`) and nothing else — no Xcode, no package manager, no
dependencies.

Piping a script to `bash` deserves a read first —
[here it is](install.sh).

**Uninstall:** quit from the menu, then `rm -rf "/Applications/Caffeinate Toggle.app"`.

## Usage

- Outline mug = sleep allowed. Filled mug = keeping the Mac awake.
- The header counts down live while the menu is open.
- Clicking the preset that's already running turns it off, so the menu doubles
  as the on/off toggle. `Turn Off` appears only while active.
- `Keep Display Awake` is remembered between launches. Toggling it mid-session
  respawns the assertion without losing the time remaining.

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

Verify what's actually holding your Mac awake at any time:

```bash
pmset -g assertions
```

### Known limitation

`caffeinate` prevents *idle* sleep, not *lid-close* sleep. Closing the lid on a
laptop still sleeps it, Apple Silicon especially. Leave the lid open or run
clamshell with an external display. Also note `-s` (used by some other tools)
only takes effect on AC power — this app uses `-i`, which works on battery too.

## Building it yourself

```bash
git clone https://github.com/arsalaniqbal-dl/caffeinate-toggle.git
cd caffeinate-toggle
./build.sh
open "build/Caffeinate Toggle.app"
```

Produces a universal (arm64 + x86_64) ad-hoc signed bundle. The whole app is a
single Swift file — [`Sources/main.swift`](Sources/main.swift), about 200 lines
of AppKit.

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
It's a small app on purpose, so the bar for new features is "does this still fit
in one dropdown".

## License

MIT — see [LICENSE](LICENSE).
