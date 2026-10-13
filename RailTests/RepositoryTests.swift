import Foundation
import SwiftData
import Testing
@testable import Rail

@MainActor
struct RepositoryTests {
    let container: AppContainer
    let modelContainer: ModelContainer

    init() throws {
        modelContainer = try Persistence.makeContainer(inMemory: true)
        container = AppContainer.local(modelContainer: modelContainer, secureStore: InMemorySecureStore())
    }

    private var dhaka: Station { SeedData.stationsByCode["DHK"]! }
    private var chattogram: Station { SeedData.stationsByCode["CTG"]! }

    /// A date a few days out that isn't an off day for most trains.
    private var journeyDate: Date { Date.now.startOfDay.adding(days: 3) }

    // MARK: Auth

    @Test func signUpLogInAndLogOut() async throws {
        let user = try await container.auth.signUp(name: "Rahim Uddin", email: "Rahim@Example.com ", phone: "01811112222", password: "password1")
        #expect(user.email == "rahim@example.com")
        #expect(try await container.auth.restoreSession()?.id == user.id)

        try await container.auth.logOut()
        #expect(try await container.auth.restoreSession() == nil)

        await #expect(throws: AppError.invalidCredentials) {
            try await container.auth.logIn(email: "rahim@example.com", password: "wrong-pass")
        }
        let again = try await container.auth.logIn(email: "RAHIM@example.com", password: "password1")
        #expect(again.id == user.id)
    }

    @Test func duplicateEmailIsRejected() async throws {
        _ = try await container.auth.signUp(name: "A B", email: "a@b.com", phone: "01811112222", password: "password1")
        await #expect(throws: AppError.emailInUse) {
            try await container.auth.signUp(name: "C D", email: "A@B.com", phone: "01811113333", password: "password2")
        }
    }

    // MARK: Search

    @Test func searchFindsDhakaChattogramTrains() async throws {
        let query = SearchQuery(from: dhaka, to: chattogram, date: journeyDate, seatClass: .sChair, passengers: 2)
        let offers = try await container.trains.search(query)
        #expect(!offers.isEmpty)
        #expect(offers.allSatisfy { $0.from == dhaka && $0.to == chattogram && $0.departure < $0.arrival })
        #expect(offers.map(\.departure) == offers.map(\.departure).sorted())
    }

    @Test func searchRespectsDirection() async throws {
        let query = SearchQuery(from: chattogram, to: dhaka, date: journeyDate, seatClass: .sChair, passengers: 1)
        let offers = try await container.trains.search(query)
        #expect(!offers.isEmpty)
        #expect(offers.allSatisfy { $0.train.stopIndex(of: "CTG")! < $0.train.stopIndex(of: "DHK")! })
    }

    @Test func seatMapIsDeterministic() async throws {
        let query = SearchQuery(from: dhaka, to: chattogram, date: journeyDate, seatClass: .snigdha, passengers: 1)
        let offer = try #require(try await container.trains.search(query).first)
        let first = try await container.trains.coaches(for: offer)
        let second = try await container.trains.coaches(for: offer)
        #expect(first == second)
        #expect(first.count == offer.train.coachNames(for: .snigdha).count)
    }

    @Test func suggestTogetherPicksAdjacentFreeSeats() async throws {
        let query = SearchQuery(from: dhaka, to: chattogram, date: journeyDate, seatClass: .sChair, passengers: 2)
        let offer = try #require(try await container.trains.search(query).first)
        let model = SeatSelectionViewModel(offer: offer, trains: container.trains)
        await model.load()

        model.suggestTogether(2)
        #expect(model.selected.count == 2)
        #expect(Set(model.selected.map(\.coach)).count == 1)
        #expect(Set(model.selected.map(\.row)).count == 1)
        #expect(model.togetherNotice == nil)
    }

    // MARK: Booking

    @Test func bookingMarksSeatsTakenAndCanBeCancelled() async throws {
        let user = try await container.auth.signUp(name: "Karim Ali", email: "k@a.com", phone: "01911112222", password: "password1")
        let query = SearchQuery(from: dhaka, to: chattogram, date: journeyDate, seatClass: .acSeat, passengers: 1)
        let offer = try #require(try await container.trains.search(query).first { !$0.isSoldOut })
        let seat = try #require(try await container.trains.coaches(for: offer).flatMap(\.seats).first { !$0.isBooked })

        let receipt = PaymentReceipt(method: .bkash, transactionID: "TXN1", amount: 0)
        let request = BookingRequest(offer: offer,
                                     passengers: [TicketPassenger(name: "Karim Ali", age: 34, gender: .male, seatID: seat.id)],
                                     contactPhone: user.phone, payment: receipt)
        let booking = try await container.bookings.book(request, for: user)
        #expect(booking.pnr.hasPrefix("BR"))

        let coaches = try await container.trains.coaches(for: offer)
        #expect(coaches.flatMap(\.seats).first { $0.id == seat.id }?.isBooked == true)

        await #expect(throws: AppError.seatsUnavailable([seat.id])) {
            try await container.bookings.book(request, for: user)
        }

        let verified = try await container.bookings.verify(pnr: booking.pnr.lowercased(), phone: user.phone)
        #expect(verified.id == booking.id)

        let cancelled = try await container.bookings.cancel(booking)
        #expect(cancelled.status == .cancelled)
        #expect(cancelled.refundAmount != nil)
        let freed = try await container.bookings.bookedSeatIDs(trainNumber: offer.train.number, runDate: offer.runDate, seatClass: .acSeat)
        #expect(!freed.contains(seat.id))
    }

    @Test func savedPassengersAreScopedToUser() async throws {
        let user = try await container.auth.signUp(name: "One User", email: "one@x.com", phone: "01711112222", password: "password1")
        let other = try await container.auth.signUp(name: "Two User", email: "two@x.com", phone: "01711113333", password: "password1")
        try await container.passengers.save(Passenger(name: "Mother", age: 60, gender: .female), for: user)
        #expect(try await container.passengers.passengers(for: user).count == 1)
        #expect(try await container.passengers.passengers(for: other).isEmpty)
    }
}
