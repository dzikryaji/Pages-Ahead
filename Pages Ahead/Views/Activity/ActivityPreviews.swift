import SwiftUI

#Preview("Activity") {
    let container = AppContainer.preview
    ActivityView(
        viewModel: ActivityViewModel(
            repository: container.activity,
            library: container.library
        )
    )
}

#Preview("Activity - Empty") {
    let container = AppContainer.empty
    ActivityView(
        viewModel: ActivityViewModel(
            repository: container.activity,
            library: container.library
        )
    )
}


#Preview("Session Detail") {
    let container = AppContainer.preview
    let record = container.activity.records()[0]
    NavigationStack {
        SessionDetailView(
            record: record,
            book: container.library.books().first,
            viewModel: ActivityViewModel(
                repository: container.activity,
                library: container.library
            )
        )
    }
}
