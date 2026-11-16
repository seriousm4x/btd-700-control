#!/bin/sh
set -eu

cd "$(dirname "$0")"
APP="build/BTD 700 Control.app"
ICON_TMP="$(mktemp -d "${TMPDIR:-/tmp}/btd700-icons.XXXXXX")"
trap 'rm -rf -- "$ICON_TMP"' EXIT
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
swift tools/GenerateIcons.swift assets/BTD700.svg assets/MenuBarIcon.svg \
    "$ICON_TMP/AppIcon.iconset" "$APP/Contents/Resources"
iconutil --convert icns --output "$APP/Contents/Resources/AppIcon.icns" \
    "$ICON_TMP/AppIcon.iconset"
swiftc -O -target arm64-apple-macos13.0 \
    -framework AppKit -framework IOKit \
    Sources/Models.swift Sources/ModePolicy.swift Sources/BTDHID.swift \
    Sources/DongleMonitor.swift Sources/NativeModeItem.swift Sources/AppMain.swift \
    -o "$APP/Contents/MacOS/BTD700Control"
codesign --force --sign - "$APP"
echo "Built $PWD/$APP"
