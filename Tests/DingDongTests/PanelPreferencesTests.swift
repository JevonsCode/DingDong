import Foundation
import Testing
@testable import DingDong

struct PanelPreferencesTests {
    @Test func panelPreferencesDefaultOpacityIsSubtlyTranslucent() throws {
        let suiteName = "dingdong-panel-preferences-default-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let loaded = PanelPreferences.load(defaults: defaults)

        #expect(loaded.backgroundOpacity == PanelPreferences.defaultBackgroundOpacity)
        #expect(loaded.backgroundOpacity < 1.0)
    }

    @Test func panelPreferencesClampAndPersistUserDefaults() throws {
        let suiteName = "dingdong-panel-preferences-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        PanelPreferences.save(
            PanelPreferences(
                backgroundOpacity: 0.2,
                density: .compact,
                defaultTab: .api
            ),
            defaults: defaults
        )

        let loaded = PanelPreferences.load(defaults: defaults)

        #expect(loaded.backgroundOpacity == PanelPreferences.minBackgroundOpacity)
        #expect(loaded.density == .compact)
        #expect(loaded.defaultTab == .today)
    }
}
