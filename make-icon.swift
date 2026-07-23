import AppKit

// Gera os PNGs do ícone do Uptend num .iconset (depois vira .icns via iconutil).
// Marca: martelo (SF Symbol) sobre um squircle azul.

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Uptend.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func symbolImage(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return NSImage() }
    let out = NSImage(size: base.size)
    out.lockFocus()
    base.draw(at: .zero, from: NSRect(origin: .zero, size: base.size), operation: .sourceOver, fraction: 1)
    color.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

func makePNG(_ size: CGFloat) -> Data? {
    let px = Int(size)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Fundo (squircle) com gradiente azul.
    let margin = size * 0.098
    let rect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = size * 0.205
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.24, green: 0.54, blue: 0.98, alpha: 1),
        NSColor(red: 0.14, green: 0.40, blue: 0.92, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -90)

    // Martelo, em tom escuro (como na referência).
    let hammer = symbolImage("hammer.fill", pointSize: size * 0.46,
                             color: NSColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1))
    let hs = hammer.size
    let drawRect = NSRect(x: (size - hs.width) / 2, y: (size - hs.height) / 2, width: hs.width, height: hs.height)
    hammer.draw(in: drawRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let targets: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (px, name) in targets {
    guard let data = makePNG(CGFloat(px)) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Ícone gerado em \(outDir)")
