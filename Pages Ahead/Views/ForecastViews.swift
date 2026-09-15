import SwiftUI
import TipKit

struct ForecastHomeView: View {
    @Bindable var viewModel: ForecastViewModel
    let activityRepository: ActivityRepository
    let sessionProgress: SessionProgressRepository
    let readingActivity: ReadingActivityManaging
    let notifications: NotificationScheduling
    let calendarWriter: CalendarEventWriting
    let settings: SettingsRepository
    let personalization: PersonalizationRepository
    var onReplayOnboarding: () -> Void = {}
    var loadsOnAppear = true
    @State private var showingSettings = false
    @State private var activePlannedSession: PlannedSession?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if viewModel.isLoading { ProgressView("Checking forecast…").frame(maxWidth: .infinity).padding() }
                    if let error = viewModel.loadError {
                        VStack(spacing: 12) {
                            AppContentUnavailableView(
                                title: "Forecast unavailable",
                                systemName: "cloud.bolt",
                                description: error
                            )
                            Button("Try Again", systemImage: "arrow.clockwise") {
                                Task { await viewModel.reload() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                    } else if !viewModel.isLoading && viewModel.recommendedBook == nil {
                        AppContentUnavailableView(
                            title: "Add a current book",
                            systemName: "books.vertical",
                            description: "Choose a book in Library to create reading windows."
                        )
                    }
                    if let window = viewModel.windows.first, let book = viewModel.book(id: window.bookID) {
                        NavigationLink(value: window) { HeroWindowCard(window: window, book: book) }.buttonStyle(.plain)
                        Button("Plan Reading") {
                            viewModel.editingSession = nil
                            viewModel.planningWindow = window
                            viewModel.showingPlanner = true
                        }.buttonStyle(PrimaryButtonStyle())
                        Label(
                            "Chosen from your book, schedule, preferences, and local weather.",
                            systemImage: "slider.horizontal.3"
                        )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    if let session = viewModel.plannedSession, let book = viewModel.book(id: session.bookID) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PLANNED").font(AppTypography.displayEyebrow).tracking(0.8).foregroundStyle(AppTheme.ink)
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.start, format: .dateTime.weekday().hour().minute()).font(.headline)
                                    Text("\(book.title) · \(session.durationMinutes) min").font(AppTypography.subheadline).foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Button("Start") {
                                    activePlannedSession = session
                                }
                                .buttonStyle(.borderedProminent)
                                Menu {
                                    Button("Edit", systemImage: "pencil") {
                                        viewModel.editingSession = session
                                        viewModel.planningWindow = viewModel.windows.first { $0.start == session.start }
                                        viewModel.showingPlanner = true
                                    }
                                    Button("Cancel Session", systemImage: "xmark", role: .destructive) {
                                        Task { await cancel(session) }
                                    }
                                } label: {
                                    Label("Session actions", systemImage: "ellipsis.circle")
                                }
                                .labelStyle(.iconOnly)
                            }
                        }
                        .padding().appCard()
                    }
                    Text("Coming up").font(AppTypography.displaySection).tracking(0.5)
                    ForEach(viewModel.windows.dropFirst()) { window in
                        NavigationLink(value: window) {
                            UpcomingWindowRow(window: window)
                        }.buttonStyle(.plain)
                    }
                    Label(
                        "Forecast suggestions never override your schedule.",
                        systemImage: "calendar.badge.checkmark"
                    )
                        .font(AppTypography.caption).foregroundStyle(AppTheme.secondaryText).padding(.top, 6)
                }.padding()
            }
            .appBackground(enabled: !viewModel.isLoading)
            .task {
                guard loadsOnAppear else { return }
                await viewModel.reload()
            }
            .navigationTitle("Pages Ahead")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showingSettings = true
                    }
                }
            }
            .navigationDestination(for: ReadingWindow.self) { window in
                if let book = viewModel.book(id: window.bookID) {
                    ForecastDetailView(window: window, book: book, allBooks: viewModel.books,
                        plan: {
                            viewModel.editingSession = nil
                            viewModel.planningWindow = window
                            viewModel.showingPlanner = true
                        },
                        reject: { viewModel.reject(window, reason: $0) },
                        chooseBook: { chosen in Task { await viewModel.selectBook(chosen) } })
                }
            }
            .sheet(isPresented: $viewModel.showingPlanner) {
                if let window = viewModel.planningWindow ?? viewModel.windows.first,
                   let book = viewModel.book(id: window.bookID) ?? viewModel.recommendedBook {
                    PlanSessionView(window: window, book: book, existingSession: viewModel.editingSession,
                                    defaultReminder: settings.preferences.remindersEnabled,
                                    reminderLeadMinutes: settings.preferences.reminderLeadTime,
                                    notifications: notifications, calendarWriter: calendarWriter,
                                    onPlan: viewModel.plan, onNotice: { viewModel.notice = $0 })
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView(
                        settings: settings,
                        personalization: personalization,
                        onReplayOnboarding: onReplayOnboarding
                    )
                }
            }
            .fullScreenCover(item: $activePlannedSession) { session in
                if let book = viewModel.book(id: session.bookID) {
                    let matchingWindow = viewModel.windows.first {
                        $0.start == session.start
                    }
                    ReadingSessionView(
                        book: book,
                        durationMinutes: session.durationMinutes,
                        repository: activityRepository,
                        personalization: viewModel.personalizationRepository,
                        progressStore: sessionProgress,
                        activityManager: readingActivity,
                        weather: matchingWindow.map {
                            "\($0.condition), \($0.temperature)°"
                        },
                        place: session.place,
                        onPagesRead: {
                            viewModel.addProgress($0, to: book)
                            viewModel.complete(session)
                        }
                    )
                }
            }
            .alert("Action needed", isPresented: Binding(get: { viewModel.notice != nil }, set: { if !$0 { viewModel.notice = nil } })) {
                Button("OK", role: .cancel) { viewModel.notice = nil }
            } message: { Text(viewModel.notice ?? "") }
        }
    }

    private func cancel(_ session: PlannedSession) async {
        if let eventID = session.calendarEventID {
            do { try calendarWriter.delete(eventID: eventID) }
            catch { viewModel.notice = "Calendar event could not be removed. Session was kept so you can retry."; return }
        }
        notifications.cancel(sessionID: session.id)
        viewModel.cancel(session)
    }
}

