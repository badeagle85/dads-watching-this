#!/bin/bash
# 아빠안잔다 빌드 — Xcode 없이 Command Line Tools 만으로 .app 을 만든다.
set -euo pipefail

cd "$(dirname "$0")"

NAME="DadsWatchingThis"
APP="build/$NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Sparkle 프레임워크를 번들에 넣고, 실행 파일이 거기서 찾게 rpath 를 건다
mkdir -p "$APP/Contents/Frameworks"
cp -R Vendor/Sparkle.framework "$APP/Contents/Frameworks/"

swiftc -parse-as-library -O \
  -target arm64-apple-macos14.0 \
  -F Vendor -framework Sparkle \
  -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
  -o "$APP/Contents/MacOS/$NAME" \
  Sources/*.swift

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# 애드혹 서명 — 안쪽부터 바깥으로. Sparkle 이 서명 일치를 확인한다
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" 2>/dev/null || true
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" 2>/dev/null || true
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"

echo "빌드 완료: $APP"
