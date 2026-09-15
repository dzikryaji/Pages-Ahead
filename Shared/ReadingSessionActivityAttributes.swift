import ActivityKit
import Foundation

struct ReadingSessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let startedAt: Date
        let endsAt: Date
        let remainingSeconds: Int
        let isPaused: Bool
    }

    let bookID: UUID
    let bookTitle: String
    let bookAuthor: String
    let durationSeconds: Int
}