private struct HeroWindowCard: View {
    let window: ReadingWindow
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("NEXT BEST WINDOW").font(AppTypography.displayEyebrow).tracking(0.9)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
            }
                .foregroundStyle(AppTheme.secondaryText)
            if window.isCached {
                Label("Cached forecast", systemImage: "clock.arrow.circlepath")
                .font(.caption.bold())
            }
            Text(window.weatherSource.rawValue).font(AppTypography.caption).foregroundStyle(AppTheme.secondaryText)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(window.start.readingDay).font(.title3.weight(.medium))
                    Text(window.start.readingTime).font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("\(window.durationMinutes) minutes · \(window.place)").font(.subheadline)
                }
                Spacer()
                VStack(spacing: 5) {
                    AppSymbol(systemName: window.weatherSymbol, size: 40)
                    Text("\(window.temperature)°").font(.title2.bold())
                    Text(window.condition).font(.caption)
                }
            }
            HStack(spacing: 12) {
                BookCover(book: book, width: 44)
                VStack(alignment: .leading, spacing: 2) { Text("Continue reading").font(.caption); Text(book.title).font(.headline).lineLimit(2) }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(AppTheme.ink)
        .padding(.vertical, 20)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.5))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border.opacity(0.5))
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UpcomingWindowRow: View {
    let window: ReadingWindow
    var body: some View {
        HStack(spacing: 14) {
            AppSymbol(systemName: window.weatherSymbol, size: 32)
                .foregroundStyle(AppTheme.ink)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(window.start.readingDay).font(.headline)
                Text("\(window.start.readingTime) · \(window.durationMinutes) min").font(AppTypography.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text("\(window.temperature)°").font(.title3.bold())
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .padding().appCard(cornerRadius: 16)
    }
}

struct ForecastDetailView: View {
    let window: ReadingWindow
    let allBooks: [Book]
    let plan: () -> Void
    let reject: (String?) -> Void
    let chooseBook: (Book) -> Void
    @State private var book: Book
    @State private var showingAlternatives = false
    @State private var showingFeedback = false
    private let feedbackTip = RejectionFeedbackTip()
    private let showsFeedbackTip: Bool
    private let startsAtFeedbackActions: Bool

    init(window: ReadingWindow, book: Book, allBooks: [Book], showsFeedbackTip: Bool = true, feedbackInitiallyPresented: Bool = false, startsAtFeedbackActions: Bool = false, plan: @escaping () -> Void, reject: @escaping (String?) -> Void, chooseBook: @escaping (Book) -> Void) {
        self.window = window; self.allBooks = allBooks; self.plan = plan; self.reject = reject; self.chooseBook = chooseBook
        self.showsFeedbackTip = showsFeedbackTip
        self.startsAtFeedbackActions = startsAtFeedbackActions
        _book = State(initialValue: book)
        _showingFeedback = State(initialValue: feedbackInitiallyPresented)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AppSymbol(systemName: window.weatherSymbol, size: 58)
                        .foregroundStyle(AppTheme.ink)
                    Text(window.start.readingTime).font(.largeTitle.bold())
                    Text("\(window.start.readingDay) · \(window.durationMinutes) minutes").foregroundStyle(.secondary)
                    if window.isCached {
                        Label("Cached forecast", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    LabeledContent("Weather source", value: window.weatherSource.rawValue).font(.caption)
                    HStack {
                        AppSymbolLabel(
                            title: "\(window.temperature)°",
                            systemName: "thermometer.medium"
                        )
                        Spacer()
                        AppSymbolLabel(title: window.condition, systemName: "cloud")
                    }
                }.frame(maxWidth: .infinity).padding(.vertical)
            }
            Section("Why it fits") {
                Label(window.fitReason, systemImage: "sparkles")
            }
            Section("Recommended book") {
                BookRow(book: book)
                Button("Book Alternatives") { showingAlternatives = true }
            }
            Section {
                Button("Plan Reading", action: plan).buttonStyle(PrimaryButtonStyle())
            }.listRowBackground(Color.clear)
            Section {
                if showsFeedbackTip {
                    TipView(feedbackTip, arrowEdge: .bottom)
                }
                Button("Not for Me") { showingFeedback = true }
                    .frame(maxWidth: .infinity, minHeight: 44)
            }.listRowBackground(Color.clear)
            Section {
                Label("Ranked on this device", systemImage: "iphone.gen3")
            }
            .foregroundStyle(.secondary)
        }
        .defaultScrollAnchor(startsAtFeedbackActions ? .bottom : .top)
        .appBackground()
        .navigationTitle("Reading window").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAlternatives) {
            BookAlternativesView(books: allBooks, selected: book) { chosen in
                book = chosen
                chooseBook(chosen)
            }
        }
        .confirmationDialog("What did not fit?", isPresented: $showingFeedback, titleVisibility: .visible) {
            Button("Timing") { submitRejection("Timing") }
            Button("Weather") { submitRejection("Weather") }
            Button("Book") { submitRejection("Book") }
            Button("No reason") { submitRejection(nil) }
        }
        .task {
            await RejectionFeedbackTip.forecastDetailViewed.donate()
        }
    }

    private func submitRejection(_ reason: String?) {
        feedbackTip.invalidate(reason: .actionPerformed)
        reject(reason)
    }
}

