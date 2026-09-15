import Foundation

enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case reading = "Currently Reading"
    case saved = "Saved"
    case finished = "Finished"
}

struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let title: String
    let author: String
    let edition: String
    let isbn: String
    let pageCount: Int
    var status: ReadingStatus
    var currentPage: Int
    var coverURL: URL? = nil
    var coverImageData: Data? = nil
    var catalogSource: String = "Open Library"

    var progress: Double { pageCount == 0 ? 0 : min(Double(currentPage) / Double(pageCount), 1) }
}

enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

extension LoadState: Equatable where Value: Equatable { }

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

struct PlannedSession: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var start: Date
    var durationMinutes: Int
    var place: String
    var bookID: UUID?
    var reminderEnabled: Bool
    var calendarEnabled: Bool
    var calendarEventID: String? = nil
}

struct ReadingRecord: Identifiable, Hashable {
    let id: UUID
    let bookID: UUID
    var date: Date
    var minutes: Int
    var pages: Int
    var weather: String
    var place: String
    var feedback: String
    var note: String
}

enum PersonalizationEventKind: String, Codable {
    case accepted
    case rejected
    case completed
}

struct PersonalizationEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let kind: PersonalizationEventKind
    let date: Date
    let hour: Int
    let temperature: Int?
    let place: String
    let reason: String?
}

struct ActiveReadingSession: Codable, Equatable {
    let bookID: UUID
    let durationSeconds: Int
    var accumulatedSeconds: Int
    var startedAt: Date?
    var isPaused: Bool
}

struct ReadingPreferences: Equatable, Codable, Sendable {
    var weekdayPreferredTime = "Morning"
    var weekendPreferredTime = "Morning"
    var preferredWeather = "Cold"
    var preferencePriority = "Time"
    var duration = 30
    var preferredTime = "Evening"
    var weatherInfluence = "Balanced"
    var temperature = "Mild"
    var place = "Either"
    var personalizationEnabled = true
    var availableDays: Set<String> = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    var calendarAvailabilityEnabled = false
    var remindersEnabled = false
    var plannedSessionsOnly = true
    var reminderLeadTime = 10
    var automaticLocation = true
    var preciseLocation = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case weekdayPreferredTime, weekendPreferredTime, preferredWeather, preferencePriority
        case duration, preferredTime, weatherInfluence, temperature, place
        case personalizationEnabled, availableDays, calendarAvailabilityEnabled
        case remindersEnabled, plannedSessionsOnly, reminderLeadTime
        case automaticLocation, preciseLocation
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        duration = try values.decodeIfPresent(Int.self, forKey: .duration) ?? 30
        preferredTime = try values.decodeIfPresent(String.self, forKey: .preferredTime) ?? "Evening"
        weatherInfluence = try values.decodeIfPresent(String.self, forKey: .weatherInfluence) ?? "Balanced"
        temperature = try values.decodeIfPresent(String.self, forKey: .temperature) ?? "Mild"
        place = try values.decodeIfPresent(String.self, forKey: .place) ?? "Either"
        weekdayPreferredTime = try values.decodeIfPresent(String.self, forKey: .weekdayPreferredTime) ?? preferredTime
        weekendPreferredTime = try values.decodeIfPresent(String.self, forKey: .weekendPreferredTime) ?? preferredTime
        preferredWeather = try values.decodeIfPresent(String.self, forKey: .preferredWeather) ?? temperature
        if let storedPriority = try values.decodeIfPresent(String.self, forKey: .preferencePriority) {
            preferencePriority = storedPriority
        } else {
            preferencePriority = switch weatherInfluence {
            case "High": "Weather"
            case "Balanced": "Balanced"
            default: "Time"
            }
        }
        personalizationEnabled = try values.decodeIfPresent(Bool.self, forKey: .personalizationEnabled) ?? true
        availableDays = try values.decodeIfPresent(Set<String>.self, forKey: .availableDays)
            ?? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        calendarAvailabilityEnabled = try values.decodeIfPresent(Bool.self, forKey: .calendarAvailabilityEnabled) ?? false
        remindersEnabled = try values.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        plannedSessionsOnly = try values.decodeIfPresent(Bool.self, forKey: .plannedSessionsOnly) ?? true
        reminderLeadTime = try values.decodeIfPresent(Int.self, forKey: .reminderLeadTime) ?? 10
        automaticLocation = try values.decodeIfPresent(Bool.self, forKey: .automaticLocation) ?? true
        preciseLocation = try values.decodeIfPresent(Bool.self, forKey: .preciseLocation) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(weekdayPreferredTime, forKey: .weekdayPreferredTime)
        try values.encode(weekendPreferredTime, forKey: .weekendPreferredTime)
        try values.encode(preferredWeather, forKey: .preferredWeather)
        try values.encode(preferencePriority, forKey: .preferencePriority)
        try values.encode(duration, forKey: .duration)
        try values.encode(preferredTime, forKey: .preferredTime)
        try values.encode(weatherInfluence, forKey: .weatherInfluence)
        try values.encode(temperature, forKey: .temperature)
        try values.encode(place, forKey: .place)
        try values.encode(personalizationEnabled, forKey: .personalizationEnabled)
        try values.encode(availableDays, forKey: .availableDays)
        try values.encode(calendarAvailabilityEnabled, forKey: .calendarAvailabilityEnabled)
        try values.encode(remindersEnabled, forKey: .remindersEnabled)
        try values.encode(plannedSessionsOnly, forKey: .plannedSessionsOnly)
        try values.encode(reminderLeadTime, forKey: .reminderLeadTime)
        try values.encode(automaticLocation, forKey: .automaticLocation)
        try values.encode(preciseLocation, forKey: .preciseLocation)
    }
}

