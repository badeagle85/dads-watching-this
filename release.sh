#!/bin/bash
# 릴리스 한 번에. 버전만 주면 빌드부터 brew tap 갱신까지 한다.
#
#   ./release.sh 0.1.5 "짧은 제목" ["릴리스 노트 파일"]
#
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
TITLE="${2:-v$1}"
NOTES_FILE="${3:-}"

if [ -z "$VERSION" ]; then
  echo "쓰는 법: ./release.sh <버전> [제목] [노트파일]"
  exit 1
fi

TAP_DIR="../homebrew-tap"
ZIP="build/release/DadsWatchingThis-$VERSION.zip"
DMG="build/dmg/DadsWatchingThis-$VERSION.dmg"
BUILD_NUMBER=$(/usr/bin/defaults read "$PWD/Resources/Info.plist" CFBundleVersion)
NEXT_BUILD=$((BUILD_NUMBER + 1))

echo "▸ 1/8  버전을 $VERSION (빌드 $NEXT_BUILD) 로 올린다"
/usr/bin/plutil -replace CFBundleShortVersionString -string "$VERSION" Resources/Info.plist
/usr/bin/plutil -replace CFBundleVersion -string "$NEXT_BUILD" Resources/Info.plist

echo "▸ 2/8  빌드와 테스트"
./build.sh > /dev/null
./test.sh | tail -1

echo "▸ 3/8  압축 (Sparkle·brew 용)"
mkdir -p build/release
ditto -c -k --keepParent build/DadsWatchingThis.app "$ZIP"

echo "▸ 4/8  dmg 만들기 (직접 받는 사람용)"
# appcast 생성 폴더(build/release)와 분리한다 — 같이 두면 Sparkle 이 중복으로 본다
mkdir -p build/dmg
STAGE="build/dmg-stage"
/bin/rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R build/DadsWatchingThis.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
/bin/rm -f "$DMG"
# hdiutil create 는 macOS 27 에서 deprecated 다
diskutil image create from --format UDZO --volumeName "아빠안잔다 $VERSION" "$STAGE" "$DMG" > /dev/null 2>&1
/bin/rm -rf "$STAGE"

echo "▸ 5/8  appcast 서명"
./Vendor/bin/generate_appcast \
  --download-url-prefix "https://github.com/badeagle85/dads-watching-this/releases/download/v$VERSION/" \
  -o docs/appcast.xml build/release 2>&1 | grep -viE "mismatch code signing|deprecated" || true

# appcast 에 이번 버전이 들어갔는지 확인한다 — 빠지면 자동 업데이트가 안 간다
if ! grep -q "<sparkle:shortVersionString>$VERSION<" docs/appcast.xml; then
  echo "✗ appcast 에 $VERSION 이 안 들어갔다. 멈춘다."
  exit 1
fi

echo "▸ 6/8  커밋과 태그"
git add -A
git commit -q -m "chore: $VERSION"
git tag "v$VERSION"
git push -q origin main --tags

echo "▸ 7/8  릴리스 업로드 (zip + dmg)"
if [ -n "$NOTES_FILE" ]; then
  gh release create "v$VERSION" "$ZIP" "$DMG" --title "$TITLE" --notes-file "$NOTES_FILE"
else
  gh release create "v$VERSION" "$ZIP" "$DMG" --title "$TITLE" --generate-notes
fi

# 증분 업데이트 파일 — appcast 가 참조하므로 같이 올린다
DELTAS=$(grep -oE "DadsWatchingThis[0-9]+-[0-9]+\.delta" docs/appcast.xml | sort -u | sed "s|^|build/release/|" | tr "\n" " ")
if [ -n "$DELTAS" ]; then
  gh release upload "v$VERSION" $DELTAS --clobber 2>/dev/null || true
fi

echo "▸ 8/8  brew tap 갱신"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)
/usr/bin/sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$TAP_DIR/Casks/dads-watching-this.rb"
/usr/bin/sed -i '' "s/sha256 \".*\"/sha256 \"$SHA\"/" "$TAP_DIR/Casks/dads-watching-this.rb"
git -C "$TAP_DIR" add -A
git -C "$TAP_DIR" commit -q -m "chore: 아빠안잔다 $VERSION"
git -C "$TAP_DIR" push -q origin main

echo ""
echo "끝났다. https://github.com/badeagle85/dads-watching-this/releases/tag/v$VERSION"
echo "appcast 는 GitHub Pages 가 반영할 때까지 1~2분 걸린다."
