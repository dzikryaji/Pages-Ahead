#if DEBUG
import SwiftUI
import TipKit

enum ScreenshotScenario {
    static var current: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot-scenario"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

@MainActor
struct ScreenshotScenarioView: View {
    let scenario: String
    private let container: AppContainer

    init(scenario: String) {
        self.scenario = scenario
        container = Self.makeContainer(for: scenario)
    }

    @ViewBuilder
    var body: some View {
        switch scenario {
        case "welcome_new":
            WelcomeView(actionTitle: "Set Up My Reading Plan", getStarted: {})
        case "welcome_returning":
            WelcomeView(actionTitle: "Continue Setup", getStarted: {})
        case "onboarding_book_idle":
            onboardingBook(.init())
        case "onboarding_book_keyboard":
            onboardingBook(.init(), focus: true)
        case "onboarding_book_loading":
            onboardingBook(.init(query: "Left", state: .loading))
        case "onboarding_book_error":
            onboardingBook(.init(query: "Left", state: .failed("Book catalog is temporarily unavailable. Check your connection and try again.")))
        case "onboarding_book_empty":
            onboardingBook(.init(query: "Unknown title", state: .loaded([])))
        case "onboarding_book_results":
            onboardingBook(.init(query: "Book", state: .loaded(SampleData.books)))
        case "onboarding_book_selected":
            onboardingBook(.init(query: "Left", state: .loaded(SampleData.books), selected: SampleData.books[0]))
        case "onboarding_book_refreshing":
            onboardingBook(.init(query: "Left", state: .loaded(SampleData.books), isRefreshing: true))
        case "location_default":
            LocationSetupView(viewModel: appViewModel())
        case "location_resolving":
            LocationSetupView(viewModel: appViewModel(resolving: true))
        case "location_error":
            LocationSetupView(viewModel: appViewModel(error: "Location could not be determined. Choose a city instead."))
        case "location_denied":
            LocationSetupView(viewModel: appViewModel(error: "Location access was denied.", denied: true))
        case "location_manual_city":
            LocationSetupView(viewModel: appViewModel(), enteringCity: true)
        case "main_tabs_forecast":
            MainTabView(container: container)
        case "forecast_loading":
            forecast(.loading)
        case "forecast_error":
            forecast(.error)
        case "forecast_no_book":
            forecast(.noBook)
        case "forecast_loaded":
            forecast(.loaded)
        case "forecast_cached":
            forecast(.cached)
        case "forecast_planned":
            forecast(.planned)
        case "forecast_detail":
            forecastDetail(showsTip: false)
        case "forecast_detail_tip":
            forecastDetail(showsTip: true)
        case "forecast_feedback_dialog":
            forecastDetail(showsTip: false, feedback: true)
        case "plan_session_new":
            planSession()
        case "plan_session_edit":
            planSession(editing: true)
        case "plan_session_error":
            planSession(error: "Calendar access is unavailable. Your reading plan was not changed.")
        case "book_alternatives":
            BookAlternativesView(books: SampleData.books, selected: SampleData.books[0], choose: { _ in })
        case "library_empty":
            library()
        case "library_populated":
            library()
        case "library_no_results":
            library(query: "No matching title")
        case "add_book_idle":
            addBook(.init())
        case "add_book_keyboard":
            addBook(.init(), focus: true)
        case "add_book_loading":
            addBook(.init(query: "Left", state: .loading))
        case "add_book_error":
            addBook(.init(query: "Left", state: .failed("Book catalog is temporarily unavailable. Check your connection and try again.")))
        case "add_book_empty":
            addBook(.init(query: "Unknown title", state: .loaded([])))
        case "add_book_results":
            addBook(.init(query: "Book", state: .loaded(SampleData.books)))
        case "add_book_selected":
            addBook(.init(query: "Left", state: .loaded(SampleData.books), selected: SampleData.books[0]))
        case "add_book_refreshing":
            addBook(.init(query: "Left", state: .loaded(SampleData.books), isRefreshing: true))
        case "book_detail_reading":
            bookDetail(SampleData.books[0])
        case "book_detail_saved":
            bookDetail(SampleData.books[1])
        case "reading_session_running":
            readingSession()
        case "reading_session_paused":
            readingSession(paused: true)
        case "reading_session_exit_alert":
            readingSession(confirmingClose: true)
        case "reading_focus_setup":
            NavigationStack { ReadingFocusShortcutSetupView() }
        case "session_complete":
            sessionComplete()
        case "activity_empty", "activity_populated":
            ActivityView(viewModel: ActivityViewModel(repository: container.activity, library: container.library))
        case "session_detail":
            sessionDetail()
        case "session_detail_editing":
            sessionDetail(editing: true)
        case "session_delete_alert":
            sessionDetail(confirmingDelete: true)
        case "settings":
            NavigationStack { SettingsView(settings: container.settings, personalization: container.personalization) }
        case "reading_preferences", "availability", "notifications_focus", "location_settings", "privacy", "privacy_clear_alert":
            SettingsDetailScreenshot(scenario: scenario, personalization: container.personalization)
        case "personalization_empty":
            NavigationStack { PersonalizationDataView(events: [], preferences: ReadingPreferences()) }
        case "personalization_populated":
            NavigationStack { PersonalizationDataView(events: sampleEvents, preferences: ReadingPreferences()) }
        case "live_activity_running":
            LiveActivityReferenceView(mode: .lockScreen, paused: false)
        case "live_activity_paused":
            LiveActivityReferenceView(mode: .lockScreen, paused: true)
        case "dynamic_island_expanded":
            LiveActivityReferenceView(mode: .expanded, paused: false)
        case "dynamic_island_compact":
            LiveActivityReferenceView(mode: .compact, paused: false)
        case "dynamic_island_minimal":
            LiveActivityReferenceView(mode: .minimal, paused: false)
        default:
            ContentUnavailableView(
                "Unknown screenshot scenario",
                systemImage: "questionmark.square.dashed",
                description: Text(scenario)
            )
        }
    }

