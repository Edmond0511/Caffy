# Caffy

Menu bar app for `caffeinate`.

- Filled cup: Mac kept awake. Outline cup: normal sleep.
- Presets: Indefinitely, 30 min, 1 hr, 2 hr. Timed sessions count down next to the cup (`29:59`, `3:59:59`). Indefinite shows `∞`.
- "Custom…": 1 min to 24 hr, as `45`, `90m`, `2h`, `1h30` or `1:30`. Last custom value stays in the menu.
- "Keep Display On" adds `-d`.
- Caffy passes `-w <its pid>`, so `caffeinate` exits if Caffy quits or crashes.

## Install

```sh
brew install edmond0511/caffy/caffy
```

macOS 14+. Apple Silicon and Intel.

## Build

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen
xcodebuild -project Caffy.xcodeproj -scheme Caffy -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Caffy.app /Applications/
```

Tests:

```sh
xcodebuild test -project Caffy.xcodeproj -scheme Caffy -destination 'platform=macOS'
```

Some tests run real `caffeinate` and check `pmset -g assertions`, so the suite takes a few seconds.

## Lid closed

`caffeinate` can't stop sleep when a MacBook lid closes. Without this option, the session ends when the Mac sleeps.

"Stay Awake with Lid Closed" sets `pmset -a disablesleep 1` during a session. It resets to `0` when the session ends, when Caffy quits, and on next launch after a crash.

First use asks for an admin password once. Caffy installs `/etc/sudoers.d/caffy`, which lets your user run only `pmset -a disablesleep 0` and `1` without a password. This lets a timer end the session while you're away.

With the lid closed, the session also ends on battery at 10% or less, or at thermal state serious. A closed laptop kept awake in a bag gets hot and drains fast. Caffy posts a notification with the reason, and asks for notification permission on first use.

## Troubleshooting

Caffy logs why each session ended: `timerEnded`, `turnedOff`, `systemSleep`, `lowBattery`, `tooHot`, `quit`, or `caffeinateExited`.

```sh
/usr/bin/log show --last 1d --predicate 'subsystem == "com.edmondyang.caffy"'
```

## Uninstall

```sh
brew uninstall --zap caffy
```

`--zap` also removes `/etc/sudoers.d/caffy` and preferences. Plain `brew uninstall` leaves the sudoers file, because Homebrew runs uninstall steps on every upgrade.

Manual install, or remove only the permission:

```sh
sudo pmset -a disablesleep 0 && sudo rm /etc/sudoers.d/caffy
```

## Releasing

Signed with Developer ID, notarized via the Apple ID in Xcode. That Apple ID must be on team L6M742B8MJ.

```sh
scripts/release.sh 1.2.3 --dry-run   # build, test, render cask only
scripts/release.sh 1.2.3             # tag, publish GitHub release, update tap
```

Git tag is the version source of truth. `project.yml` holds a placeholder for local builds.
