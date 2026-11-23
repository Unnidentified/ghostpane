#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/template.swift"

if [ ! -f "$TEMPLATE" ]; then
    echo "Error: template.swift not found in $SCRIPT_DIR"
    exit 1
fi

echo "========================================="
echo "  App Identity & Process Configurator"
echo "========================================="
echo ""

# 1. .app bundle name
read -p "1. .app Bundle Name (without .app) [default: SystemNotes]: " APP_NAME
APP_NAME="${APP_NAME:-SystemNotes}"
APP_NAME="${APP_NAME%.app}"

# 2. Internal binary / process name
DEFAULT_BIN=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
read -p "2. Internal Binary / Process Name (ps / Activity Monitor) [default: $DEFAULT_BIN]: " BIN_NAME
BIN_NAME="${BIN_NAME:-$DEFAULT_BIN}"

# 3. Activity Monitor display name
read -p "3. Activity Monitor Display Name (CFBundleName) [default: $APP_NAME]: " ACTIVITY_NAME
ACTIVITY_NAME="${ACTIVITY_NAME:-$APP_NAME}"

# 4. Bundle Identifier
DEFAULT_BUNDLE_ID="com.local.${DEFAULT_BIN}"
read -p "4. Bundle Identifier (CFBundleIdentifier) [default: $DEFAULT_BUNDLE_ID]: " BUNDLE_ID
BUNDLE_ID="${BUNDLE_ID:-$DEFAULT_BUNDLE_ID}"

# 5. Window header title
read -p "5. Window Header Text [default: coreaudio]: " HEADER_TITLE
HEADER_TITLE="${HEADER_TITLE:-coreaudio}"

# 6. Menubar tooltip
read -p "6. Menubar // Tooltip [default: $ACTIVITY_NAME]: " TOOLTIP
TOOLTIP="${TOOLTIP:-$ACTIVITY_NAME}"

echo ""
echo "Building:"
echo "  Bundle:     $APP_NAME.app"
echo "  Binary:     $APP_NAME.app/Contents/MacOS/$BIN_NAME"
echo "  Activity:   $ACTIVITY_NAME"
echo "  Bundle ID:  $BUNDLE_ID"
echo "  Header:     $HEADER_TITLE"
echo ""

APP_DIR="$SCRIPT_DIR/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
PLIST_PATH="$APP_DIR/Contents/Info.plist"
TMP_SWIFT="$(mktemp /tmp/app_build_XXXXXX.swift)"

# Escape double quotes for Swift string literals
SAFE_HEADER=$(printf '%s' "$HEADER_TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
SAFE_TOOLTIP=$(printf '%s' "$TOOLTIP" | sed 's/\\/\\\\/g; s/"/\\"/g')

sed -e "s|__HEADER_TITLE__|${SAFE_HEADER}|g" \
    -e "s|__TOOLTIP__|${SAFE_TOOLTIP}|g" \
    "$TEMPLATE" > "$TMP_SWIFT"

# Remove previous build of the same name if present
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

echo "Compiling..."
swiftc -O "$TMP_SWIFT" -o "$MACOS_DIR/$BIN_NAME"
rm -f "$TMP_SWIFT"
chmod +x "$MACOS_DIR/$BIN_NAME"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${BIN_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${ACTIVITY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${ACTIVITY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing bundle (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo ""
echo "Done! Created: $APP_DIR"
echo "Run with:"
echo "  open \"$APP_DIR\""
echo "Or directly:"
echo "  \"$MACOS_DIR/$BIN_NAME\" &"
