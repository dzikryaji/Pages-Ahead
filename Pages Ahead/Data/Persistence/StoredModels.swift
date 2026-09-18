import Foundation
import SwiftData

@Model
final class StoredBook {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var edition: String
    var isbn: String
    var pageCount: Int
    @Attribute(originalName: "formatRawValue") var legacyMetadata: String
    var statusRawValue: String
    var currentPage: Int
    var coverURLString: String?
    @Attribute(.externalStorage) var coverImageData: Data?
    var catalogSource: String

    init(book: Book) {
        id = book.id; title = book.title; author = book.author; edition = book.edition
        isbn = book.isbn; pageCount = book.pageCount; legacyMetadata = ""
        statusRawValue = book.status.rawValue; currentPage = book.currentPage
        coverURLString = book.coverURL?.absoluteString
        coverImageData = book.coverImageData
        catalogSource = book.catalogSource
    }

    var domain: Book {
        Book(id: id, title: title, author: author, edition: edition, isbn: isbn, pageCount: pageCount,
             status: ReadingStatus(rawValue: statusRawValue) ?? .saved, currentPage: currentPage,
             coverURL: coverURLString.flatMap(URL.init(string:)),
             coverImageData: coverImageData, catalogSource: catalogSource)
    }

    func update(from book: Book) {
        title = book.title; author = book.author; edition = book.edition; isbn = book.isbn
        pageCount = book.pageCount
        statusRawValue = book.status.rawValue; currentPage = book.currentPage
        coverURLString = book.coverURL?.absoluteString
        coverImageData = book.coverImageData
        catalogSource = book.catalogSource
    }
}

@Model
final class StoredReadingRecord {
    @Attribute(.unique) var id: UUID
    var bookID: UUID
    var date: Date
    var minutes: Int
    var pages: Int
    var weather: String
    var place: String
    var feedback: String
    var note: String
    var durationSeconds: Int?
    var startingPage: Int?
    var lastPage: Int?
    var cycleID: UUID?

    init(record: ReadingRecord) {
        id = record.id; bookID = record.bookID; date = record.date; minutes = record.minutes
        pages = record.pages; weather = record.weather; place = ""
        feedback = ""; note = ""
        durationSeconds = record.durationSeconds
        startingPage = record.startingPage
        lastPage = record.lastPage
        cycleID = record.cycleID
    }

    var domain: ReadingRecord {
        ReadingRecord(
            id: id,
            bookID: bookID,
            date: date,
            durationSeconds: durationSeconds ?? max(0, minutes) * 60,
            startingPage: startingPage ?? 0,
            lastPage: lastPage ?? max(0, pages),
            weather: weather,
            cycleID: cycleID ?? id
        )
    }

    func update(from record: ReadingRecord) {
        bookID = record.bookID; date = record.date; minutes = record.minutes; pages = record.pages
        weather = record.weather
        durationSeconds = record.durationSeconds
        startingPage = record.startingPage
        lastPage = record.lastPage
        cycleID = record.cycleID
    }
}

@Model
final class StoredReadingPlan {
    private static let unassignedBookID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Attribute(.unique) var id: UUID
    var start: Date
    var durationMinutes: Int
    var place: String
    var bookID: UUID
    var reminderEnabled: Bool
    var calendarEnabled: Bool
    var calendarEventID: String?
    var end: Date?

    init(session: ReadingPlan) {
        id = session.id; start = session.start; durationMinutes = session.durationMinutes
        place = session.place; bookID = session.bookID ?? Self.unassignedBookID; reminderEnabled = session.reminderEnabled
        calendarEnabled = session.calendarEnabled
        calendarEventID = session.calendarEventID
        end = session.end
    }
    var domain: ReadingPlan {
        ReadingPlan(
            id: id,
            start: start,
            end: end ?? start.addingTimeInterval(TimeInterval(max(1, durationMinutes) * 60)),
            place: place,
            bookID: bookID == Self.unassignedBookID ? nil : bookID,
            reminderEnabled: reminderEnabled,
            calendarEnabled: calendarEnabled,
            calendarEventID: calendarEventID
        )
    }
    func update(from session: ReadingPlan) {
        start = session.start; durationMinutes = session.durationMinutes; place = session.place
        bookID = session.bookID ?? Self.unassignedBookID; reminderEnabled = session.reminderEnabled; calendarEnabled = session.calendarEnabled
        calendarEventID = session.calendarEventID
        end = session.end
    }
}

@Model
final class StoredPersonalizationEvent {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var date: Date
    var hour: Int
    var temperature: Int?
    var place: String
    var reason: String?

    init(event: PersonalizationEvent) {
        id = event.id; kindRawValue = event.kind.rawValue; date = event.date; hour = event.hour
        temperature = event.temperature; place = event.place; reason = event.reason
    }

    var domain: PersonalizationEvent {
        PersonalizationEvent(id: id, kind: PersonalizationEventKind(rawValue: kindRawValue) ?? .rejected,
                             date: date, hour: hour, temperature: temperature, place: place, reason: reason)
    }
}

@Model
final class StoredCatalogEntry {
    @Attribute(.unique) var id: UUID
    var queryKey: String
    var fetchedAt: Date
    var resultOrder: Int
    var representsEmptyResult: Bool
    var bookID: UUID
    var title: String
    var author: String
    var edition: String
    var isbn: String
    var pageCount: Int
    var coverURLString: String?
    @Attribute(.externalStorage) var coverImageData: Data?
    var catalogSource: String

    init(book: Book, queryKey: String, fetchedAt: Date, resultOrder: Int) {
        id = UUID()
        self.queryKey = queryKey
        self.fetchedAt = fetchedAt
        self.resultOrder = resultOrder
        representsEmptyResult = false
        bookID = book.id
        title = book.title
        author = book.author
        edition = book.edition
        isbn = book.isbn
        pageCount = book.pageCount
        coverURLString = book.coverURL?.absoluteString
        coverImageData = book.coverImageData
        catalogSource = book.catalogSource
    }

    init(emptyQueryKey queryKey: String, fetchedAt: Date) {
        id = UUID()
        self.queryKey = queryKey
        self.fetchedAt = fetchedAt
        resultOrder = -1
        representsEmptyResult = true
        bookID = UUID()
        title = ""
        author = ""
        edition = ""
        isbn = ""
        pageCount = 0
        coverURLString = nil
        coverImageData = nil
        catalogSource = ""
    }

    var domain: Book? {
        guard !representsEmptyResult else { return nil }
        return Book(id: bookID, title: title, author: author, edition: edition, isbn: isbn,
                    pageCount: pageCount, status: .saved, currentPage: 0,
                    coverURL: coverURLString.flatMap(URL.init(string:)),
                    coverImageData: coverImageData, catalogSource: catalogSource)
    }
}
