import AppKit

/**
 확정 아이콘 SVG 의 `d` 속성을 NSBezierPath 로 옮긴다.
 에셋 번들 없이 코드에서 그리기 위한 최소 파서 — M L H V C Q S T A Z 를 지원한다.
 좌표계는 SVG 그대로(y 아래쪽 증가)이므로 flipped 컨텍스트에 그린다.
 */
enum SVGPath {
    static func bezierPath(from d: String, flatness: CGFloat = 0.2) -> NSBezierPath {
        var parser = Parser(d: d)
        return parser.run(flatness: flatness)
    }

    private struct Parser {
        let tokens: [Token]
        var index = 0
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?
        var lastCommand: Character = " "

        enum Token {
            case command(Character)
            case number(CGFloat)
        }

        init(d: String) {
            var tokens: [Token] = []
            var numberBuffer = ""
            func flushNumber() {
                if let value = Double(numberBuffer) {
                    tokens.append(.number(CGFloat(value)))
                }
                numberBuffer = ""
            }
            for character in d {
                switch character {
                case "A"..."Z", "a"..."z":
                    flushNumber()
                    tokens.append(.command(character))
                case "-":
                    // 지수 표기의 부호가 아니면 새 숫자의 시작이다
                    if numberBuffer.isEmpty || numberBuffer.hasSuffix("e") || numberBuffer.hasSuffix("E") {
                        numberBuffer.append(character)
                    } else {
                        flushNumber()
                        numberBuffer.append(character)
                    }
                case ".":
                    if numberBuffer.contains(".") {
                        flushNumber()
                    }
                    numberBuffer.append(character)
                case "0"..."9", "e", "E", "+":
                    numberBuffer.append(character)
                default:
                    flushNumber()
                }
            }
            flushNumber()
            self.tokens = tokens
        }

        mutating func run(flatness: CGFloat) -> NSBezierPath {
            let path = NSBezierPath()
            path.flatness = flatness
            path.windingRule = .evenOdd

            while index < tokens.count {
                guard case let .command(rawCommand) = tokens[index] else {
                    // 암묵적 반복: 직전 명령을 이어 쓴다
                    appendSegment(lastCommand == "M" ? "L" : lastCommand, to: path)
                    continue
                }
                index += 1
                if rawCommand == "Z" || rawCommand == "z" {
                    path.close()
                    current = subpathStart
                    lastCommand = rawCommand
                    continue
                }
                appendSegment(rawCommand, to: path)
            }
            return path
        }

        mutating func nextNumber() -> CGFloat {
            while index < tokens.count {
                defer { index += 1 }
                if case let .number(value) = tokens[index] { return value }
            }
            return 0
        }

        mutating func appendSegment(_ command: Character, to path: NSBezierPath) {
            let isRelative = command.isLowercase
            let base = isRelative ? current : .zero

            switch Character(command.uppercased()) {
            case "M":
                let point = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                path.move(to: point)
                current = point
                subpathStart = point
            case "L":
                let point = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                path.line(to: point)
                current = point
            case "H":
                let point = CGPoint(x: base.x + nextNumber(), y: current.y)
                path.line(to: point)
                current = point
            case "V":
                let point = CGPoint(x: current.x, y: base.y + nextNumber())
                path.line(to: point)
                current = point
            case "C":
                let control1 = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                let control2 = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                let end = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
                current = end
                lastControl = control2
            case "Q":
                let control = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                let end = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                appendQuadratic(control: control, end: end, to: path)
            case "T":
                let control = mirroredControl()
                let end = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                appendQuadratic(control: control, end: end, to: path)
            case "S":
                let control1 = mirroredControl()
                let control2 = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                let end = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
                current = end
                lastControl = control2
            case "A":
                let radiusX = nextNumber()
                let radiusY = nextNumber()
                let rotation = nextNumber()
                let isLargeArc = nextNumber() != 0
                let isSweep = nextNumber() != 0
                let end = CGPoint(x: base.x + nextNumber(), y: base.y + nextNumber())
                appendArc(radiusX: radiusX, radiusY: radiusY, rotation: rotation,
                          isLargeArc: isLargeArc, isSweep: isSweep, end: end, to: path)
            default:
                break
            }
            lastCommand = command
        }

