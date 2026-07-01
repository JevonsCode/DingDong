import Foundation

struct ClipboardFilterPreferences: Equatable {
    var filterOrder: [ClipboardSmartFilter]
    var groupOrder: [String]
}

final class AppPreferences: @unchecked Sendable {
    static let shared = AppPreferences()

    private enum Key {
        static let clipboardMonitoring = "dingdong.clipboard.monitoring"
        static let language = "dingdong.language"
        static let clipboardFilterOrder = "dingdong.clipboard.filterOrder"
        static let clipboardGroupOrder = "dingdong.clipboard.groupOrder"
        static let customSoundPath = "dingdong.customSoundPath"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isClipboardMonitoringEnabled: Bool {
        get {
            defaults.bool(forKey: Key.clipboardMonitoring)
        }
        set {
            defaults.set(newValue, forKey: Key.clipboardMonitoring)
        }
    }

    var language: AppLanguage? {
        get {
            defaults.string(forKey: Key.language).flatMap(AppLanguage.init(rawValue:))
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Key.language)
            } else {
                defaults.removeObject(forKey: Key.language)
            }
        }
    }

    var customSoundPath: String? {
        get {
            defaults.string(forKey: Key.customSoundPath)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.customSoundPath)
            } else {
                defaults.removeObject(forKey: Key.customSoundPath)
            }
        }
    }

    func loadPanelPreferences() -> PanelPreferences {
        PanelPreferences.load(defaults: defaults)
    }

    func savePanelPreferences(_ preferences: PanelPreferences) {
        PanelPreferences.save(preferences, defaults: defaults)
    }

    func loadClipboardFilterPreferences() -> ClipboardFilterPreferences {
        let filterValues = defaults.stringArray(forKey: Key.clipboardFilterOrder) ?? []
        let filters = filterValues.compactMap(ClipboardSmartFilter.init(rawValue:))
        let groups = defaults.stringArray(forKey: Key.clipboardGroupOrder) ?? []
        return ClipboardFilterPreferences(filterOrder: filters, groupOrder: groups)
    }

    func saveClipboardFilterPreferences(_ preferences: ClipboardFilterPreferences) {
        defaults.set(preferences.filterOrder.map(\.rawValue), forKey: Key.clipboardFilterOrder)
        defaults.set(preferences.groupOrder, forKey: Key.clipboardGroupOrder)
    }
}
