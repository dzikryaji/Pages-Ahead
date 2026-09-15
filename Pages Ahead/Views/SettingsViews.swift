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
                NavigationLink { NotificationsFocusView(preferences: $preferences) } label: { SettingsRow("Notifications & Focus", symbol: "bell.badge") }
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

private struct SettingsRow: View {
    let title: String; let symbol: String
    init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }
    var body: some View {
        Label(title, systemImage: symbol)
    }
}

struct ReadingPreferencesView: View {
    @Binding var preferences: ReadingPreferences
    var body: some View {
        Form {
            Section("Reading") {
                Picker("Duration", selection: $preferences.duration) { ForEach([15, 25, 30, 45, 60], id: \.self) { Text("\($0) min") } }
                Picker("Time", selection: $preferences.preferredTime) { ForEach(["Morning", "Afternoon", "Evening"], id: \.self) { Text($0) } }
                Picker("Place", selection: $preferences.place) { ForEach(["Indoors", "Outdoors", "Either"], id: \.self) { Text($0) } }
            }
            Section { Picker("Influence", selection: $preferences.weatherInfluence) { ForEach(["Low", "Balanced", "High"], id: \.self) { Text($0) } } }
            header: { Text("Weather") } footer: { Text("Weather helps rank comfortable times. It never blocks reading.") }
        }.navigationTitle("Reading Preferences")
    }
}

struct AvailabilityView: View {
    @Binding var preferences: ReadingPreferences
    private let allDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    var body: some View {
        List {
            Section("Weekly schedule") {
                ForEach(allDays, id: \.self) { day in
                    Toggle(day, isOn: Binding(get: { preferences.availableDays.contains(day) }, set: { enabled in
                        if enabled { preferences.availableDays.insert(day) } else { preferences.availableDays.remove(day) }
                    }))
                }
            }
            Section { Toggle("Use free time from Calendar", isOn: $preferences.calendarAvailabilityEnabled) }
            header: { Text("Calendar") } footer: { Text("Calendar access is requested only when recommendations need busy-time data.") }
        }.navigationTitle("Availability")
    }
}

struct NotificationsFocusView: View {
    @Binding var preferences: ReadingPreferences
    var body: some View {
        Form {
            Section {
                Toggle("Reading reminders", isOn: $preferences.remindersEnabled)
                Toggle("Only for planned sessions", isOn: $preferences.plannedSessionsOnly).disabled(!preferences.remindersEnabled)
                Stepper("\(preferences.reminderLeadTime) minutes before", value: $preferences.reminderLeadTime, in: 5...60, step: 5).disabled(!preferences.remindersEnabled)
            } header: { Text("Reminders") } footer: { Text("Permission appears only when you plan a reminder.") }
            Section("Focus") {
                NavigationLink("Set Up Reading Focus Shortcut") { ReadingFocusShortcutSetupView() }
                Text("Pages Ahead provides a Start Reading action. iOS requires you to approve any shortcut that changes Focus.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Notifications & Focus")
    }
}

struct LocationSettingsView: View {
    @Binding var city: String
    @Binding var preferences: ReadingPreferences
    var body: some View {
        Form {
            Section("Forecast location") {
                TextField("City", text: $city)
                Toggle("Update automatically", isOn: $preferences.automaticLocation)
                Toggle("Precise location", isOn: $preferences.preciseLocation)
            }
            Section("Privacy") { Text("City-level location is enough. Weather uses Apple Weather first, then Open-Meteo when unavailable.").foregroundStyle(.secondary) }
        }.navigationTitle("Location")
    }
}

struct PrivacyView: View {
    @Binding var preferences: ReadingPreferences
    let personalization: PersonalizationRepository
    @State private var confirmingClear = false

    init(
        preferences: Binding<ReadingPreferences>,
        personalization: PersonalizationRepository,
        confirmingClear: Bool = false
    ) {
        _preferences = preferences
        self.personalization = personalization
        _confirmingClear = State(initialValue: confirmingClear)
    }
    var body: some View {
        Form {
            Section {
                Toggle("On-device personalization", isOn: $preferences.personalizationEnabled)
                NavigationLink("View Personalization Data") {
                    PersonalizationDataView(events: personalization.events(), preferences: preferences)
                }
            } header: { Text("Personalization") } footer: { Text("Recommendations use saved preferences on this device. When disabled, transparent rules are used.") }
            Section("Your data") { Button("Clear Personalization History", role: .destructive) { confirmingClear = true } }
        }
        .navigationTitle("Personalization & Privacy")
        .alert("Clear personalization history?", isPresented: $confirmingClear) {
            Button("Clear", role: .destructive) { personalization.clear() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Your library and activity will stay intact.") }
    }
}

struct PersonalizationDataView: View {
    let events: [PersonalizationEvent]
    let preferences: ReadingPreferences
    var body: some View {
        List {
            Section("Preferences") {
                LabeledContent("Preferred time", value: preferences.preferredTime)
                LabeledContent("Weather influence", value: preferences.weatherInfluence)
                LabeledContent("Preferred place", value: preferences.place)
            }
            Section("Learning history") {
                if events.isEmpty { Text("No learning history yet.").foregroundStyle(.secondary) }
                ForEach(events) { event in
                    VStack(alignment: .leading) {
                        Text(event.kind.rawValue.capitalized).font(.headline)
                        Text("Around \(event.hour):00 · \(event.place)").font(.subheadline).foregroundStyle(.secondary)
                        if let reason = event.reason { Text(reason).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }.navigationTitle("Personalization Data")
    }
}

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

#Preview("Notifications and Focus") {
    @Previewable @State var preferences = ReadingPreferences()
    NavigationStack { NotificationsFocusView(preferences: $preferences) }
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
