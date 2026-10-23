import AppKit

/// 앱 상태 — 뚜껑 닫힘 설정과 직교한다.
enum AwakeState: Hashable {
    case sleeping       // 잔다
    case awake          // 안 잔다
    case keepingSession // 세션 지키는 중
}

private let stateNames: [AwakeState: String] = [
    .sleeping: "잔다",
    .awake: "안 잔다",
    .keepingSession: "세션 지키는 중",
]

/**
 메뉴바 아이콘. 확정 SVG(`dads-watching-icon-studio`)의 좌표를 그대로 쓴다.
 template image 로 만들어 색은 macOS 가 칠하게 둔다 — 구분은 형태로만 한다.
 */
enum MenuBarIcon {
    private static let viewBox: CGFloat = 24
    private static let pointSize: CGFloat = 18
    private static let strokeWidth: CGFloat = 1.6

    /// 윤곽: 바깥 테와 안쪽 테를 evenodd 로 겹쳐 링을 만든다
    static let bodyOutlineData = """
    M7.5 3.6H10.5Q14.3 3.6 14.1 6.6L12.6 17.6Q12.4 20.4 9.8 20.4H8.2Q5.6 20.4 5.4 17.6L3.9 6.6Q3.7 3.6 7.5 3.6Z \
    M7.5 5.2H10.5Q12.6 5.2 12.5 6.6L11 17.5Q10.9 18.8 9.8 18.8H8.2Q7.1 18.8 7 17.5L5.5 6.6Q5.4 5.2 7.5 5.2Z
    """

    /// 채움: 본체와 버튼을 한 path 로 합쳐 evenodd 로 구멍을 뚫는다
    static let bodyFilledData = """
    M7.5 3.6H10.5Q14.3 3.6 14.1 6.6L12.6 17.6Q12.4 20.4 9.8 20.4H8.2Q5.6 20.4 5.4 17.6L3.9 6.6Q3.7 3.6 7.5 3.6Z \
    M8.2 6.2H9.8V8.8H8.2Z M7 7.4C5.4 9.6 6.8 12 9 12C11.2 12 12.6 9.6 11 7.4L10.1 8.7C10.9 9.8 9.9 10.4 9 10.4C8.1 10.4 7.1 9.8 7.9 8.7ZM8.2 13.8H9.8A.8 .8 0 0 1 9.8 15.4H8.2A.8 .8 0 0 1 8.2 13.8Z
    """

    /// 전원 기호와 버튼 — 윤곽 버전에서는 채워서 그린다
    static let controlsData = """
    M8.2 6.2H9.8V8.8H8.2Z M7 7.4C5.4 9.6 6.8 12 9 12C11.2 12 12.6 9.6 11 7.4L10.1 8.7C10.9 9.8 9.9 10.4 9 10.4C8.1 10.4 7.1 9.8 7.9 8.7ZM8.2 13.8H9.8A.8 .8 0 0 1 9.8 15.4H8.2A.8 .8 0 0 1 8.2 13.8Z
    """

    static let wavesData = "M15.7 8.6Q18 10.9 15.7 13.2M18.4 6.4Q22.3 10.9 18.4 15.4"
    private static let warningBorderRect = NSRect(x: 1, y: 1, width: 22, height: 22)
    private static let warningBorderRadius: CGFloat = 5

    private static var cache: [String: NSImage] = [:]

    static func image(for state: AwakeState, isLidWarningOn: Bool, size: CGFloat = pointSize) -> NSImage {
        let key = "\(state)-\(isLidWarningOn)-\(size)"
        if let cached = cache[key] { return cached }

        let scale = size / viewBox
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let context = NSGraphicsContext.current else { return false }
            context.cgContext.scaleBy(x: scale, y: scale)
            NSColor.black.setFill()
            NSColor.black.setStroke()

            if state == .keepingSession {
                SVGPath.bezierPath(from: bodyFilledData).fill()
            } else {
                SVGPath.bezierPath(from: bodyOutlineData).fill()
                SVGPath.bezierPath(from: controlsData).fill()
            }

            if state != .sleeping {
                let waves = SVGPath.bezierPath(from: wavesData)
                waves.lineWidth = strokeWidth
                waves.lineCapStyle = .round
                waves.lineJoinStyle = .round
                waves.stroke()
            }

            if isLidWarningOn {
                let border = NSBezierPath(roundedRect: warningBorderRect,
                                          xRadius: warningBorderRadius,
                                          yRadius: warningBorderRadius)
                border.lineWidth = strokeWidth
                border.stroke()
            }
            return true
        }
        image.isTemplate = true
        cache[key] = image
        return image
    }

    /// VoiceOver 가 읽을 문장 — 아이콘이 메뉴바에서 접혀도 상태는 들린다
    static func accessibilityLabel(for state: AwakeState, isLidWarningOn: Bool, elapsed: String?) -> String {
        var sentence = stateNames[state] ?? ""
        if let elapsed { sentence += ", \(elapsed) 경과" }
        if isLidWarningOn { sentence += ", 뚜껑 닫힘 설정 켜짐" }
        return sentence
    }
}
