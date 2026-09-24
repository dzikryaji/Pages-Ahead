import Foundation

enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case reading = "Currently Reading"
    case saved = "Saved"
    case finished = "Finished"
}

struct Book: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let title: String
    let author: String
    let edition: String
    let isbn: String
    let pageCount: Int
    var status: ReadingStatus
    var currentPage: Int
    var coverURL: URL? = nil
    var coverImageData: Data? = nil
    var catalogSource: String = "Open Library"

    var progress: Double { pageCount == 0 ? 0 : min(Double(currentPage) / Double(pageCount), 1) }
    var hasPartialProgress: Bool { currentPage > 0 && currentPage < pageCount }
}
