#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building EACCMonitor..."
swift build -c release 2>&1

EXEC=".build/release/EACCMonitor"
APP_BUNDLE="EACCMonitor.app"
APP_DIR="$APP_BUNDLE/Contents/MacOS"
INSTALL_APP="/Applications/$APP_BUNDLE"

mkdir -p "$APP_DIR"
cp "$EXEC" "$APP_DIR/"
cp Info.plist "$APP_BUNDLE/Contents/"

# Re-sign so Info.plist is bound to the bundle identity
codesign --force --sign - --deep "$APP_BUNDLE"

echo "Installing to $INSTALL_APP..."
rm -rf "$INSTALL_APP"
ditto "$APP_BUNDLE" "$INSTALL_APP"

echo ""
echo "Build complete: $APP_BUNDLE"
echo "Installed to: $INSTALL_APP"
echo "Run with: open \"$INSTALL_APP\""
