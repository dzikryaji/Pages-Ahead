import SwiftUI

struct PersonalizationDataView: View {
    let events: [PersonalizationEvent]
    let preferences: ReadingPreferences
    var body: some View {
        List {
            Section("Preferences") {
                LabeledContent("Weekday time", value: preferences.weekdayPreferredTime)
                LabeledContent("Weekend time", value: preferences.weekendPreferredTime)
                LabeledContent("Preferred weather", value: preferences.preferredWeather)
                LabeledContent("Priority", value: preferences.preferencePriority)
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
