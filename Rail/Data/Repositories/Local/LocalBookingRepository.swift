import Foundation
import SwiftData

@MainActor
final class LocalBookingRepository: BookingRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func book(_ request: BookingRequest, for user: User) async throws -> Booking {
        let offer = request.offer
        let taken = try await bookedSeatIDs(trainNumber: offer.train.number, runDate: offer.runDate, seatClass: offer.seatClass)
        let conflicts = request.passengers.map(\.seatID).filter(taken.contains)
        guard conflicts.isEmpty else { throw AppError.seatsUnavailable(conflicts) }

        let booking = Booking(
            id: UUID(), pnr: try uniquePNR(), userID: user.id,
            trainNumber: offer.train.number, trainName: offer.train.name,
            from: offer.from, to: offer.to, runDate: offer.runDate,
            departure: offer.departure, arrival: offer.arrival, seatClass: offer.seatClass,
            passengers: request.passengers,
            fare: FareTotal(perSeat: offer.fare, seats: request.passengers.count),
            paymentMethod: request.payment.method, transactionID: request.payment.transactionID,
            contactPhone: request.contactPhone, createdAt: .now, status: .confirmed
        )
        context.insert(BookingEntity(booking: booking))
        try context.save()
        return booking
    }

    func bookings(for user: User) async throws -> [Booking] {
        let userID = user.id
        let descriptor = FetchDescriptor<BookingEntity>(
            predicate: #Predicate { $0.userID == userID },
            sortBy: [SortDescriptor(\.departure)]
        )
        return try context.fetch(descriptor).map(\.model)
    }

    func cancel(_ booking: Booking) async throws -> Booking {
        guard let entity = try entity(id: booking.id) else { throw AppError.bookingNotFound }
        let current = entity.model
        guard current.canCancel, let refund = RefundPolicy.refund(for: current.fare, departure: current.departure) else {
            throw AppError.cannotCancel
        }
        entity.statusRaw = BookingStatus.cancelled.rawValue
        entity.cancelledAt = .now
        entity.refundAmount = refund
        try context.save()
        return entity.model
    }

    func bookedSeatIDs(trainNumber: Int, runDate: Date, seatClass: SeatClass) async throws -> Set<String> {
        let key = DateKey.string(from: runDate)
        let classRaw = seatClass.rawValue
        let confirmed = BookingStatus.confirmed.rawValue
        let descriptor = FetchDescriptor<BookingEntity>(predicate: #Predicate {
            $0.trainNumber == trainNumber && $0.runDateKey == key && $0.seatClassRaw == classRaw && $0.statusRaw == confirmed
        })
        return Set(try context.fetch(descriptor).flatMap(\.seatIDs))
    }

    func verify(pnr: String, phone: String) async throws -> Booking {
        let pnr = pnr.trimmed.uppercased()
        let descriptor = FetchDescriptor<BookingEntity>(predicate: #Predicate { $0.pnr == pnr })
        guard let entity = try context.fetch(descriptor).first, entity.contactPhone == phone.trimmed else {
            throw AppError.bookingNotFound
        }
        return entity.model
    }

    // MARK: - Helpers

    private func entity(id: UUID) throws -> BookingEntity? {
        try context.fetch(FetchDescriptor<BookingEntity>(predicate: #Predicate { $0.id == id })).first
    }

    private func uniquePNR() throws -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        while true {
            let pnr = "BR" + String((0..<8).map { _ in alphabet.randomElement()! })
            let descriptor = FetchDescriptor<BookingEntity>(predicate: #Predicate { $0.pnr == pnr })
            if try context.fetchCount(descriptor) == 0 { return pnr }
        }
    }
}