        mutating func appendQuadratic(control: CGPoint, end: CGPoint, to path: NSBezierPath) {
            // 2차 → 3차 베지어 승격
            let control1 = CGPoint(x: current.x + 2.0 / 3.0 * (control.x - current.x),
                                   y: current.y + 2.0 / 3.0 * (control.y - current.y))
            let control2 = CGPoint(x: end.x + 2.0 / 3.0 * (control.x - end.x),
                                   y: end.y + 2.0 / 3.0 * (control.y - end.y))
            path.curve(to: end, controlPoint1: control1, controlPoint2: control2)
            current = end
            lastControl = control
        }

        func mirroredControl() -> CGPoint {
            guard let lastControl else { return current }
            return CGPoint(x: 2 * current.x - lastControl.x, y: 2 * current.y - lastControl.y)
        }

        /// SVG 호(endpoint 표기)를 중심 표기로 바꿔 베지어 조각으로 잇는다.
        mutating func appendArc(radiusX: CGFloat, radiusY: CGFloat, rotation: CGFloat,
                                isLargeArc: Bool, isSweep: Bool, end: CGPoint, to path: NSBezierPath) {
            let start = current
            guard radiusX != 0, radiusY != 0, start != end else {
                path.line(to: end)
                current = end
                return
            }
            var rx = abs(radiusX)
            var ry = abs(radiusY)
            let angle = rotation * .pi / 180
            let cosAngle = cos(angle)
            let sinAngle = sin(angle)

            let dx2 = (start.x - end.x) / 2
            let dy2 = (start.y - end.y) / 2
            let x1 = cosAngle * dx2 + sinAngle * dy2
            let y1 = -sinAngle * dx2 + cosAngle * dy2

            let scale = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
            if scale > 1 {
                rx *= sqrt(scale)
                ry *= sqrt(scale)
            }

            let sign: CGFloat = isLargeArc == isSweep ? -1 : 1
            let numerator = max(0, rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1)
            let denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1
            let coefficient = sign * sqrt(numerator / max(denominator, .leastNonzeroMagnitude))
            let cx1 = coefficient * rx * y1 / ry
            let cy1 = -coefficient * ry * x1 / rx

            let centerX = cosAngle * cx1 - sinAngle * cy1 + (start.x + end.x) / 2
            let centerY = sinAngle * cx1 + cosAngle * cy1 + (start.y + end.y) / 2

            func angleBetween(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
                let dot = ux * vx + uy * vy
                let length = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
                var value = acos(min(1, max(-1, dot / max(length, .leastNonzeroMagnitude))))
                if ux * vy - uy * vx < 0 { value = -value }
                return value
            }

            let startAngle = angleBetween(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
            var sweepAngle = angleBetween((x1 - cx1) / rx, (y1 - cy1) / ry,
                                          (-x1 - cx1) / rx, (-y1 - cy1) / ry)
            if !isSweep && sweepAngle > 0 { sweepAngle -= 2 * .pi }
            if isSweep && sweepAngle < 0 { sweepAngle += 2 * .pi }

            let segmentCount = max(1, Int(ceil(abs(sweepAngle) / (.pi / 2))))
            let segmentAngle = sweepAngle / CGFloat(segmentCount)
            let alpha = 4.0 / 3.0 * tan(segmentAngle / 4)

            var theta = startAngle
            var point = start
            for _ in 0..<segmentCount {
                let nextTheta = theta + segmentAngle
                func onEllipse(_ t: CGFloat) -> CGPoint {
                    let ex = rx * cos(t)
                    let ey = ry * sin(t)
                    return CGPoint(x: cosAngle * ex - sinAngle * ey + centerX,
                                   y: sinAngle * ex + cosAngle * ey + centerY)
                }
                func tangent(_ t: CGFloat) -> CGPoint {
                    let ex = -rx * sin(t)
                    let ey = ry * cos(t)
                    return CGPoint(x: cosAngle * ex - sinAngle * ey,
                                   y: sinAngle * ex + cosAngle * ey)
                }
                let nextPoint = onEllipse(nextTheta)
                let startTangent = tangent(theta)
                let endTangent = tangent(nextTheta)
                let control1 = CGPoint(x: point.x + alpha * startTangent.x, y: point.y + alpha * startTangent.y)
                let control2 = CGPoint(x: nextPoint.x - alpha * endTangent.x, y: nextPoint.y - alpha * endTangent.y)
                path.curve(to: nextPoint, controlPoint1: control1, controlPoint2: control2)
                point = nextPoint
                theta = nextTheta
            }
            current = end
        }
    }
}
