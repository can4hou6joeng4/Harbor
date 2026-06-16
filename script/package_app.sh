#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="ReaderMacApp"
DISPLAY_NAME="Reader"
BUNDLE_ID="com.bobochang.ReaderMacApp"
MIN_SYSTEM_VERSION="13.0"
SHORT_VERSION="${SHORT_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENABLE_APP_SANDBOX="${ENABLE_APP_SANDBOX:-0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RESOURCE_DIR="$ROOT_DIR/Resources"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$PRODUCT_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
SANDBOX_ENTITLEMENTS="$RESOURCE_DIR/Reader.entitlements"
LOCAL_ENTITLEMENTS="$DIST_DIR/Reader.local.entitlements"
SIGNING_ENTITLEMENTS="$LOCAL_ENTITLEMENTS"
ICON_PNG="$DIST_DIR/AppIcon-1024.png"
ICONSET="$DIST_DIR/AppIcon.iconset"
ICON_FILE="$RESOURCE_DIR/AppIcon.icns"
ICON_TOOL="$DIST_DIR/make_app_icon"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_FILE="$DIST_DIR/$DISPLAY_NAME.dmg"

usage() {
  cat <<USAGE
usage: $0 [--regenerate-icon]

Environment:
  SHORT_VERSION=0.1.0          CFBundleShortVersionString
  BUILD_NUMBER=<git-count>     CFBundleVersion
  SIGN_IDENTITY=-              codesign identity; '-' means ad-hoc
  ENABLE_APP_SANDBOX=0|1       default 0 for local ad-hoc Keychain safety
USAGE
}

REGENERATE_ICON=0
for arg in "$@"; do
  case "$arg" in
    --regenerate-icon)
      REGENERATE_ICON=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required tool not found: $1" >&2
    exit 1
  fi
}

write_local_entitlements() {
  cat >"$LOCAL_ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
</dict>
</plist>
PLIST
}

generate_icon() {
  mkdir -p "$DIST_DIR" "$RESOURCE_DIR"
  swiftc "$ROOT_DIR/script/make_app_icon.swift" -o "$ICON_TOOL"
  "$ICON_TOOL" "$ICON_PNG"

  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
  cp "$ICON_PNG" "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o "$ICON_FILE"
}

write_info_plist() {
  cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$PRODUCT_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$SHORT_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.news</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 Bobo Chang. All rights reserved.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
}

require_tool swift
require_tool swiftc
require_tool sips
require_tool iconutil
require_tool codesign
require_tool hdiutil
require_tool plutil

mkdir -p "$DIST_DIR" "$RESOURCE_DIR"

if [[ "$REGENERATE_ICON" == "1" || ! -f "$ICON_FILE" ]]; then
  echo "==> Generating AppIcon.icns"
  generate_icon
fi

if [[ "$ENABLE_APP_SANDBOX" == "1" ]]; then
  SIGNING_ENTITLEMENTS="$SANDBOX_ENTITLEMENTS"
else
  write_local_entitlements
fi

echo "==> Building release binary"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$PRODUCT_NAME"

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE" "$DMG_ROOT" "$DMG_FILE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
write_info_plist
plutil -lint "$INFO_PLIST" >/dev/null

echo "==> Signing $APP_BUNDLE"
codesign --force \
  --options runtime \
  --timestamp=none \
  --entitlements "$SIGNING_ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP_BUNDLE"

echo "==> Verifying signature"
codesign --verify --strict "$APP_BUNDLE"
codesign -dvvv --entitlements :- "$APP_BUNDLE"

echo "==> Creating DMG"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$DISPLAY_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_FILE"
hdiutil verify "$DMG_FILE"

cat <<SUMMARY

Packaged:
  $APP_BUNDLE
  $DMG_FILE

Signing:
  identity: $SIGN_IDENTITY
  hardened runtime: enabled
  sandbox: $ENABLE_APP_SANDBOX
  entitlements: $SIGNING_ENTITLEMENTS
SUMMARY
