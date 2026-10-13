import Foundation
import SwiftData

/// Profiles live in SwiftData; password hashes and the active session live in the Keychain.
@MainActor
final class LocalAuthRepository: AuthRepository {
    private let context: ModelContext
    private let secureStore: SecureStore
    private static let sessionAccount = "session.userID"

    init(context: ModelContext, secureStore: SecureStore) {
        self.context = context
        self.secureStore = secureStore
    }

    func restoreSession() async throws -> User? {
        guard let data = try secureStore.data(for: Self.sessionAccount),
              let id = UUID(uuidString: String(decoding: data, as: UTF8.self)) else { return nil }
        guard let user = try fetchUser(id: id) else {
            // Keychain survives reinstalls; the database does not.
            try secureStore.remove(Self.sessionAccount)
            return nil
        }
        return user.model
    }

    func signUp(name: String, email: String, phone: String, password: String) async throws -> User {
        let email = normalized(email)
        guard try fetchUser(email: email) == nil else { throw AppError.emailInUse }

        let entity = UserEntity(name: name.trimmed, email: email, phone: phone.trimmed)
        let credential = try JSONEncoder().encode(PasswordHasher.hash(password))
        try secureStore.set(credential, for: credentialAccount(email))
        context.insert(entity)
        try save()
        try startSession(entity.id)
        return entity.model
    }

    func logIn(email: String, password: String) async throws -> User {
        let email = normalized(email)
        guard let entity = try fetchUser(email: email),
              let data = try secureStore.data(for: credentialAccount(email)),
              let stored = try? JSONDecoder().decode(PasswordHash.self, from: data),
              PasswordHasher.verify(password, against: stored) else {
            throw AppError.invalidCredentials
        }
        try startSession(entity.id)
        return entity.model
    }

    func logOut() async throws {
        try secureStore.remove(Self.sessionAccount)
    }

    func updateProfile(_ user: User) async throws -> User {
        guard let entity = try fetchUser(id: user.id) else { throw AppError.notSignedIn }
        entity.name = user.name.trimmed
        entity.phone = user.phone.trimmed
        try save()
        return entity.model
    }

    func deleteAccount(_ user: User) async throws {
        let id = user.id
        guard let entity = try fetchUser(id: id) else { throw AppError.notSignedIn }
        try context.delete(model: SavedPassengerEntity.self, where: #Predicate { $0.ownerID == id })
        try context.delete(model: BookingEntity.self, where: #Predicate { $0.userID == id })
        context.delete(entity)
        try save()
        try secureStore.remove(credentialAccount(entity.email))
        try secureStore.remove(Self.sessionAccount)
    }

    // MARK: - Helpers

    private func startSession(_ id: UUID) throws {
        try secureStore.set(Data(id.uuidString.utf8), for: Self.sessionAccount)
    }

    private func fetchUser(id: UUID) throws -> UserEntity? {
        var descriptor = FetchDescriptor<UserEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchUser(email: String) throws -> UserEntity? {
        var descriptor = FetchDescriptor<UserEntity>(predicate: #Predicate { $0.email == email })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func normalized(_ email: String) -> String { email.trimmed.lowercased() }
    private func credentialAccount(_ email: String) -> String { "credential.\(email)" }

    private func save() throws {
        do { try context.save() } catch { throw AppError.storage(error.localizedDescription) }
    }
}
