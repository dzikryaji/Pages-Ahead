import Foundation
import Testing
@testable import Pages_Ahead

@MainActor
struct MainTabsRedesignTests {
    @Test func readingPlanWindowKeepsEndSeparateFromReadingDuration() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(7_200)
        let plan = ReadingPlan(
            id: UUID(), start: start, end: end, place: "Indoors",
            bookID: nil, reminderEnabled: true, calendarEnabled: false
        )

        #expect(plan.end == end)
        #expect(plan.durationMinutes == 120)
    }

    @Test func activeSessionCountsUpWithoutAnUpperLimit() {
        let started = Date(timeIntervalSince1970: 10_000)
        let session = ActiveReadingSession(
            bookID: UUID(), accumulatedSeconds: 45, startedAt: started,
            isPaused: false, startingPage: 50, origin: .bookDetail
        )

        #expect(session.elapsedSeconds(at: started.addingTimeInterval(3_700)) == 3_745)
    }

    @Test func pausedSessionDoesNotAddWallClockTime() {
        let session = ActiveReadingSession(
            bookID: UUID(), accumulatedSeconds: 125, startedAt: nil,
            isPaused: true, startingPage: 10, origin: .bookDetail
        )

        #expect(session.elapsedSeconds(at: .distantFuture) == 125)
    }

    @Test func readingRecordDerivesPagesAndExactDuration() {
        let record = ReadingRecord(
            id: UUID(), bookID: UUID(), date: .now, durationSeconds: 1_934,
            startingPage: 50, lastPage: 72, weather: "Cloudy, 25°"
        )

        #expect(record.pages == 22)
        #expect(record.minutes == 32)
        #expect(record.durationText == "32:14")
    }

    @Test func durationFormattingAddsHoursOnlyWhenNeeded() {
        #expect(DurationFormatting.stopwatch(59) == "00:59")
        #expect(DurationFormatting.stopwatch(3_614) == "1:00:14")
    }

    @Test func completionAndHistoryReconciliationFollowLastPage() throws {
        let bookID = UUID()
        let library = InMemoryLibraryRepository(books: [
            Book(id: bookID, title: "Test", author: "Reader", edition: "", isbn: "", pageCount: 100, status: .reading, currentPage: 50)
        ])
        let activity = InMemoryActivityRepository(records: [])
        let reconciler = ReadingProgressReconciler(activity: activity, library: library)
        let session = ActiveReadingSession(
            bookID: bookID, accumulatedSeconds: 1_934, startedAt: nil,
            isPaused: true, startingPage: 50, origin: .bookDetail
        )

        let record = try reconciler.complete(session: session, lastPage: 72, at: .now)
        #expect(record.pages == 22)
        #expect(library.books().first?.currentPage == 72)

        try reconciler.update(record: record.with(lastPage: 100, durationSeconds: 2_100))
        #expect(library.books().first?.status == .finished)

        reconciler.delete(recordID: record.id)
        #expect(library.books().first?.currentPage == 0)
        #expect(library.books().first?.status == .saved)
    }

    @Test func olderRecordEditDoesNotRewindCurrentProgress() throws {
        let bookID = UUID()
        let library = InMemoryLibraryRepository(books: [
            Book(id: bookID, title: "Test", author: "Reader", edition: "", isbn: "", pageCount: 200, status: .reading, currentPage: 80)
        ])
        let older = ReadingRecord(id: UUID(), bookID: bookID, date: Date(timeIntervalSince1970: 1), durationSeconds: 600, startingPage: 0, lastPage: 30, weather: "Clear")
        let newest = ReadingRecord(id: UUID(), bookID: bookID, date: Date(timeIntervalSince1970: 2), durationSeconds: 900, startingPage: 30, lastPage: 80, weather: "Clear")
        let activity = InMemoryActivityRepository(records: [older, newest])
        let reconciler = ReadingProgressReconciler(activity: activity, library: library)

        try reconciler.update(record: older.with(lastPage: 20, durationSeconds: 600))

        #expect(library.books().first?.currentPage == 80)
    }

    @Test func bookHasPartialProgressOnlyBetweenStartAndFinish() {
        var book = Book(
            id: UUID(), title: "Test", author: "Reader", edition: "", isbn: "",
            pageCount: 100, status: .saved, currentPage: 0
        )

        #expect(!book.hasPartialProgress)
        book.currentPage = 40
        #expect(book.hasPartialProgress)
        book.currentPage = 100
        #expect(!book.hasPartialProgress)
    }

    @Test func coordinatorRestoresLatestPartialPageWhenLeavingFinished() {
        let bookID = UUID()
        let activity = InMemoryActivityRepository(records: [
            ReadingRecord(
                id: UUID(), bookID: bookID, date: Date(timeIntervalSince1970: 2),
                durationSeconds: 600, startingPage: 20, lastPage: 70, weather: "Clear"
            ),
            ReadingRecord(
                id: UUID(), bookID: bookID, date: Date(timeIntervalSince1970: 1),
                durationSeconds: 600, startingPage: 0, lastPage: 100, weather: "Clear"
            )
        ])
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: []), activity: activity,
            readingPlans: InMemoryReadingPlanRepository(),
            progressStore: InMemorySessionProgressRepository(),
            activityManager: PreviewReadingActivityManager(),
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter()
        )

        #expect(coordinator.restoredPageWhenLeavingFinished(bookID: bookID, pageCount: 100) == 70)

        let finishedBook = Book(
            id: bookID, title: "Test", author: "Reader", edition: "", isbn: "",
            pageCount: 100, status: .finished, currentPage: 100
        )
        #expect(coordinator.pageAfterStatusChange(for: finishedBook, to: .saved) == 70)
    }

    @Test func coordinatorResetsPageWhenLatestSessionReachedEndOrDoesNotExist() {
        let bookID = UUID()
        let activity = InMemoryActivityRepository(records: [
            ReadingRecord(
                id: UUID(), bookID: bookID, date: .now, durationSeconds: 600,
                startingPage: 70, lastPage: 100, weather: "Clear"
            )
        ])
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: []), activity: activity,
            readingPlans: InMemoryReadingPlanRepository(),
            progressStore: InMemorySessionProgressRepository(),
            activityManager: PreviewReadingActivityManager(),
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter()
        )

        #expect(coordinator.restoredPageWhenLeavingFinished(bookID: bookID, pageCount: 100) == 0)
        #expect(coordinator.restoredPageWhenLeavingFinished(bookID: UUID(), pageCount: 100) == 0)
    }

    @Test func coordinatorPreservesPageUnlessEnteringOrLeavingFinished() {
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: []),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: InMemoryReadingPlanRepository(),
            progressStore: InMemorySessionProgressRepository(),
            activityManager: PreviewReadingActivityManager(),
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter()
        )
        let book = Book(
            id: UUID(), title: "Test", author: "Reader", edition: "", isbn: "",
            pageCount: 100, status: .reading, currentPage: 40
        )

        #expect(coordinator.pageAfterStatusChange(for: book, to: .saved) == 40)
        #expect(coordinator.pageAfterStatusChange(for: book, to: .finished) == 100)
    }

    @Test func coordinatorRestoresRunningSessionAndRejectsSecondStart() {
        let book = SampleData.books[0]
        let started = Date(timeIntervalSince1970: 10_000)
        let clock = FixedDateProvider(now: started.addingTimeInterval(245))
        let progress = InMemorySessionProgressRepository()
        progress.save(ActiveReadingSession(
            bookID: book.id,
            accumulatedSeconds: 15,
            startedAt: started,
            isPaused: false,
            startingPage: book.currentPage,
            origin: .bookDetail
        ))
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: [book]),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: InMemoryReadingPlanRepository(),
            progressStore: progress,
            activityManager: PreviewReadingActivityManager(),
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter(),
            dateProvider: clock
        )

        #expect(coordinator.elapsedSeconds == 260)
        #expect(!coordinator.start(book: book, origin: .readingPlan))
    }

    @Test func readingPlanExpiresOnFollowingLocalDay() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = InMemoryReadingPlanRepository()
        repository.save(ReadingPlan(
            id: UUID(), start: start, end: start.addingTimeInterval(1_800),
            place: "Indoors", bookID: nil, reminderEnabled: true,
            calendarEnabled: false
        ))
        let manager = ReadingPlanManager(
            repository: repository,
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter(),
            settings: UserDefaultsSettingsRepository(
                defaults: UserDefaults(suiteName: UUID().uuidString)!
            ),
            dateProvider: FixedDateProvider(now: start.addingTimeInterval(86_400)),
            calendar: calendar
        )

        #expect(manager.current == nil)
        #expect(repository.current() == nil)
    }

    @Test func savingInsidePlannedWindowConsumesPlan() async {
        let book = SampleData.books[0]
        let now = Date(timeIntervalSince1970: 20_000)
        let plan = ReadingPlan(
            id: UUID(), start: now.addingTimeInterval(-60),
            end: now.addingTimeInterval(600), place: "Indoors", bookID: nil,
            reminderEnabled: true, calendarEnabled: false
        )
        let plans = InMemoryReadingPlanRepository()
        plans.save(plan)
        let coordinator = ReadingSessionCoordinator(
            library: InMemoryLibraryRepository(books: [book]),
            activity: InMemoryActivityRepository(records: []),
            readingPlans: plans,
            progressStore: InMemorySessionProgressRepository(),
            activityManager: PreviewReadingActivityManager(),
            notifications: PreviewNotificationScheduler(),
            calendarWriter: PreviewCalendarWriter(),
            dateProvider: FixedDateProvider(now: now)
        )

        #expect(coordinator.start(
            book: book,
            origin: .readingPlan,
            plan: plan,
            startedInsideWindow: true
        ))
        await coordinator.togglePause()
        await coordinator.stopForSummary()
        let saved = await coordinator.save(lastPage: book.currentPage)

        #expect(saved != nil)
        #expect(plans.current() == nil)
    }
}
