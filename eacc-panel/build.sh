#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building EACCMonitor..."
swift build -c release 2>&1

EXEC=".build/release/EACCMonitor"
APP_DIR="EACCMonitor.app/Contents/MacOS"

mkdir -p "$APP_DIR"
cp "$EXEC" "$APP_DIR/"
cp Info.plist "EACCMonitor.app/Contents/"

echo ""
echo "Build complete: EACCMonitor.app"
echo "Run with: open EACCMonitor.app"
