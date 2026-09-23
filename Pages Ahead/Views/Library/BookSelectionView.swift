import SwiftUI

struct BookSelectionView: View {
    @State private var search: CatalogSearchViewModel
    @State private var selectedBooks: [Book]
    @Environment(\.dismiss) private var dismiss
    let onConfirm: ([Book]) -> Void

    init(
        catalog: BookCatalogSearching,
        cache: CatalogSearchCaching,
        initialSelection: [Book],
        onConfirm: @escaping ([Book]) -> Void
    ) {
        _search = State(
            initialValue: CatalogSearchViewModel(catalog: catalog, cache: cache)
        )
        _selectedBooks = State(initialValue: initialSelection)
        self.onConfirm = onConfirm
    }

    var body: some View {
        @Bindable var search = search
        NavigationStack {
            VStack(spacing: 12) {
                content
            }
            .searchable(
                text: $search.query,
                placement: SearchFieldPlacement.toolbar,
                prompt: "Title, author, or ISBN"
            )
            .appBackground()
            .navigationTitle("Find Your Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Selected Books", systemImage: "plus") {
                        onConfirm(selectedBooks)
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedBooks.isEmpty)
                }
            }
            .onChange(of: search.query) { _, query in
                search.queryChanged(to: query)
            }
        }
        .presentationDetents([.large])
        .onDisappear(perform: search.cancelSearch)
    }

    @ViewBuilder private var content: some View {
        switch search.state {
        case .idle:
            if selectedBooks.isEmpty {
                ContentUnavailableView(
                    "Find your books",
                    systemImage: "books.vertical",
                    description: Text("Search and select one or more books.")
                )
            } else {
                bookList(selectedBooks)
            }
        case .loading:
            ProgressView("Searching catalog…").frame(maxWidth: .infinity, maxHeight: .infinity,  alignment: .center)
        case .failed(let message):
            ContentUnavailableView(
                "Search failed",
                systemImage: "wifi.exclamationmark",
                description: Text(message)
            )
        case .loaded(let books):
            if books.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try another title, author, or ISBN.")
                )
            } else {
                bookList(books)
            }
        }
    }

    private func bookList(_ books: [Book]) -> some View {
        let resultQuery = search.query
        return ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(books) { book in
                    let selected = selectedBooks.contains(where: {
                        $0.id == book.id
                    })
                    Button {
                        toggle(book)
                    } label: {
                        BookRow(
                            book: book,
                            systemImage: selected
                                ? "checkmark.circle.fill" : "circle"
                        ) { data in
                            coverLoaded(
                                data,
                                for: book.id,
                                resultQuery: resultQuery
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
    }

    private func toggle(_ book: Book) {
        if let index = selectedBooks.firstIndex(where: { $0.id == book.id }) {
            selectedBooks.remove(at: index)
        } else {
            selectedBooks.append(book)
        }
    }

    private func coverLoaded(
        _ data: Data,
        for bookID: UUID,
        resultQuery: String
    ) {
        search.coverLoaded(data, for: bookID, query: resultQuery)
        guard let index = selectedBooks.firstIndex(where: { $0.id == bookID }),
            selectedBooks[index].coverImageData == nil
        else { return }
        selectedBooks[index].coverImageData = data
    }
}
