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

    /// 권한 응답은 비동기로 온다. 아직 모르는 상태와 거부된 상태를 구분해야 알림을 안 버린다.
    private enum Authorization {
        case unknown
        case asking
        case decided(isGranted: Bool)
    }

    private var authorization: Authorization = .unknown
    /// 응답을 기다리는 사이에 온 알림들. 응답이 오면 한꺼번에 흘려보낸다.
    private var waitingForAuthorization: [(Bool) -> Void] = []

    /// 권한이 **허용으로 확정됐을 때만** true. 아직 모르는 동안은 false다 — 경고 표시에 쓰지 말 것.
    var isAuthorized: Bool {
        guard case let .decided(isGranted) = authorization else { return false }
        return isGranted
    }

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

    /**
     알림을 띄운다.

     - Parameter onResult: 실제로 알림 센터에 넣었는지. 권한 응답을 기다린 뒤에 불린다.
     */
    func post(_ kind: Kind, onResult: ((Bool) -> Void)? = nil) {
        let (title, body) = Self.text(for: kind)
        pendingWarning = body
        deliver(title: title, body: body, onResult: onResult)
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

    private func deliver(title: String, body: String, onResult: ((Bool) -> Void)? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        // 권한 응답을 기다린다. 먼저 거르면 앱을 켠 직후에 온 알림이 조용히 사라진다
        requestAuthorizationIfNeeded { isGranted in
            if isGranted { UNUserNotificationCenter.current().add(request) }
            onResult?(isGranted)
        }
    }

    /**
     앱 시작이 아니라 첫 유지 시작 때 묻는다 — 쓰지도 않을 권한을 먼저 요구하지 않는다.

     - Parameter completion: 허용 여부. 이미 정해졌으면 곧바로, 묻는 중이면 응답이 온 뒤에 불린다.
     */
    func requestAuthorizationIfNeeded(_ completion: ((Bool) -> Void)? = nil) {
        if case let .decided(isGranted) = authorization {
            completion?(isGranted)
            return
        }
        if let completion { waitingForAuthorization.append(completion) }

        guard case .unknown = authorization else { return } // 이미 묻는 중이면 대기줄에만 넣는다
        guard Bundle.main.bundleIdentifier != nil else {
            settleAuthorization(isGranted: false)
            return
        }

        authorization = .asking
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.settleAuthorization(isGranted: granted) }
        }
    }

    private func settleAuthorization(isGranted: Bool) {
        authorization = .decided(isGranted: isGranted)
        let waiting = waitingForAuthorization
        waitingForAuthorization = []
        for report in waiting { report(isGranted) }
    }
}
