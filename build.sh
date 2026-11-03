#!/bin/zsh
# Собирает CursorSwap.app в ./build
set -e
cd "$(dirname "$0")"

APP=build/CursorSwap.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET"
swift Tools/make_icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -swift-version 5 -target arm64-apple-macos14 \
    -o "$APP/Contents/MacOS/CursorSwap" $(find Sources -name "*.swift" | sort)

# Встроенные наборы курсоров (.cur/.ani + Install.inf).
cp -R Packs "$APP/Contents/Resources/Packs"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>CursorSwap</string>
    <key>CFBundleIdentifier</key><string>local.cursorswap</string>
    <key>CFBundleExecutable</key><string>CursorSwap</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
    <key>NSHumanReadableCopyright</key><string>CursorSwap · cursor sets by their respective authors</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Готово: $APP"
