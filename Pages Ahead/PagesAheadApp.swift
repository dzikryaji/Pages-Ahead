//
//  Pages_AheadApp.swift
//  Pages Ahead
//
//  Created by Dzikry Aji Santoso on 10/09/26.
//

import SwiftUI
import TipKit
import OSLog

@main
struct PagesAheadApp: App {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PagesAhead",
        category: "TipKit"
    )
    private let container: AppContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            container = .uiTesting
        } else if arguments.contains("-design-preview") {
            let preview = AppContainer.preview
            preview.settings.hasCompletedOnboarding = true
            container = preview
        } else {
            container = .live
        }
        do {
            try Tips.configure()
        } catch {
            Self.logger.error(
                "TipKit configuration failed: \(error.localizedDescription, privacy: .public)"
            )
        }
#if DEBUG
        if ScreenshotScenario.current != nil {
            Tips.showAllTipsForTesting()
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let scenario = ScreenshotScenario.current {
                ScreenshotScenarioView(scenario: scenario)
                    .preferredColorScheme(.light)
                    .tint(AppTheme.ink)
            } else {
                AppRootView(container: container)
                    .preferredColorScheme(.light)
            }
#else
            AppRootView(container: container)
                .preferredColorScheme(.light)
#endif
        }
    }
}
