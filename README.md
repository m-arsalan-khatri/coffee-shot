# Coffee Shot

**Two shots. Ten hours. No sleep.**

A menu-bar-only macOS app that keeps your Mac awake for a fixed stretch — built
for long unattended agent runs, builds and test suites that idle sleep would
otherwise kill mid-flight.

No window, no preferences pane, no Dock icon. Just a mug in the menu bar. Order
a shot, get back to work.

```
☕ Buzzing — 5:42:17 left
   ─────────────────────
 ✓ One Shot · 6 hours
   Double Shot · 10 hours
   Cut Me Off
   ─────────────────────
 ✓ Screen Stays Lit
   ─────────────────────
   Quit Coffee Shot
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/arsalaniqbal-dl/coffee-shot/main/install.sh | bash
```

That's it — the app is installed and running in your menu bar.

The installer builds from source on your machine rather than downloading a
binary. That's deliberate: locally built apps are never quarantined, so there's
no Gatekeeper warning to click through. It needs the Xcode Command Line Tools
(`xcode-select --install`) and nothing else — no Xcode, no package manager, no
dependencies.

Piping a script to `bash` deserves a read first — [here it is](install.sh).

**Uninstall:** quit from the menu, then `rm -rf "/Applications/Coffee Shot.app"`.

## The menu

| Item | What it does |
|---|---|
| **Decaf** / **Buzzing — 5:42:17 left** | Status header, not a button. Counts down live while the menu is open. |
| **One Shot · 6 hours** | Keeps the Mac awake for six hours. |
| **Double Shot · 10 hours** | Same, for ten. |
| **Cut Me Off** | Ends the session early. Only appears while a shot is running. |
| **Screen Stays Lit** | Whether the display stays on too. Remembered between launches. |

Outline mug = decaf. Filled mug = buzzing.

A checkmark marks the shot you're on, and ordering that same shot again cuts you
off — so the menu is its own toggle. You can switch from one shot to a double
mid-session without stopping first.

Uncheck **Screen Stays Lit** for overnight runs: the Mac keeps working, the
display goes dark. Toggling it mid-session doesn't cost you any remaining time.

## How it works

Coffee Shot spawns `/usr/bin/caffeinate` with:

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

Check what's actually keeping your Mac up at any time:

```bash
pmset -g assertions
```

### Known limitation

`caffeinate` prevents *idle* sleep, not *lid-close* sleep. Closing the lid on a
laptop still sleeps it, Apple Silicon especially — no amount of espresso fixes
that. Leave the lid open or run clamshell with an external display. Also note
`-s` (used by some other tools) only takes effect on AC power; Coffee Shot uses
`-i`, which works on battery too.

## Pulling your own

```bash
git clone https://github.com/arsalaniqbal-dl/coffee-shot.git
cd coffee-shot
./build.sh
open "build/Coffee Shot.app"
```

Produces a universal (arm64 + x86_64) ad-hoc signed bundle. The whole app is a
single Swift file — [`Sources/main.swift`](Sources/main.swift), about 200 lines
of AppKit.

## Contributing

Issues and pull requests welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). It's a
small app on purpose, so the bar for new features is "does this still fit on one
menu".

## License

MIT — see [LICENSE](LICENSE).
