import Foundation
import OSLog
import SwiftData

protocol LibraryRepository: AnyObject {
    func books() -> [Book]
    func add(_ book: Book)
    func update(_ book: Book)
}

protocol ForecastRepository {
    func readingWindows(for bookID: UUID) async throws -> [ReadingWindow]
    func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String
    ) async throws -> [ReadingWindow]
}

extension ForecastRepository {
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

protocol PlannedSessionRepository: AnyObject {
    func current() -> PlannedSession?
    func save(_ session: PlannedSession)
    func delete(id: UUID)
}

protocol PersonalizationRepository: AnyObject {
    func events() -> [PersonalizationEvent]
    func record(_ event: PersonalizationEvent)
    func clear()
}

protocol SessionProgressRepository: AnyObject {
    func load(bookID: UUID) -> ActiveReadingSession?
    func save(_ session: ActiveReadingSession)
    func clear(bookID: UUID)
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
    var onboardingDraft: OnboardingDraft? { get set }
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
    func requestPermission() async throws
    func requestCurrentLocation() async throws -> (location: LocationCoordinate, city: String)
    func coordinate(for city: String) async throws -> LocationCoordinate
}

protocol WeatherProviding {
    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch
}

protocol NotificationScheduling {
    func schedule(session: PlannedSession, bookTitle: String, leadMinutes: Int) async throws -> Bool
    func cancel(sessionID: UUID)
}

protocol CalendarEventWriting {
    func save(session: PlannedSession, bookTitle: String, existingEventID: String?) async throws -> String
    func delete(eventID: String) throws
}

protocol CalendarAvailabilityProviding {
    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval]
}

final class InMemoryLibraryRepository: LibraryRepository {
    private var storage: [Book]
    init(books: [Book] = []) { storage = books }
    func books() -> [Book] { storage }
    func add(_ book: Book) { guard !storage.contains(where: { $0.id == book.id }) else { return }; storage.append(book) }
    func update(_ book: Book) { guard let index = storage.firstIndex(where: { $0.id == book.id }) else { return }; storage[index] = book }
}

@MainActor
final class InMemoryCatalogSearchCache: CatalogSearchCaching {
    private var storage: [String: CachedCatalogSearch] = [:]

    func results(for query: String) -> CachedCatalogSearch? { storage[query.normalizedCacheKey] }
    func save(_ books: [Book], for query: String, fetchedAt: Date = .now) {
        storage[query.normalizedCacheKey] = CachedCatalogSearch(books: books, fetchedAt: fetchedAt)
    }
    func saveCoverImage(_ data: Data, for bookID: UUID, query: String) {
        let key = query.normalizedCacheKey
        guard let cached = storage[key] else { return }
        var books = cached.books
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].coverImageData = data
        storage[key] = CachedCatalogSearch(
            books: books,
            fetchedAt: cached.fetchedAt
        )
    }
}

extension String {
    var normalizedCacheKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

struct MockForecastRepository: ForecastRepository {
    func readingWindows(for bookID: UUID) async throws -> [ReadingWindow] { SampleData.windows(bookID: bookID) }

    func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String
    ) async throws -> [ReadingWindow] {
        SampleData.windows(bookID: bookID)
    }
}

final class InMemoryActivityRepository: ActivityRepository {
    private var storage: [ReadingRecord]
    init(bookID: UUID = SampleData.books[0].id, records: [ReadingRecord]? = nil) {
        if let records { storage = records; return }
        let calendar = Calendar.current
        storage = [
            ReadingRecord(id: UUID(), bookID: bookID, date: calendar.date(byAdding: .day, value: -1, to: .now)!, minutes: 32, pages: 18, weather: "Rainy, 24°", place: "Home", feedback: "Calm", note: "Finished chapter six."),
            ReadingRecord(id: UUID(), bookID: bookID, date: calendar.date(byAdding: .day, value: -4, to: .now)!, minutes: 24, pages: 13, weather: "Cloudy, 23°", place: "Café", feedback: "Focused", note: "")
        ]
    }
    func records() -> [ReadingRecord] { storage.sorted { $0.date > $1.date } }
    func save(_ record: ReadingRecord) { storage.removeAll { $0.id == record.id }; storage.append(record) }
    func delete(id: UUID) { storage.removeAll { $0.id == id } }
}

