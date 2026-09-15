import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    let activityRepository: ActivityRepository
    let personalization: PersonalizationRepository
    let sessionProgress: SessionProgressRepository
    let readingActivity: ReadingActivityManaging
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
                    activityRepository: activityRepository,
                    personalization: personalization,
                    sessionProgress: sessionProgress,
                    readingActivity: readingActivity
                )
            }
            .sheet(isPresented: $showingAddBook, onDismiss: viewModel.reload) {
                AddBookView(
                    library: viewModel,
                    catalog: catalog,
                    cache: catalogCache
                )
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

struct AddBookView: View {
    let library: LibraryViewModel
    @State private var viewModel: CatalogSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool
    private let requiresBook: Bool
    private let onAdded: () -> Void
    private let onBack: () -> Void
    private let focusSearchOnAppear: Bool

    private var showsScreenBackground: Bool {
        guard requiresBook else { return false }
        if case .loading = viewModel.state { return false }
        return true
    }

    init(
        library: LibraryViewModel,
        catalog: BookCatalogSearching,
        cache: CatalogSearchCaching,
        requiresBook: Bool = false,
        initialSearch: CatalogSearchInitialState? = nil,
        focusSearchOnAppear: Bool = true,
        onAdded: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.library = library
        self.requiresBook = requiresBook
        self.onAdded = onAdded
        self.onBack = onBack
        self.focusSearchOnAppear = focusSearchOnAppear
        let viewModel = CatalogSearchViewModel(catalog: catalog, cache: cache)
        if let initialSearch {
            viewModel.query = initialSearch.query
            viewModel.state = initialSearch.state
            viewModel.selected = initialSearch.selected
            viewModel.isRefreshing = initialSearch.isRefreshing
        }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    if requiresBook {
                        Text("Step 1 of 2")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField(
                            "Title, author, or ISBN",
                            text: $viewModel.query
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($isSearchFocused)
                        .accessibilityIdentifier("book-catalog-search")
                        if !viewModel.query.isEmpty {
                            Button("Clear", systemImage: "xmark.circle.fill") {
                                viewModel.query = ""
                            }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(
                        AppTheme.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.border.opacity(0.5), lineWidth: 1)
                    }
                    Text("Search for a book you own or are currently reading.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()

                Group {
                    switch viewModel.state {
                    case .idle:
                        AppContentUnavailableView(
                            title: "Find your book",
                            systemName: "text.book.closed",
                            description: "Enter a title, author, or ISBN to search the catalog."
                        )
                        .padding()
                    case .loading:
                        ProgressView("Searching catalog…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failed(let message):
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "Search failed",
                                systemImage: "wifi.exclamationmark",
                                description: Text(message)
                            )
                            Button("Try Again", systemImage: "arrow.clockwise") {
                                viewModel.queryChanged(to: viewModel.query)
                            }
                            .buttonStyle(.bordered)
                        }
                    case .loaded(let results):
                        if results.isEmpty {
                            ContentUnavailableView(
                                "No Results",
                                systemImage: "magnifyingglass",
                                description: Text("No books found for \(viewModel.query).")
                            )
                        } else {
                            List(results) { book in
                                Button {
                                    viewModel.selected = book
                                } label: {
                                    HStack {
                                        BookRow(book: book) { data in
                                            viewModel.coverLoaded(
                                                data,
                                                for: book.id
                                            )
                                        }
                                        Spacer()
                                        if viewModel.selected?.id == book.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 22))
                                            .foregroundStyle(AppTheme.ink)
                                        }
                                    }
                                }.buttonStyle(.plain)
                                    .accessibilityAddTraits(
                                        viewModel.selected?.id == book.id ? .isSelected : []
                                    )
                            }
                        }
                    }
                }
            }
            .appBackground(enabled: showsScreenBackground)
            .onChange(of: viewModel.query) { _, query in
                viewModel.queryChanged(to: query)
            }
            .overlay(alignment: .top) {
                if viewModel.isRefreshing {
                    ProgressView("Updating cached results…")
                        .padding(10).background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let selected = viewModel.selected {
                    Button(action: addSelectedBook) {
                        Text(
                            requiresBook
                                ? "Continue with \(selected.title)"
                                : "Add \(selected.title)"
                        )
                        .lineLimit(1)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                    .background(.bar)
                }
            }
            .navigationTitle(requiresBook ? "Add your first book" : "Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if requiresBook {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back", systemImage: "chevron.left", action: onBack)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .task {
            guard focusSearchOnAppear else { return }
            await Task.yield()
            isSearchFocused = true
        }
        .onDisappear(perform: viewModel.cancelSearch)
    }

    private func addSelectedBook() {
        guard let selected = viewModel.selected else { return }
        library.add(selected)
        if requiresBook { onAdded() } else { dismiss() }
    }
}

struct BookDetailView: View {
    @State private var book: Book
    let repository: LibraryViewModel
    let activityRepository: ActivityRepository
    let personalization: PersonalizationRepository
    let sessionProgress: SessionProgressRepository
    let readingActivity: ReadingActivityManaging
    @State private var showingSession = false

    init(
        book: Book,
        repository: LibraryViewModel,
        activityRepository: ActivityRepository,
        personalization: PersonalizationRepository,
        sessionProgress: SessionProgressRepository,
        readingActivity: ReadingActivityManaging
    ) {
        _book = State(initialValue: book)
        self.repository = repository
        self.activityRepository = activityRepository
        self.personalization = personalization
        self.sessionProgress = sessionProgress
        self.readingActivity = readingActivity
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    BookCover(book: book, width: 116)
                    Text(book.title).font(AppTypography.displayTitle)
                        .tracking(0.4)
                        .multilineTextAlignment(.center)
                    Text(book.author).font(AppTypography.body).foregroundStyle(AppTheme.secondaryText)
                }.frame(maxWidth: .infinity).padding(.vertical)
            }
            Section("Book information") {
                LabeledContent("Edition", value: book.edition)
                LabeledContent("ISBN", value: book.isbn)
                LabeledContent("Length", value: "\(book.pageCount) pages")
                Picker("Status", selection: $book.status) {
                    ForEach(ReadingStatus.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
            }
            if book.status == .reading {
                Section("Progress") {
                    ProgressView(value: book.progress)
                    Stepper(
                        "Page \(book.currentPage)",
                        value: $book.currentPage,
                        in: 0...book.pageCount
                    )
                }
            }
            Section {
                Button(
                    book.status == .reading
                        ? "Continue Reading" : "Start Reading"
                ) { showingSession = true }.buttonStyle(PrimaryButtonStyle())
            }.listRowBackground(Color.clear)
        }
        .appBackground()
        .navigationTitle("Book Detail").navigationBarTitleDisplayMode(.inline)
        .onDisappear { repository.update(book) }
        .fullScreenCover(isPresented: $showingSession) {
            ReadingSessionView(
                book: book,
                durationMinutes: 30,
                repository: activityRepository,
                personalization: personalization,
                progressStore: sessionProgress,
                activityManager: readingActivity
            ) { pages in
                book.currentPage = min(book.pageCount, book.currentPage + pages)
                book.status =
                    book.currentPage >= book.pageCount && book.pageCount > 0
                    ? .finished : .reading
                repository.update(book)
            }
        }
    }
}

