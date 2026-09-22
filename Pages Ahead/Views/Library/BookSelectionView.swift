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
        _search = State(initialValue: CatalogSearchViewModel(catalog: catalog, cache: cache))
        _selectedBooks = State(initialValue: initialSelection)
        self.onConfirm = onConfirm
    }

    var body: some View {
        @Bindable var search = search
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Title, author, or ISBN", text: $search.query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("book-selection-search")
                    if !search.query.isEmpty {
                        Button("Clear", systemImage: "xmark.circle.fill") { search.query = "" }
                            .labelStyle(.iconOnly)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accent) }

                content
            }
            .padding(.horizontal)
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
            .onChange(of: search.query) { _, query in search.queryChanged(to: query) }
        }
        .presentationDetents([.large])
        .onDisappear(perform: search.cancelSearch)
    }

    @ViewBuilder private var content: some View {
        switch search.state {
        case .idle:
            if selectedBooks.isEmpty {
                ContentUnavailableView("Find your books", systemImage: "books.vertical", description: Text("Search and select one or more books."))
            } else {
                bookList(selectedBooks)
            }
        case .loading:
            ProgressView("Searching catalog…").frame(maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView("Search failed", systemImage: "wifi.exclamationmark", description: Text(message))
        case .loaded(let books):
            if books.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Try another title, author, or ISBN."))
            } else {
                bookList(books)
            }
        }
    }

    private func bookList(_ books: [Book]) -> some View {
        let resultQuery = search.query
        return List(books) { book in
            let selected = selectedBooks.contains(where: { $0.id == book.id })
            Button { toggle(book) } label: {
                HStack(spacing: 12) {
                    BookRow(book: book) { data in
                        coverLoaded(
                            data,
                            for: book.id,
                            resultQuery: resultQuery
                        )
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? AppTheme.accent : AppTheme.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
              selectedBooks[index].coverImageData == nil else { return }
        selectedBooks[index].coverImageData = data
    }
}
