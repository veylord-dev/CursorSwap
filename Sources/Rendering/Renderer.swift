import AppKit
import ImageIO

// MARK: - Rendering
// Всё, что превращается в картинки для WindowServer: нарисованные пресеты, свои файлы, курсоры Windows.
// Каждый курсор отдаётся в трёх масштабах (1x, 2x, 4x), кадры анимации — вертикальной лентой.

struct RenderedCursor {
    var images: [CGImage]
    var size: CGSize
    var hotspot: CGPoint
    var frames = 1
    var frameDuration: CGFloat = 0

    /// Первый кадр в самом крупном масштабе — для превью в меню и галерее.
    var preview: NSImage? {
        guard let big = images.last else { return nil }
        let frameHeight = big.height / max(frames, 1)
        guard let first = big.cropping(to: CGRect(x: 0, y: 0, width: big.width, height: frameHeight)) else { return nil }
        return NSImage(cgImage: first, size: size)
    }
}

enum Renderer {
    static let scales: [CGFloat] = [1, 2, 4]
    /// Ограничение WindowServer на число кадров анимации.
    static let maxFrames = 24

    /// Рисует в пунктах, начало координат — левый верхний угол.
    static func bitmap(size: CGSize, scale: CGFloat, frames: Int = 1, draw: (CGContext, Int) -> Void) -> CGImage? {
        let w = Int((size.width * scale).rounded()), h = Int((size.height * scale).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h * frames, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        for frame in 0..<frames {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: CGFloat(h * (frames - frame)))
            ctx.scaleBy(x: scale, y: -scale)
            draw(ctx, frame)
            ctx.restoreGState()
        }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    static func render(_ preset: Preset, size s: CGFloat) -> RenderedCursor {
        let box = CGSize(width: s, height: s)
        let images = scales.compactMap { bitmap(size: box, scale: $0) { ctx, _ in draw(preset, side: s, in: ctx) } }
        let u = s / 32
        return RenderedCursor(images: images, size: box, hotspot: CGPoint(x: preset.hotspot.x * u, y: preset.hotspot.y * u))
    }

    /// Все фигуры заданы в сетке 32×32 и масштабируются под нужный размер.
    static func draw(_ preset: Preset, side s: CGFloat, in ctx: CGContext) {
        let u = s / 32
        ctx.setShadow(offset: CGSize(width: 0, height: u), blur: 2 * u, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { ctx.endTransparencyLayer() }

        switch preset {
        case .windows(let shape, let dark):
            let fill: NSColor = dark ? .black : .white
            let line: NSColor = dark ? .white : .black
            switch shape {
            case .arrow:
                // Узкая длинная стрелка с прямым «хвостом», как в Windows.
                let p = NSBezierPath()
                let pts: [(CGFloat, CGFloat)] = [(3, 2), (3, 23.5), (8, 18.8), (11.3, 26.4), (14.2, 25.1), (11, 17.8), (17.6, 17.8)]
                p.move(to: NSPoint(x: pts[0].0 * u, y: pts[0].1 * u))
                for pt in pts.dropFirst() { p.line(to: NSPoint(x: pt.0 * u, y: pt.1 * u)) }
                p.close()
                p.lineJoinStyle = .miter
                p.lineWidth = 1.3 * u
                fill.setFill(); p.fill()
                line.setStroke(); p.stroke()

            case .hand:
                drawHand(unit: u, outline: line) { fill.setFill(); fill.setStroke(); $0() }

            case .beam:
                // Тонкий I-beam с короткими засечками и светлой подложкой для видимости на тёмном.
                let p = NSBezierPath()
                p.move(to: NSPoint(x: 16 * u, y: 6 * u)); p.line(to: NSPoint(x: 16 * u, y: 26 * u))
                p.move(to: NSPoint(x: 12.5 * u, y: 6 * u)); p.line(to: NSPoint(x: 19.5 * u, y: 6 * u))
                p.move(to: NSPoint(x: 12.5 * u, y: 26 * u)); p.line(to: NSPoint(x: 19.5 * u, y: 26 * u))
                p.lineCapStyle = .square
                p.lineWidth = 3.2 * u; fill.setStroke(); p.stroke()
                p.lineWidth = 1.3 * u; line.setStroke(); p.stroke()
            }

        case .aurora(let shape):
            // «Аврора» — фиолетово-коралловый градиент, как на иконке приложения.
            let ink = NSColor(srgbRed: 0.12, green: 0.06, blue: 0.25, alpha: 1)
            switch shape {
            case .arrow:
                let p = roundedPolygon([(5, 4, 0.8), (5, 23.5, 2.2), (10.6, 18.8, 1.6), (18.6, 18.2, 2.2)], unit: u)
                fillGradient(p, ctx: ctx, side: s)
                p.lineWidth = 1.6 * u
                NSColor.white.setStroke(); p.stroke()
            case .hand:
                drawHand(unit: u, outline: ink) { shapes in
                    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                    NSColor.white.setFill(); NSColor.white.setStroke(); shapes()
                    ctx.setBlendMode(.sourceIn)
                    Self.aurora.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -60)
                    ctx.endTransparencyLayer()
                }
            case .beam:
                let p = NSBezierPath(roundedRect: NSRect(x: 14.4 * u, y: 6.5 * u, width: 3.2 * u, height: 19 * u),
                                     xRadius: 1.6 * u, yRadius: 1.6 * u)
                p.lineWidth = 1.4 * u
                NSColor.white.setStroke(); p.stroke()
                fillGradient(p, ctx: ctx, side: s)
            }

        case .minimal(let tone):
            // Короткий указатель без «хвоста», со скруглёнными углами; кончик острее остальных.
            let p = roundedPolygon([(5, 4, 0.8), (5, 22.5, 2.2), (10.2, 18.2, 1.6), (17.8, 17.6, 2.2)], unit: u)
            p.lineWidth = 1.6 * u
            tone.fill.setFill(); p.fill()
            tone.outline.setStroke(); p.stroke()

        case .minimalBeam(let tone):
            // Тонкая капсула вместо классического I-beam с засечками.
            let p = NSBezierPath(roundedRect: NSRect(x: 14.6 * u, y: 7 * u, width: 2.8 * u, height: 18 * u),
                                 xRadius: 1.4 * u, yRadius: 1.4 * u)
            p.lineWidth = 1.4 * u
            tone.outline.setStroke(); p.stroke()
            tone.fill.setFill(); p.fill()

        case .arrow(let tint):
            let p = NSBezierPath()
            let pts: [(CGFloat, CGFloat)] = [(3, 2), (3, 26), (8.6, 20.6), (12.4, 29.4), (16.4, 27.7), (12.7, 19.2), (20.4, 19.2)]
            p.move(to: NSPoint(x: pts[0].0 * u, y: pts[0].1 * u))
            for pt in pts.dropFirst() { p.line(to: NSPoint(x: pt.0 * u, y: pt.1 * u)) }
            p.close()
            p.lineJoinStyle = .round
            p.lineWidth = 1.6 * u
            tint.fill.setFill(); p.fill()
            tint.outline.setStroke(); p.stroke()

        case .ibeam(let tint):
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 12 * u, y: 5 * u)); p.curve(to: NSPoint(x: 16 * u, y: 8 * u), controlPoint1: NSPoint(x: 15 * u, y: 5 * u), controlPoint2: NSPoint(x: 16 * u, y: 6 * u))
            p.curve(to: NSPoint(x: 20 * u, y: 5 * u), controlPoint1: NSPoint(x: 16 * u, y: 6 * u), controlPoint2: NSPoint(x: 17 * u, y: 5 * u))
            p.move(to: NSPoint(x: 16 * u, y: 8 * u)); p.line(to: NSPoint(x: 16 * u, y: 24 * u))
            p.move(to: NSPoint(x: 12 * u, y: 27 * u)); p.curve(to: NSPoint(x: 16 * u, y: 24 * u), controlPoint1: NSPoint(x: 15 * u, y: 27 * u), controlPoint2: NSPoint(x: 16 * u, y: 26 * u))
            p.curve(to: NSPoint(x: 20 * u, y: 27 * u), controlPoint1: NSPoint(x: 16 * u, y: 26 * u), controlPoint2: NSPoint(x: 17 * u, y: 27 * u))
            p.lineCapStyle = .round
            p.lineWidth = 4 * u; tint.outline.setStroke(); p.stroke()
            p.lineWidth = 2 * u; tint.fill.setStroke(); p.stroke()

        case .dot:
            let p = NSBezierPath(ovalIn: NSRect(x: 10 * u, y: 10 * u, width: 12 * u, height: 12 * u))
            p.lineWidth = 1.5 * u
            Tint.red.fill.setFill(); p.fill()
            NSColor.white.setStroke(); p.stroke()

        case .ring:
            let p = NSBezierPath(ovalIn: NSRect(x: 7 * u, y: 7 * u, width: 18 * u, height: 18 * u))
            p.lineWidth = 5 * u; NSColor.black.setStroke(); p.stroke()
            p.lineWidth = 3 * u; Tint.yellow.fill.setStroke(); p.stroke()
            let c = NSBezierPath(ovalIn: NSRect(x: 15 * u, y: 15 * u, width: 2 * u, height: 2 * u))
            NSColor.black.setFill(); c.fill()

        case .crosshair:
            let p = NSBezierPath()
            for (a, b) in [((16, 3), (16, 12)), ((16, 20), (16, 29)), ((3, 16), (12, 16)), ((20, 16), (29, 16))] as [((CGFloat, CGFloat), (CGFloat, CGFloat))] {
                p.move(to: NSPoint(x: a.0 * u, y: a.1 * u)); p.line(to: NSPoint(x: b.0 * u, y: b.1 * u))
            }
            p.appendOval(in: NSRect(x: 15 * u, y: 15 * u, width: 2 * u, height: 2 * u))
            p.lineCapStyle = .round
            p.lineWidth = 3.5 * u; NSColor.white.setStroke(); p.stroke()
            p.lineWidth = 1.5 * u; Tint.red.fill.setStroke(); p.stroke()
        }
    }

    static let aurora = NSGradient(colors: [NSColor(srgbRed: 0.36, green: 0.22, blue: 0.95, alpha: 1),
                                            NSColor(srgbRed: 0.85, green: 0.25, blue: 0.75, alpha: 1),
                                            NSColor(srgbRed: 1.0, green: 0.48, blue: 0.4, alpha: 1)])!

    private static func fillGradient(_ path: NSBezierPath, ctx: CGContext, side s: CGFloat) {
        ctx.saveGState()
        path.addClip()
        aurora.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: -60)
        ctx.restoreGState()
    }

    /// Рука-указатель из капсул: сначала толстый контур всех частей, затем заливка (её рисует `fill`,
    /// вызывая переданное замыкание с фигурами) — так внешний контур получается цельным. Потом линии между пальцами.
    private static func drawHand(unit u: CGFloat, outline line: NSColor, fill: (() -> Void) -> Void) {
        func capsule(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSBezierPath {
            NSBezierPath(roundedRect: NSRect(x: x * u, y: y * u, width: w * u, height: h * u),
                         xRadius: w * u / 2, yRadius: w * u / 2)
        }
        let thumb = NSBezierPath()
        thumb.move(to: NSPoint(x: 6.8 * u, y: 17.2 * u))
        thumb.line(to: NSPoint(x: 11.5 * u, y: 23 * u))
        thumb.lineCapStyle = .round
        let parts = [
            capsule(10.6, 1.6, 3.8, 17),                       // указательный
            capsule(14.4, 10.2, 3.6, 10), capsule(18, 11.2, 3.6, 9.5), capsule(21.6, 12.6, 3.4, 8.5),
            NSBezierPath(roundedRect: NSRect(x: 9 * u, y: 16 * u, width: 16 * u, height: 12.8 * u),
                         xRadius: 4.5 * u, yRadius: 4.5 * u),  // ладонь
        ]
        let outline = 1.3 * u
        line.setStroke(); line.setFill()
        thumb.lineWidth = 3.6 * u + 2 * outline; thumb.stroke()
        for part in parts { part.lineWidth = 2 * outline; part.stroke() }
        fill {
            thumb.lineWidth = 3.6 * u; thumb.stroke()
            for part in parts { part.fill() }
        }
        let creases = NSBezierPath()
        for (x, y) in [(14.4, 12.2), (18, 13.2), (21.6, 14.6)] as [(CGFloat, CGFloat)] {
            creases.move(to: NSPoint(x: x * u, y: y * u)); creases.line(to: NSPoint(x: x * u, y: (y + 4) * u))
        }
        creases.lineWidth = outline * 0.8
        creases.lineCapStyle = .round
        line.setStroke(); creases.stroke()
    }

    /// Многоугольник со скруглёнными вершинами: (x, y, радиус) в сетке 32×32.
    private static func roundedPolygon(_ v: [(CGFloat, CGFloat, CGFloat)], unit u: CGFloat) -> NSBezierPath {
        let pts = v.map { NSPoint(x: $0.0 * u, y: $0.1 * u) }
        let p = NSBezierPath()
        let last = pts[pts.count - 1]
        p.move(to: NSPoint(x: (last.x + pts[0].x) / 2, y: (last.y + pts[0].y) / 2))
        for i in pts.indices {
            p.appendArc(from: pts[i], to: pts[(i + 1) % pts.count], radius: v[i].2 * u)
        }
        p.close()
        p.lineJoinStyle = .round
        return p
    }

    /// Своя картинка (PNG, JPEG, TIFF, HEIC, ICNS, SVG…); анимированный GIF/APNG — по кадрам.
    static func render(file url: URL, size s: CGFloat, centered: Bool) -> RenderedCursor? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        let box = CGSize(width: s, height: s)
        let hotspot = centered ? CGPoint(x: s / 2, y: s / 2) : .zero

        if count > 1 {
            let step = max(1, Int((Double(count) / Double(maxFrames)).rounded(.up)))
            let indices = Array(stride(from: 0, to: count, by: step).prefix(maxFrames))
            let frames = indices.compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
            guard !frames.isEmpty else { return nil }
            let duration = frameDelay(source, at: 0) * Double(step)
            let images = scales.compactMap { scale in
                bitmap(size: box, scale: scale, frames: frames.count) { ctx, i in
                    drawFitted(frames[i], in: box, ctx: ctx)
                }
            }
            return RenderedCursor(images: images, size: box, hotspot: hotspot, frames: frames.count, frameDuration: duration)
        }

        // NSImage понимает больше форматов (SVG, PDF), поэтому одиночные картинки — через него.
        guard let image = NSImage(contentsOf: url) else { return nil }
        let images = scales.compactMap { scale -> CGImage? in
            var rect = NSRect(origin: .zero, size: NSSize(width: s * scale, height: s * scale))
            guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
            return bitmap(size: box, scale: scale) { ctx, _ in drawFitted(cg, in: box, ctx: ctx) }
        }
        return images.isEmpty ? nil : RenderedCursor(images: images, size: box, hotspot: hotspot)
    }

    static func drawFitted(_ image: CGImage, in box: CGSize, ctx: CGContext) {
        let k = min(box.width / CGFloat(image.width), box.height / CGFloat(image.height))
        let w = CGFloat(image.width) * k, h = CGFloat(image.height) * k
        // Контекст перевёрнут — переворачиваем обратно, чтобы картинка не встала вверх ногами.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: (box.height + h) / 2)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: (box.width - w) / 2, y: 0, width: w, height: h))
        ctx.restoreGState()
    }

    private static func frameDelay(_ source: CGImageSource, at index: Int) -> Double {
        let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let dict = (props?[kCGImagePropertyGIFDictionary] ?? props?[kCGImagePropertyPNGDictionary]) as? [CFString: Any]
        let delay = (dict?[kCGImagePropertyGIFUnclampedDelayTime] ?? dict?[kCGImagePropertyGIFDelayTime]
            ?? dict?[kCGImagePropertyAPNGUnclampedDelayTime] ?? dict?[kCGImagePropertyAPNGDelayTime]) as? Double
        return max(delay ?? 0.1, 0.02)
    }

    /// Курсор из набора Windows. Родной размер набора (32 px = 32 pt) умножается на `scale`.
    static func render(_ cursor: WinCursor, scale k: CGFloat) -> RenderedCursor? {
        let step = max(1, Int((Double(cursor.frames.count) / Double(maxFrames)).rounded(.up)))
        let indices = Array(stride(from: 0, to: cursor.frames.count, by: step).prefix(maxFrames))
        let size = CGSize(width: cursor.nominalSize.width * k, height: cursor.nominalSize.height * k)
        let first = cursor.best(frame: indices[0], width: size.width)
        let ratio = size.width / CGFloat(first.image.width)
        let images = scales.compactMap { scale in
            bitmap(size: size, scale: scale, frames: indices.count) { ctx, i in
                drawFitted(cursor.best(frame: indices[i], width: size.width * scale).image, in: size, ctx: ctx)
            }
        }
        guard !images.isEmpty else { return nil }
        return RenderedCursor(images: images, size: size,
                              hotspot: CGPoint(x: first.hotspot.x * ratio, y: first.hotspot.y * ratio),
                              frames: indices.count, frameDuration: indices.count > 1 ? cursor.frameDuration * Double(step) : 0)
    }

    static func menuPreview(_ preset: Preset) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(preset, side: 18, in: ctx)
            return true
        }
        return image
    }
}
