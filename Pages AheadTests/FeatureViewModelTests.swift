import Foundation
import Testing
@testable import Pages_Ahead

@MainActor
struct FeatureViewModelTests {
    @Test func onboardingFollowsThreeLockedGroupsAndCommitsBooksAtEnd() async {
        let container = AppContainer.uiTesting
        let viewModel = AppFlowViewModel(container: container)

        #expect(viewModel.route == .onboarding(.welcome))
        viewModel.continueIntroduction()
        #expect(viewModel.route == .onboarding(.outcome))
        viewModel.continueIntroduction()
        #expect(viewModel.route == .onboarding(.howItWorks))
        viewModel.continueIntroduction()
        #expect(viewModel.route == .onboarding(.preferences))
        viewModel.finishPreferences()
        #expect(viewModel.route == .onboarding(.book))
        viewModel.setSelectedBooks(Array(SampleData.books.prefix(2)))
        viewModel.finishBookSetup()
        #expect(viewModel.route == .onboarding(.location))

        await viewModel.useCurrentLocation()
        #expect(viewModel.route == .onboarding(.location))
        await viewModel.finishLocationSetup()
        #expect(viewModel.route == .onboarding(.recommendations))
        #expect(!viewModel.recommendationCandidates.isEmpty)
        viewModel.planLater()
        #expect(viewModel.route == .onboarding(.complete))
        #expect(!container.settings.hasCompletedOnboarding)

        viewModel.completeOnboarding()
        #expect(viewModel.route == .main)
        #expect(container.settings.city == "Makassar")
        #expect(container.settings.hasCompletedOnboarding)
        #expect(container.library.books().count == 2)
        #expect(container.library.books().allSatisfy { $0.status == .saved })
    }

    @Test func onboardingBackNeverCrossesACompletedGroup() {
        let container = AppContainer.uiTesting
        let viewModel = AppFlowViewModel(container: container)

        viewModel.skipIntroduction()
        #expect(viewModel.route == .onboarding(.preferences))
        viewModel.goBack()
        #expect(viewModel.route == .onboarding(.preferences))
        viewModel.finishPreferences()
        #expect(viewModel.route == .onboarding(.book))
        viewModel.goBack()

        #expect(viewModel.route == .onboarding(.preferences))
        viewModel.go(to: .howItWorks)
        #expect(viewModel.route == .onboarding(.preferences))
    }

    @Test func onboardingResetsAfterAnInterruptedLaunch() {
        let container = AppContainer.uiTesting
        let first = AppFlowViewModel(container: container)
        first.skipIntroduction()
        first.finishPreferences()

        let resumed = AppFlowViewModel(container: container)
        #expect(resumed.route == .onboarding(.welcome))
        #expect(resumed.draft.selectedBooks.isEmpty)
    }

    @Test func planningAndReminderAreContextual() async {
        let container = AppContainer.uiTesting
        let viewModel = AppFlowViewModel(container: container)
        viewModel.skipIntroduction()
        viewModel.finishPreferences()
        viewModel.setSelectedBooks([SampleData.books[0]])
        viewModel.finishBookSetup()
        await viewModel.useCurrentLocation()
        await viewModel.finishLocationSetup()

        await viewModel.confirmSelectedTime()
        #expect(viewModel.draft.readingPlan != nil)
        #expect(viewModel.route == .onboarding(.complete))
        #expect(container.readingPlans.current()?.reminderEnabled == true)
        #expect(container.readingPlans.current()?.bookID == nil)
        #expect(container.settings.hasCreatedReadingPlan)
    }

    @Test func planLaterRemovesOnlyProvisionalOnboardingPlan() async {
        let container = AppContainer.uiTesting
        let viewModel = AppFlowViewModel(container: container)
        viewModel.skipIntroduction()
        viewModel.finishPreferences()
        viewModel.setSelectedBooks([SampleData.books[0]])
        viewModel.finishBookSetup()
        await viewModel.useCurrentLocation()
        await viewModel.finishLocationSetup()
        viewModel.planSelectedTime()
        #expect(container.readingPlans.current() != nil)

        viewModel.planLater()

        #expect(container.readingPlans.current() == nil)
    }

