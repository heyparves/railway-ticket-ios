import Foundation

/// Serves the seeded timetable. Seat occupancy is simulated deterministically
/// per train/date/coach and combined with real local bookings.
@MainActor
final class LocalTrainRepository: TrainRepository {
    private let bookings: BookingRepository
    private let trains: [Train]
    private let stationsByCode: [String: Station]
    private let calendar = Calendar.current

    init(bookings: BookingRepository, trains: [Train] = SeedData.trains, stations: [Station] = SeedData.stations) {
        self.bookings = bookings
        self.trains = trains
        self.stationsByCode = Dictionary(uniqueKeysWithValues: stations.map { ($0.code, $0) })
    }

    func stations() async throws -> [Station] {
        stationsByCode.values.sorted { $0.name < $1.name }
    }

    func popularStations() async throws -> [Station] {
        SeedData.popularStationCodes.compactMap { stationsByCode[$0] }
    }

    func search(_ query: SearchQuery) async throws -> [TrainOffer] {
        var offers: [TrainOffer] = []
        for train in trains where train.seatClasses.contains(query.seatClass) {
            guard let offer = try await makeOffer(train: train, from: query.from.code, to: query.to.code,
                                                  boardingDate: query.date, seatClass: query.seatClass,
                                                  passengers: query.passengers),
                  offer.departure > .now else { continue }
            offers.append(offer)
        }
        return offers.sorted { $0.departure < $1.departure }
    }

    func classAvailability(for offer: TrainOffer) async throws -> [ClassAvailability] {
        var result: [ClassAvailability] = []
        for seatClass in offer.train.seatClasses {
            let coaches = try await coaches(train: offer.train, runDate: offer.runDate, seatClass: seatClass)
            result.append(ClassAvailability(
                seatClass: seatClass,
                fare: FarePolicy.fare(for: seatClass, distanceKm: offer.distanceKm),
                availableSeats: coaches.reduce(0) { $0 + $1.availableCount }
            ))
        }
        return result
    }

    func offer(_ offer: TrainOffer, in seatClass: SeatClass) async throws -> TrainOffer? {
        try await makeOffer(train: offer.train, from: offer.from.code, to: offer.to.code,
                            boardingDate: offer.departure, seatClass: seatClass, passengers: offer.passengers)
    }

    func coaches(for offer: TrainOffer) async throws -> [Coach] {
        try await coaches(train: offer.train, runDate: offer.runDate, seatClass: offer.seatClass)
    }

    // MARK: - Offer building

    private func makeOffer(train: Train, from: String, to: String, boardingDate: Date,
                           seatClass: SeatClass, passengers: Int) async throws -> TrainOffer? {
        guard let fromIndex = train.stopIndex(of: from), let toIndex = train.stopIndex(of: to), fromIndex < toIndex,
              let fromStation = stationsByCode[from], let toStation = stationsByCode[to] else { return nil }

        let boardStop = train.stops[fromIndex]
        let alightStop = train.stops[toIndex]
        let boardOffset = boardStop.departureOffset ?? 0

        // A stop reached after midnight belongs to a run that started the day before.
        let dayShift = (train.departureMinutes + boardOffset) / (24 * 60)
        let runDate = boardingDate.startOfDay.adding(days: -dayShift)
        guard !train.offDays.contains(calendar.component(.weekday, from: runDate)),
              let runStart = calendar.date(byAdding: .minute, value: train.departureMinutes, to: runDate) else { return nil }

        let distance = alightStop.distanceKm - boardStop.distanceKm
        let coaches = try await coaches(train: train, runDate: runDate, seatClass: seatClass)
        return TrainOffer(
            train: train, from: fromStation, to: toStation, seatClass: seatClass, passengers: passengers,
            runDate: runDate,
            departure: runStart.addingTimeInterval(TimeInterval(boardOffset * 60)),
            arrival: runStart.addingTimeInterval(TimeInterval((alightStop.arrivalOffset ?? 0) * 60)),
            distanceKm: distance,
            fare: FarePolicy.fare(for: seatClass, distanceKm: distance),
            availableSeats: coaches.reduce(0) { $0 + $1.availableCount }
        )
    }

    // MARK: - Seat inventory

    private func coaches(train: Train, runDate: Date, seatClass: SeatClass) async throws -> [Coach] {
        let booked = try await bookings.bookedSeatIDs(trainNumber: train.number, runDate: runDate, seatClass: seatClass)
        let dateKey = DateKey.string(from: runDate)
        let layout = train.layout(for: seatClass)
        let baseLoad = occupancy(for: runDate, seatClass: seatClass)

        return train.coachNames(for: seatClass).map { name in
            var generator = SeededGenerator(seed: "\(train.number)|\(dateKey)|\(name)")
            let load = min(0.95, max(0.05, baseLoad + Double.random(in: -0.15...0.15, using: &generator)))
            var seats: [Seat] = []
            for row in 0..<layout.rows {
                for column in 0..<layout.columns {
                    let number = row * layout.columns + column + 1
                    let id = "\(name)-\(number)"
                    let simulated = Double.random(in: 0..<1, using: &generator) < load
                    seats.append(Seat(coach: name, number: number, row: row, column: column,
                                      isBooked: simulated || booked.contains(id)))
                }
            }
            return Coach(name: name, seatClass: seatClass, layout: layout, seats: seats)
        }
    }

    /// Trains fill up as the journey approaches; AC classes sell out first.
    private func occupancy(for runDate: Date, seatClass: SeatClass) -> Double {
        let daysAhead = calendar.dateComponents([.day], from: Date.now.startOfDay, to: runDate.startOfDay).day ?? 0
        let urgency = Double(max(0, 7 - daysAhead)) * 0.06
        return 0.3 + urgency + (seatClass.isAirConditioned ? 0.08 : 0)
    }
}
