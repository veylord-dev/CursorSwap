import AppKit

// MARK: - Drawn presets
// Курсоры, которые программа рисует сама (векторно, под любой размер).
// id пресетов хранятся в настройках — не переименовывать.

enum Tint: String, CaseIterable {
    case white, black, red, yellow, neon, pink

    var title: String { L("tint." + rawValue) }

    var fill: NSColor {
        switch self {
        case .white: .white
        case .black: .black
        case .red: NSColor(srgbRed: 0.93, green: 0.18, blue: 0.2, alpha: 1)
        case .yellow: NSColor(srgbRed: 1, green: 0.83, blue: 0.1, alpha: 1)
        case .neon: NSColor(srgbRed: 0.2, green: 1, blue: 0.45, alpha: 1)
        case .pink: NSColor(srgbRed: 1, green: 0.42, blue: 0.75, alpha: 1)
        }
    }

    var outline: NSColor { self == .black ? .white : .black }
}

/// Тона минималистичного набора «Мини».
enum Tone: String, CaseIterable {
    case graphite, light, accent

    var title: String { L("tone." + rawValue) }

    var fill: NSColor {
        switch self {
        case .graphite: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1)
        case .light: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
        case .accent: NSColor(srgbRed: 0.31, green: 0.49, blue: 1, alpha: 1)
        }
    }

    var outline: NSColor { self == .light ? NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 0.9) : .white }
}

/// Фигуры для наборов из трёх курсоров: стрелка, рука-указатель, I-beam.
enum WinShape: String {
    case arrow, hand, beam

    var title: String { L("shape." + rawValue) }
}

enum Preset: Equatable {
    case windows(WinShape, dark: Bool)
    case minimal(Tone), minimalBeam(Tone)
    case aurora(WinShape)
    case arrow(Tint), ibeam(Tint), dot, ring, crosshair

    var id: String {
        switch self {
        case .windows(let shape, let dark): "win.\(shape.rawValue).\(dark ? "dark" : "light")"
        case .minimal(let t): "minimal.\(t.rawValue)"
        case .minimalBeam(let t): "minibeam.\(t.rawValue)"
        case .aurora(let shape): "aurora.\(shape.rawValue)"
        case .arrow(let t): "arrow.\(t.rawValue)"
        case .ibeam(let t): "ibeam.\(t.rawValue)"
        case .dot: "dot"
        case .ring: "ring"
        case .crosshair: "crosshair"
        }
    }

    init?(id: String) {
        let parts = id.split(separator: ".").map(String.init)
        switch parts.first {
        case "win":
            guard parts.count == 3, let shape = WinShape(rawValue: parts[1]) else { return nil }
            self = .windows(shape, dark: parts[2] == "dark")
        case "minimal": guard let t = parts.last.flatMap(Tone.init) else { return nil }; self = .minimal(t)
        case "minibeam": guard let t = parts.last.flatMap(Tone.init) else { return nil }; self = .minimalBeam(t)
        case "aurora": guard let s = parts.last.flatMap(WinShape.init) else { return nil }; self = .aurora(s)
        case "arrow": guard let t = parts.last.flatMap(Tint.init) else { return nil }; self = .arrow(t)
        case "ibeam": guard let t = parts.last.flatMap(Tint.init) else { return nil }; self = .ibeam(t)
        case "dot": self = .dot
        case "ring": self = .ring
        case "crosshair": self = .crosshair
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .windows(let shape, let dark): L(dark ? "preset.classic.dark" : "preset.classic", shape.title)
        case .minimal(let t), .minimalBeam(let t): L("preset.mini", t.title)
        case .aurora(let shape): L("preset.aurora", shape.title)
        case .arrow(let t): L("preset.arrow", t.title)
        case .ibeam(let t): L("preset.ibeam", t.title)
        case .dot: L("preset.dot")
        case .ring: L("preset.ring")
        case .crosshair: L("preset.crosshair")
        }
    }

    /// Точка клика в сетке 32×32.
    var hotspot: CGPoint {
        switch self {
        case .arrow, .windows(.arrow, _): CGPoint(x: 3, y: 2)
        case .minimal, .aurora(.arrow): CGPoint(x: 5, y: 4)
        case .windows(.hand, _), .aurora(.hand): CGPoint(x: 12.5, y: 2.5)
        default: CGPoint(x: 16, y: 16)
        }
    }
}
