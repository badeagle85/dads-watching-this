import AppKit

/// `.iconset` 폴더에 애플이 요구하는 크기를 전부 떨어뜨린다. 변환은 iconutil 이 한다.
let output = CommandLine.arguments[1]
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
