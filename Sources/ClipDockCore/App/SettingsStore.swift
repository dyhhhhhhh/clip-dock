import Foundation

public protocol SettingsStore {
    func load() -> UserSettings
    func save(_ settings: UserSettings)
}

public final class UserDefaultsSettingsStore: SettingsStore {
    public static let environmentSuiteKey = "CLIPDOCK_SETTINGS_SUITE"

    private let defaults: UserDefaults
    private let key = "ClipDock.UserSettings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public static func configured(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UserDefaultsSettingsStore {
        guard let suiteName = environment[environmentSuiteKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !suiteName.isEmpty,
              let defaults = UserDefaults(suiteName: suiteName)
        else {
            return UserDefaultsSettingsStore()
        }

        return UserDefaultsSettingsStore(defaults: defaults)
    }

    public func load() -> UserSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder.clipDock.decode(UserSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    public func save(_ settings: UserSettings) {
        guard let data = try? JSONEncoder.clipDock.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
