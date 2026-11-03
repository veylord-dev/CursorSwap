import AppKit

// MARK: - Style
// Что стоит в конкретном слоте (стрелка / рука / текст).

enum Style: Equatable {
    case system
    case preset(Preset)
    case file(URL)
    /// Курсор из набора Windows (.cur/.ani) — по id набора (имя папки).
    case pack(String)

    var stored: String {
        switch self {
        case .system: "system"
        case .preset(let p): "preset:" + p.id
        case .file(let url): "file:" + url.path
        case .pack(let id): "pack:" + id
        }
    }

    init(stored: String?) {
        guard let stored else { self = .system; return }
        if stored.hasPrefix("preset:"), let p = Preset(id: String(stored.dropFirst(7))) {
            self = .preset(p)
        } else if stored.hasPrefix("file:"), FileManager.default.fileExists(atPath: String(stored.dropFirst(5))) {
            self = .file(URL(fileURLWithPath: String(stored.dropFirst(5))))
        } else if stored.hasPrefix("pack:") {
            let id = String(stored.dropFirst(5))
            self = .pack(Self.renamedPacks[id] ?? id)
        } else {
            self = .system
        }
    }

    /// В версии 1.0 встроенные наборы назывались по-русски — переводим сохранённые настройки.
    private static let renamedPacks = [
        "Windows 11 светлый": "Windows 11 Light", "Windows 11 тёмный": "Windows 11 Dark",
        "macOS-стиль": "macOS Style", "Vision белый": "Vision White", "Vision чёрный": "Vision Black",
        "Material светлый": "Material Light", "Material тёмный": "Material Dark",
        "Material тёмный мини": "Material Dark Mini", "Windows 10X ×1.5": "Windows 10X Large",
    ]
}

// MARK: - Settings

final class Settings {
    private let defaults = UserDefaults.standard

    func style(for role: CursorRole) -> Style { Style(stored: defaults.string(forKey: "style." + role.rawValue)) }
    func setStyle(_ style: Style, for role: CursorRole) { defaults.set(style.stored, forKey: "style." + role.rawValue) }

    static let sizes: [CGFloat] = [24, 32, 48, 64, 96]
    static let sizeRange: ClosedRange<CGFloat> = 16...128

    /// Размер в пунктах; 32 — «обычный», он же родной размер наборов Windows.
    var size: CGFloat {
        get { let v = defaults.double(forKey: "size"); return v > 0 ? min(max(v, Self.sizeRange.lowerBound), Self.sizeRange.upperBound) : 32 }
        set { defaults.set(Double(newValue), forKey: "size") }
    }

    /// Где у своей картинки «кончик»: левый верхний угол или центр.
    var fileHotspotCentered: Bool {
        get { defaults.bool(forKey: "fileHotspotCentered") }
        set { defaults.set(newValue, forKey: "fileHotspotCentered") }
    }

    /// Пауза: настройки сохранены, но показываются системные курсоры.
    var paused: Bool {
        get { defaults.bool(forKey: "paused") }
        set { defaults.set(newValue, forKey: "paused") }
    }

    static let storage: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CursorSwap", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
}
