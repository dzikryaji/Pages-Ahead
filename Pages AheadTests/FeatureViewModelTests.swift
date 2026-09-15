import Foundation
import Testing
@testable import Pages_Ahead

@MainActor
struct FeatureViewModelTests {
    @Test func onboardingRequiresBookThenCompletesAfterLocation() {
        let container = AppContainer.uiTesting
        let viewModel = AppViewModel(container: container)

        #expect(viewModel.route == .welcome)
        viewModel.beginOnboarding()
        #expect(viewModel.route == .bookSetup)

        container.library.add(SampleData.books[0])
        viewModel.finishBookSetup()
        #expect(viewModel.route == .locationSetup)

        viewModel.manualCity = "  Denpasar  "
        viewModel.finishLocationSetup()
        #expect(viewModel.route == .main)
        #expect(container.settings.city == "Denpasar")
        #expect(container.settings.hasCompletedOnboarding)

        viewModel.replayOnboarding()
        #expect(viewModel.route == .welcome)
        #expect(!container.settings.hasCompletedOnboarding)
        viewModel.beginOnboarding()
        #expect(viewModel.route == .locationSetup)
    }

    @Test func completedSessionProgressUpdatesBook() {
        let original = Book(id: UUID(), title: "Test Book", author: "Author", edition: "Edition", isbn: "1", pageCount: 100, status: .saved, currentPage: 10)
        let library = InMemoryLibraryRepository(books: [original])
        let viewModel = ForecastViewModel(library: library, repository: MockForecastRepository(), sessions: InMemoryPlannedSessionRepository(), personalization: InMemoryPersonalizationRepository())

        viewModel.addProgress(25, to: original)

        #expect(library.books().first?.currentPage == 35)
        #expect(library.books().first?.status == .reading)
    }

    @Test func completingFinalPagesMarksBookFinished() {
        let original = Book(id: UUID(), title: "Test Book", author: "Author", edition: "Edition", isbn: "1", pageCount: 100, status: .reading, currentPage: 95)
        let library = InMemoryLibraryRepository(books: [original])
        let viewModel = ForecastViewModel(library: library, repository: MockForecastRepository(), sessions: InMemoryPlannedSessionRepository(), personalization: InMemoryPersonalizationRepository())

        viewModel.addProgress(10, to: original)

        #expect(library.books().first?.currentPage == 100)
        #expect(library.books().first?.status == .finished)
    }

    @Test func readingSessionKeepsLiveActivityInSync() async {
        let manager = RecordingReadingActivityManager()
        let store = InMemorySessionProgressRepository()
        let book = SampleData.books[0]
        let viewModel = ReadingSessionViewModel(book: book, durationMinutes: 30, store: store, activityManager: manager)

        await viewModel.startLiveActivity()
        await viewModel.togglePause()
        await viewModel.finish()

        #expect(manager.startedBookID == book.id)
        #expect(manager.updatedSession?.isPaused == true)
        #expect(manager.endedBookID == book.id)
        #expect(store.load(bookID: book.id) == nil)
    }

    @Test func leavingReadingSessionStopsActivityAndClearsProgress() async {
        let manager = RecordingReadingActivityManager()
        let store = InMemorySessionProgressRepository()
        let book = SampleData.books[0]
        let viewModel = ReadingSessionViewModel(
            book: book,
            durationMinutes: 30,
            store: store,
            activityManager: manager
        )

        await viewModel.startLiveActivity()
        await viewModel.leaveSession()
        await viewModel.leaveSession()

        #expect(manager.endedBookID == book.id)
        #expect(manager.endCallCount == 1)
        #expect(store.load(bookID: book.id) == nil)
    }

    @Test func activityInsightUsesRecordedAverages() {
        let bookID = UUID()
        let records = [
            ReadingRecord(id: UUID(), bookID: bookID, date: .now, minutes: 40, pages: 10, weather: "Rain", place: "Home", feedback: "Calm", note: ""),
            ReadingRecord(id: UUID(), bookID: bookID, date: .now, minutes: 20, pages: 5, weather: "Clear", place: "Home", feedback: "Calm", note: "")
        ]
        let activity = InMemoryActivityRepository(bookID: bookID, records: records)
        let viewModel = ActivityViewModel(repository: activity, library: InMemoryLibraryRepository(books: []))

        #expect(viewModel.insight.contains("20 minutes longer"))
    }

    @Test func weatherProviderUsesNextAvailableSource() async throws {
        let candidate = ForecastCandidate(date: .now.addingTimeInterval(3_600), temperature: 25, condition: "Clear", symbolName: "sun.max.fill")
        let chain = FallbackWeatherProvider(providers: [FailingWeatherProvider(), FixedWeatherProvider(candidate: candidate)])

        let result = try await chain.hourlyForecast(at: LocationCoordinate(latitude: 0, longitude: 0))

        #expect(result.source == .openMeteo)
        #expect(result.candidates.first?.temperature == 25)
    }

    @Test func openMeteoResponseMapsIntoForecastCandidates() throws {
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
        let repository = WeatherKitForecastRepository(
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

    @Test func freshCatalogCacheSkipsNetwork() async throws {
        let cache = InMemoryCatalogSearchCache()
        cache.save([SampleData.books[0]], for: "d", fetchedAt: .now)
        let catalog = CatalogSpy()
        let viewModel = CatalogSearchViewModel(catalog: catalog, cache: cache)

        viewModel.queryChanged(to: "D")
        await Task.yield()
        let calls = await catalog.queries

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

        let callCount = await loader.callCount
        #expect(repository.books().first?.coverImageData == coverData)
        #expect(callCount == 1)
    }

    @Test func firstCatalogCharacterIsImmediateAndNewQueryCancelsOldWork() async throws {
        let catalog = CatalogSpy(delay: .milliseconds(300))
        let viewModel = CatalogSearchViewModel(catalog: catalog, cache: InMemoryCatalogSearchCache())

        viewModel.queryChanged(to: "D")
        try await Task.sleep(for: .milliseconds(40))
        let immediateQueries = await catalog.queries
        viewModel.queryChanged(to: "Du")
        try await Task.sleep(for: .milliseconds(150))
        let beforeDebounce = await catalog.queries
        try await Task.sleep(for: .seconds(1.25))
        let finalQueries = await catalog.queries

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

private actor FixedBookCoverLoader: BookCoverImageLoading {
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
    let candidate: ForecastCandidate
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

    func hourlyForecast(at coordinate: LocationCoordinate) async throws -> WeatherForecastBatch {
        await counter.increment()
        let candidates = (1...168).map { hour in
            ForecastCandidate(date: .now.addingTimeInterval(TimeInterval(hour * 3_600)),
                              temperature: 25, condition: "Clear", symbolName: "sun.max.fill")
        }
        return WeatherForecastBatch(candidates: candidates, source: .openMeteo)
    }
}

private actor CatalogSpy: BookCatalogSearching {
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