struct PlanSessionView: View {
    let window: ReadingWindow
    let book: Book
    let existingSession: PlannedSession?
    let defaultReminder: Bool
    let reminderLeadMinutes: Int
    let notifications: NotificationScheduling
    let calendarWriter: CalendarEventWriting
    let onPlan: (PlannedSession) -> Void
    let onNotice: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var duration: Int
    @State private var place: String
    @State private var reminder = true
    @State private var addToCalendar = false
    @State private var saveError: String?
    @State private var isSaving = false

    init(window: ReadingWindow, book: Book, existingSession: PlannedSession? = nil, defaultReminder: Bool, reminderLeadMinutes: Int, notifications: NotificationScheduling, calendarWriter: CalendarEventWriting, initialSaveError: String? = nil, onPlan: @escaping (PlannedSession) -> Void, onNotice: @escaping (String) -> Void) {
        self.window = window; self.book = book; self.existingSession = existingSession; self.defaultReminder = defaultReminder; self.reminderLeadMinutes = reminderLeadMinutes; self.notifications = notifications; self.calendarWriter = calendarWriter; self.onPlan = onPlan; self.onNotice = onNotice
        _start = State(initialValue: existingSession?.start ?? window.start)
        _duration = State(initialValue: existingSession?.durationMinutes ?? window.durationMinutes)
        _place = State(initialValue: existingSession?.place ?? window.place)
        _reminder = State(initialValue: existingSession?.reminderEnabled ?? defaultReminder)
        _addToCalendar = State(initialValue: existingSession?.calendarEnabled ?? false)
        _saveError = State(initialValue: initialSaveError)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") { DatePicker("Start", selection: $start); Stepper("\(duration) minutes", value: $duration, in: 10...120, step: 5) }
                Section("Reading") { BookRow(book: book); Picker("Place", selection: $place) { ForEach(["Indoors", "Outdoors", "Covered patio", "Café"], id: \.self) { Text($0) } } }
                Section("Optional") { Toggle("Reminder", isOn: $reminder); Toggle("Add to Calendar", isOn: $addToCalendar) }
                if let saveError { Section { Text(saveError).foregroundStyle(.red) } }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.white) } else { Text("Plan Reading") }
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(isSaving)
                }.listRowBackground(Color.clear)
            }
            .navigationTitle(existingSession == nil ? "Plan session" : "Edit session").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func save() async {
        isSaving = true; saveError = nil
        defer { isSaving = false }
        var session = PlannedSession(id: existingSession?.id ?? UUID(), start: start, durationMinutes: duration, place: place, bookID: book.id, reminderEnabled: reminder, calendarEnabled: addToCalendar, calendarEventID: existingSession?.calendarEventID)
        do {
            var notices: [String] = []
            if reminder {
                let scheduled = try await notifications.schedule(session: session, bookTitle: book.title, leadMinutes: reminderLeadMinutes)
                if !scheduled {
                    session.reminderEnabled = false
                    notices.append("Session saved without a reminder because notification access or timing was unavailable.")
                }
            } else { notifications.cancel(sessionID: session.id) }
            if addToCalendar {
                do { session.calendarEventID = try await calendarWriter.save(session: session, bookTitle: book.title, existingEventID: existingSession?.calendarEventID) }
                catch where existingSession?.calendarEventID == nil {
                    session.calendarEnabled = false
                    notices.append("Session saved without a Calendar event because Calendar access was unavailable.")
                }
            } else if let eventID = existingSession?.calendarEventID {
                try calendarWriter.delete(eventID: eventID)
                session.calendarEventID = nil
            }
            onPlan(session)
            if !notices.isEmpty { onNotice(notices.joined(separator: " ")) }
            dismiss()
        } catch { saveError = error.localizedDescription }
    }
}

