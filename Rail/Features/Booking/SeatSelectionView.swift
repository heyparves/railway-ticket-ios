import SwiftUI

struct SeatSelectionView: View {
    @State private var model: SeatSelectionViewModel
    @ObserveInjection var inject

    init(offer: TrainOffer, trains: TrainRepository) {
        _model = State(initialValue: SeatSelectionViewModel(offer: offer, trains: trains))
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage {
                ContentUnavailableView("Couldn't load seats", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                content
            }
        }
        .background(Color.canvas)
        .navigationTitle("Choose Seats")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .sensoryFeedback(.warning, trigger: model.limitReachedCount)
        .sensoryFeedback(.warning, trigger: model.togetherFailureCount)
        .sensoryFeedback(.selection, trigger: model.selected)
        .sensoryFeedback(.impact(weight: .light), trigger: model.selectedCoachName)
        .task { await model.load() }
        .enableInjection()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                TripStrip(offer: model.offer)
                    .padding(.horizontal, Spacing.x2)

                VStack(alignment: .leading, spacing: Spacing.x1) {
                    HStack {
                        Eyebrow("Coaches")
                        Spacer()
                        Text("\(model.coaches.count) × \(model.offer.seatClass.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.x2)
                    TrainConsist(coaches: model.coaches,
                                 selectedName: model.selectedCoachName,
                                 chosen: model.selectedCount(in:)) { coach in
                        model.selectedCoachName = coach.name
                    }
                }

                if let coach = model.selectedCoach {
                    VStack(spacing: Spacing.x2) {
                        coachPanel(coach)
                        CoachSeatMap(coach: coach,
                                     selectedIDs: model.selectedIDs,
                                     highlight: model.preference,
                                     onTap: model.toggle)
                            .id(coach.name)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .frame(maxWidth: .infinity)
                        SeatLegend()
                    }
                    .padding(.horizontal, Spacing.x2)
                }
            }
            .padding(.vertical, Spacing.x2)
            .animation(.snappy, value: model.selectedCoachName)
            .animation(.snappy, value: model.selectedIDs)
            .animation(.snappy, value: model.preference)
        }
    }

    /// Coach identity, preference filter and auto-pick in one compact surface.
    private func coachPanel(_ coach: Coach) -> some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
            CoachHeader(coach: coach)
            Divider()
            HStack(spacing: Spacing.x1) {
                SegmentedChips(options: [nil] + model.preferenceOptions.map(Optional.some),
                               selection: model.preference,
                               title: { $0?.title ?? "Any" }) { spot in
                    model.preference = spot
                }
                Spacer(minLength: 0)
                pickMenu
            }
            if let notice = model.togetherNotice {
                Label(notice, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .surface(radius: Radius.large, padding: Spacing.x1 + Spacing.half)
    }

    /// Tap picks as many seats as are chosen now (at least one); hold for a party size.
    private var pickMenu: some View {
        let count = max(model.selected.count, 1)
        return Menu {
            Section("Pick seats together") {
                ForEach(1...model.maxSeats, id: \.self) { size in
                    Button {
                        model.suggestTogether(size)
                    } label: {
                        Label("\(size) \(model.offer.seatClass.seatNoun)\(size == 1 ? "" : "s")",
                              systemImage: "\(size).circle")
                    }
                }
            }
        } label: {
            Label(count > 1 ? "Pick \(count)" : "Pick for me", systemImage: "wand.and.stars")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, Spacing.x1 + Spacing.half)
                .frame(minHeight: 32)
                .foregroundStyle(Color.onAccent)
                .background(.tint, in: Capsule())
        } primaryAction: {
            model.suggestTogether(count)
        }
        .menuStyle(.button)
        .buttonStyle(.pressable)
        .accessibilityLabel(count > 1 ? "Pick \(count) seats together" : "Pick a seat for me")
        .accessibilityHint("Touch and hold to choose how many")
    }

