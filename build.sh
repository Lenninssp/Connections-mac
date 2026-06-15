#!/bin/zsh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Load API key
if [[ -f .env ]]; then
  export $(grep -v '^#' .env | xargs)
fi

echo "Building..."
swift build -c release

APP="$SCRIPT_DIR/Connections.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp .build/release/Connections "$MACOS/Connections"
cp Sources/Connections/Resources/Info.plist "$CONTENTS/Info.plist"

# Generate app icon
echo "Generating icon..."
swift make_icon.swift
iconutil -c icns Connections.iconset -o "$RESOURCES/AppIcon.icns"
rm -rf Connections.iconset

echo "Built: $APP"
echo "Launching..."
open "$APP"
