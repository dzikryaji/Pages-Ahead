#if DEBUG
import SwiftUI

@MainActor
struct ScreenshotScenarioView: View {
    let scenario: ScreenshotScenario
    let container: AppContainer

    init(scenario: ScreenshotScenario) {
        self.scenario = scenario
        container = Self.makeContainer(for: scenario)
    }

    @ViewBuilder
    var body: some View {
        switch scenario {
        case .onboardingWelcome:
            OnboardingIntroductionFlowView(viewModel: onboardingViewModel(page: .welcome))
        case .onboardingOutcome:
            OnboardingIntroductionFlowView(viewModel: onboardingViewModel(page: .outcome))
        case .onboardingHowItWorks:
            OnboardingIntroductionFlowView(viewModel: onboardingViewModel(page: .howItWorks))
        case .onboardingPreferences:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .preferences))
        case .onboardingRecommendations:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .recommendations, recommendations: true))
        case .onboardingCompletePlanned:
            OnboardingCompletionView(viewModel: onboardingViewModel(page: .complete, recommendations: true, planned: true))
        case .onboardingCompleteLater:
            OnboardingCompletionView(viewModel: onboardingViewModel(page: .complete))
        case .onboardingBookIdle:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .book))
        case .locationDefault:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .location))
        case .locationResolving:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .location, resolving: true))
        case .locationError:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .location, error: "Location could not be determined."))
        case .locationDenied:
            OnboardingSetupFlowView(viewModel: onboardingViewModel(page: .location, error: "Location access was denied.", denied: true))
        case .mainTabsReadingPlan:
            MainTabView(
                container: container,
                planManager: makePlanManager(),
                sessionCoordinator: makeCoordinator()
            )
        case .readingPlanLoading:
            readingPlan(.loading)
        case .readingPlanError:
            readingPlan(.error)
        case .readingPlanNoBook:
            readingPlan(.noBook)
        case .readingPlanLoaded:
            readingPlan(.loaded)
        case .readingPlanCached:
            readingPlan(.cached)
        case .readingPlanPlanned:
            readingPlan(.planned)
        case .readingPlanDetail:
            readingPlanDetail()
        case .readingSessionBookPicker:
            ReadingSessionBookPicker(
                books: SampleData.books,
                initiallySelected: SampleData.books[0],
                onStart: { _ in }
            )
        case .readingWindowDetail:
            readingWindowDetail()
        case .bookAlternatives:
            BookAlternativesView(books: SampleData.books, selected: SampleData.books[0], choose: { _ in })
        case .libraryEmpty:
            library()
        case .libraryPopulated:
            library()
        case .libraryNoCurrentReading:
            library()
        case .libraryNoResults:
            library(query: "No matching title")
        case .bookDetailReading:
            bookDetail(SampleData.books[0])
        case .bookDetailSaved:
            bookDetail(SampleData.books[1])
        case .readingSessionRunning:
            readingSession()
        case .readingSessionPaused:
            readingSession(paused: true)
        case .sessionComplete:
            sessionComplete()
        case .activityEmpty, .activityPopulated:
            ActivityView(viewModel: ActivityViewModel(repository: container.activity, library: container.library))
        case .sessionDetail:
            sessionDetail()
        case .sessionDetailEditing:
            sessionDetail(editing: true)
        case .sessionDeleteAlert:
            sessionDetail(confirmingDelete: true)
        case .settings:
            NavigationStack { SettingsView(settings: container.settings, personalization: container.personalization) }
        case .readingPreferences, .availability, .locationSettings, .privacy, .privacyClearAlert:
            SettingsDetailScreenshot(scenario: scenario, personalization: container.personalization)
        case .personalizationEmpty:
            NavigationStack { PersonalizationDataView(events: [], preferences: ReadingPreferences()) }
        case .personalizationPopulated:
            NavigationStack { PersonalizationDataView(events: sampleEvents, preferences: ReadingPreferences()) }
        case .liveActivityRunning:
            LiveActivityReferenceView(mode: .lockScreen, paused: false)
        case .liveActivityPaused:
            LiveActivityReferenceView(mode: .lockScreen, paused: true)
        case .dynamicIslandExpanded:
            LiveActivityReferenceView(mode: .expanded, paused: false)
        case .dynamicIslandCompact:
            LiveActivityReferenceView(mode: .compact, paused: false)
        case .dynamicIslandMinimal:
            LiveActivityReferenceView(mode: .minimal, paused: false)
        case .addBookIdle:
            BookSelectionView(
                catalog: container.catalog,
                cache: container.catalogCache,
                initialSelection: [],
                onConfirm: { _ in }
            )
        }
    }

}

#endif
