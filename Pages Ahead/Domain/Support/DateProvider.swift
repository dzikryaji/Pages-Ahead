import Foundation

protocol DateProviding: Sendable {
    var now: Date { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date { .now }
}

struct FixedDateProvider: DateProviding {
    let now: Date
}
