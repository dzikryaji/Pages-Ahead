import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    @Bindable var sessionCoordinator: ReadingSessionCoordinator
    let catalog: BookCatalogSearching
    let catalogCache: CatalogSearchCaching
    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.filteredBooks.isEmpty {
                    if viewModel.query.isEmpty {
                        VStack(spacing: 14) {
                            AppContentUnavailableView(
                                title: "Your library is ready",
                                systemName: "books.vertical",
                                description: "Add the book you're reading to get personalized windows and track progress."
                            )
                            Button("Add Your First Book", systemImage: "plus") {
                                showingAddBook = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "magnifyingglass",
                            description: Text("No books found for \(viewModel.query).")
                        )
                            .listRowBackground(Color.clear)
                    }
                } else {
                    bookSection(
                        "Currently Reading",
                        books: viewModel.books(with: .reading)
                    )
                    bookSection(
                        "Saved Books",
                        books: viewModel.books(with: .saved)
                    )
                    bookSection(
                        "Finished",
                        books: viewModel.books(with: .finished)
                    )
                }
            }
            .appBackground()
            .navigationTitle("Library")
            .searchable(text: $viewModel.query, prompt: "Title or author")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Book", systemImage: "plus") {
                        showingAddBook = true
                    }
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(
                    book: book,
                    repository: viewModel,
                    sessionCoordinator: sessionCoordinator
                )
            }
            .sheet(isPresented: $showingAddBook, onDismiss: viewModel.reload) {
                BookSelectionView(
                    catalog: catalog,
                    cache: catalogCache,
                    initialSelection: []
                ) { books in books.forEach(viewModel.add) }
            }
            .onAppear(perform: viewModel.reload)
        }
    }

    @ViewBuilder private func bookSection(_ title: String, books: [Book])
        -> some View
    {
        if !books.isEmpty {
            Section(title) {
                ForEach(books) { book in
                    NavigationLink(value: book) { BookRow(book: book) }
                }
            }
        }
    }
}