struct ReadingSessionView: View {
    let book: Book
    let durationMinutes: Int
    let repository: ActivityRepository
    let personalization: PersonalizationRepository
    let onPagesRead: (Int) -> Void
    let weather: String?
    let place: String?
    @State private var viewModel: ReadingSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingComplete = false
    @State private var showingFocusSetup = false
    @State private var confirmingClose = false

    init(
        book: Book,
        durationMinutes: Int,
        repository: ActivityRepository,
        personalization: PersonalizationRepository,
        progressStore: SessionProgressRepository,
        activityManager: ReadingActivityManaging,
        weather: String? = nil,
        place: String? = nil,
        confirmingClose: Bool = false,
        onPagesRead: @escaping (Int) -> Void
    ) {
        self.book = book
        self.durationMinutes = durationMinutes
        self.repository = repository
        self.personalization = personalization
        self.weather = weather
        self.place = place
        self.onPagesRead = onPagesRead
        _confirmingClose = State(initialValue: confirmingClose)
        _viewModel = State(
            initialValue: ReadingSessionViewModel(
                book: book,
                durationMinutes: durationMinutes,
                store: progressStore,
                activityManager: activityManager
            )
        )
    }

    private var timeText: String {
        String(
            format: "%02d:%02d",
            viewModel.remainingSeconds / 60,
            viewModel.remainingSeconds % 60
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if showingComplete {
                    completionContent
                } else {
                    sessionContent
                }
            }
            .navigationDestination(isPresented: $showingFocusSetup) {
                ReadingFocusShortcutSetupView()
            }
        }
    }

    private var sessionContent: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                HStack {
                    AppSymbolLabel(
                        title: "Reading session",
                        systemName: "book.pages.fill",
                        symbolSize: 18
                    )
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button {
                        showingFocusSetup = true
                    } label: {
                        AppSymbol(systemName: "moon.fill", size: 20)
                    }
                    .accessibilityLabel("Focus")
                    .buttonStyle(.glass)
                    Button("Close", systemImage: "xmark") { confirmingClose = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                }
            }.padding()
            Spacer()
            BookCover(book: book, width: 120)
            VStack(spacing: 6) {
                Text(book.title).font(AppTypography.displayTitle).tracking(0.4).multilineTextAlignment(
                    .center
                )
                Text("Current chapter").font(AppTypography.body).foregroundStyle(AppTheme.secondaryText)
            }
            Text(timeText)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(
                    "\(viewModel.remainingSeconds / 60) minutes, \(viewModel.remainingSeconds % 60) seconds"
                )
            Text(viewModel.isPaused ? "Paused" : "Time remaining")
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    Task { await viewModel.togglePause() }
                } label: {
                    Label(
                        viewModel.isPaused ? "Resume" : "Pause",
                        systemImage: viewModel.isPaused ? "play.fill" : "pause.fill"
                    ).frame(maxWidth: .infinity, minHeight: 50)
                }.buttonStyle(.bordered)
                Button {
                    Task {
                        await viewModel.endLiveActivity()
                        showingComplete = true
                    }
                } label: {
                    Label("End Session", systemImage: "stop.fill").frame(
                        maxWidth: .infinity,
                        minHeight: 50
                    )
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .appBackground()

        .task {
            await viewModel.startLiveActivity()
            while !Task.isCancelled && viewModel.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                viewModel.tick()
            }
            if viewModel.remainingSeconds == 0 {
                await viewModel.endLiveActivity()
                showingComplete = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { viewModel.persist() }
        }
        .onDisappear {
            guard !showingFocusSetup && !showingComplete else { return }
            Task { await viewModel.leaveSession() }
        }
        .alert("End this session?", isPresented: $confirmingClose) {
            Button("Keep Reading", role: .cancel) { }
            Button("End Without Saving", role: .destructive) {
                Task {
                    await viewModel.leaveSession()
                    dismiss()
                }
            }
        } message: {
            Text("The timer and Live Activity will stop. This session will not be added to Activity.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var completionContent: some View {
        SessionCompleteView(
            book: book,
            minutes: max(1, viewModel.elapsedSeconds / 60),
            weather: weather,
            place: place,
            repository: repository,
            personalization: personalization,
            onPagesRead: onPagesRead
        ) {
            Task {
                await viewModel.finish()
                dismiss()
            }
        }
    }
}

struct ReadingFocusShortcutSetupView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Label(
                    "Pages Ahead already provides a Start Reading action in Shortcuts.",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(AppTheme.ink)
            }
            Section("Create your shortcut") {
                setupStep(1, "Add Set Focus and choose your Reading Focus.")
                setupStep(
                    2,
                    "Set it to turn on for your preferred duration."
                )
                setupStep(3, "Add Start Reading from Pages Ahead.")
                setupStep(4, "Name it Pages Ahead Reading Focus.")
            }
            Section {
                Button("Open Shortcut Editor", systemImage: "square.grid.2x2") {
                    openURL(URL(string: "shortcuts://create-shortcut")!)
                }
                .buttonStyle(PrimaryButtonStyle())
            } footer: {
                Text(
                    "iOS requires you to approve shortcuts that change Focus. Pages Ahead cannot install this automation silently."
                )
            }
        }
        .navigationTitle("Reading Focus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func setupStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 24, height: 24).background(
                    AppTheme.ink,
                    in: Circle()
                )
            Text(text)
        }
    }
}

