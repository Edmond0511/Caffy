# Caffy

A menu bar app for `caffeinate`.

- Filled cup = Mac is being kept awake, outline cup = normal sleep behavior.
- Presets: Indefinitely, 30 min, 1 hr, 2 hr. Next to the cup, timed sessions count down (`29:59`, or `3:59:59` from an hour up) and indefinite ones show `∞`.
- "Custom…" takes any length from 1 min to 24 hr: `45`, `90m`, `2h`, `1h30` or `1:30`. The last one stays in the menu.
- "Keep Display On" adds `-d` so the screen stays on too.
- Caffy passes `-w <its pid>` so `caffeinate` exits if Caffy quits or crashes.

## Install

```sh
brew install --cask edmond0511/caffy/caffy
```

Requires macOS 14 or later. Runs on Apple Silicon and Intel.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen
xcodebuild -project Caffy.xcodeproj -scheme Caffy -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Caffy.app /Applications/
```

Run tests with `xcodebuild test -project Caffy.xcodeproj -scheme Caffy -destination 'platform=macOS'`. A few of them run real `caffeinate` and check `pmset -g assertions`, so the suite takes a few seconds.

## Staying awake with the lid closed

`caffeinate` can't stop a MacBook sleeping when its lid closes, so without this option Caffy ends the session when the Mac goes to sleep. "Stay Awake with Lid Closed" does it with `pmset -a disablesleep 1` while a session is on, and sets it back to `0` when the session ends, when Caffy quits, and on the next launch if Caffy crashed.

The first time you tick it, macOS asks for an admin password once. Caffy installs `/etc/sudoers.d/caffy`, which lets your user run only `pmset -a disablesleep 0` and `1` without a password, so a timer can end the session while you're away.

While the lid is closed, the session also ends on its own when running on battery at 10% or less, or when macOS reports the Mac's thermal state as serious (hot enough that it's already slowing itself down). A closed laptop kept awake in a bag gets hot and drains fast. When either happens, Caffy posts a notification saying why; it asks for notification permission the first time you tick the option.

## Troubleshooting

If a session ends when you didn't expect it to, Caffy logs why (`timerEnded`, `turnedOff`, `systemSleep`, `lowBattery`, `tooHot`, `quit`, or `caffeinateExited` when `caffeinate` quit early):

```sh
/usr/bin/log show --last 1d --predicate 'subsystem == "com.edmondyang.caffy"'
```

## Uninstall

```sh
brew uninstall --zap caffy
```

`--zap` also removes the lid-closed permission and Caffy's preferences. A plain `brew uninstall` leaves `/etc/sudoers.d/caffy` in place, since Homebrew runs uninstall steps on every upgrade too.

If you installed by hand, or want to remove the permission without uninstalling, run `sudo pmset -a disablesleep 0 && sudo rm /etc/sudoers.d/caffy`.

## Releasing

Releases are signed with a Developer ID and notarized through the Apple ID signed in to Xcode, which must be on team L6M742B8MJ.

```sh
scripts/release.sh 1.2.3 --dry-run   # build, test and render the cask only
scripts/release.sh 1.2.3             # tag, publish the GitHub release, update the tap
```

The tag is the version source of truth; `project.yml` keeps a placeholder for local builds.
