#if DEBUG
import SwiftUI

struct SettingsDetailScreenshot: View {
    let scenario: ScreenshotScenario
    let personalization: PersonalizationRepository
    @State private var preferences = ReadingPreferences()
    @State private var city = "Makassar"

    @ViewBuilder
    var body: some View {
        NavigationStack {
            switch scenario {
            case .readingPreferences: ReadingPreferencesView(preferences: $preferences)
            case .availability: AvailabilityView(preferences: $preferences)
            case .locationSettings: LocationSettingsView(city: $city, preferences: $preferences)
            case .privacyClearAlert: PrivacyView(preferences: $preferences, personalization: personalization, confirmingClear: true)
            default: PrivacyView(preferences: $preferences, personalization: personalization)
            }
        }
    }
}

#endif
