import AppKit

// MARK: - Cursor sets
// Набор = готовая комбинация курсоров, которая ставится одним кликом.
// Бывает трёх видов: нарисованный программой, встроенный набор Windows (Resources/Packs)
// и добавленный пользователем (~/Library/Application Support/CursorSwap/Packs).

/// Набор из трёх нарисованных курсоров.
struct DrawnSet {
    let id: String
    let arrow: Preset, hand: Preset, text: Preset

    var title: String { L("set." + id) }

    func preset(for role: CursorRole) -> Preset? {
        switch role {
        case .arrow: arrow
        case .hand: hand
        case .text: text
        default: nil
        }
    }

    static let all: [DrawnSet] = [
        DrawnSet(id: "aurora", arrow: .aurora(.arrow), hand: .aurora(.hand), text: .aurora(.beam)),
        DrawnSet(id: "mini", arrow: .minimal(.graphite), hand: .minimal(.accent), text: .minimalBeam(.graphite)),
        DrawnSet(id: "mini.light", arrow: .minimal(.light), hand: .minimal(.accent), text: .minimalBeam(.light)),
        DrawnSet(id: "classic", arrow: .windows(.arrow, dark: false), hand: .windows(.hand, dark: false), text: .windows(.beam, dark: false)),
        DrawnSet(id: "classic.dark", arrow: .windows(.arrow, dark: true), hand: .windows(.hand, dark: true), text: .windows(.beam, dark: true)),
    ]
}

/// Папка с курсорами Windows (.cur/.ani) и, если есть, Install.inf со схемой ролей.
struct CursorPack {
    var id: String          // имя папки
    var folder: URL
    var files: [CursorRole: URL]
    var isBuiltIn: Bool

    /// У встроенных — перевод, у своих — имя папки.
    var title: String { hasL("pack." + id) ? L("pack." + id) : id }
    var isAnimated: Bool { files[.working]?.pathExtension.lowercased() == "ani" }

    static func load(_ folder: URL, builtIn: Bool = false) -> CursorPack? {
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        let cursors = items.filter { isCursorFile($0) }
        guard !cursors.isEmpty else { return nil }
        var files: [CursorRole: URL] = [:]

        if let inf = items.first(where: { $0.pathExtension.lowercased() == "inf" }),
           let raw = try? Data(contentsOf: inf) {
            let (registry, strings) = parseINF(String(decoding: raw, as: UTF8.self))
            for role in CursorRole.allCases {
                guard let key = registry[role.registryKey], let file = strings[key] else { continue }
                files[role] = cursors.first { $0.lastPathComponent.lowercased() == file.lowercased() }
            }
        }
        for role in CursorRole.allCases where files[role] == nil {
            files[role] = cursors.first { f in
                let name = f.deletingPathExtension().lastPathComponent.lowercased()
                return role.fileHints.contains { name.contains($0) }
            }
        }
        guard files[.arrow] != nil else { return nil }
        return CursorPack(id: folder.lastPathComponent, folder: folder, files: files, isBuiltIn: builtIn)
    }

    static func isCursorFile(_ url: URL) -> Bool { ["cur", "ani"].contains(url.pathExtension.lowercased()) }

    /// Из Install.inf: роль → %ключ% (раздел реестра) и ключ → имя файла ([Strings]).
    private static func parseINF(_ text: String) -> (registry: [String: String], strings: [String: String]) {
        var strings: [String: String] = [:], registry: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let l = line.trimmingCharacters(in: .whitespaces)
            if l.lowercased().hasPrefix("hkcu,\"control panel\\cursors\"") {
                // HKCU,"Control Panel\Cursors",Arrow,0x00020000,"%10%\%CUR_DIR%\%pointer%"
                let parts = l.components(separatedBy: ",")
                guard parts.count >= 5, let key = parts.last?.components(separatedBy: "%").dropLast().last else { continue }
                registry[parts[2].lowercased()] = key.lowercased()
            } else if let eq = l.firstIndex(of: "="), !l.hasPrefix(";") {
                let k = l[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
                let v = l[l.index(after: eq)...].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                strings[k] = v
            }
        }
        return (registry, strings)
    }
}

