import Foundation

/// Static network used by the local repositories. Timetables are modelled on
/// published Bangladesh Railway intercity schedules and rounded for the demo.
enum SeedData {
    static let stations: [Station] = [
        Station(code: "DHK", name: "Dhaka"),
        Station(code: "DAP", name: "Dhaka Airport"),
        Station(code: "JDP", name: "Joydebpur"),
        Station(code: "NSD", name: "Narsingdi"),
        Station(code: "BRB", name: "Bhairab Bazar"),
        Station(code: "BBA", name: "Brahmanbaria"),
        Station(code: "AKH", name: "Akhaura"),
        Station(code: "CML", name: "Cumilla"),
        Station(code: "LKM", name: "Laksam"),
        Station(code: "FEN", name: "Feni"),
        Station(code: "CTG", name: "Chattogram"),
        Station(code: "CXB", name: "Cox's Bazar"),
        Station(code: "SHG", name: "Shaistaganj"),
        Station(code: "SRM", name: "Srimangal"),
        Station(code: "KLR", name: "Kulaura"),
        Station(code: "SYL", name: "Sylhet"),
        Station(code: "TGL", name: "Tangail"),
        Station(code: "ULP", name: "Ullapara"),
        Station(code: "IWD", name: "Ishwardi"),
        Station(code: "ABP", name: "Abdulpur"),
        Station(code: "RAJ", name: "Rajshahi"),
        Station(code: "BNG", name: "Bhanga"),
        Station(code: "FRD", name: "Faridpur"),
        Station(code: "RJB", name: "Rajbari"),
        Station(code: "JSR", name: "Jashore"),
        Station(code: "NWP", name: "Noapara"),
        Station(code: "KHL", name: "Khulna"),
        Station(code: "SNH", name: "Santahar"),
        Station(code: "JPH", name: "Joypurhat"),
        Station(code: "PBT", name: "Parbatipur"),
        Station(code: "DNJ", name: "Dinajpur"),
        Station(code: "BGR", name: "Bogura"),
        Station(code: "RNG", name: "Rangpur"),
        Station(code: "GBD", name: "Gaibandha"),
        Station(code: "KAU", name: "Kaunia"),
        Station(code: "LMH", name: "Lalmonirhat"),
        Station(code: "MYM", name: "Mymensingh"),
        Station(code: "JMP", name: "Jamalpur"),
        Station(code: "DWG", name: "Dewanganj Bazar"),
    ]

    static let popularStationCodes = ["DHK", "CTG", "SYL", "RAJ", "KHL", "CXB"]

    static let stationsByCode: [String: Station] = Dictionary(uniqueKeysWithValues: stations.map { ($0.code, $0) })

