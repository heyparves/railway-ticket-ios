#if DEBUG
import Foundation

/// Debug-only launch arguments for demos and UI tests:
/// `-demo` skips onboarding and signs in demo@rail.app / railpass1.
/// `-demoScreen <results|detail|seats|passengers|payment|ticket|trips|profile>` jumps to a screen.
@MainActor
enum DemoSeeder {
    static let email = "demo@rail.app"
    static let password = "railpass1"

    static func applyLaunchArguments(container: AppContainer, session: SessionStore) async {
        guard ProcessInfo.processInfo.arguments.contains("-demo") else { return }
        UserDefaults.standard.set(true, forKey: AppStorageKey.hasCompletedOnboarding)
        if (try? await container.auth.logIn(email: email, password: password)) == nil {
            _ = try? await container.auth.signUp(name: "Parves", email: email, phone: "01712345678", password: password)
        }
    }

    static var requestedScreen: String? { argument("-demoScreen") }

    /// Value following `flag` in the launch arguments, e.g. `-demoTo RAJ`, `-demoClass S_CHAIR`.
    private static func argument(_ flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Builds navigation state for `-demoScreen`. Returns the tab to select.
    static func openRequestedScreen(container: AppContainer, session: SessionStore, router: SearchRouter) async -> AppTab? {
        guard let screen = requestedScreen, let user = session.user,
              let from = try? await container.trains.stations().first(where: { $0.code == "DHK" }),
              let to = try? await container.trains.stations().first(where: { $0.code == (argument("-demoTo") ?? "CTG") }) else { return nil }

        switch screen {
        case "trips": _ = await makeBooking(container: container, user: user, from: from, to: to); return .trips
        case "profile": return .profile
        default: break
        }

        let query = SearchQuery(from: from, to: to, date: Date.now.startOfDay.adding(days: 2), seatClass: argument("-demoClass").flatMap(SeatClass.init) ?? .snigdha, passengers: 2)
        guard let offer = try? await container.trains.search(query).first(where: { !$0.isSoldOut }) else { return .book }
        let seats = Array(((try? await container.trains.coaches(for: offer)) ?? []).flatMap(\.seats).filter { !$0.isBooked }.prefix(2))
        var draft = BookingDraft(offer: offer, seats: seats)
        draft.passengers = seats.enumerated().map {
            TicketPassenger(name: $0.offset == 0 ? user.name : "Arif Hossain", age: $0.offset == 0 ? 25 : 33,
                            gender: .male, seatID: $0.element.id)
        }
        draft.contactPhone = user.phone

        switch screen {
        case "results": router.path = [.results(query)]
        case "detail": router.path = [.results(query), .detail(offer)]
        case "seats": router.path = [.results(query), .detail(offer), .seats(offer)]
        case "passengers": router.path = [.results(query), .detail(offer), .seats(offer), .passengers(draft)]
        case "payment": router.path = [.results(query), .detail(offer), .seats(offer), .passengers(draft), .payment(draft)]
        case "ticket": router.confirmedBooking = await makeBooking(container: container, user: user, from: from, to: to)
        default: break
        }
        return .book
    }

    private static func makeBooking(container: AppContainer, user: User, from: Station, to: Station) async -> Booking? {
        let query = SearchQuery(from: from, to: to, date: Date.now.startOfDay.adding(days: 3), seatClass: .acSeat, passengers: 2)
        guard let offer = try? await container.trains.search(query).first(where: { !$0.isSoldOut }) else { return nil }
        let seats = ((try? await container.trains.coaches(for: offer)) ?? []).flatMap(\.seats).filter { !$0.isBooked }.prefix(2)
        let passengers = seats.enumerated().map {
            TicketPassenger(name: $0.offset == 0 ? user.name : "Arif Hossain", age: $0.offset == 0 ? 25 : 33,
                            gender: .male, seatID: $0.element.id)
        }
        let receipt = PaymentReceipt(method: .bkash, transactionID: "TXNDEMO\(Int.random(in: 1000...9999))", amount: 0)
        let request = BookingRequest(offer: offer, passengers: passengers, contactPhone: user.phone, payment: receipt)
        return try? await container.bookings.book(request, for: user)
    }
}
#endif
