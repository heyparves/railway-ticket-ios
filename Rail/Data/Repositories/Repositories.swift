import Foundation

// Every screen talks to data through these protocols. The app ships with
// local implementations (SwiftData + Keychain + seed data); swap in API-backed
// types in `AppContainer` when a backend is available.

@MainActor
protocol AuthRepository: AnyObject {
    func restoreSession() async throws -> User?
    func signUp(name: String, email: String, phone: String, password: String) async throws -> User
    func logIn(email: String, password: String) async throws -> User
    func logOut() async throws
    func updateProfile(_ user: User) async throws -> User
    func deleteAccount(_ user: User) async throws
}

@MainActor
protocol TrainRepository: AnyObject {
    func stations() async throws -> [Station]
    func popularStations() async throws -> [Station]
    func search(_ query: SearchQuery) async throws -> [TrainOffer]
    func classAvailability(for offer: TrainOffer) async throws -> [ClassAvailability]
    func offer(_ offer: TrainOffer, in seatClass: SeatClass) async throws -> TrainOffer?
    func coaches(for offer: TrainOffer) async throws -> [Coach]
}

@MainActor
protocol BookingRepository: AnyObject {
    func book(_ request: BookingRequest, for user: User) async throws -> Booking
    func bookings(for user: User) async throws -> [Booking]
    func cancel(_ booking: Booking) async throws -> Booking
    func bookedSeatIDs(trainNumber: Int, runDate: Date, seatClass: SeatClass) async throws -> Set<String>
    func verify(pnr: String, phone: String) async throws -> Booking
}

@MainActor
protocol PassengerRepository: AnyObject {
    func passengers(for user: User) async throws -> [Passenger]
    func save(_ passenger: Passenger, for user: User) async throws
    func delete(_ passenger: Passenger, for user: User) async throws
}

@MainActor
protocol PaymentService: AnyObject {
    func charge(amount: Int, method: PaymentMethod, details: PaymentDetails) async throws -> PaymentReceipt
}
