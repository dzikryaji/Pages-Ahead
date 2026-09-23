import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    @Bindable var sessionCoordinator: ReadingSessionCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let catalog: BookCatalogSearching
    let catalogCache: CatalogSearchCaching
    @State private var showingAddBook = false
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("Library")
                        .font(AppTypography.displayLarge)
                    Spacer()
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(12)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Add Book")
                }
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if !viewModel.books.isEmpty {
                        searchField
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    libraryContent
                }
                .padding(.top, 12)
                .padding(.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(searchAnimation, value: viewModel.books.isEmpty)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .appBackground()
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
            .onChange(of: viewModel.books.isEmpty) { _, isEmpty in
                guard isEmpty else { return }
                cancelSearch()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)
                    .accessibilityHidden(true)

                TextField("Title or author", text: $viewModel.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .onSubmit { isSearchFieldFocused = false }

                if !viewModel.query.isEmpty {
                    Button("Clear Search", systemImage: "xmark.circle.fill") {
                        viewModel.query = ""
                        isSearchFieldFocused = true
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .frame(minHeight: 44)
            .padding(.leading, 14)
            .padding(.trailing, viewModel.query.isEmpty ? 14 : 0)
            .contentShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .onTapGesture { isSearchFieldFocused = true }

            if isSearching {
                Button {
                    cancelSearch()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(12)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Cancel Search")
                .transition(
                    .move(edge: .trailing)
                        .combined(with: .opacity)
                )
            }
        }
        .padding(.horizontal)
        .animation(searchAnimation, value: isSearching)
        .animation(searchAnimation, value: viewModel.query.isEmpty)
        .onChange(of: isSearchFieldFocused) { _, focused in
            guard focused, !isSearching else { return }
            withAnimation(searchAnimation) {
                isSearching = true
            }
        }
    }

    private var searchAnimation: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.3, extraBounce: 0)
    }

    private func cancelSearch() {
        isSearchFieldFocused = false
        withAnimation(searchAnimation) {
            viewModel.query = ""
            isSearching = false
        }
    }

    @ViewBuilder private var libraryContent: some View {
        if viewModel.books.isEmpty {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                AppContentUnavailableView(
                    title: "Your library is ready",
                    systemName: "books.vertical",
                    description:
                        "Add the book you're reading to get personalized windows and track progress."
                )
                Button("Add Your First Book", systemImage: "plus") {
                    showingAddBook = true
                }
                .buttonStyle(PrimaryButtonStyle())
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredBooks.isEmpty {
            VStack {
                Spacer(minLength: 0)
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text(
                        "No books found for \(viewModel.query)."
                    )
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
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
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder private func bookSection(_ title: String, books: [Book])
        -> some View
    {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(AppTypography.displaySection)

                ForEach(books) { book in
                    NavigationLink(value: book) {
                        BookRow(book: book, systemImage: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
