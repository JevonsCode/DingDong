import AppKit
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardDetailPopoverView: View {
    var item: ResourceItem
    var language: AppLanguage
    var onCopy: () -> Void
    var onShare: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PanelTheme.textPrimary)
                        .lineLimit(2)

                    Text(item.updatedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(PanelTheme.textTertiary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(IconButtonStyle(size: 28))
                .help(language == .chinese ? "关闭" : "Close")
            }

            detailContent

            HStack(spacing: 8) {
                Button(action: onCopy) {
                    Label(language == .chinese ? "复制" : "Copy", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(ControlButtonStyle(isProminent: true))

                Button(action: onShare) {
                    Label(language == .chinese ? "分享" : "Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(ControlButtonStyle())

                Spacer()
            }
        }
        .padding(14)
        .frame(width: PanelMetrics.detailWidth, height: PanelMetrics.detailHeight)
        .foregroundStyle(PanelTheme.textPrimary)
        .background(PanelTheme.panelBackground(opacity: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PanelTheme.border, lineWidth: 1)
        }
    }

    private var title: String {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        let preview = item.content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return preview.isEmpty ? item.group : preview
    }

    @ViewBuilder
    private var detailContent: some View {
        if let image = previewImage {
            VStack(alignment: .leading, spacing: 8) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 190)
                    .padding(8)
                    .background(PanelTheme.surface, in: RoundedRectangle(cornerRadius: 9))

                ScrollView {
                    Text(item.content.isEmpty ? title : item.content)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(PanelTheme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .frame(maxHeight: 72)
                .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 9))
            }
            .frame(maxHeight: 286)
        } else {
            ScrollView {
                Text(item.content.isEmpty ? title : item.content)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(PanelTheme.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(maxHeight: 286)
            .background(PanelTheme.field, in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private var previewImage: NSImage? {
        guard let url = ClipboardFileReference.imageURL(for: item) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    private var icon: String {
        if item.isSensitiveClipboard {
            return "lock.shield"
        }
        if item.tags.contains("image") {
            return "photo"
        }
        if item.tags.contains("file") {
            return "doc"
        }
        if item.tags.contains("command") {
            return "terminal"
        }
        if item.tags.contains("url") {
            return "link"
        }
        if item.tags.contains("code") || item.tags.contains("json") {
            return "chevron.left.forwardslash.chevron.right"
        }
        if item.tags.contains("path") {
            return "folder"
        }
        return "doc.on.clipboard"
    }

    private var accent: Color {
        if item.isSensitiveClipboard {
            return PanelTheme.danger
        }
        if item.tags.contains("image") {
            return PanelTheme.warning
        }
        if item.tags.contains("file") {
            return PanelTheme.accent
        }
        if item.tags.contains("command") {
            return PanelTheme.success
        }
        if item.tags.contains("url") {
            return PanelTheme.accent
        }
        return PanelTheme.textSecondary
    }
}

struct ClipboardQuickSelectMonitor: NSViewRepresentable {
    var isEnabled: Bool
    var isQuickSelectEnabled: Bool
    var focusedPanelField: PanelFocusField?
    var onCommandStateChange: (Bool) -> Void
    var onNumber: (Int) -> Void
    var onSearch: () -> Void
    var onToggleFilters: () -> Void
    var onTab: (CompanionTab) -> Void
    var onPage: (PanelPageDirection) -> Void
    var onMoveSelection: (ClipboardSelectionDirection) -> Void
    var onPreviewSelection: () -> Void
    var onUseSelection: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = MouseTransparentMonitorView(frame: .zero)
        context.coordinator.install()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncCommandState()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    @MainActor
    final class Coordinator {
        var parent: ClipboardQuickSelectMonitor
        private var monitor: Any?
        private var syncTimer: Timer?
        private var isCommandActive = false

        init(parent: ClipboardQuickSelectMonitor) {
            self.parent = parent
        }

        func install() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                self?.handle(event) ?? event
            }
            syncTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.syncCommandState()
                }
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            syncTimer?.invalidate()
            syncTimer = nil
            setCommandActive(false)
        }

        func syncCommandState() {
            let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            setCommandActive(parent.isEnabled && flags.contains(.command))
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard parent.isEnabled else {
                setCommandActive(false)
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let commandActive = flags.contains(.command)

            if event.type == .flagsChanged || event.type == .keyUp {
                setCommandActive(commandActive)
                return event
            }

            guard event.type == .keyDown else {
                return event
            }
            setCommandActive(commandActive)

            if commandActive, forwardStandardTextEditingCommand(event) {
                return nil
            }

            if commandActive, isTextEditing(event: event) {
                return event
            }

            if commandActive,
               event.matchesCommandCharacter("f") {
                parent.onSearch()
                return nil
            }

            if !commandActive,
               parent.isQuickSelectEnabled,
               parent.focusedPanelField == .clipboardSearch {
                switch event.keyCode {
                case 126:
                    parent.onMoveSelection(.up)
                    return nil
                case 125:
                    parent.onMoveSelection(.down)
                    return nil
                default:
                    break
                }
            }

            if commandActive,
               event.matchesCommandCharacter("r") {
                guard parent.isQuickSelectEnabled else {
                    return event
                }
                parent.onToggleFilters()
                return nil
            }

            guard !isTextEditing(event: event) else {
                return event
            }

            if !commandActive, parent.isQuickSelectEnabled {
                switch event.keyCode {
                case 126:
                    parent.onMoveSelection(.up)
                    return nil
                case 125:
                    parent.onMoveSelection(.down)
                    return nil
                case 49:
                    parent.onPreviewSelection()
                    return nil
                case 36, 76:
                    parent.onUseSelection()
                    return nil
                default:
                    break
                }
            }

            guard commandActive else {
                return event
            }

            guard let characters = event.charactersIgnoringModifiers,
                  characters.count == 1
            else {
                return event
            }

            switch characters.lowercased() {
            case "q":
                parent.onTab(.today)
                return nil
            case "w":
                parent.onTab(.library)
                return nil
            case "e":
                parent.onTab(.clipboard)
                return nil
            case "a":
                parent.onPage(.up)
                return nil
            case "d":
                parent.onPage(.down)
                return nil
            default:
                break
            }

            guard parent.isQuickSelectEnabled,
                  let number = Int(characters),
                  (1...9).contains(number)
            else {
                return event
            }

            parent.onNumber(number)
            return nil
        }

        private func setCommandActive(_ active: Bool) {
            guard isCommandActive != active else {
                return
            }

            isCommandActive = active
            parent.onCommandStateChange(active)
        }

        private func forwardStandardTextEditingCommand(_ event: NSEvent) -> Bool {
            guard let selector = event.standardTextEditingSelector else {
                return false
            }

            return NSApp.sendAction(selector, to: nil, from: nil)
        }

        private func isTextEditing(event: NSEvent? = nil) -> Bool {
            if parent.focusedPanelField != nil {
                return true
            }

            let responders = [
                event?.window?.firstResponder,
                NSApp.keyWindow?.firstResponder,
                NSApp.mainWindow?.firstResponder
            ]

            return responders.contains { responder in
                guard let responder else {
                    return false
                }

                if responder is NSTextView || responder is NSTextField {
                    return true
                }

                let typeName = String(describing: type(of: responder))
                return typeName.contains("TextField") || typeName.contains("FieldEditor")
            }
        }
    }
}

extension NSEvent {
    var standardTextEditingSelector: Selector? {
        guard modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              let characters = charactersIgnoringModifiers,
              characters.count == 1
        else {
            return nil
        }

        switch characters.lowercased() {
        case "a":
            return #selector(NSResponder.selectAll(_:))
        case "c":
            return #selector(NSText.copy(_:))
        case "v":
            return #selector(NSText.paste(_:))
        case "x":
            return #selector(NSText.cut(_:))
        case "z":
            return Selector(("undo:"))
        case "y":
            return Selector(("redo:"))
        default:
            return nil
        }
    }

    func matchesCommandCharacter(_ character: String) -> Bool {
        guard let characters = charactersIgnoringModifiers,
              characters.count == 1
        else {
            return false
        }

        return characters.lowercased() == character.lowercased()
    }
}

final class MouseTransparentMonitorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct WindowDragSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragSurfaceView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class WindowDragSurfaceView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

