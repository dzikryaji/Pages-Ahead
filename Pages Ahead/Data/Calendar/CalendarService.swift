import EventKit
import Foundation

@MainActor
final class EventKitCalendarService: CalendarEventWriting, CalendarAvailabilityProviding {
    private let store = EKEventStore()
    func save(session: ReadingPlan, bookTitle: String, existingEventID: String?) async throws -> String {
        guard try await store.requestWriteOnlyAccessToEvents() else { throw LocationError.denied }
        let event = existingEventID.flatMap(store.event(withIdentifier:)) ?? EKEvent(eventStore: store)
        event.title = "Read \(bookTitle)"
        event.startDate = session.start
        event.endDate = session.end
        event.location = session.place
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
    }

    func delete(eventID: String) throws {
        guard let event = store.event(withIdentifier: eventID) else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval] {
        guard try await store.requestFullAccessToEvents() else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return store.events(matching: predicate).map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }
}