    private func onboardingBook(_ initial: CatalogSearchInitialState, focus: Bool = false) -> some View {
        OnboardingBookSetupView(viewModel: appViewModel(), initialSearch: initial, focusSearchOnAppear: focus)
    }

    private func appViewModel(error: String? = nil, denied: Bool = false, resolving: Bool = false) -> AppViewModel {
        let viewModel = AppViewModel(container: container)
        viewModel.locationError = error
        viewModel.isLocationPermissionDenied = denied
        viewModel.isResolvingLocation = resolving
        return viewModel
    }

    private enum ForecastState { case loading, error, noBook, loaded, cached, planned }

    private func forecast(_ state: ForecastState) -> some View {
        let viewModel = ForecastViewModel(
            library: container.library,
            repository: container.forecast,
            sessions: container.sessions,
            personalization: container.personalization
        )
        viewModel.books = state == .noBook ? [] : SampleData.books
        viewModel.windows = state == .noBook ? [] : SampleData.windows(bookID: SampleData.books[0].id)
        viewModel.isLoading = state == .loading
        viewModel.loadError = state == .error ? "Weather services are unavailable. Check your connection and try again." : nil
        if state == .cached {
            viewModel.windows = viewModel.windows.map {
                var window = $0
                window.isCached = true
                window.weatherSource = .openMeteo
                return window
            }
        }
        if state == .planned, let window = viewModel.windows.first {
            viewModel.plannedSession = PlannedSession(
                id: UUID(),
                start: window.start,
                durationMinutes: window.durationMinutes,
                place: window.place,
                bookID: window.bookID,
                reminderEnabled: true,
                calendarEnabled: false
            )
        }
        return ForecastHomeView(
            viewModel: viewModel,
            activityRepository: container.activity,
            sessionProgress: container.sessionProgress,
            readingActivity: container.readingActivity,
            notifications: container.notifications,
            calendarWriter: container.calendar,
            settings: container.settings,
            personalization: container.personalization,
            loadsOnAppear: false
        )
    }

