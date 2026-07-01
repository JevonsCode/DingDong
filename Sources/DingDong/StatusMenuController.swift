import AppKit

@MainActor
final class StatusMenuController: NSObject {
    var language: AppLanguage = .english
    var isClipboardMonitoring = false
    var onOpenPanel: (() -> Void)?
    var onOpenClipboard: (() -> Void)?
    var onOpenResourceManager: (() -> Void)?
    var onToggleClipboardMonitoring: (() -> Void)?
    var onOpenUsageGuide: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    func show(from statusItem: NSStatusItem) {
        guard let button = statusItem.button else {
            return
        }

        let menu = NSMenu()
        menu.addItem(menuItem(title: title(.openPanel), action: #selector(openPanel)))
        menu.addItem(menuItem(title: title(.openClipboard), action: #selector(openClipboard)))
        menu.addItem(menuItem(title: title(.resourceManager), action: #selector(openResourceManager)))
        menu.addItem(menuItem(title: title(.toggleClipboardMonitoring), action: #selector(toggleClipboardMonitoring)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: title(.usageGuide), action: #selector(openUsageGuide)))
        menu.addItem(menuItem(title: title(.settings), action: #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: title(.quit), action: #selector(quit)))

        button.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        button.highlight(false)
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private enum Action {
        case openPanel
        case openClipboard
        case resourceManager
        case toggleClipboardMonitoring
        case usageGuide
        case settings
        case quit
    }

    private func title(_ action: Action) -> String {
        switch (language, action) {
        case (.chinese, .openPanel):
            "打开面板"
        case (.english, .openPanel):
            "Open Panel"
        case (.chinese, .openClipboard):
            "打开剪贴板"
        case (.english, .openClipboard):
            "Open Clipboard"
        case (.chinese, .resourceManager):
            "资源管理"
        case (.english, .resourceManager):
            "Resource Manager"
        case (.chinese, .toggleClipboardMonitoring):
            isClipboardMonitoring ? "关闭剪贴板监听" : "开启剪贴板监听"
        case (.english, .toggleClipboardMonitoring):
            isClipboardMonitoring ? "Stop Clipboard Monitoring" : "Start Clipboard Monitoring"
        case (.chinese, .usageGuide):
            "使用说明"
        case (.english, .usageGuide):
            "User Guide"
        case (.chinese, .settings):
            "设置"
        case (.english, .settings):
            "Settings"
        case (.chinese, .quit):
            "退出"
        case (.english, .quit):
            "Quit"
        }
    }

    @objc private func openPanel() {
        onOpenPanel?()
    }

    @objc private func openClipboard() {
        onOpenClipboard?()
    }

    @objc private func openResourceManager() {
        onOpenResourceManager?()
    }

    @objc private func toggleClipboardMonitoring() {
        onToggleClipboardMonitoring?()
    }

    @objc private func openUsageGuide() {
        onOpenUsageGuide?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
