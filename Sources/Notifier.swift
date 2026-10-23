import AppKit
import UserNotifications

/// 알림 3종 — 자리를 비운 사이에 일어난 일만 알린다.
@MainActor
final class Notifier {
    enum Kind {
        case sessionEnded(name: String, remaining: Int)
        case chargerUnplugged(isLidSettingOn: Bool)
        case durationExpired(title: String, isLidSettingOn: Bool)
        case batteryLow(percent: Int, isLidSettingOn: Bool)
    }

    private(set) var isAuthorized = false
    private var hasAskedAuthorization = false

    /// 거부당했을 때를 위해 메뉴 상단에 띄울 한 줄. G4 추천안.
    private(set) var pendingWarning: String?

    func clearWarning() { pendingWarning = nil }

    func post(_ kind: Kind) {
        let (title, body) = Self.text(for: kind)
        pendingWarning = body
        deliver(title: title, body: body)
    }

    private static func text(for kind: Kind) -> (String, String) {
        if case let .sessionEnded(name, remaining) = kind {
            let tail = remaining > 0 ? " 다른 세션 \(remaining)개는 아직 돌고 있다." : ""
            return ("아빠 잔다", "\(name) 세션이 끝나서 유지를 해제했다.\(tail)")
        }
        if case let .chargerUnplugged(isLidSettingOn) = kind {
            return ("충전기가 빠졌다", Self.lidTail("배터리로 버티는 중이다.", isLidSettingOn))
        }
        if case let .durationExpired(title, isLidSettingOn) = kind {
            return ("시간이 다 됐다", Self.lidTail("\(title) 이 지나 유지를 해제했다.", isLidSettingOn))
        }
        if case let .batteryLow(percent, isLidSettingOn) = kind {
            return ("배터리가 \(percent)% 다", Self.lidTail("유지를 해제했다.", isLidSettingOn))
        }
        return ("아빠안잔다", "")
    }

    private static func lidTail(_ body: String, _ isLidSettingOn: Bool) -> String {
        guard isLidSettingOn else { return body }
        return body + " 앱은 해제했으나 뚜껑 닫힘 시스템 설정은 켜져 있다."
    }

    private func deliver(title: String, body: String) {
        requestAuthorizationIfNeeded()
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// 앱 시작이 아니라 첫 유지 시작 때 묻는다 — 쓰지도 않을 권한을 먼저 요구하지 않는다.
    func requestAuthorizationIfNeeded() {
        guard !hasAskedAuthorization, Bundle.main.bundleIdentifier != nil else { return }
        hasAskedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.isAuthorized = granted }
        }
    }
}
