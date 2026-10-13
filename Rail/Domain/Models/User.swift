import Foundation

struct User: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var email: String
    var phone: String
    let createdAt: Date

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap(\.first).map(String.init).joined().uppercased()
    }
}

enum Gender: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case male, female, other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .other: "Other"
        }
    }
}

/// A traveller saved to the user's profile for quick reuse.
struct Passenger: Identifiable, Hashable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var age: Int
    var gender: Gender

    var isChild: Bool { age < 12 }
    var summary: String { "\(age) yrs · \(gender.title)" }
}
