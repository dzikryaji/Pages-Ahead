import Foundation

enum ReadingProgressError: LocalizedError, Equatable {
    case bookMissing
    case lastPageBeforeStart(Int)
    case lastPageBeyondBook(Int)

    var errorDescription: String? {
        switch self {
        case .bookMissing:
            "This book is no longer in your library."
        case .lastPageBeforeStart(let page):
            "Last Page cannot be before page \(page)."
        case .lastPageBeyondBook(let page):
            "Last Page cannot be higher than page \(page)."
        }
    }
}

@MainActor
final class ReadingProgressReconciler {
    private let activity: ActivityRepository
    private let library: LibraryRepository

    init(activity: ActivityRepository, library: LibraryRepository) {
        self.activity = activity
        self.library = library
    }

    @discardableResult
    func complete(
        session: ActiveReadingSession,
        lastPage: Int,
        at date: Date
    ) throws -> ReadingRecord {
        guard var book = library.books().first(where: { $0.id == session.bookID }) else {
            throw ReadingProgressError.bookMissing
        }
        guard lastPage >= session.startingPage else {
            throw ReadingProgressError.lastPageBeforeStart(session.startingPage)
        }
        guard lastPage <= book.pageCount else {
            throw ReadingProgressError.lastPageBeyondBook(book.pageCount)
        }

        let previousCycle = activity.records()
            .filter { $0.bookID == book.id }
            .sorted { $0.date > $1.date }
            .first?.cycleID
        let record = ReadingRecord(
            id: UUID(),
            bookID: book.id,
            date: date,
            durationSeconds: session.elapsedSeconds(at: date),
            startingPage: session.startingPage,
            lastPage: lastPage,
            weather: session.weather,
            cycleID: session.isReread ? UUID() : (previousCycle ?? UUID())
        )
        activity.save(record)

        book.currentPage = lastPage
        book.status = lastPage >= book.pageCount && book.pageCount > 0 ? .finished : .reading
        library.update(book)
        return record
    }

    func update(record: ReadingRecord) throws {
        guard var book = library.books().first(where: { $0.id == record.bookID }) else {
            throw ReadingProgressError.bookMissing
        }
        guard record.lastPage >= record.startingPage else {
            throw ReadingProgressError.lastPageBeforeStart(record.startingPage)
        }
        guard record.lastPage <= book.pageCount else {
            throw ReadingProgressError.lastPageBeyondBook(book.pageCount)
        }

        let newestID = activity.records()
            .filter { $0.bookID == record.bookID }
            .max(by: { $0.date < $1.date })?.id
        activity.save(record)
        guard newestID == record.id else { return }
        book.currentPage = record.lastPage
        book.status = record.lastPage >= book.pageCount && book.pageCount > 0 ? .finished : .reading
        library.update(book)
    }

    func delete(recordID: UUID) {
        guard let target = activity.records().first(where: { $0.id == recordID }) else { return }
        let bookRecords = activity.records()
            .filter { $0.bookID == target.bookID }
            .sorted { $0.date > $1.date }
        let wasNewest = bookRecords.first?.id == target.id
        activity.delete(id: target.id)
        guard wasNewest,
              var book = library.books().first(where: { $0.id == target.bookID }) else { return }

        if let previous = bookRecords.dropFirst().first {
            book.currentPage = previous.lastPage
            book.status = previous.lastPage >= book.pageCount && book.pageCount > 0 ? .finished : .reading
        } else {
            book.currentPage = 0
            book.status = .saved
        }
        library.update(book)
    }
}
