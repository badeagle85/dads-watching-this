import Foundation

/// 메뉴바에 경과 시간을 어떻게 보일지
enum ElapsedDisplay: String, CaseIterable {
    case hidden
    case minutes
    case seconds

    var menuTitle: String {
        if self == .hidden { return "숨김" }
        if self == .minutes { return "시:분" }
        return "시:분:초"
    }
}

/// 유지 모드 — 무엇이 끝나면 해제할지를 정한다.
enum KeepAwakeMode: Equatable {
    case indefinite
    case duration(TimeInterval)
    case session(pid: Int32, name: String)

    var menuTitle: String {
        if case .indefinite = self { return "계속 본다" }
        if case let .duration(seconds) = self { return Self.durationTitle(seconds) }
        if case let .session(_, name) = self { return name }
        return ""
    }

    static func durationTitle(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes)분만 더" : "\(minutes / 60)시간만 더"
    }
}

/**
 `/usr/bin/caffeinate` 자식 프로세스 하나를 관리한다.

 - `-i` 로 시스템 잠만 막는다. 화면은 평소대로 꺼진다 — 자리를 비우는 것이 전제다.
 - `-w <앱 PID>` 를 항상 붙여 앱이 죽으면 좀비가 남지 않게 한다 (케이스 28·29).
 - 세션 종료는 `DispatchSource` 커널 이벤트로 받는다 — 폴링 없음 (B5·G1).
 */
@MainActor
final class Caffeinate: ObservableObject {
    @Published private(set) var mode: KeepAwakeMode?
    @Published private(set) var startedAt: Date?

    /// 해제됐을 때 불린다. 사용자가 끈 경우에만 `wasExpected == true`.
    var onRelease: ((_ mode: KeepAwakeMode, _ wasExpected: Bool) -> Void)?

    private var task: Process?
    private var expiryTimer: Timer?
    private var sessionWatcher: DispatchSourceProcess?
    private var isStoppingByUser = false

    var isRunning: Bool { mode != nil }

    func elapsedText(withSeconds: Bool) -> String? {
        guard let startedAt else { return nil }
        let total = Int(Date().timeIntervalSince(startedAt))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        guard withSeconds else { return String(format: "%d:%02d", hours, minutes) }
        return String(format: "%d:%02d:%02d", hours, minutes, total % 60)
    }

    func start(mode: KeepAwakeMode) {
        discardCurrentProcess()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        // -i 고정: 시스템만 깨워 두고 화면은 평소대로 꺼지게 둔다
        process.arguments = ["-i", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        process.terminationHandler = { [weak self] finished in
            Task { @MainActor in
                guard let self, self.task === finished else { return }
                self.handleTermination()
            }
        }

        do {
            try process.run()
        } catch {
            NSLog("caffeinate 실행 실패: \(error.localizedDescription)")
            return
        }

        task = process
        self.mode = mode
        startedAt = Date()
        isStoppingByUser = false

        if case let .duration(seconds) = mode {
            scheduleExpiry(after: seconds)
        }
        if case let .session(pid, _) = mode {
            watchSession(pid: pid)
        }
    }

    func stop(byUser: Bool) {
        guard let process = task, process.isRunning else {
            clearState()
            return
        }
        isStoppingByUser = byUser
        process.terminate()
    }

    /// 콜백 없이 조용히 버린다 — 새 모드로 갈아탈 때.
    private func discardCurrentProcess() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        sessionWatcher?.cancel()
        sessionWatcher = nil
        task?.terminate()
        task = nil
    }

    private func scheduleExpiry(after seconds: TimeInterval) {
        expiryTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop(byUser: false) }
        }
    }

    /// 세션 프로세스가 끝나면 해제한다 — 커널 이벤트라 폴링이 없다.
    private func watchSession(pid: Int32) {
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.stop(byUser: false) }
        }
        source.resume()
        sessionWatcher = source
    }

    private func handleTermination() {
        let releasedMode = mode
        let wasExpected = isStoppingByUser
        clearState()
        guard let releasedMode else { return }
        onRelease?(releasedMode, wasExpected)
    }

    private func clearState() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        sessionWatcher?.cancel()
        sessionWatcher = nil
        task = nil
        mode = nil
        startedAt = nil
        isStoppingByUser = false
    }
}