enum CursorSet {
    case drawn(DrawnSet)
    case pack(CursorPack)

    var id: String {
        switch self {
        case .drawn(let d): "drawn:" + d.id
        case .pack(let p): "pack:" + p.id
        }
    }

    var title: String {
        switch self {
        case .drawn(let d): d.title
        case .pack(let p): p.title
        }
    }

    var isBuiltIn: Bool {
        if case .pack(let p) = self { return p.isBuiltIn }
        return true
    }

    var isAnimated: Bool {
        if case .pack(let p) = self { return p.isAnimated }
        return false
    }

    var roles: [CursorRole] {
        switch self {
        case .drawn: CursorRole.slots
        case .pack(let p): CursorRole.allCases.filter { p.files[$0] != nil }
        }
    }

    /// Что этот набор ставит в слот (nil — слот остаётся системным).
    func style(for role: CursorRole) -> Style? {
        switch self {
        case .drawn(let d): d.preset(for: role).map { .preset($0) }
        case .pack(let p): p.files[role] != nil ? .pack(p.id) : nil
        }
    }
}

// MARK: - Catalog

/// Все наборы и разобранные файлы курсоров. Читается с диска один раз и при изменениях (`reload`).
final class Catalog {
    static let shared = Catalog()

    private(set) var packs: [CursorPack] = []
    private var decoded: [URL: WinCursor] = [:]
    private var previews: [String: NSImage] = [:]

    static var bundledPacks: URL? { Bundle.main.resourceURL?.appendingPathComponent("Packs") }

    static let userPacks: URL = {
        let dir = Settings.storage.appendingPathComponent("Packs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() { reload() }

    func reload() {
        func scan(_ dir: URL?, builtIn: Bool) -> [CursorPack] {
            guard let dir, let subs = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
            return subs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .compactMap { CursorPack.load($0, builtIn: builtIn) }
        }
        let builtIn = scan(Self.bundledPacks, builtIn: true)
        let ids = Set(builtIn.map(\.id))
        packs = builtIn + scan(Self.userPacks, builtIn: false).filter { !ids.contains($0.id) }
        decoded = [:]
        previews = [:]
    }

    /// Сначала нарисованные, затем встроенные наборы Windows, затем свои.
    var sets: [CursorSet] { DrawnSet.all.map(CursorSet.drawn) + packs.map(CursorSet.pack) }
    var builtInSets: [CursorSet] { sets.filter(\.isBuiltIn) }
    var userSets: [CursorSet] { sets.filter { !$0.isBuiltIn } }

    func pack(_ id: String) -> CursorPack? { packs.first { $0.id == id } }
    func set(_ id: String) -> CursorSet? { sets.first { $0.id == id } }

    func cursor(_ url: URL) -> WinCursor? {
        if let c = decoded[url] { return c }
        let c = WinCursor.load(url)
        decoded[url] = c
        return c
    }

    /// `scale` — множитель к родному размеру набора (1 = как в Windows при 100%).
    func render(pack id: String, role: CursorRole, scale: CGFloat) -> RenderedCursor? {
        guard let url = pack(id)?.files[role], let cursor = cursor(url) else { return nil }
        return Renderer.render(cursor, scale: scale)
    }

    /// Превью курсора набора (первый кадр, обычный размер). Кэшируется.
    func preview(_ set: CursorSet, _ role: CursorRole) -> NSImage? {
        let key = set.id + "/" + role.rawValue
        if let p = previews[key] { return p }
        let rendered: RenderedCursor? = switch set {
        case .drawn(let d): d.preset(for: role).map { Renderer.render($0, size: 32) }
        case .pack(let p): render(pack: p.id, role: role, scale: 1)
        }
        let image = rendered?.preview
        previews[key] = image
        return image
    }
}
