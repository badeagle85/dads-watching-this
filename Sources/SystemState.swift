import Foundation
import IOKit
import IOKit.ps
import ServiceManagement

/// 뚜껑 닫힘 설정. 값은 `ioreg` 로 읽고, 바꿀 때는 macOS 가 암호를 받는다 (G3-A').
enum LidSleepSetting {
    static let enableCommand = "sudo pmset -a disablesleep 1"
    static let disableCommand = "sudo pmset -a disablesleep 0"

    /**
     관리자 권한으로 `pmset` 을 실행한다.
     암호 입력은 macOS 가 직접 받는다 — 앱은 암호를 보지도, 저장하지도 않는다.

     - Returns: 오류 메시지. 성공했거나 사용자가 취소했으면 nil.
     */
    static func apply(isOn: Bool) -> String? {
        let value = isOn ? 1 : 0
        let source = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        var failure: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&failure)
        guard let failure else { return nil }

        let code = failure[NSAppleScript.errorNumber] as? Int ?? 0
        let didCancel = code == -128
        guard !didCancel else { return nil }
        return failure[NSAppleScript.errorMessage] as? String ?? "설정을 바꾸지 못했다"
    }

    /// `ioreg` 의 IOPMrootDomain 에서 읽는다. 권한이 필요 없다.
    static var isOn: Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "SleepDisabled" as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }
}

/**
 로그인할 때 자동 실행 (B4).

 `SMAppService` 는 macOS 13 부터 쓸 수 있고 별도 헬퍼 번들이 필요 없다.
 켜고 끄는 것은 시스템 설정 ▸ 일반 ▸ 로그인 항목에도 그대로 보인다.
 */
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 바꾸지 못하면 이유를 돌려준다. 성공하면 nil.
    static func setEnabled(_ shouldEnable: Bool) -> String? {
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

enum Display {
    /**
     화면만 끈다. 모니터 전원만 내리는 것이라 세션·시스템은 그대로 돈다.
     시스템 설정에서 "화면이 꺼진 뒤 암호 요구" 가 켜져 있으면 결과적으로 잠긴다.
     */
    @discardableResult
    static func sleepNow() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

enum Battery {
    /// 충전기 연결 여부와 잔량(%). 전원 정보를 못 읽으면 nil.
    static func current() -> (percent: Int, isPluggedIn: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            guard let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int, maximum > 0
            else { continue }
            let state = description[kIOPSPowerSourceStateKey] as? String
            return (Int(round(Double(capacity) / Double(maximum) * 100)), state == kIOPSACPowerValue)
        }
        return nil
    }
}

/// 실행 중인 Claude Code 세션. 부모가 claude 가 아니고 부모가 쉘인 것만 센다.
struct ClaudeSession: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let startedAt: Date

    var id: Int32 { pid }

    var elapsedText: String {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        if seconds < 3600 { return "\(max(seconds / 60, 1))분" }
        if seconds < 86_400 { return "\(seconds / 3600)시간" }
        return "\(seconds / 86_400)일"
    }
}

enum SessionScanner {
    private static let shellNames: Set<String> = ["zsh", "-zsh", "bash", "-bash", "fish", "-fish", "login", "sh"]
    static let recentWindow: TimeInterval = 12 * 3600
    static let menuLimit = 8

    /// 메뉴를 열 때만 호출한다 (G1: 폴링 없음).
    static func scan(withinRecentWindow: Bool = true) -> [ClaudeSession] {
        let rows = runProcessList()
        let claudePIDs = Set(rows.filter { $0.command.hasSuffix("claude") }.map(\.pid))

        let topLevel = rows.filter { row in
            guard claudePIDs.contains(row.pid), !claudePIDs.contains(row.parentPID) else { return false }
            guard let parent = rows.first(where: { $0.pid == row.parentPID }) else { return false }
            return shellNames.contains(parent.command)
        }

        // lsof 는 PID 를 한꺼번에 받는다 — 세션마다 띄우면 프로세스가 그 수만큼 생긴다
        let directories = workingDirectories(of: topLevel.map(\.pid))
        let sessions = topLevel.map { row in
            ClaudeSession(pid: row.pid,
                          name: directories[row.pid] ?? "PID \(row.pid)",
                          startedAt: row.startedAt)
        }

        let sorted = sessions.sorted { $0.startedAt > $1.startedAt }
        guard withinRecentWindow else { return sorted }
        let cutoff = Date().addingTimeInterval(-recentWindow)
        return sorted.filter { $0.startedAt > cutoff }
    }

    private struct ProcessRow {
        let pid: Int32
        let parentPID: Int32
        let command: String
        let startedAt: Date
    }

    private static func runProcessList() -> [ProcessRow] {
        guard let output = shell("/bin/ps", ["-axo", "pid=,ppid=,etime=,comm="]) else { return [] }
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]), let parentPID = Int32(parts[1]) else { return nil }
            let command = parts[3...].joined(separator: " ")
            let name = command.split(separator: "/").last.map(String.init) ?? command
            return ProcessRow(pid: pid, parentPID: parentPID, command: name,
                              startedAt: Date().addingTimeInterval(-parseElapsed(String(parts[2]))))
        }
    }

    /// `[[dd-]hh:]mm:ss` 형태의 etime 을 초로
    private static func parseElapsed(_ text: String) -> TimeInterval {
        var days = 0.0
        var rest = text
        if let dash = text.firstIndex(of: "-") {
            days = Double(text[text.startIndex..<dash]) ?? 0
            rest = String(text[text.index(after: dash)...])
        }
        // 뒤에서부터 초·분·시 — 자리 수가 몇 개든 같은 식으로 더한다
        let parts = rest.split(separator: ":").compactMap { Double($0) }.reversed()
        let seconds = parts.enumerated().reduce(0.0) { total, pair in
            total + pair.element * pow(60, Double(pair.offset))
        }
        return days * 86_400 + seconds
    }

    /// PID → 작업 폴더 이름. `lsof` 를 **한 번만** 부른다.
    private static func workingDirectories(of pids: [Int32]) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let joined = pids.map(String.init).joined(separator: ",")
        guard let output = shell("/usr/sbin/lsof", ["-a", "-d", "cwd", "-p", joined, "-Fpn"]) else { return [:] }

        var directories: [Int32: String] = [:]
        var currentPID: Int32?
        for line in output.split(separator: "\n") {
            if line.hasPrefix("p") {
                currentPID = Int32(line.dropFirst())
                continue
            }
            guard line.hasPrefix("n"), let pid = currentPID else { continue }
            let path = line.dropFirst()
            guard let last = path.split(separator: "/").last else { continue }
            directories[pid] = String(last)
        }
        return directories
    }

    static func shell(_ launchPath: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("\(launchPath) 실행 실패: \(error.localizedDescription)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // 명시적으로 닫지 않으면 읽기 쪽 디스크립터가 쌓인다
        try? pipe.fileHandleForReading.close()
        // pmset 로그에는 UTF-8 이 아닌 바이트가 섞인다. 엄격하게 디코딩하면 통째로 nil 이 된다
        return String(decoding: data, as: UTF8.self)
    }
}

/// 전원 상태가 바뀔 때만 깨어난다 — 폴링 없음(G1).
final class PowerWatcher {
    private var source: CFRunLoopSource?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let watcher = Unmanaged<PowerWatcher>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { watcher.onChange() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        self.source = source
    }

    deinit {
        guard let source else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
    }
}
