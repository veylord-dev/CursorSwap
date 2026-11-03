# CursorSwap

[English](#english) · [Русский](#русский)

## English

macOS menu bar app that replaces the mouse cursor in every app. macOS 14+, tested on macOS 27.

**Features**
- 16 built-in sets: 5 drawn (Aurora, Mini, Mini Light, Classic, Classic Dark) and 11 Windows packs.
- Windows `.cur` / `.ani` support, including animated cursors. Up to 12 cursors per set.
- Add your own Windows cursor folder; roles are read from `Install.inf` or file names.
- Per-cursor setup for arrow, hand and I-beam: drawn variant, cursor from any set, or your image (PNG, SVG, GIF/APNG…).
- Gallery window, size 16–128 pt, pause with `⌃⌥⌘C`, English/Russian UI.
- Quit or “Restore System Cursors” brings back the originals.

**Build**
```bash
./build.sh && open build/CursorSwap.app
```

**CLI:** `--list`, `--set <id>`, `--apply`, `--reset`, `--export <id> <folder>`.

**How it works:** private WindowServer API `CGSRegisterCursorWithImages`, as in [Mousecape](https://github.com/alexzielenski/Mousecape). On macOS 26+ the arrow and I-beam live under `ArrowS` / `IBeamS` ([SnowGlow-aww/Mousecape](https://github.com/SnowGlow-aww/Mousecape)); originals are restored from `SkyLight.framework/Resources/CursorAsset`. No SIP changes.

**Limitations:** private API may break with macOS updates. Games, Java and some Electron apps draw their own cursor. The wait “beach ball” is not replaced.

## Русский

Приложение для строки меню macOS: меняет курсор во всех программах. macOS 14+, проверено на macOS 27.

**Возможности**
- 16 встроенных наборов: 5 нарисованных (Аврора, Мини, Мини светлый, Классический, Классический тёмный) и 11 наборов Windows.
- Поддержка Windows `.cur` / `.ani`, включая анимацию. До 12 курсоров в наборе.
- Свои папки с курсорами Windows; роли берутся из `Install.inf` или по именам файлов.
- Отдельная настройка стрелки, руки и I-beam: нарисованный вариант, курсор из набора или своя картинка (PNG, SVG, GIF/APNG…).
- Галерея, размер 16–128 pt, пауза `⌃⌥⌘C`, интерфейс на русском и английском.
- Выход или «Вернуть системные курсоры» возвращают оригиналы.

**Сборка**
```bash
./build.sh && open build/CursorSwap.app
```

**Командная строка:** `--list`, `--set <id>`, `--apply`, `--reset`, `--export <id> <папка>`.

**Как работает:** приватный API WindowServer `CGSRegisterCursorWithImages`, как в [Mousecape](https://github.com/alexzielenski/Mousecape). В macOS 26+ стрелка и I-beam — под именами `ArrowS` / `IBeamS` ([SnowGlow-aww/Mousecape](https://github.com/SnowGlow-aww/Mousecape)); оригиналы восстанавливаются из `SkyLight.framework/Resources/CursorAsset`. SIP не трогается.

**Ограничения:** приватный API может сломаться с обновлением macOS. Игры, Java и часть Electron-приложений рисуют курсор сами. «Мяч» ожидания не заменяется.

## Credits / Авторы наборов

Cursor sets in `Packs/` belong to their authors / Наборы в `Packs/` принадлежат авторам:
Windows 11 Concept, Material Design — JepriCreations; Vision — Darques; Windows 10X — alexgal; collection — Markella's.
