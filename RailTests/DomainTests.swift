import Foundation
import Testing
@testable import Rail

struct PasswordHasherTests {
    @Test func verifiesCorrectPasswordOnly() {
        let stored = PasswordHasher.hash("correct horse", iterations: 1_000)
        #expect(PasswordHasher.verify("correct horse", against: stored))
        #expect(!PasswordHasher.verify("Correct horse", against: stored))
    }

    @Test func saltsEachHash() {
        let a = PasswordHasher.hash("same", iterations: 1_000)
        let b = PasswordHasher.hash("same", iterations: 1_000)
        #expect(a.salt != b.salt)
        #expect(a.hash != b.hash)
    }
}

struct FareTests {
    @Test func nonACHasNoVAT() {
        let fare = FarePolicy.fare(for: .sChair, distanceKm: 321)
        #expect(fare.vat == 0)
        #expect(fare.bedding == 0)
        #expect(fare.base == 337)
    }

    @Test func acBerthAddsVATAndBedding() {
        let fare = FarePolicy.fare(for: .acBerth, distanceKm: 321)
        #expect(fare.vat == Int((Double(fare.base) * 0.15).rounded()))
        #expect(fare.bedding == FarePolicy.beddingCharge)
    }

    @Test func totalAddsServiceChargePerSeat() {
        let total = FareTotal(perSeat: FareBreakdown(base: 100, vat: 15, bedding: 0), seats: 3)
        #expect(total.fare == 345)
        #expect(total.total == 345 + 3 * FarePolicy.serviceChargePerSeat)
    }

    @Test func refundShrinksNearDeparture() {
        let total = FareTotal(perSeat: FareBreakdown(base: 1000, vat: 0, bedding: 0), seats: 1)
        let now = Date.now
        #expect(RefundPolicy.refund(for: total, departure: now.addingTimeInterval(72 * 3600), at: now) == 900)
        #expect(RefundPolicy.refund(for: total, departure: now.addingTimeInterval(24 * 3600), at: now) == 750)
        #expect(RefundPolicy.refund(for: total, departure: now.addingTimeInterval(3600), at: now) == 500)
        #expect(RefundPolicy.refund(for: total, departure: now.addingTimeInterval(-60), at: now) == nil)
    }
}

struct ValidationTests {
    @Test func mobileNumbers() {
        #expect(Validation.isMobile("01712345678"))
        #expect(!Validation.isMobile("01212345678"))
        #expect(!Validation.isMobile("0171234567"))
    }

    @Test func cardLuhn() {
        #expect(Validation.isCardNumber("4242424242424242"))
        #expect(!Validation.isCardNumber("4242424242424241"))
    }
}

struct SeedDataTests {
    @Test func everyTrainHasAReturnWithMirroredRoute() {
        let subarnaUp = SeedData.trains.first { $0.number == 701 }
        let subarnaDown = SeedData.trains.first { $0.number == 702 }
        #expect(subarnaUp?.stops.first?.stationCode == "CTG")
        #expect(subarnaDown?.stops.first?.stationCode == "DHK")
        #expect(subarnaUp?.stops.last?.distanceKm == subarnaDown?.stops.last?.distanceKm)
    }

    @Test func coachNamesAreUniqueAcrossClasses() {
        for train in SeedData.trains {
            let names = train.seatClasses.flatMap { train.coachNames(for: $0) }
            #expect(Set(names).count == names.count, "\(train.displayName)")
        }
    }
}
