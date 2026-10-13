#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="build/macos"
APP="$OUT/Event Horizon.app"
BINARY="event_horizon"
INSTALL=0
if [ "${1:-}" = "--install" ]; then
    INSTALL=1
    shift
fi
VARIANTS=("$@")
if [ ${#VARIANTS[@]} -eq 0 ]; then
    VARIANTS=()
    for size in 1920x1200 3072x1920 3840x2400; do
        for rate in 30 60; do VARIANTS+=("media/Gargantua-$size-${rate}fps.mp4"); done
    done
fi

for file in "${VARIANTS[@]}"; do
    [ -f "$file" ] || { echo "Missing $file — make it with: make variants"; exit 1; }
done

echo "Compiling core and app"
mkdir -p "$OUT"
STRICT="-std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -Wshadow -Wstrict-prototypes -Wmissing-prototypes -Wcast-qual -Wundef -Wvla -Wformat=2 -Wconversion -Wunused-macros -Wnull-dereference -Wdouble-promotion"
clang $STRICT -target arm64-apple-macos15.0 -c core/wallpaper.c -o "$OUT/wallpaper.o"
clang $STRICT -target arm64-apple-macos15.0 -c core/mpv.c -o "$OUT/mpv.o"
swiftc -O -whole-module-optimization -warnings-as-errors -target arm64-apple-macos15.0 \
    -import-objc-header core/mpv.h macos/main.swift "$OUT/wallpaper.o" "$OUT/mpv.o" -o "$OUT/$BINARY"
rm -f "$OUT/wallpaper.o" "$OUT/mpv.o"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$OUT/$BINARY" "$APP/Contents/MacOS/$BINARY"
chmod +x "$APP/Contents/MacOS/$BINARY"

for file in "${VARIANTS[@]}"; do
    cp "$file" "$APP/Contents/Resources/"
    echo "  + ${file#media/}"
done

if [ -f macos/MenuIcon.png ]; then
    cp macos/MenuIcon.png "$APP/Contents/Resources/"
    echo "  + MenuIcon.png"
fi

if [ -f media/icon.png ]; then
    ICONSET="$OUT/icon.iconset"
    rm -rf "$ICONSET"
    mkdir "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z $size $size media/icon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
        sips -z $((size * 2)) $((size * 2)) media/icon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/event_horizon.icns"
    rm -rf "$ICONSET"
    echo "  + event_horizon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key><string>Event Horizon</string>
	<key>CFBundleExecutable</key><string>event_horizon</string>
	<key>CFBundleIdentifier</key><string>local.eventhorizon.wallpaper</string>
	<key>CFBundleName</key><string>Event Horizon</string>
	<key>CFBundleIconFile</key><string>event_horizon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>2.0</string>
	<key>CFBundleVersion</key><string>2</string>
	<key>LSMinimumSystemVersion</key><string>15.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || echo "Warning: signing failed"
echo "Built: $APP ($(du -sh "$APP" | cut -f1))"

if [ "$INSTALL" = "1" ]; then
    rm -rf "/Applications/Event Horizon.app"
    cp -R "$APP" /Applications/
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "/Applications/Event Horizon.app" >/dev/null 2>&1 || true
    echo "Installed: /Applications/Event Horizon.app"
fi
