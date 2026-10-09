# Caffy

A menu bar `/usr/bin/caffeinate` .

- Filled cup = Mac is being kept awake, outline cup = normal sleep behavior.
- Presets: Indefinitely, 15 min, 30 min, 1 hr, 2 hr, 4 hr. The menu shows the time left.
- "Keep Display On" adds `-d` so the screen stays on too.
- Caffy passes `-w <its pid>` so `caffeinate` exits if Caffy quits or crashes.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen
xcodebuild -project Caffy.xcodeproj -scheme Caffy -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Caffy.app /Applications/
```

Run tests with `xcodebuild test -project Caffy.xcodeproj -scheme Caffy -destination 'platform=macOS'`.

## Staying awake with the lid closed

`caffeinate` can't stop a MacBook sleeping when its lid closes. "Stay Awake with Lid Closed" does it with `pmset -a disablesleep 1` while a session is on, and sets it back to `0` when the session ends, when Caffy quits, and on the next launch if Caffy crashed.

The first time you tick it, macOS asks for an admin password once. Caffy installs `/etc/sudoers.d/caffy`, which lets your user run only `pmset -a disablesleep 0` and `1` without a password, so a timer can end the session while you're away.

The session also ends on its own when running on battery at 10% or less. A closed laptop kept awake in a bag gets hot and drains fast.

To uninstall, choose "Remove Lid-Closed Permission…" before deleting the app, or run `sudo pmset -a disablesleep 0 && sudo rm /etc/sudoers.d/caffy`.
