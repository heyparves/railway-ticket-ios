import Foundation
import Observation

@MainActor
@Observable
final class SeatSelectionViewModel {
    let offer: TrainOffer
    private(set) var coaches: [Coach] = []
    var selectedCoachName: String?
    private(set) var selected: [Seat] = []
    private(set) var isLoading = true
    private(set) var limitReachedCount = 0
    private(set) var togetherFailureCount = 0
    private(set) var togetherNotice: String?
    private(set) var errorMessage: String?

    private let trains: TrainRepository

    init(offer: TrainOffer, trains: TrainRepository) {
        self.offer = offer
        self.trains = trains
    }

    /// Highlights matching seats on the map and steers auto-pick. Nil means any seat.
    var preference: SeatSpot?

    var selectedCoach: Coach? { coaches.first { $0.name == selectedCoachName } }
    var preferenceOptions: [SeatSpot] { offer.seatClass.interior == .berth ? [.lower, .upper] : [.window, .aisle] }

    func coach(of seat: Seat) -> Coach? { coaches.first { $0.name == seat.coach } }

    /// e.g. "Window · Faces front".
    func detail(of seat: Seat) -> String { coach(of: seat)?.detail(of: seat) ?? "" }

    /// Shows the seat's coach on the map.
    func reveal(_ seat: Seat) { selectedCoachName = seat.coach }
    var selectedIDs: Set<String> { Set(selected.map(\.id)) }
    /// Most seats one booking can hold. The rider picks any number from one up to this.
    var maxSeats: Int { FarePolicy.maxPassengers }
    var canContinue: Bool { !selected.isEmpty }
    var fare: FareTotal { FareTotal(perSeat: offer.fare, seats: max(selected.count, 1)) }

    var draft: BookingDraft { BookingDraft(offer: offer, seats: selected) }

    func selectedCount(in coach: Coach) -> Int {
        selected.filter { $0.coach == coach.name }.count
    }

    /// Loads (or refreshes) seat maps. Keeps the current selection unless a seat was taken meanwhile.
    func load() async {
        do {
            coaches = try await trains.coaches(for: offer)
            let booked = Set(coaches.flatMap(\.seats).filter(\.isBooked).map(\.id))
            selected.removeAll { booked.contains($0.id) }
            if selectedCoachName == nil {
                selectedCoachName = coaches.max { $0.availableCount < $1.availableCount }?.name
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggle(_ seat: Seat) {
        guard !seat.isBooked else { return }
        if let index = selected.firstIndex(where: { $0.id == seat.id }) {
            selected.remove(at: index)
        } else if selected.count < maxSeats {
            selected.append(seat)
        } else {
            limitReachedCount += 1
        }
    }

    /// Picks `count` free seats side by side. Tries the chosen coach first, then the rest.
    /// Same side of the aisle wins over a run across the aisle. A single seat follows `preference`.
    func suggestTogether(_ count: Int) {
        let required = min(max(count, 1), maxSeats)
        let ordered = (selectedCoach.map { [$0] } ?? []) + coaches.filter { $0.name != selectedCoachName }
        if required == 1 {
            let wanted = preference.map { [$0, nil] } ?? [nil]
            for spot in wanted {
                for coach in ordered {
                    guard let seat = coach.seats.first(where: { !$0.isBooked && (spot == nil || coach.spot(of: $0) == spot) }) else { continue }
                    selectedCoachName = coach.name
                    selected = [seat]
                    togetherNotice = nil
                    return
                }
            }
        }
        for allowAisle in [false, true] {
            for coach in ordered {
                guard let run = Self.freeRun(in: coach, length: required, allowAisle: allowAisle) else { continue }
                selectedCoachName = coach.name
                selected = run
                togetherNotice = nil
                return
            }
        }
        togetherFailureCount += 1
        togetherNotice = "No \(required) free \(offer.seatClass.seatNoun)s side by side in any coach. Try picking them yourself."
    }

    /// First row, front to back, with `length` free seats in a row. Without `allowAisle`, the run stays on one side of the aisle.
    private static func freeRun(in coach: Coach, length: Int, allowAisle: Bool) -> [Seat]? {
        let layout = coach.layout
        let sides = allowAisle ? [0..<layout.columns] : [0..<layout.leftColumns, layout.leftColumns..<layout.columns]
        for row in 0..<layout.rows {
            for side in sides {
                var run: [Seat] = []
                for column in side {
                    guard let seat = coach.seat(row: row, column: column), !seat.isBooked else {
                        run.removeAll()
                        continue
                    }
                    run.append(seat)
                    if run.count == length { return run }
                }
            }
        }
        return nil
    }
}
