#!/usr/bin/env bash
set -euo pipefail
umask 022

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Steam Link Keyboard Helper"
APP="$ROOT/build/${APP_NAME}.app"
EXEC="$ROOT/.build/arm64-apple-macosx/release/MacSteamLinkKeyboardHelper"

cd "$ROOT"
MACOSX_DEPLOYMENT_TARGET=26.0 swift build -c release --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$EXEC" "$APP/Contents/MacOS/MacSteamLinkKeyboardHelper"
chmod 755 "$APP/Contents/MacOS/MacSteamLinkKeyboardHelper"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacSteamLinkKeyboardHelper</string>
    <key>CFBundleIdentifier</key>
    <string>tw.ipa.MacSteamLinkKeyboardHelper</string>
    <key>CFBundleName</key>
    <string>Steam Link Keyboard Helper</string>
    <key>CFBundleDisplayName</key>
    <string>Steam Link Keyboard Helper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

find "$APP" -type d -exec chmod 755 {} +
find "$APP" -type f -exec chmod 644 {} +
chmod 755 "$APP/Contents/MacOS/MacSteamLinkKeyboardHelper"

codesign --force --deep --sign - "$APP"

find "$APP" -type d -exec chmod 755 {} +
find "$APP" -type f -exec chmod 644 {} +
chmod 755 "$APP/Contents/MacOS/MacSteamLinkKeyboardHelper"

echo "$APP"
