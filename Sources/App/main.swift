import AppKit

// Режим командной строки — для скриптов и проверки:
//   CursorSwap --list                 список наборов (id и название)
//   CursorSwap --set <id>             поставить набор и выйти (курсоры держатся до выхода из системы)
//   CursorSwap --apply                применить сохранённые настройки и выйти
//   CursorSwap --reset                вернуть системные курсоры и выйти
//   CursorSwap --export <id> <папка>  сохранить все курсоры набора в PNG (2x)
let args = CommandLine.arguments
if args.count > 1 {
    let engine = CursorEngine()
    switch args[1] {
    case "--list":
        for set in engine.catalog.sets { print(set.id, "—", set.title, "(\(set.roles.count))") }
    case "--set" where args.count > 2:
        guard let set = engine.catalog.set(args[2]) else { print("Unknown set:", args[2]); exit(1) }
        engine.apply(set)
    case "--apply": engine.applyAll()
    case "--reset": CoreCursor.resetAll()
    case "--export" where args.count > 3:
        guard let set = engine.catalog.set(args[2]) else { print("Unknown set:", args[2]); exit(1) }
        let out = URL(fileURLWithPath: args[3])
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for role in set.roles {
            guard let style = set.style(for: role), let r = engine.render(style, role: role) else { print(role, "—"); continue }
            print(role.rawValue, r.size, "hotspot", r.hotspot, "frames", r.frames)
            try? NSBitmapImageRep(cgImage: r.images[1]).representation(using: .png, properties: [:])?
                .write(to: out.appendingPathComponent(role.rawValue + ".png"))
        }
    default:
        print("Usage: CursorSwap [--list | --set <id> | --apply | --reset | --export <id> <folder>]")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
