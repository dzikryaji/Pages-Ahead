import SwiftUI

struct BookDetailView: View {
    @State private var book: Book
    let repository: LibraryViewModel
    @Bindable var sessionCoordinator: ReadingSessionCoordinator

    init(book: Book, repository: LibraryViewModel, sessionCoordinator: ReadingSessionCoordinator) {
        _book = State(initialValue: book)
        self.repository = repository
        self.sessionCoordinator = sessionCoordinator
    }

    private var actionTitle: String {
        switch book.status {
        case .saved: "Start Reading"
        case .reading: "Continue Reading"
        case .finished: "Read Again"
        }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    BookCover(book: book, width: 116)
                    Text(book.title).font(AppTypography.displayTitle).tracking(0.4)
                        .multilineTextAlignment(.center)
                    Text(book.author).font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            Section("Book information") {
                LabeledContent("Edition", value: book.edition)
                LabeledContent("ISBN", value: book.isbn)
                LabeledContent("Length", value: "\(book.pageCount) pages")
                Picker("Status", selection: $book.status) {
                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
            }
            if book.status == .reading {
                Section("Progress") {
                    ProgressView(value: book.progress)
                    Stepper("Page \(book.currentPage)", value: $book.currentPage, in: 0...max(0, book.pageCount))
                }
            }
            Section {
                Button(actionTitle) {
                    repository.update(book)
                    _ = sessionCoordinator.start(
                        book: book,
                        origin: .bookDetail,
                        reread: book.status == .finished
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("book-detail-reading-action")
            }
            .listRowBackground(Color.clear)
        }
        .appBackground()
        .navigationTitle("Book Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: book.status) { _, status in
            if status == .finished { book.currentPage = book.pageCount }
            repository.update(book)
        }
        .onChange(of: book.currentPage) { _, _ in repository.update(book) }
        .onDisappear { repository.update(book) }
    }
}
