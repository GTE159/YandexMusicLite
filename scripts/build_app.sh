#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "Сборка релизной версии YandexMusicMac..."
swift build -c release --product YandexMusicMac

APP_NAME="YandexMusicMac.app"
CONTENTS="$APP_NAME/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Создание структуры бандла .app..."
rm -rf "$APP_NAME"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

echo "Копирование бинарника..."
cp .build/release/YandexMusicMac "$MACOS/YandexMusicMac"

echo "Создание Info.plist..."
cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>YandexMusicMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.yandexmusic.mac.client</string>
    <key>CFBundleName</key>
    <string>YandexMusicMac</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Copy AppIcon if present in Resources
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES/"
fi

echo "Локальная подпись приложения..."
codesign --force --deep --sign - "$APP_NAME"

echo "Готово! Приложение собрано: $APP_NAME"
