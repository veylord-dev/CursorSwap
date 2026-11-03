// Рисует иконку приложения: swift Tools/make_icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

// Форма стрелки в сетке 32×32 — та же, что у встроенных курсоров.
func arrowPath(origin: NSPoint, scale k: CGFloat) -> NSBezierPath {
    let pts: [(CGFloat, CGFloat)] = [(3, 2), (3, 26), (8.6, 20.6), (12.4, 29.4), (16.4, 27.7), (12.7, 19.2), (20.4, 19.2)]
    let p = NSBezierPath()
    p.move(to: NSPoint(x: origin.x + pts[0].0 * k, y: origin.y + pts[0].1 * k))
    for pt in pts.dropFirst() { p.line(to: NSPoint(x: origin.x + pt.0 * k, y: origin.y + pt.1 * k)) }
    p.close()
    p.lineJoinStyle = .round
    return p
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)
    // Рисуем в координатах сверху вниз.
    ctx.translateBy(x: 0, y: 1024)
    ctx.scaleBy(x: 1, y: -1)

    // Фон: скруглённый квадрат по сетке macOS (824pt с отступом 100), фиолетово-розовый градиент.
    let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGradient(colors: [NSColor(srgbRed: 0.36, green: 0.22, blue: 0.95, alpha: 1),
                        NSColor(srgbRed: 0.85, green: 0.25, blue: 0.75, alpha: 1),
                        NSColor(srgbRed: 1.0, green: 0.48, blue: 0.4, alpha: 1)])!
        .draw(in: bg, angle: -60)

    // Задняя «старая» стрелка — полупрозрачный контур.
    let k: CGFloat = 17
    let back = arrowPath(origin: NSPoint(x: 215, y: 175), scale: k)
    back.lineWidth = 26
    NSColor.white.withAlphaComponent(0.4).setStroke()
    back.stroke()

    // Передняя «новая» стрелка — жёлтая с тёмным контуром и тенью.
    let front = arrowPath(origin: NSPoint(x: 360, y: 285), scale: k)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 24), blur: 40, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor(srgbRed: 1, green: 0.85, blue: 0.15, alpha: 1).setFill()
    front.fill()
    ctx.restoreGState()
    front.lineWidth = 28
    NSColor(srgbRed: 0.12, green: 0.06, blue: 0.25, alpha: 1).setStroke()
    front.stroke()

    // Искра — намёк на «волшебную» подмену.
    func sparkle(_ c: NSPoint, _ r: CGFloat) {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: c.x, y: c.y - r))
        p.curve(to: NSPoint(x: c.x + r, y: c.y), controlPoint1: NSPoint(x: c.x + r * 0.12, y: c.y - r * 0.12), controlPoint2: NSPoint(x: c.x + r * 0.12, y: c.y - r * 0.12))
        p.curve(to: NSPoint(x: c.x, y: c.y + r), controlPoint1: NSPoint(x: c.x + r * 0.12, y: c.y + r * 0.12), controlPoint2: NSPoint(x: c.x + r * 0.12, y: c.y + r * 0.12))
        p.curve(to: NSPoint(x: c.x - r, y: c.y), controlPoint1: NSPoint(x: c.x - r * 0.12, y: c.y + r * 0.12), controlPoint2: NSPoint(x: c.x - r * 0.12, y: c.y + r * 0.12))
        p.curve(to: NSPoint(x: c.x, y: c.y - r), controlPoint1: NSPoint(x: c.x - r * 0.12, y: c.y - r * 0.12), controlPoint2: NSPoint(x: c.x - r * 0.12, y: c.y - r * 0.12))
        NSColor.white.setFill()
        p.fill()
    }
    sparkle(NSPoint(x: 720, y: 270), 80)
    sparkle(NSPoint(x: 800, y: 400), 38)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size)@2x.png"))
}
