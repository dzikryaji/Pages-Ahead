import Foundation

final class UserDefaultsSettingsRepository: SettingsRepository {
    private enum Key {
        static let onboarding = "hasCompletedOnboarding"
        static let hasCreatedReadingPlan = "hasCreatedReadingPlan"
        static let preferences = "readingPreferences"
        static let city = "forecastCity"
        static let planNotificationEnabled = "planNotificationEnabled"
        static let planCalendarEnabled = "planCalendarEnabled"
        static let permissionRecoveryTipShown = "permissionRecoveryTipShown"
    }

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.onboarding) }
        set { defaults.set(newValue, forKey: Key.onboarding) }
    }

    var hasCreatedReadingPlan: Bool {
        get { defaults.bool(forKey: Key.hasCreatedReadingPlan) }
        set { defaults.set(newValue, forKey: Key.hasCreatedReadingPlan) }
    }

    var preferences: ReadingPreferences {
        get {
            guard let data = defaults.data(forKey: Key.preferences),
                  let value = try? JSONDecoder().decode(ReadingPreferences.self, from: data) else { return ReadingPreferences() }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.preferences) }
    }

    var city: String {
        get { defaults.string(forKey: Key.city) ?? "Makassar" }
        set { defaults.set(newValue, forKey: Key.city) }
    }

    var planNotificationEnabled: Bool {
        get {
            if defaults.object(forKey: Key.planNotificationEnabled) == nil { return true }
            return defaults.bool(forKey: Key.planNotificationEnabled)
        }
        set { defaults.set(newValue, forKey: Key.planNotificationEnabled) }
    }

    var planCalendarEnabled: Bool {
        get { defaults.bool(forKey: Key.planCalendarEnabled) }
        set { defaults.set(newValue, forKey: Key.planCalendarEnabled) }
    }

    var permissionRecoveryTipShown: Bool {
        get { defaults.bool(forKey: Key.permissionRecoveryTipShown) }
        set { defaults.set(newValue, forKey: Key.permissionRecoveryTipShown) }
    }
}
