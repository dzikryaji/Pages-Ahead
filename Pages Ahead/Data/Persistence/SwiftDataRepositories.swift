import Foundation
import SwiftData

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

    func delete(id: UUID) {
        var descriptor = FetchDescriptor<StoredBook>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let stored = try? context.fetch(descriptor).first else { return }
        context.delete(stored)
        save()
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
final class SwiftDataReadingPlanRepository: ReadingPlanRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }
    func current() -> ReadingPlan? {
        var descriptor = FetchDescriptor<StoredReadingPlan>(sortBy: [SortDescriptor(\.start, order: .forward)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.domain
    }
    func save(_ session: ReadingPlan) {
        let id = session.id
        var descriptor = FetchDescriptor<StoredReadingPlan>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let stored = try? context.fetch(descriptor).first { stored.update(from: session) }
        else {
            if let existing = try? context.fetch(FetchDescriptor<StoredReadingPlan>()) { existing.forEach(context.delete) }
            context.insert(StoredReadingPlan(session: session))
        }
        try? context.save()
    }
    func delete(id: UUID) {
        let target = id
        let descriptor = FetchDescriptor<StoredReadingPlan>(predicate: #Predicate { $0.id == target })
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
