import AppKit

// MARK: - Private CoreGraphics API
// Тот же механизм, что в Mousecape (github.com/alexzielenski/Mousecape, BSD):
// регистрируем свою картинку в WindowServer под системным именем курсора —
// и её начинают показывать все приложения. Сбрасывается при выходе из системы.
//
// С macOS 26 стрелка и I-beam рисуются из новых имён ArrowS / IBeamS (см. форк
// github.com/SnowGlow-aww/Mousecape), а CoreCursorUnregisterAll их уже не откатывает —
// поэтому для сброса заново регистрируем оригиналы из SkyLight/CursorAsset.

enum CoreCursor {
    typealias Conn = Int32
    private typealias MainConnFn = @convention(c) () -> Conn
    private typealias RegisterFn = @convention(c) (
        Conn, UnsafePointer<CChar>, Bool, Bool, CGSize, CGPoint, Int, CGFloat, CFArray, UnsafeMutablePointer<Int32>
    ) -> CGError
    private typealias UnregisterAllFn = @convention(c) (Conn) -> CGError

    private static let skyLight = dlopen(nil, RTLD_NOW)
    private static let hiServices = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_NOW)

    private static func sym<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as: T.Type) -> T? {
        dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
    }

    private static let mainConnection = sym(skyLight, "CGSMainConnectionID", as: MainConnFn.self)
    private static let register = sym(skyLight, "CGSRegisterCursorWithImages", as: RegisterFn.self)
    private static let unregisterAll = sym(hiServices, "CoreCursorUnregisterAll", as: UnregisterAllFn.self)

    static var isAvailable: Bool { mainConnection != nil && register != nil && unregisterAll != nil }

    /// `images` — одна и та же картинка в разных масштабах (1x, 2x…); кадры анимации
    /// уложены в каждой картинке вертикальной лентой. `size` и `hotspot` — в пунктах, на один кадр.
    @discardableResult
    static func set(_ names: [String], images: [CGImage], size: CGSize, hotspot: CGPoint,
                    frames: Int = 1, frameDuration: CGFloat = 0) -> Bool {
        guard let mainConnection, let register else { return false }
        let cid = mainConnection()
        var ok = true
        for name in names {
            var seed: Int32 = 0
            let err = register(cid, name, true, true, size, hotspot, frames, frameDuration, images as CFArray, &seed)
            if err != .success { NSLog("CGSRegisterCursorWithImages(\(name)) = \(err.rawValue)"); ok = false }
        }
        return ok
    }

    static func resetAll() {
        guard let mainConnection, let unregisterAll else { return }
        _ = unregisterAll(mainConnection())
        for (assetID, names) in SystemCursorAsset.coreNames {
            guard let c = SystemCursorAsset.cursor(id: assetID) else { continue }
            set(names, images: c.images, size: c.size, hotspot: c.hotspot)
        }
    }
}

/// Оригинальные картинки курсоров, зашитые в SkyLight. Это dylib с одним символом `cursors`:
/// массив {id, указатель} до нулевой записи. Курсор: w, h, hotX, hotY (double), кадры, длительность,
/// число картинок и указатели на них. Картинка: w, h (u64), hotX, hotY (double), затем пиксели BGRA.
enum SystemCursorAsset {
    /// id 100 — стрелка, 101 — I-beam (размеры совпадают с тем, что отдаёт система).
    static let coreNames: [(UInt64, [String])] = [
        (100, ["com.apple.coregraphics.ArrowS", "com.apple.coregraphics.Arrow"]),
        (101, ["com.apple.coregraphics.IBeamS", "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamXOR"]),
    ]

    private static let table: UnsafePointer<UInt64>? = {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/Resources/CursorAsset", RTLD_NOW)
        return dlsym(handle, "cursors").map { UnsafePointer($0.assumingMemoryBound(to: UInt64.self)) }
    }()

    static func cursor(id: UInt64) -> RenderedCursor? {
        guard var entry = table else { return nil }
        while entry[1] != 0 {
            if entry[0] == id, let c = UnsafeRawPointer(bitPattern: UInt(entry[1])) {
                let size = CGSize(width: c.load(as: Double.self), height: c.load(fromByteOffset: 8, as: Double.self))
                let hotspot = CGPoint(x: c.load(fromByteOffset: 16, as: Double.self), y: c.load(fromByteOffset: 24, as: Double.self))
                guard c.load(fromByteOffset: 32, as: UInt64.self) == 1 else { return nil }  // только статичные
                let count = Int(c.load(fromByteOffset: 48, as: UInt64.self))
                let images = (0..<count).compactMap { i -> CGImage? in
                    guard let r = UnsafeRawPointer(bitPattern: UInt(c.load(fromByteOffset: 56 + i * 8, as: UInt64.self))) else { return nil }
                    let w = Int(r.load(as: UInt64.self)), h = Int(r.load(fromByteOffset: 8, as: UInt64.self))
                    let data = Data(bytes: r + 32, count: w * h * 4) as CFData
                    return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                   provider: CGDataProvider(data: data)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                }
                return images.isEmpty ? nil : RenderedCursor(images: images, size: size, hotspot: hotspot)
            }
            entry += 2
        }
        return nil
    }
}
