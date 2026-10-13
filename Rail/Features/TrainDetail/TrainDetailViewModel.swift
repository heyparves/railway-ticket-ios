import Foundation
import Observation

@MainActor
@Observable
final class TrainDetailViewModel {
    struct RouteStop: Identifiable {
        enum Role { case before, board, between, alight, after }

        let station: Station
        let time: Date
        let arrival: Date?
        let departure: Date?
        let role: Role
        let isFirst: Bool
        let isLast: Bool

        var id: String { station.code }
        var isInJourney: Bool { [.board, .between, .alight].contains(role) }
        var haltMinutes: Int? {
            guard let arrival, let departure else { return nil }
            return Int(departure.timeIntervalSince(arrival) / 60)
        }
    }

    private(set) var offer: TrainOffer
    private(set) var classes: [ClassAvailability] = []
    private(set) var isSwitchingClass = false

    private let trains: TrainRepository

    init(offer: TrainOffer, trains: TrainRepository) {
        self.offer = offer
        self.trains = trains
    }

    var train: Train { offer.train }

    var runsText: String {
        guard !train.offDays.isEmpty else { return "Runs daily" }
        let names = Calendar.current.weekdaySymbols
        let off = train.offDays.sorted().map { names[$0 - 1] }
        return "Off day: \(off.formatted(.list(type: .and)))"
    }

    var route: [RouteStop] {
        let calendar = Calendar.current
        guard let runStart = calendar.date(byAdding: .minute, value: train.departureMinutes, to: offer.runDate),
              let boardIndex = train.stopIndex(of: offer.from.code),
              let alightIndex = train.stopIndex(of: offer.to.code) else { return [] }

        func date(_ offset: Int?) -> Date? {
            offset.map { runStart.addingTimeInterval(TimeInterval($0 * 60)) }
        }

        return train.stops.enumerated().compactMap { index, stop in
            guard let time = date(stop.departureOffset ?? stop.arrivalOffset) else { return nil }
            let role: RouteStop.Role = switch index {
            case ..<boardIndex: .before
            case boardIndex: .board
            case alightIndex: .alight
            case (alightIndex + 1)...: .after
            default: .between
            }
            return RouteStop(station: stop.station,
                             time: role == .alight ? (date(stop.arrivalOffset) ?? time) : time,
                             arrival: date(stop.arrivalOffset), departure: date(stop.departureOffset),
                             role: role, isFirst: index == 0, isLast: index == train.stops.count - 1)
        }
    }

    func load() async {
        classes = (try? await trains.classAvailability(for: offer)) ?? []
    }

    func select(_ seatClass: SeatClass) async {
        guard seatClass != offer.seatClass else { return }
        isSwitchingClass = true
        defer { isSwitchingClass = false }
        if let updated = try? await trains.offer(offer, in: seatClass) {
            offer = updated
        }
    }
}
