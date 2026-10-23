#!/bin/bash
# 아빠안잔다 빌드 — Xcode 없이 Command Line Tools 만으로 .app 을 만든다.
set -euo pipefail

cd "$(dirname "$0")"

NAME="DadsWatchingThis"
APP="build/$NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -parse-as-library -O \
  -target arm64-apple-macos14.0 \
  -o "$APP/Contents/MacOS/$NAME" \
  Sources/*.swift

cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# 애드혹 서명 — 알림·전역 단축키가 번들 신원을 요구한다
codesign --force --sign - "$APP"

echo "빌드 완료: $APP"
