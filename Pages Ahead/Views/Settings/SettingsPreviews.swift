import SwiftUI

#Preview("Settings") {
    let container = AppContainer.preview
    NavigationStack { SettingsView(settings: container.settings, personalization: container.personalization) }
}

#Preview("Settings Row") {
    List { SettingsRow("Reading Preferences", symbol: "slider.horizontal.3") }
}

#Preview("Reading Preferences") {
    @Previewable @State var preferences = ReadingPreferences()
    NavigationStack { ReadingPreferencesView(preferences: $preferences) }
}

#Preview("Availability") {
    @Previewable @State var preferences = ReadingPreferences()
    NavigationStack { AvailabilityView(preferences: $preferences) }
}

#Preview("Location Settings") {
    @Previewable @State var city = "Makassar"
    @Previewable @State var preferences = ReadingPreferences()
    NavigationStack { LocationSettingsView(city: $city, preferences: $preferences) }
}

#Preview("Privacy") {
    @Previewable @State var preferences = ReadingPreferences()
    NavigationStack { PrivacyView(preferences: $preferences, personalization: InMemoryPersonalizationRepository()) }
}

#Preview("Personalization Data") {
    let events = [PersonalizationEvent(id: UUID(), kind: .completed, date: .now,
                                       hour: 19, temperature: 24, place: "Indoors", reason: "Focused")]
    NavigationStack { PersonalizationDataView(events: events, preferences: ReadingPreferences()) }
}