    static let trains: [Train] = {
        var trains: [Train] = []
        func add(_ number: Int, _ name: String, departs: String, off: Set<Int> = [],
                 classes: [(SeatClass, Int)], route: [(String, Int, Int)],
                 returning: (number: Int, name: String?, departs: String, off: Set<Int>?)) {
            let outbound = makeTrain(number, name, departs: departs, off: off, classes: classes, route: route)
            trains.append(outbound)
            trains.append(reversed(outbound, number: returning.number, name: returning.name ?? name,
                                   departs: returning.departs, off: returning.off ?? off))
        }

        // Weekdays: 1 Sun, 2 Mon, 3 Tue, 4 Wed, 5 Thu, 6 Fri, 7 Sat.
        add(702, "Subarna Express", departs: "16:30", off: [2],
            classes: [(.sChair, 6), (.snigdha, 4), (.acSeat, 2)],
            route: [("DHK", 0, 0), ("CTG", 300, 321)],
            returning: (701, nil, "07:00", nil))

        add(788, "Sonar Bangla Express", departs: "07:00", off: [4],
            classes: [(.sChair, 6), (.snigdha, 4), (.acSeat, 2)],
            route: [("DHK", 0, 0), ("DAP", 25, 17), ("CTG", 320, 321)],
            returning: (787, nil, "17:00", nil))

        add(704, "Mohanagar Provati", departs: "07:45",
            classes: [(.shovan, 3), (.sChair, 6), (.snigdha, 2), (.acSeat, 1)],
            route: [("DHK", 0, 0), ("DAP", 25, 17), ("NSD", 70, 58), ("BRB", 110, 85), ("BBA", 150, 118),
                    ("AKH", 170, 130), ("CML", 235, 194), ("LKM", 265, 220), ("FEN", 300, 255), ("CTG", 390, 321)],
            returning: (703, "Mohanagar Godhuli", "15:00", nil))

        add(742, "Turna Express", departs: "23:30",
            classes: [(.shovan, 2), (.sChair, 5), (.acSeat, 1), (.acBerth, 2)],
            route: [("DHK", 0, 0), ("DAP", 25, 17), ("BBA", 160, 118), ("CML", 250, 194), ("FEN", 320, 255), ("CTG", 430, 321)],
            returning: (741, nil, "23:00", nil))

        add(814, "Cox's Bazar Express", departs: "22:30", off: [4],
            classes: [(.sChair, 6), (.snigdha, 4), (.acSeat, 2)],
            route: [("DHK", 0, 0), ("DAP", 25, 17), ("CTG", 370, 321), ("CXB", 530, 422)],
            returning: (813, nil, "12:30", nil))

        add(709, "Parabat Express", departs: "06:20", off: [3],
            classes: [(.shovan, 2), (.sChair, 6), (.snigdha, 2), (.acSeat, 1)],
            route: [("DHK", 0, 0), ("DAP", 25, 17), ("NSD", 70, 58), ("BRB", 105, 85), ("SHG", 220, 200),
                    ("SRM", 270, 235), ("KLR", 330, 270), ("SYL", 410, 319)],
            returning: (710, nil, "15:45", nil))

        add(739, "Upaban Express", departs: "21:50", off: [4],
            classes: [(.sChair, 4), (.snigdha, 1), (.acSeat, 1), (.acBerth, 2)],
            route: [("DHK", 0, 0), ("DAP", 25, 17), ("BRB", 115, 85), ("SHG", 240, 200), ("SRM", 295, 235),
                    ("KLR", 360, 270), ("SYL", 460, 319)],
            returning: (740, nil, "23:30", nil))

        add(753, "Silk City Express", departs: "14:45", off: [1],
            classes: [(.shovan, 2), (.sChair, 6), (.snigdha, 2), (.acSeat, 1)],
            route: [("DHK", 0, 0), ("DAP", 30, 17), ("JDP", 60, 32), ("TGL", 140, 98), ("ULP", 220, 170),
                    ("IWD", 290, 230), ("ABP", 330, 255), ("RAJ", 360, 343)],
            returning: (754, nil, "07:40", nil))

        add(759, "Padma Express", departs: "23:00", off: [3],
            classes: [(.sChair, 5), (.snigdha, 2), (.acBerth, 1)],
            route: [("DHK", 0, 0), ("DAP", 30, 17), ("JDP", 60, 32), ("TGL", 145, 98), ("ABP", 330, 255), ("RAJ", 370, 343)],
            returning: (760, nil, "16:00", nil))

        add(726, "Sundarban Express", departs: "08:15", off: [4],
            classes: [(.shovan, 2), (.sChair, 5), (.snigdha, 2), (.acSeat, 1), (.acBerth, 1)],
            route: [("DHK", 0, 0), ("BNG", 90, 80), ("FRD", 130, 110), ("RJB", 170, 135), ("JSR", 300, 250),
                    ("NWP", 330, 275), ("KHL", 380, 300)],
            returning: (725, nil, "21:45", nil))

        add(705, "Ekota Express", departs: "10:10",
            classes: [(.shovan, 2), (.sChair, 5), (.snigdha, 1), (.acSeat, 1), (.acBerth, 1)],
            route: [("DHK", 0, 0), ("DAP", 30, 17), ("JDP", 60, 32), ("TGL", 140, 98), ("SNH", 330, 250),
                    ("JPH", 375, 280), ("PBT", 470, 345), ("DNJ", 510, 380)],
            returning: (706, nil, "21:20", nil))

        add(771, "Rangpur Express", departs: "09:10", off: [1],
            classes: [(.shovan, 1), (.sChair, 5), (.snigdha, 1), (.acSeat, 1), (.acBerth, 1)],
            route: [("DHK", 0, 0), ("DAP", 30, 17), ("JDP", 60, 32), ("TGL", 140, 98), ("SNH", 330, 250),
                    ("BGR", 390, 290), ("RNG", 510, 390)],
            returning: (772, nil, "20:00", nil))

        add(751, "Lalmoni Express", departs: "21:45", off: [6],
            classes: [(.shovan, 2), (.sChair, 5), (.acSeat, 1), (.acBerth, 1)],
            route: [("DHK", 0, 0), ("DAP", 30, 17), ("JDP", 60, 32), ("TGL", 140, 98), ("SNH", 335, 250),
                    ("GBD", 450, 340), ("KAU", 540, 380), ("LMH", 595, 405)],
            returning: (752, nil, "10:20", nil))

        add(707, "Tista Express", departs: "07:30", off: [2],
            classes: [(.shovan, 3), (.sChair, 4), (.acSeat, 1)],
            route: [("DHK", 0, 0), ("DAP", 30, 17), ("JDP", 60, 32), ("MYM", 200, 120), ("JMP", 290, 175), ("DWG", 380, 222)],
            returning: (708, nil, "15:00", nil))

        return trains
    }()

    // MARK: - Builders

    /// Builds a train from `(stationCode, minutesFromOrigin, km)` tuples.
    /// Intermediate stops get a short halt after arrival.
    private static func makeTrain(_ number: Int, _ name: String, departs: String, off: Set<Int>,
                                  classes: [(SeatClass, Int)], route: [(String, Int, Int)]) -> Train {
        let stops = route.enumerated().map { index, item in
            let (code, minutes, km) = item
            let isFirst = index == 0
            let isLast = index == route.count - 1
            guard let station = stationsByCode[code] else { preconditionFailure("Unknown station \(code)") }
            return TrainStop(station: station,
                             arrivalOffset: isFirst ? nil : minutes,
                             departureOffset: isLast ? nil : (isFirst ? 0 : minutes + halt(for: code)),
                             distanceKm: km)
        }
        return Train(number: number, name: name, departureMinutes: minutes(departs), offDays: off,
                     stops: stops, inventory: classes.map { CoachInventory(seatClass: $0.0, coachCount: $0.1) })
    }

    private static func reversed(_ train: Train, number: Int, name: String, departs: String, off: Set<Int>) -> Train {
        guard let last = train.stops.last, let total = last.arrivalOffset else { return train }
        let route = train.stops.reversed().map { stop in
            (stop.stationCode, total - (stop.departureOffset ?? stop.arrivalOffset ?? 0), last.distanceKm - stop.distanceKm)
        }
        return makeTrain(number, name, departs: departs, off: off,
                         classes: train.inventory.map { ($0.seatClass, $0.coachCount) }, route: route)
    }

    private static func halt(for code: String) -> Int {
        ["DAP", "CTG", "BBA", "SRM", "IWD", "SNH", "JSR"].contains(code) ? 5 : 3
    }

    private static func minutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }
}
