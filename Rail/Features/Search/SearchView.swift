import SwiftUI

struct SearchView: View {
    @Environment(SearchRouter.self) private var router
    @Environment(SessionStore.self) private var session
    @State private var model: SearchViewModel
    @State private var swapTurns = 0
    @ObserveInjection var inject

    init(trains: TrainRepository) {
        _model = State(initialValue: SearchViewModel(trains: trains))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x2) {
                header
                routeCard
                tripCard
                searchButton
                if !model.recentRoutes.isEmpty {
                    recentSection
                        .padding(.top, Spacing.x1)
                }
            }
            .padding(.horizontal, Spacing.x2)
            .padding(.bottom, Spacing.x6)
        }
        .background(Color.canvas)
        .navigationTitle("Book")
        .toolbar(.hidden, for: .navigationBar)
        .task { await model.load() }
        .sheet(item: $model.picking) { endpoint in
            StationPickerView(
                title: endpoint.title,
                stations: model.stations,
                popular: model.popularStations,
                selected: endpoint == .from ? model.from : model.to
            ) { station in
                model.select(station, for: endpoint)
            }
        }
        .sensoryFeedback(.selection, trigger: model.seatClass)
        .sensoryFeedback(.selection, trigger: model.date)
        .sensoryFeedback(.impact(weight: .light), trigger: swapTurns)
        .enableInjection()
    }

    // MARK: Header

    /// Greeting over the moving train scene, which runs full-bleed up under the status bar.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(greeting)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
            Text("Where to next?")
                .font(.title.bold())
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
        }
        .accessibilityElement(children: .combine)
        .padding(.top, Spacing.x1)
        .frame(maxWidth: .infinity, minHeight: 272, alignment: .topLeading)
        .background {
            // Reaches well above the content so the sky fills the status bar and the top bounce.
            RailHeroScene()
                .padding(.horizontal, -Spacing.x2)
                .padding(.top, -Self.heroOverscan)
        }
    }

    private static let heroOverscan: CGFloat = 240

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        guard let first = session.user?.name.split(separator: " ").first else { return part }
        return "\(part), \(first)"
    }

    // MARK: Route

    /// Boarding-pass style: origin code on the left, destination on the right, swap in the middle.
    private var routeCard: some View {
        HStack(alignment: .center, spacing: Spacing.x1) {
            stationButton(.from, station: model.from, alignment: .leading)
            swapButton
            stationButton(.to, station: model.to, alignment: .trailing)
        }
        .padding(Spacing.x2)
        .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
    }

    private var swapButton: some View {
        Button {
            withAnimation(.snappy) {
                model.swap()
                swapTurns += 1
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tint)
                .rotationEffect(.degrees(Double(swapTurns) * 180))
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: Circle())
        }
        .buttonStyle(.pressable)
        .disabled(model.from == nil && model.to == nil)
        .accessibilityLabel("Swap stations")
    }

    private func stationButton(_ endpoint: SearchViewModel.Endpoint, station: Station?, alignment: HorizontalAlignment) -> some View {
        let frameAlignment: Alignment = alignment == .leading ? .leading : .trailing
        return Button {
            model.picking = endpoint
        } label: {
            VStack(alignment: alignment, spacing: 2) {
                Eyebrow(endpoint.title)
                Text(station?.code ?? "———")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(station == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(station?.name ?? "Choose station")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(endpoint.title), \(station?.name ?? "not selected")")
        .accessibilityHint("Choose a station")
    }

    // MARK: Trip details

    /// Date and class grouped in one surface so the form reads as a single ticket.
    /// Party size isn't asked here: riders pick up to four seats on the seat map.
    private var tripCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            dateSection
                .padding(.vertical, Spacing.x2)
            Divider().padding(.horizontal, Spacing.x2)
            classSection
                .padding(.vertical, Spacing.x2)
        }
        .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
    }

    private var dates: [Date] {
        (0..<FarePolicy.bookingWindowDays).map { model.dateRange.lowerBound.adding(days: $0) }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Journey date")
                Spacer(minLength: Spacing.x1)
                Text(model.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, Spacing.x2)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.x1) {
                        ForEach(dates, id: \.self) { date in
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: model.date)
                            Button {
                                withAnimation(.snappy) { model.date = date }
                            } label: {
                                DayPill(date: date, isSelected: isSelected)
                            }
                            .buttonStyle(.pressable)
                            .id(date)
                            .accessibilityLabel(date.longDayText)
                            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.horizontal, Spacing.x2)
                }
                .onAppear { proxy.scrollTo(model.date, anchor: .center) }
            }
        }
    }

    private var classSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Seat type")
                Spacer(minLength: Spacing.x1)
                Text(model.seatClass.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, Spacing.x2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.x1) {
                    ForEach(SeatClass.allCases) { seatClass in
                        SeatClassPill(seatClass: seatClass, isSelected: model.seatClass == seatClass) {
                            withAnimation(.snappy) { model.seatClass = seatClass }
                        }
                    }
                }
                .padding(.horizontal, Spacing.x2)
            }
        }
    }

    private var searchButton: some View {
        Button {
            if let query = model.makeQuery() { router.path.append(.results(query)) }
        } label: {
            Label("Search Trains", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .primaryAction()
        .disabled(!model.canSearch)
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow("Recent")
                Spacer(minLength: Spacing.x1)
                Button("Clear", action: model.clearRecents)
                    .font(.caption.weight(.semibold))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.x1) {
                    ForEach(model.recentRoutes) { route in
                        Button {
                            withAnimation(.snappy) { model.apply(route) }
                        } label: {
                            HStack(spacing: Spacing.x1) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                                Text(route.from.code)
                                Image(systemName: "arrow.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text(route.to.code)
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, Spacing.x1 + Spacing.half)
                            .frame(minHeight: 40)
                            .background(Color.raised, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel("\(route.from.name) to \(route.to.name)")
                        .accessibilityHint("Fills the route")
                    }
                }
                .padding(.horizontal, Spacing.x2)
            }
            .padding(.horizontal, -Spacing.x2)
        }
    }
}

