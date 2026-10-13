import SwiftUI

struct TrainDetailView: View {
    @State private var model: TrainDetailViewModel
    @ObserveInjection var inject

    init(offer: TrainOffer, trains: TrainRepository) {
        _model = State(initialValue: TrainDetailViewModel(offer: offer, trains: trains))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                summary
                classSection
                routeSection
            }
            .padding(Spacing.x2)
        }
        .background(Color.canvas)
        .navigationTitle(model.train.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .task { await model.load() }
        .sensoryFeedback(.selection, trigger: model.offer.seatClass)
        .enableInjection()
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack(alignment: .top, spacing: Spacing.x2) {
                BrandLogo(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.train.name)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Train \(model.train.number) · \(model.offer.departure.longDayText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            JourneyTimesView(departure: model.offer.departure, arrival: model.offer.arrival,
                             from: model.offer.from.name, to: model.offer.to.name, size: .large)
                .padding(.vertical, Spacing.x1)
            ViewThatFits {
                HStack(spacing: Spacing.x1) { facts }
                VStack(alignment: .leading, spacing: Spacing.x1) { facts }
            }
        }
        .surface(radius: Radius.xlarge, padding: Spacing.x2 + 4)
    }

    @ViewBuilder
    private var facts: some View {
        fact("\(model.offer.distanceKm) km", symbol: "point.topleft.down.to.point.bottomright.curvepath")
        fact(model.runsText, symbol: "calendar")
        fact("\(model.route.filter { $0.role == .between }.count) stops", symbol: "mappin.and.ellipse")
    }

    private func fact(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, Spacing.x1 + 2)
            .padding(.vertical, Spacing.half + 2)
            .background(Color.well, in: Capsule())
    }

    // MARK: Class

    private var classSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle("Choose class")
            if model.classes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.x1 + 4)], spacing: Spacing.x1 + 4) {
                    ForEach(model.classes) { availability in
                        ClassTile(availability: availability,
                                  isSelected: availability.seatClass == model.offer.seatClass,
                                  passengers: model.offer.passengers) {
                            Task { await model.select(availability.seatClass) }
                        }
                    }
                }
            }
            Text("Fares are per seat and include VAT. AC Berth includes a \(FarePolicy.beddingCharge.taka) bedding charge.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle("Route")
            VStack(spacing: 0) {
                ForEach(model.route) { stop in
                    RouteStopRow(stop: stop)
                }
            }
            .surface(radius: Radius.xlarge, padding: Spacing.x2)
        }
    }

    // MARK: Footer

    private var footer: some View {
        BottomBar {
            HStack(spacing: Spacing.x2) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.offer.fare.perSeat.taka)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(model.offer.fare.perSeat)))
                    Text("Per seat · \(model.offer.seatClass.title) · up to \(FarePolicy.maxPassengers) seats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(model.offer.fare.perSeat.takaSpoken) per seat in \(model.offer.seatClass.title), up to \(FarePolicy.maxPassengers) seats per booking")
                Spacer()
                NavigationLink(value: SearchRoute.seats(model.offer)) {
                    Label("Select Seats", systemImage: "chair.fill")
                }
                .primaryAction()
                .disabled(model.offer.isSoldOut || model.isSwitchingClass)
            }
            .animation(.snappy, value: model.offer.seatClass)
        }
    }
}

private struct ClassTile: View {
    let availability: ClassAvailability
    let isSelected: Bool
    let passengers: Int
    let onSelect: () -> Void

    private var isAvailable: Bool { availability.availableSeats >= passengers }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.large, style: .continuous) }
    @ObserveInjection var inject

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Spacing.x1) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(availability.seatClass.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(availability.seatClass.isAirConditioned ? "AC" : "Non-AC")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Spacing.half)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                Text(availability.fare.perSeat.taka)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                Text(isAvailable ? "\(availability.availableSeats) available" : "Sold out")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isAvailable ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .padding(Spacing.x2 - 2)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(Color.raised), in: shape)
            .overlay(shape.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear), lineWidth: 2))
            .contentShape(shape)
            .opacity(isAvailable ? 1 : 0.55)
        }
        .buttonStyle(.pressable)
        .disabled(!isAvailable)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(availability.seatClass.title), \(availability.fare.perSeat.takaSpoken)")
        .accessibilityValue(isAvailable ? "\(availability.availableSeats) available" : "Sold out")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .enableInjection()
    }
}

private struct RouteStopRow: View {
    let stop: TrainDetailViewModel.RouteStop
    @ScaledMetric(relativeTo: .subheadline) private var timeWidth: CGFloat = 72
    @ObserveInjection var inject

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.x2) {
            Text(stop.time.timeText)
                .font(.subheadline.weight(isEndpoint ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(stop.isInJourney ? .primary : .tertiary)
                .frame(width: timeWidth, alignment: .trailing)
                .padding(.vertical, Spacing.x1)

            marker

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.station.name)
                    .font(isEndpoint ? .body.weight(.semibold) : .body)
                    .foregroundStyle(stop.isInJourney ? .primary : .tertiary)
                if let detail {
                    Text(detail)
                        .font(.caption.weight(isEndpoint ? .semibold : .regular))
                        .foregroundStyle(isEndpoint ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
            }
            .padding(.vertical, Spacing.x1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([stop.station.name, stop.time.timeText, detail].compactMap { $0 }.joined(separator: ", "))
        .enableInjection()
    }

    private var isEndpoint: Bool { stop.role == .board || stop.role == .alight }

    private var detail: String? {
        switch stop.role {
        case .board: return "Board here"
        case .alight: return "Get off here"
        default:
            if let halt = stop.haltMinutes { return "\(halt) min halt" }
            return stop.isFirst ? "Origin" : stop.isLast ? "Terminus" : nil
        }
    }

    /// Vertical line with a dot; the segment you travel is drawn in the accent colour.
    private var marker: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(lineStyle(above: true))
                .frame(width: 3, height: Spacing.x1 + 4)
                .opacity(stop.isFirst ? 0 : 1)
            ZStack {
                Circle()
                    .fill(isEndpoint ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.raised))
                Circle()
                    .strokeBorder(stop.isInJourney ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), lineWidth: 2.5)
                if isEndpoint {
                    Circle().fill(Color.raised).frame(width: 6, height: 6)
                }
            }
            .frame(width: isEndpoint ? 18 : 12, height: isEndpoint ? 18 : 12)
            Rectangle()
                .fill(lineStyle(above: false))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .opacity(stop.isLast ? 0 : 1)
        }
        .frame(width: 18)
        .accessibilityHidden(true)
    }

    private func lineStyle(above: Bool) -> AnyShapeStyle {
        let travelled = above
            ? (stop.role == .between || stop.role == .alight)
            : (stop.role == .board || stop.role == .between)
        return travelled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .separator))
    }
}
