import Foundation
import Testing
@testable import Pages_Ahead

struct RecommendationEngineTests {
    @Test func unavailableDaysAreFiltered() {
        var preferences = ReadingPreferences()
        preferences.availableDays = []
        let candidate = ForecastCandidate(date: .now, temperature: 24, condition: "Clear", symbolName: "sun.max")
        #expect(RecommendationEngine().rank([candidate], preferences: preferences).isEmpty)
    }

    @Test func preferredTimeRanksFirst() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.preferredTime = "Evening"
        let calendar = Calendar.current
        let morning = ForecastCandidate(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let evening = ForecastCandidate(date: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "moon")
        #expect(RecommendationEngine().rank([morning, evening], preferences: preferences).first?.date == evening.date)
    }

    @Test func completionHistoryPersonalizesRanking() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.preferredTime = "Evening"
        let calendar = Calendar.current
        let morning = ForecastCandidate(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let afternoon = ForecastCandidate(date: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let events = (0..<2).map { _ in PersonalizationEvent(id: UUID(), kind: .completed, date: .now, hour: 8, temperature: nil, place: "Indoors", reason: nil) }
        #expect(RecommendationEngine().rank([afternoon, morning], preferences: preferences, events: events).first?.date == morning.date)
    }

    @Test func disabledPersonalizationIgnoresHistory() {
        var preferences = ReadingPreferences()
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        preferences.personalizationEnabled = false
        let calendar = Calendar.current
        let first = ForecastCandidate(date: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let second = ForecastCandidate(date: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now)!, temperature: 24, condition: "Clear", symbolName: "sun.max")
        let event = PersonalizationEvent(id: UUID(), kind: .rejected, date: .now, hour: 8, temperature: nil, place: "Indoors", reason: nil)
        let baseline = RecommendationEngine().rank([first, second], preferences: preferences)
        let withHistory = RecommendationEngine().rank([first, second], preferences: preferences, events: [event])
        #expect(baseline.map(\.date) == withHistory.map(\.date))
    }
}
