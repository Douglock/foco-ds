#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
MACOS_DIR="$ROOT_DIR/macos"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/Foco DS.app"

echo "Compilando Foco DS (Release)..."
cd "$MACOS_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/FocoDS"

echo "Montando pacote Foco DS.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/FocoDS"
chmod +x "$APP_BUNDLE/Contents/MacOS/FocoDS"

cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FocoDS</string>
    <key>CFBundleIdentifier</key>
    <string>com.douglock.foco-ds</string>
    <key>CFBundleName</key>
    <string>Foco DS</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cd "$RELEASE_DIR"
zip -r "Foco-DS-macOS.zip" "Foco DS.app"

echo "Foco DS compilado e empacotado com sucesso em: $APP_BUNDLE e Foco-DS-macOS.zip"
