import Foundation
import Observation

@MainActor
@Observable
final class PassengerDetailsViewModel {
    /// One seat's traveller. Only the lead (first seat) must be filled in; companions may stay blank
    /// and travel on the lead's ticket, but anything typed for them still has to make sense.
    struct Entry: Identifiable {
        let seat: Seat
        let isLead: Bool
        var name = ""
        var age = ""
        var gender: Gender?
        var savedPassengerID: UUID?

        var id: String { seat.id }
        var ageValue: Int? { Int(age.trimmed).flatMap { (1...120).contains($0) ? $0 : nil } }
        var isBlank: Bool { name.trimmed.isEmpty && age.trimmed.isEmpty && gender == nil }
        var isComplete: Bool { Validation.isName(name) && ageValue != nil && gender != nil }
        var isValid: Bool { isLead ? isComplete : nameError == nil && ageError == nil }

        var nameError: String? { name.trimmed.isEmpty || Validation.isName(name) ? nil : "Use at least 2 letters." }
        var ageError: String? { age.isEmpty || ageValue != nil ? nil : "Enter an age between 1 and 120." }
    }

    let draft: BookingDraft
    var entries: [Entry]
    var contactPhone = ""
    var saveNewPassengers = true
    private(set) var saved: [Passenger] = []

    private let repository: PassengerRepository
    private var user: User?
    private var didLoad = false

    init(draft: BookingDraft, repository: PassengerRepository) {
        self.draft = draft
        self.repository = repository
        entries = draft.seats.enumerated().map { Entry(seat: $0.element, isLead: $0.offset == 0) }
    }

    var lead: Entry? { entries.first }
    var companions: ArraySlice<Entry> { entries.dropFirst() }
    var namedCompanionCount: Int { companions.filter { !$0.name.trimmed.isEmpty }.count }

    var phoneError: String? { contactPhone.isEmpty || Validation.isMobile(contactPhone) ? nil : "Use an 11-digit number starting with 01." }
    var canContinue: Bool { entries.allSatisfy(\.isValid) && Validation.isMobile(contactPhone) }
    var hasUnsavedEntries: Bool { entries.contains { $0.isComplete && $0.savedPassengerID == nil } }

    func load(user: User?) async {
        guard !didLoad, let user else { return }
        didLoad = true
        self.user = user
        contactPhone = user.phone
        saved = (try? await repository.passengers(for: user)) ?? []
        guard entries.indices.contains(0) else { return }
        // The lead is always the account holder; reuse their saved age and gender if the profile has them.
        if entries[0].ageValue == nil, entries[0].gender == nil, let me = saved.first(where: isAccountHolder) {
            apply(me, to: entries[0].id)
        }
        entries[0].name = user.name.trimmed
    }

    /// Saved travellers other than the account holder, who is always the lead.
    var savedCompanions: [Passenger] { saved.filter { !isAccountHolder($0) } }

    func isInUse(_ passenger: Passenger) -> Bool {
        entries.contains { $0.savedPassengerID == passenger.id }
    }

    func savedChoices(for entry: Entry) -> [Passenger] {
        let usedElsewhere = Set(entries.filter { $0.id != entry.id }.compactMap(\.savedPassengerID))
        return savedCompanions.filter { !usedElsewhere.contains($0.id) }
    }

    /// Where a tapped saved traveller lands: the first blank companion seat.
    func nextOpenEntryID() -> Entry.ID? {
        companions.first(where: \.isBlank)?.id
    }

    private func isAccountHolder(_ passenger: Passenger) -> Bool {
        guard let user else { return false }
        return passenger.name.caseInsensitiveCompare(user.name.trimmed) == .orderedSame
    }

    func apply(_ passenger: Passenger, to entryID: Entry.ID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index].name = passenger.name
        entries[index].age = String(passenger.age)
        entries[index].gender = passenger.gender
        entries[index].savedPassengerID = passenger.id
    }

    /// Empties a companion back to an unnamed seat.
    func clear(_ entryID: Entry.ID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[index] = Entry(seat: entries[index].seat, isLead: entries[index].isLead)
    }

    /// Unlinks an entry from its saved passenger once the user edits it away from the saved values.
    func syncSavedLink(_ entryID: Entry.ID) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }),
              let savedID = entries[index].savedPassengerID,
              let passenger = saved.first(where: { $0.id == savedID }) else { return }
        let entry = entries[index]
        if entry.name.trimmed != passenger.name || entry.ageValue != passenger.age || entry.gender != passenger.gender {
            entries[index].savedPassengerID = nil
        }
    }

    /// Builds the next draft and, if requested, stores newly entered travellers on the profile.
    /// Every seat stays on the ticket; blank companions are carried without personal details.
    func makeDraft() async -> BookingDraft {
        let passengers = entries.map {
            TicketPassenger(name: $0.name.trimmed, age: $0.ageValue, gender: $0.gender, seatID: $0.seat.id)
        }
        if saveNewPassengers, let user {
            for entry in entries where entry.isComplete && entry.savedPassengerID == nil {
                guard let age = entry.ageValue, let gender = entry.gender else { continue }
                try? await repository.save(Passenger(name: entry.name.trimmed, age: age, gender: gender), for: user)
            }
            saved = (try? await repository.passengers(for: user)) ?? saved
            relinkSavedPassengers()
        }
        var next = draft
        next.passengers = passengers
        next.contactPhone = contactPhone.trimmed
        return next
    }

    /// After saving, mark entries as linked so going back and forth doesn't duplicate them.
    private func relinkSavedPassengers() {
        for index in entries.indices where entries[index].savedPassengerID == nil && entries[index].isComplete {
            let entry = entries[index]
            entries[index].savedPassengerID = saved.first {
                $0.name == entry.name.trimmed && $0.age == entry.ageValue && $0.gender == entry.gender
            }?.id
        }
    }
}
