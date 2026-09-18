import Foundation

extension Date {
    var readingDay: String { formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
    var readingTime: String { formatted(date: .omitted, time: .shortened) }
}

extension ReadingWindow {
    var readingTimeRange: String {
        "\(start.readingTime)–\(end.readingTime)"
    }
}
