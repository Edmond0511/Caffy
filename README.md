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

## Limitation: closing the lid

A MacBook still sleeps when its lid closes, unless it is on power with an external display attached. `caffeinate` cannot prevent that.
