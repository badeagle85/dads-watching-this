import AppKit
import Sparkle

/**
 자동 업데이트.

 공증을 안 받았으므로 Apple 서명 대신 **EdDSA 키**로 무결성을 확인한다.
 Sparkle 이 내려받은 앱의 격리 표시를 직접 떼므로, 사용자는 처음 설치할 때만
 `xattr` 을 치면 된다.
 */
@MainActor
final class Updater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var availableVersion: String?

    private var controller: SPUStandardUpdaterController?

    /// 메뉴에서 보여줄 한 줄. 새 버전이 없으면 nil.
    var noticeText: String? {
        availableVersion.map { "새 버전 \($0) 이 나왔다" }
    }

    override init() {
        super.init()
        // startingUpdater: 앱이 뜨면 바로 배경에서 확인한다 (하루 1회)
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: self,
                                                  userDriverDelegate: nil)
    }

    /// 메뉴의 `새 거 있나 보자` 에서 부른다 — 사용자가 직접 확인
    func checkNow() {
        controller?.updater.checkForUpdates()
    }

    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            availableVersion = item.displayVersionString
        }
    }

    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            availableVersion = nil
        }
    }
}