    @Test func replayPrefillsWithoutDuplicatingBookOrPlan() async {
        let container = AppContainer.uiTesting
        container.library.add(SampleData.books[0])
        let session = ReadingPlan(
            id: UUID(), start: .now.addingTimeInterval(7_200),
            durationMinutes: 30, place: "Indoors",
            bookID: SampleData.books[0].id, reminderEnabled: false,
            calendarEnabled: false
        )
        container.readingPlans.save(session)
        container.settings.hasCompletedOnboarding = true
        let viewModel = AppFlowViewModel(container: container)

        viewModel.replayOnboarding()
        #expect(viewModel.route == .onboarding(.welcome))
        #expect(!container.settings.hasCompletedOnboarding)
        #expect(viewModel.draft.selectedBooks.first?.id == SampleData.books[0].id)
        #expect(viewModel.draft.readingPlan?.id == session.id)

        viewModel.skipIntroduction()
        viewModel.finishPreferences()
        viewModel.finishBookSetup()
        viewModel.go(to: .complete)
        viewModel.completeOnboarding()
        #expect(container.library.books().count == 1)
        #expect(container.readingPlans.current()?.id == session.id)
    }

    @Test func readingSessionKeepsLiveActivityInSync() async {
        let manager = RecordingReadingActivityManager()
        let store = InMemorySessionProgressRepository()
        let book = SampleData.books[0]
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: [book]),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: InMemoryReadingPlanRepository(),
            progressStore: store,
            activityManager: manager,
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter()
        )

        #expect(coordinator.start(book: book, origin: .bookDetail))
        await Task.yield()
        await coordinator.togglePause()
        await coordinator.endWithoutSaving()

        #expect(manager.startedBookID == book.id)
        #expect(manager.updatedSession?.isPaused == true)
        #expect(manager.endedBookID == book.id)
        #expect(store.load(bookID: book.id) == nil)
    }

    @Test func leavingReadingSessionStopsActivityAndClearsProgress() async {
        let manager = RecordingReadingActivityManager()
        let store = InMemorySessionProgressRepository()
        let book = SampleData.books[0]
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: [book]),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: InMemoryReadingPlanRepository(),
            progressStore: store,
            activityManager: manager,
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter()
        )

        #expect(coordinator.start(book: book, origin: .bookDetail))
        await Task.yield()
        await coordinator.endWithoutSaving()
        await coordinator.endWithoutSaving()

        #expect(manager.endedBookID == book.id)
        #expect(manager.endCallCount == 1)
        #expect(store.load(bookID: book.id) == nil)
    }

    @Test func activityInsightUsesRecordedAverages() {
        let bookID = UUID()
        let records = [
            ReadingRecord(id: UUID(), bookID: bookID, date: .now, minutes: 40, pages: 10, weather: "Rain"),
            ReadingRecord(id: UUID(), bookID: bookID, date: .now, minutes: 20, pages: 5, weather: "Clear")
        ]
        let activity = InMemoryActivityRepository(bookID: bookID, records: records)
        let viewModel = ActivityViewModel(repository: activity, library: InMemoryLibraryRepository(books: []))

        #expect(viewModel.insight.contains("20 minutes longer"))
    }

    @Test func weatherProviderUsesNextAvailableSource() async throws {
        let candidate = HourlyWeatherSnapshot(date: .now.addingTimeInterval(3_600), temperature: 25, condition: "Clear", symbolName: "sun.max.fill")
        let chain = FallbackWeatherProvider(providers: [FailingWeatherProvider(), FixedWeatherProvider(candidate: candidate)])

        let result = try await chain.hourlyForecast(at: LocationCoordinate(latitude: 0, longitude: 0))

        #expect(result.source == .openMeteo)
        #expect(result.candidates.first?.temperature == 25)
    }

    @Test func openMeteoResponseMapsIntoHourlyWeatherSnapshots() throws {
        let data = Data(#"{"hourly":{"time":[4102444800],"temperature_2m":[27.4],"weather_code":[61]}}"#.utf8)

        let result = try OpenMeteoWeatherProvider().decode(data, now: Date(timeIntervalSince1970: 0))

        #expect(result.source == .openMeteo)
        #expect(result.candidates.first?.temperature == 27)
        #expect(result.candidates.first?.condition == "Rain")
        #expect(result.candidates.first?.symbolName == "cloud.rain.fill")
    }

    @Test func weatherUsesDailyCacheUntilCityChanges() async throws {
        let suite = "WeatherCacheTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = UserDefaultsSettingsRepository(defaults: defaults)
        var preferences = settings.preferences
        preferences.availableDays = Set(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        settings.preferences = preferences
        settings.city = "Makassar"
        let counter = WeatherCallCounter()
        let repository = WeatherReadingWindowRepository(
            settings: settings,
            location: PreviewLocationService(),
            calendar: PreviewCalendarWriter(),
            personalization: InMemoryPersonalizationRepository(),
            weather: CountingWeatherProvider(counter: counter),
            cache: UserDefaultsWeatherForecastCache(defaults: defaults, key: "testWeather")
        )

        let first = try await repository.readingWindows(for: UUID())
        let second = try await repository.readingWindows(for: UUID())
        let callsBeforeMove = await counter.value
        settings.city = "Denpasar"
        _ = try await repository.readingWindows(for: UUID())
        let callsAfterMove = await counter.value
        let secondResponseWasCached = second.allSatisfy { $0.isCached }

        #expect(!first.isEmpty)
        #expect(secondResponseWasCached)
        #expect(callsBeforeMove == 1)
        #expect(callsAfterMove == 2)
    }

    @Test func weatherRefreshesWhenClosestCachedRangeHasEnded() async throws {
        let suite = "WeatherExpiredWindowTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let fixedNow = Date(timeIntervalSince1970: 4_104_993_600)
        let settings = UserDefaultsSettingsRepository(defaults: defaults)
        settings.city = "Makassar"
        var preferences = ReadingPreferences()
        preferences.weekdayPreferredTime = "Anytime"
        preferences.weekendPreferredTime = "Anytime"
        settings.preferences = preferences
        let cache = UserDefaultsWeatherForecastCache(defaults: defaults, key: "expiredWindow")
        let oldHours = (18...20).map { hour in
            HourlyWeatherSnapshot(
                date: fixedNow.addingTimeInterval(TimeInterval((-24 + hour - 18) * 3_600)),
                temperature: 24,
                condition: "Clear",
                symbolName: "sun.max.fill"
            )
        }
        cache.save(
            WeatherForecastBatch(candidates: oldHours, source: .openMeteo),
            for: "Makassar",
            at: fixedNow.addingTimeInterval(-20 * 3_600)
        )
        let counter = WeatherCallCounter()
        let repository = WeatherReadingWindowRepository(
            settings: settings,
            location: PreviewLocationService(),
            calendar: PreviewCalendarWriter(),
            personalization: InMemoryPersonalizationRepository(),
            weather: CountingWeatherProvider(counter: counter, start: fixedNow),
            cache: cache,
            nowProvider: { fixedNow }
        )

        let windows = try await repository.readingWindows(for: UUID())

        #expect(await counter.value == 1)
        #expect(!windows.isEmpty)
        #expect(windows.allSatisfy { !$0.isCached })
    }

    @Test func freshCatalogCacheSkipsNetwork() async throws {
        let cache = InMemoryCatalogSearchCache()
        cache.save([SampleData.books[0]], for: "d", fetchedAt: .now)
        let catalog = CatalogSpy()
        let viewModel = CatalogSearchViewModel(catalog: catalog, cache: cache)

        viewModel.queryChanged(to: "D")
        await Task.yield()
        let calls = catalog.queries

        guard case .loaded(let books) = viewModel.state else {
            Issue.record("Expected cached books")
            return
        }
        #expect(books.first?.title == SampleData.books[0].title)
        #expect(calls.isEmpty)
    }

    @Test func catalogReturnsMetadataWithoutWaitingForCovers() throws {
        let data = Data(
            #"{"docs":[{"key":"/works/OL1W","title":"Dune","author_name":["Frank Herbert"],"isbn":["9780441013593"],"cover_i":42}]}"#.utf8
        )

        let books = try OpenLibraryCatalogService().decode(data)

        #expect(books.first?.title == "Dune")
        #expect(books.first?.coverURL?.absoluteString.contains("42-M.jpg") == true)
        #expect(books.first?.coverImageData == nil)
    }

    @Test func addingBookDownloadsAndStoresCover() async throws {
        let coverData = Data([1, 2, 3, 4])
        let repository = InMemoryLibraryRepository()
        let loader = FixedBookCoverLoader(data: coverData)
        let viewModel = LibraryViewModel(
            repository: repository,
            coverImages: loader
        )
        var book = SampleData.books[0]
        book.coverURL = URL(string: "https://example.com/cover.jpg")
        book.coverImageData = nil

        viewModel.add(book)
        for _ in 0..<20 where repository.books().first?.coverImageData == nil {
            try await Task.sleep(for: .milliseconds(10))
        }

        let callCount = loader.callCount
        #expect(repository.books().first?.coverImageData == coverData)
        #expect(callCount == 1)
    }

    @Test func firstCatalogCharacterIsImmediateAndNewQueryCancelsOldWork() async throws {
        let catalog = CatalogSpy(delay: .milliseconds(300))
        let viewModel = CatalogSearchViewModel(catalog: catalog, cache: InMemoryCatalogSearchCache())

        viewModel.queryChanged(to: "D")
        try await Task.sleep(for: .milliseconds(40))
        let immediateQueries = catalog.queries
        viewModel.queryChanged(to: "Du")
        try await Task.sleep(for: .milliseconds(150))
        let beforeDebounce = catalog.queries
        try await Task.sleep(for: .seconds(1.25))
        let finalQueries = catalog.queries

        #expect(immediateQueries == ["D"])
        #expect(beforeDebounce == ["D"])
        #expect(finalQueries == ["D", "Du"])
        guard case .loaded(let books) = viewModel.state else {
            Issue.record("Expected newest query results")
            return
        }
        #expect(books.first?.title == "Result Du")
    }
}

@MainActor
private final class FixedBookCoverLoader: BookCoverImageLoading {
    let data: Data
    private(set) var callCount = 0

    init(data: Data) { self.data = data }

    func data(for url: URL, embeddedData: Data?) async throws -> Data {
        callCount += 1
        return data
    }
}

private struct FailingWeatherProvider: WeatherProviding {
    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        throw WeatherProviderError.noForecast
    }
}