    /// One row: running fare over the seat tokens, Continue on the right.
    private var footer: some View {
        BottomBar {
            HStack(spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: Spacing.x1 - 2) {
                    BarTotal(amount: model.fare.fare) {
                        Text(model.selected.isEmpty ? "Per \(model.offer.seatClass.seatNoun) · incl. VAT" : "\(model.selected.count) \(model.offer.seatClass.seatNoun)\(model.selected.count == 1 ? "" : "s") · incl. VAT")
                    }
                    .accessibilityElement(children: .combine)
                    seatTokens
                }
                Spacer(minLength: 0)
                NavigationLink(value: SearchRoute.passengers(model.draft)) {
                    Label("Continue", systemImage: "arrow.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .primaryAction()
                .disabled(!model.canContinue)
            }

            if model.limitReachedCount > 0 && model.selected.count == model.maxSeats {
                Text("\(model.maxSeats) is the most per booking. Tap a chosen seat to free it up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var seatTokens: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.half + 2) {
                ForEach(model.selected) { seat in
                    SeatToken(seat: seat, detail: model.detail(of: seat),
                              onReveal: { model.reveal(seat) },
                              onRemove: { model.toggle(seat) })
                }
                if model.selected.count < model.maxSeats {
                    EmptySeatToken(remaining: model.maxSeats - model.selected.count,
                                   noun: model.offer.seatClass.seatNoun,
                                   isFirst: model.selected.isEmpty)
                }
            }
        }
        .scrollClipDisabled()
        .animation(.snappy, value: model.selectedIDs)
    }
}

// MARK: - Header pieces

/// Train, route and class at a glance.
private struct TripStrip: View {
    let offer: TrainOffer
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.x1 + Spacing.half) {
            IconBadge(systemName: "train.side.front.car", size: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(offer.train.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(offer.train.number) · \(offer.from.code) → \(offer.to.code) · \(offer.departure.timeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Label(offer.seatClass.shortTitle, systemImage: offer.seatClass.symbol)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, Spacing.x1)
                .padding(.vertical, Spacing.half)
                .foregroundStyle(.tint)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .surface(radius: Radius.large, padding: Spacing.x1 + Spacing.half)
        .accessibilityElement(children: .combine)
        .enableInjection()
    }
}

/// Bengali coach letter, layout and how full the coach is.
private struct CoachHeader: View {
    let coach: Coach
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.x1 + Spacing.half) {
            CoachLetterBadge(name: coach.name, size: 44)
            VStack(alignment: .leading, spacing: 0) {
                Text("Coach \(coach.name)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("\(coach.layout.leftColumns) + \(coach.layout.rightColumns) \(coach.seatClass.interior.title.lowercased()) · \(coach.seatClass.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(coach.availableCount)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText())
                Text("of \(coach.seats.count) free")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .enableInjection()
    }
}

/// Bengali letter painted on the coach, Latin name underneath.
private struct CoachLetterBadge: View {
    let name: String
    var size: CGFloat = 44
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: -2) {
            Text(CoachName.letter(for: name) ?? name)
                .font(.system(size: size * 0.42, weight: .bold))
            Text(name)
                .font(.system(size: size * 0.2, weight: .bold))
                .opacity(0.75)
        }
        .foregroundStyle(Color.onAccent)
        .frame(width: size, height: size)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .accessibilityHidden(true)
        .enableInjection()
    }
}

/// Inline segmented control built from capsules. `expands` splits the full width evenly.
struct SegmentedChips<Option: Hashable>: View {
    let options: [Option]
    /// `nil` leaves every option unselected, e.g. a field the user hasn't answered yet.
    let selection: Option?
    let title: (Option) -> String
    var expands = false
    var height: CGFloat = 28
    let onSelect: (Option) -> Void

    @Namespace private var namespace
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isOn = option == selection
                Button {
                    onSelect(option)
                } label: {
                    Text(title(option))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, expands ? Spacing.half : Spacing.x1 + Spacing.half)
                        .frame(maxWidth: expands ? .infinity : nil, minHeight: height)
                        .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .background {
                            if isOn {
                                Capsule()
                                    .fill(Color.raised)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "thumb", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(Color.well, in: Capsule())
        .enableInjection()
    }
}

// MARK: - Consist (top view of the train)

/// Mono-colour palette for the drawn coaches: one accent hue plus neutrals.
enum CoachPalette {
    /// Coach body and walls, the livery seen from above.
    static let body = Color.accentColor
    /// Window glass let into the walls.
    static let glass = Color.white.opacity(0.55)
    /// Interior floor.
    static let floor = Color.raised
    /// Aisle runner and bench planks.
    static let fitting = Color.accentColor.opacity(0.07)
    /// Partitions, backrests and other fixed lines.
    static let line = Color.accentColor.opacity(0.3)
}

/// Engine plus coaches in train order, drawn from above like the platform coach-position board.
private struct TrainConsist: View {
    let coaches: [Coach]
    let selectedName: String?
    let chosen: (Coach) -> Int
    let onSelect: (Coach) -> Void
    @ObserveInjection var inject

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    Locomotive()
                    ForEach(coaches) { coach in
                        Bellows(vertical: false)
                            .padding(.top, 13)
                        CoachRoof(coach: coach, isSelected: coach.name == selectedName, chosen: chosen(coach)) {
                            onSelect(coach)
                        }
                        .id(coach.name)
                    }
                }
                .padding(.horizontal, Spacing.x2)
                .padding(.vertical, Spacing.half)
            }
            .onChange(of: selectedName, initial: true) { _, name in
                guard let name else { return }
                withAnimation(.snappy) { proxy.scrollTo(name, anchor: .center) }
            }
        }
        .enableInjection()
    }
}

