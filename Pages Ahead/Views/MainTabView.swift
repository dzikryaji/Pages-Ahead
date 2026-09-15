import SwiftUI

struct MainTabView: View {
    let container: AppContainer
    let onReplayOnboarding: () -> Void
    @State private var forecastViewModel: ForecastViewModel
    @State private var libraryViewModel: LibraryViewModel
    @State private var activityViewModel: ActivityViewModel

    init(
        container: AppContainer,
        onReplayOnboarding: @escaping () -> Void = {}
    ) {
        self.container = container
        self.onReplayOnboarding = onReplayOnboarding
        _forecastViewModel = State(initialValue: ForecastViewModel(library: container.library, repository: container.forecast, sessions: container.sessions, personalization: container.personalization))
        _libraryViewModel = State(initialValue: LibraryViewModel(repository: container.library))
        _activityViewModel = State(initialValue: ActivityViewModel(repository: container.activity, library: container.library))
    }

    var body: some View {
        TabView {
            Tab("Reading Plan", systemImage: "cloud.sun.fill") {
                ForecastHomeView(
                    viewModel: forecastViewModel,
                    activityRepository: container.activity,
                    sessionProgress: container.sessionProgress,
                    readingActivity: container.readingActivity,
                    notifications: container.notifications,
                    calendarWriter: container.calendar,
                    settings: container.settings,
                    personalization: container.personalization,
                    onReplayOnboarding: onReplayOnboarding
                )
            }
            Tab("Library", systemImage: "books.vertical.fill") {
                LibraryView(viewModel: libraryViewModel, activityRepository: container.activity, personalization: container.personalization, sessionProgress: container.sessionProgress, readingActivity: container.readingActivity, catalog: container.catalog, catalogCache: container.catalogCache)
            }
            Tab("Activity", systemImage: "chart.bar.fill") {
                ActivityView(viewModel: activityViewModel)
            }
        }
    }
}

#Preview("Main Tabs") {
    MainTabView(container: .preview)
}
