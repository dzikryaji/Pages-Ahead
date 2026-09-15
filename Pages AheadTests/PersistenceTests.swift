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
        _ = appContainer.sessions.current()
        _ = appContainer.personalization.events()
    }

    @Test func bookSurvivesNewRepositoryInstance() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredPlannedSession.self, StoredPersonalizationEvent.self, configurations: configuration)
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
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredPlannedSession.self, StoredPersonalizationEvent.self, configurations: configuration)
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

    @Test func plannedSessionCanBeUpdatedAndDeleted() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredPlannedSession.self, StoredPersonalizationEvent.self, configurations: configuration)
        let repository = SwiftDataPlannedSessionRepository(context: container.mainContext)
        var session = PlannedSession(id: UUID(), start: .now, durationMinutes: 30, place: "Indoors", bookID: UUID(), reminderEnabled: true, calendarEnabled: false)
        repository.save(session)
        session.durationMinutes = 45
        repository.save(session)
        #expect(repository.current()?.durationMinutes == 45)
        repository.delete(id: session.id)
        #expect(repository.current() == nil)
    }

    @Test func personalizationHistoryCanBeCleared() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: StoredBook.self, StoredReadingRecord.self, StoredPlannedSession.self, StoredPersonalizationEvent.self, configurations: configuration)
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
