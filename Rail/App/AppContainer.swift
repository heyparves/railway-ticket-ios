import Foundation
import Observation
import SwiftData

/// Composition root. Swap the local implementations for API-backed ones here.
@MainActor
@Observable
final class AppContainer {
    let auth: AuthRepository
    let trains: TrainRepository
    let bookings: BookingRepository
    let passengers: PassengerRepository
    let payments: PaymentService

    init(auth: AuthRepository, trains: TrainRepository, bookings: BookingRepository,
         passengers: PassengerRepository, payments: PaymentService) {
        self.auth = auth
        self.trains = trains
        self.bookings = bookings
        self.passengers = passengers
        self.payments = payments
    }

    static func local(modelContainer: ModelContainer, secureStore: SecureStore = KeychainStore()) -> AppContainer {
        let context = modelContainer.mainContext
        let bookings = LocalBookingRepository(context: context)
        return AppContainer(
            auth: LocalAuthRepository(context: context, secureStore: secureStore),
            trains: LocalTrainRepository(bookings: bookings),
            bookings: bookings,
            passengers: LocalPassengerRepository(context: context),
            payments: MockPaymentService()
        )
    }

    /// In-memory container for SwiftUI previews.
    static func preview() -> AppContainer {
        // swiftlint:disable:next force_try
        let container = try! Persistence.makeContainer(inMemory: true)
        return local(modelContainer: container, secureStore: InMemorySecureStore())
    }
}
