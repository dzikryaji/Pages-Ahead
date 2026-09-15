import Foundation
import Observation

@MainActor @Observable
final class AppViewModel {
    enum Route: Equatable { case welcome, bookSetup, locationSetup, main }

    let container: AppContainer
    var route: Route
    var preferences: ReadingPreferences
    var manualCity: String
    var locationError: String?
    var isLocationPermissionDenied = false
    var isResolvingLocation = false

    init(container: AppContainer) {
        self.container = container
        route = container.settings.hasCompletedOnboarding ? .main : .welcome
        preferences = container.settings.preferences
        manualCity = container.settings.city
    }
    var welcomeActionTitle: String {
        container.library.books().isEmpty ? "Set Up My Reading Plan" : "Continue Setup"
    }
    var onboardingBook: Book? {
        let books = container.library.books()
        return books.first(where: { $0.status == .reading }) ?? books.first
    }

    func beginOnboarding() {
        route = container.library.books().isEmpty ? .bookSetup : .locationSetup
    }
    func finishBookSetup() {
        route = .locationSetup
    }
    func backToWelcome() {
        route = .welcome
    }
    func finishLocationSetup() {
        manualCity = manualCity.trimmingCharacters(in: .whitespacesAndNewlines)
        completeOnboarding()
    }
    func completeOnboarding() {
        persistPreferences()
        container.settings.hasCompletedOnboarding = true
        route = .main
    }
    func useCurrentLocation() async {
        isResolvingLocation = true
        isLocationPermissionDenied = false
        locationError = nil
        defer { isResolvingLocation = false }
        do {
            manualCity = try await container.location.requestCurrentLocation().city
            finishLocationSetup()
        }
        catch LocationError.denied {
            isLocationPermissionDenied = true
            locationError = LocationError.denied.localizedDescription
        }
        catch { locationError = error.localizedDescription }
    }
    func replayOnboarding() {
        container.settings.hasCompletedOnboarding = false
        preferences = container.settings.preferences
        manualCity = container.settings.city
        locationError = nil
        isLocationPermissionDenied = false
        route = .welcome
    }
    private func persistPreferences() {
        container.settings.preferences = preferences
        container.settings.city = manualCity
    }
}

@MainActor @Observable
final class ForecastViewModel {
    private let library: LibraryRepository
    private let repository: ForecastRepository
    private let sessions: PlannedSessionRepository
    private let personalization: PersonalizationRepository
    var books: [Book] = []
    var windows: [ReadingWindow] = []
    var plannedSession: PlannedSession?
    var showingPlanner = false
    var editingSession: PlannedSession?
    var planningWindow: ReadingWindow?
    var notice: String?
    var selectedBookID: UUID?
    var loadError: String?
    var isLoading = false

    init(library: LibraryRepository, repository: ForecastRepository, sessions: PlannedSessionRepository, personalization: PersonalizationRepository) {
        self.library = library
        self.repository = repository
        self.sessions = sessions
        self.personalization = personalization
        books = library.books()
        plannedSession = sessions.current()
    }

    var recommendedBook: Book? { selectedBookID.flatMap(book(id:)) ?? books.first(where: { $0.status == .reading }) ?? books.first }
    var personalizationRepository: PersonalizationRepository { personalization }
    func book(id: UUID) -> Book? { books.first { $0.id == id } }
    func reload() async {
        books = library.books()
        guard let book = recommendedBook else { windows = []; return }
        isLoading = true; loadError = nil
        defer { isLoading = false }
        do { windows = try await repository.readingWindows(for: book.id) }
        catch { windows = []; loadError = error.localizedDescription }
    }
    func selectBook(_ book: Book) async {
        selectedBookID = book.id
        await reload()
    }
    func addProgress(_ pages: Int, to book: Book) {
        var updated = book
        updated.currentPage = min(updated.pageCount, updated.currentPage + pages)
        updated.status = updated.currentPage >= updated.pageCount && updated.pageCount > 0 ? .finished : .reading
        library.update(updated)
        books = library.books()
    }
    func plan(_ session: PlannedSession) {
        sessions.save(session); plannedSession = session; showingPlanner = false; planningWindow = nil
        personalization.record(PersonalizationEvent(id: UUID(), kind: .accepted, date: .now,
            hour: Calendar.current.component(.hour, from: session.start),
            temperature: windows.first(where: { $0.start == session.start })?.temperature,
            place: session.place, reason: nil))
    }
    func reject(_ window: ReadingWindow, reason: String?) {
        personalization.record(PersonalizationEvent(id: UUID(), kind: .rejected, date: .now,
            hour: Calendar.current.component(.hour, from: window.start), temperature: window.temperature,
            place: window.place, reason: reason))
    }
    func cancel(_ session: PlannedSession) { sessions.delete(id: session.id); plannedSession = nil }
    func complete(_ session: PlannedSession) { sessions.delete(id: session.id); plannedSession = nil }
}

