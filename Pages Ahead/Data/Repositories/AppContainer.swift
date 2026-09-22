import Foundation
import OSLog
import SwiftData

struct AppContainer {
    // Retain the container for as long as its ModelContext-backed repositories live.
    // A ModelContext does not own its ModelContainer.
    let persistentContainer: ModelContainer?
    let catalogPersistentContainer: ModelContainer?
    let library: LibraryRepository
    let readingWindows: ReadingWindowRepository
    let activity: ActivityRepository
    let readingPlans: ReadingPlanRepository
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
            let schema = Schema([
                StoredBook.self,
                StoredReadingRecord.self,
                StoredReadingPlan.self,
                StoredPersonalizationEvent.self
            ])
            let container = try ModelContainer(for: schema)
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
                readingWindows: WeatherReadingWindowRepository(settings: settings, location: location, calendar: calendar, personalization: personalization, weather: weather),
                activity: SwiftDataActivityRepository(context: container.mainContext),
                readingPlans: SwiftDataReadingPlanRepository(context: container.mainContext),
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
                readingWindows: WeatherReadingWindowRepository(settings: settings, location: location, calendar: calendar, personalization: personalization, weather: weather),
                activity: InMemoryActivityRepository(records: []),
                readingPlans: InMemoryReadingPlanRepository(),
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
            readingWindows: MockReadingWindowRepository(),
            activity: InMemoryActivityRepository(bookID: SampleData.books[0].id),
            readingPlans: InMemoryReadingPlanRepository(),
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
    
    static var empty: AppContainer {
        let library = InMemoryLibraryRepository(books: [])
        return AppContainer(
            persistentContainer: nil,
            catalogPersistentContainer: nil,
            library: library,
            readingWindows: MockReadingWindowRepository(),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: InMemoryReadingPlanRepository(),
            personalization: InMemoryPersonalizationRepository(),
            sessionProgress: InMemorySessionProgressRepository(),
            readingActivity: PreviewReadingActivityManager(),
            settings: UserDefaultsSettingsRepository(defaults: UserDefaults(suiteName: "PagesAheadEmptyPreview")!),
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
            readingWindows: MockReadingWindowRepository(),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: InMemoryReadingPlanRepository(),
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
