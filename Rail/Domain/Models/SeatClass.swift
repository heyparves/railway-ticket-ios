import Foundation

enum SeatClass: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case shovan = "SHOVAN"
    case sChair = "S_CHAIR"
    case snigdha = "SNIGDHA"
    case acSeat = "AC_S"
    case acBerth = "AC_B"

    var id: String { rawValue }

    /// Code as printed on Bangladesh Railway tickets.
    var code: String { rawValue }

    var title: String {
        switch self {
        case .shovan: "Shovan"
        case .sChair: "Shovan Chair"
        case .snigdha: "Snigdha"
        case .acSeat: "AC Seat"
        case .acBerth: "AC Berth"
        }
    }

    /// Fits compact pills, e.g. "S. Chair".
    var shortTitle: String { self == .sChair ? "S. Chair" : title }

    /// SF Symbol for the coach climate.
    var symbol: String { isAirConditioned ? "snowflake" : "wind" }

    var summary: String {
        switch self {
        case .shovan: "Non-AC bench seating"
        case .sChair: "Non-AC reclining chair"
        case .snigdha: "AC chair, wider seats"
        case .acSeat: "AC cabin seat"
        case .acBerth: "AC sleeper berth with bedding"
        }
    }

    var isAirConditioned: Bool {
        switch self {
        case .shovan, .sChair: false
        case .snigdha, .acSeat, .acBerth: true
        }
    }

    var seatNoun: String { self == .acBerth ? "berth" : "seat" }

    /// Physical fit-out of the coach. Decides how the seat map is drawn.
    var interior: CoachInterior {
        switch self {
        case .shovan: .bench
        case .sChair, .snigdha: .recliner
        case .acSeat: .cabin
        case .acBerth: .berth
        }
    }

    /// Seat plan for one coach. Non-AC coaches on the Rajshahi and Khulna lines
    /// seat 2 + 3; every other chair and bench coach seats 2 + 2.
    func layout(threeAcross: Bool) -> SeatLayout {
        switch self {
        case .shovan:
            threeAcross ? SeatLayout(leftColumns: 2, rightColumns: 3, rows: 14) : SeatLayout(leftColumns: 2, rightColumns: 2, rows: 16)
        case .sChair:
            threeAcross ? SeatLayout(leftColumns: 2, rightColumns: 3, rows: 13) : SeatLayout(leftColumns: 2, rightColumns: 2, rows: 15)
        case .snigdha: SeatLayout(leftColumns: 2, rightColumns: 2, rows: 13)
        case .acSeat: SeatLayout(leftColumns: 2, rightColumns: 2, rows: 10)
        case .acBerth: SeatLayout(leftColumns: 2, rightColumns: 2, rows: 6)
        }
    }
}

/// Bangladesh Railway coach interiors, from the seat map's point of view.
enum CoachInterior: Hashable, Sendable {
    /// Shovan: fixed benches. Each bench is a plank of seats, not individual chairs.
    case bench
    /// S_CHAIR, SNIGDHA: reclining chairs in rows, split by an aisle.
    case recliner
    /// AC_S: four-seat cabins, one per row, with a partition between sides.
    case cabin
    /// AC_B: sleeper bays, one per row, each bay boxed in.
    case berth

    var title: String {
        switch self {
        case .bench: "Bench"
        case .recliner: "Reclining"
        case .cabin: "Cabin"
        case .berth: "Sleeper bay"
        }
    }
}

struct SeatLayout: Hashable, Sendable {
    let leftColumns: Int
    let rightColumns: Int
    let rows: Int

    var columns: Int { leftColumns + rightColumns }
    var capacity: Int { columns * rows }
}