/// Engine roof: streamlined nose leading, radiator grilles behind the cab.
private struct Locomotive: View {
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: Spacing.half) {
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20,
                                       bottomTrailingRadius: 6, topTrailingRadius: 6, style: .continuous)
                    .fill(CoachPalette.body.opacity(0.85))
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3).fill(CoachPalette.glass).frame(width: 8, height: 26)
                    ForEach(0..<4, id: \.self) { _ in
                        Capsule().fill(Color.black.opacity(0.18)).frame(width: 3, height: 22)
                    }
                }
                .padding(.leading, 10)
            }
            .frame(width: 72, height: 42)
            Text("Engine")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
        .enableInjection()
    }
}

/// Rubber gangway between coaches; ribs run across the direction of travel.
private struct Bellows: View {
    let vertical: Bool
    @ObserveInjection var inject

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 2) { ribs }
                    .frame(width: 40, height: 12)
            } else {
                HStack(spacing: 2) { ribs }
                    .frame(width: 10, height: 18)
            }
        }
        .accessibilityHidden(true)
        .enableInjection()
    }

    private var ribs: some View {
        ForEach(0..<3, id: \.self) { _ in
            Capsule().fill(CoachPalette.line)
        }
    }
}

/// One coach seen from above: roof seams, AC units on air-conditioned stock, letter on the roof.
private struct CoachRoof: View {
    let coach: Coach
    let isSelected: Bool
    let chosen: Int
    let action: () -> Void

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 8, style: .continuous) }
    private var ink: Color { isSelected ? .onAccent : .accentColor }
    @ObserveInjection var inject

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.half) {
                ZStack {
                    shape.fill(isSelected ? AnyShapeStyle(CoachPalette.body) : AnyShapeStyle(CoachPalette.body.opacity(0.1)))
                    // Roof seams.
                    VStack {
                        Rectangle().fill(ink.opacity(0.18)).frame(height: 1)
                        Spacer()
                        Rectangle().fill(ink.opacity(0.18)).frame(height: 1)
                    }
                    .padding(.vertical, 8)
                    if coach.seatClass.isAirConditioned {
                        HStack {
                            acUnit
                            Spacer()
                            acUnit
                        }
                        .padding(.horizontal, 6)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(CoachName.letter(for: coach.name) ?? coach.name)
                            .font(.headline.weight(.bold))
                        Text(coach.name)
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.75)
                    }
                    .foregroundStyle(ink)
                }
                .frame(width: 92, height: 42)
                .overlay(shape.strokeBorder(isSelected ? Color.clear : CoachPalette.line, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if chosen > 0 {
                        Text("\(chosen)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.onAccent)
                            .frame(width: 18, height: 18)
                            .background(isSelected ? Color.white : Color.accentColor, in: Circle())
                            .overlay(Circle().strokeBorder(Color.canvas, lineWidth: 2))
                            .offset(x: 5, y: -5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text("\(coach.availableCount) free")
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Coach \(coach.name)")
        .accessibilityValue("\(coach.availableCount) of \(coach.seats.count) free\(chosen > 0 ? ", \(chosen) chosen" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .enableInjection()
    }

    private var acUnit: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(ink.opacity(isSelected ? 0.25 : 0.18))
            .frame(width: 12, height: 18)
    }
}

// MARK: - Footer pieces

/// Chosen seat as a compact ticket tag. Tap shows its coach; hold to remove.
private struct SeatToken: View {
    let seat: Seat
    let detail: String
    let onReveal: () -> Void
    let onRemove: () -> Void
    @ObserveInjection var inject

    var body: some View {
        Menu {
            Button("Show in Coach \(seat.coach)", systemImage: "scope", action: onReveal)
            Button("Remove \(seat.id)", systemImage: "xmark", role: .destructive, action: onRemove)
        } label: {
            HStack(spacing: 0) {
                Text(seat.coach)
                    .foregroundStyle(Color.onAccent)
                    .padding(.horizontal, Spacing.half + 1)
                    .frame(maxHeight: .infinity)
                    .background(.tint)
                Text("\(seat.number)")
                    .foregroundStyle(.tint)
                    .padding(.horizontal, Spacing.half + 2)
            }
            .font(.caption.weight(.bold).monospacedDigit())
            .frame(height: 24)
            .background(Color.accentColor.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle().inset(by: -6))
        } primaryAction: {
            onReveal()
        }
        .accessibilityLabel("\(seat.id), \(detail)")
        .accessibilityHint("Shows the coach")
        .accessibilityAction(named: "Remove") { onRemove() }
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .enableInjection()
    }
}

/// Open slot after the chosen seats. Before the first pick it says what to do.
private struct EmptySeatToken: View {
    let remaining: Int
    let noun: String
    let isFirst: Bool
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.half) {
            Image(systemName: "plus")
                .font(.caption2.weight(.bold))
            if isFirst {
                Text("Tap up to \(remaining) on the map")
                    .font(.caption.weight(.medium))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, isFirst ? Spacing.x1 : 0)
        .frame(minWidth: 36)
        .frame(height: 24)
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
        .accessibilityLabel("Up to \(remaining) more \(noun)\(remaining == 1 ? "" : "s")")
        .enableInjection()
    }
}

private struct SeatLegend: View {
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.x2) {
            item("Free", state: .available)
            item("Taken", state: .booked)
            item("Yours", state: .selected)
            HStack(spacing: Spacing.half) {
                Capsule().fill(CoachPalette.body).frame(width: 8, height: 16)
                    .overlay(Capsule().fill(CoachPalette.glass).frame(width: 2, height: 10))
                Text("Window")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .enableInjection()
    }

    private func item(_ title: String, state: SeatCell.State) -> some View {
        HStack(spacing: Spacing.half) {
            SeatCell.swatch(state)
                .frame(width: 14, height: 14)
            Text(title)
        }
    }
}

// MARK: - Coach map

/// Top-down drawing of a Bangladesh Railway coach in one accent colour: gangway bellows and an
/// end wall at each end, doors cut into the side walls, windows let into the walls row by row,
/// toilets and wash basins in the vestibules, seats drawn per interior.
struct CoachSeatMap: View {
    let coach: Coach
    let selectedIDs: Set<String>
    var highlight: SeatSpot? = nil
    let onTap: (Seat) -> Void

    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 40
    private var seatSize: CGFloat { min(scaledSize, 46) }
    private var interior: CoachInterior { coach.seatClass.interior }
    private var layout: SeatLayout { coach.layout }
    private let wall: CGFloat = 10
    private var shell: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }
    @ObserveInjection var inject

    /// Rows drawn as one unit: cabins pair facing rows, everything else is one row.
    private var groups: [[Int]] {
        let step = interior == .cabin ? 2 : 1
        return stride(from: 0, to: layout.rows, by: step).map { start in
            Array(start..<min(start + step, layout.rows))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Label("Engine side", systemImage: "arrow.up")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, Spacing.half)
            Bellows(vertical: true)
            VStack(spacing: 0) {
                CoachEnd(coach: coach, isFront: true, wall: wall)
                ForEach(Array(groups.enumerated()), id: \.offset) { index, rows in
                    group(index: index, rows: rows)
                }
                CoachEnd(coach: coach, isFront: false, wall: wall)
            }
            .clipShape(shell)
            .overlay(shell.strokeBorder(CoachPalette.line, lineWidth: 1))
            .shadow(color: CoachPalette.body.opacity(0.18), radius: 14, y: 8)
            Bellows(vertical: true)
        }
        .fixedSize(horizontal: true, vertical: false)
        .enableInjection()
    }

    /// Wall, left side, aisle, right side, wall.
    private func group(index: Int, rows: [Int]) -> some View {
        HStack(spacing: 0) {
            Wall(windows: rows.count, width: wall)
            HStack(spacing: 0) {
                side(rows: rows, columns: 0..<layout.leftColumns)
                aisle(index: index)
                side(rows: rows, columns: layout.leftColumns..<layout.columns)
            }
            .padding(.horizontal, Spacing.half + 2)
            .padding(.vertical, interior == .cabin || interior == .berth ? Spacing.half : 0)
            .background(CoachPalette.floor)
            Wall(windows: rows.count, width: wall)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Aisle runner with the row, cabin or bay number.
    private func aisle(index: Int) -> some View {
        let label: String = switch interior {
        case .cabin: "C\(index + 1)"
        case .berth: "B\(index + 1)"
        case .bench, .recliner: "\(index + 1)"
        }
        return Text(label)
            .font(.system(size: 10, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.accentColor.opacity(0.55))
            .frame(width: max(seatSize * 0.7, 24))
            .frame(maxHeight: .infinity)
            .background(interior == .bench || interior == .recliner ? CoachPalette.fitting : .clear)
            .padding(.horizontal, Spacing.half)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func side(rows: [Int], columns: Range<Int>) -> some View {
        switch interior {
        case .bench:
            ForEach(rows, id: \.self) { row in bench(row: row, columns: columns) }
        case .recliner:
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Spacing.half + 1) {
                    ForEach(columns, id: \.self) { column in chair(row: row, column: column) }
                }
                .padding(.vertical, 3)
            }
        case .cabin:
            cabin(rows: rows, columns: columns)
        case .berth:
            bay(row: rows[0], columns: columns)
        }
    }

    /// Shovan bench: one plank with a shared backrest.
    private func bench(row: Int, columns: Range<Int>) -> some View {
        let backOnTop = coach.facing(row: row) == .back
        return VStack(spacing: 2) {
            if backOnTop { backrest }
            HStack(spacing: 2) {
                ForEach(columns, id: \.self) { column in
                    if let seat = coach.seat(row: row, column: column) {
                        cell(seat, style: .cushion)
                    }
                }
            }
            if !backOnTop { backrest }
        }
        .padding(3)
        .background(CoachPalette.fitting, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.vertical, 3)
    }

    private var backrest: some View {
        Capsule().fill(CoachPalette.line).frame(height: 5).padding(.horizontal, 2)
    }

    /// AC cabin: two rows facing each other across a window table, walled off from the corridor.
    private func cabin(rows: [Int], columns: Range<Int>) -> some View {
        VStack(spacing: Spacing.half) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(CoachPalette.line)
                        .frame(width: seatSize, height: 6)
                        .accessibilityHidden(true)
                }
                HStack(spacing: Spacing.half) {
                    ForEach(columns, id: \.self) { column in chair(row: row, column: column) }
                }
            }
        }
        .padding(Spacing.half + 2)
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(CoachPalette.line, lineWidth: 2))
    }

    /// Sleeper bay: upper berth drawn above lower, boxed in.
    private func bay(row: Int, columns: Range<Int>) -> some View {
        VStack(spacing: Spacing.half) {
            ForEach(columns.reversed(), id: \.self) { column in
                if let seat = coach.seat(row: row, column: column) {
                    cell(seat, style: .berth(isUpper: coach.spot(of: seat) == .upper))
                }
            }
        }
        .padding(Spacing.half + 2)
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(CoachPalette.line, lineWidth: 2))
    }

    @ViewBuilder
    private func chair(row: Int, column: Int) -> some View {
        if let seat = coach.seat(row: row, column: column) {
            cell(seat, style: .chair(backOnTop: coach.facing(row: row) == .back))
        }
    }

    private func cell(_ seat: Seat, style: SeatCell.Style) -> some View {
        SeatCell(seat: seat,
                 label: "\(coach.seatClass.seatNoun.capitalized) \(seat.id), \(coach.detail(of: seat))",
                 style: style,
                 isSelected: selectedIDs.contains(seat.id),
                 isDimmed: highlight.map { coach.spot(of: seat) != $0 } ?? false,
                 size: seatSize) {
            onTap(seat)
        }
    }
}

