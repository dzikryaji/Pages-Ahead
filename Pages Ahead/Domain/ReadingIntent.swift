import AppIntents

struct StartReadingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Reading"
    static let description = IntentDescription("Opens Pages Ahead so you can begin your current reading session.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Opening your current read.")
    }
}

struct PagesAheadShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartReadingIntent(), phrases: ["Start reading with \(.applicationName)"], shortTitle: "Start Reading", systemImageName: "book.fill")
    }
}
