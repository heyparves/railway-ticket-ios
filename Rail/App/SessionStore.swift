import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    enum Phase: Equatable {
        case launching, signedOut, signedIn
    }

    private(set) var phase: Phase = .launching
    private(set) var user: User?

    private let auth: AuthRepository

    init(auth: AuthRepository) {
        self.auth = auth
    }

    func restore() async {
        guard phase == .launching else { return }
        user = try? await auth.restoreSession()
        phase = user == nil ? .signedOut : .signedIn
    }

    func logIn(email: String, password: String) async throws {
        setSignedIn(try await auth.logIn(email: email, password: password))
    }

    func signUp(name: String, email: String, phone: String, password: String) async throws {
        setSignedIn(try await auth.signUp(name: name, email: email, phone: phone, password: password))
    }

    func update(_ updated: User) async throws {
        user = try await auth.updateProfile(updated)
    }

    func logOut() async {
        try? await auth.logOut()
        user = nil
        phase = .signedOut
    }

    func deleteAccount() async throws {
        guard let user else { return }
        try await auth.deleteAccount(user)
        self.user = nil
        phase = .signedOut
    }

    private func setSignedIn(_ user: User) {
        self.user = user
        phase = .signedIn
    }
}
