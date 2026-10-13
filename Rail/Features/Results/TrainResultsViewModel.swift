import Foundation
import Observation

/// One train on the searched route with an offer for every class it carries.
struct TrainResult: Identifiable, Hashable {
    let train: Train
    /// In the train's coach order.
    let offers: [TrainOffer]

    var id: Int { train.number }
    var departure: Date { offers[0].departure }
    var duration: TimeInterval { offers[0].duration }

    func offer(for seatClass: SeatClass) -> TrainOffer? {
        offers.first { $0.seatClass == seatClass }
    }
}

@MainActor
@Observable
final class TrainResultsViewModel {
    enum State {
        case loading
        case loaded([TrainResult])
        case failed(String)
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case departure = "Departure"
        case fare = "Lowest fare"
        case duration = "Shortest trip"
        case seats = "Most seats"
        var id: String { rawValue }
    }

    var query: SearchQuery {
        didSet { if query.seatClass != oldValue.seatClass { choices = [:] } }
    }
    var sortOrder: SortOrder = .departure
    private(set) var state: State = .loading
    /// Classes the user switched to on individual trains. Others follow `query.seatClass`.
    private var choices: [Int: SeatClass] = [:]

    private let trains: TrainRepository

    init(query: SearchQuery, trains: TrainRepository) {
        self.query = query
        self.trains = trains
    }

    var dates: [Date] {
        let today = Date.now.startOfDay
        return (0..<FarePolicy.bookingWindowDays).map { today.adding(days: $0) }
    }

    /// The offer shown for a train: the user's pick, else the searched class, else the first class with room.
    func offer(for result: TrainResult) -> TrainOffer {
        if let chosen = choices[result.id], let offer = result.offer(for: chosen) { return offer }
        if let offer = result.offer(for: query.seatClass), !offer.isSoldOut { return offer }
        return result.offers.first { !$0.isSoldOut } ?? result.offer(for: query.seatClass) ?? result.offers[0]
    }

    func choose(_ seatClass: SeatClass, for result: TrainResult) {
        choices[result.id] = seatClass
    }

    var results: [TrainResult] {
        guard case .loaded(let results) = state else { return [] }
        switch sortOrder {
        case .departure: return results
        case .fare: return results.sorted { offer(for: $0).fare.perSeat < offer(for: $1).fare.perSeat }
        case .duration: return results.sorted { $0.duration < $1.duration }
        case .seats: return results.sorted { offer(for: $0).availableSeats > offer(for: $1).availableSeats }
        }
    }

    /// Trains that carry the searched class, for the summary line.
    var matchingCount: Int {
        results.filter { $0.offer(for: query.seatClass) != nil }.count
    }

    func load() async {
        state = .loading
        do {
            var byTrain: [Int: [TrainOffer]] = [:]
            for seatClass in SeatClass.allCases {
                var classQuery = query
                classQuery.seatClass = seatClass
                for offer in try await trains.search(classQuery) {
                    byTrain[offer.train.number, default: []].append(offer)
                }
            }
            let results = byTrain.values.map { offers in
                let order = offers[0].train.seatClasses
                return TrainResult(train: offers[0].train,
                                   offers: offers.sorted { (order.firstIndex(of: $0.seatClass) ?? 0) < (order.firstIndex(of: $1.seatClass) ?? 0) })
            }
            state = .loaded(results.sorted { $0.departure < $1.departure })
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
