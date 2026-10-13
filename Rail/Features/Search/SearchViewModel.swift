import Foundation
import Observation

struct RecentRoute: Codable, Hashable, Identifiable {
    let from: Station
    let to: Station

    var id: String { "\(from.code)-\(to.code)" }
}

@MainActor
@Observable
final class SearchViewModel {
    enum Endpoint: String, Identifiable {
        case from, to
        var id: String { rawValue }
        var title: String { self == .from ? "From" : "To" }
    }

    var from: Station?
    var to: Station?
    var date: Date = Date.now.startOfDay
    var seatClass: SeatClass
    var picking: Endpoint?

    private(set) var stations: [Station] = []
    private(set) var popularStations: [Station] = []
    private(set) var recentRoutes: [RecentRoute] = []

    private let trains: TrainRepository
    private let defaults: UserDefaults

    init(trains: TrainRepository, defaults: UserDefaults = .standard) {
        self.trains = trains
        self.defaults = defaults
        seatClass = defaults.string(forKey: AppStorageKey.defaultSeatClass).flatMap(SeatClass.init) ?? .sChair
        recentRoutes = Self.loadRecents(defaults)
        if let last = recentRoutes.first {
            from = last.from
            to = last.to
        }
    }

    var dateRange: ClosedRange<Date> {
        let today = Date.now.startOfDay
        return today...today.adding(days: FarePolicy.bookingWindowDays - 1)
    }

    var canSearch: Bool {
        guard let from, let to else { return false }
        return from != to
    }

    func load() async {
        guard stations.isEmpty else { return }
        stations = (try? await trains.stations()) ?? []
        popularStations = (try? await trains.popularStations()) ?? []
    }

    func select(_ station: Station, for endpoint: Endpoint) {
        switch endpoint {
        case .from:
            if station == to { to = from }
            from = station
        case .to:
            if station == from { from = to }
            to = station
        }
    }

    func swap() {
        (from, to) = (to, from)
    }

    func apply(_ route: RecentRoute) {
        from = route.from
        to = route.to
    }

    func makeQuery() -> SearchQuery? {
        guard canSearch, let from, let to else { return nil }
        let date = min(max(date.startOfDay, dateRange.lowerBound), dateRange.upperBound)
        remember(RecentRoute(from: from, to: to))
        return SearchQuery(from: from, to: to, date: date, seatClass: seatClass, passengers: 1)
    }

    func clearRecents() {
        recentRoutes = []
        defaults.removeObject(forKey: AppStorageKey.recentRoutes)
    }

    private func remember(_ route: RecentRoute) {
        recentRoutes.removeAll { $0 == route }
        recentRoutes.insert(route, at: 0)
        recentRoutes = Array(recentRoutes.prefix(4))
        if let data = try? JSONEncoder().encode(recentRoutes) {
            defaults.set(data, forKey: AppStorageKey.recentRoutes)
        }
    }

    private static func loadRecents(_ defaults: UserDefaults) -> [RecentRoute] {
        guard let data = defaults.data(forKey: AppStorageKey.recentRoutes) else { return [] }
        return (try? JSONDecoder().decode([RecentRoute].self, from: data)) ?? []
    }
}
