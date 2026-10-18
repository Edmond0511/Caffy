#!/usr/bin/env bash
# Usage: scripts/release.sh <version> [--dry-run]
# Builds a universal Caffy.app, notarizes it, publishes it as a GitHub release, and
# updates the Homebrew tap. --dry-run stops after building the zip and rendering the cask.
# Signing and notarization use the Apple ID signed in to Xcode (team L6M742B8MJ).
set -euo pipefail

VERSION=${1:?usage: scripts/release.sh <version> [--dry-run]}
DRY_RUN=${2:-}
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3" >&2; exit 1; }

cd "$(dirname "$0")/.."
TAP_REPO=Edmond0511/homebrew-caffy
OUT=build/release
ARCHIVE=build/Caffy.xcarchive
APP=$OUT/notarized/Caffy.app
ZIP=$OUT/Caffy-$VERSION.zip

if [[ $DRY_RUN != --dry-run ]]; then
  [[ -z $(git status --porcelain) ]] || { echo "working tree not clean" >&2; exit 1; }
  [[ $(git branch --show-current) == master ]] || { echo "not on master" >&2; exit 1; }
  git fetch -q origin
  [[ $(git rev-parse HEAD) == $(git rev-parse origin/master) ]] || { echo "master not in sync with origin" >&2; exit 1; }
  ! git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null || { echo "tag v$VERSION exists" >&2; exit 1; }
fi

xcodegen -q
xcodebuild test -project Caffy.xcodeproj -scheme Caffy -destination 'platform=macOS' -quiet
rm -rf "$ARCHIVE" "$OUT" && mkdir -p "$OUT"
xcodebuild archive -project Caffy.xcodeproj -scheme Caffy -configuration Release -archivePath "$ARCHIVE" -quiet \
  -allowProvisioningUpdates ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  DEVELOPMENT_TEAM=L6M742B8MJ CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" ENABLE_HARDENED_RUNTIME=YES \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)"

# Re-signs with the cloud-managed Developer ID cert and submits to Apple's notary service.
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist packaging/ExportOptions.plist \
  -exportPath "$OUT/upload" -allowProvisioningUpdates
echo "Waiting for notarization..."
while ! log=$(xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$OUT/notarized" 2>&1); do
  grep -q "not ready" <<<"$log" || { echo "$log" >&2; exit 1; }
  sleep 30
done
[[ -d $APP ]] || { echo "notarized app missing" >&2; exit 1; }
spctl -a -t exec -vv "$APP"

[[ $(lipo -archs "$APP/Contents/MacOS/Caffy") == "x86_64 arm64" ]] || { echo "not a universal build" >&2; exit 1; }
ditto -c -k --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA256__/$SHA/" packaging/caffy.rb > "$OUT/caffy.rb"

echo "Built $ZIP ($SHA)"
[[ $DRY_RUN == --dry-run ]] && { echo "Dry run: cask at $OUT/caffy.rb, nothing published."; exit 0; }

git tag -a "v$VERSION" -m "Caffy $VERSION"
git push -q origin "v$VERSION"
gh release create "v$VERSION" "$ZIP" --title "Caffy $VERSION" --generate-notes

TAP=$(mktemp -d)
trap 'rm -rf "$TAP"' EXIT
gh repo clone "$TAP_REPO" "$TAP" -- -q
mkdir -p "$TAP/Casks" && cp "$OUT/caffy.rb" "$TAP/Casks/caffy.rb"
git -C "$TAP" add Casks/caffy.rb
git -C "$TAP" commit -q -m "caffy $VERSION"
git -C "$TAP" push -q
echo "Released Caffy $VERSION: brew install edmond0511/caffy/caffy"
