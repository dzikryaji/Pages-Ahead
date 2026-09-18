#if DEBUG
import Foundation

enum ScreenshotScenario: String, CaseIterable {
    case onboardingWelcome = "onboarding_welcome"
    case onboardingOutcome = "onboarding_outcome"
    case onboardingHowItWorks = "onboarding_how_it_works"
    case onboardingPreferences = "onboarding_preferences"
    case onboardingRecommendations = "onboarding_recommendations"
    case onboardingCompletePlanned = "onboarding_complete_planned"
    case onboardingCompleteLater = "onboarding_complete_later"
    case onboardingBookIdle = "onboarding_book_idle"
    case locationDefault = "location_default"
    case locationResolving = "location_resolving"
    case locationError = "location_error"
    case locationDenied = "location_denied"
    case mainTabsReadingPlan = "main_tabs_reading_plan"
    case readingPlanLoading = "reading_plan_loading"
    case readingPlanError = "reading_plan_error"
    case readingPlanNoBook = "reading_plan_no_book"
    case readingPlanLoaded = "reading_plan_loaded"
    case readingPlanCached = "reading_plan_cached"
    case readingPlanPlanned = "reading_plan_planned"
    case readingPlanDetail = "reading_plan_detail"
    case readingSessionBookPicker = "reading_session_book_picker"
    case readingWindowDetail = "reading_window_detail"
    case bookAlternatives = "book_alternatives"
    case libraryEmpty = "library_empty"
    case libraryPopulated = "library_populated"
    case libraryNoCurrentReading = "library_no_current_reading"
    case libraryNoResults = "library_no_results"
    case addBookIdle = "add_book_idle"
    case bookDetailReading = "book_detail_reading"
    case bookDetailSaved = "book_detail_saved"
    case readingSessionRunning = "reading_session_running"
    case readingSessionPaused = "reading_session_paused"
    case sessionComplete = "session_complete"
    case activityEmpty = "activity_empty"
    case activityPopulated = "activity_populated"
    case sessionDetail = "session_detail"
    case sessionDetailEditing = "session_detail_editing"
    case sessionDeleteAlert = "session_delete_alert"
    case settings = "settings"
    case readingPreferences = "reading_preferences"
    case availability = "availability"
    case locationSettings = "location_settings"
    case privacy = "privacy"
    case privacyClearAlert = "privacy_clear_alert"
    case personalizationEmpty = "personalization_empty"
    case personalizationPopulated = "personalization_populated"
    case liveActivityRunning = "live_activity_running"
    case liveActivityPaused = "live_activity_paused"
    case dynamicIslandExpanded = "dynamic_island_expanded"
    case dynamicIslandCompact = "dynamic_island_compact"
    case dynamicIslandMinimal = "dynamic_island_minimal"

    static var current: ScreenshotScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot-scenario"),
              arguments.indices.contains(index + 1) else { return nil }
        return ScreenshotScenario(rawValue: arguments[index + 1])
    }
}

#endif