final class UserDefaultsSettingsRepository: SettingsRepository {
    private enum Key {
        static let onboarding = "hasCompletedOnboarding"
        static let hasCreatedReadingPlan = "hasCreatedReadingPlan"
        static let preferences = "readingPreferences"
        static let city = "forecastCity"
        static let onboardingDraft = "onboardingDraftV2"
    }

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.onboarding) }
        set { defaults.set(newValue, forKey: Key.onboarding) }
    }

    var hasCreatedReadingPlan: Bool {
        get { defaults.bool(forKey: Key.hasCreatedReadingPlan) }
        set { defaults.set(newValue, forKey: Key.hasCreatedReadingPlan) }
    }

    var preferences: ReadingPreferences {
        get {
            guard let data = defaults.data(forKey: Key.preferences),
                  let value = try? JSONDecoder().decode(ReadingPreferences.self, from: data) else { return ReadingPreferences() }
            return value
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.preferences) }
    }

    var city: String {
        get { defaults.string(forKey: Key.city) ?? "Makassar" }
        set { defaults.set(newValue, forKey: Key.city) }
    }

    var onboardingDraft: OnboardingDraft? {
        get {
            guard let data = defaults.data(forKey: Key.onboardingDraft) else {
                return nil
            }
            return try? JSONDecoder().decode(OnboardingDraft.self, from: data)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: Key.onboardingDraft)
                return
            }
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.onboardingDraft)
        }
    }
}

struct AppContainer {
    // Retain the container for as long as its ModelContext-backed repositories live.
    // A ModelContext does not own its ModelContainer.
    let persistentContainer: ModelContainer?
    let catalogPersistentContainer: ModelContainer?
    let library: LibraryRepository
    let forecast: ForecastRepository
    let activity: ActivityRepository
    let sessions: PlannedSessionRepository
    let personalization: PersonalizationRepository
    let sessionProgress: SessionProgressRepository
    let readingActivity: ReadingActivityManaging
    let settings: SettingsRepository
    let catalog: BookCatalogSearching
    let catalogCache: CatalogSearchCaching
    let location: LocationProviding
    let notifications: NotificationScheduling
    let calendar: CalendarEventWriting
    let startupError: String?

    private static let logger = Logger(subsystem: "com.dzikryaji.Pages-Ahead", category: "persistence")

    static var live: AppContainer {
        do {
            let schema = Schema(versionedSchema: PagesAheadSchemaV1.self)
            let container = try ModelContainer(for: schema, migrationPlan: PagesAheadMigrationPlan.self)
            let settings = UserDefaultsSettingsRepository()
            let location = CoreLocationService()
            let calendar = EventKitCalendarService()
            let personalization = SwiftDataPersonalizationRepository(context: container.mainContext)
            let catalogPersistence = makeCatalogPersistence()
            let weather = FallbackWeatherProvider(providers: [WeatherKitWeatherProvider(), OpenMeteoWeatherProvider(), MockWeatherProvider()])
            return AppContainer(
                persistentContainer: container,
                catalogPersistentContainer: catalogPersistence.container,
                library: SwiftDataLibraryRepository(context: container.mainContext),
                forecast: WeatherKitForecastRepository(settings: settings, location: location, calendar: calendar, personalization: personalization, weather: weather),
                activity: SwiftDataActivityRepository(context: container.mainContext),
                sessions: SwiftDataPlannedSessionRepository(context: container.mainContext),
                personalization: personalization,
                sessionProgress: UserDefaultsSessionProgressRepository(),
                readingActivity: LiveReadingActivityManager(),
                settings: settings,
                catalog: OpenLibraryCatalogService(),
                catalogCache: catalogPersistence.cache,
                location: location,
                notifications: LocalNotificationScheduler(),
                calendar: calendar,
                startupError: nil
            )
        } catch {
            logger.error("Persistent store unavailable: \(error.localizedDescription, privacy: .public)")
            let settings = UserDefaultsSettingsRepository()
            let location = CoreLocationService()
            let calendar = EventKitCalendarService()
            let personalization = InMemoryPersonalizationRepository()
            let weather = FallbackWeatherProvider(providers: [WeatherKitWeatherProvider(), OpenMeteoWeatherProvider(), MockWeatherProvider()])
            return AppContainer(
                persistentContainer: nil,
                catalogPersistentContainer: nil,
                library: InMemoryLibraryRepository(books: []),
                forecast: WeatherKitForecastRepository(settings: settings, location: location, calendar: calendar, personalization: personalization, weather: weather),
                activity: InMemoryActivityRepository(records: []),
                sessions: InMemoryPlannedSessionRepository(),
                personalization: personalization,
                sessionProgress: UserDefaultsSessionProgressRepository(),
                readingActivity: LiveReadingActivityManager(),
                settings: settings,
                catalog: OpenLibraryCatalogService(),
                catalogCache: InMemoryCatalogSearchCache(),
                location: location,
                notifications: LocalNotificationScheduler(),
                calendar: calendar,
                startupError: "Saved data could not be opened. Pages Ahead is using temporary storage for this launch."
            )
        }
    }
    static var preview: AppContainer {
        let library = InMemoryLibraryRepository(books: SampleData.books)
        return AppContainer(
            persistentContainer: nil,
            catalogPersistentContainer: nil,
            library: library,
            forecast: MockForecastRepository(),
            activity: InMemoryActivityRepository(bookID: SampleData.books[0].id),
            sessions: InMemoryPlannedSessionRepository(),
            personalization: InMemoryPersonalizationRepository(),
            sessionProgress: InMemorySessionProgressRepository(),
            readingActivity: PreviewReadingActivityManager(),
            settings: UserDefaultsSettingsRepository(defaults: UserDefaults(suiteName: "PagesAheadPreview")!),
            catalog: PreviewCatalogService(),
            catalogCache: InMemoryCatalogSearchCache(),
            location: PreviewLocationService(),
            notifications: PreviewNotificationScheduler(),
            calendar: PreviewCalendarWriter(),
            startupError: nil
        )
    }

