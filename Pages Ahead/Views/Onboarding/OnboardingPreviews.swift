import SwiftUI

@MainActor
private func onboardingPreviewModel(page: OnboardingPage, planned: Bool = false)
    -> AppFlowViewModel
{
    let container = AppContainer.preview
    container.settings.hasCompletedOnboarding = false

    let viewModel = AppFlowViewModel(container: container)
    let windows = SampleData.windows(bookID: SampleData.books[0].id)
    viewModel.draft.currentPage = page
    viewModel.draft.selectedBooks = [SampleData.books[0]]
    viewModel.draft.resolvedCity = "Makassar"
    viewModel.draft.recommendationCandidates = windows
    viewModel.draft.selectedCandidateID = windows.first?.id
    if planned, let window = windows.first {
        viewModel.draft.readingPlan = ReadingPlan(
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
    OnboardingIntroductionFlowView(viewModel: onboardingPreviewModel(page: .welcome))
}

#Preview("Onboarding · Setup") {
    OnboardingSetupFlowView(
        viewModel: onboardingPreviewModel(page: .preferences)
    )
}

#Preview("Onboarding · Finish · No Plan") {
    OnboardingCompletionView(viewModel: onboardingPreviewModel(page: .complete))
}

#Preview("Onboarding · Finish · Planned") {
    OnboardingCompletionView(
        viewModel: onboardingPreviewModel(page: .complete, planned: true)
    )
}
