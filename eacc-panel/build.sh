#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Building Tachi..."
BUILD_ARGS=(-c release)
TACHI_BUILD_TRIPLE="${TACHI_BUILD_TRIPLE:-}"
if [ -n "$TACHI_BUILD_TRIPLE" ]; then
    BUILD_ARGS+=(--triple "$TACHI_BUILD_TRIPLE")
fi
swift build "${BUILD_ARGS[@]}" 2>&1

BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
EXEC="$BIN_DIR/Tachi"
APP_BUNDLE="Tachi.app"
APP_DIR="$APP_BUNDLE/Contents/MacOS"
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"
INSTALL_APP="/Applications/$APP_BUNDLE"
LEGACY_APP_BUNDLES=("Monolith.app")
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
TACHI_INSTALL_APP="${TACHI_INSTALL_APP:-1}"

test -x "$EXEC"

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

# Bind Info.plist and resources to the bundle signature. Release builds pass a
# Developer ID Application identity; local builds remain ad-hoc signed.
if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP_BUNDLE"
else
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
fi
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [ "$TACHI_INSTALL_APP" = "1" ]; then
    echo "Installing to $INSTALL_APP..."
    rm -rf "$INSTALL_APP"
    for legacy_bundle in "${LEGACY_APP_BUNDLES[@]}"; do
        rm -rf "/Applications/$legacy_bundle"
    done
    ditto --noextattr --noqtn "$APP_BUNDLE" "$INSTALL_APP"
fi

echo ""
echo "Build complete: $APP_BUNDLE"
if [ "$TACHI_INSTALL_APP" = "1" ]; then
    echo "Installed to: $INSTALL_APP"
    echo "Run with: open \"$INSTALL_APP\""
fi
