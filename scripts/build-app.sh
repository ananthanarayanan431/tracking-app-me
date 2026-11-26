#!/bin/bash
# Builds Spent.app from the Swift package and (optionally) installs it.
# Usage: scripts/build-app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Spent"

APP="build/Spent.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Spent"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# App icon: rendered from code, converted to .icns
if [ -x "$(command -v iconutil)" ]; then
  ICONSET="build/AppIcon.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  swift scripts/make-icon.swift "$ICONSET" >/dev/null
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
fi

# Sign with the local "Spent Local Signing" certificate when it exists: macOS then ties
# permissions (Full Disk Access, Automation, Notifications) to the certificate, so they survive
# rebuilds. Without it, fall back to ad-hoc signing (permissions reset on every rebuild).
# Create the certificate once with: scripts/make-signing-cert.sh
IDENTITY=$(security find-identity 2>/dev/null | awk -F'"' '/"Spent Local Signing"/ {print $0; exit}' | awk '{print $2}')
if [ -n "$IDENTITY" ]; then
  codesign --force --deep --sign "$IDENTITY" --identifier com.spent.app "$APP"
  echo "Signed with Spent Local Signing"
else
  codesign --force --deep --sign - --identifier com.spent.app "$APP"
  echo "Signed ad-hoc (run scripts/make-signing-cert.sh to keep permissions across rebuilds)"
fi
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
  pkill -x Spent 2>/dev/null || true
  rm -rf "$DEST/Spent.app"
  cp -R "$APP" "$DEST/"
  echo "Installed to $DEST/Spent.app"
  open "$DEST/Spent.app"
fi
