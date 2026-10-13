import SwiftUI

@MainActor
@Observable
final class SavedPassengersViewModel {
    private(set) var passengers: [Passenger] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    func load(_ repository: PassengerRepository, user: User?) async {
        guard let user else { return }
        passengers = (try? await repository.passengers(for: user)) ?? []
        hasLoaded = true
    }

    func save(_ passenger: Passenger, repository: PassengerRepository, user: User?) async {
        guard let user else { return }
        do {
            try await repository.save(passenger, for: user)
            await load(repository, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet, repository: PassengerRepository, user: User?) async {
        guard let user else { return }
        for passenger in offsets.map({ passengers[$0] }) {
            try? await repository.delete(passenger, for: user)
        }
        await load(repository, user: user)
    }
}

struct SavedPassengersView: View {
    @Environment(AppContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var model = SavedPassengersViewModel()
    @State private var editing: Passenger?
    @ObserveInjection var inject

    var body: some View {
        List {
            if model.hasLoaded && model.passengers.isEmpty {
                ContentUnavailableView {
                    Label("No saved passengers", systemImage: "person.2")
                } description: {
                    Text("Save the people you travel with to fill in bookings faster.")
                } actions: {
                    Button("Add Passenger") { editing = newPassenger }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(model.passengers) { passenger in
                        Button {
                            editing = passenger
                        } label: {
                            VStack(alignment: .leading, spacing: Spacing.half) {
                                Text(passenger.name).foregroundStyle(.primary)
                                Text(passenger.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityHint("Edit passenger")
                    }
                    .onDelete { offsets in
                        Task { await model.delete(at: offsets, repository: container.passengers, user: session.user) }
                    }
                } footer: {
                    Text("Swipe left to remove a passenger.")
                }
            }
        }
        .navigationTitle("Saved Passengers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = newPassenger
                } label: {
                    Label("Add Passenger", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { passenger in
            PassengerEditorView(passenger: passenger, isNew: !model.passengers.contains { $0.id == passenger.id }) { updated in
                Task { await model.save(updated, repository: container.passengers, user: session.user) }
            }
        }
        .task { await model.load(container.passengers, user: session.user) }
        .enableInjection()
    }

    private var newPassenger: Passenger { Passenger(name: "", age: 30, gender: .male) }
}

struct PassengerEditorView: View {
    let isNew: Bool
    let onSave: (Passenger) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var passenger: Passenger
    @ObserveInjection var inject

    init(passenger: Passenger, isNew: Bool, onSave: @escaping (Passenger) -> Void) {
        _passenger = State(initialValue: passenger)
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Full name", text: $passenger.name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                Stepper(value: $passenger.age, in: 1...120) {
                    LabeledContent("Age", value: "\(passenger.age)")
                }
                .accessibilityValue("\(passenger.age) years")
                Picker("Gender", selection: $passenger.gender) {
                    ForEach(Gender.allCases) { Text($0.title).tag($0) }
                }
            }
            .navigationTitle(isNew ? "New Passenger" : "Edit Passenger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        passenger.name = passenger.name.trimmed
                        onSave(passenger)
                        dismiss()
                    }
                    .disabled(!Validation.isName(passenger.name))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .enableInjection()
    }
}
