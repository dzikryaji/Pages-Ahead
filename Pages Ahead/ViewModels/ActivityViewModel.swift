import Foundation
import Observation

enum ActivityRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case allTime = "All Time"

    var id: Self { self }
}

@MainActor @Observable
final class ActivityViewModel {
    private let repository: ActivityRepository
    private let library: LibraryRepository
    private let reconciler: ReadingProgressReconciler
    private let dateProvider: DateProviding
    private var calendar: Calendar
    private var booksByID: [UUID: Book] = [:]
    var records: [ReadingRecord] = []
    var range: ActivityRange = .week
    var errorMessage: String?

    init(
        repository: ActivityRepository,
        library: LibraryRepository,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.library = library
        self.dateProvider = dateProvider ?? SystemDateProvider()
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        self.calendar = mondayCalendar
        reconciler = ReadingProgressReconciler(activity: repository, library: library)
        reload()
    }

    var visibleRecords: [ReadingRecord] {
        records(for: range)
    }

    var totalMinutes: Int { visibleRecords.reduce(0) { $0 + $1.durationSeconds } / 60 }
    var totalPages: Int { visibleRecords.reduce(0) { $0 + $1.pages } }
    var insight: String {
        insight(for: range)
    }

    func records(for range: ActivityRange) -> [ReadingRecord] {
        guard let interval = dateInterval(for: range) else { return records }
        return records.filter { interval.contains($0.date) }
    }

    func totalMinutes(for range: ActivityRange) -> Int {
        records(for: range).reduce(0) { $0 + $1.durationSeconds } / 60
    }

    func totalPages(for range: ActivityRange) -> Int {
        records(for: range).reduce(0) { $0 + $1.pages }
    }

    func periodTitle(for range: ActivityRange) -> String {
        switch range {
        case .week:
            return "This Week"
        case .month:
            return dateProvider.now.formatted(.dateTime.month(.wide))
        case .allTime:
            return range.rawValue
        }
    }

    func insight(for range: ActivityRange) -> String {
        let visibleRecords = records(for: range)
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

    private func dateInterval(for range: ActivityRange) -> DateInterval? {
        switch range {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: dateProvider.now)
        case .month:
            return calendar.dateInterval(of: .month, for: dateProvider.now)
        case .allTime:
            return nil
        }
    }

    func book(for record: ReadingRecord) -> Book? {
        booksByID[record.bookID]
    }
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
    func reload() {
        records = repository.records()
        booksByID = Dictionary(
            library.books().map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
