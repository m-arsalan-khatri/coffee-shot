# Contributing

Thanks for taking a look. Coffee Shot is a deliberately small app — one Swift
file, no dependencies, no build system beyond a shell script. Please keep it
that way.

## Getting set up

You need the Xcode Command Line Tools (`xcode-select --install`), version 16 or
newer — the app builds in Swift 6 language mode. Nothing else.

```bash
git clone https://github.com/arsalaniqbal-dl/coffee-shot.git
cd coffee-shot
./build.sh
open "build/Coffee Shot.app"
```

Rebuilding while a copy is running leaves a stale mug in the menu bar, so quit
the old one first (`pkill -f MacOS/CoffeeShot`).

## Before opening a PR

```bash
./build.sh && ./test.sh
```

`test.sh` is what CI runs: it lints the shell scripts, compiles with warnings as
errors under Swift 6, and verifies the built bundle is signed, universal and
internally consistent. Install `shellcheck` (`brew install shellcheck`) to get
the lint locally — it's skipped if absent.

## Testing behaviour by hand

`test.sh` is static only: a menu bar app needs a logged-in GUI session, which CI
doesn't have. So behaviour is checked by hand:

1. Order a shot from the menu; confirm the mug fills in and the countdown ticks
   while the menu is open.
2. Confirm the assertion is real:
   ```bash
   pmset -g assertions | grep caffeinate
   ```
   You should see `PreventUserIdleSystemSleep` and `PreventDiskIdle`, plus
   `PreventUserIdleDisplaySleep` when "Screen Stays Lit" is checked.
3. Cut yourself off and confirm the assertion disappears from `pmset`.
4. Force-quit the app mid-shot (`pkill -9 -f MacOS/CoffeeShot`) and confirm no
   `caffeinate` process survives — this is what `-w <pid>` guarantees, and it's
   the most important property to not break.

## Scope

The point of Coffee Shot is that it does one thing and stays out of the way.
Good contributions:

- Bug fixes, especially anything that could strand a power assertion.
- Accessibility and VoiceOver improvements.
- Making the existing behaviour clearer or simpler.

Things likely to be declined:

- Preference windows, onboarding, or anything with a UI beyond the menu.
- Third-party dependencies or a package manager.
- Features that don't fit on the one menu.

If you're planning something substantial, open an issue first so you don't spend
time on a change that doesn't fit.

## Style

Match what's there: standard Swift conventions, tabs as they appear in the shell
scripts, and comments reserved for explaining *why* something is done a
particular way rather than restating the code. Keep the barista voice in
user-facing strings; keep code comments plain and technical.