struct SessionCompleteView: View {
    let book: Book
    let minutes: Int
    let weather: String?
    let place: String?
    let repository: ActivityRepository
    let personalization: PersonalizationRepository
    let onPagesRead: (Int) -> Void
    let finish: () -> Void
    @State private var pages: Int
    @State private var feedback = "Calm"
    @State private var note = ""

    init(
        book: Book,
        minutes: Int,
        weather: String?,
        place: String?,
        repository: ActivityRepository,
        personalization: PersonalizationRepository,
        onPagesRead: @escaping (Int) -> Void,
        finish: @escaping () -> Void
    ) {
        self.book = book
        self.minutes = minutes
        self.weather = weather
        self.place = place
        self.repository = repository
        self.personalization = personalization
        self.onPagesRead = onPagesRead
        self.finish = finish
        _pages = State(initialValue: min(10, max(0, book.pageCount - book.currentPage)))
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(AppTheme.ink)
                    Text("Reading complete").font(AppTypography.displayTitle).tracking(0.4)
                    Text("A quiet step forward.").foregroundStyle(
                        .secondary
                    )
                }.frame(maxWidth: .infinity).padding()
            }
            Section("Session") {
                LabeledContent("Minutes", value: "\(minutes)")
                Stepper(
                    "\(pages) pages",
                    value: $pages,
                    in: 0...max(0, book.pageCount - book.currentPage)
                )
            }
            Section("How did it feel?") {
                Picker("Feedback", selection: $feedback) {
                    ForEach(
                        ["Calm", "Focused", "Restless", "Tired"],
                        id: \.self
                    ) { Text($0) }
                }.pickerStyle(.segmented)
                TextField("Optional note", text: $note, axis: .vertical)
            }
            Section {
                Button("Save Session") { save() }.buttonStyle(
                    PrimaryButtonStyle()
                )
            }.listRowBackground(Color.clear)
        }
        .navigationTitle("Session summary").navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar(.visible, for: .navigationBar)
        .interactiveDismissDisabled()
    }

    private func save() {
        repository.save(
            ReadingRecord(
                id: UUID(),
                bookID: book.id,
                date: .now,
                minutes: minutes,
                pages: pages,
                weather: weather ?? "Not recorded",
                place: place ?? "Not recorded",
                feedback: feedback,
                note: note
            )
        )
        onPagesRead(pages)
        personalization.record(
            PersonalizationEvent(
                id: UUID(),
                kind: .completed,
                date: .now,
                hour: Calendar.current.component(.hour, from: .now),
                temperature: nil,
                place: place ?? "Not recorded",
                reason: feedback
            )
        )
        finish()
    }
}

