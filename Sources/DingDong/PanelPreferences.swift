import Foundation

enum PanelDensity: String, CaseIterable, Codable, Equatable {
    case comfortable
    case compact

    func title(language: AppLanguage) -> String {
        switch (language, self) {
        case (.english, .comfortable):
            "Comfortable"
        case (.chinese, .comfortable):
            "舒展"
        case (.english, .compact):
            "Compact"
        case (.chinese, .compact):
            "紧凑"
        }
    }
}

struct PanelPreferences: Equatable {
    static let defaultBackgroundOpacity = 0.90
    static let minBackgroundOpacity = 0.82
    static let maxBackgroundOpacity = 0.96
    static let backgroundOpacityKey = "dingdong.panel.backgroundOpacity"
    static let densityKey = "dingdong.panel.density"
    static let defaultTabKey = "dingdong.panel.defaultTab"

    var backgroundOpacity: Double
    var density: PanelDensity
    var defaultTab: CompanionTab

    func sanitized() -> PanelPreferences {
        PanelPreferences(
            backgroundOpacity: Self.clampedBackgroundOpacity(backgroundOpacity),
            density: density,
            defaultTab: CompanionTab.mainPanelTabs.contains(defaultTab) ? defaultTab : .today
        )
    }

    static func load(defaults: UserDefaults = .standard) -> PanelPreferences {
        let rawOpacity = defaults.object(forKey: backgroundOpacityKey) == nil
            ? defaultBackgroundOpacity
            : defaults.double(forKey: backgroundOpacityKey)
        let rawDensity = defaults.string(forKey: densityKey)
            .flatMap(PanelDensity.init(rawValue:)) ?? .comfortable
        let rawDefaultTab = defaults.string(forKey: defaultTabKey)
            .flatMap(CompanionTab.init(apiValue:)) ?? .today

        return PanelPreferences(
            backgroundOpacity: rawOpacity,
            density: rawDensity,
            defaultTab: rawDefaultTab
        ).sanitized()
    }

    static func save(_ preferences: PanelPreferences, defaults: UserDefaults = .standard) {
        let sanitized = preferences.sanitized()
        defaults.set(sanitized.backgroundOpacity, forKey: backgroundOpacityKey)
        defaults.set(sanitized.density.rawValue, forKey: densityKey)
        defaults.set(sanitized.defaultTab.apiValue, forKey: defaultTabKey)
    }

    static func clampedBackgroundOpacity(_ value: Double) -> Double {
        min(max(value, minBackgroundOpacity), maxBackgroundOpacity)
    }
}
