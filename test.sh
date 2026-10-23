#!/bin/bash
# 시나리오 케이스 표를 실제로 돌린다. 실행 중인 앱과 무관하게 따로 뜬다.
# App.swift 는 @main 이 겹쳐서 뺀다 — UI 는 어차피 여기서 못 돌린다.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -o build/harness \
  Sources/SVGPath.swift Sources/MenuBarIcon.swift Sources/SystemState.swift \
  Sources/Caffeinate.swift Sources/Notifier.swift Sources/HotKey.swift Sources/AppState.swift \
  Tests/main.swift
./build/harness
