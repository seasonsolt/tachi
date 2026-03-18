#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building EACCSMonitor..."
swift build -c release 2>&1

EXEC=".build/release/EACCSMonitor"
APP_DIR="EACCSMonitor.app/Contents/MacOS"

mkdir -p "$APP_DIR"
cp "$EXEC" "$APP_DIR/"
cp Info.plist "EACCSMonitor.app/Contents/"

echo ""
echo "Build complete: EACCSMonitor.app"
echo "Run with: open EACCSMonitor.app"
