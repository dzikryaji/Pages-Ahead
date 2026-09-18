import SwiftUI
import TipKit
import UIKit

private struct PendingPlannedStart {
    let plan: ReadingPlan
    let book: Book
}

struct ReadingPlanView: View {
    @Bindable var viewModel: ReadingPlanViewModel
    @Bindable var planManager: ReadingPlanManager
    @Bindable var sessionCoordinator: ReadingSessionCoordinator
    let settings: SettingsRepository
    var onReplayOnboarding: () -> Void = {}
    var loadsOnAppear = true

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var showingSettings = false
    @State private var planToReplaceWith: ReadingWindow?
    @State private var showingReplacementAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingBookPicker = false
    @State private var pendingStart: PendingPlannedStart?
    @State private var showingOutsideWindowAlert = false
    private let permissionRecoveryTip = PermissionRecoveryTip()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    if let plan = planManager.current {
                        plannedSection(plan)
                    }
                    recommendationContent
                }
                .padding(.horizontal)
                .padding(.bottom, 28)
            }
            .appBackground(enabled: !viewModel.isLoading)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReadingWindow.self) { window in
                ReadingWindowDetailView(
                    window: window,
                    book: viewModel.recommendedBook,
                    allBooks: viewModel.books,
                    onPlan: { requestPlan(window) },
                    reject: { reason in
                        viewModel.reject(window, reason: reason)
                    },
                    chooseBook: { book in Task { await viewModel.selectBook(book) } }
                )
            }
            .navigationDestination(for: ReadingPlan.self) { plan in
                ReadingPlanDetailView(
                    plan: plan,
                    books: viewModel.books,
                    planManager: planManager,
                    sessionCoordinator: sessionCoordinator,
                    initiallySelected: viewModel.recommendedBook
                )
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView(
                        settings: settings,
                        personalization: viewModel.personalizationRepository,
                        onReplayOnboarding: onReplayOnboarding
                    )
                }
            }
            .sheet(isPresented: $showingBookPicker) {
                ReadingSessionBookPicker(
                    books: startableBooks,
                    initiallySelected: viewModel.recommendedBook,
                    onStart: prepareStart
                )
            }
            .alert("Replace your reading plan?", isPresented: $showingReplacementAlert) {
                Button("Replace Plan", role: .destructive) {
                    guard let window = planToReplaceWith else { return }
                    Task { await createPlan(window) }
                }
                Button("Cancel", role: .cancel) { planToReplaceWith = nil }
            } message: {
                Text("Your current plan, notification, and Calendar event will be replaced.")
            }
            .alert("Delete this plan?", isPresented: $showingDeleteAlert) {
                Button("Delete Plan", role: .destructive) {
                    Task { await planManager.deleteCurrent() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Its notification and Calendar event will also be removed.")
            }
            .alert("Start outside your planned time?", isPresented: $showingOutsideWindowAlert) {
                Button("Keep Plan") { startOutsideWindow(keepsPlan: true) }
                Button("Remove Plan", role: .destructive) {
                    Task {
                        guard await planManager.deleteCurrent() else { return }
                        startOutsideWindow(keepsPlan: false)
                    }
                }
                Button("Cancel", role: .cancel) { pendingStart = nil }
            } message: {
                Text("You can keep this plan for its original window or remove it before reading now.")
            }
            .alert(item: noticeBinding) { notice in
                switch notice {
                case .message(let message):
                    Alert(title: Text("Reading Plan"), message: Text(message), dismissButton: .default(Text("OK")))
                case .openSettings(let message):
                    Alert(
                        title: Text("Permission Needed"),
                        message: Text(message),
                        primaryButton: .default(Text("Open Settings")) {
                            openURL(URL(string: UIApplication.openSettingsURLString)!)
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .task {
                planManager.refresh()
                if loadsOnAppear { await viewModel.reload() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                planManager.refresh()
            }
            .onChange(of: sessionCoordinator.isPresented) { wasPresented, isPresented in
                if wasPresented && !isPresented {
                    planManager.refresh()
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("READING PLAN")
                    .font(AppTypography.displayLarge)
                    .tracking(0.5)
                Text("Find the right time. Read for as long as you like.")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Button("Settings", systemImage: "gearshape") { showingSettings = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var recommendationContent: some View {
        if viewModel.isLoading {
            ProgressView("Checking forecast…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
        } else if let error = viewModel.loadError {
            AppContentUnavailableView(
                title: "Forecast unavailable",
                systemName: "cloud.bolt",
                description: error
            )
            Button("Try Again", systemImage: "arrow.clockwise") {
                Task { await viewModel.reload() }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        } else if viewModel.recommendedBook == nil {
            AppContentUnavailableView(
                title: "Add a book first",
                systemName: "books.vertical",
                description: "Add a book in Library before starting a reading session."
            )
        } else if let best = viewModel.windows.first {
            Text("TODAY’S BEST WINDOW")
                .font(AppTypography.displayEyebrow)
                .foregroundStyle(AppTheme.secondaryText)
            NavigationLink(value: best) {
                FeaturedReadingWindowCard(window: best)
            }
            .buttonStyle(.plain)
            Button(planManager.current == nil ? "Plan Reading" : "Plan This Instead") {
                requestPlan(best)
            }
            .buttonStyle(PrimaryButtonStyle())

            if viewModel.windows.count > 1 {
                Text("COMING UP")
                    .font(AppTypography.displaySection)
                    .tracking(0.5)
                    .padding(.top, 6)
                ForEach(viewModel.windows.dropFirst()) { window in
                    NavigationLink(value: window) {
                        ReadingWindowRow(window: window)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            AppContentUnavailableView(
                title: "No reading windows yet",
                systemName: "calendar.badge.clock",
                description: "Try again later or adjust your availability."
            )
        }
    }

    private func plannedSection(_ plan: ReadingPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if planManager.shouldShowPermissionRecoveryTip {
                TipView(permissionRecoveryTip)
                    .onAppear { planManager.markPermissionRecoveryTipShown() }
            }
            HStack {
                Text("PLANNED")
                    .font(AppTypography.displaySection)
                    .tracking(0.5)
                Spacer()
                Menu {
                    Button(plan.reminderEnabled ? "Remove Notification" : "Add Notification", systemImage: plan.reminderEnabled ? "bell.slash" : "bell") {
                        Task {
                            let changed = await planManager.setNotification(!plan.reminderEnabled)
                            if !changed, case .openSettings = planManager.notice {
                                openURL(URL(string: UIApplication.openSettingsURLString)!)
                            }
                        }
                    }
                    Button(plan.calendarEnabled ? "Remove Calendar" : "Add Calendar", systemImage: plan.calendarEnabled ? "calendar.badge.minus" : "calendar.badge.plus") {
                        Task {
                            let changed = await planManager.setCalendar(!plan.calendarEnabled, bookTitle: viewModel.recommendedBook?.title ?? "your book")
                            if !changed, case .openSettings = planManager.notice {
                                openURL(URL(string: UIApplication.openSettingsURLString)!)
                            }
                        }
                    }
                    Divider()
                    Button("Delete Plan", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Label("Plan actions", systemImage: "ellipsis")
                        .frame(width: 44, height: 44)
                }
            }

            NavigationLink(value: plan) {
                ReadingPlanCard(plan: plan)
            }
            .buttonStyle(.plain)

            Button("Start Reading") { showingBookPicker = true }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var startableBooks: [Book] {
        let books = viewModel.books.filter { $0.status != .finished }
        return books.isEmpty ? viewModel.books : books
    }

    private var noticeBinding: Binding<ReadingPlanNotice?> {
        Binding(
            get: { planManager.notice },
            set: { planManager.notice = $0 }
        )
    }

    private func requestPlan(_ window: ReadingWindow) {
        if planManager.current != nil {
            planToReplaceWith = window
            showingReplacementAlert = true
        } else {
            Task { await createPlan(window) }
        }
    }

    private func createPlan(_ window: ReadingWindow) async {
        _ = await planManager.create(
            from: window,
            bookTitle: viewModel.recommendedBook?.title ?? "your book"
        )
        planToReplaceWith = nil
    }

    private func prepareStart(_ book: Book) {
        guard let plan = planManager.current else { return }
        let pending = PendingPlannedStart(plan: plan, book: book)
        pendingStart = pending
        if plan.start...plan.end ~= Date.now {
            start(pending, keepsPlan: true, insideWindow: true)
        } else {
            showingOutsideWindowAlert = true
        }
    }

    private func startOutsideWindow(keepsPlan: Bool) {
        guard let pendingStart else { return }
        start(pendingStart, keepsPlan: keepsPlan, insideWindow: false)
    }

    private func start(_ pending: PendingPlannedStart, keepsPlan: Bool, insideWindow: Bool) {
        let window = viewModel.windows.first { $0.start == pending.plan.start }
        let weather = window.map { "\($0.condition), \($0.temperature)°" } ?? "Not recorded"
        _ = sessionCoordinator.start(
            book: pending.book,
            origin: .readingPlan,
            plan: keepsPlan ? pending.plan : nil,
            startedInsideWindow: insideWindow,
            weather: weather
        )
        pendingStart = nil
    }

}
