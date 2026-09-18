import Foundation

enum SampleData {
    static let books: [Book] = [
        Book(id: UUID(uuidString: "77D55E5B-F34E-42A0-A291-A9483884DF62")!, title: "The Left Hand of Darkness", author: "Ursula K. Le Guin", edition: "50th Anniversary Edition", isbn: "9780441478125", pageCount: 304, status: .reading, currentPage: 126),
        Book(id: UUID(uuidString: "AAEB0ED4-E291-403C-B4B0-DB795808BF7C")!, title: "Braiding Sweetgrass", author: "Robin Wall Kimmerer", edition: "First paperback edition", isbn: "9781571313560", pageCount: 408, status: .saved, currentPage: 0),
        Book(id: UUID(uuidString: "433E22EB-98A6-4EAF-B86F-987D138796A0")!, title: "Piranesi", author: "Susanna Clarke", edition: "Bloomsbury edition", isbn: "9781635577808", pageCount: 272, status: .saved, currentPage: 0)
    ]

    static func windows(bookID: UUID) -> [ReadingWindow] {
        let calendar = Calendar.current
        let today = Date()
        let starts = [
            calendar.date(bySettingHour: 18, minute: 30, second: 0, of: today)!,
            calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: today)!)!,
            calendar.date(byAdding: .day, value: 2, to: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)!)!
        ]
        return [
            ReadingWindow(id: UUID(), start: starts[0], durationMinutes: 35, temperature: 24, condition: "Light rain", weatherSymbol: "cloud.rain.fill", place: "Indoors", fitReason: "Your evening is open, and light rain matches your calm indoor preference.", bookID: bookID),
            ReadingWindow(id: UUID(), start: starts[1], durationMinutes: 25, temperature: 22, condition: "Cloudy", weatherSymbol: "cloud.fill", place: "Covered patio", fitReason: "A short open window before your day begins, with mild weather.", bookID: bookID),
            ReadingWindow(id: UUID(), start: starts[2], durationMinutes: 45, temperature: 25, condition: "Clear", weatherSymbol: "moon.stars.fill", place: "Indoors", fitReason: "A longer evening opening near your preferred reading time.", bookID: bookID)
        ]
    }
}
