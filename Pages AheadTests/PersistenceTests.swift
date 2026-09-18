import Foundation
import SwiftData
import Testing
@testable import Pages_Ahead

@MainActor
struct PersistenceTests {
    @Test func liveContainerRetainsItsSwiftDataStore() {
        let appContainer = AppContainer.live

        #expect(appContainer.persistentContainer != nil || appContainer.startupError != nil)
        _ = appContainer.library.books()
        _ = appContainer.activity.records()
        _ = appContainer.readingPlans.current()
        _ = appContainer.personalization.events()
    }

    @Test func bookSurvivesNewRepositoryInstance() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredReadingPlan.self, StoredPersonalizationEvent.self, configurations: configuration)
        let first = SwiftDataLibraryRepository(context: container.mainContext)
        var book = SampleData.books[0]
        book.coverImageData = Data([1, 2, 3, 4])
        first.add(book)
        let second = SwiftDataLibraryRepository(context: container.mainContext)
        #expect(second.books() == [book])
        #expect(second.books().first?.coverImageData == Data([1, 2, 3, 4]))
    }

    @Test func exactISBNIsNotDuplicated() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredReadingPlan.self, StoredPersonalizationEvent.self, configurations: configuration)
        let repository = SwiftDataLibraryRepository(context: container.mainContext)
        repository.add(SampleData.books[0])
        repository.add(SampleData.books[0])
        #expect(repository.books().count == 1)
    }

    @Test func catalogResultsAndCoverImageSurviveNewRepositoryInstance() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredCatalogEntry.self, configurations: configuration)
        let first = SwiftDataCatalogSearchCache(context: container.mainContext)
        let book = SampleData.books[0]
        first.save([book], for: "  DÜNE ", fetchedAt: .now)
        first.saveCoverImage(
            Data([1, 2, 3, 4]),
            for: book.id,
            query: "dune"
        )

        let second = SwiftDataCatalogSearchCache(context: container.mainContext)
        let cached = second.results(for: "dune")

        #expect(cached?.books.first?.title == book.title)
        #expect(cached?.books.first?.coverImageData == Data([1, 2, 3, 4]))
    }

    @Test func readingPlanCanBeUpdatedAndDeleted() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredReadingPlan.self, StoredPersonalizationEvent.self, configurations: configuration)
        let repository = SwiftDataReadingPlanRepository(context: container.mainContext)
        var session = ReadingPlan(id: UUID(), start: .now, durationMinutes: 30, place: "Indoors", bookID: nil, reminderEnabled: true, calendarEnabled: false)
        repository.save(session)
        session.durationMinutes = 45
        repository.save(session)
        #expect(repository.current()?.durationMinutes == 45)
        #expect(repository.current()?.bookID == nil)
        repository.delete(id: session.id)
        #expect(repository.current() == nil)
    }

    @Test func legacyReadingPreferencesGainNewDefaultsWithoutLosingChoices() throws {
        let data = Data(#"{"preferredTime":"Afternoon","temperature":"Warm","weatherInfluence":"Balanced","duration":45,"remindersEnabled":true,"plannedSessionsOnly":false,"reminderLeadTime":30}"#.utf8)

        let preferences = try JSONDecoder().decode(ReadingPreferences.self, from: data)

        #expect(preferences.weekdayPreferredTime == "Afternoon")
        #expect(preferences.weekendPreferredTime == "Afternoon")
        #expect(preferences.preferredWeather == "Warm")
        #expect(preferences.preferencePriority == "Balanced")
        #expect(preferences.preferredWindowMinutes == 45)
    }

    @Test func legacyActiveSessionPlanKeysDecodeIntoCurrentNames() throws {
        let bookID = UUID()
        let planID = UUID()
        let data = Data("""
        {
          "bookID": "\(bookID.uuidString)",
          "accumulatedSeconds": 42,
          "isPaused": true,
          "startingPage": 5,
          "origin": "readingPlan",
          "plannedSessionID": "\(planID.uuidString)",
          "startedInsidePlannedWindow": true
        }
        """.utf8)

        let session = try JSONDecoder().decode(ActiveReadingSession.self, from: data)

        #expect(session.bookID == bookID)
        #expect(session.readingPlanID == planID)
        #expect(session.startedInsideReadingWindow)
    }

    @Test func currentReadingPreferencesRoundTripAllActiveChoices() throws {
        var preferences = ReadingPreferences()
        preferences.weekdayPreferredTime = "Afternoon"
        preferences.weekendPreferredTime = "Evening"
        preferences.preferredWeather = "Warm"
        preferences.preferencePriority = "Weather"
        preferences.preferredWindowMinutes = 45
        preferences.personalizationEnabled = false
        preferences.availableDays = ["Monday", "Saturday"]
        preferences.calendarAvailabilityEnabled = true
        preferences.automaticLocation = false
        preferences.preciseLocation = true

        let encoded = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(ReadingPreferences.self, from: encoded)

        #expect(decoded == preferences)
        let payload = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(payload["preferredWindowMinutes"] as? Int == 45)
        #expect(payload["duration"] == nil)
        #expect(payload["preferredTime"] == nil)
        #expect(payload["weatherInfluence"] == nil)
        #expect(payload["temperature"] == nil)
        #expect(payload["place"] == nil)
        #expect(payload["remindersEnabled"] == nil)
        #expect(payload["plannedSessionsOnly"] == nil)
        #expect(payload["reminderLeadTime"] == nil)
    }

    @Test func legacyStoredRecordAndPlanFieldsProduceCurrentDomainValues() {
        let recordID = UUID()
        let storedRecord = StoredReadingRecord(record: ReadingRecord(
            id: recordID,
            bookID: UUID(),
            date: .now,
            durationSeconds: 1,
            startingPage: 0,
            lastPage: 1,
            weather: "Clear"
        ))
        storedRecord.minutes = 12
        storedRecord.pages = 9
        storedRecord.durationSeconds = nil
        storedRecord.startingPage = nil
        storedRecord.lastPage = nil
        storedRecord.cycleID = nil
        storedRecord.place = "Legacy place"
        storedRecord.feedback = "Legacy feedback"
        storedRecord.note = "Legacy note"

        let record = storedRecord.domain
        #expect(record.durationSeconds == 720)
        #expect(record.startingPage == 0)
        #expect(record.lastPage == 9)
        #expect(record.cycleID == recordID)

        let start = Date(timeIntervalSince1970: 1_000)
        let storedPlan = StoredReadingPlan(session: ReadingPlan(
            id: UUID(),
            start: start,
            end: start.addingTimeInterval(600),
            place: "Indoors",
            bookID: nil,
            reminderEnabled: false,
            calendarEnabled: false
        ))
        storedPlan.end = nil
        storedPlan.durationMinutes = 25

        #expect(storedPlan.domain.end == start.addingTimeInterval(1_500))
    }

    @Test func personalizationHistoryCanBeCleared() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredReadingPlan.self, StoredPersonalizationEvent.self, configurations: configuration)
        let repository = SwiftDataPersonalizationRepository(context: container.mainContext)
        repository.record(PersonalizationEvent(id: UUID(), kind: .accepted, date: .now, hour: 19, temperature: 25, place: "Indoors", reason: nil))
        #expect(repository.events().count == 1)
        repository.clear()
        #expect(repository.events().isEmpty)
    }

    @Test func activeSessionProgressCanBeRestoredAndCleared() {
        let repository = InMemorySessionProgressRepository()
        let bookID = UUID()
        let session = ActiveReadingSession(bookID: bookID, durationSeconds: 1_800, accumulatedSeconds: 120, startedAt: nil, isPaused: true)
        repository.save(session)
        #expect(repository.load(bookID: bookID) == session)
        repository.clear(bookID: bookID)
        #expect(repository.load(bookID: bookID) == nil)
    }
}
