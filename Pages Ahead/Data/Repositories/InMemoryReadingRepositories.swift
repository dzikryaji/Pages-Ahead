import Foundation

final class InMemoryReadingPlanRepository: ReadingPlanRepository {
    private var session: ReadingPlan?
    func current() -> ReadingPlan? { session }
    func save(_ session: ReadingPlan) { self.session = session }
    func delete(id: UUID) { if session?.id == id { session = nil } }
}

final class InMemoryPersonalizationRepository: PersonalizationRepository {
    private var storage: [PersonalizationEvent] = []
    func events() -> [PersonalizationEvent] { storage }
    func record(_ event: PersonalizationEvent) { storage.append(event) }
    func clear() { storage.removeAll() }
}
