import AppKit
import Combine

/// 메뉴·아이콘·시스템 감시를 잇는 한 곳.
@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let releasesOnLowBattery = "releasesOnLowBattery"
        static let elapsedDisplay = "elapsedDisplay"
    }

    static let batteryThreshold = 20
    static let durationChoices: [TimeInterval] = [30 * 60, 60 * 60, 2 * 3600]

    @Published private(set) var elapsedText: String?
    @Published private(set) var isLidSettingOn = LidSleepSetting.isOn
    @Published private(set) var sessions: [ClaudeSession] = []

    /// 12시간 안에 띄운 것만 기본 목록에 올린다 (케이스 16)
    var recentSessions: [ClaudeSession] {
        let cutoff = Date().addingTimeInterval(-SessionScanner.recentWindow)
        let recent = sessions.filter { $0.startedAt > cutoff }
        // 전부 오래됐으면 빈 서브메뉴를 보여주지 않고 있는 것을 올린다
        return Array((recent.isEmpty ? sessions : recent).prefix(SessionScanner.menuLimit))
    }

    /// 기본 목록에 안 올라간 나머지 — `모두 보기…` 로 들어간다 (케이스 16·17)
    var olderSessions: [ClaudeSession] {
        let shown = Set(recentSessions.map(\.pid))
        return sessions.filter { !shown.contains($0.pid) }
    }

    /// 폴더명과 경과 시간이 같은 세션이 있으면 PID 를 붙여 구분한다 (케이스 15, B6)
    func menuLabel(for session: ClaudeSession) -> String {
        let base = "\(session.name) · \(session.elapsedText)"
        let isAmbiguous = sessions.contains {
            $0.pid != session.pid && $0.name == session.name && $0.elapsedText == session.elapsedText
        }
        return isAmbiguous ? "\(base) (\(session.pid))" : base
    }
    @Published private(set) var sleptWhileAwayNote: String?
    @Published private(set) var warning: String?
    @Published private(set) var lidError: String?

    @Published var releasesOnLowBattery: Bool {
        didSet { UserDefaults.standard.set(releasesOnLowBattery, forKey: Key.releasesOnLowBattery) }
    }

    /// 로그인할 때 자동 실행 (B4). 값은 시스템이 들고 있으므로 UserDefaults 에 저장하지 않는다.
    @Published private(set) var isLoginItemEnabled = LoginItem.isEnabled

    /// 메뉴바에 경과 시간을 어떻게 보일지 (B2). 메뉴 안에서는 설정과 무관하게 늘 초까지 보인다.
    @Published var elapsedDisplay: ElapsedDisplay {
        didSet {
            UserDefaults.standard.set(elapsedDisplay.rawValue, forKey: Key.elapsedDisplay)
            guard caffeinate.isRunning else { return }
            startElapsedTimer()
        }
    }

    let caffeinate = Caffeinate()
    private let notifier = Notifier()
    private var powerWatcher: PowerWatcher?
    private var hotKey: HotKey?
    private var elapsedTimer: Timer?
    private var wasPluggedIn = Battery.current()?.isPluggedIn ?? true

    var mode: KeepAwakeMode? { caffeinate.mode }

    var state: AwakeState {
        guard let mode = caffeinate.mode else { return .sleeping }
        if case .session = mode { return .keepingSession }
        return .awake
    }

    /// 메뉴 상태 줄 — 표시 설정과 무관하게 늘 초까지 보인다
    var statusText: String {
        guard let mode = caffeinate.mode else { return "잔다" }
        let elapsed = fullElapsedText.map { " · \($0)" } ?? ""
        if case let .session(_, name) = mode { return "\(name) 지키는 중\(elapsed)" }
        return "안 잔다\(elapsed)"
    }

    private var fullElapsedText: String? {
        guard let startedAt = caffeinate.startedAt else { return nil }
        let total = Int(Date().timeIntervalSince(startedAt))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)시간 \(minutes)분 \(seconds)초" }
        if minutes > 0 { return "\(minutes)분 \(seconds)초" }
        return "\(seconds)초"
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Key.releasesOnLowBattery: true,
                                     Key.elapsedDisplay: ElapsedDisplay.minutes.rawValue])
        releasesOnLowBattery = defaults.bool(forKey: Key.releasesOnLowBattery)
        elapsedDisplay = ElapsedDisplay(rawValue: defaults.string(forKey: Key.elapsedDisplay) ?? "")
            ?? .minutes

        caffeinate.onRelease = { [weak self] mode, wasExpected in
            self?.handleRelease(mode: mode, wasExpected: wasExpected)
        }
        powerWatcher = PowerWatcher { [weak self] in self?.handlePowerChange() }
        hotKey = HotKey { [weak self] in self?.toggle() }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recordSleep() }
        }
    }

    // MARK: 메뉴에서 부르는 것

    /// 메뉴를 여는 순간에만 읽는다 (케이스 7·14, G1).
    func refreshForMenuOpen() {
        isLidSettingOn = LidSleepSetting.isOn
        isLoginItemEnabled = LoginItem.isEnabled
        sessions = SessionScanner.scan(withinRecentWindow: false)
        warning = nil
    }

    func toggleLoginItem() {
        let failure = LoginItem.setEnabled(!isLoginItemEnabled)
        isLoginItemEnabled = LoginItem.isEnabled
        warning = failure.map { "로그인 항목을 바꾸지 못했다 — \($0)" }
    }

    /// `DWT_SELFTEST=1` 로 띄웠을 때만 돈다. 권한 응답을 기다렸다가 알림 3종을 보낸다.
    func runNotificationSelfTest() {
        notifier.requestAuthorizationIfNeeded()
        notifier.currentStatus { status in
            NSLog("[자가진단] 알림 권한: %@", status)
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            notifier.currentStatus { status in
                NSLog("[자가진단] 권한 응답 후: %@", status)
            }
            notifier.runSelfTest()
        }
    }

    func refreshLidSetting() {
        isLidSettingOn = LidSleepSetting.isOn
    }

    /// 안내 창의 버튼에서 부른다. 암호 창은 macOS 가 띄운다 (케이스 23).
    func applyLidSetting(isOn: Bool) {
        lidError = LidSleepSetting.apply(isOn: isOn)
        refreshLidSetting()
    }

    func start(mode: KeepAwakeMode) {
        notifier.requestAuthorizationIfNeeded()
        sleptWhileAwayNote = nil
        caffeinate.start(mode: mode)
        startElapsedTimer()
    }

    /// 자리를 비울 때 한 번으로 끝낸다 — 유지를 켜고 화면을 끈다.
    func leaveNow() {
        if !caffeinate.isRunning { start(mode: .indefinite) }
        guard !Display.sleepNow() else { return }
        warning = "화면을 끄지 못했다"
    }

    func stopByUser() {
        caffeinate.stop(byUser: true)
    }

    func toggle() {
        guard caffeinate.isRunning else {
            start(mode: .indefinite)
            return
        }
        stopByUser()
    }

    func isSelected(_ mode: KeepAwakeMode) -> Bool {
        caffeinate.mode == mode
    }

    // MARK: 내부

    private func handleRelease(mode: KeepAwakeMode, wasExpected: Bool) {
        stopElapsedTimer()
        guard !wasExpected else { return }

        if case let .session(pid, name) = mode {
            let remaining = SessionScanner.scan().filter { $0.pid != pid }.count
            notify(.sessionEnded(name: name, remaining: remaining))
            return
        }
        if case .duration = mode {
            notify(.durationExpired(title: mode.menuTitle, isLidSettingOn: LidSleepSetting.isOn))
        }
    }

    private func handlePowerChange() {
        guard let battery = Battery.current() else { return }

        if wasPluggedIn, !battery.isPluggedIn, caffeinate.isRunning {
            notify(.chargerUnplugged(isLidSettingOn: LidSleepSetting.isOn))
        }
        wasPluggedIn = battery.isPluggedIn

        let isBelowThreshold = !battery.isPluggedIn && battery.percent <= Self.batteryThreshold
        guard releasesOnLowBattery, isBelowThreshold, caffeinate.isRunning else { return }
        caffeinate.stop(byUser: true) // 해제 자체는 의도된 것이라 중복 알림을 막는다
        stopElapsedTimer()
        notify(.batteryLow(percent: battery.percent, isLidSettingOn: LidSleepSetting.isOn))
    }

    private func notify(_ kind: Notifier.Kind) {
        notifier.post(kind)
        warning = notifier.isAuthorized ? nil : notifier.pendingWarning
    }

    /**
     유지 중에 맥이 잠들었다 깨어났다 = 자리를 비운 사이 끊겼다는 뜻 (케이스 30).

     사유는 `pmset -g log` 에만 있고 읽는 데 1초가 넘으므로 백그라운드에서 찾는다.
     */
    private func recordSleep() {
        guard caffeinate.isRunning else { return }
        let wokeAt = Date()
        let fallback = DateFormatter.localizedString(from: wokeAt, dateStyle: .none, timeStyle: .short)
        sleptWhileAwayNote = "\(fallback) 에 잠들었다 깨어났다"

        Task.detached(priority: .utility) {
            guard let event = SleepHistory.lastRealSleep(before: wokeAt) else { return }
            await MainActor.run { self.sleptWhileAwayNote = event.noteText }
        }
    }

    /**
     경과 시간 타이머.

     분 단위로 보일 때는 **다음 분 경계**에 맞춰 1분에 한 번만 깨어난다 —
     30초 주기보다 적게 깨면서 분이 바뀌는 순간을 놓치지 않는다.
     */
    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        updateElapsed()

        guard elapsedDisplay != .hidden, let startedAt = caffeinate.startedAt else { return }

        let interval: TimeInterval = elapsedDisplay == .seconds ? 1 : 60
        let elapsed = Date().timeIntervalSince(startedAt)
        let firstDelay = interval - elapsed.truncatingRemainder(dividingBy: interval)

        let timer = Timer(fire: Date().addingTimeInterval(firstDelay), interval: interval, repeats: true) {
            [weak self] _ in
            Task { @MainActor in self?.updateElapsed() }
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsedText = nil
    }

    private func updateElapsed() {
        guard elapsedDisplay != .hidden else {
            elapsedText = nil
            return
        }
        elapsedText = caffeinate.elapsedText(withSeconds: elapsedDisplay == .seconds)
    }
}
