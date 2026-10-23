#!/bin/bash
# 앱 아이콘을 코드에서 렌더해 Resources/AppIcon.icns 를 만든다.
# 디자인을 고쳤을 때만 돌리면 된다 — 결과물은 저장소에 커밋되어 있다.
set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" build/iconmaker
mkdir -p "$ICONSET"

swiftc -O -o build/iconmaker \
  Sources/SVGPath.swift Sources/MenuBarIcon.swift \
  Tools/AppIcon.swift Tools/main.swift

./build/iconmaker iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$ICONSET"

mkdir -p docs/images
./build/iconmaker readme docs/images

echo "만들었다: Resources/AppIcon.icns · docs/images/*.png"
