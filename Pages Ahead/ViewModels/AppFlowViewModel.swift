import Foundation
import Observation
import OSLog

@MainActor @Observable
final class AppFlowViewModel {
    enum Route: Equatable {
        case onboarding(OnboardingPage)
        case main
    }

    let container: AppContainer
    var route: Route
    var draft: OnboardingDraft
    var locationError: String?
    var isLocationPermissionDenied = false
    var isResolvingLocation = false
    var recommendationError: String?
    var isLoadingRecommendations = false
    var isSchedulingReminder = false

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PagesAhead",
        category: "onboarding"
    )

    init(container: AppContainer) {
        self.container = container
        if container.settings.hasCompletedOnboarding {
            draft = OnboardingDraft(
                currentPage: .complete,
                preferences: container.settings.preferences,
                selectedBooks: container.library.books(),
                resolvedCity: container.settings.city,
                readingPlan: container.readingPlans.current()
            )
            route = .main
        } else {
            let initialDraft = OnboardingDraft()
            draft = initialDraft
            route = .onboarding(initialDraft.currentPage)
            Self.logger.info("onboarding_started")
        }
    }

    var preferences: ReadingPreferences {
        get { draft.preferences }
        set { draft.preferences = newValue; invalidateRecommendations() }
    }

    var recommendationCandidates: [ReadingWindow] {
        draft.recommendationCandidates
    }

    var selectedCandidate: ReadingWindow? {
        guard let id = draft.selectedCandidateID else { return nil }
        return draft.recommendationCandidates.first { $0.id == id }
    }

    func continueIntroduction() {
        switch draft.currentPage {
        case .welcome: go(to: .outcome)
        case .outcome: go(to: .howItWorks)
        case .howItWorks:
            go(to: .preferences)
        default: break
        }
    }

    func skipIntroduction() {
        log("introduction_skipped")
        go(to: .preferences)
    }

    func finishPreferences() {
        log("preferences_completed")
        go(to: .book)
    }

    func setSelectedBooks(_ books: [Book]) {
        draft.selectedBooks = books
        log("books_selected")
    }

    func finishBookSetup() {
        guard !draft.selectedBooks.isEmpty else { return }
        go(to: .location)
    }

    func completeOnboarding() {
        guard draft.currentPage == .complete else { return }
        container.settings.preferences = draft.preferences
        container.settings.city = draft.resolvedCity
        for var book in draft.selectedBooks {
            guard !container.library.books().contains(where: { $0.id == book.id }) else {
                continue
            }
            book.status = .saved
            container.library.add(book)
        }
        if let session = draft.readingPlan { container.readingPlans.save(session) }
        container.settings.hasCompletedOnboarding = true
        route = .main
        log("onboarding_completed")
    }

    func useCurrentLocation() async {
        isResolvingLocation = true
        isLocationPermissionDenied = false
        locationError = nil
        defer { isResolvingLocation = false }
        do {
            let city = try await container.location.requestCurrentLocation().city
            log("location_permission_outcome")
            acceptLocation(city: city)
        }
        catch LocationError.denied {
            isLocationPermissionDenied = true
            locationError = LocationError.denied.localizedDescription
            log("location_permission_outcome")
        }
        catch {
            locationError = error.localizedDescription
            log("location_permission_outcome")
        }
    }

    func finishLocationSetup() async {
        guard !draft.resolvedCity.isEmpty else { return }
        go(to: .recommendations)
        await loadRecommendations()
    }

    func loadRecommendations() async {
        guard !draft.selectedBooks.isEmpty, !draft.resolvedCity.isEmpty else {
            recommendationError = "Choose a book and city before loading reading times."
            return
        }
        isLoadingRecommendations = true
        recommendationError = nil
        defer { isLoadingRecommendations = false }
        do {
            let windows = try await container.readingWindows.readingWindows(
                for: draft.selectedBooks[0].id,
                preferences: draft.preferences,
                city: draft.resolvedCity
            ).filter { $0.end > .now }
            draft.recommendationCandidates = windows
            if !windows.contains(where: { $0.id == draft.selectedCandidateID }) {
                draft.selectedCandidateID = windows.first?.id
            }
            log("recommendations_loaded")
        } catch {
            recommendationError = error.localizedDescription
            log("recommendations_failed")
        }
    }

    func selectCandidate(_ candidate: ReadingWindow) {
        draft.selectedCandidateID = candidate.id
        log("recommendation_selected")
    }

    func planSelectedTime(now: Date = .now) {
        guard let candidate = selectedCandidate else { return }
        guard candidate.end > now else {
            recommendationError = "That time has passed. Refresh to choose another upcoming time."
            return
        }
        let session = ReadingPlan(
            id: draft.readingPlan?.id ?? UUID(),
            start: max(candidate.start, now),
            durationMinutes: max(1, Int(candidate.end.timeIntervalSince(max(candidate.start, now)) / 60)),
            place: candidate.place,
            bookID: nil,
            reminderEnabled: false,
            calendarEnabled: false
        )
        container.readingPlans.save(session)
        container.settings.hasCreatedReadingPlan = true
        draft.readingPlan = session
        draft.plannedDuringOnboarding = true
        log("plan_created")
    }

    func confirmSelectedTime() async {
        planSelectedTime()
        guard draft.readingPlan != nil else { return }
        await enableReminder()
    }

    func planLater() {
        if draft.plannedDuringOnboarding, let session = draft.readingPlan {
            container.readingPlans.delete(id: session.id)
        }
        draft.readingPlan = nil
        draft.plannedDuringOnboarding = false
        log("plan_deferred")
        go(to: .complete)
    }

    func enableReminder() async {
        guard var session = draft.readingPlan else { return }
        isSchedulingReminder = true
        defer { isSchedulingReminder = false }
        log("reminder_choice")
        do {
            let scheduled = try await container.notifications.schedule(session: session)
            session.reminderEnabled = scheduled
            container.settings.planNotificationEnabled = scheduled
        } catch {
            session.reminderEnabled = false
            container.settings.planNotificationEnabled = false
        }
        container.readingPlans.save(session)
        draft.readingPlan = session
        draft.plannedDuringOnboarding = true
        log("notification_permission_outcome")
        go(to: .complete)
    }

    func goBack() {
        let destination: OnboardingPage? = switch draft.currentPage {
        case .welcome: nil
        case .outcome: .welcome
        case .howItWorks: .outcome
        case .preferences: nil
        case .book: .preferences
        case .location: .book
        case .recommendations: .location
        case .complete: nil
        }
        if let destination { go(to: destination) }
    }

    func go(to page: OnboardingPage) {
        guard page.group >= draft.currentPage.group else { return }
        draft.currentPage = page
        route = .onboarding(page)
        log("page_\(page.rawValue)_viewed")
    }

    func replayOnboarding() {
        container.settings.hasCompletedOnboarding = false
        draft = OnboardingDraft(
            currentPage: .welcome,
            preferences: container.settings.preferences,
            selectedBooks: container.library.books(),
            resolvedCity: container.settings.city,
            readingPlan: container.readingPlans.current()
        )
        locationError = nil
        isLocationPermissionDenied = false
        recommendationError = nil
        route = .onboarding(.welcome)
    }

    private func acceptLocation(city: String) {
        let changed = draft.resolvedCity.normalizedCacheKey != city.normalizedCacheKey
        draft.resolvedCity = city
        if changed { invalidateRecommendations() }
        log("location_method_selected")
    }

    private func invalidateRecommendations() {
        draft.recommendationCandidates = []
        draft.selectedCandidateID = nil
        draft.readingPlan = nil
        draft.plannedDuringOnboarding = false
    }

    private func log(_ event: String) {
        Self.logger.info("\(event, privacy: .public)")
    }
}

