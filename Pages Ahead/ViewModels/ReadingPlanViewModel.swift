import Foundation
import Observation

@MainActor @Observable
final class ReadingPlanViewModel {
    private let library: LibraryRepository
    private let repository: ReadingWindowRepository
    private let personalization: PersonalizationRepository
    var books: [Book] = []
    var windows: [ReadingWindow] = []
    var selectedBookID: UUID?
    var loadError: String?
    var isLoading = false

    init(library: LibraryRepository, repository: ReadingWindowRepository, personalization: PersonalizationRepository) {
        self.library = library
        self.repository = repository
        self.personalization = personalization
        books = library.books()
    }

    var recommendedBook: Book? { selectedBookID.flatMap(book(id:)) ?? books.first(where: { $0.status == .reading }) ?? books.first }
    var personalizationRepository: PersonalizationRepository { personalization }
    func book(id: UUID?) -> Book? {
        guard let id else { return nil }
        return books.first { $0.id == id }
    }
    func reload() async {
        books = library.books()
        guard let book = recommendedBook else { windows = []; return }
        isLoading = true; loadError = nil
        defer { isLoading = false }
        do { windows = try await repository.readingWindows(for: book.id) }
        catch { windows = []; loadError = error.localizedDescription }
    }
    func selectBook(_ book: Book) async {
        selectedBookID = book.id
        await reload()
    }
    func reject(_ window: ReadingWindow, reason: String?) {
        personalization.record(PersonalizationEvent(id: UUID(), kind: .rejected, date: .now,
            hour: Calendar.current.component(.hour, from: window.start), temperature: window.temperature,
            place: window.place, reason: reason))
        windows.removeAll { $0.id == window.id }
    }
}
