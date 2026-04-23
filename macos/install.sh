#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Quill"
APP_BUNDLE="${APP_NAME}.app"
DEST="$HOME/Applications"

echo "=== Quill Installer ==="
echo ""

# 1. Check Swift
if ! command -v swift &>/dev/null; then
    echo "❌ Swift not found."
    echo "   Install Xcode Command Line Tools by running:"
    echo "   xcode-select --install"
    exit 1
fi

echo "✓ Swift found: $(swift --version 2>&1 | head -1)"

# 2. Kill any running instance
if pgrep -x "$APP_NAME" &>/dev/null; then
    echo "→ Stopping existing instance..."
    pkill -x "$APP_NAME" || true
    sleep 1
fi

# 3. Build
echo "→ Building (this takes ~30 seconds the first time)..."
swift build -c release

echo "✓ Build complete."

# 4. Create .app bundle
echo "→ Bundling .app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Info.plist" "$APP_BUNDLE/Contents/"
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# 5. Install to ~/Applications
mkdir -p "$DEST"
rm -rf "$DEST/$APP_BUNDLE"
cp -R "$APP_BUNDLE" "$DEST/"
rm -rf "$APP_BUNDLE"   # clean up local copy

echo "✓ Installed to $DEST/$APP_BUNDLE"

# 6. Launch
open "$DEST/$APP_BUNDLE"
echo "✓ Launched — look for 📅 in your menu bar."
echo ""

# 7. Add to Login Items
if osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$DEST/$APP_BUNDLE\", hidden:false}" &>/dev/null 2>&1; then
    echo "✓ Added to Login Items — will auto-start on reboot."
else
    echo "ℹ To auto-start on login, add it manually:"
    echo "  System Settings → General → Login Items → + → pick $DEST/$APP_BUNDLE"
fi

echo ""
echo "=== Done! Click 📅 in your menu bar to open the journal. ==="
