import CoreLocation
import EventKit
import Foundation
import MapKit
import UserNotifications

struct LocationCoordinate: Sendable {
    let latitude: Double
    let longitude: Double
    var coreLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

enum LocationError: LocalizedError {
    case denied
    case unavailable
    var errorDescription: String? {
        switch self { case .denied: "Location access is unavailable. Enter a city instead."; case .unavailable: "Current location could not be determined." }
    }
}

@MainActor
final class CoreLocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() async throws {
        switch manager.authorizationStatus {
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        case .denied, .restricted: throw LocationError.denied
        case .authorizedAlways, .authorizedWhenInUse: return
        @unknown default: throw LocationError.unavailable
        }
    }

    func requestCurrentLocation() async throws -> (location: LocationCoordinate, city: String) {
        try await requestPermission()
        let location = try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
        let mapItems = try? await MKReverseGeocodingRequest(location: location)?.mapItems
        let city = mapItems?.first?.addressRepresentations?.cityName ?? "Current Location"
        return (LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude), city)
    }

    func coordinate(for city: String) async throws -> LocationCoordinate {
        guard let request = MKGeocodingRequest(addressString: city),
              let location = try await request.mapItems.first?.location else { throw LocationError.unavailable }
        return LocationCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location); locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error); locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            authorizationContinuation?.resume(throwing: LocationError.denied)
            authorizationContinuation = nil
            locationContinuation?.resume(throwing: LocationError.denied)
            locationContinuation = nil
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationContinuation?.resume()
            authorizationContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            authorizationContinuation?.resume(throwing: LocationError.unavailable)
            authorizationContinuation = nil
        }
    }
}

protocol WeatherForecastCaching {
    func forecast(for city: String, now: Date) -> WeatherForecastBatch?
    func save(_ forecast: WeatherForecastBatch, for city: String, at date: Date)
}

final class UserDefaultsWeatherForecastCache: WeatherForecastCaching {
    private struct Entry: Codable {
        let savedAt: Date
        let cityKey: String
        let forecast: WeatherForecastBatch
    }

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "weatherForecastCacheV2") {
        self.defaults = defaults
        self.key = key
    }

    func forecast(for city: String, now: Date = .now) -> WeatherForecastBatch? {
        guard let data = defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.cityKey == city.normalizedCacheKey,
              now.timeIntervalSince(entry.savedAt) >= 0,
              now.timeIntervalSince(entry.savedAt) < 86_400 else { return nil }
        return entry.forecast
    }

    func save(_ forecast: WeatherForecastBatch, for city: String, at date: Date = .now) {
        let entry = Entry(savedAt: date, cityKey: city.normalizedCacheKey, forecast: forecast)
        defaults.set(try? JSONEncoder().encode(entry), forKey: key)
    }
}

struct WeatherKitForecastRepository: ForecastRepository {
    let settings: SettingsRepository
    let location: LocationProviding
    let calendar: CalendarAvailabilityProviding
    let personalization: PersonalizationRepository
    let weather: WeatherProviding
    var cache: WeatherForecastCaching = UserDefaultsWeatherForecastCache()

    func readingWindows(for bookID: UUID) async throws -> [ReadingWindow] {
        let city = settings.city
        let batch: WeatherForecastBatch
        let isCached: Bool
        if let cached = cache.forecast(for: city, now: .now) {
            batch = cached
            isCached = true
        } else {
            do {
                let coordinate = try await location.coordinate(for: city)
                batch = try await weather.hourlyForecast(at: coordinate)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                batch = try await MockWeatherProvider().hourlyForecast(at: LocationCoordinate(latitude: 0, longitude: 0))
            }
            cache.save(batch, for: city, at: .now)
            isCached = false
        }

        let preferences = settings.preferences
        let events = preferences.personalizationEnabled ? personalization.events() : []
        var ranked = RecommendationEngine().rank(batch.candidates, preferences: preferences, events: events)
        if preferences.calendarAvailabilityEnabled,
           let first = ranked.first?.date,
           let last = ranked.last?.date {
            let busy = try await calendar.busyIntervals(in: DateInterval(start: first, end: last.addingTimeInterval(3600)))
            ranked.removeAll { candidate in
                let reading = DateInterval(start: candidate.date, duration: TimeInterval(preferences.duration * 60))
                return busy.contains { $0.intersects(reading) }
            }
        }
        return ranked.prefix(5).map { hour in
            ReadingWindow(id: UUID(), start: hour.date, durationMinutes: preferences.duration, temperature: hour.temperature,
                          condition: hour.condition, weatherSymbol: hour.symbolName,
                          place: preferences.place == "Outdoors" ? "Outdoors" : "Indoors",
                          fitReason: "This time matches your \(preferences.preferredTime.lowercased()) preference and \(preferences.duration)-minute session length.",
                          bookID: bookID, isCached: isCached, weatherSource: batch.source)
        }
    }
}

struct LocalNotificationScheduler: NotificationScheduling {
    func schedule(session: PlannedSession, bookTitle: String, leadMinutes: Int) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound]) else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Time to read"
        content.body = "Your planned session with \(bookTitle) starts soon."
        content.sound = .default
        content.userInfo = ["sessionID": session.id.uuidString]
        let reminderDate = session.start.addingTimeInterval(TimeInterval(-leadMinutes * 60))
        guard reminderDate > .now else { return false }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let request = UNNotificationRequest(identifier: session.id.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        center.removePendingNotificationRequests(withIdentifiers: [session.id.uuidString])
        try await center.add(request)
        return true
    }
    func cancel(sessionID: UUID) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionID.uuidString]) }
}

@MainActor
final class EventKitCalendarService: CalendarEventWriting, CalendarAvailabilityProviding {
    private let store = EKEventStore()
    func save(session: PlannedSession, bookTitle: String, existingEventID: String?) async throws -> String {
        guard try await store.requestWriteOnlyAccessToEvents() else { throw LocationError.denied }
        let event = existingEventID.flatMap(store.event(withIdentifier:)) ?? EKEvent(eventStore: store)
        event.title = "Read \(bookTitle)"
        event.startDate = session.start
        event.endDate = session.start.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
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

final class PreviewLocationService: LocationProviding {
    func requestPermission() async throws { }
    func requestCurrentLocation() async throws -> (location: LocationCoordinate, city: String) { (LocationCoordinate(latitude: -5.1477, longitude: 119.4327), "Makassar") }
    func coordinate(for city: String) async throws -> LocationCoordinate { LocationCoordinate(latitude: -5.1477, longitude: 119.4327) }
}
struct PreviewNotificationScheduler: NotificationScheduling { func schedule(session: PlannedSession, bookTitle: String, leadMinutes: Int) async throws -> Bool { true }; func cancel(sessionID: UUID) { } }
struct PreviewCalendarWriter: CalendarEventWriting, CalendarAvailabilityProviding {
    func save(session: PlannedSession, bookTitle: String, existingEventID: String?) async throws -> String { existingEventID ?? "preview-event" }
    func delete(eventID: String) throws { }
    func busyIntervals(in interval: DateInterval) async throws -> [DateInterval] { [] }
}
