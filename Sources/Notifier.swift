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

    /// 지금 권한이 어떤 상태인지 — 자가 진단용
    func currentStatus(_ completion: @escaping (String) -> Void) {
        guard Bundle.main.bundleIdentifier != nil else {
            completion("번들이 아니라 알림을 쓸 수 없다")
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let names: [UNAuthorizationStatus: String] = [
                .notDetermined: "아직 묻지 않음",
                .denied: "거부됨",
                .authorized: "허용됨",
                .provisional: "임시 허용",
            ]
            completion(names[settings.authorizationStatus] ?? "알 수 없음")
        }
    }

    /// 알림 3종을 차례로 띄워 본다 (`DWT_SELFTEST=1` 로 실행하면 돈다)
    func runSelfTest() {
        let samples: [Kind] = [
            .sessionEnded(name: "자가진단", remaining: 2),
            .chargerUnplugged(isLidSettingOn: true),
            .batteryLow(percent: 19, isLidSettingOn: false),
        ]
        for (index, kind) in samples.enumerated() {
            let (title, body) = Self.text(for: kind)
            NSLog("[자가진단] %d/3 보냄: %@ — %@", index + 1, title, body)
            deliver(title: title, body: body)
        }

        // 실제로 알림 센터에 꽂혔는지 확인한다
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
                NSLog("[자가진단] 알림 센터 도착: %d개", delivered.count)
                for item in delivered {
                    NSLog("[자가진단]   · %@ / %@", item.request.content.title, item.request.content.body)
                }
            }
        }
    }

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
            let tail = remaining > 0 ? " 다른 세션 \(remaining)개는 아직 돈다." : ""
            return ("다 봤다", "\(name) 끝나서 껐다.\(tail)")
        }
        if case let .chargerUnplugged(isLidSettingOn) = kind {
            return ("선 빠졌다", Self.lidTail("배터리로 버티는 중이다.", isLidSettingOn))
        }
        if case let .durationExpired(title, isLidSettingOn) = kind {
            return ("시간 다 됐다", Self.lidTail("\(title) 지나서 껐다.", isLidSettingOn))
        }
        if case let .batteryLow(percent, isLidSettingOn) = kind {
            return ("힘 빠졌다", Self.lidTail("배터리 \(percent)% 라 껐다.", isLidSettingOn))
        }
        return ("아빠안잔다", "")
    }

    private static func lidTail(_ body: String, _ isLidSettingOn: Bool) -> String {
        guard isLidSettingOn else { return body }
        return body + " 뚜껑 닫힘 설정은 아직 켜져 있다."
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
