import Foundation

enum WeatherDataSource: String, Codable, Sendable {
    case weatherKit = "Apple Weather"
    case openMeteo = "Open-Meteo"
    case mock = "Preview weather"
}

struct ReadingWindow: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let start: Date
    let end: Date
    let temperature: Int
    let condition: String
    let weatherSymbol: String
    let place: String
    let fitReason: String
    let bookID: UUID?
    var isCached: Bool = false
    var weatherSource: WeatherDataSource = .mock

    var durationMinutes: Int {
        max(1, Int(end.timeIntervalSince(start) / 60))
    }

    init(
        id: UUID,
        start: Date,
        durationMinutes: Int,
        temperature: Int,
        condition: String,
        weatherSymbol: String,
        place: String,
        fitReason: String,
        bookID: UUID?,
        isCached: Bool = false,
        weatherSource: WeatherDataSource = .mock,
        end: Date? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end ?? start.addingTimeInterval(TimeInterval(durationMinutes * 60))
        self.temperature = temperature
        self.condition = condition
        self.weatherSymbol = weatherSymbol
        self.place = place
        self.fitReason = fitReason
        self.bookID = bookID
        self.isCached = isCached
        self.weatherSource = weatherSource
    }
}
