# Contributing

Thanks for taking a look. This is a deliberately small app — one Swift file, no
dependencies, no build system beyond a shell script. Please keep it that way.

## Getting set up

You need the Xcode Command Line Tools (`xcode-select --install`). Nothing else.

```bash
git clone https://github.com/arsalaniqbal-dl/caffeinate-toggle.git
cd caffeinate-toggle
./build.sh
open "build/Caffeinate Toggle.app"
```

Rebuilding while a copy is running leaves a stale icon in the menu bar, so quit
the old one first (`pkill -f MacOS/CaffeinateToggle`).

## Testing a change

There are no automated tests — the app is almost entirely UI and power
assertions. Check by hand:

1. Start a session from the menu; confirm the mug fills in and the countdown
   ticks while the menu is open.
2. Confirm the assertion is real:
   ```bash
   pmset -g assertions | grep caffeinate
   ```
   You should see `PreventUserIdleSystemSleep` and `PreventDiskIdle`, plus
   `PreventUserIdleDisplaySleep` when "Keep Display Awake" is checked.
3. Turn it off and confirm the assertion disappears from `pmset`.
4. Force-quit the app while a session is active
   (`pkill -9 -f MacOS/CaffeinateToggle`) and confirm no `caffeinate` process
   survives — this is what `-w <pid>` guarantees, and it's the most important
   property to not break.

## Scope

The point of this app is that it does one thing and stays out of the way. Good
contributions:

- Bug fixes, especially anything that could strand a power assertion.
- Accessibility and VoiceOver improvements.
- Making the existing behaviour clearer or simpler.

Things likely to be declined:

- Preference windows, onboarding, or anything with a UI beyond the dropdown.
- Third-party dependencies or a package manager.
- Features that don't fit in the one dropdown.

If you're planning something substantial, open an issue first so you don't spend
time on a change that doesn't fit.

## Style

Match what's there: standard Swift conventions, tabs as they appear in the shell
scripts, and comments reserved for explaining *why* something is done a
particular way rather than restating the code.