#Preview("Library") {
    let container = AppContainer.preview
    LibraryView(
        viewModel: LibraryViewModel(repository: container.library),
        activityRepository: container.activity,
        personalization: container.personalization,
        sessionProgress: container.sessionProgress,
        readingActivity: container.readingActivity,
        catalog: container.catalog,
        catalogCache: container.catalogCache
    )
}

#Preview("Add Book") {
    let container = AppContainer.preview
    AddBookView(
        library: LibraryViewModel(repository: container.library),
        catalog: container.catalog,
        cache: container.catalogCache
    )
}

#Preview("Book Detail") {
    let container = AppContainer.preview
    NavigationStack {
        BookDetailView(
            book: SampleData.books[0],
            repository: LibraryViewModel(repository: container.library),
            activityRepository: container.activity,
            personalization: container.personalization,
            sessionProgress: container.sessionProgress,
            readingActivity: container.readingActivity
        )
    }
}

#Preview("Reading Session") {
    let container = AppContainer.preview
    ReadingSessionView(
        book: SampleData.books[0],
        durationMinutes: 30,
        repository: container.activity,
        personalization: container.personalization,
        progressStore: container.sessionProgress,
        activityManager: container.readingActivity,
        weather: "Light rain, 24°",
        place: "Indoors",
        onPagesRead: { _ in }
    )
}

#Preview("Session Complete") {
    let container = AppContainer.preview
    NavigationStack {
        SessionCompleteView(
            book: SampleData.books[0],
            minutes: 30,
            weather: "Light rain, 24°",
            place: "Indoors",
            repository: container.activity,
            personalization: container.personalization,
            onPagesRead: { _ in },
            finish: {}
        )
    }
}

#Preview("Reading Focus Shortcut Setup") {
    NavigationStack { ReadingFocusShortcutSetupView() }
}
