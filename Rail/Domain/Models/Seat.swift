import Foundation

struct Seat: Identifiable, Hashable, Codable, Sendable {
    let coach: String
    let number: Int
    let row: Int
    let column: Int
    var isBooked: Bool

    /// Seat label as printed on the ticket, e.g. "KA-12".
    var id: String { "\(coach)-\(number)" }
}

struct Coach: Identifiable, Hashable, Sendable {
    let name: String
    let seatClass: SeatClass
    let layout: SeatLayout
    let seats: [Seat]

    var id: String { name }
    var availableCount: Int { seats.filter { !$0.isBooked }.count }

    func seat(row: Int, column: Int) -> Seat? {
        seats.first { $0.row == row && $0.column == column }
    }

    /// Where the seat sits: window/middle/aisle for chairs, lower/upper for berths.
    func spot(of seat: Seat) -> SeatSpot {
        let left = layout.leftColumns
        if seatClass.interior == .berth {
            let local = seat.column < left ? seat.column : seat.column - left
            return local == 0 ? .lower : .upper
        }
        if seat.column == 0 || seat.column == layout.columns - 1 { return .window }
        if seat.column == left - 1 || seat.column == left { return .aisle }
        return .middle
    }

    /// Seats are fixed and face the middle of the coach; cabin rows face each other.
    /// Berths have no facing.
    func facing(row: Int) -> SeatFacing? {
        switch seatClass.interior {
        case .berth: nil
        case .cabin: row.isMultiple(of: 2) ? .back : .front
        case .bench, .recliner: row < layout.rows / 2 ? .back : .front
        }
    }

    /// Short description for labels, e.g. "Window · Faces front".
    func detail(of seat: Seat) -> String {
        [spot(of: seat).title, facing(row: seat.row)?.title].compactMap { $0 }.joined(separator: " · ")
    }
}

enum SeatSpot: Hashable, Sendable {
    case window, middle, aisle, lower, upper

    var title: String {
        switch self {
        case .window: "Window"
        case .middle: "Middle"
        case .aisle: "Aisle"
        case .lower: "Lower"
        case .upper: "Upper"
        }
    }
}

/// Direction a seat faces, relative to the front of the coach.
enum SeatFacing: Hashable, Sendable {
    case front, back

    var title: String { self == .front ? "Faces front" : "Faces back" }
}
