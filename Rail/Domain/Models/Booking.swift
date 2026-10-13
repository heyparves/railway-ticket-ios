import Foundation

enum PaymentMethod: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case bkash, nagad, card

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bkash: "bKash"
        case .nagad: "Nagad"
        case .card: "Debit or Credit Card"
        }
    }

    var symbol: String {
        switch self {
        case .bkash, .nagad: "iphone"
        case .card: "creditcard"
        }
    }

    var isWallet: Bool { self != .card }
}

enum BookingStatus: String, Hashable, Codable, Sendable {
    case confirmed, cancelled
}

/// A seat on a ticket. Only the lead traveller is guaranteed to carry details;
/// companions may be booked unnamed, with an empty `name` and no age or gender.
struct TicketPassenger: Hashable, Codable, Sendable {
    let name: String
    let age: Int?
    let gender: Gender?
    let seatID: String

    var isNamed: Bool { !name.isEmpty }

    /// "34 yrs · Female", or whichever parts are known.
    var details: String? {
        let parts = [age.map { "\($0) yrs" }, gender?.title].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct Booking: Identifiable, Hashable, Sendable {
    let id: UUID
    let pnr: String
    let userID: UUID
    let trainNumber: Int
    let trainName: String
    let from: Station
    let to: Station
    let runDate: Date
    let departure: Date
    let arrival: Date
    let seatClass: SeatClass
    let passengers: [TicketPassenger]
    let fare: FareTotal
    let paymentMethod: PaymentMethod
    let transactionID: String
    let contactPhone: String
    let createdAt: Date
    var status: BookingStatus
    var cancelledAt: Date?
    var refundAmount: Int?

    var seatIDs: [String] { passengers.map(\.seatID) }
    var trainDisplayName: String { "\(trainName) (\(trainNumber))" }
    var isUpcoming: Bool { status == .confirmed && departure > .now }
    var canCancel: Bool { isUpcoming }

    /// Payload encoded into the ticket QR code.
    var qrPayload: String {
        "BR|\(pnr)|\(trainNumber)|\(DateKey.string(from: runDate))|\(from.code)-\(to.code)|\(seatClass.code)|\(seatIDs.joined(separator: ","))"
    }
}

/// Everything needed to create a booking once payment succeeds.
struct BookingRequest: Sendable {
    let offer: TrainOffer
    let passengers: [TicketPassenger]
    let contactPhone: String
    let payment: PaymentReceipt
}

struct PaymentReceipt: Hashable, Sendable {
    let method: PaymentMethod
    let transactionID: String
    let amount: Int
}

enum PaymentDetails: Sendable {
    case wallet(accountNumber: String)
    case card(number: String, expiry: String, cvc: String, holder: String)
}
