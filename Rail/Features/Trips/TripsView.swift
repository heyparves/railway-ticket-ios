import SwiftUI

struct TripsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(SessionStore.self) private var session
    @State private var model = TripsViewModel()
    @State private var isVerifying = false
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.x1 + 4) {
                    Picker("Trips", selection: $model.segment) {
                        ForEach(TripsViewModel.Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, Spacing.x1)

                    if model.hasLoaded && model.visible.isEmpty {
                        emptyState
                            .padding(.top, Spacing.x6)
                    } else {
                        ForEach(model.visible) { booking in
                            NavigationLink(value: booking) {
                                TripRow(booking: booking)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .padding(Spacing.x2)
                .animation(.snappy, value: model.segment)
            }
            .background(Color.canvas)
            .navigationTitle("My Trips")
            .navigationDestination(for: Booking.self) { booking in
                TicketView(booking: booking)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isVerifying = true
                    } label: {
                        Label("Verify Ticket", systemImage: "checkmark.shield")
                    }
                }
            }
            .sheet(isPresented: $isVerifying) {
                VerifyTicketView(repository: container.bookings)
            }
            .refreshable { await reload() }
            .onAppear { Task { await reload() } }
            .sensoryFeedback(.selection, trigger: model.segment)
        }
        .enableInjection()
    }

    @ViewBuilder
    private var emptyState: some View {
        switch model.segment {
        case .upcoming:
            ContentUnavailableView("No upcoming trips",
                                   systemImage: "ticket",
                                   description: Text("Tickets you book appear here."))
        case .past:
            ContentUnavailableView("No past trips",
                                   systemImage: "clock",
                                   description: Text("Completed and cancelled tickets appear here."))
        }
    }

    private func reload() async {
        await model.load(repository: container.bookings, user: session.user)
    }
}

/// Ticket stub: date block on the left, journey on the right, separated by a vertical tear line.
private struct TripRow: View {
    let booking: Booking
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(booking.departure.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                Text(booking.departure.formatted(.dateTime.day()))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text(booking.departure.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 72)
            .padding(.vertical, Spacing.x2)

            VerticalPerforation()

            VStack(alignment: .leading, spacing: Spacing.x1) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.half) {
                    Text(booking.from.code)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    Text(booking.to.code)
                    Spacer(minLength: Spacing.x1)
                    if !booking.isUpcoming {
                        booking.statusLabel
                    }
                }
                .font(.system(.title3, design: .rounded, weight: .bold))
                Text("\(booking.from.name) to \(booking.to.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: Spacing.x2) {
                    Label(booking.departure.timeText, systemImage: "clock")
                    Label(booking.trainName, systemImage: "tram")
                        .lineLimit(1)
                    Label("\(booking.passengers.count)", systemImage: "person.fill")
                        .accessibilityLabel("\(booking.passengers.count) \(booking.passengers.count == 1 ? "passenger" : "passengers")")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .labelStyle(CompactLabelStyle())
            }
            .foregroundStyle(.primary)
            .padding(Spacing.x2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
        .opacity(booking.status == .cancelled ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(booking.from.name) to \(booking.to.name), \(booking.departure.longDayText) at \(booking.departure.timeText), \(booking.trainDisplayName)")
        .enableInjection()
    }

    private var isActive: Bool { booking.isUpcoming }
}

private struct VerticalPerforation: View {
    @ObserveInjection var inject

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0.75, y: 0))
                path.addLine(to: CGPoint(x: 0.75, y: proxy.size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
            .foregroundStyle(Color(uiColor: .separator))
        }
        .frame(width: 1.5)
        .padding(.vertical, Spacing.x1 + 4)
        .accessibilityHidden(true)
        .enableInjection()
    }
}

private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
