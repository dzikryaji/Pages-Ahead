import SwiftUI

struct OnboardingCompletionView: View {
    @Bindable var viewModel: AppFlowViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment:.leading, spacing: 12) {
                Text("Everything is all set")
                    .font(AppTypography.displaySuperLarge)
                .multilineTextAlignment(.leading)
                Text(
                    viewModel.draft.readingPlan == nil
                    ? "All your preferences are recorded. Pages Ahead will start suggesting your best reading times."
                    : "You're all set. Welcome to Pages Ahead"
                )
                .frame(maxWidth:.infinity, alignment: .leading)
                .font(AppTypography.description)
        
            }
            .frame(maxWidth:.infinity, alignment: .leading)
            Spacer()
            AppSymbol(systemName: "sun.max.fill", size: 250)
                .foregroundStyle(AppTheme.accent)
                .rotationEffect(.degrees(rotation))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            Spacer()
            if viewModel.draft.readingPlan != nil,
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