/// Side wall with a window slot per row.
private struct Wall: View {
    let windows: Int
    let width: CGFloat
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: Spacing.x1 + Spacing.half) {
            ForEach(0..<windows, id: \.self) { _ in
                Capsule().fill(CoachPalette.glass).frame(width: 3)
            }
        }
        .padding(.vertical, Spacing.x1)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(CoachPalette.body)
        .accessibilityHidden(true)
        .enableInjection()
    }
}

/// Coach end: end wall with the gangway opening, doors cut into both side walls,
/// toilet and wash basin, then the partition into the saloon.
private struct CoachEnd: View {
    let coach: Coach
    let isFront: Bool
    let wall: CGFloat

    private let doorHeight: CGFloat = 30
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: 0) {
            if isFront { endWall }
            HStack(spacing: 0) {
                sideWall
                VStack(spacing: Spacing.x1) {
                    if isFront {
                        doorRow
                        fittings
                        partition
                    } else {
                        partition
                        fittings
                        doorRow
                    }
                }
                .padding(.horizontal, Spacing.x1)
                .padding(.top, isFront ? 0 : Spacing.x1)
                .padding(.bottom, isFront ? Spacing.x1 : 0)
                .background(CoachPalette.floor)
                sideWall
            }
            .fixedSize(horizontal: false, vertical: true)
            if !isFront { endWall }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFront ? "Engine end of coach \(coach.name): doors, toilet and wash basin" : "Rear end of coach \(coach.name): doors, toilet and wash basin")
        .enableInjection()
    }

    /// Full-width end wall with the gangway opening in the middle.
    private var endWall: some View {
        HStack(spacing: 0) {
            CoachPalette.body
            CoachPalette.floor.frame(width: 40)
            CoachPalette.body
        }
        .frame(height: wall)
    }

    /// Side wall with the door opening level with `doorRow`.
    private var sideWall: some View {
        VStack(spacing: 0) {
            if !isFront { CoachPalette.body }
            CoachPalette.floor
                .frame(height: doorHeight)
                .overlay { Rectangle().fill(CoachPalette.line).frame(width: 2) }
            if isFront { CoachPalette.body }
        }
        .frame(width: wall)
    }

    private var doorRow: some View {
        HStack {
            door(leading: true)
            Spacer(minLength: Spacing.x1)
            if isFront {
                CoachLetterBadge(name: coach.name, size: 26)
            }
            Spacer(minLength: Spacing.x1)
            door(leading: false)
        }
        .frame(height: doorHeight)
    }

    private func door(leading: Bool) -> some View {
        HStack(spacing: 2) {
            if leading { Image(systemName: "arrow.left") }
            Text("Door")
            if !leading { Image(systemName: "arrow.right") }
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(Color.accentColor.opacity(0.7))
    }

    private var fittings: some View {
        HStack(spacing: Spacing.x1) {
            fixture("toilet", "WC")
            Spacer(minLength: Spacing.half)
            fixture("drop", "Wash")
        }
    }

    private func fixture(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.accentColor.opacity(0.8))
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(CoachPalette.fitting, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(CoachPalette.line, lineWidth: 1))
    }

    /// Partition with the sliding door into the saloon.
    private var partition: some View {
        HStack(spacing: 0) {
            Rectangle().fill(CoachPalette.line)
            Color.clear.frame(width: 36)
            Rectangle().fill(CoachPalette.line)
        }
        .frame(height: 2)
    }
}

