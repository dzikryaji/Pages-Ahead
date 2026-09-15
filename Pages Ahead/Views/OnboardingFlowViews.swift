import SwiftUI
import UIKit

struct OnboardingSetupGroupView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingBookSheet = false
    @State private var openedSettings = false

    private static let setupPages: [OnboardingPage] = [
        .preferences, .book, .location, .recommendations,
    ]

    private var page: OnboardingPage { viewModel.draft.currentPage }
    private var step: Int { page.setupStep ?? 1 }

    private var selection: Binding<OnboardingPage> {
        Binding(
            get: { page },
            set: { newPage in
                guard newPage.group == .setup else { return }
                viewModel.go(to: newPage)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    if step > 1 {
                        Button("Back", action: viewModel.goBack)
                    }
                    Spacer()
                }
                .font(AppTypography.description)
                .frame(minHeight: 44)

                setupProgress
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)

            TabView(selection: selection) {
                ForEach(Self.setupPages, id: \.self) { p in
                    setupPageView(for: p)
                        .tag(p)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .swipeDisabled()
        }
        .padding(.top, 50)
        .appBackground()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: page)

        .sheet(isPresented: $showingBookSheet) {
            BookSelectionSheet(
                catalog: viewModel.container.catalog,
                cache: viewModel.container.catalogCache,
                initialSelection: viewModel.draft.selectedBooks,
                onConfirm: viewModel.setSelectedBooks
            )
        }
        .task(id: page) {
            guard page == .recommendations,
                viewModel.recommendationCandidates.isEmpty
            else { return }
            await viewModel.loadRecommendations()
        }
        .onChange(of: page) { _, newPage in
            UIAccessibility.post(
                notification: .screenChanged,
                argument: String(localized: title(for: newPage))
            )
        }
        .onChange(of: scenePhase) { _, phase in
            guard page == .location, phase == .active, openedSettings else {
                return
            }
            openedSettings = false
            Task { await viewModel.useCurrentLocation() }
        }

        .ignoresSafeArea()
    }

    /// One TabView page: same title/content/footer layout the old
    /// switch-based ScrollView used, just keyed off the page passed in
    /// rather than the shared `page` property, since TabView can keep
    /// neighboring pages alive at the same time.
    private func setupPageView(for p: OnboardingPage) -> some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title(for: p))
                        .font(AppTypography.displayLarge)
                    Text(description(for: p))
                        .font(AppTypography.description)
                    setupContent(for: p)
                    setupFooter(for: p)
                }
                .padding(.horizontal, 32)
                .frame(
                    maxWidth: .infinity,
                    minHeight: proxy.size.height,
                    alignment: .top
                )
            }
        }
    }

    private var setupProgress: some View {
        HStack(spacing: 10) {
            ForEach(1...4, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? AppTheme.ink : AppTheme.border)
                    .frame(height: 5)
                    .opacity(index <= step ? 1 : 0.65)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup progress")
        .accessibilityValue("Step \(step) of 4")
    }

    private func title(for p: OnboardingPage) -> LocalizedStringResource {
        switch p {
        case .preferences: "When do you like to read?"
        case .book: "What book are you reading?"
        case .location: "Enable your location"
        case .recommendations: "Your best upcoming reading time"
        default: "Set up Pages Ahead"
        }
    }

    private func description(for p: OnboardingPage) -> LocalizedStringResource {
        switch p {
        case .preferences: "Tell us a bit about your reading preferences."
        case .book:
            "Add the books you're currently reading. You'll need at least one to get started."
        case .location:
            "We use your location to check the weather, so Pages Ahead can suggest the best time to read."
        case .recommendations:
            "Based on your preferences and this week's weather"
        default: "Set up Pages Ahead"
        }
    }

    @ViewBuilder private func setupContent(for p: OnboardingPage) -> some View {
        switch p {
        case .preferences: preferencesContent
        case .book: bookContent
        case .location: locationContent
        case .recommendations: recommendationsContent
        default: EmptyView()
        }
    }

    private var preferencesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingChoiceGroup(
                title: "Weekday Preferred Time",
                values: ["Morning", "Afternoon", "Evening", "Anytime"],
                selection: $viewModel.preferences.weekdayPreferredTime
            )
            OnboardingChoiceGroup(
                title: "Weekend Preferred Time",
                values: ["Morning", "Afternoon", "Evening", "Anytime"],
                selection: $viewModel.preferences.weekendPreferredTime
            )
            OnboardingChoiceGroup(
                title: "Preferred Weather",
                values: ["Cold", "Mild", "Warm"],
                selection: $viewModel.preferences.preferredWeather
            )
            OnboardingChoiceGroup(
                title: "Preferences Priority",
                values: ["Time", "Balanced", "Weather"],
                selection: $viewModel.preferences.preferencePriority
            )
        }
    }

    private var bookContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Find Your Book").font(AppTypography.bodyBold)
                Spacer()
                Button("Find Your Book", systemImage: "plus") {
                    showingBookSheet = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .accessibilityIdentifier("onboarding-add-books")
            }
            if viewModel.draft.selectedBooks.isEmpty {
                Text("No books added yet")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.draft.selectedBooks) { book in
                        BookRow(book: book)
                            .padding(12)
                            .appCard(cornerRadius: 14)
                    }
                }
            }
            Spacer()
        }
    }

    private var locationContent: some View {
        VStack(alignment: .leading) {
            Spacer()
            AppSymbol(systemName: "onboarding.location", size: 250)
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity)
            if let error = viewModel.locationError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }

    private var recommendationsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Group {
                if viewModel.isLoadingRecommendations {
                    ProgressView("Finding nearby suitable times…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else if let error = viewModel.recommendationError {
                    VStack(spacing: 12) {
                        AppContentUnavailableView(
                            title: "Reading times unavailable",
                            systemName: "cloud.bolt",
                            description: error
                        )
                        Button("Try Again", systemImage: "arrow.clockwise") {
                            Task { await viewModel.loadRecommendations() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                } else if viewModel.recommendationCandidates.isEmpty {
                    AppContentUnavailableView(
                        title: "No suitable times yet",
                        systemName: "calendar.badge.exclamationmark",
                        description:
                            "Change your preferences or location, or plan later."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.recommendationCandidates.prefix(3)) {
                            candidate in
                            OnboardingWindowChoice(
                                window: candidate,
                                selected: candidate.id
                                    == viewModel.draft.selectedCandidateID
                            ) {
                                viewModel.selectCandidate(candidate)
                            }
                        }
                    }
                }
            }
            Spacer()
        }
    }

    @ViewBuilder private func setupFooter(for p: OnboardingPage) -> some View {
        switch p {
        case .preferences:
            VStack(spacing: 12) {
                Text("You can change these later in settings")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                Button("Next", action: viewModel.finishPreferences)
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .book:
            VStack(spacing: 12) {
                Text("You can change these later in settings")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                Button("Next", action: viewModel.finishBookSetup)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.draft.selectedBooks.isEmpty)
            }
        case .location:
            Button {
                if !viewModel.draft.resolvedCity.isEmpty {
                    Task { await viewModel.finishLocationSetup() }
                } else if viewModel.isLocationPermissionDenied {
                    openSettings()
                } else {
                    Task { await viewModel.useCurrentLocation() }
                }
            } label: {
                if viewModel.isResolvingLocation {
                    ProgressView().tint(.white)
                } else {
                    Text(locationActionTitle)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.isResolvingLocation)
            .accessibilityIdentifier("onboarding-location-action")
        case .recommendations:
            VStack(spacing: 12) {
                Button("I'll Do This Later", action: viewModel.planLater)
                    .font(AppTypography.displayEyebrow)
                    .frame(maxWidth: .infinity)
                Button {
                    Task { await viewModel.confirmSelectedTime() }
                } label: {
                    if viewModel.isSchedulingReminder {
                        ProgressView().tint(.white)
                    } else {
                        Text("Confirm This Time")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(
                    viewModel.selectedCandidate == nil
                        || viewModel.isSchedulingReminder
                )
            }
        default:
            EmptyView()
        }
    }

    private var locationActionTitle: LocalizedStringKey {
        if !viewModel.draft.resolvedCity.isEmpty { return "Next" }
        return viewModel.isLocationPermissionDenied
            ? "Open Settings" : "Turn On Location"
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openedSettings = true
        openURL(url)
    }
}

// MARK: - Swipe-lock helper

extension View {
    /// Disables the pan/swipe gesture on a `.page`-style `TabView`.
    ///
    /// SwiftUI doesn't expose any API for this — a `.page` `TabView` is
    /// backed by a `UIPageViewController`, which owns its own internal
    /// `UIScrollView` for paging. This drops to UIKit, walks up from an
    /// invisible helper view to find that scroll view, and toggles
    /// `isScrollEnabled` on it. Apply it directly to the `TabView`:
    ///
    ///     TabView(selection: $selection) { ... }
    ///         .tabViewStyle(.page(indexDisplayMode: .never))
    ///         .swipeDisabled()
    ///
    /// Programmatic navigation (setting `selection`, e.g. from Next/Back
    /// buttons) still animates normally — only the finger-driven swipe is
    /// blocked.
    func swipeDisabled(_ disabled: Bool = true) -> some View {
        background(SwipeGestureLock(disabled: disabled))
    }
}

private struct SwipeGestureLock: UIViewRepresentable {
    let disabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The TabView's UIScrollView may not exist yet the first time this
        // runs (right after makeUIView), so defer a tick.
        DispatchQueue.main.async {
            applyLock(from: uiView)
        }
    }

    private func applyLock(from view: UIView) {
        guard let scrollView = findScrollView(from: view) else { return }
        scrollView.isScrollEnabled = !disabled
    }

    /// Walks up the ancestor chain and, at each level, searches that
    /// ancestor's whole subtree for a `UIScrollView`. Starting from the
    /// closest ancestor and expanding outward finds the TabView's paging
    /// scroll view reliably without needing to know the exact hierarchy
    /// depth (which can shift between iOS versions).
    private func findScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while let candidate = current {
            if let match = recursiveFind(in: candidate) {
                return match
            }
            current = candidate.superview
        }
        return nil
    }

    private func recursiveFind(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let match = recursiveFind(in: subview) {
                return match
            }
        }
        return nil
    }
}

