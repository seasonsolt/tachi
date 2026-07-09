#!/bin/bash
# Build Tachi.app (via build.sh) and package it into a drag-to-Applications DMG.
# The app is ad-hoc signed (no paid Developer ID), so downloaders must clear the
# quarantine flag once — see the release notes / the README below.
set -e
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
APP="Tachi.app"
VOLNAME="Tachi $VERSION"
DMG="Tachi-$VERSION.dmg"
STAGING="$(mktemp -d)/dmg"

echo "Building Tachi $VERSION..."
./build.sh >/dev/null

echo "Staging DMG contents..."
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# One-tap fix for Gatekeeper on an unsigned app.
cat > "$STAGING/READ ME — first launch.txt" <<TXT
Tachi is an open-source, ad-hoc-signed app (no paid Apple Developer ID),
so macOS quarantines it on download. To run it:

1. Drag Tachi.app onto the Applications folder in this window.
2. Open Terminal and run:
     xattr -dr com.apple.quarantine /Applications/Tachi.app
3. Launch Tachi from Applications.

(Or: right-click Tachi.app in Applications -> Open -> Open, the first time.)
TXT

echo "Creating $DMG..."
rm -f "$DMG"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$(dirname "$STAGING")"

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo ""
echo "Done: $(pwd)/$DMG"
