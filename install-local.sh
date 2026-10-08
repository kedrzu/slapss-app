#!/usr/bin/env bash
# Builds this checkout and installs it as a separate app next to the App Store copy.
#
# A different bundle ID keeps it out of the App Store build's sandbox container,
# calendar permission and updates, so both can be installed and switched between.
# Microsoft 365 sign-in is tied to com.cancetin.slapss and won't work in this build.
#
#   ./install-local.sh            build, install, restart
#   ./install-local.sh --status   show what is installed and running
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE_ID="${BUNDLE_ID:-com.kedrzu.slapss}"
DEST="/Applications/slapss (local).app"
IDENTITY="${IDENTITY:-Apple Development}"
DERIVED="build/DerivedData"

if [[ "${1:-}" == "--status" ]]; then
    for app in /Applications/slapss.app "$DEST"; do
        [[ -d "$app" ]] || continue
        printf '%s  %s  %s\n' "$app" \
            "$(defaults read "$app/Contents/Info.plist" CFBundleIdentifier)" \
            "$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString)"
    done
    pgrep -lf 'MacOS/slapss$' || echo "slapss is not running"
    exit 0
fi

# The project needs full Xcode; xcode-select often points at the Command Line Tools.
if ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

xcodebuild build -quiet \
    -project slapss.xcodeproj -scheme slapss -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" CODE_SIGNING_ALLOWED=NO

BUILT="$DERIVED/Build/Products/Release/slapss.app"

# A stable signing identity keeps the calendar permission across rebuilds;
# ad-hoc signatures change every build and macOS would ask again each time.
codesign --force --options runtime --timestamp=none \
    --entitlements slapss/slapss.entitlements --sign "$IDENTITY" "$BUILT"
codesign --verify --strict "$BUILT"

pkill -x slapss 2>/dev/null && sleep 1 || true
rm -rf "$DEST"
ditto "$BUILT" "$DEST"
open "$DEST"

echo "Installed $DEST ($BUNDLE_ID), running."
