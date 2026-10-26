import AppKit
import Combine
import SwiftUI

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // 독에 안 뜬다
        app.run()
    }
}

/**
 메뉴바 항목과 메뉴를 직접 만든다.

 SwiftUI `MenuBarExtra` 가 아니라 `NSStatusItem` 을 쓰는 이유는 `menuWillOpen` 이다 —
 메뉴가 열리는 순간을 알아야 뚜껑 설정·세션 목록을 그때만 읽을 수 있다 (케이스 7·14, G1).
 */
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let fadeDuration = 0.12

    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var stateObserver: AnyCancellable?
    private var isFading = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        stateObserver = state.objectWillChange.sink { [weak self] _ in
            // objectWillChange 는 변경 전에 오므로 한 틱 미뤄 바뀐 값을 읽는다
            Task { @MainActor in self?.updateStatusItem() }
        }
        updateStatusItem()

        if ProcessInfo.processInfo.environment["DWT_SELFTEST"] != nil {
            state.runNotificationSelfTest()
        }
    }

    // MARK: 메뉴바 아이콘

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let icon = MenuBarIcon.image(for: state.state, isLidWarningOn: state.isLidSettingOn)

        // 아이콘 모양이 바뀔 때만 페이드한다 — 경과 시간이 바뀌는 것으로는 깜빡이지 않는다
        let didShapeChange = button.image !== icon
        guard didShapeChange, !isFading, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            apply(icon, to: button)
            return
        }

        isFading = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            button.animator().alphaValue = 0.15
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.apply(icon, to: button)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Self.fadeDuration
                    button.animator().alphaValue = 1
                } completionHandler: {
                    Task { @MainActor in self.isFading = false }
                }
            }
        }
    }

    private func apply(_ icon: NSImage, to button: NSStatusBarButton) {
        button.image = icon
        button.imagePosition = state.elapsedText == nil ? .imageOnly : .imageLeading
        button.title = state.elapsedText.map { " \($0)" } ?? ""
        button.setAccessibilityLabel(MenuBarIcon.accessibilityLabel(for: state.state,
                                                                    isLidWarningOn: state.isLidSettingOn,
                                                                    elapsed: state.elapsedText))
    }

    // MARK: 메뉴

    func menuWillOpen(_ menu: NSMenu) {
        state.refreshForMenuOpen()
        rebuild(menu)
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(disabledItem(state.statusText))
        if let note = state.sleptWhileAwayNote {
            menu.addItem(disabledItem("⚠︎ \(note)"))
        }
        if let warning = state.warning {
            menu.addItem(disabledItem("⚠︎ \(warning)"))
        }

        menu.addItem(.separator())

        // 가장 자주 쓸 동작이라 맨 위에 둔다
        let leaveItem = actionItem("불 끄고 본다", action: #selector(handleLeaveNow))
        leaveItem.toolTip = "화면을 바로 끄고, 안 걸려 있으면 '끌 때까지' 로 켠다. 세션은 계속 돈다."
        menu.addItem(leaveItem)

        menu.addItem(.separator())

        // 다섯 항목이 한 질문의 답이라는 걸 제목으로 보인다
        menu.addItem(.sectionHeader(title: "언제까지 안 자나"))
        menu.addItem(modeItem("계속 본다", mode: .indefinite))
        for seconds in AppState.durationChoices {
            menu.addItem(modeItem(KeepAwakeMode.durationTitle(seconds), mode: .duration(seconds)))
        }
        menu.addItem(sessionItem())

        menu.addItem(.separator())

        // 둘 다 "체크 = 이 문장이 사실" 로 읽히는 안전장치다
        let batteryItem = checkItem("배터리 \(AppState.batteryThreshold)% 되면 잔다",
                                    isOn: state.releasesOnLowBattery,
                                    action: #selector(handleBatteryToggle))
        batteryItem.toolTip = "충전기가 빠진 채 배터리가 \(AppState.batteryThreshold)% 아래로 내려가면 유지를 스스로 푼다."
        menu.addItem(batteryItem)

        let lidItem = checkItem("뚜껑 닫아도 안 잔다…",
                                isOn: state.isLidSettingOn,
                                action: #selector(handleLidClick))
        lidItem.toolTip = "맥 시스템 설정이다. 누르면 안내 창이 열리고, 바꿀 때 macOS 가 암호를 묻는다."
        menu.addItem(lidItem)

        let loginItem = checkItem("로그인할 때 자동 실행",
                                  isOn: state.isLoginItemEnabled,
                                  action: #selector(handleLoginItemToggle))
        loginItem.toolTip = "시스템 설정 ▸ 일반 ▸ 로그인 항목에서도 보인다."
        menu.addItem(loginItem)

        menu.addItem(elapsedDisplayItem())

        menu.addItem(.separator())

        if state.caffeinate.isRunning {
            menu.addItem(actionItem("이제 잔다", action: #selector(handleStop)))
        }
        menu.addItem(actionItem("리모콘 설명서…", action: #selector(handleHelpClick)))

        let quit = actionItem("종료", action: #selector(handleQuit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    /// 세션 수에 따라 모양이 셋이다 — 없음·하나(자동 선택)·여럿(서브메뉴)
    private func sessionItem() -> NSMenuItem {
        guard !state.sessions.isEmpty else {
            return disabledItem("이것만 보고 잘게 (볼 게 없다)")
        }
        if state.sessions.count == 1, let only = state.recentSessions.first {
            return modeItem("이것만 보고 잘게 (\(only.name))",
                            mode: .session(pid: only.pid, name: only.name))
        }

        let parent = NSMenuItem(title: "이것만 보고 잘게", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for session in state.recentSessions {
            submenu.addItem(modeItem(state.menuLabel(for: session),
                                     mode: .session(pid: session.pid, name: session.name)))
        }
        if !state.olderSessions.isEmpty {
            submenu.addItem(.separator())
            let all = NSMenuItem(title: "모두 보기…", action: nil, keyEquivalent: "")
            let allMenu = NSMenu()
            for session in state.olderSessions {
                allMenu.addItem(modeItem(state.menuLabel(for: session),
                                         mode: .session(pid: session.pid, name: session.name)))
            }
            all.submenu = allMenu
            submenu.addItem(all)
        }
        parent.submenu = submenu
        return parent
    }

    /// 메뉴바 숫자를 어떻게 보일지. 메뉴 안 상태 줄은 이 설정과 무관하게 늘 초까지 보인다 (B2).
    private func elapsedDisplayItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "메뉴바 경과 시간", action: nil, keyEquivalent: "")
        parent.toolTip = "메뉴 안에서는 설정과 상관없이 늘 초까지 보인다."
        let submenu = NSMenu()
        for display in ElapsedDisplay.allCases {
            let item = actionItem(display.menuTitle, action: #selector(handleElapsedDisplayClick(_:)))
            item.state = state.elapsedDisplay == display ? .on : .off
            item.representedObject = display
            submenu.addItem(item)
        }
        parent.submenu = submenu
        return parent
    }

    // MARK: 항목 만들기

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func checkItem(_ title: String, isOn: Bool, action: Selector) -> NSMenuItem {
        let item = actionItem(title, action: action)
        item.state = isOn ? .on : .off
        return item
    }

    private func modeItem(_ title: String, mode: KeepAwakeMode) -> NSMenuItem {
        let item = actionItem(title, action: #selector(handleModeClick(_:)))
        item.state = state.isSelected(mode) ? .on : .off
        item.representedObject = mode
        return item
    }

    // MARK: 액션

    @objc private func handleModeClick(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? KeepAwakeMode else { return }
        // 켜져 있는 것을 다시 누르면 해제다
        if state.isSelected(mode) {
            state.stopByUser()
            return
        }
        state.start(mode: mode)
    }

    @objc private func handleElapsedDisplayClick(_ sender: NSMenuItem) {
        guard let display = sender.representedObject as? ElapsedDisplay else { return }
        state.elapsedDisplay = display
    }

    @objc private func handleLoginItemToggle() { state.toggleLoginItem() }
    @objc private func handleLeaveNow() { state.leaveNow() }
    @objc private func handleBatteryToggle() { state.releasesOnLowBattery.toggle() }
    @objc private func handleLidClick() { LidWindow.shared.show(state: state) }
    @objc private func handleStop() { state.stopByUser() }
    @objc private func handleHelpClick() { HelpWindow.shared.show() }
    @objc private func handleQuit() { NSApp.terminate(nil) }
}

/**
 안내 창. 다시 앞으로 올 때마다 `ioreg` 를 읽는다 —
 사용자가 터미널에서 직접 명령을 치고 돌아와도 맞는 값이 보여야 한다.
 */
@MainActor
final class LidWindow: NSObject, NSWindowDelegate {
    static let shared = LidWindow()
    private var window: NSWindow?
    private var state: AppState?

    func show(state: AppState) {
        self.state = state
        state.refreshLidSetting()

        let target = window ?? makeWindow()
        window = target
        if target.contentViewController == nil {
            target.contentViewController = NSHostingController(rootView: LidGuideView(state: state))
        }
        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        state?.refreshLidSetting()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "뚜껑 닫아도 안 잔다"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}

/// 뚜껑 닫힘 설정 안내 — 지금 상태를 먼저 보이고, 바꾸는 건 macOS 가 암호를 받는다 (케이스 23).
struct LidGuideView: View {
    @ObservedObject var state: AppState

    private var isOn: Bool { state.isLidSettingOn }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: MenuBarIcon.image(for: .sleeping, isLidWarningOn: isOn, size: 34))
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isOn ? "켜짐" : "꺼짐")
                        .font(.title2.weight(.semibold))
                    Text(isOn ? "노트북을 닫아도 맥이 종료되지 않습니다" : "노트북을 닫으면 맥이 종료됩니다")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isOn ? "되돌리기" : "켜기") { state.applyLidSetting(isOn: !isOn) }
                    .controlSize(.large)
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            if let error = state.lidError {
                Text("⚠︎ \(error)")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("뚜껑 닫힘은 앱이 막을 수 없는 잠이라 맥 설정을 직접 바꾼다. 그래서 누르면 macOS 가 암호를 묻는다 — 암호는 시스템이 받고 앱은 보지 못한다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("터미널에서 직접 하기") {
                VStack(alignment: .leading, spacing: 10) {
                    CommandRow(label: "켜기", command: LidSleepSetting.enableCommand)
                    CommandRow(label: "되돌리기", command: LidSleepSetting.disableCommand)
                }
                .padding(.top, 8)
            }
            .font(.footnote)
        }
        .padding(20)
        .frame(width: 440)
    }
}

private struct CommandRow: View {
    let label: String
    let command: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button("복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
                .controlSize(.small)
                .accessibilityLabel("\(label) 명령 복사")
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityElement(children: .contain)
    }
}
