import SwiftUI

struct SettingsView: View {
    let settings: SettingsRepository
    let personalization: PersonalizationRepository
    let onReplayOnboarding: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var preferences: ReadingPreferences
    @State private var city: String

    init(
        settings: SettingsRepository,
        personalization: PersonalizationRepository,
        onReplayOnboarding: @escaping () -> Void = {}
    ) {
        self.settings = settings
        self.personalization = personalization
        self.onReplayOnboarding = onReplayOnboarding
        _preferences = State(initialValue: settings.preferences)
        _city = State(initialValue: settings.city)
    }

    var body: some View {
        List {
            Section("Planning") {
                NavigationLink { ReadingPreferencesView(preferences: $preferences) } label: { SettingsRow("Reading Preferences", symbol: "slider.horizontal.3") }
                NavigationLink { AvailabilityView(preferences: $preferences) } label: { SettingsRow("Availability", symbol: "calendar") }
            }
            Section("Data") {
                NavigationLink { LocationSettingsView(city: $city, preferences: $preferences) } label: { SettingsRow("Location", symbol: "location") }
                NavigationLink { PrivacyView(preferences: $preferences, personalization: personalization) } label: { SettingsRow("Personalization & Privacy", symbol: "hand.raised") }
            }
            Section("Help") {
                Button {
                    save()
                    dismiss()
                    onReplayOnboarding()
                } label: {
                    SettingsRow("Replay Welcome & Setup", symbol: "arrow.counterclockwise")
                }
            }
            Section("About") {
                LabeledContent("Primary weather", value: "Apple Weather")
                Link("Open-Meteo fallback", destination: URL(string: "https://open-meteo.com")!)
                Link("Open Library catalog", destination: URL(string: "https://openlibrary.org")!)
                LabeledContent("Pages Ahead", value: "1.0")
            }
        }
        .navigationTitle("Settings")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { save(); dismiss() } } }
        .onDisappear(perform: save)
    }

    private func save() { settings.preferences = preferences; settings.city = city }
}

struct SettingsRow: View {
    let title: String; let symbol: String
    init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View {
        Label(title, systemImage: symbol)
    }
}