private struct OnboardingChoiceGroup<Value: Hashable>: View {
    let title: LocalizedStringKey
    let values: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    init(
        title: LocalizedStringKey,
        values: [Value],
        selection: Binding<Value>,
        label: @escaping (Value) -> String = { String(describing: $0) }
    ) {
        self.title = title
        self.values = values
        _selection = selection
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppTypography.bodyBold)
            ForEach(values, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    HStack {
                        Text(label(value))
                        Spacer()
                        Image(
                            systemName: selection == value
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(
                            selection == value
                                ? AppTheme.ink : AppTheme.tertiaryText
                        )
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(
                        selection == value
                            ? AppTheme.selectedSurface : AppTheme.surface,
                        in: RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                selection == value
                                    ? AppTheme.ink
                                    : AppTheme.border.opacity(0.4),
                                lineWidth: selection == value ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

private struct OnboardingWindowChoice: View {
    let window: ReadingWindow
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    AppSymbol(systemName: window.weatherSymbol, size: 30).frame(
                        width: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(window.start.readingDay).font(.headline)
                        Text(window.readingTimeRange).font(
                            AppTypography.subheadline
                        )
                        Text(
                            "\(window.condition), \(window.temperature)° · \(window.place)"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Image(
                        systemName: selected
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.system(size: 24))
                    .foregroundStyle(
                        selected ? AppTheme.ink : AppTheme.tertiaryText
                    )
                }
                Text(window.fitReason).font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                if window.isCached {
                    Label(
                        "Cached forecast",
                        systemImage: "clock.arrow.circlepath"
                    ).font(AppTypography.caption)
                }
            }
            .padding(16)
            .background(
                selected ? AppTheme.selectedSurface : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        selected ? AppTheme.ink : AppTheme.border.opacity(0.4),
                        lineWidth: selected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct OnboardingCompletePage: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment:.leading, spacing: 12) {
                Text("Everything is all set")
                    .font(AppTypography.displaySuperLarge)
                .multilineTextAlignment(.leading)
                Text(
                    viewModel.draft.plannedSession == nil
                    ? "All your preferences are recorded. Pages Ahead will start suggesting your best reading times."
                    : "You're all set. Welcome to Pages Ahead"
                )
                .frame(maxWidth:.infinity, alignment: .leading)
                .font(AppTypography.description)
        
            }
            .frame(maxWidth:.infinity, alignment: .leading)
            Spacer()
            AppSymbol(systemName: "sun.max.fill", size: 250)
                .foregroundStyle(AppTheme.ink)
                .rotationEffect(.degrees(rotation))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            Spacer()
            if viewModel.draft.plannedSession != nil,
                let window = viewModel.recommendationCandidates.first(
                    where: { $0.id == viewModel.draft.selectedCandidateID })
            {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Next Reading Time").font(
                        AppTypography.bodyBold
                    )
                    OnboardingWindowChoice(
                        window: window,
                        selected: true,
                        action: {}
                    )
                }
            }

            Button("Get Started", action: viewModel.completeOnboarding)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .padding(32)
        .padding(.top,50)
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .linear(duration: 12).repeatForever(autoreverses: false)
            ) { rotation = 360 }
        }
        .ignoresSafeArea()
        .appBackground()
        
    }
}