struct SeatCell: View {
    enum State { case available, booked, selected }

    enum Style {
        /// Individual chair; the backrest sits on the side the passenger leans against.
        case chair(backOnTop: Bool)
        /// Part of a bench; the plank draws the backrest.
        case cushion
        /// Sleeper berth, drawn long with a pillow.
        case berth(isUpper: Bool)
    }

    let seat: Seat
    let label: String
    let style: Style
    let isSelected: Bool
    let isDimmed: Bool
    let size: CGFloat
    let action: () -> Void

    private var state: State { isSelected ? .selected : seat.isBooked ? .booked : .available }
    @ObserveInjection var inject

    var body: some View {
        Button(action: action) {
            glyph
                .scaleEffect(isSelected ? 1.06 : 1)
                .opacity(isDimmed && !isSelected ? 0.3 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(seat.isBooked)
        .accessibilityLabel(label)
        .accessibilityValue(state == .selected ? "Selected" : state == .booked ? "Taken" : "Available")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .enableInjection()
    }

    @ViewBuilder
    private var glyph: some View {
        switch style {
        case .chair(let backOnTop):
            VStack(spacing: 2) {
                if backOnTop { back }
                cushion(height: size * 0.78)
                if !backOnTop { back }
            }
            .frame(width: size, height: size)
        case .cushion:
            cushion(height: size * 0.85)
                .frame(width: size)
        case .berth(let isUpper):
            HStack(spacing: Spacing.half) {
                Capsule()
                    .fill(backColor)
                    .frame(width: 6, height: size * 0.4)
                Text("\(seat.number)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if state == .booked {
                    Image(systemName: "person.fill").font(.caption2)
                } else {
                    Text(isUpper ? "U" : "L")
                        .font(.caption2.weight(.bold))
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, Spacing.x1)
            .frame(width: size * 2.1, height: size * 0.72)
            .foregroundStyle(foreground)
            .background(Self.swatch(state))
        }
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(backColor)
            .frame(height: size * 0.16)
            .padding(.horizontal, size * 0.06)
    }

    private func cushion(height: CGFloat) -> some View {
        ZStack {
            Self.swatch(state)
            switch state {
            case .booked:
                Image(systemName: "person.fill").font(.system(size: 10))
            case .selected:
                VStack(spacing: -1) {
                    Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy))
                    Text("\(seat.number)").font(.caption2.weight(.bold)).monospacedDigit()
                }
            case .available:
                Text("\(seat.number)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(foreground)
        .frame(height: height)
    }

    private var backColor: Color {
        switch state {
        case .available: Color.accentColor.opacity(0.35)
        case .booked: Color.accentColor.opacity(0.1)
        case .selected: Color.accentColor
        }
    }

    private var foreground: Color {
        switch state {
        case .available: .primary
        case .booked: Color.accentColor.opacity(0.35)
        case .selected: .white
        }
    }

    @ViewBuilder
    static func swatch(_ state: State) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        switch state {
        case .available:
            shape.fill(Color(.systemBackground))
                .overlay(shape.strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1))
        case .booked:
            shape.fill(Color.accentColor.opacity(0.1))
        case .selected:
            shape.fill(Color.accentColor.gradient)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 4, y: 2)
        }
    }
}
