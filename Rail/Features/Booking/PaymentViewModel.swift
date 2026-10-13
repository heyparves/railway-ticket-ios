import Foundation
import Observation

@MainActor
@Observable
final class PaymentViewModel {
    let draft: BookingDraft
    var method: PaymentMethod = .bkash
    var walletNumber: String
    var cardNumber = ""
    var cardExpiry = ""
    var cardCVC = ""
    var cardHolder = ""
    private(set) var isProcessing = false
    var errorMessage: String?

    private let payments: PaymentService
    private let bookings: BookingRepository

    init(draft: BookingDraft, payments: PaymentService, bookings: BookingRepository) {
        self.draft = draft
        self.payments = payments
        self.bookings = bookings
        walletNumber = draft.contactPhone
    }

    var fare: FareTotal { draft.fare }

    var canPay: Bool {
        guard !isProcessing else { return false }
        switch method {
        case .bkash, .nagad:
            return Validation.isMobile(walletNumber)
        case .card:
            return cardNumber.filter(\.isNumber).count >= 13 && cardExpiry.count == 5
                && (3...4).contains(cardCVC.count) && Validation.isName(cardHolder)
        }
    }

    /// Groups card digits in fours as the user types.
    func formatCardNumber() {
        let digits = String(cardNumber.filter(\.isNumber).prefix(19))
        let grouped = stride(from: 0, to: digits.count, by: 4).map {
            let start = digits.index(digits.startIndex, offsetBy: $0)
            let end = digits.index(start, offsetBy: 4, limitedBy: digits.endIndex) ?? digits.endIndex
            return String(digits[start..<end])
        }.joined(separator: " ")
        if grouped != cardNumber { cardNumber = grouped }
    }

    /// Keeps expiry in MM/YY form.
    func formatExpiry() {
        let digits = String(cardExpiry.filter(\.isNumber).prefix(4))
        let formatted = digits.count > 2 ? "\(digits.prefix(2))/\(digits.dropFirst(2))" : digits
        if formatted != cardExpiry { cardExpiry = formatted }
    }

    func formatCVC() {
        let digits = String(cardCVC.filter(\.isNumber).prefix(4))
        if digits != cardCVC { cardCVC = digits }
    }

    func pay(for user: User?) async -> Booking? {
        guard canPay, let user else { return nil }
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            // Re-check seats before charging so a conflict never takes money.
            let offer = draft.offer
            let taken = try await bookings.bookedSeatIDs(trainNumber: offer.train.number, runDate: offer.runDate, seatClass: offer.seatClass)
            let conflicts = draft.passengers.map(\.seatID).filter(taken.contains)
            guard conflicts.isEmpty else { throw AppError.seatsUnavailable(conflicts) }

            let details: PaymentDetails = method.isWallet
                ? .wallet(accountNumber: walletNumber.trimmed)
                : .card(number: cardNumber, expiry: cardExpiry, cvc: cardCVC, holder: cardHolder.trimmed)
            let receipt = try await payments.charge(amount: fare.total, method: method, details: details)
            let request = BookingRequest(offer: offer, passengers: draft.passengers, contactPhone: draft.contactPhone, payment: receipt)
            return try await bookings.book(request, for: user)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
