#if DEBUG
import Foundation
import SwiftUI

extension ScreenshotScenarioView {

    func onboardingViewModel(
        page: OnboardingPage,
        recommendations: Bool = false,
        planned: Bool = false,
        error: String? = nil,
        denied: Bool = false,
        resolving: Bool = false
    ) -> AppFlowViewModel {
        let viewModel = AppFlowViewModel(container: container)
        viewModel.draft.currentPage = page
        viewModel.draft.selectedBooks = [SampleData.books[0]]
        viewModel.draft.resolvedCity = "Makassar"
        if recommendations {
            let windows = SampleData.windows(bookID: SampleData.books[0].id)
            viewModel.draft.recommendationCandidates = windows
            viewModel.draft.selectedCandidateID = windows.first?.id
            if planned, let window = windows.first {
                viewModel.draft.readingPlan = ReadingPlan(
                    id: UUID(), start: window.start,
                    durationMinutes: window.durationMinutes,
                    place: window.place, bookID: window.bookID,
                    reminderEnabled: false, calendarEnabled: false
                )
            }
        }
        viewModel.locationError = error
        viewModel.isLocationPermissionDenied = denied
        viewModel.isResolvingLocation = resolving
        viewModel.route = .onboarding(page)
        return viewModel
    }

    enum ReadingPlanState { case loading, error, noBook, loaded, cached, planned }

    func readingPlan(_ state: ReadingPlanState) -> some View {
        let viewModel = ReadingPlanViewModel(
            library: container.library,
            repository: container.readingWindows,
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
            let session = ReadingPlan(
                id: UUID(),
                start: window.start,
                durationMinutes: window.durationMinutes,
                place: window.place,
                bookID: window.bookID,
                reminderEnabled: true,
                calendarEnabled: false
            )
            container.readingPlans.save(session)
        }
        return ReadingPlanView(
            viewModel: viewModel,
            planManager: makePlanManager(),
            sessionCoordinator: makeCoordinator(),
            settings: container.settings,
            loadsOnAppear: false
        )
    }

    func readingWindowDetail() -> some View {
        NavigationStack {
            ReadingWindowDetailView(
                window: SampleData.windows(bookID: SampleData.books[0].id)[0],
                book: SampleData.books[0],
                allBooks: SampleData.books,
                onPlan: {},
                reject: { _ in },
                chooseBook: { _ in }
            )
        }
    }

    func readingPlanDetail() -> some View {
        let window = SampleData.windows(bookID: SampleData.books[0].id)[0]
        let plan = ReadingPlan(
            id: UUID(),
            start: window.start,
            durationMinutes: window.durationMinutes,
            place: window.place,
            bookID: window.bookID,
            reminderEnabled: true,
            calendarEnabled: false
        )
        container.readingPlans.save(plan)
        return NavigationStack {
            ReadingPlanDetailView(
                plan: plan,
                books: SampleData.books,
                planManager: makePlanManager(),
                sessionCoordinator: makeCoordinator(),
                initiallySelected: SampleData.books[0]
            )
        }
    }

    func library(query: String = "") -> some View {
        let viewModel = LibraryViewModel(repository: container.library)
        viewModel.query = query
        return LibraryView(
            viewModel: viewModel,
            sessionCoordinator: makeCoordinator(),
            catalog: container.catalog,
            catalogCache: container.catalogCache
        )
    }

    func bookDetail(_ book: Book) -> some View {
        NavigationStack {
            BookDetailView(
                book: book,
                repository: LibraryViewModel(repository: container.library),
                sessionCoordinator: makeCoordinator()
            )
        }
    }

    func readingSession(paused: Bool = false) -> some View {
        let progress = InMemorySessionProgressRepository()
        progress.save(
            ActiveReadingSession(
                bookID: SampleData.books[0].id,
                accumulatedSeconds: paused ? 612 : 0,
                startedAt: paused ? nil : .now.addingTimeInterval(-612),
                isPaused: paused,
                startingPage: SampleData.books[0].currentPage,
                origin: .bookDetail,
                phase: paused ? .paused : .running
            )
        )
        return ReadingSessionView(coordinator: makeCoordinator(progress: progress))
    }

    func sessionComplete() -> some View {
        let progress = InMemorySessionProgressRepository()
        progress.save(
            ActiveReadingSession(
                bookID: SampleData.books[0].id,
                accumulatedSeconds: 1_934,
                startedAt: nil,
                isPaused: true,
                startingPage: SampleData.books[0].currentPage,
                origin: .bookDetail,
                weather: "Light rain, 24°",
                phase: .summary
            )
        )
        return ReadingSessionView(coordinator: makeCoordinator(progress: progress))
    }

    func makePlanManager() -> ReadingPlanManager {
        ReadingPlanManager(
            repository: container.readingPlans,
            notifications: container.notifications,
            calendarWriter: container.calendar,
            settings: container.settings
        )
    }

    func makeCoordinator(
        progress: SessionProgressRepository? = nil
    ) -> ReadingSessionCoordinator {
        ReadingSessionCoordinator(
            library: container.library,
            activity: container.activity,
            readingPlans: container.readingPlans,
            progressStore: progress ?? container.sessionProgress,
            activityManager: container.readingActivity,
            notifications: container.notifications,
            calendarWriter: container.calendar
        )
    }

    func sessionDetail(editing: Bool = false, confirmingDelete: Bool = false) -> some View {
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

    var sampleEvents: [PersonalizationEvent] {
        [
            PersonalizationEvent(id: UUID(), kind: .completed, date: .now, hour: 19, temperature: 24, place: "Indoors", reason: "Focused"),
            PersonalizationEvent(id: UUID(), kind: .rejected, date: .now.addingTimeInterval(-86_400), hour: 7, temperature: 30, place: "Outdoors", reason: "Weather")
        ]
    }

    static let sampleRecord = ReadingRecord(
        id: UUID(), bookID: SampleData.books[0].id, date: .now,
        minutes: 32, pages: 18, weather: "Light rain, 24°"
    )

    static func makeContainer(for scenario: ScreenshotScenario) -> AppContainer {
        let books: [Book]
        if [.readingPlanNoBook, .libraryEmpty, .activityEmpty].contains(scenario) {
            books = []
        } else if scenario == .libraryNoCurrentReading {
            books = SampleData.books.map { book in
                var book = book
                book.status = .saved
                return book
            }
        } else {
            books = SampleData.books
        }
        let records: [ReadingRecord] = scenario == .activityEmpty ? [] : [sampleRecord]
        let suiteName = "PagesAheadScreenshots-\(scenario.rawValue)-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AppContainer(
            persistentContainer: nil,
            catalogPersistentContainer: nil,
            library: InMemoryLibraryRepository(books: books),
            readingWindows: MockReadingWindowRepository(),
            activity: InMemoryActivityRepository(records: records),
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
}

#endif
