import SwiftUI

#Preview("Library") {
    let container = AppContainer.preview
    let coordinator = ReadingSessionCoordinator(
        library: container.library, activity: container.activity,
        readingPlans: container.readingPlans, progressStore: container.sessionProgress,
        activityManager: container.readingActivity, notifications: container.notifications,
        calendarWriter: container.calendar
    )
    LibraryView(
        viewModel: LibraryViewModel(repository: container.library),
        sessionCoordinator: coordinator,
        catalog: container.catalog,
        catalogCache: container.catalogCache
    )
}

#Preview("Library - Empty") {
    let container = AppContainer.empty
    let coordinator = ReadingSessionCoordinator(
        library: container.library, activity: container.activity,
        readingPlans: container.readingPlans, progressStore: container.sessionProgress,
        activityManager: container.readingActivity, notifications: container.notifications,
        calendarWriter: container.calendar
    )
    LibraryView(
        viewModel: LibraryViewModel(repository: container.library),
        sessionCoordinator: coordinator,
        catalog: container.catalog,
        catalogCache: container.catalogCache
    )
}

#Preview("Book Detail") {
    let container = AppContainer.preview
    let coordinator = ReadingSessionCoordinator(
        library: container.library, activity: container.activity,
        readingPlans: container.readingPlans, progressStore: container.sessionProgress,
        activityManager: container.readingActivity, notifications: container.notifications,
        calendarWriter: container.calendar
    )
    NavigationStack {
        BookDetailView(
            book: SampleData.books[0],
            repository: LibraryViewModel(repository: container.library),
            sessionCoordinator: coordinator
        )
    }
}