@MainActor @Observable
final class LibraryViewModel {
    private let repository: LibraryRepository
    private let coverImages: any BookCoverImageLoading
    var books: [Book] = []
    var query = ""

    init(
        repository: LibraryRepository,
        coverImages: (any BookCoverImageLoading)? = nil
    ) {
        self.repository = repository
        self.coverImages = coverImages ?? CoverImageCache.shared
        reload()
    }
    var filteredBooks: [Book] {
        guard !query.isEmpty else { return books }
        return books.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query) }
    }
    func books(with status: ReadingStatus) -> [Book] { filteredBooks.filter { $0.status == status } }
    func add(_ book: Book) {
        repository.add(book)
        reload()
        guard book.coverImageData == nil, let url = book.coverURL else { return }

        let coverImages = coverImages
        Task { [weak self] in
            guard let data = try? await coverImages.data(
                for: url,
                embeddedData: nil
            ), let self,
                  var storedBook = self.repository.books().first(where: {
                      $0.id == book.id
                  }) else { return }
            storedBook.coverImageData = data
            self.repository.update(storedBook)
            self.reload()
        }
    }
    func update(_ book: Book) { repository.update(book); reload() }
    func reload() { books = repository.books() }
}

@MainActor @Observable
final class ActivityViewModel {
    private let repository: ActivityRepository
    private let library: LibraryRepository
    var records: [ReadingRecord] = []
    var range = "Week"

    init(repository: ActivityRepository, library: LibraryRepository) { self.repository = repository; self.library = library; reload() }
    var visibleRecords: [ReadingRecord] {
        let days = range == "Month" ? -30 : -7
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .distantPast
        return records.filter { $0.date >= cutoff }
    }
    var totalMinutes: Int { visibleRecords.reduce(0) { $0 + $1.minutes } }
    var totalPages: Int { visibleRecords.reduce(0) { $0 + $1.pages } }
    var insight: String {
        let rainy = visibleRecords.filter { $0.weather.localizedCaseInsensitiveContains("rain") }
        let dry = visibleRecords.filter { !$0.weather.localizedCaseInsensitiveContains("rain") }
        guard !rainy.isEmpty, !dry.isEmpty else { return "Complete sessions in different conditions to reveal a useful pattern." }
        let rainyAverage = rainy.reduce(0) { $0 + $1.minutes } / rainy.count
        let dryAverage = dry.reduce(0) { $0 + $1.minutes } / dry.count
        let difference = rainyAverage - dryAverage
        if difference == 0 { return "Your average session length is similar in rainy and dry conditions." }
        let direction = difference > 0 ? "longer" : "shorter"
        return "Your rainy-session average is \(abs(difference)) minutes \(direction) than your dry-session average."
    }
    func book(for record: ReadingRecord) -> Book? { library.books().first { $0.id == record.bookID } }
    func save(_ record: ReadingRecord) { repository.save(record); reload() }
    func delete(_ record: ReadingRecord) { repository.delete(id: record.id); reload() }
    func reload() { records = repository.records() }
}

@MainActor @Observable
final class CatalogSearchViewModel {
    private let catalog: BookCatalogSearching
    private let cache: CatalogSearchCaching
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var hasActiveQuery = false
    var query = ""
    var state: LoadState<[Book]> = .idle
    var selected: Book?
    var isRefreshing = false

    init(catalog: BookCatalogSearching, cache: CatalogSearchCaching) {
        self.catalog = catalog
        self.cache = cache
    }

    func queryChanged(to value: String) {
        query = value
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        selected = nil
        isRefreshing = false

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            hasActiveQuery = false
            return
        }

