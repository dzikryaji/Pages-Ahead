import Foundation
import Observation

@MainActor @Observable
final class ActivityViewModel {
    private let repository: ActivityRepository
    private let library: LibraryRepository
    private let reconciler: ReadingProgressReconciler
    var records: [ReadingRecord] = []
    var range = "Week"
    var errorMessage: String?

    init(repository: ActivityRepository, library: LibraryRepository) {
        self.repository = repository
        self.library = library
        reconciler = ReadingProgressReconciler(activity: repository, library: library)
        reload()
    }
    var visibleRecords: [ReadingRecord] {
        guard range != "All Time" else { return records }
        let days = range == "Month" ? -30 : -7
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .distantPast
        return records.filter { $0.date >= cutoff }
    }
    var totalMinutes: Int { visibleRecords.reduce(0) { $0 + $1.durationSeconds } / 60 }
    var totalPages: Int { visibleRecords.reduce(0) { $0 + $1.pages } }
    var insight: String {
        let rainy = visibleRecords.filter { $0.weather.localizedCaseInsensitiveContains("rain") }
        let dry = visibleRecords.filter { !$0.weather.localizedCaseInsensitiveContains("rain") }
        guard !rainy.isEmpty, !dry.isEmpty else { return "Complete sessions in different conditions to reveal a useful pattern." }
        let rainyAverage = rainy.reduce(0) { $0 + $1.minutes } / rainy.count
        let dryAverage = dry.reduce(0) { $0 + $1.minutes } / dry.count
        let difference = rainyAverage - dryAverage
        if difference == 0 { return "Your average session length is similar in rainy and dry conditions." }
        let direction = difference > 0 ? "longer" : "shorter"
        return "Your rainy-session average is \(abs(difference)) minutes \(direction) than your dry-session average."
    }
    func book(for record: ReadingRecord) -> Book? { library.books().first { $0.id == record.bookID } }
    @discardableResult
    func save(_ record: ReadingRecord) -> Bool {
        do {
            try reconciler.update(record: record)
            errorMessage = nil
            reload()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    func delete(_ record: ReadingRecord) { reconciler.delete(recordID: record.id); reload() }
    func reload() { records = repository.records() }
}
