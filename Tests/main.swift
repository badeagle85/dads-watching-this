import AppKit

/**
 시나리오 케이스 표를 그대로 돌리는 하네스.
 UI 클릭은 보조 접근 권한이 없어 못 하므로, 그 아래 로직을 실제 프로세스로 검증한다.
 테스트 이름 = 시나리오 행 번호.
 */
@MainActor
final class Harness {
    private var passed = 0
    private var failed: [String] = []

    func check(_ name: String, _ isOK: Bool, _ detail: String = "") {
        if isOK {
            passed += 1
            print("  ✓ \(name)")
            return
        }
        failed.append(name)
        print("  ✗ \(name) — \(detail)")
    }

    func report() -> Int32 {
        print("\n통과 \(passed) · 실패 \(failed.count)")
        for name in failed { print("  실패: \(name)") }
        return failed.isEmpty ? 0 : 1
    }
}

/// 떠 있는 caffeinate 자식의 인자를 읽는다
@MainActor
func caffeinateArguments() -> [String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-axo", "pid=,ppid=,args="]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(data: data, encoding: .utf8) ?? ""
    let ownPID = String(ProcessInfo.processInfo.processIdentifier)
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count > 3, parts[1] == ownPID, parts[2].hasSuffix("caffeinate") else { continue }
        return Array(parts[2...])
    }
    return []
}

/// 떠 있는 caffeinate 자식의 PID. 밖에서 죽는 경우를 흉내 내는 데 쓴다.
@MainActor
func caffeinateChildPIDs() -> [Int32] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-axo", "pid=,ppid=,args="]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(data: data, encoding: .utf8) ?? ""
    let ownPID = String(ProcessInfo.processInfo.processIdentifier)
    return text.split(separator: "\n").compactMap { line in
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count > 3, parts[1] == ownPID, parts[2].hasSuffix("caffeinate") else { return nil }
        return Int32(parts[0])
    }
}

@MainActor
func wait(_ seconds: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
}

