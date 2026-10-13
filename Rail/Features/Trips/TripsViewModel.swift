import Foundation
import Observation

@MainActor
@Observable
final class TripsViewModel {
    enum Segment: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case past = "Past"
        var id: String { rawValue }
    }

    var segment: Segment = .upcoming
    private(set) var bookings: [Booking] = []
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    var upcoming: [Booking] { bookings.filter(\.isUpcoming).sorted { $0.departure < $1.departure } }
    var past: [Booking] { bookings.filter { !$0.isUpcoming }.sorted { $0.departure > $1.departure } }
    var visible: [Booking] { segment == .upcoming ? upcoming : past }

    func load(repository: BookingRepository, user: User?) async {
        guard let user else { return }
        do {
            bookings = try await repository.bookings(for: user)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        hasLoaded = true
    }
}
