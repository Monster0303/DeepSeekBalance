#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
NAME="DeepSeekBalance"
DISPLAY_NAME="DeepSeekBalance"
VERSION=$(cat "$DIR/VERSION" | tr -d ' \n')
BUNDLE="$DIR/build/$NAME.app"
DMG="$DIR/build/$NAME-$VERSION.dmg"

echo "🔨 构建 $DISPLAY_NAME v$VERSION ..."
mkdir -p "$DIR/.build/debug"

swiftc -o "$DIR/.build/debug/$NAME" "$DIR/Sources/DeepSeekBalance/"*.swift \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -target x86_64-apple-macosx12.0 \
  -framework AppKit -framework SwiftUI -framework Security \
  -module-cache-path /tmp/clang-module-cache

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$DIR/.build/debug/$NAME" "$BUNDLE/Contents/MacOS/"
cp "$DIR/Resources/Info.plist" "$BUNDLE/Contents/"
cp "$DIR/Resources/entitlements.plist" "$BUNDLE/Contents/Resources/"
cp "$DIR/Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/"
# 写入版本号到 .app 内的 Info.plist
plutil -replace CFBundleShortVersionString -string "$VERSION" "$BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$(echo "$VERSION" | cut -d. -f1)" "$BUNDLE/Contents/Info.plist"

codesign --force --deep --sign - "$BUNDLE" 2>/dev/null || true

echo "✅ 构建完成: $BUNDLE"

# ── 打包 DMG ──
if [ "$1" != "--app-only" ]; then
  echo "📦 打包 DMG ..."
  TMP_DIR=$(mktemp -d)
  cp -R "$BUNDLE" "$TMP_DIR/$DISPLAY_NAME.app"
  ln -s /Applications "$TMP_DIR/Applications"
  hdiutil create -volname "$DISPLAY_NAME" \
    -srcfolder "$TMP_DIR" \
    -ov -format UDZO \
    "$DMG" 2>/dev/null
  rm -rf "$TMP_DIR"
  echo "✅ DMG 已生成: $DMG"
fi