    static var uiTesting: AppContainer {
        let suiteName = "PagesAheadUITests-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let library = InMemoryLibraryRepository()
        return AppContainer(
            persistentContainer: nil,
            catalogPersistentContainer: nil,
            library: library,
            forecast: MockForecastRepository(),
            activity: InMemoryActivityRepository(records: []),
            sessions: InMemoryPlannedSessionRepository(),
            personalization: InMemoryPersonalizationRepository(),
            sessionProgress: InMemorySessionProgressRepository(),
            readingActivity: PreviewReadingActivityManager(),
            settings: UserDefaultsSettingsRepository(defaults: defaults),
            catalog: PreviewCatalogService(),
            catalogCache: InMemoryCatalogSearchCache(),
            location: PreviewLocationService(),
            notifications: PreviewNotificationScheduler(),
            calendar: PreviewCalendarWriter(),
            startupError: nil
        )
    }

    @MainActor
    private static func makeCatalogPersistence() -> (container: ModelContainer?, cache: CatalogSearchCaching) {
        do {
            let storeURL = URL.applicationSupportDirectory.appending(path: "CatalogCacheV2.store")
            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: StoredCatalogEntry.self, configurations: configuration)
            return (container, SwiftDataCatalogSearchCache(context: container.mainContext))
        } catch {
            logger.error("Catalog cache unavailable: \(error.localizedDescription, privacy: .public)")
            return (nil, InMemoryCatalogSearchCache())
        }
    }
}

final class InMemoryPlannedSessionRepository: PlannedSessionRepository {
    private var session: PlannedSession?
    func current() -> PlannedSession? { session }
    func save(_ session: PlannedSession) { self.session = session }
    func delete(id: UUID) { if session?.id == id { session = nil } }
}

final class InMemoryPersonalizationRepository: PersonalizationRepository {
    private var storage: [PersonalizationEvent] = []
    func events() -> [PersonalizationEvent] { storage }
    func record(_ event: PersonalizationEvent) { storage.append(event) }
    func clear() { storage.removeAll() }
}

final class UserDefaultsSessionProgressRepository: SessionProgressRepository {
    private let defaults: UserDefaults
    private let key = "activeReadingSession"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load(bookID: UUID) -> ActiveReadingSession? {
        guard let data = defaults.data(forKey: key),
              let session = try? JSONDecoder().decode(ActiveReadingSession.self, from: data),
              session.bookID == bookID else { return nil }
        return session
    }
    func save(_ session: ActiveReadingSession) { defaults.set(try? JSONEncoder().encode(session), forKey: key) }
    func clear(bookID: UUID) {
        guard load(bookID: bookID) != nil else { return }
        defaults.removeObject(forKey: key)
    }
}

final class InMemorySessionProgressRepository: SessionProgressRepository {
    private var session: ActiveReadingSession?
    func load(bookID: UUID) -> ActiveReadingSession? { session?.bookID == bookID ? session : nil }
    func save(_ session: ActiveReadingSession) { self.session = session }
    func clear(bookID: UUID) { if session?.bookID == bookID { session = nil } }
}
