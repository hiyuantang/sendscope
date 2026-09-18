#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="SendScope"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build
BUILD_DIR="$(swift build --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp engine/sendscope_addon.py "$APP_BUNDLE/Contents/Resources/"
printf '%s\n' "$ROOT_DIR/.runtime/bin/mitmdump" > "$APP_BUNDLE/Contents/Resources/engine-path.txt"
if [[ -f assets/SendScope.icns ]]; then cp assets/SendScope.icns "$APP_BUNDLE/Contents/Resources/"; fi
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SendScope</string>
<key>CFBundleIdentifier</key><string>app.sendscope.mac</string>
<key>CFBundleName</key><string>SendScope</string>
<key>CFBundleDisplayName</key><string>SendScope</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>SendScope</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP_BUNDLE" >/dev/null
case "$MODE" in
  --build-only) ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|--telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --predicate 'process == "SendScope"' ;;
  *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
