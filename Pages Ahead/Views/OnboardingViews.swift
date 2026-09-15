import SwiftUI
import UIKit

struct WelcomeView: View {
    let actionTitle: String
    let getStarted: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 44)
                    VStack(spacing: 12) {
                        AppSymbolLabel(
                            title: "READ WITH THE WEATHER",
                            systemName: "book.pages.fill",
                            symbolSize: 17
                        )
                            .font(AppTypography.displayEyebrow)
                            .tracking(1.1)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text("Pages Ahead")
                            .font(AppTypography.displayLarge)
                            .tracking(0.8)
                        Text(
                            "Find a comfortable time for your next chapter."
                        )
                        .font(AppTypography.description)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 420)
                    }
                    Text(
                        "Pages Ahead combines the book you're reading with weather near you to suggest personalized reading windows."
                    )
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
                    OnboardingValueChainCard()
                        .frame(maxWidth: 420)
                    RecommendationPreviewCard()
                        .frame(maxWidth: 420)
                    Spacer(minLength: 44)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(actionTitle, action: getStarted)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .appBackground()
    }
}

private struct OnboardingValueChainCard: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                input("Your book", symbol: "book.closed.fill")
                Image(systemName: "plus").font(.system(size: 16)).foregroundStyle(.secondary)
                input("Your city", symbol: "location.fill")
                Image(systemName: "arrow.right").font(.system(size: 18)).foregroundStyle(.secondary)
                input("Reading windows", symbol: "sparkles")
            }
            VStack(alignment: .leading, spacing: 12) {
                input("Your book", symbol: "book.closed.fill")
                input("Weather near your city", symbol: "location.fill")
                Divider()
                input("Personalized reading windows", symbol: "sparkles")
            }
        }
        .font(AppTypography.subheadlineSemibold)
        .padding(16)
        .appCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Your book plus weather near your city creates personalized reading windows."
        )
    }

    @ViewBuilder private func input(_ title: String, symbol: String) -> some View {
        if HandDrawnSymbol.assetName(for: symbol) != nil {
            AppSymbolLabel(title: title, systemName: symbol, symbolSize: 17)
                .foregroundStyle(AppTheme.ink)
        } else {
            Label(title, systemImage: symbol)
                .foregroundStyle(AppTheme.ink)
        }
    }
}

private struct RecommendationPreviewCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("TONIGHT'S READING WINDOW", systemImage: "sparkles")
                .font(AppTypography.displayEyebrow)
                .tracking(0.8)
                .foregroundStyle(AppTheme.ink)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    bookIcon
                    recommendationDetails
                }
            } else {
                HStack(spacing: 16) {
                    bookIcon
                    recommendationDetails
                }
            }
        }
        .padding(20)
        .appCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Example recommendation: Tonight from 7:30 to 8 PM, comfortable weather at 24 degrees, for a 30-minute reading session."
        )
    }

    private var bookIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.coverGradient)
            AppSymbol(systemName: "book.closed.fill", size: 30)
                .foregroundStyle(.white)
        }
        .frame(width: 64, height: 84)
        .accessibilityHidden(true)
    }

    private var recommendationDetails: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("7:30–8:00 PM")
                .font(.title2.bold())
            AppSymbolLabel(
                title: "Comfortable · 24°",
                systemName: "cloud.sun.fill",
                symbolSize: 18
            )
                .font(AppTypography.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Text("A calm 30-minute window")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Continue your current book")
                .font(AppTypography.subheadlineSemibold)
        }
    }
}

struct LocationSetupView: View {
    @Bindable var viewModel: AppViewModel
    @State private var enteringCity = false
    @Environment(\.openURL) private var openURL

    init(viewModel: AppViewModel, enteringCity: Bool = false) {
        self.viewModel = viewModel
        _enteringCity = State(initialValue: enteringCity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Step 2 of 2")
                        .font(AppTypography.subheadlineSemibold)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer(minLength: 20)
                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 76))
                        .foregroundStyle(AppTheme.ink)
                        .accessibilityHidden(true)
                    Text("Where should we check the weather?")
                        .font(AppTypography.displayLarge)
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                    Text(
                        "Local weather helps us find comfortable times and places to read. City-level location is enough; precise location is never required."
                    )
                    .font(AppTypography.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    if let book = viewModel.onboardingBook {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("WHAT HAPPENS NEXT", systemImage: "sparkles")
                                .font(AppTypography.displayEyebrow)
                                .tracking(0.8)
                                .foregroundStyle(AppTheme.ink)
                            Text(
                                "We'll combine **\(book.title)** with weather near your city to suggest your first reading window."
                            )
                            .font(AppTypography.body)
                        }
                        .frame(maxWidth: 420, alignment: .leading)
                        .padding(16)
                        .appCard()
                        .accessibilityElement(children: .combine)
                    }
                    Spacer(minLength: 32)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        Task { await viewModel.useCurrentLocation() }
                    } label: {
                        if viewModel.isResolvingLocation {
                            ProgressView().tint(.white)
                        } else {
                            Text("Use Current Location")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(
                        viewModel.isResolvingLocation
                    )
                    if let error = viewModel.locationError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        if viewModel.isLocationPermissionDenied,
                           let settingsURL = URL(
                               string: UIApplication.openSettingsURLString
                           ) {
                            Button("Open Settings") { openURL(settingsURL) }
                                .buttonStyle(.bordered)
                        }
                    }
                    Button("Choose a City Instead") { enteringCity = true }
                        .font(.headline)
                        .frame(minHeight: 44)
                    Label(
                        "Location stays under your control",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .appBackground()
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        viewModel.backToWelcome()
                    }
                }
            }
        }
        .sheet(isPresented: $enteringCity) {
            NavigationStack {
                Form {
                    TextField("City", text: $viewModel.manualCity)
                        .textContentType(.addressCity)
                }
                .navigationTitle("Choose city")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { enteringCity = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use City") {
                            enteringCity = false
                            viewModel.finishLocationSetup()
                        }.disabled(
                            viewModel.manualCity.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        )
                    }
                }
            }.presentationDetents([.medium])
        }
    }
}

