import Foundation
import SwiftData

enum PagesAheadSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        StoredBook.self,
        StoredReadingRecord.self,
        StoredPlannedSession.self,
        StoredPersonalizationEvent.self
    ]
}

enum PagesAheadMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [PagesAheadSchemaV1.self]
    static let stages: [MigrationStage] = []
}

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

    init(record: ReadingRecord) {
        id = record.id; bookID = record.bookID; date = record.date; minutes = record.minutes
        pages = record.pages; weather = record.weather; place = record.place
        feedback = record.feedback; note = record.note
    }

    var domain: ReadingRecord {
        ReadingRecord(id: id, bookID: bookID, date: date, minutes: minutes, pages: pages,
                      weather: weather, place: place, feedback: feedback, note: note)
    }

    func update(from record: ReadingRecord) {
        bookID = record.bookID; date = record.date; minutes = record.minutes; pages = record.pages
        weather = record.weather; place = record.place; feedback = record.feedback; note = record.note
    }
}

@Model
final class StoredPlannedSession {
    private static let unassignedBookID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    @Attribute(.unique) var id: UUID
    var start: Date
    var durationMinutes: Int
    var place: String
    var bookID: UUID
    var reminderEnabled: Bool
    var calendarEnabled: Bool
    var calendarEventID: String?

    init(session: PlannedSession) {
        id = session.id; start = session.start; durationMinutes = session.durationMinutes
        place = session.place; bookID = session.bookID ?? Self.unassignedBookID; reminderEnabled = session.reminderEnabled
        calendarEnabled = session.calendarEnabled
        calendarEventID = session.calendarEventID
    }
    var domain: PlannedSession { PlannedSession(id: id, start: start, durationMinutes: durationMinutes, place: place, bookID: bookID == Self.unassignedBookID ? nil : bookID, reminderEnabled: reminderEnabled, calendarEnabled: calendarEnabled, calendarEventID: calendarEventID) }
    func update(from session: PlannedSession) {
        start = session.start; durationMinutes = session.durationMinutes; place = session.place
        bookID = session.bookID ?? Self.unassignedBookID; reminderEnabled = session.reminderEnabled; calendarEnabled = session.calendarEnabled
        calendarEventID = session.calendarEventID
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

@MainActor
final class SwiftDataCatalogSearchCache: CatalogSearchCaching {
    private let context: ModelContext

    init(context: ModelContext) { self.context = context }

    func results(for query: String) -> CachedCatalogSearch? {
        let key = query.normalizedCacheKey
        let descriptor = FetchDescriptor<StoredCatalogEntry>(
            predicate: #Predicate { $0.queryKey == key },
            sortBy: [SortDescriptor(\.resultOrder)]
        )
        guard let entries = try? context.fetch(descriptor),
              let fetchedAt = entries.first?.fetchedAt else { return nil }
        return CachedCatalogSearch(books: entries.compactMap(\.domain), fetchedAt: fetchedAt)
    }

    func save(_ books: [Book], for query: String, fetchedAt: Date) {
        let key = query.normalizedCacheKey
        let descriptor = FetchDescriptor<StoredCatalogEntry>(predicate: #Predicate { $0.queryKey == key })
        if let existing = try? context.fetch(descriptor) { existing.forEach(context.delete) }
        if books.isEmpty {
            context.insert(StoredCatalogEntry(emptyQueryKey: key, fetchedAt: fetchedAt))
        } else {
            for (index, book) in books.enumerated() {
                context.insert(StoredCatalogEntry(book: book, queryKey: key, fetchedAt: fetchedAt, resultOrder: index))
            }
        }
        try? context.save()
    }

    func saveCoverImage(_ data: Data, for bookID: UUID, query: String) {
        let key = query.normalizedCacheKey
        let descriptor = FetchDescriptor<StoredCatalogEntry>(
            predicate: #Predicate {
                $0.queryKey == key && $0.bookID == bookID
            }
        )
        guard let entry = try? context.fetch(descriptor).first else { return }
        entry.coverImageData = data
        try? context.save()
    }
}

@MainActor
final class SwiftDataLibraryRepository: LibraryRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func books() -> [Book] {
        let descriptor = FetchDescriptor<StoredBook>(sortBy: [SortDescriptor(\.title)])
        return (try? context.fetch(descriptor).map(\.domain)) ?? []
    }

    func add(_ book: Book) {
        guard !books().contains(where: { $0.id == book.id || (!$0.isbn.isEmpty && $0.isbn == book.isbn) }) else { return }
        context.insert(StoredBook(book: book)); save()
    }

    func update(_ book: Book) {
        let id = book.id
        var descriptor = FetchDescriptor<StoredBook>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let stored = try? context.fetch(descriptor).first else { add(book); return }
        stored.update(from: book); save()
    }

    private func save() { try? context.save() }
}

@MainActor
final class SwiftDataActivityRepository: ActivityRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func records() -> [ReadingRecord] {
        let descriptor = FetchDescriptor<StoredReadingRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor).map(\.domain)) ?? []
    }

    func save(_ record: ReadingRecord) {
        let id = record.id
        var descriptor = FetchDescriptor<StoredReadingRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let stored = try? context.fetch(descriptor).first { stored.update(from: record) }
        else { context.insert(StoredReadingRecord(record: record)) }
        try? context.save()
    }

    func delete(id: UUID) {
        let target = id
        let descriptor = FetchDescriptor<StoredReadingRecord>(predicate: #Predicate { $0.id == target })
        guard let records = try? context.fetch(descriptor) else { return }
        records.forEach(context.delete); try? context.save()
    }
}

@MainActor
final class SwiftDataPlannedSessionRepository: PlannedSessionRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func current() -> PlannedSession? {
        var descriptor = FetchDescriptor<StoredPlannedSession>(sortBy: [SortDescriptor(\.start, order: .forward)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.domain
    }
    func save(_ session: PlannedSession) {
        let id = session.id
        var descriptor = FetchDescriptor<StoredPlannedSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let stored = try? context.fetch(descriptor).first { stored.update(from: session) }
        else {
            if let existing = try? context.fetch(FetchDescriptor<StoredPlannedSession>()) { existing.forEach(context.delete) }
            context.insert(StoredPlannedSession(session: session))
        }
        try? context.save()
    }
    func delete(id: UUID) {
        let target = id
        let descriptor = FetchDescriptor<StoredPlannedSession>(predicate: #Predicate { $0.id == target })
        guard let matches = try? context.fetch(descriptor) else { return }
        matches.forEach(context.delete); try? context.save()
    }
}

@MainActor
final class SwiftDataPersonalizationRepository: PersonalizationRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func events() -> [PersonalizationEvent] {
        let descriptor = FetchDescriptor<StoredPersonalizationEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor).map(\.domain)) ?? []
    }
    func record(_ event: PersonalizationEvent) { context.insert(StoredPersonalizationEvent(event: event)); try? context.save() }
    func clear() {
        guard let stored = try? context.fetch(FetchDescriptor<StoredPersonalizationEvent>()) else { return }
        stored.forEach(context.delete); try? context.save()
    }
}
