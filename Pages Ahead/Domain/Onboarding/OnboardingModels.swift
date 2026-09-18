import Foundation

enum OnboardingPage: Int, CaseIterable, Codable, Sendable {
    case welcome = 1
    case outcome
    case howItWorks
    case preferences
    case book
    case location
    case recommendations
    case complete

    enum Group: Int, Comparable, Sendable {
        case intro
        case setup
        case finish

        static func < (lhs: Group, rhs: Group) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var group: Group {
        switch self {
        case .welcome, .outcome, .howItWorks: .intro
        case .preferences, .book, .location, .recommendations: .setup
        case .complete: .finish
        }
    }

    var setupStep: Int? {
        guard group == .setup else { return nil }
        return rawValue - Self.preferences.rawValue + 1
    }
}

struct OnboardingDraft: Equatable, Codable, Sendable {
    var currentPage: OnboardingPage = .welcome
    var preferences = ReadingPreferences()
    var selectedBooks: [Book] = []
    var resolvedCity = ""
    var recommendationCandidates: [ReadingWindow] = []
    var selectedCandidateID: UUID?
    var readingPlan: ReadingPlan?
    var plannedDuringOnboarding = false
}
