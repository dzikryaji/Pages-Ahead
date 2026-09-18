import Foundation

struct ReadingPlan: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var start: Date
    var end: Date
    var place: String
    var bookID: UUID?
    var reminderEnabled: Bool
    var calendarEnabled: Bool
    var calendarEventID: String? = nil

    var durationMinutes: Int {
        get { max(1, Int(end.timeIntervalSince(start) / 60)) }
        set { end = start.addingTimeInterval(TimeInterval(max(1, newValue) * 60)) }
    }

    init(
        id: UUID,
        start: Date,
        end: Date,
        place: String,
        bookID: UUID?,
        reminderEnabled: Bool,
        calendarEnabled: Bool,
        calendarEventID: String? = nil
    ) {
        self.id = id
        self.start = start
        self.end = max(end, start.addingTimeInterval(60))
        self.place = place
        self.bookID = bookID
        self.reminderEnabled = reminderEnabled
        self.calendarEnabled = calendarEnabled
        self.calendarEventID = calendarEventID
    }

    init(
        id: UUID,
        start: Date,
        durationMinutes: Int,
        place: String,
        bookID: UUID?,
        reminderEnabled: Bool,
        calendarEnabled: Bool,
        calendarEventID: String? = nil
    ) {
        self.init(
            id: id,
            start: start,
            end: start.addingTimeInterval(TimeInterval(max(1, durationMinutes) * 60)),
            place: place,
            bookID: bookID,
            reminderEnabled: reminderEnabled,
            calendarEnabled: calendarEnabled,
            calendarEventID: calendarEventID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, start, end, durationMinutes, place, bookID
        case reminderEnabled, calendarEnabled, calendarEventID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        start = try values.decode(Date.self, forKey: .start)
        let legacyDuration = try values.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 30
        end = try values.decodeIfPresent(Date.self, forKey: .end)
            ?? start.addingTimeInterval(TimeInterval(max(1, legacyDuration) * 60))
        place = try values.decodeIfPresent(String.self, forKey: .place) ?? "Not recorded"
        bookID = try values.decodeIfPresent(UUID.self, forKey: .bookID)
        reminderEnabled = try values.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        calendarEnabled = try values.decodeIfPresent(Bool.self, forKey: .calendarEnabled) ?? false
        calendarEventID = try values.decodeIfPresent(String.self, forKey: .calendarEventID)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(start, forKey: .start)
        try values.encode(end, forKey: .end)
        try values.encode(place, forKey: .place)
        try values.encodeIfPresent(bookID, forKey: .bookID)
        try values.encode(reminderEnabled, forKey: .reminderEnabled)
        try values.encode(calendarEnabled, forKey: .calendarEnabled)
        try values.encodeIfPresent(calendarEventID, forKey: .calendarEventID)
    }
}
