import Foundation

final class PreviewLocationService: LocationProviding {
    func requestCurrentLocation() async throws -> (location: LocationCoordinate, city: String) { (LocationCoordinate(latitude: -5.1477, longitude: 119.4327), "Makassar") }
    func coordinate(for city: String) async throws -> LocationCoordinate { LocationCoordinate(latitude: -5.1477, longitude: 119.4327) }
}
struct PreviewNotificationScheduler: NotificationScheduling { func schedule(session: ReadingPlan) async throws -> Bool { true }; func cancel(sessionID: UUID) { } }
struct PreviewCalendarWriter: CalendarEventWriting, CalendarAvailabilityProviding {
    func save(session: ReadingPlan, bookTitle: String, existingEventID: String?) async throws -> String { existingEventID ?? "preview-event" }
    func delete(eventID: String) throws { }
    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval] { [] }
}