struct BookAlternativesView: View {
    let books: [Book]
    let selected: Book
    let choose: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var choice: Book.ID

    init(books: [Book], selected: Book, choose: @escaping (Book) -> Void) { self.books = books; self.selected = selected; self.choose = choose; _choice = State(initialValue: selected.id) }
    var body: some View {
        NavigationStack {
            List(books) { book in
                Button { choice = book.id } label: {
                    HStack {
                        BookRow(book: book)
                        Spacer()
                        if choice == book.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.ink)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(choice == book.id ? .isSelected : [])
            }
            .navigationTitle("Book alternatives")
            .safeAreaInset(edge: .bottom) {
                Button("Choose Book") {
                    if let book = books.first(where: { $0.id == choice }) { choose(book) }
                    dismiss()
                }.buttonStyle(PrimaryButtonStyle()).padding().background(.bar)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

#Preview("Forecast Home") {
    let container = AppContainer.preview
    ForecastHomeView(
        viewModel: ForecastViewModel(library: container.library, repository: container.forecast,
                                     sessions: container.sessions, personalization: container.personalization),
        activityRepository: container.activity,
        sessionProgress: container.sessionProgress,
        readingActivity: container.readingActivity,
        notifications: container.notifications,
        calendarWriter: container.calendar,
        settings: container.settings,
        personalization: container.personalization
    )
}

#Preview("Hero Window Card") {
    HeroWindowCard(window: SampleData.windows(bookID: SampleData.books[0].id)[0], book: SampleData.books[0])
        .padding()
}

#Preview("Upcoming Window Row") {
    UpcomingWindowRow(window: SampleData.windows(bookID: SampleData.books[0].id)[1])
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Forecast Detail") {
    NavigationStack {
        ForecastDetailView(window: SampleData.windows(bookID: SampleData.books[0].id)[0],
                           book: SampleData.books[0], allBooks: SampleData.books,
                           plan: { }, reject: { _ in }, chooseBook: { _ in })
    }
}

#Preview("Plan Session") {
    let container = AppContainer.preview
    PlanSessionView(window: SampleData.windows(bookID: SampleData.books[0].id)[0],
                    book: SampleData.books[0], defaultReminder: true, reminderLeadMinutes: 10,
                    notifications: container.notifications, calendarWriter: container.calendar,
                    onPlan: { _ in }, onNotice: { _ in })
}

#Preview("Book Alternatives") {
    BookAlternativesView(books: SampleData.books, selected: SampleData.books[0], choose: { _ in })
}
