import AppKit

// Gera os PNGs do ícone do Uptend num .iconset (depois vira .icns via iconutil).
// Marca: linha de tendência para cima (up-trend) branca sobre gradiente azul→teal.

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Uptend.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func makeImage(_ size: CGFloat) -> CGImage {
    let pixels = Int(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    let margin = size * 0.098
    let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = size * 0.205

    // Fundo (squircle) com gradiente.
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    let colors = [CGColor(colorSpace: cs, components: [0.30, 0.42, 0.95, 1])!,
                  CGColor(colorSpace: cs, components: [0.12, 0.78, 0.70, 1])!] as CFArray
    let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    ctx.restoreGState()

    // Linha de tendência para cima + seta.
    func pt(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * nx, y: rect.minY + rect.height * ny)
    }
    let pts = [pt(0.22, 0.40), pt(0.42, 0.52), pt(0.56, 0.44), pt(0.78, 0.66)]

    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(size * 0.062)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.beginPath()
    ctx.move(to: pts[0])
    for point in pts.dropFirst() { ctx.addLine(to: point) }
    ctx.strokePath()

    // Ponta da seta no último ponto.
    let tip = pts[3], prev = pts[2]
    let angle = atan2(tip.y - prev.y, tip.x - prev.x)
    let len = size * 0.14
    let a1 = angle + .pi * 0.82, a2 = angle - .pi * 0.82
    ctx.beginPath()
    ctx.move(to: CGPoint(x: tip.x + cos(a1) * len, y: tip.y + sin(a1) * len))
    ctx.addLine(to: tip)
    ctx.addLine(to: CGPoint(x: tip.x + cos(a2) * len, y: tip.y + sin(a2) * len))
    ctx.strokePath()

    return ctx.makeImage()!
}

let targets: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

for (px, name) in targets {
    let image = makeImage(CGFloat(px))
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
print("Ícone gerado em \(outDir)")
