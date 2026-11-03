import AppKit
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Status bar menu
// Меню собирается заново при каждом открытии — так галочки и язык всегда актуальны.

final class StatusMenu: NSObject, NSMenuDelegate {
    private let engine: CursorEngine
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var onOpenGallery: (() -> Void)?

    private var settings: Settings { engine.settings }
    private var catalog: Catalog { engine.catalog }

    init(engine: CursorEngine) {
        self.engine = engine
        super.init()
        statusItem.button?.image = Self.icon(paused: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func refreshIcon() {
        statusItem.button?.image = Self.icon(paused: settings.paused)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        menu.addItem(item(L("menu.gallery"), #selector(openGallery), key: "g"))
        menu.addItem(submenu(L("menu.sets"), setsMenu()))
        menu.addItem(submenu(L("menu.customize"), customizeMenu()))
        menu.addItem(submenu(L("menu.size"), sizeMenu()))

        menu.addItem(.separator())
        let pause = item(L("menu.pause") + "   " + HotKey.pauseDisplay, #selector(togglePause), on: settings.paused)
        menu.addItem(pause)
        menu.addItem(item(L("menu.reapply"), #selector(reapply)))
        menu.addItem(item(L("menu.reset"), #selector(resetAll)))

        menu.addItem(.separator())
        menu.addItem(submenu(L("menu.language"), languageMenu()))
        menu.addItem(item(L("menu.login"), #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(item(L("menu.about"), #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private var statusLine: String {
        if settings.paused { return L("status.paused") }
        if let set = engine.currentSet { return L("status.current", set.title) }
        return engine.isAllSystem ? L("status.system") : L("status.custom")
    }

    // MARK: Submenus

    private func setsMenu() -> NSMenu {
        let m = NSMenu()
        let current = engine.currentSet?.id
        func add(_ sets: [CursorSet]) {
            for set in sets {
                let it = item(set.title, #selector(applySet), on: set.id == current)
                it.representedObject = set.id
                it.image = catalog.preview(set, .arrow).map { Self.menuSized($0) }
                m.addItem(it)
            }
        }
        m.addItem(.sectionHeader(title: L("menu.sets.builtIn")))
        add(catalog.builtInSets)
        if !catalog.userSets.isEmpty {
            m.addItem(.separator())
            m.addItem(.sectionHeader(title: L("menu.sets.mine")))
            add(catalog.userSets)
        }
        m.addItem(.separator())
        m.addItem(item(L("menu.sets.add"), #selector(addPack)))
        m.addItem(item(L("menu.sets.openFolder"), #selector(openPacksFolder)))
        return m
    }

    private func customizeMenu() -> NSMenu {
        let m = NSMenu()
        for role in CursorRole.slots {
            let sub = NSMenu()
            let current = settings.style(for: role)
            sub.addItem(roleItem(L("menu.system"), #selector(chooseSystem), role, on: current == .system))
            sub.addItem(.separator())
            for preset in role.presets {
                let it = roleItem(preset.title, #selector(choosePreset), role, on: current == .preset(preset), value: preset.id)
                it.image = Renderer.menuPreview(preset)
                sub.addItem(it)
            }
            let packs = catalog.sets.filter { if case .pack = $0 { $0.roles.contains(role) } else { false } }
            if !packs.isEmpty {
                sub.addItem(.separator())
                sub.addItem(.sectionHeader(title: L("menu.fromSet")))
                for set in packs {
                    let style = set.style(for: role)!
                    let it = roleItem(set.title, #selector(choosePackForRole), role, on: current == style, value: set.id)
                    it.image = catalog.preview(set, role).map { Self.menuSized($0) }
                    sub.addItem(it)
                }
            }
            sub.addItem(.separator())
            var fileTitle = L("menu.customImage")
            if case .file(let url) = current { fileTitle = L("menu.customImage.current", url.pathExtension.uppercased()) }
            sub.addItem(roleItem(fileTitle, #selector(chooseFile), role, on: { if case .file = current { true } else { false } }()))
            m.addItem(submenu(role.title, sub))
        }
        m.addItem(.separator())
        let hotspot = item(L("menu.hotspotCenter"), #selector(toggleHotspot), on: settings.fileHotspotCentered)
        hotspot.toolTip = L("menu.hotspotCenter.tip")
        m.addItem(hotspot)
        return m
    }

    private func sizeMenu() -> NSMenu {
        let m = NSMenu()
        for value in Settings.sizes {
            let it = item(L("menu.size.item", L("size.\(Int(value))"), Int(value)), #selector(chooseSize), on: settings.size == value)
            it.tag = Int(value)
            m.addItem(it)
        }
        return m
    }

    private func languageMenu() -> NSMenu {
        let m = NSMenu()
        for lang in Language.allCases {
            let it = item(lang.title, #selector(chooseLanguage), on: Language.current == lang)
            it.representedObject = lang.rawValue
            m.addItem(it)
        }
        return m
    }

    // MARK: Item helpers

    private func item(_ title: String, _ action: Selector, key: String = "", on: Bool = false) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        it.state = on ? .on : .off
        return it
    }

    private func roleItem(_ title: String, _ action: Selector, _ role: CursorRole, on: Bool, value: String? = nil) -> NSMenuItem {
        let it = item(title, action, on: on)
        it.representedObject = [role.rawValue, value].compactMap { $0 }
        return it
    }

    private func submenu(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.submenu = menu
        return it
    }

    private func role(of sender: NSMenuItem) -> CursorRole? {
        (sender.representedObject as? [String])?.first.flatMap(CursorRole.init)
    }

    private func value(of sender: NSMenuItem) -> String? {
        (sender.representedObject as? [String]).flatMap { $0.count > 1 ? $0[1] : nil }
    }

    // MARK: Actions

    @objc private func openGallery() { onOpenGallery?() }

    @objc private func applySet(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let set = catalog.set(id) else { return }
        engine.apply(set)
    }

    @objc private func chooseSystem(_ sender: NSMenuItem) {
        guard let role = role(of: sender) else { return }
        engine.setStyle(.system, for: role)
    }

    @objc private func choosePreset(_ sender: NSMenuItem) {
        guard let role = role(of: sender), let preset = value(of: sender).flatMap(Preset.init(id:)) else { return }
        engine.setStyle(.preset(preset), for: role)
    }

    @objc private func choosePackForRole(_ sender: NSMenuItem) {
        guard let role = role(of: sender), let set = value(of: sender).flatMap(catalog.set), let style = set.style(for: role) else { return }
        engine.setStyle(style, for: role)
    }

    @objc private func chooseFile(_ sender: NSMenuItem) {
        guard let role = role(of: sender) else { return }
        Self.chooseImage(for: role, engine: engine)
    }

    @objc private func addPack() { Self.addPack(engine: engine) }
    @objc private func openPacksFolder() { NSWorkspace.shared.open(Catalog.userPacks) }
    @objc private func chooseSize(_ sender: NSMenuItem) { engine.setSize(CGFloat(sender.tag)) }

    @objc private func toggleHotspot() {
        settings.fileHotspotCentered.toggle()
        engine.applyAll()
    }

    @objc private func togglePause() { engine.togglePause() }
    @objc private func reapply() { engine.applyAll() }
    @objc private func resetAll() { engine.resetToSystem() }

    @objc private func chooseLanguage(_ sender: NSMenuItem) {
        guard let lang = (sender.representedObject as? String).flatMap(Language.init) else { return }
        Language.current = lang
        engine.applyAll()  // обновит галерею
    }

    @objc private func toggleLogin() { Self.toggleLogin() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: L("about.credits"),
                                         attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]),
        ])
    }

    // MARK: Shared actions (меню и галерея)

    static func chooseImage(for role: CursorRole, engine: CursorEngine) {
        let panel = NSOpenPanel()
        panel.title = L("open.image.title", role.title)
        panel.message = L("open.image.message")
        panel.allowedContentTypes = [.image]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard Renderer.render(file: url, size: engine.settings.size, centered: engine.settings.fileHotspotCentered) != nil else {
            alert(L("error.image"), url.lastPathComponent)
            return
        }
        do {
            engine.setStyle(.file(try engine.importFile(url, for: role)), for: role)
        } catch {
            alert(L("error.copy"), error.localizedDescription)
        }
    }

    static func addPack(engine: CursorEngine) {
        let panel = NSOpenPanel()
        panel.title = L("open.pack.title")
        panel.message = L("open.pack.message")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard CursorPack.load(url) != nil else {
            alert(L("error.pack"), L("error.pack.text"))
            return
        }
        do {
            if let set = try engine.importPack(url) { engine.apply(set) }
        } catch {
            alert(L("error.copy"), error.localizedDescription)
        }
    }

    static func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            alert(L("error.login"), error.localizedDescription)
        }
    }

    static func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        a.runModal()
    }

    // MARK: Images

    private static func menuSized(_ image: NSImage) -> NSImage {
        let copy = image.copy() as! NSImage
        copy.size = NSSize(width: 18, height: 18)
        return copy
    }

    /// Стрелка с маленькой «искрой»; на паузе — пунктирная.
    static func icon(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let p = NSBezierPath()
            p.move(to: NSPoint(x: 4, y: 2.5))
            p.line(to: NSPoint(x: 4, y: 14.5))
            p.line(to: NSPoint(x: 7, y: 11.5))
            p.line(to: NSPoint(x: 9.5, y: 16))
            p.line(to: NSPoint(x: 11, y: 15.2))
            p.line(to: NSPoint(x: 8.7, y: 10.8))
            p.line(to: NSPoint(x: 12.8, y: 10.8))
            p.close()
            p.lineWidth = 1.3
            p.lineJoinStyle = .round
            if paused { p.setLineDash([1.6, 2.0], count: 2, phase: 0) }
            NSColor.black.setStroke()
            p.stroke()
            if !paused {
                let s = NSBezierPath()
                s.move(to: NSPoint(x: 14.5, y: 2)); s.line(to: NSPoint(x: 14.5, y: 7))
                s.move(to: NSPoint(x: 12, y: 4.5)); s.line(to: NSPoint(x: 17, y: 4.5))
                s.lineWidth = 1.3
                s.lineCapStyle = .round
                s.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "CursorSwap"
        return image
    }
}
