import Foundation

struct ForecastCandidate: Codable, Sendable {
    let date: Date
    let temperature: Int
    let condition: String
    let symbolName: String
}

struct RecommendationEngine {
    private static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    func rank(_ candidates: [ForecastCandidate], preferences: ReadingPreferences, events: [PersonalizationEvent] = [], calendar: Calendar = .current) -> [ForecastCandidate] {
        candidates
            .filter { preferences.availableDays.contains(weekdayName(for: $0.date, calendar: calendar)) }
            .sorted { score($0, preferences: preferences, events: events, calendar: calendar) > score($1, preferences: preferences, events: events, calendar: calendar) }
    }

    private func weekdayName(for date: Date, calendar: Calendar) -> String {
        Self.weekdayNames[calendar.component(.weekday, from: date) - 1]
    }

    private func score(_ candidate: ForecastCandidate, preferences: ReadingPreferences, events: [PersonalizationEvent], calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: candidate.date)
        let timeScore: Int = switch preferences.preferredTime {
        case "Morning": (6...10).contains(hour) ? 30 : 0
        case "Afternoon": (12...17).contains(hour) ? 30 : 0
        default: (18...22).contains(hour) ? 30 : 0
        }
        let weatherMultiplier = switch preferences.weatherInfluence { case "High": 3; case "Low": 1; default: 2 }
        let temperatureScore: Int = switch preferences.temperature {
        case "Cool": candidate.temperature < 22 ? 5 : 0
        case "Warm": candidate.temperature >= 27 ? 5 : 0
        default: (22...27).contains(candidate.temperature) ? 5 : 0
        }
        let learnedScore = preferences.personalizationEnabled ? events.reduce(0) { partial, event in
            guard abs(event.hour - hour) <= 1 else { return partial }
            switch event.kind { case .completed: return partial + 4; case .accepted: return partial + 2; case .rejected: return partial - 4 }
        } : 0
        return timeScore + temperatureScore * weatherMultiplier + learnedScore
    }
}
