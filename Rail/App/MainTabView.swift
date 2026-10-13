import SwiftUI

enum AppTab: Hashable {
    case book, trips, profile
}

struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var selection: AppTab = .book
    @State private var router = SearchRouter()
    @ObserveInjection var inject

    var body: some View {
        TabView(selection: $selection) {
            SearchTab()
                .tabItem { Label("Book", systemImage: "tram.fill") }
                .tag(AppTab.book)
            TripsView()
                .tabItem { Label("My Trips", systemImage: "ticket") }
                .tag(AppTab.trips)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        .environment(router)
        #if DEBUG
        .task {
            if let tab = await DemoSeeder.openRequestedScreen(container: container, session: session, router: router) {
                selection = tab
            }
        }
        #endif
        .sheet(item: $router.confirmedBooking) { booking in
            NavigationStack {
                TicketView(booking: booking, isConfirmation: true) {
                    router.confirmedBooking = nil
                    selection = .trips
                }
            }
        }
        .enableInjection()
    }
}

/// Navigation state for the booking flow, shared so payment can reset the stack.
@MainActor
@Observable
final class SearchRouter {
    var path: [SearchRoute] = []
    var confirmedBooking: Booking?

    func finish(with booking: Booking) {
        path.removeAll()
        confirmedBooking = booking
    }
}

enum SearchRoute: Hashable {
    case results(SearchQuery)
    case detail(TrainOffer)
    case seats(TrainOffer)
    case passengers(BookingDraft)
    case payment(BookingDraft)
}

/// Accumulates choices as the user moves through the booking flow.
struct BookingDraft: Hashable {
    let offer: TrainOffer
    let seats: [Seat]
    var passengers: [TicketPassenger] = []
    var contactPhone: String = ""

    var fare: FareTotal { FareTotal(perSeat: offer.fare, seats: seats.count) }
}

private struct SearchTab: View {
    @Environment(AppContainer.self) private var container
    @Environment(SearchRouter.self) private var router
    @ObserveInjection var inject

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            SearchView(trains: container.trains)
                .navigationDestination(for: SearchRoute.self, destination: destination)
        }
        .enableInjection()
    }

    @ViewBuilder
    private func destination(_ route: SearchRoute) -> some View {
        switch route {
        case .results(let query):
            TrainResultsView(query: query, trains: container.trains)
        // Checkout screens own the bottom edge with their primary action.
        case .detail(let offer):
            TrainDetailView(offer: offer, trains: container.trains)
                .toolbar(.hidden, for: .tabBar)
        case .seats(let offer):
            SeatSelectionView(offer: offer, trains: container.trains)
                .toolbar(.hidden, for: .tabBar)
        case .passengers(let draft):
            PassengerDetailsView(draft: draft, repository: container.passengers)
                .toolbar(.hidden, for: .tabBar)
        case .payment(let draft):
            PaymentView(draft: draft, payments: container.payments, bookings: container.bookings)
                .toolbar(.hidden, for: .tabBar)
        }
    }
}
