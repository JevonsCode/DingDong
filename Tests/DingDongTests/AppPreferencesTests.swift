import Foundation
import Testing
@testable import DingDong

@MainActor
struct AppPreferencesTests {
    @Test func appPreferencesRoundTripTypedValues() throws {
        let suiteName = "dingdong-app-preferences-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let preferences = AppPreferences(defaults: defaults)

        preferences.language = .chinese
        preferences.isClipboardMonitoringEnabled = true
        preferences.customSoundPath = "/tmp/ding.wav"
        preferences.saveClipboardFilterPreferences(ClipboardFilterPreferences(
            filterOrder: [.url, .command],
            groupOrder: ["Commands", "URLs"]
        ))
        preferences.savePanelPreferences(PanelPreferences(
            backgroundOpacity: 0.91,
            density: .compact,
            defaultTab: .clipboard
        ))

        #expect(preferences.language == .chinese)
        #expect(preferences.isClipboardMonitoringEnabled == true)
        #expect(preferences.customSoundPath == "/tmp/ding.wav")
        #expect(preferences.loadClipboardFilterPreferences().filterOrder == [.url, .command])
        #expect(preferences.loadClipboardFilterPreferences().groupOrder == ["Commands", "URLs"])
        #expect(preferences.loadPanelPreferences().density == .compact)
        #expect(preferences.loadPanelPreferences().defaultTab == .clipboard)
    }
}

@MainActor
struct ClipboardMonitoringServiceTests {
    @Test func clipboardMonitoringServiceCallsHandlerOnlyWhenChangeCountMoves() {
        let reader = MutableClipboardReader(changeCount: 10)
        var captures = 0
        let service = ClipboardMonitoringService(reader: reader) {
            captures += 1
        }

        service.start()
        service.pollForChanges()
        #expect(captures == 0)

        reader.changeCount = 11
        service.pollForChanges()
        service.pollForChanges()

        #expect(captures == 1)
        #expect(service.isRunning == true)

        service.stop()

        #expect(service.isRunning == false)
    }
}

private final class MutableClipboardReader: ClipboardReading {
    var changeCount: Int

    init(changeCount: Int) {
        self.changeCount = changeCount
    }

    func stringValue() -> String? {
        nil
    }

    func fileURLs() -> [URL] {
        []
    }

    func imageData() -> ClipboardImageData? {
        nil
    }
}
