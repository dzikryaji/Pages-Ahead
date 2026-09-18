import SwiftUI

struct MainTabView: View {
    let container: AppContainer
    @Bindable var planManager: ReadingPlanManager
    @Bindable var sessionCoordinator: ReadingSessionCoordinator
    let onReplayOnboarding: () -> Void
    @State private var readingPlanViewModel: ReadingPlanViewModel
    @State private var libraryViewModel: LibraryViewModel
    @State private var activityViewModel: ActivityViewModel

    init(
        container: AppContainer,
        planManager: ReadingPlanManager,
        sessionCoordinator: ReadingSessionCoordinator,
        onReplayOnboarding: @escaping () -> Void = {}
    ) {
        self.container = container
        self.planManager = planManager
        self.sessionCoordinator = sessionCoordinator
        self.onReplayOnboarding = onReplayOnboarding
        _readingPlanViewModel = State(initialValue: ReadingPlanViewModel(library: container.library, repository: container.readingWindows, personalization: container.personalization))
        _libraryViewModel = State(initialValue: LibraryViewModel(repository: container.library))
        _activityViewModel = State(initialValue: ActivityViewModel(repository: container.activity, library: container.library))
    }

    var body: some View {
        TabView {
            Tab("Reading Plan", systemImage: "cloud.sun.fill") {
                ReadingPlanView(
                    viewModel: readingPlanViewModel,
                    planManager: planManager,
                    sessionCoordinator: sessionCoordinator,
                    settings: container.settings,
                    onReplayOnboarding: onReplayOnboarding
                )
            }
            Tab("Library", systemImage: "books.vertical.fill") {
                LibraryView(
                    viewModel: libraryViewModel,
                    sessionCoordinator: sessionCoordinator,
                    catalog: container.catalog,
                    catalogCache: container.catalogCache
                )
            }
            Tab("Activity", systemImage: "chart.bar.fill") {
                ActivityView(viewModel: activityViewModel)
            }
        }
    }
}

#Preview("Main Tabs") {
    let container = AppContainer.preview
    MainTabView(
        container: container,
        planManager: ReadingPlanManager(
            repository: container.readingPlans,
            notifications: container.notifications,
            calendarWriter: container.calendar,
            settings: container.settings
        ),
        sessionCoordinator: ReadingSessionCoordinator(
            library: container.library,
            activity: container.activity,
            readingPlans: container.readingPlans,
            progressStore: container.sessionProgress,
            activityManager: container.readingActivity,
            notifications: container.notifications,
            calendarWriter: container.calendar
        )
    )
}
