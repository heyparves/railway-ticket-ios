import Foundation
import SwiftData

@Model
final class UserEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var email: String
    var name: String
    var phone: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, email: String, phone: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.createdAt = createdAt
    }

    var model: User { User(id: id, name: name, email: email, phone: phone, createdAt: createdAt) }
}

@Model
final class SavedPassengerEntity {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var name: String
    var age: Int
    var genderRaw: String
    var createdAt: Date

    init(_ passenger: Passenger, ownerID: UUID) {
        id = passenger.id
        self.ownerID = ownerID
        name = passenger.name
        age = passenger.age
        genderRaw = passenger.gender.rawValue
        createdAt = .now
    }

    func apply(_ passenger: Passenger) {
        name = passenger.name
        age = passenger.age
        genderRaw = passenger.gender.rawValue
    }

    var model: Passenger { Passenger(id: id, name: name, age: age, gender: Gender(rawValue: genderRaw) ?? .other) }
}

@Model
final class BookingEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var pnr: String
    var userID: UUID
    var trainNumber: Int
    var trainName: String
    var fromCode: String
    var fromName: String
    var toCode: String
    var toName: String
    var runDateKey: String
    var runDate: Date
    var departure: Date
    var arrival: Date
    var seatClassRaw: String
    var seatIDs: [String]
    /// JSON-encoded `[TicketPassenger]`.
    var passengersData: Data
    var baseFare: Int
    var vat: Int
    var bedding: Int
    var paymentMethodRaw: String
    var transactionID: String
    var contactPhone: String
    var statusRaw: String
    var createdAt: Date
    var cancelledAt: Date?
    var refundAmount: Int?

    init(booking: Booking) {
        id = booking.id
        pnr = booking.pnr
        userID = booking.userID
        trainNumber = booking.trainNumber
        trainName = booking.trainName
        fromCode = booking.from.code
        fromName = booking.from.name
        toCode = booking.to.code
        toName = booking.to.name
        runDateKey = DateKey.string(from: booking.runDate)
        runDate = booking.runDate
        departure = booking.departure
        arrival = booking.arrival
        seatClassRaw = booking.seatClass.rawValue
        seatIDs = booking.seatIDs
        passengersData = (try? JSONEncoder().encode(booking.passengers)) ?? Data()
        baseFare = booking.fare.perSeat.base
        vat = booking.fare.perSeat.vat
        bedding = booking.fare.perSeat.bedding
        paymentMethodRaw = booking.paymentMethod.rawValue
        transactionID = booking.transactionID
        contactPhone = booking.contactPhone
        statusRaw = booking.status.rawValue
        createdAt = booking.createdAt
        cancelledAt = booking.cancelledAt
        refundAmount = booking.refundAmount
    }

    var model: Booking {
        let passengers = (try? JSONDecoder().decode([TicketPassenger].self, from: passengersData)) ?? []
        return Booking(
            id: id, pnr: pnr, userID: userID, trainNumber: trainNumber, trainName: trainName,
            from: Station(code: fromCode, name: fromName), to: Station(code: toCode, name: toName),
            runDate: runDate, departure: departure, arrival: arrival,
            seatClass: SeatClass(rawValue: seatClassRaw) ?? .sChair, passengers: passengers,
            fare: FareTotal(perSeat: FareBreakdown(base: baseFare, vat: vat, bedding: bedding), seats: passengers.count),
            paymentMethod: PaymentMethod(rawValue: paymentMethodRaw) ?? .card, transactionID: transactionID,
            contactPhone: contactPhone, createdAt: createdAt, status: BookingStatus(rawValue: statusRaw) ?? .confirmed,
            cancelledAt: cancelledAt, refundAmount: refundAmount
        )
    }
}

enum Persistence {
    static let models: [any PersistentModel.Type] = [UserEntity.self, SavedPassengerEntity.self, BookingEntity.self]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }
}
