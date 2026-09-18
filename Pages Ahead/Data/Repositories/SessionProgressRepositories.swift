import Foundation

final class UserDefaultsSessionProgressRepository: SessionProgressRepository {
    private let defaults: UserDefaults
    private let key = "activeReadingSession"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func loadCurrent() -> ActiveReadingSession? {
        guard let data = defaults.data(forKey: key),
              let session = try? JSONDecoder().decode(ActiveReadingSession.self, from: data) else { return nil }
        return session
    }
    func save(_ session: ActiveReadingSession) { defaults.set(try? JSONEncoder().encode(session), forKey: key) }
    func clear() { defaults.removeObject(forKey: key) }
}

final class InMemorySessionProgressRepository: SessionProgressRepository {
    private var session: ActiveReadingSession?
    func loadCurrent() -> ActiveReadingSession? { session }
    func save(_ session: ActiveReadingSession) { self.session = session }
    func clear() { session = nil }
}
