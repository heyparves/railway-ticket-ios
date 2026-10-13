import Foundation

struct TrainStop: Hashable, Codable, Sendable {
    let station: Station
    /// Minutes after the train leaves its origin. `nil` at the origin.
    let arrivalOffset: Int?
    /// Minutes after the train leaves its origin. `nil` at the terminus.
    let departureOffset: Int?
    let distanceKm: Int

    var stationCode: String { station.code }
}

struct CoachInventory: Hashable, Codable, Sendable {
    let seatClass: SeatClass
    let coachCount: Int
}

struct Train: Identifiable, Hashable, Codable, Sendable {
    let number: Int
    let name: String
    /// Minutes after midnight the train leaves its origin.
    let departureMinutes: Int
    /// Calendar weekdays (1 = Sunday) the train does not run.
    let offDays: Set<Int>
    let stops: [TrainStop]
    let inventory: [CoachInventory]

    var id: Int { number }
    var displayName: String { "\(name) (\(number))" }
    var seatClasses: [SeatClass] { inventory.map(\.seatClass) }

    /// Rajshahi and Khulna line trains run 2 + 3 non-AC coaches.
    var hasThreeAcrossSeating: Bool {
        stops.contains { ["RAJ", "KHL"].contains($0.stationCode) }
    }

    func layout(for seatClass: SeatClass) -> SeatLayout {
        seatClass.layout(threeAcross: hasThreeAcrossSeating)
    }

    func stopIndex(of code: String) -> Int? {
        stops.firstIndex { $0.stationCode == code }
    }

    /// Coach names in train order, e.g. KA, KHA, GA. Classes are assigned
    /// consecutive coaches in the order they appear in `inventory`.
    func coachNames(for seatClass: SeatClass) -> [String] {
        var cursor = 0
        for item in inventory {
            let range = cursor..<(cursor + item.coachCount)
            if item.seatClass == seatClass {
                return range.map { CoachName.at($0) }
            }
            cursor += item.coachCount
        }
        return []
    }
}

enum CoachName {
    static let all = ["KA", "KHA", "GA", "GHA", "UMA", "CHA", "SCHA", "JA", "JHA", "NEO", "TA", "THA", "DA", "DHA", "PA", "FA"]

    /// Bengali letters painted on the coaches, same order as `all`.
    static let bangla = ["ক", "খ", "গ", "ঘ", "ঙ", "চ", "ছ", "জ", "ঝ", "ঞ", "ট", "ঠ", "ড", "ঢ", "প", "ফ"]

    static func at(_ index: Int) -> String {
        index < all.count ? all[index] : "C\(index + 1)"
    }

    /// Bengali letter for a coach name, e.g. "KA" → "ক". Nil for overflow coaches.
    static func letter(for name: String) -> String? {
        all.firstIndex(of: name).map { bangla[$0] }
    }
}
