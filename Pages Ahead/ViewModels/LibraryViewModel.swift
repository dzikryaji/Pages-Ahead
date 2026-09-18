import Foundation
import Observation

@MainActor @Observable
final class LibraryViewModel {
    private let repository: LibraryRepository
    private let coverImages: any BookCoverImageLoading
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
        guard book.coverImageData == nil, let url = book.coverURL else { return }

        let coverImages = coverImages
        Task { [weak self] in
            guard let data = try? await coverImages.data(
                for: url,
                embeddedData: nil
            ), let self,
                  var storedBook = self.repository.books().first(where: {
                      $0.id == book.id
                  }) else { return }
            storedBook.coverImageData = data
            self.repository.update(storedBook)
            self.reload()
        }
    }
    func update(_ book: Book) { repository.update(book); reload() }
    func reload() { books = repository.books() }
}
