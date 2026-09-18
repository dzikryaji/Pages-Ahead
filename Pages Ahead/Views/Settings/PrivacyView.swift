import SwiftUI

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