@MainActor
private func onboardingPreviewModel(page: OnboardingPage, planned: Bool = false)
    -> AppViewModel
{
    let container = AppContainer.preview
    container.settings.hasCompletedOnboarding = false

    let viewModel = AppViewModel(container: container)
    let windows = SampleData.windows(bookID: SampleData.books[0].id)
    viewModel.draft.currentPage = page
    viewModel.draft.introductionSeen = page.group != .intro
    viewModel.draft.selectedBooks = [SampleData.books[0]]
    viewModel.draft.resolvedCity = "Makassar"
    viewModel.draft.recommendationCandidates = windows
    viewModel.draft.selectedCandidateID = windows.first?.id
    if planned, let window = windows.first {
        viewModel.draft.plannedSession = PlannedSession(
            id: UUID(),
            start: window.start,
            durationMinutes: window.durationMinutes,
            place: window.place,
            bookID: nil,
            reminderEnabled: false,
            calendarEnabled: false
        )
    }
    viewModel.route = .onboarding(page)
    return viewModel
}

#Preview("Onboarding · Intro") {
    OnboardingIntroGroupView(viewModel: onboardingPreviewModel(page: .welcome))
}

#Preview("Onboarding · Setup") {
    OnboardingSetupGroupView(
        viewModel: onboardingPreviewModel(page: .preferences)
    )
}

#Preview("Onboarding · Finish · No Plan") {
    OnboardingCompletePage(viewModel: onboardingPreviewModel(page: .complete))
}

#Preview("Onboarding · Finish · Planned") {
    OnboardingCompletePage(
        viewModel: onboardingPreviewModel(page: .complete, planned: true)
    )
}