    private func forecastDetail(showsTip: Bool, feedback: Bool = false) -> some View {
        NavigationStack {
            ForecastDetailView(
                window: SampleData.windows(bookID: SampleData.books[0].id)[0],
                book: SampleData.books[0],
                allBooks: SampleData.books,
                showsFeedbackTip: showsTip,
                feedbackInitiallyPresented: feedback,
                startsAtFeedbackActions: showsTip,
                plan: {},
                reject: { _ in },
                chooseBook: { _ in }
            )
        }
    }

    private func planSession(editing: Bool = false, error: String? = nil) -> some View {
        let window = SampleData.windows(bookID: SampleData.books[0].id)[0]
        let existing = editing ? PlannedSession(
            id: UUID(), start: window.start, durationMinutes: 45, place: "Café",
            bookID: window.bookID, reminderEnabled: true, calendarEnabled: true
        ) : nil
        return PlanSessionView(
            window: window,
            book: SampleData.books[0],
            existingSession: existing,
            defaultReminder: true,
            reminderLeadMinutes: 10,
            notifications: container.notifications,
            calendarWriter: container.calendar,
            initialSaveError: error,
            onPlan: { _ in },
            onNotice: { _ in }
        )
    }

    private func library(query: String = "") -> some View {
        let viewModel = LibraryViewModel(repository: container.library)
        viewModel.query = query
        return LibraryView(
            viewModel: viewModel,
            activityRepository: container.activity,
            personalization: container.personalization,
            sessionProgress: container.sessionProgress,
            readingActivity: container.readingActivity,
            catalog: container.catalog,
            catalogCache: container.catalogCache
        )
    }

    private func addBook(_ initial: CatalogSearchInitialState, focus: Bool = false) -> some View {
        AddBookView(
            library: LibraryViewModel(repository: container.library),
            catalog: container.catalog,
            cache: container.catalogCache,
            initialSearch: initial,
            focusSearchOnAppear: focus
        )
    }

    private func bookDetail(_ book: Book) -> some View {
        NavigationStack {
            BookDetailView(
                book: book,
                repository: LibraryViewModel(repository: container.library),
                activityRepository: container.activity,
                personalization: container.personalization,
                sessionProgress: container.sessionProgress,
                readingActivity: container.readingActivity
            )
        }
    }

    private func readingSession(paused: Bool = false, confirmingClose: Bool = false) -> some View {
        let progress = InMemorySessionProgressRepository()
        if paused {
            progress.save(
                ActiveReadingSession(
                    bookID: SampleData.books[0].id,
                    durationSeconds: 1_800,
                    accumulatedSeconds: 612,
                    startedAt: nil,
                    isPaused: true
                )
            )
        }
        return ReadingSessionView(
            book: SampleData.books[0],
            durationMinutes: 30,
            repository: container.activity,
            personalization: container.personalization,
            progressStore: progress,
            activityManager: container.readingActivity,
            weather: "Light rain, 24°",
            place: "Indoors",
            confirmingClose: confirmingClose,
            onPagesRead: { _ in }
        )
    }

    private func sessionComplete() -> some View {
        NavigationStack {
            SessionCompleteView(
                book: SampleData.books[0],
                minutes: 30,
                weather: "Light rain, 24°",
                place: "Indoors",
                repository: container.activity,
                personalization: container.personalization,
                onPagesRead: { _ in },
                finish: {}
            )
        }
    }

    private func sessionDetail(editing: Bool = false, confirmingDelete: Bool = false) -> some View {
        let viewModel = ActivityViewModel(repository: container.activity, library: container.library)
        let record = container.activity.records().first ?? Self.sampleRecord
        return NavigationStack {
            SessionDetailView(
                record: record,
                book: SampleData.books[0],
                viewModel: viewModel,
                editing: editing,
                confirmingDelete: confirmingDelete
            )
        }
    }

