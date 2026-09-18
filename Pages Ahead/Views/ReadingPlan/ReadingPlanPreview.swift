import SwiftUI

extension ReadingPlanNotice: Identifiable {
    var id: String {
        switch self {
        case .message(let value): "message-\(value)"
        case .openSettings(let value): "settings-\(value)"
        }
    }
}

#Preview("Reading Plan") {
    let container = AppContainer.preview
    let coordinator = ReadingSessionCoordinator(
        library: container.library,
        activity: container.activity,
        readingPlans: container.readingPlans,
        progressStore: container.sessionProgress,
        activityManager: container.readingActivity,
        notifications: container.notifications,
        calendarWriter: container.calendar
    )
    ReadingPlanView(
        viewModel: ReadingPlanViewModel(
            library: container.library,
            repository: container.readingWindows,
            personalization: container.personalization
        ),
        planManager: ReadingPlanManager(
            repository: container.readingPlans,
            notifications: container.notifications,
            calendarWriter: container.calendar,
            settings: container.settings
        ),
        sessionCoordinator: coordinator,
        settings: container.settings
    )
}
