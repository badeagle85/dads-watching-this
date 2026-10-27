#!/usr/bin/env python3
"""
appcast 에서 최신 항목만 남긴다.

왜 필요한가: generate_appcast 는 `--download-url-prefix` 하나를 build/release 의
모든 zip 에 붙인다. 그 폴더에는 delta 를 만들기 위해 과거 zip 을 남겨 두므로,
옛 항목의 zip URL 이 최신 태그를 가리켜 404 가 된다 (2026-10-27 확인: 0.1.5·0.1.4).

옛 항목은 Sparkle 이 쓰지 않는다 — 늘 가장 새 항목을 고른다. delta 는 최신 항목
안에 들어 있으므로 잘라도 증분 업데이트는 그대로다.

    ./Tools/trim-appcast.py docs/appcast.xml [남길 개수]
"""
import io
import re
import sys

ITEM = re.compile(r'[ \t]*<item>.*?</item>\n', re.S)
BUILD = re.compile(r'<sparkle:version>(\d+)</sparkle:version>')
SHORT = re.compile(r'<sparkle:shortVersionString>([^<]+)</sparkle:shortVersionString>')
ZIP = re.compile(r'<enclosure url="([^"]*?\.zip)"')


def build_number(item):
    found = BUILD.search(item)
    return int(found.group(1)) if found else -1


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'docs/appcast.xml'
    keep = int(sys.argv[2]) if len(sys.argv) > 2 else 1

    text = io.open(path, encoding='utf-8').read()
    items = ITEM.findall(text)
    if not items:
        sys.exit('✗ appcast 에 item 이 없다: %s' % path)

    newest = sorted(items, key=build_number, reverse=True)[:keep]
    dropped = len(items) - len(newest)

    # 남길 항목은 zip URL 의 태그가 자기 버전과 맞아야 한다 — 어긋나면 받는 쪽이 404 를 만난다
    for item in newest:
        version = SHORT.search(item)
        url = ZIP.search(item)
        if not (version and url):
            sys.exit('✗ 버전이나 zip URL 을 못 읽었다')
        tag = re.search(r'/download/(v[^/]+)/', url.group(1))
        if not tag or tag.group(1) != 'v' + version.group(1):
            sys.exit('✗ %s 항목의 zip URL 태그가 %s 다. 멈춘다.'
                     % (version.group(1), tag.group(1) if tag else '없음'))

    kept_text = ''.join(newest)
    first = ITEM.search(text)
    # 첫 item 자리에 남길 것을 넣고 나머지 item 은 지운다
    text = text[:first.start()] + kept_text + ITEM.sub('', text[first.start():])
    io.open(path, 'w', encoding='utf-8').write(text)

    versions = ', '.join(SHORT.search(i).group(1) for i in newest)
    print('   appcast 항목 %d개 남김 (%s) · %d개 잘라냄' % (len(newest), versions, dropped))


main()
