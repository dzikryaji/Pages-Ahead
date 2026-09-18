import Foundation

protocol LibraryRepository: AnyObject {
    func books() -> [Book]
    func add(_ book: Book)
    func update(_ book: Book)
}

protocol ReadingWindowRepository {
    func readingWindows(for bookID: UUID) async throws -> [ReadingWindow]
    func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String
    ) async throws -> [ReadingWindow]
}

extension ReadingWindowRepository {
    func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String
    ) async throws -> [ReadingWindow] {
        try await readingWindows(for: bookID)
    }
}

protocol ActivityRepository: AnyObject {
    func records() -> [ReadingRecord]
    func save(_ record: ReadingRecord)
    func delete(id: UUID)
}

protocol ReadingPlanRepository: AnyObject {
    func current() -> ReadingPlan?
    func save(_ session: ReadingPlan)
    func delete(id: UUID)
}

protocol PersonalizationRepository: AnyObject {
    func events() -> [PersonalizationEvent]
    func record(_ event: PersonalizationEvent)
    func clear()
}

protocol SessionProgressRepository: AnyObject {
    func loadCurrent() -> ActiveReadingSession?
    func save(_ session: ActiveReadingSession)
    func clear()
}

extension SessionProgressRepository {
    func load(bookID: UUID) -> ActiveReadingSession? {
        guard let session = loadCurrent(), session.bookID == bookID else { return nil }
        return session
    }

    func clear(bookID: UUID) {
        guard load(bookID: bookID) != nil else { return }
        clear()
    }
}

@MainActor
protocol ReadingActivityManaging: AnyObject {
    func start(book: Book, session: ActiveReadingSession) async
    func update(bookID: UUID, session: ActiveReadingSession) async
    func end(bookID: UUID, session: ActiveReadingSession) async
}

protocol SettingsRepository: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
    var hasCreatedReadingPlan: Bool { get set }
    var preferences: ReadingPreferences { get set }
    var city: String { get set }
    var planNotificationEnabled: Bool { get set }
    var planCalendarEnabled: Bool { get set }
    var permissionRecoveryTipShown: Bool { get set }
}

protocol BookCatalogSearching {
    func search(query: String) async throws -> [Book]
}

protocol BookCoverImageLoading: Sendable {
    func data(for url: URL, embeddedData: Data?) async throws -> Data
}

struct CachedCatalogSearch: Sendable {
    let books: [Book]
    let fetchedAt: Date
}

@MainActor
protocol CatalogSearchCaching: AnyObject {
    func results(for query: String) -> CachedCatalogSearch?
    func save(_ books: [Book], for query: String, fetchedAt: Date)
    func saveCoverImage(_ data: Data, for bookID: UUID, query: String)
}

protocol LocationProviding: AnyObject {
    func requestCurrentLocation() async throws -> (location: LocationCoordinate, city: String)
    func coordinate(for city: String) async throws -> LocationCoordinate
}

protocol WeatherProviding {
    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch
}

protocol NotificationScheduling {
    func schedule(session: ReadingPlan) async throws -> Bool
    func cancel(sessionID: UUID)
}

protocol CalendarEventWriting {
    func save(session: ReadingPlan, bookTitle: String, existingEventID: String?) async throws -> String
    func delete(eventID: String) throws
}

protocol CalendarAvailabilityProviding {
    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval]
}