        let cached = cache.results(for: trimmed)
        if let cached {
            state = .loaded(cached.books)
        } else {
            state = .loading
        }

        let delay: Duration = hasActiveQuery ? .seconds(1) : .zero
        hasActiveQuery = true
        let cacheAge = cached.map { Date.now.timeIntervalSince($0.fetchedAt) }
        let cacheIsFresh = cacheAge.map { $0 >= 0 && $0 < 30 * 86_400 } ?? false
        guard !cacheIsFresh else { return }

        isRefreshing = cached != nil
        searchTask = Task { [weak self] in
            do {
                if delay != .zero { try await Task.sleep(for: delay) }
                guard !Task.isCancelled, let self else { return }
                let books = try await self.catalog.search(query: trimmed)
                guard !Task.isCancelled, generation == self.searchGeneration else { return }
                let fetchedAt = Date.now
                self.cache.save(books, for: trimmed, fetchedAt: fetchedAt)
                self.state = .loaded(books)
                self.isRefreshing = false
            } catch is CancellationError {
                // Newer query owns visible state.
            } catch {
                guard let self, generation == self.searchGeneration else { return }
                self.isRefreshing = false
                if cached == nil { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    func coverLoaded(_ data: Data, for bookID: UUID) {
        guard case .loaded(var books) = state,
              let index = books.firstIndex(where: { $0.id == bookID }),
              books[index].coverImageData == nil else { return }
        books[index].coverImageData = data
        state = .loaded(books)
        if selected?.id == bookID { selected?.coverImageData = data }
        cache.saveCoverImage(data, for: bookID, query: query)
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}

struct CatalogSearchInitialState {
    var query = ""
    var state: LoadState<[Book]> = .idle
    var selected: Book?
    var isRefreshing = false
}

@MainActor @Observable
final class ReadingSessionViewModel {
    private let store: SessionProgressRepository
    private let activityManager: ReadingActivityManaging
    private let book: Book
    private var hasEndedLiveActivity = false
    private var hasLeftSession = false
    private(set) var session: ActiveReadingSession
    private var now = Date.now

    init(book: Book, durationMinutes: Int, store: SessionProgressRepository, activityManager: ReadingActivityManaging) {
        self.store = store
        self.activityManager = activityManager
        self.book = book
        if var restored = store.load(bookID: book.id) {
            if let startedAt = restored.startedAt, !restored.isPaused {
                restored.accumulatedSeconds += max(0, Int(Date.now.timeIntervalSince(startedAt)))
                restored.startedAt = .now
            }
            session = restored
        } else {
            session = ActiveReadingSession(bookID: book.id, durationSeconds: durationMinutes * 60,
                                           accumulatedSeconds: 0, startedAt: .now, isPaused: false)
        }
        persist()
    }

    var elapsedSeconds: Int {
        let running = session.startedAt.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
        return min(session.accumulatedSeconds + running, session.durationSeconds)
    }
    var remainingSeconds: Int { max(session.durationSeconds - elapsedSeconds, 0) }
    var isPaused: Bool { session.isPaused }

    func tick() { now = .now; if !session.isPaused && elapsedSeconds.isMultiple(of: 15) { persist() } }
    func startLiveActivity() async {
        guard !hasLeftSession, !hasEndedLiveActivity else { return }
        await activityManager.start(book: book, session: session)
        if hasLeftSession {
            await activityManager.end(bookID: book.id, session: session)
            hasEndedLiveActivity = true
        }
    }
    func togglePause() async {
        now = .now
        if session.isPaused { session.isPaused = false; session.startedAt = now }
        else { session.accumulatedSeconds = elapsedSeconds; session.startedAt = nil; session.isPaused = true }
        persist()
        await activityManager.update(bookID: book.id, session: session)
    }
    func persist() {
        var snapshot = session
        if !snapshot.isPaused { snapshot.accumulatedSeconds = elapsedSeconds; snapshot.startedAt = .now }
        store.save(snapshot)
    }
    func endLiveActivity() async {
        guard !hasEndedLiveActivity else { return }
        hasEndedLiveActivity = true
        await activityManager.end(bookID: book.id, session: session)
    }
    func leaveSession() async {
        hasLeftSession = true
        await endLiveActivity()
        store.clear(bookID: session.bookID)
    }
    func finish() async {
        await leaveSession()
    }
}
