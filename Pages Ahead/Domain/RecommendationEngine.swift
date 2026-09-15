import Foundation

struct ForecastCandidate: Codable, Sendable, Equatable {
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
            .sorted {
                let left = score($0, preferences: preferences, events: events, calendar: calendar)
                let right = score($1, preferences: preferences, events: events, calendar: calendar)
                return left == right ? $0.date < $1.date : left > right
            }
    }

    func dailyRanges(
        _ candidates: [ForecastCandidate],
        preferences: ReadingPreferences,
        bookID: UUID? = nil,
        events: [PersonalizationEvent] = [],
        now: Date = .now,
        calendar: Calendar = .current,
        limit: Int = 7
    ) -> [ReadingWindow] {
        let upcoming = candidates.filter {
            $0.date.addingTimeInterval(3_600) > now &&
            (6...22).contains(calendar.component(.hour, from: $0.date)) &&
            preferences.availableDays.contains(weekdayName(for: $0.date, calendar: calendar))
        }
        let grouped = Dictionary(grouping: upcoming) {
            calendar.startOfDay(for: $0.date)
        }

        return grouped.keys.sorted().compactMap { day in
            guard let hours = grouped[day]?.sorted(by: { $0.date < $1.date }) else {
                return nil
            }
            let blocks = stableBlocks(hours)
            guard let best = blocks.max(by: {
                blockScore($0, preferences: preferences, events: events, calendar: calendar) <
                blockScore($1, preferences: preferences, events: events, calendar: calendar)
            }), let first = best.first, let last = best.last else { return nil }

            let start = max(first.date, now)
            let end = last.date.addingTimeInterval(3_600)
            guard end > start else { return nil }
            let averageTemperature = Int(
                (Double(best.reduce(0) { $0 + $1.temperature }) / Double(best.count)).rounded()
            )
            let preferredTime = preferredTime(for: first.date, preferences: preferences, calendar: calendar)
            return ReadingWindow(
                id: UUID(),
                start: start,
                durationMinutes: max(1, Int(end.timeIntervalSince(start) / 60)),
                temperature: averageTemperature,
                condition: first.condition,
                weatherSymbol: first.symbolName,
                place: "Flexible",
                fitReason: fitReason(
                    preferredTime: preferredTime,
                    priority: preferences.preferencePriority,
                    weather: preferences.preferredWeather
                ),
                bookID: bookID,
                end: end
            )
        }.prefix(limit).map { $0 }
    }

    private func weekdayName(for date: Date, calendar: Calendar) -> String {
        Self.weekdayNames[calendar.component(.weekday, from: date) - 1]
    }

    private func score(_ candidate: ForecastCandidate, preferences: ReadingPreferences, events: [PersonalizationEvent], calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: candidate.date)
        let preferredTime = preferredTime(for: candidate.date, preferences: preferences, calendar: calendar)
        let timeMatch: Int = switch preferredTime {
        case "Morning": (6...10).contains(hour) ? 30 : 0
        case "Afternoon": (12...17).contains(hour) ? 30 : 0
        case "Evening": (18...22).contains(hour) ? 30 : 0
        default: 30
        }
        let weatherMatch: Int = switch preferences.preferredWeather {
        case "Cold": candidate.temperature < 22 ? 5 : 0
        case "Warm": candidate.temperature >= 27 ? 5 : 0
        default: (22...27).contains(candidate.temperature) ? 5 : 0
        }
        let weights: (time: Int, weather: Int) = switch preferences.preferencePriority {
        case "Weather": (1, 6)
        case "Balanced": (1, 3)
        default: (1, 1)
        }
        let learnedScore = preferences.personalizationEnabled ? events.reduce(0) { partial, event in
            guard abs(event.hour - hour) <= 1 else { return partial }
            switch event.kind { case .completed: return partial + 4; case .accepted: return partial + 2; case .rejected: return partial - 4 }
        } : 0
        return timeMatch * weights.time + weatherMatch * weights.weather + learnedScore
    }

    private func preferredTime(
        for date: Date,
        preferences: ReadingPreferences,
        calendar: Calendar
    ) -> String {
        calendar.isDateInWeekend(date)
            ? preferences.weekendPreferredTime
            : preferences.weekdayPreferredTime
    }

    private func stableBlocks(_ candidates: [ForecastCandidate]) -> [[ForecastCandidate]] {
        candidates.reduce(into: [[ForecastCandidate]]()) { blocks, candidate in
            guard var current = blocks.popLast() else {
                blocks.append([candidate])
                return
            }
            let temperatures = current.map(\.temperature) + [candidate.temperature]
            let isAdjacent = candidate.date.timeIntervalSince(current.last!.date) <= 5_400
            let isStable = weatherCategory(candidate) == weatherCategory(current[0]) &&
                (temperatures.max()! - temperatures.min()! <= 2)
            if isAdjacent && isStable {
                current.append(candidate)
                blocks.append(current)
            } else {
                blocks.append(current)
                blocks.append([candidate])
            }
        }
    }

    private func blockScore(
        _ block: [ForecastCandidate],
        preferences: ReadingPreferences,
        events: [PersonalizationEvent],
        calendar: Calendar
    ) -> Int {
        (block.map { score($0, preferences: preferences, events: events, calendar: calendar) }.max() ?? 0)
            + min(block.count, 6)
    }

    private func weatherCategory(_ candidate: ForecastCandidate) -> String {
        let value = "\(candidate.symbolName) \(candidate.condition)".lowercased()
        if value.contains("thunder") || value.contains("bolt") { return "storm" }
        if value.contains("snow") || value.contains("sleet") { return "snow" }
        if value.contains("rain") || value.contains("drizzle") { return "rain" }
        if value.contains("fog") || value.contains("haze") { return "fog" }
        if value.contains("cloud") || value.contains("overcast") { return "cloud" }
        if value.contains("clear") || value.contains("sun") { return "clear" }
        return value
    }

    private func fitReason(preferredTime: String, priority: String, weather: String) -> String {
        switch priority {
        case "Weather": "Stable \(weather.lowercased()) weather makes this the best window that day."
        case "Balanced": "This balances your \(preferredTime.lowercased()) timing with stable \(weather.lowercased()) weather."
        default: "This overlaps your \(preferredTime.lowercased()) preference with steady weather."
        }
    }
}
