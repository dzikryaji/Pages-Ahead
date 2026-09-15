import SwiftUI

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: AppViewModel
    @State private var showingStartupError: Bool

    init(container: AppContainer = .preview) {
        _viewModel = State(initialValue: AppViewModel(container: container))
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
                        OnboardingIntroGroupView(viewModel: viewModel)
                    case .setup:
                        OnboardingSetupGroupView(viewModel: viewModel)
                    case .finish:
                        OnboardingCompletePage(viewModel: viewModel)
                    }
                case .main:
                    MainTabView(
                        container: viewModel.container,
                        onReplayOnboarding: viewModel.replayOnboarding,
                        startPlannedSessionOnAppear: viewModel.startReadingAfterOnboarding
                    )
                }
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
    ContentView()
}
