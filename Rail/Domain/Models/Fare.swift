import Foundation

/// Per-seat fare in whole taka.
struct FareBreakdown: Hashable, Codable, Sendable {
    let base: Int
    let vat: Int
    let bedding: Int

    var perSeat: Int { base + vat + bedding }
}

/// Totals for a whole booking.
struct FareTotal: Hashable, Codable, Sendable {
    let perSeat: FareBreakdown
    let seats: Int
    let serviceCharge: Int

    var base: Int { perSeat.base * seats }
    var vat: Int { perSeat.vat * seats }
    var bedding: Int { perSeat.bedding * seats }
    var fare: Int { perSeat.perSeat * seats }
    var total: Int { fare + serviceCharge }

    init(perSeat: FareBreakdown, seats: Int) {
        self.perSeat = perSeat
        self.seats = seats
        self.serviceCharge = FarePolicy.serviceChargePerSeat * seats
    }
}

enum FarePolicy {
    static let serviceChargePerSeat = 20
    static let beddingCharge = 50
    static let vatRate = 0.15
    static let maxPassengers = 4
    /// Tickets open this many days ahead, including today.
    static let bookingWindowDays = 10

    static func ratePerKm(_ seatClass: SeatClass) -> Double {
        switch seatClass {
        case .shovan: 0.85
        case .sChair: 1.05
        case .snigdha: 1.95
        case .acSeat: 2.35
        case .acBerth: 3.45
        }
    }

    static func fare(for seatClass: SeatClass, distanceKm: Int) -> FareBreakdown {
        let base = max(30, Int((ratePerKm(seatClass) * Double(distanceKm)).rounded()))
        let vat = seatClass.isAirConditioned ? Int((Double(base) * vatRate).rounded()) : 0
        let bedding = seatClass == .acBerth ? beddingCharge : 0
        return FareBreakdown(base: base, vat: vat, bedding: bedding)
    }
}

enum RefundPolicy {
    /// Refund for a confirmed booking cancelled at `date`. Service charge is never refunded.
    static func refund(for fare: FareTotal, departure: Date, at date: Date = .now) -> Int? {
        let hours = departure.timeIntervalSince(date) / 3600
        guard hours > 0 else { return nil }
        let ratio: Double = switch hours {
        case 48...: 0.9
        case 12..<48: 0.75
        default: 0.5
        }
        return Int((Double(fare.fare) * ratio).rounded())
    }
}
