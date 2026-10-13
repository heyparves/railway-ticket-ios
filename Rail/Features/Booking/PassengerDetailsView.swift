import SwiftUI

struct PassengerDetailsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SearchRouter.self) private var router
    @State private var model: PassengerDetailsViewModel
    @State private var isContinuing = false
    @State private var expanded: Set<String> = []
    @FocusState private var focus: Focus?

    private enum Focus: Hashable {
        case name(String), age(String), phone
    }

    @ObserveInjection var inject

    init(draft: BookingDraft, repository: PassengerRepository) {
        _model = State(initialValue: PassengerDetailsViewModel(draft: draft, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                StepHeader(step: 3, title: "Who's travelling?",
                           message: model.entries.count > 1
                               ? "You're the lead traveller. Everyone else can ride on your ticket."
                               : "You're the ticket holder. Carry a photo ID that matches your name.")
                if !model.savedCompanions.isEmpty && !model.companions.isEmpty {
                    savedStrip
                }
                if let lead = model.lead {
                    leadTicket(lead)
                }
                if !model.companions.isEmpty {
                    companionsSection
                }
                if model.hasUnsavedEntries {
                    saveToggle
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(Spacing.x2)
            .animation(.snappy(duration: 0.25), value: model.hasUnsavedEntries)
        }
        .background(Color.canvas)
        .navigationTitle("Passengers")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .task { await model.load(user: session.user) }
        .enableInjection()
    }

    // MARK: Footer

    private var footer: some View {
        BottomBar {
            HStack(spacing: Spacing.x2) {
                BarTotal(amount: model.draft.fare.fare) {
                    Text(footerDetail)
                        .contentTransition(.opacity)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button {
                    focus = nil
                    Task {
                        isContinuing = true
                        let draft = await model.makeDraft()
                        isContinuing = false
                        router.path.append(.payment(draft))
                    }
                } label: {
                    Label("Payment", systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .primaryAction()
                .disabled(!model.canContinue || isContinuing)
                .accessibilityLabel("Continue to payment")
            }
        }
    }

    private var footerDetail: String {
        if model.lead?.isComplete != true { return "Add your age and gender" }
        if !Validation.isMobile(model.contactPhone) { return "Add a mobile number" }
        if model.entries.contains(where: { !$0.isValid }) { return "Check guest details" }
        let seats = model.entries.count
        return "\(seats) \(seats == 1 ? "seat" : "seats") · incl. VAT"
    }

    // MARK: Saved passengers

    /// One-tap fill from the profile. Each tap lands on the next open seat, lead first.
    private var savedStrip: some View {
        let target = model.nextOpenEntryID()
        return VStack(alignment: .leading, spacing: Spacing.x1) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Saved travellers")
                Spacer(minLength: Spacing.x1)
                Text(target.map { "Fills seat \($0)" } ?? "All seats filled")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, Spacing.half)
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.x1) {
                    ForEach(model.savedCompanions) { passenger in
                        SavedTravellerChip(passenger: passenger, isInUse: model.isInUse(passenger)) {
                            guard let target else { return }
                            withAnimation(.snappy(duration: 0.25)) {
                                model.apply(passenger, to: target)
                                expanded.insert(target)
                            }
                        }
                        .disabled(model.isInUse(passenger) || target == nil)
                    }
                }
                .padding(.horizontal, Spacing.x2)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Spacing.x2)
        }
        .animation(.snappy(duration: 0.2), value: target)
    }

    // MARK: Lead traveller

    /// The lead traveller is the ticket holder: printed as a ticket with the contact number on its stub.
    private func leadTicket(_ lead: PassengerDetailsViewModel.Entry) -> some View {
        TicketCard {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: Spacing.x1 + Spacing.half) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.x1) {
                            Text("LEAD TRAVELLER")
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(.tint)
                            Text("You")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .overlay(Capsule().strokeBorder(Color(uiColor: .separator)))
                        }
                        HStack(spacing: Spacing.half + 2) {
                            Text(lead.name.trimmed.isEmpty ? "Account holder" : lead.name.trimmed)
                                .font(.title3.bold())
                                .lineLimit(1)
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(lead.isComplete ? summary(of: lead) : "From your account")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .contentTransition(.opacity)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHint("Name comes from your account and can't be changed here")
                    Spacer(minLength: Spacing.x1)
                    SeatStub(seat: lead.seat, state: lead.isComplete ? .complete : .pending)
                }
                .padding(Spacing.x2)

                Divider()
                fields(at: 0, entry: lead)
            }
            .padding(.bottom, Spacing.x1)
        } stub: {
            VStack(alignment: .leading, spacing: 0) {
                FieldRow(label: "Mobile for ticket & SMS", isFocused: focus == .phone, error: model.phoneError) {
                    TextField("Mobile number", text: $model.contactPhone, prompt: Text("01XXXXXXXXX"))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                        .monospacedDigit()
                        .focused($focus, equals: .phone)
                }
                .onTapGesture { focus = .phone }
                Label("Checkers may ask for this number with the PNR.", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.x2)
                    .padding(.bottom, Spacing.x2)
            }
            .padding(.top, Spacing.x1)
        }
        .animation(.snappy(duration: 0.2), value: lead.isComplete)
    }

    // MARK: Companions

    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
                    Text("Travelling with")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Optional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: Spacing.x1)
                    Text("\(model.namedCompanionCount)/\(model.companions.count) named")
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Text("Blank seats are booked under your name.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.half)

            VStack(spacing: 0) {
                ForEach(Array(model.entries.enumerated()).dropFirst(), id: \.element.id) { index, entry in
                    if index > 1 { Divider().padding(.leading, Spacing.x2 + 44 + Spacing.x1 + Spacing.half) }
                    companionRow(index: index, entry: entry)
                }
            }
            .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .animation(.snappy(duration: 0.25), value: expanded)
        }
    }

    private func companionRow(index: Int, entry: PassengerDetailsViewModel.Entry) -> some View {
        let isOpen = expanded.contains(entry.id)
        return VStack(spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    if isOpen {
                        expanded.remove(entry.id)
                        if focus == .name(entry.id) || focus == .age(entry.id) { focus = nil }
                    } else {
                        expanded.insert(entry.id)
                        if entry.isBlank { focus = .name(entry.id) }
                    }
                }
            } label: {
                HStack(spacing: Spacing.x1 + Spacing.half) {
                    SeatStub(seat: entry.seat, state: entry.isComplete ? .complete : entry.isBlank ? .open : .pending)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name.trimmed.isEmpty ? "Guest \(index + 1)" : entry.name.trimmed)
                            .font(.body.weight(.medium))
                            .foregroundStyle(entry.name.trimmed.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                        Text(companionSummary(entry))
                            .font(.caption)
                            .foregroundStyle(entry.isValid ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                            .lineLimit(1)
                    }
                    .contentTransition(.opacity)
                    Spacer(minLength: Spacing.x1)
                    Image(systemName: entry.isBlank && !isOpen ? "plus" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.isBlank && !isOpen ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .frame(width: 28, height: 28)
                        .background(Color.well, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.horizontal, Spacing.x2)
                .padding(.vertical, Spacing.x1 + Spacing.half)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Seat \(entry.seat.id), \(entry.name.trimmed.isEmpty ? "guest \(index + 1)" : entry.name.trimmed)")
            .accessibilityValue(companionSummary(entry))
            .accessibilityHint(isOpen ? "Hides details" : "Adds optional details")

            if isOpen {
                VStack(spacing: 0) {
                    Divider()
                    fields(at: index, entry: entry)
                    Divider().padding(.leading, Spacing.x2)
                    HStack(spacing: Spacing.x2) {
                        let choices = model.savedChoices(for: entry)
                        if !choices.isEmpty {
                            Menu {
                                Section("Saved travellers") {
                                    ForEach(choices) { passenger in
                                        Button("\(passenger.name), \(passenger.age)") {
                                            model.apply(passenger, to: entry.id)
                                        }
                                    }
                                }
                            } label: {
                                Label("Use saved", systemImage: "person.crop.circle.badge.checkmark")
                            }
                            .accessibilityLabel("Fill guest \(index + 1) from saved travellers")
                        }
                        Spacer(minLength: 0)
                        if !entry.isBlank {
                            Button("Leave blank", role: .destructive) {
                                withAnimation(.snappy(duration: 0.25)) {
                                    focus = nil
                                    model.clear(entry.id)
                                    expanded.remove(entry.id)
                                }
                            }
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, Spacing.x2)
                    .frame(minHeight: 44)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private func companionSummary(_ entry: PassengerDetailsViewModel.Entry) -> String {
        if entry.isBlank { return "No details · optional" }
        if !entry.isValid { return "Check details" }
        let parts = [entry.ageValue.map { "\($0) yrs" }, entry.gender?.title].compactMap { $0 }
        return parts.isEmpty ? "Name only" : parts.joined(separator: " · ")
    }

    // MARK: Shared fields

    /// Name over an age | gender split, as hairline rows inside the owning surface.
    /// The lead's name comes from the account and is shown in the card header instead.
    private func fields(at index: Int, entry: PassengerDetailsViewModel.Entry) -> some View {
        VStack(spacing: 0) {
            if !entry.isLead {
                FieldRow(label: "Full name", isFocused: focus == .name(entry.id), error: entry.nameError) {
                    TextField("Full name", text: $model.entries[index].name, prompt: Text("Optional"))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .name(entry.id))
                        .submitLabel(.next)
                        .onSubmit { focus = .age(entry.id) }
                        .onChange(of: model.entries[index].name) { model.syncSavedLink(entry.id) }
                }
                .onTapGesture { focus = .name(entry.id) }

                Divider().padding(.leading, Spacing.x2)
            }

            HStack(spacing: 0) {
                FieldRow(label: "Age", isFocused: focus == .age(entry.id), error: entry.ageError) {
                    TextField("Age", text: $model.entries[index].age, prompt: Text(entry.isLead ? "Years" : "—"))
                        .keyboardType(.numberPad)
                        .monospacedDigit()
                        .focused($focus, equals: .age(entry.id))
                        .onChange(of: model.entries[index].age) { model.syncSavedLink(entry.id) }
                }
                .frame(width: 104)
                .onTapGesture { focus = .age(entry.id) }

                Divider()

                FieldRow(label: "Gender") {
                    SegmentedChips(options: Gender.allCases,
                                   selection: entry.gender,
                                   title: \.title,
                                   expands: true,
                                   height: 30) { gender in
                        // Companions can untick an answer; the lead always keeps one.
                        let current = model.entries[index].gender
                        model.entries[index].gender = !entry.isLead && current == gender ? nil : gender
                        model.syncSavedLink(entry.id)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Gender")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "34 · Female" once filled.
    private func summary(of entry: PassengerDetailsViewModel.Entry) -> String {
        guard let age = entry.ageValue, let gender = entry.gender else { return "" }
        return "\(age) yrs · \(gender.title)"
    }

    private var saveToggle: some View {
        Toggle(isOn: $model.saveNewPassengers) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remember new travellers")
                    .font(.subheadline.weight(.medium))
                Text("Anyone with full details is one tap away next time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.vertical, Spacing.x1 + Spacing.half)
        .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }
}

/// Saved profile traveller as a fill-in chip: initials disc, name, age. Greys out once seated.
private struct SavedTravellerChip: View {
    let passenger: Passenger
    let isInUse: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @ObserveInjection var inject

    private var initials: String {
        passenger.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.x1) {
                ZStack {
                    Circle().fill(isInUse ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.accentColor.opacity(0.12)))
                    if isInUse {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.onAccent)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(initials)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tint)
                    }
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text(passenger.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(isInUse ? "Added" : passenger.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.leading, Spacing.half + 2)
            .padding(.trailing, Spacing.x2)
            .frame(height: 44)
            .background(Color.raised, in: Capsule())
            .opacity(isEnabled || isInUse ? 1 : 0.5)
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .animation(.snappy(duration: 0.2), value: isInUse)
        .accessibilityLabel("\(passenger.name), \(passenger.summary)")
        .accessibilityValue(isInUse ? "Added to this booking" : "")
        .accessibilityHint(isInUse ? "" : "Fills the next open seat")
        .enableInjection()
    }
}

/// Seat printed like a ticket stub: coach over number.
/// Dashed while a seat is open, tinted while details are in progress, solid once complete.
private struct SeatStub: View {
    enum Fill { case open, pending, complete }

    let seat: Seat
    let state: Fill
    @ObserveInjection var inject

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.small + 2, style: .continuous) }

    var body: some View {
        VStack(spacing: -1) {
            Text(seat.coach)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .opacity(0.8)
            Text("\(seat.number)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(foreground)
        .frame(width: 44, height: 44)
        .background(background, in: shape)
        .overlay {
            if state == .open {
                shape.strokeBorder(Color(uiColor: .separator), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .overlay(alignment: .topTrailing) {
            if state == .complete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.onAccent, Color.accentColor)
                    .background(Circle().fill(Color.raised).padding(-2))
                    .offset(x: 5, y: -5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seat \(seat.id)\(state == .complete ? ", details complete" : "")")
        .enableInjection()
    }

    private var foreground: AnyShapeStyle {
        switch state {
        case .open: AnyShapeStyle(.secondary)
        case .pending: AnyShapeStyle(.tint)
        case .complete: AnyShapeStyle(Color.onAccent)
        }
    }

    private var background: AnyShapeStyle {
        switch state {
        case .open: AnyShapeStyle(Color.clear)
        case .pending: AnyShapeStyle(Color.accentColor.opacity(0.12))
        case .complete: AnyShapeStyle(.tint)
        }
    }
}

/// "Step n of 4" eyebrow over the screen title, with an even segmented progress track.
struct StepHeader: View {
    let step: Int
    var total = 4
    let title: String
    var message: String?
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            HStack(spacing: 3) {
                ForEach(1...total, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well))
                        .frame(height: 3)
                }
            }
            .padding(.bottom, Spacing.half)
            .accessibilityHidden(true)
            Text("Step \(step) of \(total)".uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .enableInjection()
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.x1) {
            configuration.title
            configuration.icon
        }
    }
}