enum OnboardingPage: Int, CaseIterable, Codable, Sendable {
    case welcome = 1
    case outcome
    case howItWorks
    case preferences
    case book
    case location
    case recommendations
    case complete

    enum Group: Int, Comparable, Sendable {
        case intro
        case setup
        case finish

        static func < (lhs: Group, rhs: Group) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var group: Group {
        switch self {
        case .welcome, .outcome, .howItWorks: .intro
        case .preferences, .book, .location, .recommendations: .setup
        case .complete: .finish
        }
    }

    var setupStep: Int? {
        guard group == .setup else { return nil }
        return rawValue - Self.preferences.rawValue + 1
    }
}

enum OnboardingLocationMode: String, Codable, Sendable {
    case current
    case manual
}

enum OnboardingReminderChoice: String, Codable, Sendable {
    case undecided
    case allow
    case notNow
}

enum OnboardingNotificationOutcome: String, Codable, Sendable {
    case notRequested
    case scheduled
    case denied
    case unavailable
}

struct OnboardingDraft: Equatable, Codable, Sendable {
    var introductionSeen = false
    var currentPage: OnboardingPage = .welcome
    var preferences = ReadingPreferences()
    var selectedBooks: [Book] = []
    var bookSearchQuery = ""
    var bookSearchResults: [Book] = []
    var locationMode: OnboardingLocationMode?
    var resolvedCity = ""
    var recommendationCandidates: [ReadingWindow] = []
    var selectedCandidateID: UUID?
    var plannedSession: PlannedSession?
    var plannedDuringOnboarding = false
    var reminderChoice: OnboardingReminderChoice = .undecided
    var notificationOutcome: OnboardingNotificationOutcome = .notRequested
}

enum SampleData {
    static let books: [Book] = [
        Book(id: UUID(uuidString: "77D55E5B-F34E-42A0-A291-A9483884DF62")!, title: "The Left Hand of Darkness", author: "Ursula K. Le Guin", edition: "50th Anniversary Edition", isbn: "9780441478125", pageCount: 304, status: .reading, currentPage: 126),
        Book(id: UUID(uuidString: "AAEB0ED4-E291-403C-B4B0-DB795808BF7C")!, title: "Braiding Sweetgrass", author: "Robin Wall Kimmerer", edition: "First paperback edition", isbn: "9781571313560", pageCount: 408, status: .saved, currentPage: 0),
        Book(id: UUID(uuidString: "433E22EB-98A6-4EAF-B86F-987D138796A0")!, title: "Piranesi", author: "Susanna Clarke", edition: "Bloomsbury edition", isbn: "9781635577808", pageCount: 272, status: .saved, currentPage: 0)
    ]

    static func windows(bookID: UUID) -> [ReadingWindow] {
        let calendar = Calendar.current
        let today = Date()
        let starts = [
            calendar.date(bySettingHour: 18, minute: 30, second: 0, of: today)!,
            calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today)!)!,
            calendar.date(byAdding: .day, value: 2, to: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)!)!
        ]
        return [
            ReadingWindow(id: UUID(), start: starts[0], durationMinutes: 35, temperature: 24, condition: "Light rain", weatherSymbol: "cloud.rain.fill", place: "Indoors", fitReason: "Your evening is open, and light rain matches your calm indoor preference.", bookID: bookID),
            ReadingWindow(id: UUID(), start: starts[1], durationMinutes: 25, temperature: 22, condition: "Cloudy", weatherSymbol: "cloud.fill", place: "Covered patio", fitReason: "A short open window before your day begins, with mild weather.", bookID: bookID),
            ReadingWindow(id: UUID(), start: starts[2], durationMinutes: 45, temperature: 25, condition: "Clear", weatherSymbol: "moon.stars.fill", place: "Indoors", fitReason: "A longer evening opening near your preferred reading time.", bookID: bookID)
        ]
    }
}
