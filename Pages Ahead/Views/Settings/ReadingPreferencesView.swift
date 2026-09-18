import SwiftUI

struct ReadingPreferencesView: View {
    @Binding var preferences: ReadingPreferences
    var body: some View {
        Form {
            Section("Timing") {
                Picker("Weekday", selection: $preferences.weekdayPreferredTime) { ForEach(["Morning", "Afternoon", "Evening", "Anytime"], id: \.self) { Text($0) } }
                Picker("Weekend", selection: $preferences.weekendPreferredTime) { ForEach(["Morning", "Afternoon", "Evening", "Anytime"], id: \.self) { Text($0) } }
            }
            Section("Weather") {
                Picker("Preferred weather", selection: $preferences.preferredWeather) { ForEach(["Cold", "Mild", "Warm"], id: \.self) { Text($0) } }
                Picker("Priority", selection: $preferences.preferencePriority) { ForEach(["Time", "Balanced", "Weather"], id: \.self) { Text($0) } }
            }
            Section("Recommendation windows") {
                Picker("Preferred window length", selection: $preferences.preferredWindowMinutes) { ForEach([15, 25, 30, 45, 60], id: \.self) { Text("\($0) min") } }
            }
        }.navigationTitle("Reading Preferences")
    }
}
