import Foundation

struct ReadingRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let bookID: UUID
    var date: Date
    var durationSeconds: Int
    var startingPage: Int
    var lastPage: Int
    var weather: String
    var cycleID: UUID

    var minutes: Int {
        get { durationSeconds / 60 }
        set { durationSeconds = max(0, newValue) * 60 }
    }

    var pages: Int {
        get { max(0, lastPage - startingPage) }
        set { lastPage = max(startingPage, startingPage + max(0, newValue)) }
    }

    var durationText: String { DurationFormatting.stopwatch(durationSeconds) }

    init(
        id: UUID,
        bookID: UUID,
        date: Date,
        durationSeconds: Int,
        startingPage: Int,
        lastPage: Int,
        weather: String,
        cycleID: UUID = UUID()
    ) {
        self.id = id
        self.bookID = bookID
        self.date = date
        self.durationSeconds = max(0, durationSeconds)
        self.startingPage = max(0, startingPage)
        self.lastPage = max(self.startingPage, lastPage)
        self.weather = weather
        self.cycleID = cycleID
    }

    init(
        id: UUID,
        bookID: UUID,
        date: Date,
        minutes: Int,
        pages: Int,
        weather: String
    ) {
        self.init(
            id: id,
            bookID: bookID,
            date: date,
            durationSeconds: max(0, minutes) * 60,
            startingPage: 0,
            lastPage: max(0, pages),
            weather: weather
        )
    }

    func with(lastPage: Int, durationSeconds: Int) -> ReadingRecord {
        var copy = self
        copy.lastPage = max(startingPage, lastPage)
        copy.durationSeconds = max(0, durationSeconds)
        return copy
    }
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

enum ReadingSessionOrigin: String, Codable, Sendable {
    case readingPlan
    case bookDetail
}

enum ReadingSessionPhase: String, Codable, Sendable {
    case running
    case paused
    case summary
}

struct ActiveReadingSession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let bookID: UUID
    var accumulatedSeconds: Int
    var startedAt: Date?
    var isPaused: Bool
    let startingPage: Int
    let origin: ReadingSessionOrigin
    let readingPlanID: UUID?
    let startedInsideReadingWindow: Bool
    let weather: String
    let isReread: Bool
    var phase: ReadingSessionPhase

    init(
        id: UUID = UUID(),
        bookID: UUID,
        accumulatedSeconds: Int,
        startedAt: Date?,
        isPaused: Bool,
        startingPage: Int,
        origin: ReadingSessionOrigin,
        readingPlanID: UUID? = nil,
        startedInsideReadingWindow: Bool = false,
        weather: String = "Not recorded",
        isReread: Bool = false,
        phase: ReadingSessionPhase? = nil
    ) {
        self.id = id
        self.bookID = bookID
        self.accumulatedSeconds = max(0, accumulatedSeconds)
        self.startedAt = startedAt
        self.isPaused = isPaused
        self.startingPage = max(0, startingPage)
        self.origin = origin
        self.readingPlanID = readingPlanID
        self.startedInsideReadingWindow = startedInsideReadingWindow
        self.weather = weather
        self.isReread = isReread
        self.phase = phase ?? (isPaused ? .paused : .running)
    }

    init(
        bookID: UUID,
        durationSeconds: Int,
        accumulatedSeconds: Int,
        startedAt: Date?,
        isPaused: Bool
    ) {
        self.init(
            bookID: bookID,
            accumulatedSeconds: min(max(0, accumulatedSeconds), max(0, durationSeconds)),
            startedAt: startedAt,
            isPaused: isPaused,
            startingPage: 0,
            origin: .bookDetail
        )
    }

    func elapsedSeconds(at date: Date) -> Int {
        let running = startedAt.map { max(0, Int(date.timeIntervalSince($0))) } ?? 0
        return max(0, accumulatedSeconds + (isPaused || phase == .summary ? 0 : running))
    }

    private enum CodingKeys: String, CodingKey {
        case id, bookID, durationSeconds, accumulatedSeconds, startedAt, isPaused
        case startingPage, origin, readingPlanID, startedInsideReadingWindow
        case plannedSessionID, startedInsidePlannedWindow
        case weather, isReread, phase
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        bookID = try values.decode(UUID.self, forKey: .bookID)
        let accumulated = try values.decodeIfPresent(Int.self, forKey: .accumulatedSeconds) ?? 0
        let legacyLimit = try values.decodeIfPresent(Int.self, forKey: .durationSeconds)
        accumulatedSeconds = min(max(0, accumulated), legacyLimit ?? .max)
        startedAt = try values.decodeIfPresent(Date.self, forKey: .startedAt)
        isPaused = try values.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        startingPage = try values.decodeIfPresent(Int.self, forKey: .startingPage) ?? 0
        origin = try values.decodeIfPresent(ReadingSessionOrigin.self, forKey: .origin) ?? .bookDetail
        readingPlanID = try values.decodeIfPresent(UUID.self, forKey: .readingPlanID)
            ?? values.decodeIfPresent(UUID.self, forKey: .plannedSessionID)
        startedInsideReadingWindow = try values.decodeIfPresent(Bool.self, forKey: .startedInsideReadingWindow)
            ?? values.decodeIfPresent(Bool.self, forKey: .startedInsidePlannedWindow)
            ?? false
        weather = try values.decodeIfPresent(String.self, forKey: .weather) ?? "Not recorded"
        isReread = try values.decodeIfPresent(Bool.self, forKey: .isReread) ?? false
        phase = try values.decodeIfPresent(ReadingSessionPhase.self, forKey: .phase)
            ?? (isPaused ? .paused : .running)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(bookID, forKey: .bookID)
        try values.encode(accumulatedSeconds, forKey: .accumulatedSeconds)
        try values.encodeIfPresent(startedAt, forKey: .startedAt)
        try values.encode(isPaused, forKey: .isPaused)
        try values.encode(startingPage, forKey: .startingPage)
        try values.encode(origin, forKey: .origin)
        try values.encodeIfPresent(readingPlanID, forKey: .readingPlanID)
        try values.encode(startedInsideReadingWindow, forKey: .startedInsideReadingWindow)
        try values.encode(weather, forKey: .weather)
        try values.encode(isReread, forKey: .isReread)
        try values.encode(phase, forKey: .phase)
    }
}

enum DurationFormatting {
    static func stopwatch(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remainder) }
        return String(format: "%02d:%02d", minutes, remainder)
    }
}
