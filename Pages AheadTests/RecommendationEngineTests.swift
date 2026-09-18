import Foundation
import Testing
@testable import Pages_Ahead

struct RecommendationEngineTests {
    @Test func unavailableDaysAreFiltered() {
        var preferences = ReadingPreferences()
        preferences.availableDays = []
        let candidate = HourlyWeatherSnapshot(date: .now, temperature: 24, condition: "Clear", symbolName: "sun.max")
        #expect(RecommendationEngine().rank([candidate], preferences: preferences).isEmpty)
    }

    @Test func preferredTimeRanksFirst() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.weekdayPreferredTime = "Evening"
        preferences.weekendPreferredTime = "Evening"
        let calendar = Calendar.current
        let morning = HourlyWeatherSnapshot(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let evening = HourlyWeatherSnapshot(date: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "moon")
        #expect(RecommendationEngine().rank([morning, evening], preferences: preferences).first?.date == evening.date)
    }

    @Test func completionHistoryPersonalizesRanking() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.weekdayPreferredTime = "Evening"
        preferences.weekendPreferredTime = "Evening"
        let calendar = Calendar.current
        let morning = HourlyWeatherSnapshot(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let afternoon = HourlyWeatherSnapshot(date: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let events = (0..<2).map { _ in PersonalizationEvent(id: UUID(), kind: .completed, date: .now, hour: 8, temperature: nil, place: "Indoors", reason: nil) }
        #expect(RecommendationEngine().rank([afternoon, morning], preferences: preferences, events: events).first?.date == morning.date)
    }

    @Test func disabledPersonalizationIgnoresHistory() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.personalizationEnabled = false
        let calendar = Calendar.current
        let first = HourlyWeatherSnapshot(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let second = HourlyWeatherSnapshot(date: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let event = PersonalizationEvent(id: UUID(), kind: .rejected, date: .now, hour: 8, temperature: nil, place: "Indoors", reason: nil)
        let baseline = RecommendationEngine().rank([first, second], preferences: preferences)
        let withHistory = RecommendationEngine().rank([first, second], preferences: preferences, events: [event])
        #expect(baseline.map(\.date) == withHistory.map(\.date))
    }

    @Test func equallySuitableWindowsUseChronologicalProximity() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        let later = HourlyWeatherSnapshot(date: .now.addingTimeInterval(7_200), temperature: 24, condition: "Clear", symbolName: "sun.max")
        let sooner = HourlyWeatherSnapshot(date: .now.addingTimeInterval(3_600), temperature: 24, condition: "Clear", symbolName: "sun.max")

        let ranked = RecommendationEngine().rank([later, sooner], preferences: preferences)

        #expect(ranked.map(\.date) == [sooner.date, later.date])
    }

    @Test func dailyRangesReturnOnlyOneStableWindowPerDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2100, month: 2, day: 1))!
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.weekdayPreferredTime = "Evening"
        preferences.weekendPreferredTime = "Morning"
        let candidates = (0..<3).flatMap { day in
            (6...22).map { hour in
                HourlyWeatherSnapshot(
                    date: calendar.date(byAdding: .hour, value: day * 24 + hour, to: start)!,
                    temperature: hour < 12 ? 20 : 25,
                    condition: hour < 12 ? "Cloudy" : "Clear",
                    symbolName: hour < 12 ? "cloud.fill" : "sun.max.fill"
                )
            }
        }

        let ranges = RecommendationEngine().dailyRanges(
            candidates,
            preferences: preferences,
            now: start,
            calendar: calendar
        )

        #expect(ranges.count == 3)
        #expect(Set(ranges.map { calendar.startOfDay(for: $0.start) }).count == 3)
        #expect(ranges.allSatisfy { $0.end > $0.start })
    }

    @Test func stableRangeStopsWhenTemperatureSpreadExceedsTwoDegrees() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2100, month: 2, day: 1))!
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.weekdayPreferredTime = "Morning"
        preferences.weekendPreferredTime = "Morning"
        let candidates = [20, 21, 22, 23].enumerated().map { index, temperature in
            HourlyWeatherSnapshot(
                date: calendar.date(byAdding: .hour, value: 7 + index, to: day)!,
                temperature: temperature,
                condition: "Cloudy",
                symbolName: "cloud.fill"
            )
        }

        let range = RecommendationEngine().dailyRanges(
            candidates,
            preferences: preferences,
            now: day,
            calendar: calendar
        ).first

        #expect(range?.durationMinutes == 180)
    }

    @Test func partiallyElapsedRangeUsesRemainingTimeUntilOriginalEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2100, month: 2, day: 1))!
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.weekdayPreferredTime = "Anytime"
        preferences.weekendPreferredTime = "Anytime"
        let candidates = (18...21).map { hour in
            HourlyWeatherSnapshot(
                date: calendar.date(byAdding: .hour, value: hour, to: day)!,
                temperature: 24,
                condition: "Clear",
                symbolName: "sun.max.fill"
            )
        }
        let now = calendar.date(byAdding: .minute, value: 30, to: candidates[1].date)!

        let range = RecommendationEngine().dailyRanges(
            candidates,
            preferences: preferences,
            now: now,
            calendar: calendar
        ).first

        #expect(range?.start == now)
        #expect(range?.end == candidates.last!.date.addingTimeInterval(3_600))
    }
}
