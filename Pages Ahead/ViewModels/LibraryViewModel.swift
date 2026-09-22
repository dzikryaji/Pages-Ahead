import Foundation
import Observation

@MainActor @Observable
final class LibraryViewModel {
    private struct PendingCoverLoad {
        let url: URL
        let token: UUID
        let task: Task<Void, Never>
    }

    private let repository: LibraryRepository
    private let coverImages: any BookCoverImageLoading
    @ObservationIgnored private var pendingCoverLoads: [UUID: PendingCoverLoad] = [:]
    var books: [Book] = []
    var query = ""

    init(
        repository: LibraryRepository,
        coverImages: (any BookCoverImageLoading)? = nil
    ) {
        self.repository = repository
        self.coverImages = coverImages ?? CoverImageCache.shared
        reload()
    }
    var filteredBooks: [Book] {
        guard !query.isEmpty else { return books }
        return books.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query) }
    }
    func books(with status: ReadingStatus) -> [Book] { filteredBooks.filter { $0.status == status } }
    func add(_ book: Book) {
        repository.add(book)
        reload()
        loadCoverIfNeeded(for: book.id)
    }

    func update(_ book: Book) {
        repository.update(book)
        reload()
        loadCoverIfNeeded(for: book.id)
    }

    func reload() { books = repository.books() }

    private func loadCoverIfNeeded(for bookID: UUID) {
        guard let book = books.first(where: { $0.id == bookID }),
              book.coverImageData == nil,
              let url = book.coverURL else {
            pendingCoverLoads.removeValue(forKey: bookID)?.task.cancel()
            return
        }
        if pendingCoverLoads[bookID]?.url == url { return }

        pendingCoverLoads.removeValue(forKey: bookID)?.task.cancel()
        let token = UUID()

        let coverImages = coverImages
        let task = Task { [weak self] in
            do {
                let data = try await coverImages.data(
                    for: url,
                    embeddedData: nil
                )
                try Task.checkCancellation()
                guard let self,
                      self.pendingCoverLoads[bookID]?.token == token else {
                    return
                }
                defer { self.pendingCoverLoads[bookID] = nil }
                guard var storedBook = self.repository.books().first(where: {
                    $0.id == bookID
                }),
                      storedBook.coverURL == url,
                      storedBook.coverImageData == nil else { return }
                storedBook.coverImageData = data
                self.repository.update(storedBook)
                self.reload()
            } catch {
                guard let self,
                      self.pendingCoverLoads[bookID]?.token == token else {
                    return
                }
                self.pendingCoverLoads[bookID] = nil
            }
        }
        pendingCoverLoads[bookID] = PendingCoverLoad(
            url: url,
            token: token,
            task: task
        )
    }
}
