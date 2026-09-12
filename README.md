# Coffee Shot

[![CI](https://github.com/m-arsalan-khatri/coffee-shot/actions/workflows/ci.yml/badge.svg)](https://github.com/m-arsalan-khatri/coffee-shot/actions/workflows/ci.yml)

**Two shots. Ten hours. No sleep.**
&nbsp;·&nbsp; [m-arsalan-khatri.github.io/coffee-shot](https://m-arsalan-khatri.github.io/coffee-shot/)

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
   Screen Stays Lit
   ─────────────────────
   Quit Coffee Shot
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/m-arsalan-khatri/coffee-shot/v1.1.0/install.sh | bash
```

That's it — the app is installed and running in your menu bar.

That URL is pinned to a release tag rather than a branch, and the script builds
the source from the same tag, so nothing in the install path follows a moving
branch. Tags here are covered by a repository ruleset that blocks updating or
deleting them, which is what lets a pinned URL keep returning the same bytes.
Rather not pipe a URL into `bash`? Clone the repo, run `./build.sh`, and move
the bundle it leaves in `build/` into `/Applications` yourself.

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
| **Screen Stays Lit** | Whether the display stays on too. Off by default. Remembered between launches. |

Outline mug = decaf. Filled mug = buzzing.

A checkmark marks the shot you're on, and ordering that same shot again cuts you
off — so the menu is its own toggle. You can switch from one shot to a double
mid-session without stopping first.

**Screen Stays Lit** is off by default, because the app is built for unattended
runs and a lit display is the largest single draw on the battery — keeping the
Mac awake doesn't require keeping the screen awake. Turn it on if you want the
screen up too. Toggling it mid-session doesn't cost you any remaining time.

## On battery

A shot ends early if the battery falls to 10% while you're unplugged, and the
header then reads **Decaf — battery ran low**. Ordering a shot below that
doesn't start one.

This is not fussiness. `caffeinate` outranks idle sleep all the way to 0%, so
without a floor a six-hour shot on battery will happily run the Mac flat and
take the unattended job it was protecting down with it — which is the exact
opposite of the point. Cutting off at 10% lets the Mac sleep normally instead
of dying.

## How it works

Coffee Shot spawns `/usr/bin/caffeinate` with:

| Flag | Assertion | Effect |
|---|---|---|
| `-i` | `PreventUserIdleSystemSleep` | The Mac won't idle-sleep |
| `-m` | `PreventDiskIdle` | Disks stay spun up |
| `-d` | `PreventUserIdleDisplaySleep` | Display stays on (optional, off by default) |
| `-w <pid>` | — | Child exits when the app exits |

Three deliberate choices:

**`-w <our pid>`** means the power assertion is torn down by macOS even if the
app crashes or is force-killed. There's no way to end up with an orphaned
`caffeinate` silently keeping the machine awake forever.

**Expiry is owned by the app's timer, not `caffeinate -t`.** This keeps the
countdown in the menu and the real assertion from ever drifting apart.

**The battery can end a shot too.** Time is not the only way a session should
end on a laptop — see [On battery](#on-battery).

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
git clone https://github.com/m-arsalan-khatri/coffee-shot.git
cd coffee-shot
./build.sh
open "build/Coffee Shot.app"
```

Produces a universal (arm64 + x86_64) ad-hoc signed bundle. The whole app is a
single Swift file — [`Sources/main.swift`](Sources/main.swift), about 430 lines
of AppKit, built in Swift 6 language mode so the compiler proves the timer and
process-exit callbacks hop to the main actor correctly.

`./test.sh` verifies the result: shell lint, a warnings-as-errors compile, and
bundle checks (signed, universal, `Info.plist` consistent with what's on disk).

## Contributing

Issues and pull requests welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). It's a
small app on purpose, so the bar for new features is "does this still fit on one
menu".

## License

MIT — see [LICENSE](LICENSE).
