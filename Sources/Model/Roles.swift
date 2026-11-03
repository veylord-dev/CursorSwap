import Foundation

// MARK: - Cursor roles
// Одна роль = один «смысл» курсора (стрелка, рука, запрет…) и все имена в WindowServer,
// под которыми macOS его ищет. Первые три роли можно настраивать по отдельности (слоты),
// остальные приходят только из наборов Windows.

enum CursorRole: String, CaseIterable {
    case arrow, hand, text, working, unavailable, cross, move, help, horizontal, vertical, diagonal1, diagonal2

    static let slots: [CursorRole] = [.arrow, .hand, .text]
    var isSlot: Bool { Self.slots.contains(self) }

    var title: String { L("role." + rawValue) }

    /// Имена курсоров (список из Mousecape, MCDefs.m). Стрелка и I-beam — и старые имена (macOS 14–15),
    /// и новые *S (macOS 26+). Кроме них берём только com.apple.cursor.N: их CoreCursorUnregisterAll
    /// корректно откатывает, а системные Wait/Copy/Move после подмены вернуть нечем.
    var cursorNames: [String] {
        switch self {
        case .arrow: ["com.apple.coregraphics.ArrowS", "com.apple.coregraphics.Arrow"]
        case .hand: ["com.apple.cursor.13"]
        case .text: ["com.apple.coregraphics.IBeamS", "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamXOR"]
        case .working: ["com.apple.cursor.4"]
        case .unavailable: ["com.apple.cursor.3"]
        case .cross: ["com.apple.cursor.7", "com.apple.cursor.8"]
        case .move: ["com.apple.cursor.39"]
        case .help: ["com.apple.cursor.40"]
        case .horizontal: [17, 18, 19, 27, 28, 38].map { "com.apple.cursor.\($0)" }
        case .vertical: [21, 22, 23, 31, 32, 36].map { "com.apple.cursor.\($0)" }
        case .diagonal1: [33, 34, 35].map { "com.apple.cursor.\($0)" }
        case .diagonal2: [29, 30, 37].map { "com.apple.cursor.\($0)" }
        }
    }

    /// Ключ роли в разделе реестра Install.inf.
    var registryKey: String {
        switch self {
        case .arrow: "arrow"
        case .hand: "hand"
        case .text: "ibeam"
        case .working: "appstarting"
        case .unavailable: "no"
        case .cross: "crosshair"
        case .move: "sizeall"
        case .help: "help"
        case .horizontal: "sizewe"
        case .vertical: "sizens"
        case .diagonal1: "sizenwse"
        case .diagonal2: "sizenesw"
        }
    }

    /// Запасной вариант, если в .inf нет схемы: части имён файлов.
    var fileHints: [String] {
        switch self {
        case .arrow: ["pointer", "normal", "arrow"]
        case .hand: ["link", "hand"]
        case .text: ["text", "beam"]
        case .working: ["working", "work", "appstarting"]
        case .unavailable: ["unavail", "forbidden"]
        case .cross: ["precision", "cross"]
        case .move: ["move", "sizeall"]
        case .help: ["help"]
        case .horizontal: ["horz", "horizontal", "sizewe"]
        case .vertical: ["vert", "sizens"]
        case .diagonal1: ["dgn1", "diagonal resize 1", "sizenwse"]
        case .diagonal2: ["dgn2", "diagonal resize 2", "sizenesw"]
        }
    }

    /// Нарисованные варианты для ручной настройки слота.
    var presets: [Preset] {
        switch self {
        case .arrow, .hand:
            [.windows(.arrow, dark: false), .windows(.hand, dark: false), .windows(.arrow, dark: true), .windows(.hand, dark: true),
             .minimal(.graphite), .minimal(.light), .minimal(.accent),
             .aurora(.arrow), .aurora(.hand),
             .arrow(.white), .arrow(.black), .arrow(.red), .arrow(.yellow), .arrow(.neon), .arrow(.pink),
             .dot, .ring, .crosshair]
        case .text:
            [.windows(.beam, dark: false), .windows(.beam, dark: true),
             .minimalBeam(.graphite), .minimalBeam(.light), .minimalBeam(.accent), .aurora(.beam),
             .ibeam(.black), .ibeam(.white), .ibeam(.red), .ibeam(.neon), .crosshair]
        default: []
        }
    }
}
