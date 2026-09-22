import Foundation
import Observation

@MainActor @Observable
final class CatalogSearchViewModel {
    private let catalog: BookCatalogSearching
    private let cache: CatalogSearchCaching
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var hasActiveQuery = false
    var query = ""
    var state: LoadState<[Book]> = .idle
    var selected: Book?
    var isRefreshing = false

    init(catalog: BookCatalogSearching, cache: CatalogSearchCaching) {
        self.catalog = catalog
        self.cache = cache
    }

    func queryChanged(to value: String) {
        query = value
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        selected = nil
        isRefreshing = false

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            hasActiveQuery = false
            return
        }

        let cached = cache.results(for: trimmed)
        if let cached {
            state = .loaded(cached.books)
        } else {
            state = .loading
        }

        let delay: Duration = hasActiveQuery ? .seconds(1) : .zero
        hasActiveQuery = true
        let cacheAge = cached.map { Date.now.timeIntervalSince($0.fetchedAt) }
        let cacheIsFresh = cacheAge.map { $0 >= 0 && $0 < 30 * 86_400 } ?? false
        guard !cacheIsFresh else { return }

        isRefreshing = cached != nil
        searchTask = Task { [weak self] in
            do {
                if delay != .zero { try await Task.sleep(for: delay) }
                guard !Task.isCancelled, let self else { return }
                let books = try await self.catalog.search(query: trimmed)
                guard !Task.isCancelled, generation == self.searchGeneration else { return }
                let fetchedAt = Date.now
                self.cache.save(books, for: trimmed, fetchedAt: fetchedAt)
                self.state = .loaded(books)
                self.isRefreshing = false
            } catch is CancellationError {
                // Newer query owns visible state.
            } catch {
                guard let self, generation == self.searchGeneration else { return }
                self.isRefreshing = false
                if cached == nil { self.state = .failed(error.localizedDescription) }
            }
        }
    }

    func coverLoaded(_ data: Data, for bookID: UUID) {
        coverLoaded(data, for: bookID, query: query)
    }

    func coverLoaded(_ data: Data, for bookID: UUID, query resultQuery: String) {
        cache.saveCoverImage(data, for: bookID, query: resultQuery)
        guard resultQuery.normalizedCacheKey == query.normalizedCacheKey else {
            return
        }
        guard case .loaded(var books) = state,
              let index = books.firstIndex(where: { $0.id == bookID }),
              books[index].coverImageData == nil else { return }
        books[index].coverImageData = data
        state = .loaded(books)
        if selected?.id == bookID { selected?.coverImageData = data }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}