    private var sampleEvents: [PersonalizationEvent] {
        [
            PersonalizationEvent(id: UUID(), kind: .completed, date: .now, hour: 19, temperature: 24, place: "Indoors", reason: "Focused"),
            PersonalizationEvent(id: UUID(), kind: .rejected, date: .now.addingTimeInterval(-86_400), hour: 7, temperature: 30, place: "Outdoors", reason: "Weather")
        ]
    }

    private static let sampleRecord = ReadingRecord(
        id: UUID(), bookID: SampleData.books[0].id, date: .now,
        minutes: 32, pages: 18, weather: "Light rain, 24°",
        place: "Indoors", feedback: "Focused", note: "Finished chapter six."
    )

    private static func makeContainer(for scenario: String) -> AppContainer {
        let books: [Book] = ["forecast_no_book", "library_empty", "activity_empty"].contains(scenario) ? [] : SampleData.books
        let records: [ReadingRecord] = scenario == "activity_empty" ? [] : [sampleRecord]
        let suiteName = "PagesAheadScreenshots-\(scenario)-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppContainer(
            persistentContainer: nil,
            catalogPersistentContainer: nil,
            library: InMemoryLibraryRepository(books: books),
            forecast: MockForecastRepository(),
            activity: InMemoryActivityRepository(records: records),
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
}

private struct SettingsDetailScreenshot: View {
    let scenario: String
    let personalization: PersonalizationRepository
    @State private var preferences = ReadingPreferences()
    @State private var city = "Makassar"

    @ViewBuilder
    var body: some View {
        NavigationStack {
            switch scenario {
            case "reading_preferences": ReadingPreferencesView(preferences: $preferences)
            case "availability": AvailabilityView(preferences: $preferences)
            case "notifications_focus": NotificationsFocusView(preferences: $preferences)
            case "location_settings": LocationSettingsView(city: $city, preferences: $preferences)
            case "privacy_clear_alert": PrivacyView(preferences: $preferences, personalization: personalization, confirmingClear: true)
            default: PrivacyView(preferences: $preferences, personalization: personalization)
            }
        }
    }
}

private struct LiveActivityReferenceView: View {
    enum Mode { case lockScreen, expanded, compact, minimal }
    let mode: Mode
    let paused: Bool

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            switch mode {
            case .lockScreen: lockScreen
            case .expanded: expanded
            case .compact: compact
            case .minimal: minimal
            }
        }
    }

    private var lockScreen: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.pages.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(.white)
                .frame(width: 48, height: 64)
                .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text("READING NOW").font(.caption2.bold()).foregroundStyle(AppTheme.ink)
                Text(SampleData.books[0].title).font(.headline).lineLimit(1)
                Text(SampleData.books[0].author).font(.caption).foregroundStyle(.secondary)
                if paused {
                    Label("19:48", systemImage: "pause.fill")
                        .font(.subheadline.monospacedDigit())
                } else {
                    ProgressView(value: 0.34).tint(AppTheme.ink)
                    Text("19:48 remaining").font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding()
        .background { AppBackground() }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(20)
    }

    private var expanded: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "book.fill").font(.system(size: 20))
                Spacer()
                VStack { Text(SampleData.books[0].title).font(.headline); Text(SampleData.books[0].author).font(.caption) }
                Spacer()
                Text("19:48").monospacedDigit()
            }
            ProgressView(value: 0.34).tint(.white)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black, in: Capsule())
        .padding(16)
    }

    private var compact: some View {
        HStack(spacing: 18) {
            Image(systemName: "book.fill").font(.system(size: 20))
            Text("19:48").monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.black, in: Capsule())
    }

    private var minimal: some View {
        Text("20m").font(.caption2.monospacedDigit()).foregroundStyle(.white)
            .frame(width: 42, height: 42).background(.black, in: Circle())
    }
}
#endif
