@testable import ClipDockCore
import XCTest

final class SettingsStoreTests: XCTestCase {
    func testLoadReturnsDefaultsWhenNoSettingsAreStored() {
        let suiteName = uniqueSuiteName()
        let defaults = cleanDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)

        XCTAssertEqual(store.load(), .defaults)
    }

    func testSaveRoundTripsSettings() {
        let suiteName = uniqueSuiteName()
        let defaults = cleanDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        var settings = UserSettings.defaults
        settings.recordingPaused = true
        settings.maxHistoryCount = 2_000

        store.save(settings)

        XCTAssertEqual(UserDefaultsSettingsStore(defaults: defaults).load(), settings)
    }

    func testLoadFallsBackToDefaultsWhenStoredDataIsCorrupt() {
        let suiteName = uniqueSuiteName()
        let defaults = cleanDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "ClipDock.UserSettings")

        let settings = UserDefaultsSettingsStore(defaults: defaults).load()

        XCTAssertEqual(settings, .defaults)
    }

    func testConfiguredStoreUsesEnvironmentSuite() {
        let suiteName = uniqueSuiteName()
        let defaults = cleanDefaults(suiteName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = UserSettings.defaults
        settings.lowPowerPolling = true

        UserDefaultsSettingsStore
            .configured(environment: ["CLIPDOCK_SETTINGS_SUITE": suiteName])
            .save(settings)

        XCTAssertEqual(UserDefaultsSettingsStore(defaults: defaults).load(), settings)
    }

    private func uniqueSuiteName() -> String {
        "ClipDockTests.\(UUID().uuidString)"
    }

    private func cleanDefaults(suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
