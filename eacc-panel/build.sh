#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building Tachi..."
swift build -c release 2>&1

EXEC=".build/release/Tachi"
APP_BUNDLE="Tachi.app"
APP_DIR="$APP_BUNDLE/Contents/MacOS"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"
INSTALL_APP="/Applications/$APP_BUNDLE"
LEGACY_APP_BUNDLES=("Monolith.app")

rm -rf "$APP_BUNDLE"
for legacy_bundle in "${LEGACY_APP_BUNDLES[@]}"; do
    rm -rf "$legacy_bundle"
done
mkdir -p "$APP_DIR"
mkdir -p "$APP_RESOURCES"
cp -X "$EXEC" "$APP_DIR/"
cp -X Info.plist "$APP_BUNDLE/Contents/"
cp -X Resources/AppIcon.icns "$APP_RESOURCES/"
if [ -d Resources/Fonts ]; then
    mkdir -p "$APP_RESOURCES/Fonts"
    cp -X Resources/Fonts/* "$APP_RESOURCES/Fonts/"
fi

# Re-sign so Info.plist is bound to the bundle identity
codesign --force --sign - --deep "$APP_BUNDLE"

echo "Installing to $INSTALL_APP..."
rm -rf "$INSTALL_APP"
for legacy_bundle in "${LEGACY_APP_BUNDLES[@]}"; do
    rm -rf "/Applications/$legacy_bundle"
done
ditto --noextattr --noqtn "$APP_BUNDLE" "$INSTALL_APP"

echo ""
echo "Build complete: $APP_BUNDLE"
echo "Installed to: $INSTALL_APP"
echo "Run with: open \"$INSTALL_APP\""
