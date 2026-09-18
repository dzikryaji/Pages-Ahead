import SwiftUI

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
