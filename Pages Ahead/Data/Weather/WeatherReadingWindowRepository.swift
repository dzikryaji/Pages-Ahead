import Foundation

struct CachedWeatherForecast: Sendable {
    let savedAt: Date
    let forecast: WeatherForecastBatch
}

protocol WeatherForecastCaching {
    func entry(for city: String) -> CachedWeatherForecast?
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

    func entry(for city: String) -> CachedWeatherForecast? {
        guard let data = defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.cityKey == city.normalizedCacheKey else { return nil }
        return CachedWeatherForecast(savedAt: entry.savedAt, forecast: entry.forecast)
    }

    func save(_ forecast: WeatherForecastBatch, for city: String, at date: Date = .now) {
        let entry = Entry(savedAt: date, cityKey: city.normalizedCacheKey, forecast: forecast)
        defaults.set(try? JSONEncoder().encode(entry), forKey: key)
    }
}

struct WeatherReadingWindowRepository: ReadingWindowRepository {
    let settings: SettingsRepository
    let location: LocationProviding
    let calendar: CalendarAvailabilityProviding
    let personalization: PersonalizationRepository
    let weather: WeatherProviding
    var cache: WeatherForecastCaching = UserDefaultsWeatherForecastCache()
    var nowProvider: @Sendable () -> Date = { .now }

    func readingWindows(for bookID: UUID) async throws -> [ReadingWindow] {
        try await readingWindows(
            for: bookID,
            preferences: settings.preferences,
            city: settings.city,
            allowsMockFallback: true
        )
    }

    func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String
    ) async throws -> [ReadingWindow] {
        try await readingWindows(
            for: bookID,
            preferences: preferences,
            city: city,
            allowsMockFallback: false
        )
    }

    private func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String,
        allowsMockFallback: Bool
    ) async throws -> [ReadingWindow] {
        let now = nowProvider()
        let cached = cache.entry(for: city)
        let cachedRanges = cached.map {
            RecommendationEngine().dailyRanges(
                $0.forecast.candidates,
                preferences: preferences,
                bookID: bookID,
                events: [],
                now: $0.savedAt
            )
        } ?? []
        let cacheAge = cached.map { now.timeIntervalSince($0.savedAt) } ?? .infinity
        let cacheAgeIsValid = cacheAge >= 0 && cacheAge < 86_400
        let closestCachedWindowPassed = cachedRanges.first.map { $0.end <= now } ?? true

        let batch: WeatherForecastBatch
        let isCached: Bool
        if let cached, cacheAgeIsValid, !closestCachedWindowPassed {
            batch = cached.forecast
            isCached = true
        } else {
            do {
                let coordinate = try await location.coordinate(for: city)
                batch = try await weather.hourlyForecast(at: coordinate)
                cache.save(batch, for: city, at: now)
                isCached = false
            } catch is CancellationError {
                throw CancellationError()
            } catch let error where cached != nil {
                guard let cached else { throw error }
                batch = cached.forecast
                isCached = true
            } catch where allowsMockFallback {
                batch = try await MockWeatherProvider().hourlyForecast(at: LocationCoordinate(latitude: 0, longitude: 0))
                cache.save(batch, for: city, at: now)
                isCached = false
            }
        }

        let events = preferences.personalizationEnabled ? personalization.events() : []
        var candidates = batch.candidates
        if preferences.calendarAvailabilityEnabled,
           let first = candidates.min(by: { $0.date < $1.date })?.date,
           let last = candidates.max(by: { $0.date < $1.date })?.date {
            let busy = try await calendar.busyIntervals(in: DateInterval(start: first, end: last.addingTimeInterval(3600)))
            candidates.removeAll { candidate in
                let reading = DateInterval(start: candidate.date, duration: TimeInterval(preferences.preferredWindowMinutes * 60))
                return busy.contains { $0.intersects(reading) }
            }
        }
        return RecommendationEngine().dailyRanges(
            candidates,
            preferences: preferences,
            bookID: bookID,
            events: events,
            now: now,
            limit: 7
        ).map { window in
            var window = window
            window.isCached = isCached
            window.weatherSource = batch.source
            return window
        }
    }
}
