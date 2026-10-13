import SwiftUI

/// Departure → arrival summary used by results, details and tickets.
struct JourneyTimesView: View {
    enum Size { case regular, large }

    let departure: Date
    let arrival: Date
    let from: String
    let to: String
    var size: Size = .regular

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObserveInjection var inject

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.x1) {
                    endpoint(departure, from, alignment: .leading)
                    Label(duration, systemImage: "arrow.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    endpoint(arrival, to, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .top, spacing: Spacing.x2) {
                    endpoint(departure, from, alignment: .leading)
                    RouteTrack(caption: duration)
                        .padding(.top, size == .large ? 2 : 0)
                        .frame(maxWidth: .infinity)
                    endpoint(arrival, to, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Departs \(departure.timeText) from \(from). Arrives \(arrival.timeText) at \(to). \(arrival.timeIntervalSince(departure).durationSpoken).")
        .enableInjection()
    }

    private var duration: String { arrival.timeIntervalSince(departure).durationText }

    private var timeFont: Font {
        size == .large
            ? .system(.title, design: .rounded, weight: .bold)
            : .system(.title2, design: .rounded, weight: .bold)
    }

    private func endpoint(_ date: Date, _ station: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(date.timeText)
                .font(timeFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(station)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    JourneyTimesView(departure: .now, arrival: .now.addingTimeInterval(5 * 3600 + 1200), from: "Dhaka", to: "Chattogram")
        .padding()
}
