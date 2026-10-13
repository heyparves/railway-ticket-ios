import Foundation

/// Simulates a payment gateway. No money moves and no card data is stored.
@MainActor
final class MockPaymentService: PaymentService {
    private let latency: Duration

    init(latency: Duration = .milliseconds(1200)) {
        self.latency = latency
    }

    func charge(amount: Int, method: PaymentMethod, details: PaymentDetails) async throws -> PaymentReceipt {
        try await Task.sleep(for: latency)
        switch details {
        case .wallet(let account):
            guard Validation.isMobile(account) else {
                throw AppError.paymentDeclined("Enter the 11-digit \(method.title) account number.")
            }
        case .card(let number, let expiry, let cvc, _):
            guard Validation.isCardNumber(number.filter(\.isNumber)) else {
                throw AppError.paymentDeclined("Card number is not valid.")
            }
            guard expiry.range(of: #"^(0[1-9]|1[0-2])/\d{2}$"#, options: .regularExpression) != nil,
                  (3...4).contains(cvc.count) else {
                throw AppError.paymentDeclined("Check the expiry date and security code.")
            }
        }
        let reference = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10))
        return PaymentReceipt(method: method, transactionID: "TXN\(reference)", amount: amount)
    }
}
