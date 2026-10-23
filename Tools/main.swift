import AppKit

/// `iconset <폴더>` → .icns 용 PNG 모음 · `readme <폴더>` → README 에 넣을 이미지
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "iconset"
let output = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "."

if mode == "iconset" {
    let sizes: [(name: String, pixels: CGFloat)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]
    for (name, pixels) in sizes {
        AppIcon.writePNG(AppIcon.render(size: pixels), to: "\(output)/\(name).png")
    }
    print("\(sizes.count)개 생성")
} else {
    AppIcon.writePNG(AppIcon.render(size: 512), to: "\(output)/app-icon.png")

    let states: [(String, AwakeState, Bool)] = [
        ("state-sleeping", .sleeping, false),
        ("state-awake", .awake, false),
        ("state-session", .keepingSession, false),
        ("state-lid", .sleeping, true),
    ]
    for (name, state, border) in states {
        AppIcon.writePNG(StateTile.render(state: state, border: border), to: "\(output)/\(name).png")
    }
    print("README 이미지 \(states.count + 1)개 생성")
}
