#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building Monolith..."
swift build -c release 2>&1

EXEC=".build/release/EACCMonitor"
APP_BUNDLE="Monolith.app"
APP_DIR="$APP_BUNDLE/Contents/MacOS"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"
INSTALL_APP="/Applications/$APP_BUNDLE"
LEGACY_APP_BUNDLE="EACCMonitor.app"
LEGACY_INSTALL_APP="/Applications/$LEGACY_APP_BUNDLE"

rm -rf "$APP_BUNDLE" "$LEGACY_APP_BUNDLE"
mkdir -p "$APP_DIR"
mkdir -p "$APP_RESOURCES"
cp -X "$EXEC" "$APP_DIR/"
cp -X Info.plist "$APP_BUNDLE/Contents/"
cp -X Resources/AppIcon.icns "$APP_RESOURCES/"

# Re-sign so Info.plist is bound to the bundle identity
codesign --force --sign - --deep "$APP_BUNDLE"

echo "Installing to $INSTALL_APP..."
rm -rf "$INSTALL_APP"
rm -rf "$LEGACY_INSTALL_APP"
ditto --noextattr --noqtn "$APP_BUNDLE" "$INSTALL_APP"

echo ""
echo "Build complete: $APP_BUNDLE"
echo "Installed to: $INSTALL_APP"
echo "Run with: open \"$INSTALL_APP\""
