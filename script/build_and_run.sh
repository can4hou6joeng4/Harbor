#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PRODUCT_NAME="ReaderMacApp"
DISPLAY_NAME="Reader"
BUNDLE_ID="com.bobochang.ReaderMacApp"
MIN_SYSTEM_VERSION="13.0"
SHORT_VERSION="${SHORT_VERSION:-0.1.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RESOURCE_DIR="$ROOT_DIR/Resources"
ICON_FILE="$RESOURCE_DIR/AppIcon.icns"
APP_NAME="$PRODUCT_NAME"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
LOCAL_ENTITLEMENTS="$DIST_DIR/ReaderMacApp.local.entitlements"
BUILD_DIR=""

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"

find_sparkle_framework() {
  if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR/Sparkle.framework" ]]; then
    printf '%s\n' "$BUILD_DIR/Sparkle.framework"
    return
  fi

  find "$ROOT_DIR/.build/artifacts" -type d -name "Sparkle.framework" -print 2>/dev/null | sort | head -n 1
}

copy_embedded_frameworks() {
  local sparkle_framework
  sparkle_framework="$(find_sparkle_framework)"
  if [[ -z "$sparkle_framework" ]]; then
    echo "error: Sparkle.framework not found under .build; run swift package resolve/build first" >&2
    exit 1
  fi

  mkdir -p "$APP_FRAMEWORKS"
  ditto "$sparkle_framework" "$APP_FRAMEWORKS/Sparkle.framework"

  if ! otool -l "$APP_BINARY" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BINARY"
  fi
}

copy_embedded_frameworks

cat >"$LOCAL_ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
PLIST

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
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
  <key>ReaderEnableSparkleUpdates</key>
  <false/>
</dict>
</plist>
PLIST

plutil -lint "$INFO_PLIST" >/dev/null

codesign --force \
  --options runtime \
  --timestamp=none \
  --sign - \
  "$APP_FRAMEWORKS/Sparkle.framework"

codesign --force \
  --options runtime \
  --timestamp=none \
  --entitlements "$LOCAL_ENTITLEMENTS" \
  --sign - \
  "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
