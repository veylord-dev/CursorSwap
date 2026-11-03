import Foundation

// MARK: - Localization
// Строки лежат прямо в коде, а не в .lproj: так язык можно переключить на лету из меню,
// без перезапуска приложения.

enum Language: String, CaseIterable {
    case auto, en, ru

    /// Название пункта — на своём языке, чтобы его нашёл тот, кто другой не читает.
    var title: String {
        switch self {
        case .auto: L("language.auto")
        case .en: "English"
        case .ru: "Русский"
        }
    }

    static var current: Language {
        get { Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .auto }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "language") }
    }

    static var isRussian: Bool {
        switch current {
        case .ru: true
        case .en: false
        case .auto: Locale.preferredLanguages.first?.hasPrefix("ru") ?? false
        }
    }
}

func L(_ key: String) -> String {
    guard let s = strings[key] else { return key }
    return Language.isRussian ? s.ru : s.en
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}

/// Есть ли перевод для ключа (для названий наборов: у своих наборов его нет — показываем имя папки).
func hasL(_ key: String) -> Bool { strings[key] != nil }

private let strings: [String: (en: String, ru: String)] = [
    // Общее
    "language.auto": ("System language", "Как в системе"),
    "menu.language": ("Language", "Язык"),
    "menu.gallery": ("Cursor Gallery…", "Галерея курсоров…"),
    "menu.sets": ("Cursor Sets", "Наборы курсоров"),
    "menu.sets.builtIn": ("Built-in", "Встроенные"),
    "menu.sets.mine": ("My Sets", "Мои наборы"),
    "menu.sets.add": ("Add Set from Folder…", "Добавить набор из папки…"),
    "menu.sets.openFolder": ("Show My Sets in Finder", "Показать мои наборы в Finder"),
    "menu.customize": ("Customize Individually", "Настроить по отдельности"),
    "menu.system": ("System", "Системный"),
    "menu.fromSet": ("From a Set", "Из набора"),
    "menu.customImage": ("Custom Image…", "Своя картинка…"),
    "menu.customImage.current": ("Custom Image (%@)…", "Своя картинка (%@)…"),
    "menu.size": ("Size", "Размер"),
    "menu.size.item": ("%@ (%d pt)", "%@ (%d pt)"),
    "menu.hotspotCenter": ("Custom Image Clicks at Center", "Своя картинка кликает центром"),
    "menu.hotspotCenter.tip": ("Off: the top-left corner of the image is the click point, like an arrow.",
                               "Выключено — кликает левый верхний угол картинки, как у стрелки."),
    "menu.pause": ("Pause (Show System Cursors)", "Пауза (показать системные)"),
    "menu.reapply": ("Reapply", "Применить заново"),
    "menu.reset": ("Restore System Cursors", "Вернуть системные курсоры"),
    "menu.login": ("Open at Login", "Запускать при входе"),
    "menu.about": ("About CursorSwap", "О программе CursorSwap"),
    "menu.quit": ("Quit (Restores System Cursors)", "Выход (вернёт системные курсоры)"),
    "status.current": ("Set: %@", "Набор: %@"),
    "status.custom": ("Set: custom mix", "Набор: своя комбинация"),
    "status.system": ("System cursors", "Системные курсоры"),
    "status.paused": ("Paused — system cursors shown", "Пауза — показаны системные"),

    // Размеры
    "size.24": ("Small", "Маленький"),
    "size.32": ("Normal", "Обычный"),
    "size.48": ("Large", "Большой"),
    "size.64": ("Huge", "Огромный"),
    "size.96": ("Giant", "Гигантский"),

    // Роли
    "role.arrow": ("Arrow", "Стрелка"),
    "role.hand": ("Hand (Links)", "Рука (ссылки)"),
    "role.text": ("Text (I-beam)", "Текст (I-beam)"),
    "role.working": ("Working in Background", "Работает в фоне"),
    "role.unavailable": ("Not Allowed", "Запрещено"),
    "role.cross": ("Crosshair", "Прицел"),
    "role.move": ("Move", "Перемещение"),
    "role.help": ("Help", "Справка"),
    "role.horizontal": ("Resize Left–Right", "Размер влево-вправо"),
    "role.vertical": ("Resize Up–Down", "Размер вверх-вниз"),
    "role.diagonal1": ("Resize Diagonal ↖↘", "Размер по диагонали ↖↘"),
    "role.diagonal2": ("Resize Diagonal ↗↙", "Размер по диагонали ↗↙"),

    // Нарисованные наборы
    "set.classic": ("Classic", "Классический"),
    "set.classic.dark": ("Classic Dark", "Классический тёмный"),
    "set.mini": ("Mini", "Мини"),
    "set.mini.light": ("Mini Light", "Мини светлый"),
    "set.aurora": ("Aurora", "Аврора"),

    // Встроенные наборы Windows (папки в Packs/)
    "pack.Windows 11 Light": ("Windows 11 Light", "Windows 11 светлый"),
    "pack.Windows 11 Dark": ("Windows 11 Dark", "Windows 11 тёмный"),
    "pack.macOS Style": ("macOS Style", "Стиль macOS"),
    "pack.Vision White": ("Vision White", "Vision белый"),
    "pack.Vision Black": ("Vision Black", "Vision чёрный"),
    "pack.Material Light": ("Material Light", "Material светлый"),
    "pack.Material Dark": ("Material Dark", "Material тёмный"),
    "pack.Material Dark Mini": ("Material Dark Mini", "Material тёмный мини"),
    "pack.Windows 10X": ("Windows 10X", "Windows 10X"),
    "pack.Windows 10X Mini": ("Windows 10X Mini", "Windows 10X мини"),
    "pack.Windows 10X Large": ("Windows 10X Large", "Windows 10X крупный"),

    // Пресеты
    "tint.white": ("White", "белая"), "tint.black": ("Black", "чёрная"), "tint.red": ("Red", "красная"),
    "tint.yellow": ("Yellow", "жёлтая"), "tint.neon": ("Neon", "неоновая"), "tint.pink": ("Pink", "розовая"),
    "tone.graphite": ("graphite", "графит"), "tone.light": ("light", "светлый"), "tone.accent": ("blue", "синий"),
    "shape.arrow": ("arrow", "стрелка"), "shape.hand": ("hand", "рука"), "shape.beam": ("I-beam", "I-beam"),
    "preset.classic": ("Classic %@", "Классический: %@"),
    "preset.classic.dark": ("Classic dark %@", "Классический тёмный: %@"),
    "preset.mini": ("Mini, %@", "Мини, %@"),
    "preset.aurora": ("Aurora %@", "Аврора: %@"),
    "preset.arrow": ("%@ arrow", "Стрелка %@"),
    "preset.ibeam": ("%@ I-beam", "Курсор %@"),
    "preset.dot": ("Dot", "Точка"),
    "preset.ring": ("Ring", "Кольцо"),
    "preset.crosshair": ("Crosshair", "Прицел"),

    // Галерея
    "gallery.title": ("CursorSwap Gallery", "Галерея CursorSwap"),
    "gallery.subtitle": ("Click a set to apply it to every app.", "Нажмите на набор, чтобы применить его во всех программах."),
    "gallery.size": ("Size", "Размер"),
    "gallery.empty": ("Add your own Windows cursor folders (.cur / .ani) here.",
                      "Сюда можно добавить свои папки с курсорами Windows (.cur / .ani)."),
    "gallery.roles": ("%d cursors", "Курсоров: %d"),
    "gallery.animated": ("animated", "с анимацией"),
    "gallery.delete": ("Delete Set", "Удалить набор"),
    "gallery.reveal": ("Show in Finder", "Показать в Finder"),
    "gallery.active": ("Active", "Включён"),

    // Окна выбора и ошибки
    "open.image.title": ("Image for “%@”", "Картинка для «%@»"),
    "open.image.message": ("A PNG with a transparent background looks best. GIF/APNG will be animated.",
                           "Лучше всего смотрится PNG с прозрачным фоном. GIF/APNG будут анимированными."),
    "open.pack.title": ("Folder with Windows Cursors", "Папка с курсорами Windows"),
    "open.pack.message": ("Choose a folder with .cur / .ani files (and Install.inf if there is one).",
                          "Выберите папку с файлами .cur / .ani (и Install.inf, если он есть)."),
    "error.unsupported": ("This macOS version can’t replace cursors", "Эта версия macOS не поддерживает подмену курсора"),
    "error.unsupported.text": ("The required private CoreGraphics functions were not found.",
                               "Не найдены нужные системные функции CoreGraphics."),
    "error.image": ("Couldn’t open the image", "Не получилось открыть картинку"),
    "error.copy": ("Couldn’t copy the file", "Не получилось скопировать файл"),
    "error.pack": ("No usable cursors in this folder", "В папке нет подходящих курсоров"),
    "error.pack.text": ("It needs .cur or .ani files, including a normal arrow.",
                        "Нужны файлы .cur или .ani, среди них — обычная стрелка."),
    "error.login": ("Couldn’t change Open at Login", "Не удалось изменить автозапуск"),
    "about.credits": ("Cursor sets: Windows 11 Concept and Material by JepriCreations, Vision by Darques, Windows 10X by alexgal (collected by Markella’s). Cursor replacement technique from Mousecape by Alex Zielenski.",
                      "Наборы: Windows 11 Concept и Material — JepriCreations, Vision — Darques, Windows 10X — alexgal (сборка Markella’s). Способ подмены курсора — из Mousecape (Alex Zielenski)."),
]
