import AppKit

/**
 앱 아이콘(.icns) 렌더러.

 메뉴바 아이콘과 달리 색을 쓴다. macOS 관례대로 1024 캔버스 안에 824 크기의
 둥근 사각형을 그리고(모서리 반지름 185.4), 그 위에 리모콘을 올린다.
 */
enum AppIcon {
    static let canvas: CGFloat = 1024
    static let body: CGFloat = 824
    static let radiusRatio: CGFloat = 185.4 / 824

    /// 확정안 — 남색 바탕에 흰 리모콘
    static let background = [NSColor(srgbRed: 0.16, green: 0.24, blue: 0.40, alpha: 1),
                             NSColor(srgbRed: 0.08, green: 0.13, blue: 0.25, alpha: 1)]
    static let foreground = NSColor.white

    /// 그림의 실제 경계는 24 좌표계에서 x 3.9~21.15 다. 그대로 중앙에 놓으면 오른쪽으로 쏠린다.
    private static let opticalShiftX: CGFloat = -0.525
    private static let artRatio: CGFloat = 0.64

    static func render(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let context = NSGraphicsContext.current else { return false }
            let scale = size / canvas
            context.cgContext.scaleBy(x: scale, y: scale)

            let inset = (canvas - body) / 2
            let shape = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: body, height: body),
                                     xRadius: body * radiusRatio,
                                     yRadius: body * radiusRatio)
            let gradient = NSGradient(colors: background)
            gradient?.draw(in: shape, angle: -90)

            // 리모콘은 24 좌표계로 그려져 있다
            let artSize = body * artRatio
            let artScale = artSize / 24
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: (canvas - artSize) / 2 + opticalShiftX * artScale,
                                          y: (canvas - artSize) / 2)
            context.cgContext.scaleBy(x: artScale, y: artScale)

            foreground.setFill()
            foreground.setStroke()
            SVGPath.bezierPath(from: MenuBarIcon.bodyOutlineData).fill()
            SVGPath.bezierPath(from: MenuBarIcon.controlsData).fill()
            let waves = SVGPath.bezierPath(from: MenuBarIcon.wavesData)
            waves.lineWidth = 1.6
            waves.lineCapStyle = .round
            waves.stroke()

            context.cgContext.restoreGState()
            return true
        }
        return image
    }

    static func writePNG(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
