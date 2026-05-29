import Foundation

public protocol SettingsStore {
    func load() -> UserSettings
    func save(_ settings: UserSettings)
}

public final class UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key = "ClipDock.UserSettings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
