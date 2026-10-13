import Foundation
import SwiftData

@MainActor
final class LocalPassengerRepository: PassengerRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func passengers(for user: User) async throws -> [Passenger] {
        let ownerID = user.id
        let descriptor = FetchDescriptor<SavedPassengerEntity>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).map(\.model)
    }

    func save(_ passenger: Passenger, for user: User) async throws {
        let id = passenger.id
        let descriptor = FetchDescriptor<SavedPassengerEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.apply(passenger)
        } else {
            context.insert(SavedPassengerEntity(passenger, ownerID: user.id))
        }
        try context.save()
    }

    func delete(_ passenger: Passenger, for user: User) async throws {
        let id = passenger.id
        let ownerID = user.id
        try context.delete(model: SavedPassengerEntity.self, where: #Predicate { $0.id == id && $0.ownerID == ownerID })
        try context.save()
    }
}
