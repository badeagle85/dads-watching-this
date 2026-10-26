import AppKit
import SwiftUI

/// 아이콘 읽는 법. 메뉴바 아이콘은 색을 못 쓰니(template image) 형태가 전부라 설명이 필요하다.
@MainActor
final class HelpWindow: NSObject {
    static let shared = HelpWindow()
    private var window: NSWindow?
    private var onCheckUpdate: (() -> Void)?

    func show(onCheckUpdate: @escaping () -> Void) {
        self.onCheckUpdate = onCheckUpdate
        let target = window ?? makeWindow()
        window = target
        NSApp.activate(ignoringOtherApps: true)
        target.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "리모콘 설명서"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: HelpView(onCheckUpdate: { [weak self] in self?.onCheckUpdate?() }))
        window.center()
        return window
    }
}

struct HelpView: View {
    let onCheckUpdate: () -> Void

    private static let iconSize: CGFloat = 26

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("모양이 상태다") {
                    row(.sleeping, border: false, title: "잔다",
                        detail: "아무것도 안 걸렸다. 맥은 평소대로 잠든다.")
                    row(.awake, border: false, title: "안 잔다",
                        detail: "깨워 두는 중이다. 파동이 붙는다.")
                    row(.keepingSession, border: false, title: "보는 중",
                        detail: "고른 세션이 끝나면 저절로 풀린다. 속이 꽉 찬다.")
                }

                section("테두리는 시스템 설정이다") {
                    row(.sleeping, border: true, title: "뚜껑 닫아도 안 잔다",
                        detail: "앱과 따로 논다. 앱을 꺼도, 재부팅해도 남는다. 세 모양 어디에나 붙을 수 있다.")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("둘은 막는 범위가 다르다")
                            .font(.callout.weight(.semibold))
                        rangeRow("뚜껑 닫아도 안 잔다", "맥의 모든 잠을 막는다 — 가만둬도, 뚜껑을 닫아도 안 잔다")
                        rangeRow("앱의 유지 모드", "가만둘 때의 잠만 막는다. 뚜껑을 닫으면 잔다")
                        Text("그래서 테두리가 있는 동안은 유지 모드를 안 걸어도 맥이 안 잔다. 테두리를 끄면 다시 필요해진다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                section("아이콘 옆 숫자") {
                    VStack(alignment: .leading, spacing: 6) {
                        detailRow("0:03", "켜 둔 지 3분")
                        detailRow("0:03:12", "`시:분:초` 로 바꾼 경우")
                        detailRow("없음", "`숨김` 으로 뒀거나 안 걸린 상태")
                    }
                    Text("메뉴를 열면 설정과 상관없이 늘 초까지 보인다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("메뉴바에서 아이콘이 안 보이면 오른쪽 끝 `»` 안에 접혀 있다. 메뉴바가 좁으면 macOS 가 뒤쪽부터 숨긴다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

            }
            .padding(24)
        }
        .frame(width: 460)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("아빠안잔다 \(version)")
                            .font(.callout.weight(.medium))
                            .textSelection(.enabled)
                        Text("새 버전은 하루 한 번 알아서 확인한다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("업데이트 확인", action: onCheckUpdate)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(.bar)
        }
        .frame(height: 520)
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func row(_ state: AwakeState, border: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: MenuBarIcon.image(for: state, isLidWarningOn: border, size: Self.iconSize))
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func rangeRow(_ name: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.callout.weight(.medium))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detailRow(_ sample: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(sample)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 64, alignment: .leading)
            Text(meaning)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