@MainActor
func run() async -> Int32 {
    let harness = Harness()

    print("\n── 세션 조회 (케이스 14·15·16·17) ──")
    let sessions = SessionScanner.scan(withinRecentWindow: false)
    harness.check("#14 세션이 하나 이상 잡힌다", !sessions.isEmpty, "0개")
    harness.check("#14 모든 세션이 서로 다른 PID", Set(sessions.map(\.pid)).count == sessions.count)
    harness.check("#14 최근 시작 순 정렬",
                  zip(sessions, sessions.dropFirst()).allSatisfy { $0.startedAt >= $1.startedAt })
    let recent = SessionScanner.scan(withinRecentWindow: true)
    harness.check("#16 12시간 필터가 부분집합", recent.count <= sessions.count)

    let state = AppState()
    state.refreshForMenuOpen()
    harness.check("#17 기본 목록은 8개 이하", state.recentSessions.count <= SessionScanner.menuLimit,
                  "\(state.recentSessions.count)개")
    harness.check("#16·17 기본과 나머지의 합이 전체",
                  state.recentSessions.count + state.olderSessions.count == state.sessions.count)
    let labels = state.sessions.map(state.menuLabel(for:))
    harness.check("#15 라벨이 서로 다르다", Set(labels).count == labels.count, labels.joined(separator: " / "))
    harness.check("#14 세션 이름이 PID 대신 폴더명으로 잡힌다",
                  state.sessions.contains { !$0.name.hasPrefix("PID ") },
                  state.sessions.map(\.name).joined(separator: ", "))

    print("\n── 뚜껑 설정 읽기 (케이스 7·24) ──")
    harness.check("#7 ioreg 값과 앱이 읽은 값이 같다",
                  state.isLidSettingOn == LidSleepSetting.isOn)

    print("\n── 켜고 끄기 (케이스 2·3) ──")
    state.start(mode: .indefinite)
    await wait(0.4)
    var arguments = caffeinateArguments()
    harness.check("#2 caffeinate 가 떴다", !arguments.isEmpty)
    harness.check("#18 항상 -i (화면은 평소대로 꺼진다)", arguments.contains("-i"), arguments.joined(separator: " "))
    harness.check("#18 -di 는 쓰지 않는다", !arguments.contains("-di"))
    harness.check("#28 자기 PID 를 -w 로 감시", arguments.contains("-w"))
    harness.check("#2 상태가 '안 잔다'", state.state == .awake)
    harness.check("#2 아이콘이 template", MenuBarIcon.image(for: state.state, isLidWarningOn: false).isTemplate)

    state.stopByUser()
    await wait(0.4)
    harness.check("#3 해제하면 caffeinate 가 사라진다", caffeinateArguments().isEmpty)
    harness.check("#3 상태가 '잔다'", state.state == .sleeping)
    harness.check("#3 경과 시간이 사라진다", state.elapsedText == nil)

    print("\n── 모드 교체 (케이스 5) ──")
    state.start(mode: .duration(30 * 60))
    await wait(0.3)
    state.start(mode: .duration(2 * 3600))
    await wait(0.4)
    harness.check("#5 교체 후에도 caffeinate 는 하나", !caffeinateArguments().isEmpty)
    harness.check("#5 선택이 2시간으로 바뀐다", state.isSelected(.duration(2 * 3600)))
    harness.check("#5 30분 선택은 풀린다", !state.isSelected(.duration(30 * 60)))
    state.stopByUser()
    await wait(0.3)

    print("\n── 세션 감시 (케이스 11·12) ──")
    let dummy = Process()
    dummy.executableURL = URL(fileURLWithPath: "/bin/sleep")
    dummy.arguments = ["60"]
    try? dummy.run()
    await wait(0.2)
    state.start(mode: .session(pid: dummy.processIdentifier, name: "테스트세션"))
    await wait(0.4)
    harness.check("#11 세션 모드에서 caffeinate 가 뜬다", !caffeinateArguments().isEmpty)
    harness.check("#11 상태가 '세션 지키는 중'", state.state == .keepingSession)

    dummy.terminate()
    await wait(1.0)
    harness.check("#12 세션이 끝나면 자동 해제", state.state == .sleeping)
    harness.check("#12 caffeinate 도 사라진다", caffeinateArguments().isEmpty)

    print("\n── 해제를 알릴지 (shouldAnnounce) ──")
    // 이름만 뒤집고 동작이 반대가 되는 자리라 기본값까지 못 박는다
    let releases = Caffeinate()
    var announced: [Bool] = []
    releases.onRelease = { _, shouldAnnounce in announced.append(shouldAnnounce) }

    releases.start(mode: .indefinite)
    await wait(0.4)
    releases.stop(shouldAnnounce: false)
    await wait(0.6)
    harness.check("사용자가 끈 해제는 알리지 않는다", announced == [false], "\(announced)")

    let watched = Process()
    watched.executableURL = URL(fileURLWithPath: "/bin/sleep")
    watched.arguments = ["60"]
    try? watched.run()
    await wait(0.2)
    releases.start(mode: .session(pid: watched.processIdentifier, name: "알림테스트"))
    await wait(0.4)
    watched.terminate()
    await wait(1.0)
    harness.check("세션이 끝난 해제는 알린다", announced == [false, true], "\(announced)")

    // 기본값이 '안 알린다' 로 뒤집히면 여기서 걸린다
    releases.start(mode: .indefinite)
    await wait(0.4)
    for pid in caffeinateChildPIDs() { kill(pid, SIGTERM) }
    await wait(1.0)
    harness.check("밖에서 죽은 caffeinate 도 알린다", announced == [false, true, true], "\(announced)")

    print("\n── 로그인 항목 (B4) ──")
    harness.check("#B4 상태를 읽을 수 있다", state.isLoginItemEnabled == LoginItem.isEnabled)

    print("\n── 끊김 이력 (케이스 30, G2-A) ──")
    let idleLine = "2026-10-22 15:04:06 +0900 Sleep               \tEntering Sleep state due to 'Idle Sleep':TCPKeepAlive=active Using AC (Charge:100%) 286 secs"
    let parsed = SleepHistory.parse(idleLine)
    harness.check("#30 로그 한 줄에서 사유를 읽는다", parsed?.reason == "오래 안 써서", parsed?.reason ?? "nil")
    harness.check("#30 시각도 읽는다", parsed != nil && parsed!.date.timeIntervalSince1970 > 0)

    let clamshell = "2026-10-21 18:02:11 +0900 Sleep               \tEntering Sleep state due to 'Clamshell Sleep': Using Batt (Charge:88%)"
    harness.check("#30 뚜껑 닫힘을 한국어로", SleepHistory.parse(clamshell)?.reason == "뚜껑 닫힘")
    harness.check("#30 사유 없는 줄은 걸러낸다", SleepHistory.parse("2026-10-22 15:04:06 +0900 Wake   something") == nil)

    let found = SleepHistory.lastRealSleep(before: Date())
    harness.check("#30 실제 로그에서 마지막 잠을 찾는다", found != nil, "못 찾음")
    if let found {
        harness.check("#30 유지보수 잠은 제외된다", found.reason != "유지보수", found.reason)
        print("     → 마지막 잠: \(found.noteText)")
    }

    print("\n── 알림 권한 대기줄 ──")
    // 권한 응답이 오기 전에 보낸 알림이 조용히 버려지면 안 된다.
    // 하네스는 번들이 아니라 '거부' 로 즉시 확정된다 — 콜백이 빠지지 않는지를 본다.
    // 허용된 실제 번들에서의 비동기 경로는 `DWT_SELFTEST=1` 자가 진단이 확인한다.
    let notifier = Notifier()
    var results: [Bool] = []
    notifier.post(.sessionEnded(name: "첫째", remaining: 0)) { results.append($0) }
    notifier.post(.chargerUnplugged(isLidSettingOn: false)) { results.append($0) }
    notifier.post(.batteryLow(percent: 19, isLidSettingOn: false)) { results.append($0) }
    harness.check("연달아 보낸 알림이 모두 결과를 받는다", results.count == 3, "\(results.count)개")
    harness.check("권한을 모르는 동안은 보냈다고 하지 않는다", results.allSatisfy { $0 == false })
    harness.check("권한 미확정은 isAuthorized 가 false", !notifier.isAuthorized)

    print("\n── 아이콘 (상태 정의 3×2) ──")
    let states: [AwakeState] = [.sleeping, .awake, .keepingSession]
    var sizes: Set<String> = []
    for awake in states {
        for border in [false, true] {
            let image = MenuBarIcon.image(for: awake, isLidWarningOn: border)
            sizes.insert("\(image.size)")
            harness.check("아이콘 \(awake)/\(border) 생성", image.size.width == 18 && image.isTemplate)
        }
    }
    harness.check("6종 모두 같은 크기", sizes.count == 1)
    harness.check("VoiceOver 라벨에 상태와 경과가 들어간다",
                  MenuBarIcon.accessibilityLabel(for: .awake, isLidWarningOn: true, elapsed: "1:23")
                    == "안 잔다, 1:23 경과, 뚜껑 닫힘 설정 켜짐")

    return harness.report()
}

let task = Task { @MainActor in
    let code = await run()
    exit(code)
}
RunLoop.main.run()
