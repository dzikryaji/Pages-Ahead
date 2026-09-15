import Foundation
import Observation
import OSLog

@MainActor @Observable
final class AppViewModel {
    enum Route: Equatable {
        case onboarding(OnboardingPage)
        case main
    }

    let container: AppContainer
    var route: Route
    var draft: OnboardingDraft
    var locationError: String?
    var isLocationPermissionDenied = false
    var isResolvingLocation = false
    var recommendationError: String?
    var isLoadingRecommendations = false
    var isSchedulingReminder = false
    var startReadingAfterOnboarding = false

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PagesAhead",
        category: "onboarding"
    )

    init(container: AppContainer) {
        self.container = container
        if container.settings.hasCompletedOnboarding {
            draft = OnboardingDraft(
                introductionSeen: true,
                currentPage: .complete,
                preferences: container.settings.preferences,
                selectedBooks: container.library.books(),
                resolvedCity: container.settings.city,
                plannedSession: container.sessions.current()
            )
            route = .main
        } else {
            container.settings.onboardingDraft = nil
            let initialDraft = OnboardingDraft()
            draft = initialDraft
            route = .onboarding(initialDraft.currentPage)
            Self.logger.info("onboarding_started")
        }
    }

    var preferences: ReadingPreferences {
        get { draft.preferences }
        set { draft.preferences = newValue; invalidateRecommendations(); persistDraft() }
    }

    var manualCity: String {
        get { draft.resolvedCity }
        set { draft.resolvedCity = newValue; persistDraft() }
    }

    var onboardingBook: Book? {
        draft.selectedBooks.first ?? Self.preferredBook(in: container.library)
    }

    var recommendationCandidates: [ReadingWindow] {
        draft.recommendationCandidates
    }

    var selectedCandidate: ReadingWindow? {
        guard let id = draft.selectedCandidateID else { return nil }
        return draft.recommendationCandidates.first { $0.id == id }
    }

    func continueIntroduction() {
        switch draft.currentPage {
        case .welcome: go(to: .outcome)
        case .outcome: go(to: .howItWorks)
        case .howItWorks:
            draft.introductionSeen = true
            go(to: .preferences)
        default: break
        }
    }

    func skipIntroduction() {
        draft.introductionSeen = true
        log("introduction_skipped")
        go(to: .preferences)
    }

    func finishPreferences() {
        log("preferences_completed")
        go(to: .book)
    }

    func chooseBook(_ book: Book) {
        if !draft.selectedBooks.contains(where: { $0.id == book.id }) {
            draft.selectedBooks.append(book)
        }
        persistDraft()
        log("book_selected")
    }

    func setSelectedBooks(_ books: [Book]) {
        draft.selectedBooks = books
        persistDraft()
        log("books_selected")
    }

    func finishBookSetup() {
        guard !draft.selectedBooks.isEmpty else { return }
        go(to: .location)
    }

    func updateBookSearch(query: String, results: [Book]) {
        if draft.bookSearchQuery.isEmpty,
           !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log("book_search_started")
        }
        draft.bookSearchQuery = query
        draft.bookSearchResults = results
        persistDraft()
    }

    func useManualCity() async {
        let city = manualCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else {
            locationError = "Enter a city to continue."
            return
        }
        isResolvingLocation = true
        locationError = nil
        defer { isResolvingLocation = false }
        do {
            _ = try await container.location.coordinate(for: city)
            acceptLocation(city: city, mode: .manual)
        } catch {
            locationError = "We couldn't find that city. Check the spelling and try again."
        }
    }

    func completeOnboarding() {
        guard draft.currentPage == .complete else { return }
        container.settings.preferences = draft.preferences
        container.settings.city = draft.resolvedCity
        for var book in draft.selectedBooks {
            guard !container.library.books().contains(where: { $0.id == book.id }) else {
                continue
            }
            book.status = .saved
            container.library.add(book)
        }
        if let session = draft.plannedSession { container.sessions.save(session) }
        container.settings.hasCompletedOnboarding = true
        container.settings.onboardingDraft = nil
        route = .main
        log("onboarding_completed")
    }

    func completeAndStartReading() {
        guard draft.plannedSession != nil else { return }
        startReadingAfterOnboarding = true
        completeOnboarding()
    }

    func useCurrentLocation() async {
        isResolvingLocation = true
        isLocationPermissionDenied = false
        locationError = nil
        defer { isResolvingLocation = false }
        do {
            let city = try await container.location.requestCurrentLocation().city
            log("location_permission_outcome")
            acceptLocation(city: city, mode: .current)
        }
        catch LocationError.denied {
            isLocationPermissionDenied = true
            locationError = LocationError.denied.localizedDescription
            log("location_permission_outcome")
        }
        catch {
            locationError = error.localizedDescription
            log("location_permission_outcome")
        }
    }

    func finishLocationSetup() async {
        guard !draft.resolvedCity.isEmpty else { return }
        go(to: .recommendations)
        await loadRecommendations()
    }

    func loadRecommendations() async {
        guard !draft.selectedBooks.isEmpty, !draft.resolvedCity.isEmpty else {
            recommendationError = "Choose a book and city before loading reading times."
            return
        }
        isLoadingRecommendations = true
        recommendationError = nil
        defer { isLoadingRecommendations = false }
        do {
            let windows = try await container.forecast.readingWindows(
                for: draft.selectedBooks[0].id,
                preferences: draft.preferences,
                city: draft.resolvedCity
            ).filter { $0.end > .now }
            draft.recommendationCandidates = windows
            if !windows.contains(where: { $0.id == draft.selectedCandidateID }) {
                draft.selectedCandidateID = windows.first?.id
            }
            persistDraft()
            log("recommendations_loaded")
        } catch {
            recommendationError = error.localizedDescription
            log("recommendations_failed")
        }
    }

    func selectCandidate(_ candidate: ReadingWindow) {
        draft.selectedCandidateID = candidate.id
        persistDraft()
        log("recommendation_selected")
    }

    func chooseAnotherTime() {
        let visibleCandidates = Array(recommendationCandidates.prefix(3))
        guard !visibleCandidates.isEmpty else { return }
        let current = visibleCandidates.firstIndex {
            $0.id == draft.selectedCandidateID
        } ?? -1
        let next = (current + 1) % visibleCandidates.count
        selectCandidate(visibleCandidates[next])
    }

    func planSelectedTime(now: Date = .now) {
        guard let candidate = selectedCandidate else { return }
        guard candidate.end > now else {
            recommendationError = "That time has passed. Refresh to choose another upcoming time."
            return
        }
        let session = PlannedSession(
            id: draft.plannedSession?.id ?? UUID(),
            start: max(candidate.start, now),
            durationMinutes: max(1, Int(candidate.end.timeIntervalSince(max(candidate.start, now)) / 60)),
            place: candidate.place,
            bookID: nil,
            reminderEnabled: false,
            calendarEnabled: false
        )
        container.sessions.save(session)
        container.settings.hasCreatedReadingPlan = true
        draft.plannedSession = session
        draft.plannedDuringOnboarding = true
        draft.reminderChoice = .undecided
        draft.notificationOutcome = .notRequested
        persistDraft()
        log("plan_created")
    }

    func confirmSelectedTime() async {
        planSelectedTime()
        guard draft.plannedSession != nil else { return }
        await enableReminder()
    }

    func planLater() {
        if draft.plannedDuringOnboarding, let session = draft.plannedSession {
            container.sessions.delete(id: session.id)
        }
        draft.plannedSession = nil
        draft.plannedDuringOnboarding = false
        draft.reminderChoice = .notNow
        draft.notificationOutcome = .notRequested
        log("plan_deferred")
        go(to: .complete)
    }

    func declineReminder() {
        guard var session = draft.plannedSession else { return }
        session.reminderEnabled = false
        container.notifications.cancel(sessionID: session.id)
        container.sessions.save(session)
        draft.plannedSession = session
        draft.plannedDuringOnboarding = true
        draft.reminderChoice = .notNow
        draft.notificationOutcome = .notRequested
        log("reminder_choice")
        go(to: .complete)
    }

    func enableReminder() async {
        guard var session = draft.plannedSession else { return }
        isSchedulingReminder = true
        defer { isSchedulingReminder = false }
        draft.reminderChoice = .allow
        log("reminder_choice")
        do {
            let scheduled = try await container.notifications.schedule(
                session: session,
                bookTitle: "a book",
                leadMinutes: draft.preferences.reminderLeadTime
            )
            session.reminderEnabled = scheduled
            draft.notificationOutcome = scheduled ? .scheduled : .denied
        } catch {
            session.reminderEnabled = false
            draft.notificationOutcome = .unavailable
        }
        container.sessions.save(session)
        draft.plannedSession = session
        draft.plannedDuringOnboarding = true
        log("notification_permission_outcome")
        go(to: .complete)
    }

    func goBack() {
        let destination: OnboardingPage? = switch draft.currentPage {
        case .welcome: nil
        case .outcome: .welcome
        case .howItWorks: .outcome
        case .preferences: nil
        case .book: .preferences
        case .location: .book
        case .recommendations: .location
        case .complete: nil
        }
        if let destination { go(to: destination) }
    }

    func go(to page: OnboardingPage) {
        guard page.group >= draft.currentPage.group else { return }
        draft.currentPage = page
        route = .onboarding(page)
        persistDraft()
        log("page_\(page.rawValue)_viewed")
    }

    func persistDraft() {
        container.settings.onboardingDraft = nil
    }

    func replayOnboarding() {
        container.settings.hasCompletedOnboarding = false
        draft = OnboardingDraft(
            introductionSeen: false,
            currentPage: .welcome,
            preferences: container.settings.preferences,
            selectedBooks: container.library.books(),
            resolvedCity: container.settings.city,
            plannedSession: container.sessions.current()
        )
        locationError = nil
        isLocationPermissionDenied = false
        recommendationError = nil
        route = .onboarding(.welcome)
        persistDraft()
    }

    private func acceptLocation(city: String, mode: OnboardingLocationMode) {
        let changed = draft.resolvedCity.normalizedCacheKey != city.normalizedCacheKey
        draft.resolvedCity = city
        draft.locationMode = mode
        if changed { invalidateRecommendations() }
        log("location_method_selected")
    }

    private func invalidateRecommendations() {
        draft.recommendationCandidates = []
        draft.selectedCandidateID = nil
        draft.plannedSession = nil
        draft.plannedDuringOnboarding = false
        draft.reminderChoice = .undecided
        draft.notificationOutcome = .notRequested
    }

    private static func preferredBook(in library: LibraryRepository) -> Book? {
        let books = library.books()
        return books.first(where: { $0.status == .reading }) ?? books.first
    }

    private func log(_ event: String) {
        Self.logger.info("\(event, privacy: .public)")
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
    func book(id: UUID?) -> Book? {
        guard let id else { return nil }
        return books.first { $0.id == id }
    }
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
