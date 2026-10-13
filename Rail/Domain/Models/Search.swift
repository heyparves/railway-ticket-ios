import Foundation

struct SearchQuery: Hashable, Codable, Sendable {
    var from: Station
    var to: Station
    var date: Date
    var seatClass: SeatClass
    var passengers: Int
}

/// A bookable train segment for a specific date and class.
struct TrainOffer: Identifiable, Hashable, Sendable {
    let train: Train
    let from: Station
    let to: Station
    let seatClass: SeatClass
    let passengers: Int
    /// Date the train leaves its origin; seat inventory is keyed on this.
    let runDate: Date
    let departure: Date
    let arrival: Date
    let distanceKm: Int
    let fare: FareBreakdown
    let availableSeats: Int

    var id: String { "\(train.number)-\(DateKey.string(from: runDate))-\(from.code)-\(to.code)-\(seatClass.rawValue)" }
    var duration: TimeInterval { arrival.timeIntervalSince(departure) }
    var isSoldOut: Bool { availableSeats < passengers }
    var fareTotal: FareTotal { FareTotal(perSeat: fare, seats: passengers) }
}

/// Fare and availability for one class on an offer's segment.
struct ClassAvailability: Identifiable, Hashable, Sendable {
    let seatClass: SeatClass
    let fare: FareBreakdown
    let availableSeats: Int

    var id: SeatClass { seatClass }
}

enum DateKey {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
}
