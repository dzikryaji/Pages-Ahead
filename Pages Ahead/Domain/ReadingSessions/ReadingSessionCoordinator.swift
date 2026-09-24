import Foundation
import Observation

@MainActor @Observable
final class ReadingSessionCoordinator {
    private let library: LibraryRepository
    private let activity: ActivityRepository
    private let readingPlans: ReadingPlanRepository
    private let progressStore: SessionProgressRepository
    private let activityManager: ReadingActivityManaging
    private let notifications: NotificationScheduling
    private let calendarWriter: CalendarEventWriting
    private let dateProvider: DateProviding
    private let reconciler: ReadingProgressReconciler
    private(set) var session: ActiveReadingSession?
    private(set) var now: Date
    var errorMessage: String?

    init(
        library: LibraryRepository,
        activity: ActivityRepository,
        readingPlans: ReadingPlanRepository,
        progressStore: SessionProgressRepository,
        activityManager: ReadingActivityManaging,
        notifications: NotificationScheduling,
        calendarWriter: CalendarEventWriting,
        dateProvider: DateProviding? = nil
    ) {
        self.library = library
        self.activity = activity
        self.readingPlans = readingPlans
        self.progressStore = progressStore
        self.activityManager = activityManager
        self.notifications = notifications
        self.calendarWriter = calendarWriter
        self.dateProvider = dateProvider ?? SystemDateProvider()
        reconciler = ReadingProgressReconciler(activity: activity, library: library)
        session = progressStore.loadCurrent()
        now = self.dateProvider.now
    }

    var book: Book? {
        guard let bookID = session?.bookID else { return nil }
        return library.books().first { $0.id == bookID }
    }

    var elapsedSeconds: Int { session?.elapsedSeconds(at: now) ?? 0 }
    var timeText: String { DurationFormatting.stopwatch(elapsedSeconds) }
    var isPresented: Bool { session != nil }
    var isPaused: Bool { session?.phase == .paused }
    var isShowingSummary: Bool { session?.phase == .summary }

    func restoredPageWhenLeavingFinished(bookID: UUID, pageCount: Int) -> Int {
        guard pageCount > 0,
              let lastPage = activity.records()
                .filter({ $0.bookID == bookID })
                .max(by: { $0.date < $1.date })?
                .lastPage else {
            return 0
        }
        let clampedPage = min(max(0, lastPage), pageCount)
        return clampedPage == pageCount ? 0 : clampedPage
    }

    func pageAfterStatusChange(for book: Book, to status: ReadingStatus) -> Int {
        if status == .finished { return book.pageCount }
        if book.status == .finished {
            return restoredPageWhenLeavingFinished(
                bookID: book.id,
                pageCount: book.pageCount
            )
        }
        return book.currentPage
    }

    @discardableResult
    func start(
        book: Book,
        origin: ReadingSessionOrigin,
        plan: ReadingPlan? = nil,
        startedInsideWindow: Bool = false,
        weather: String = "Not recorded",
        reread: Bool = false
    ) -> Bool {
        guard session == nil else { return false }
        let date = dateProvider.now
        let startingPage = reread && book.status == .finished ? 0 : book.currentPage
        let newSession = ActiveReadingSession(
            bookID: book.id,
            accumulatedSeconds: 0,
            startedAt: date,
            isPaused: false,
            startingPage: startingPage,
            origin: origin,
            readingPlanID: plan?.id,
            startedInsideReadingWindow: startedInsideWindow,
            weather: weather,
            isReread: reread,
            phase: .running
        )
        session = newSession
        now = date
        progressStore.save(newSession)
        Task { await activityManager.start(book: book, session: newSession) }
        return true
    }

    func tick() {
        guard session != nil else { return }
        now = dateProvider.now
        if elapsedSeconds.isMultiple(of: 15) { persistSnapshot() }
    }

    func togglePause() async {
        guard var session else { return }
        now = dateProvider.now
        if session.phase == .paused {
            session.phase = .running
            session.isPaused = false
            session.startedAt = now
        } else if session.phase == .running {
            session.accumulatedSeconds = session.elapsedSeconds(at: now)
            session.startedAt = nil
            session.isPaused = true
            session.phase = .paused
        }
        self.session = session
        progressStore.save(session)
        await activityManager.update(bookID: session.bookID, session: session)
    }

    func stopForSummary() async {
        guard var session, session.phase == .paused else { return }
        session.phase = .summary
        session.isPaused = true
        session.startedAt = nil
        self.session = session
        progressStore.save(session)
        await activityManager.end(bookID: session.bookID, session: session)
    }

    func persistSnapshot() {
        guard var session else { return }
        now = dateProvider.now
        if session.phase == .running {
            session.accumulatedSeconds = session.elapsedSeconds(at: now)
            session.startedAt = now
        }
        self.session = session
        progressStore.save(session)
    }

    func endWithoutSaving() async {
        guard let session else { return }
        await activityManager.end(bookID: session.bookID, session: session)
        progressStore.clear()
        self.session = nil
    }

    @discardableResult
    func save(lastPage: Int) async -> ReadingRecord? {
        guard let session else { return nil }
        do {
            let record = try reconciler.complete(
                session: session,
                lastPage: lastPage,
                at: dateProvider.now
            )
            if session.startedInsideReadingWindow,
               let planID = session.readingPlanID,
               let plan = readingPlans.current(), plan.id == planID {
                notifications.cancel(sessionID: planID)
                if let eventID = plan.calendarEventID { try? calendarWriter.delete(eventID: eventID) }
                readingPlans.delete(id: planID)
            }
            progressStore.clear()
            self.session = nil
            return record
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
