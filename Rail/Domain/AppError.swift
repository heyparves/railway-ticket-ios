import Foundation

enum AppError: LocalizedError, Equatable {
    case invalidCredentials
    case emailInUse
    case notSignedIn
    case seatsUnavailable([String])
    case bookingNotFound
    case cannotCancel
    case paymentDeclined(String)
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Email or password is incorrect."
        case .emailInUse: "An account with this email already exists."
        case .notSignedIn: "Please sign in to continue."
        case .seatsUnavailable(let seats): "\(seats.joined(separator: ", ")) \(seats.count == 1 ? "was" : "were") just booked by someone else. Please pick other seats."
        case .bookingNotFound: "No ticket matches those details."
        case .cannotCancel: "This ticket can no longer be cancelled."
        case .paymentDeclined(let reason): reason
        case .storage(let reason): "Something went wrong saving your data. \(reason)"
        }
    }
}
