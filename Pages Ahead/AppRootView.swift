import SwiftUI

struct AppRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: AppFlowViewModel
    @State private var planManager: ReadingPlanManager
    @State private var sessionCoordinator: ReadingSessionCoordinator
    @State private var showingStartupError: Bool

    init(container: AppContainer = .preview) {
        _viewModel = State(initialValue: AppFlowViewModel(container: container))
        _planManager = State(initialValue: ReadingPlanManager(
            repository: container.readingPlans,
            notifications: container.notifications,
            calendarWriter: container.calendar,
            settings: container.settings
        ))
        _sessionCoordinator = State(initialValue: ReadingSessionCoordinator(
            library: container.library,
            activity: container.activity,
            readingPlans: container.readingPlans,
            progressStore: container.sessionProgress,
            activityManager: container.readingActivity,
            notifications: container.notifications,
            calendarWriter: container.calendar
        ))
        _showingStartupError = State(initialValue: container.startupError != nil)
    }

    var body: some View {
        ZStack() {
            AppBackground()
            
            Group {
                switch viewModel.route {
                case .onboarding(let page):
                    switch page.group {
                    case .intro:
                        OnboardingIntroductionFlowView(viewModel: viewModel)
                    case .setup:
                        OnboardingSetupFlowView(viewModel: viewModel)
                    case .finish:
                        OnboardingCompletionView(viewModel: viewModel)
                    }
                case .main:
                    MainTabView(
                        container: viewModel.container,
                        planManager: planManager,
                        sessionCoordinator: sessionCoordinator,
                        onReplayOnboarding: viewModel.replayOnboarding
                    )
                    .disabled(sessionCoordinator.isPresented)
                    .accessibilityHidden(sessionCoordinator.isPresented)
                }
            }

            if sessionCoordinator.isPresented {
                ReadingSessionView(coordinator: sessionCoordinator)
                    .zIndex(10)
                    .transition(.opacity)
            }
        }
        .tint(AppTheme.ink)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.route)
        .alert("Temporary storage in use", isPresented: $showingStartupError) {
            Button("Continue", role: .cancel) { }
        } message: {
            Text(viewModel.container.startupError ?? "")
        }
    }
}

#Preview("App Flow") {
    AppRootView()
}
