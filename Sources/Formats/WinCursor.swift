import AppKit
import ImageIO

// MARK: - Windows .cur / .ani
// .cur — это .ico с типом 2, где вместо «планов/бит» в записи лежит точка клика.
// .ani — RIFF «ACON»: заголовок anih, необязательные rate/seq и список кадров-иконок.

struct WinCursorImage {
    var image: CGImage
    var hotspot: CGPoint  // в пикселях этой картинки
}

struct WinCursor {
    /// Кадры анимации; у каждого — набор размеров (32, 48, 64…), от меньшего к большему.
    var frames: [[WinCursorImage]]
    var frameDuration: Double = 0

    static func load(_ url: URL) -> WinCursor? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if data.starts(with: Array("RIFF".utf8)) { return loadANI(data) }
        return parseCUR(data).map { WinCursor(frames: [$0]) }
    }

    static func parseCUR(_ d: Data) -> [WinCursorImage]? {
        let d = Data(d)  // индексы с нуля
        guard d.count >= 6, d.u16(2) == 2 || d.u16(2) == 1 else { return nil }
        let count = Int(d.u16(4))
        var result: [WinCursorImage] = []
        for i in 0..<count {
            let e = 6 + i * 16
            guard e + 16 <= d.count else { break }
            let hot = CGPoint(x: Int(d.u16(e + 4)), y: Int(d.u16(e + 6)))
            let size = Int(d.u32(e + 8)), offset = Int(d.u32(e + 12))
            guard offset + size <= d.count, size > 0 else { continue }
            let blob = d.subdata(in: offset..<offset + size)
            let image: CGImage?
            if blob.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                image = CGImageSourceCreateWithData(blob as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            } else {
                // DIB без заголовка файла: заворачиваем в .ico из одной картинки — его ImageIO читает сам.
                var ico = Data([0, 0, 1, 0, 1, 0])
                ico.append(d.subdata(in: e..<e + 4))
                ico.append(contentsOf: [1, 0])
                ico.append(blob.count >= 16 ? blob.subdata(in: 14..<16) : Data([32, 0]))
                ico.append(le32(UInt32(blob.count)))
                ico.append(le32(22))
                ico.append(blob)
                image = CGImageSourceCreateWithData(ico as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            }
            if let image { result.append(WinCursorImage(image: image, hotspot: hot)) }
        }
        result.sort { $0.image.width < $1.image.width }
        return result.isEmpty ? nil : result
    }

    private static func loadANI(_ d: Data) -> WinCursor? {
        let d = Data(d)
        guard d.count > 12, d.subdata(in: 8..<12) == Data("ACON".utf8) else { return nil }
        var icons: [[WinCursorImage]] = []
        var rates: [UInt32] = [], seq: [Int] = []
        var defaultRate: UInt32 = 6

        func walk(_ start: Int, _ end: Int) {
            var p = start
            while p + 8 <= end {
                let id = String(decoding: d.subdata(in: p..<p + 4), as: UTF8.self)
                let len = Int(d.u32(p + 4)), body = p + 8
                guard body + len <= d.count else { return }
                switch id {
                case "anih" where len >= 36: defaultRate = max(d.u32(body + 28), 1)
                case "rate": rates = (0..<len / 4).map { d.u32(body + $0 * 4) }
                case "seq ": seq = (0..<len / 4).map { Int(d.u32(body + $0 * 4)) }
                case "LIST": walk(body + 4, body + len)
                case "icon": if let f = parseCUR(d.subdata(in: body..<body + len)) { icons.append(f) }
                default: break
                }
                p = body + len + (len & 1)
            }
        }
        walk(12, d.count)
        guard !icons.isEmpty else { return nil }

        let order = seq.isEmpty ? Array(icons.indices) : seq.filter { $0 < icons.count }
        let steps = rates.count == order.count ? rates : Array(repeating: defaultRate, count: order.count)
        // У macOS одна длительность на все кадры — берём среднюю (в «тиках» 1/60 с).
        let average = Double(steps.reduce(0, +)) / Double(max(steps.count, 1)) / 60
        return WinCursor(frames: order.map { icons[$0] }, frameDuration: max(average, 0.02))
    }

    /// Номинальный размер в пунктах: у Windows курсор 32 px = 32 pt при масштабе 100%.
    var nominalSize: CGSize {
        let base = frames[0][0].image
        return CGSize(width: base.width, height: base.height)
    }

    /// Картинка, подходящая под нужное число пикселей по ширине.
    func best(frame: Int, width: CGFloat) -> WinCursorImage {
        let sizes = frames[frame]
        return sizes.first { CGFloat($0.image.width) >= width } ?? sizes[sizes.count - 1]
    }

    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
}

extension Data {
    func u16(_ o: Int) -> UInt16 { UInt16(self[o]) | UInt16(self[o + 1]) << 8 }
    func u32(_ o: Int) -> UInt32 { UInt32(u16(o)) | UInt32(u16(o + 2)) << 16 }
}

