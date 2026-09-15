import ActivityKit
import Foundation

@MainActor
final class LiveReadingActivityManager: ReadingActivityManaging {
    func start(book: Book, session: ActiveReadingSession) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = activityContent(for: session)

        if let existing = activity(for: book.id) {
            await existing.update(content)
            return
        }

        let attributes = ReadingSessionActivityAttributes(
            bookID: book.id,
            bookTitle: book.title,
            bookAuthor: book.author,
            durationSeconds: session.durationSeconds
        )
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func update(bookID: UUID, session: ActiveReadingSession) async {
        guard let activity = activity(for: bookID) else { return }
        await activity.update(activityContent(for: session))
    }

    func end(bookID: UUID, session: ActiveReadingSession) async {
        guard let activity = activity(for: bookID) else { return }
        await activity.end(activityContent(for: session), dismissalPolicy: .immediate)
    }

    private func activity(for bookID: UUID) -> Activity<ReadingSessionActivityAttributes>? {
        Activity<ReadingSessionActivityAttributes>.activities.first { $0.attributes.bookID == bookID }
    }

    private func activityContent(for session: ActiveReadingSession) -> ActivityContent<ReadingSessionActivityAttributes.ContentState> {
        let now = Date.now
        let runningSeconds = session.startedAt.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
        let elapsed = min(session.accumulatedSeconds + runningSeconds, session.durationSeconds)
        let remaining = max(session.durationSeconds - elapsed, 0)
        let state = ReadingSessionActivityAttributes.ContentState(
            startedAt: now.addingTimeInterval(TimeInterval(-elapsed)),
            endsAt: now.addingTimeInterval(TimeInterval(remaining)),
            remainingSeconds: remaining,
            isPaused: session.isPaused
        )
        return ActivityContent(state: state, staleDate: state.endsAt)
    }
}

@MainActor
final class PreviewReadingActivityManager: ReadingActivityManaging {
    func start(book: Book, session: ActiveReadingSession) async { }
    func update(bookID: UUID, session: ActiveReadingSession) async { }
    func end(bookID: UUID, session: ActiveReadingSession) async { }
}
