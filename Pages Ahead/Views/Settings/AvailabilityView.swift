import SwiftUI

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