struct OnboardingBookSetupView: View {
    @Bindable var viewModel: AppViewModel
    @State private var library: LibraryViewModel
    @State private var search: CatalogSearchViewModel
    @FocusState private var isSearchFocused: Bool
    private let focusSearchOnAppear: Bool

    init(
        viewModel: AppViewModel,
        initialSearch: CatalogSearchInitialState? = nil,
        focusSearchOnAppear: Bool = true
    ) {
        self.viewModel = viewModel
        self.focusSearchOnAppear = focusSearchOnAppear
        _library = State(
            initialValue: LibraryViewModel(
                repository: viewModel.container.library
            )
        )
        let search = CatalogSearchViewModel(
            catalog: viewModel.container.catalog,
            cache: viewModel.container.catalogCache
        )
        if let initialSearch {
            search.query = initialSearch.query
            search.state = initialSearch.state
            search.selected = initialSearch.selected
            search.isRefreshing = initialSearch.isRefreshing
        }
        _search = State(initialValue: search)
    }

    var body: some View {
        @Bindable var search = search
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    introduction
                    searchField
                    searchContent
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if let selected = search.selected {
                    Button("Continue with \(selected.title)") {
                        library.add(selected)
                        viewModel.finishBookSetup()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
            .appBackground()
            .navigationTitle("Your first book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        viewModel.backToWelcome()
                    }
                }
            }
            .onChange(of: search.query) { _, query in
                search.queryChanged(to: query)
            }
        }
        .task {
            guard focusSearchOnAppear else { return }
            await Task.yield()
            isSearchFocused = true
        }
        .onDisappear(perform: search.cancelSearch)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 1 of 2")
                .font(AppTypography.subheadlineSemibold)
                .foregroundStyle(AppTheme.secondaryText)
            ProgressView(value: 0.5)
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step 1 of 2")
            AppSymbol(systemName: "books.vertical.fill", size: 52)
                .foregroundStyle(AppTheme.ink)
                .accessibilityHidden(true)
            Text("What are you reading?")
                .font(AppTypography.displayLarge)
                .tracking(0.5)
            Text(
                "Choose one book so Pages Ahead can personalize recommendations, track your progress, and show the right title during reading sessions."
            )
            .font(AppTypography.body)
            .foregroundStyle(AppTheme.secondaryText)
            VStack(alignment: .leading, spacing: 10) {
                benefit("Personalized reading windows", symbol: "sparkles")
                benefit("Progress connected to your book", symbol: "chart.line.uptrend.xyaxis")
                benefit("Your title and cover during sessions", symbol: "timer")
            }
            .padding(16)
            .appCard()
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find your book")
                .font(AppTypography.bodyBold)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Title, author, or ISBN", text: $search.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .accessibilityIdentifier("onboarding-book-search")
                if !search.query.isEmpty {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        search.query = ""
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
            Text("Search by title, author, or ISBN. Select one result to continue.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var searchContent: some View {
        switch search.state {
        case .idle:
            Label(
                "Your book stays in your private on-device library.",
                systemImage: "lock.fill"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        case .loading:
            ProgressView("Searching catalog…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        case .failed(let message):
            VStack(spacing: 12) {
                ContentUnavailableView(
                    "Search failed",
                    systemImage: "wifi.exclamationmark",
                    description: Text(message)
                )
                Button("Try Again") {
                    search.queryChanged(to: search.query)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        case .loaded(let results):
            if results.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No books found for \(search.query).")
                )
                    .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search results")
                        .font(.headline)
                    ForEach(results) { book in
                        resultButton(for: book)
                    }
                }
            }
        }
    }

    private func resultButton(for book: Book) -> some View {
        let isSelected = search.selected?.id == book.id
        return Button {
            search.selected = book
        } label: {
            HStack(spacing: 12) {
                BookRow(book: book) { data in
                    search.coverLoaded(data, for: book.id)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                .foregroundStyle(
                    isSelected ? AppTheme.ink : AppTheme.tertiaryText
                )
                .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                isSelected ? AppTheme.selectedSurface : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? AppTheme.ink : AppTheme.border.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(book.title) by \(book.author)\(isSelected ? ", selected" : "")"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private func benefit(_ title: String, symbol: String) -> some View {
        if HandDrawnSymbol.assetName(for: symbol) != nil {
            AppSymbolLabel(title: title, systemName: symbol, symbolSize: 17)
                .font(AppTypography.subheadline)
                .foregroundStyle(.primary)
        } else {
            Label(title, systemImage: symbol)
                .font(AppTypography.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

#Preview("Welcome") {
    WelcomeView(actionTitle: "Set Up My Reading Plan", getStarted: {})
}

#Preview("Onboarding Value Chain") {
    OnboardingValueChainCard()
        .padding()
        .appBackground()
}

#Preview("Recommendation Preview") {
    RecommendationPreviewCard()
        .padding()
        .appBackground()
}

#Preview("Location Setup") {
    LocationSetupView(viewModel: AppViewModel(container: .preview))
}

#Preview("Required Book Setup") {
    let viewModel = AppViewModel(container: .preview)
    OnboardingBookSetupView(viewModel: viewModel)
}
