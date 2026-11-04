#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "==> Сборка релиза (ARM64 Apple Silicon)..."
swift build -c release

echo "==> Упаковка в YandexMusic.app..."
mkdir -p build/YandexMusic.app/Contents/MacOS build/YandexMusic.app/Contents/Resources
cp .build/release/YandexMusicMac build/YandexMusic.app/Contents/MacOS/YandexMusicMac
codesign --force --deep --sign - build/YandexMusic.app 2>/dev/null || true

echo "==> Запуск приложения..."
open build/YandexMusic.app
echo "Приложение успешно запущено!"
