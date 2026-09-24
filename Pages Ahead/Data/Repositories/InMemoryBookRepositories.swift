import Foundation

final class InMemoryLibraryRepository: LibraryRepository {
    private var storage: [Book]
    init(books: [Book] = []) { storage = books }
    func books() -> [Book] { storage }
    func add(_ book: Book) { guard !storage.contains(where: { $0.id == book.id }) else { return }; storage.append(book) }
    func update(_ book: Book) { guard let index = storage.firstIndex(where: { $0.id == book.id }) else { return }; storage[index] = book }
    func delete(id: UUID) { storage.removeAll { $0.id == id } }
}

@MainActor
final class InMemoryCatalogSearchCache: CatalogSearchCaching {
    private var storage: [String: CachedCatalogSearch] = [:]

    func results(for query: String) -> CachedCatalogSearch? { storage[query.normalizedCacheKey] }
    func save(_ books: [Book], for query: String, fetchedAt: Date = .now) {
        storage[query.normalizedCacheKey] = CachedCatalogSearch(books: books, fetchedAt: fetchedAt)
    }
    func saveCoverImage(_ data: Data, for bookID: UUID, query: String) {
        let key = query.normalizedCacheKey
        guard let cached = storage[key] else { return }
        var books = cached.books
        guard let index = books.firstIndex(where: { $0.id == bookID }) else {
            return
        }
        books[index].coverImageData = data
        storage[key] = CachedCatalogSearch(
            books: books,
            fetchedAt: cached.fetchedAt
        )
    }
}

extension String {
    var normalizedCacheKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

struct MockReadingWindowRepository: ReadingWindowRepository {
    func readingWindows(for bookID: UUID) async throws -> [ReadingWindow] { SampleData.windows(bookID: bookID) }

    func readingWindows(
        for bookID: UUID,
        preferences: ReadingPreferences,
        city: String
    ) async throws -> [ReadingWindow] {
        SampleData.windows(bookID: bookID)
    }
}

final class InMemoryActivityRepository: ActivityRepository {
    private var storage: [ReadingRecord]
    init(bookID: UUID = SampleData.books[0].id, records: [ReadingRecord]? = nil) {
        if let records { storage = records; return }
        let calendar = Calendar.current
        storage = [
            ReadingRecord(id: UUID(), bookID: bookID, date: calendar.date(byAdding: .day, value: -1, to: .now)!, minutes: 32, pages: 18, weather: "Rainy, 24°"),
            ReadingRecord(id: UUID(), bookID: bookID, date: calendar.date(byAdding: .day, value: -4, to: .now)!, minutes: 24, pages: 13, weather: "Cloudy, 23°")
        ]
    }
    func records() -> [ReadingRecord] { storage.sorted { $0.date > $1.date } }
    func save(_ record: ReadingRecord) { storage.removeAll { $0.id == record.id }; storage.append(record) }
    func delete(id: UUID) { storage.removeAll { $0.id == id } }
}
