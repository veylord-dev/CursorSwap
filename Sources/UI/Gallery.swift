import AppKit
import SwiftUI

// MARK: - Gallery window
// Все наборы карточками с превью курсоров; клик — применить.

final class GalleryWindowController {
    private let engine: CursorEngine
    private var window: NSWindow?

    init(engine: CursorEngine) { self.engine = engine }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 520, height: 420)
            w.contentView = NSHostingView(rootView: GalleryView(engine: engine))
            w.center()
            w.setFrameAutosaveName("CursorSwapGallery")
            window = w
        }
        window?.title = L("gallery.title")
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Значение ползунка, пока его тянут (применяем, только когда отпустили).
/// Обычный ObservableObject вместо @State: макросы SwiftUI недоступны при сборке голым swiftc.
final class SliderModel: ObservableObject {
    @Published var size: Double
    init(_ size: Double) { self.size = size }
}

struct GalleryView: View {
    @ObservedObject var engine: CursorEngine
    @ObservedObject private var slider: SliderModel

    init(engine: CursorEngine) {
        self.engine = engine
        slider = SliderModel(Double(engine.settings.size))
    }

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        // revision меняется при любом изменении — по нему пересчитываются тексты и галочки.
        let _ = engine.revision
        let current = engine.currentSet?.id
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(L("menu.sets.builtIn"), engine.catalog.builtInSets, current: current)
                    section(L("menu.sets.mine"), engine.catalog.userSets, current: current, footer: true)
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { slider.size = Double(engine.settings.size) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("gallery.title")).font(.title2.weight(.semibold))
                Text(L("gallery.subtitle")).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(isOn: Binding(get: { engine.settings.paused }, set: { _ in engine.togglePause() })) {
                Text(L("menu.pause")).help(HotKey.pauseDisplay)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func section(_ title: String, _ sets: [CursorSet], current: String?, footer: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if footer {
                    Button(L("menu.sets.add")) { StatusMenu.addPack(engine: engine) }
                        .controlSize(.small)
                }
            }
            if sets.isEmpty {
                Text(L("gallery.empty")).font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4])))
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(sets, id: \.id) { set in
                        SetCard(set: set, active: set.id == current, catalog: engine.catalog)
                            .onTapGesture { engine.apply(set) }
                            .contextMenu { contextMenu(for: set) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for set: CursorSet) -> some View {
        if case .pack(let pack) = set {
            Button(L("gallery.reveal")) { NSWorkspace.shared.activateFileViewerSelecting([pack.folder]) }
            if !pack.isBuiltIn {
                Button(L("gallery.delete"), role: .destructive) { engine.deletePack(pack) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text(L("gallery.size"))
            Slider(value: $slider.size, in: Double(Settings.sizeRange.lowerBound)...Double(Settings.sizeRange.upperBound), step: 4,
                   onEditingChanged: { editing in if !editing { engine.setSize(CGFloat(slider.size)) } })
            .frame(maxWidth: 220)
            Text("\(Int(slider.size)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            Spacer()
            Picker("", selection: Binding(get: { Language.current }, set: { Language.current = $0; engine.applyAll() })) {
                ForEach(Language.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
            Button(L("menu.reset")) { engine.resetToSystem() }
        }
        .controlSize(.small)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct SetCard: View {
    let set: CursorSet
    let active: Bool
    let catalog: Catalog

    private func icon(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
    }

    /// Какие курсоры показывать в превью.
    private var shown: [CursorRole] {
        let order: [CursorRole] = [.arrow, .hand, .text, .working, .unavailable]
        return order.filter { set.roles.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(shown, id: \.self) { role in
                    if let image = catalog.preview(set, role) { icon(image).help(role.title) }
                }
                Spacer(minLength: 0)
                // Та же стрелка на тёмном — видно, как курсор смотрится на любом фоне.
                if let arrow = catalog.preview(set, .arrow) {
                    icon(arrow)
                        .padding(7)
                        .background(Color(white: 0.2), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(8)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 54)
            .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 6) {
                Text(set.title).font(.body.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                if active {
                    Label(L("gallery.active"), systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.accentColor)
                        .help(L("gallery.active"))
                }
            }
            HStack(spacing: 6) {
                Text(L("gallery.roles", set.roles.count))
                if set.isAnimated { Text("·"); Text(L("gallery.animated")) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(active ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: active ? 2 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
