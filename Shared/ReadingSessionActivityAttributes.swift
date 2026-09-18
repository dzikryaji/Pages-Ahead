import ActivityKit
import Foundation

nonisolated struct ReadingSessionActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        let startedAt: Date
        let elapsedSeconds: Int
        let isPaused: Bool
    }

    let bookID: UUID
    let bookTitle: String
    let bookAuthor: String
}
