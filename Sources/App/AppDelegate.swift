import AppKit
import Combine

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = CursorEngine()
    private lazy var menu = StatusMenu(engine: engine)
    private lazy var gallery = GalleryWindowController(engine: engine)
    private let hotKey = HotKey()
    private var changes: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.onOpenGallery = { [weak self] in self?.gallery.show() }
        changes = engine.$revision.sink { [weak self] _ in
            DispatchQueue.main.async { self?.menu.refreshIcon() }
        }

        guard CoreCursor.isAvailable else {
            StatusMenu.alert(L("error.unsupported"), L("error.unsupported.text"))
            return
        }
        engine.applyAll()

        hotKey.onPress = { [weak self] in self?.engine.togglePause() }
        hotKey.register(keyCode: HotKey.pauseKeyCode, modifiers: HotKey.pauseModifiers)

        // После сна, смены мониторов или переключения пользователя WindowServer может вернуть системные курсоры.
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(self, selector: #selector(reapply), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reapply),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Первый запуск — сразу показываем галерею, чтобы было понятно, что делать.
        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            gallery.show()
        }
    }

    /// Повторный запуск из Finder/Launchpad открывает галерею.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        gallery.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        CoreCursor.resetAll()
    }

    @objc private func reapply() {
        engine.applyAll()
    }
}