private struct FixedWeatherProvider: WeatherProviding {
    let candidate: HourlyWeatherSnapshot
    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        WeatherForecastBatch(candidates: [candidate], source: .openMeteo)
    }
}

private actor WeatherCallCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private struct CountingWeatherProvider: WeatherProviding {
    let counter: WeatherCallCounter
    var start: Date = .now

    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        await counter.increment()
        let candidates = (1...168).map { hour in
            HourlyWeatherSnapshot(date: start.addingTimeInterval(TimeInterval(hour * 3_600)),
                              temperature: 25, condition: "Clear", symbolName: "sun.max.fill")
        }
        return WeatherForecastBatch(candidates: candidates, source: .openMeteo)
    }
}

@MainActor
private final class CatalogSpy: BookCatalogSearching {
    private(set) var queries: [String] = []
    let delay: Duration

    init(delay: Duration = .zero) { self.delay = delay }

    func search(query: String) async throws -> [Book] {
        queries.append(query)
        if delay != .zero { try await Task.sleep(for: delay) }
        return [Book(id: UUID(), title: "Result \(query)", author: "Author", edition: "Edition",
                     isbn: query, pageCount: 100, status: .saved, currentPage: 0)]
    }
}

@MainActor
private final class RecordingReadingActivityManager: ReadingActivityManaging {
    var startedBookID: UUID?
    var updatedSession: ActiveReadingSession?
    var endedBookID: UUID?
    var endCallCount = 0

    func start(book: Book, session: ActiveReadingSession) async { startedBookID = book.id }
    func update(bookID: UUID, session: ActiveReadingSession) async { updatedSession = session }
    func end(bookID: UUID, session: ActiveReadingSession) async {
        endedBookID = bookID
        endCallCount += 1
    }
}