/// Uppercase caption that labels a group inside a surface.
struct Eyebrow: View {
    let text: String
    @ObserveInjection var inject

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .enableInjection()
    }
}

/// Compact weekday + day number; today and tomorrow are named.
private struct DayPill: View {
    let date: Date
    let isSelected: Bool
    @ObserveInjection var inject

    private var weekday: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tmrw" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(weekday.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .opacity(isSelected ? 0.9 : 0.6)
            Text(date.formatted(.dateTime.day()))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: 52, height: 52)
        .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
        .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well),
                    in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .animation(.snappy(duration: 0.2), value: isSelected)
        .enableInjection()
    }
}

/// Seat-type tile, read like a fare board: class code on top, per-seat fare as the headline and
/// seats left underneath, so riders compare classes at a glance. Snowflake marks AC classes.
struct SeatClassPill: View {
    let seatClass: SeatClass
    let isSelected: Bool
    var fare: String?
    /// Free seats in this class. Nil when no train is chosen yet.
    var available: Int?
    var isEnabled = true
    let action: () -> Void
    @ObserveInjection var inject

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.medium, style: .continuous) }
    private var isSoldOut: Bool { available == 0 }
    private var isLow: Bool { (available ?? .max) < 20 }

    // Selected flips to a solid accent tile: one decisive state, no outline-plus-tick.
    private var ink: Color { isSelected ? .onAccent : .primary }
    private var muted: Color { isSelected ? .onAccent.opacity(0.72) : .secondary }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: fare == nil ? 2 : Spacing.half) {
                HStack(spacing: 3) {
                    Text(seatClass.shortTitle.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                    if seatClass.isAirConditioned {
                        Image(systemName: "snowflake")
                            .font(.system(size: 8, weight: .black))
                    }
                }
                .foregroundStyle(fare == nil ? ink : muted)

                if let fare {
                    Text(fare)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .strikethrough(isSoldOut)
                        .foregroundStyle(isSoldOut ? muted : ink)
                    if let available { availabilityLine(available) }
                } else {
                    Text(seatClass.isAirConditioned ? "Air-conditioned" : "Non-AC")
                        .font(.caption)
                        .foregroundStyle(muted)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Spacing.x1 + Spacing.half)
            .padding(.vertical, Spacing.x1 + 2)
            .frame(minWidth: 92, alignment: .leading)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well), in: shape)
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(seatClass.title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(seatClass.summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .enableInjection()
    }

    /// Plain count, coloured only when it matters: orange when running low.
    private func availabilityLine(_ count: Int) -> some View {
        let urgent = isLow && !isSoldOut && !isSelected
        return Text(isSoldOut ? "Sold out" : isLow ? "Only \(count) left" : "\(count) left")
            .font(.caption.weight(urgent ? .semibold : .medium))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(count)))
            .foregroundStyle(urgent ? Color.orange : muted)
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if let fare { parts.append("\(fare) per seat") }
        if let available { parts.append(isSoldOut ? "Sold out" : "\(available) seats free") }
        if parts.isEmpty { parts.append(seatClass.isAirConditioned ? "Air conditioned" : "Non AC") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let container = AppContainer.preview()
    NavigationStack {
        SearchView(trains: container.trains)
    }
    .environment(SearchRouter())
    .environment(SessionStore(auth: container.auth))
}
