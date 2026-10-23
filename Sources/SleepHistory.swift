import Foundation

/// 맥이 잠들었던 기록 한 건
struct SleepEvent: Equatable {
    let date: Date
    let reason: String

    var noteText: String {
        let time = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        return "\(time) 에 잠들었다 — \(reason)"
    }
}

/**
 `pmset -g log` 에서 "진짜 잠" 을 찾는다.

 로그가 2만 줄이 넘고 1.4초쯤 걸리므로 **반드시 백그라운드에서** 부른다.
 깨어난 직후 한 번만 읽으면 되니 폴링은 없다 (G2-A).
 */
enum SleepHistory {
    /// 유지보수용 짧은 잠은 세션을 멈추지 않으므로 세지 않는다
    private static let maintenanceMarkers = ["Maintenance Sleep", "DarkWake"]

    private static let reasonNames: [String: String] = [
        "Clamshell Sleep": "뚜껑 닫힘",
        "Idle Sleep": "오래 안 써서",
        "Software Sleep": "사용자나 앱이 재움",
        "Low Power Sleep": "배터리 부족",
        "Maintenance Sleep": "유지보수",
    ]

    /// `before` 보다 앞선 가장 최근의 진짜 잠. 로그를 못 읽으면 nil.
    static func lastRealSleep(before: Date) -> SleepEvent? {
        guard let log = runLog() else { return nil }

        for line in log.split(separator: "\n").reversed() {
            guard line.contains("Entering Sleep state due to") else { continue }
            guard !maintenanceMarkers.contains(where: line.contains) else { continue }
            guard let event = parse(String(line)), event.date < before else { continue }
            return event
        }
        return nil
    }

    /// `2026-10-22 15:04:06 +0900 Sleep  Entering Sleep state due to 'Idle Sleep':…`
    static func parse(_ line: String) -> SleepEvent? {
        guard let date = parseDate(line), let reason = parseReason(line) else { return nil }
        return SleepEvent(date: date, reason: reason)
    }

    private static func parseDate(_ line: String) -> Date? {
        guard line.count >= 25 else { return nil }
        let stamp = String(line.prefix(25))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: stamp)
    }

    /// `due to 'Idle Sleep'` 의 따옴표 안쪽
    private static func parseReason(_ line: String) -> String? {
        guard let opening = line.range(of: "due to '"),
              let closing = line.range(of: "'", range: opening.upperBound..<line.endIndex)
        else { return nil }
        let raw = String(line[opening.upperBound..<closing.lowerBound])
        return reasonNames[raw] ?? raw
    }

    private static func runLog() -> String? {
        SessionScanner.shell("/usr/bin/pmset", ["-g", "log"])
    }
}
