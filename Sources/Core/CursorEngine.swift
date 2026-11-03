import AppKit
import Combine

// MARK: - Engine
// Единственное место, которое решает, какие курсоры зарегистрировать в WindowServer.
// Интерфейс (меню и галерея) только меняет настройки и просит `applyAll()`.

final class CursorEngine: ObservableObject {
    let settings = Settings()
    let catalog = Catalog.shared

    /// Увеличивается при каждом изменении — галерея перерисовывается.
    @Published private(set) var revision = 0

    /// Сначала возвращаем всё системное, затем регистрируем выбранные курсоры заново.
    func applyAll() {
        defer { revision += 1 }
        CoreCursor.resetAll()
        guard !settings.paused else { return }

        for role in CursorRole.slots {
            guard let r = render(settings.style(for: role), role: role) else { continue }
            register(r, for: role)
        }
        // Если стрелка из набора Windows — остальные курсоры (запрет, ресайз, «в фоне»…) берём оттуда же.
        guard case .pack(let id) = settings.style(for: .arrow) else { return }
        for role in CursorRole.allCases where !role.isSlot {
            guard let r = catalog.render(pack: id, role: role, scale: packScale) else { continue }
            register(r, for: role)
        }
    }

    func render(_ style: Style, role: CursorRole) -> RenderedCursor? {
        switch style {
        case .system: nil
        case .preset(let p): Renderer.render(p, size: settings.size)
        case .file(let url): Renderer.render(file: url, size: settings.size, centered: settings.fileHotspotCentered)
        case .pack(let id): catalog.render(pack: id, role: role, scale: packScale)
        }
    }

    private func register(_ r: RenderedCursor, for role: CursorRole) {
        CoreCursor.set(role.cursorNames, images: r.images, size: r.size, hotspot: r.hotspot,
                       frames: r.frames, frameDuration: r.frameDuration)
    }

    /// «Обычный» размер (32 pt) — родной размер наборов Windows.
    private var packScale: CGFloat { settings.size / 32 }

    // MARK: Sets

    func apply(_ set: CursorSet) {
        for role in CursorRole.slots { settings.setStyle(set.style(for: role) ?? .system, for: role) }
        settings.paused = false
        applyAll()
    }

    /// Набор, который сейчас стоит целиком (nil — системные курсоры или своя комбинация).
    var currentSet: CursorSet? {
        let styles = CursorRole.slots.map { settings.style(for: $0) }
        guard styles.contains(where: { $0 != .system }) else { return nil }
        return catalog.sets.first { set in
            zip(CursorRole.slots, styles).allSatisfy { (set.style(for: $0) ?? .system) == $1 }
        }
    }

    var isAllSystem: Bool { CursorRole.slots.allSatisfy { settings.style(for: $0) == .system } }

    func setStyle(_ style: Style, for role: CursorRole) {
        settings.setStyle(style, for: role)
        applyAll()
    }

    func resetToSystem() {
        for role in CursorRole.slots { settings.setStyle(.system, for: role) }
        applyAll()
    }

    func togglePause() {
        settings.paused.toggle()
        applyAll()
    }

    func setSize(_ size: CGFloat) {
        settings.size = size
        applyAll()
    }

    // MARK: Files

    /// Копируем картинку к себе, чтобы курсор не пропал, если оригинал удалят или переместят.
    func importFile(_ url: URL, for role: CursorRole) throws -> URL {
        let fm = FileManager.default
        if let old = try? fm.contentsOfDirectory(at: Settings.storage, includingPropertiesForKeys: nil) {
            for f in old where f.deletingPathExtension().lastPathComponent == role.rawValue { try? fm.removeItem(at: f) }
        }
        let dest = Settings.storage.appendingPathComponent(role.rawValue).appendingPathExtension(url.pathExtension)
        try fm.copyItem(at: url, to: dest)
        return dest
    }

    /// Копируем из папки набора только курсоры и Install.inf (без PSD, PNG-исходников и т.п.).
    func importPack(_ folder: URL) throws -> CursorSet? {
        let fm = FileManager.default
        let dest = Catalog.userPacks.appendingPathComponent(folder.lastPathComponent)
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        for f in try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        where CursorPack.isCursorFile(f) || f.pathExtension.lowercased() == "inf" {
            try fm.copyItem(at: f, to: dest.appendingPathComponent(f.lastPathComponent))
        }
        catalog.reload()
        return catalog.set("pack:" + dest.lastPathComponent)
    }

    func deletePack(_ pack: CursorPack) {
        guard !pack.isBuiltIn else { return }
        try? FileManager.default.trashItem(at: pack.folder, resultingItemURL: nil)
        for role in CursorRole.slots where settings.style(for: role) == .pack(pack.id) {
            settings.setStyle(.system, for: role)
        }
        catalog.reload()
        applyAll()
    }
}
