import SwiftUI

struct TicketView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var booking: Booking
    @State private var isConfirmingCancel = false
    @State private var isCancelling = false
    @State private var errorMessage: String?

    private let isConfirmation: Bool
    private let onViewTrips: (() -> Void)?
    @ObserveInjection var inject

    init(booking: Booking, isConfirmation: Bool = false, onViewTrips: (() -> Void)? = nil) {
        _booking = State(initialValue: booking)
        self.isConfirmation = isConfirmation
        self.onViewTrips = onViewTrips
    }

    private var refund: Int? { RefundPolicy.refund(for: booking.fare, departure: booking.departure) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                if isConfirmation {
                    ConfirmationHeader()
                }
                BoardingPass(booking: booking)
                passengersSection
                paymentSection
                if booking.canCancel {
                    cancelSection
                }
            }
            .padding(Spacing.x2)
        }
        .background(Color.canvas)
        .navigationTitle("E‑Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: shareText, subject: Text("Train ticket \(booking.pnr)")) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            if isConfirmation {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isConfirmation, let onViewTrips {
                BottomBar {
                    Button(action: onViewTrips) {
                        Text("View My Trips").frame(maxWidth: .infinity)
                    }
                    .primaryAction()
                }
            }
        }
        .confirmationDialog("Cancel this ticket?", isPresented: $isConfirmingCancel, titleVisibility: .visible) {
            Button("Cancel Ticket", role: .destructive) { Task { await cancel() } }
            Button("Keep Ticket", role: .cancel) {}
        } message: {
            if let refund {
                Text("\(refund.taka) will be refunded to your \(booking.paymentMethod.title). The \(booking.fare.serviceCharge.taka) service charge is not refundable.")
            }
        }
        .sensoryFeedback(.success, trigger: booking.status) { _, new in new == .cancelled }
        .enableInjection()
    }

    // MARK: Sections

    private var passengersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle("Passengers")
            VStack(spacing: 0) {
                ForEach(Array(booking.passengers.enumerated()), id: \.element.seatID) { index, passenger in
                    if index > 0 { Divider().padding(.leading, Spacing.x2 + 40 + Spacing.x2) }
                    HStack(spacing: Spacing.x2) {
                        Group {
                            if passenger.isNamed {
                                Text(initials(passenger.name))
                            } else {
                                Image(systemName: "person.fill")
                            }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.tint)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(passenger.isNamed ? passenger.name : "Guest \(index + 1)")
                                .font(.body.weight(.medium))
                            Text(passenger.details ?? "Travelling with \(booking.passengers.first?.name ?? "lead")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Spacing.x1)
                        Text(passenger.seatID)
                            .font(.subheadline.weight(.bold).monospaced())
                            .padding(.horizontal, Spacing.x1 + 2)
                            .padding(.vertical, Spacing.half + 2)
                            .background(Color.well, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    }
                    .padding(.horizontal, Spacing.x2)
                    .padding(.vertical, Spacing.x1 + 4)
                    .accessibilityElement(children: .combine)
                }
                Divider().padding(.leading, Spacing.x2)
                row("Contact", booking.contactPhone.maskedPhone)
            }
            .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
        }
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle("Payment")
            VStack(spacing: 0) {
                row("Fare", booking.fare.fare.taka)
                row("Service charge", booking.fare.serviceCharge.taka)
                Divider().padding(.horizontal, Spacing.x2)
                HStack {
                    Text("Total paid").font(.headline)
                    Spacer()
                    Text(booking.fare.total.taka)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
                .padding(.horizontal, Spacing.x2)
                .padding(.vertical, Spacing.x1 + 4)
                .accessibilityElement(children: .combine)
                Divider().padding(.horizontal, Spacing.x2)
                row("Paid with", booking.paymentMethod.title)
                row("Transaction", booking.transactionID, monospaced: true)
                if let refundAmount = booking.refundAmount {
                    row("Refunded", refundAmount.taka)
                }
            }
            .padding(.vertical, Spacing.half)
            .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
        }
    }

    private var cancelSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1) {
            Button(role: .destructive) {
                isConfirmingCancel = true
            } label: {
                Label("Cancel Ticket", systemImage: "xmark.circle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.raised, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            }
            .buttonStyle(.pressable)
            .foregroundStyle(.red)
            .disabled(isCancelling)
            Group {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if let refund {
                    Text("Cancel now for a refund of \(refund.taka). Refunds shrink closer to departure.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .padding(.horizontal, Spacing.half)
        }
    }

    private func row(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: Spacing.x2)
            Text(value)
                .font(monospaced ? .subheadline.monospaced() : .body)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.vertical, Spacing.x1 + 4)
        .accessibilityElement(children: .combine)
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private var shareText: String {
        """
        \(booking.trainDisplayName)
        \(booking.from.name) to \(booking.to.name)
        \(booking.departure.longDayText), \(booking.departure.timeText)
        \(booking.seatClass.code) · Seats \(booking.seatIDs.joined(separator: ", "))
        PNR \(booking.pnr)
        """
    }

    private func cancel() async {
        isCancelling = true
        defer { isCancelling = false }
        do {
            booking = try await container.bookings.cancel(booking)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The ticket itself: journey on the main body, scannable code on the tear-off stub.
private struct BoardingPass: View {
    let booking: Booking
    @ObserveInjection var inject

    var body: some View {
        TicketCard {
            VStack(alignment: .leading, spacing: Spacing.x2 + 4) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(booking.trainName)
                            .font(.headline)
                        Text("Train \(booking.trainNumber)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    booking.statusLabel
                }

                HStack(alignment: .top, spacing: Spacing.x1) {
                    StationCodeView(station: booking.from, time: booking.departure)
                    RouteTrack(caption: booking.arrival.timeIntervalSince(booking.departure).durationText)
                        .frame(maxWidth: 120)
                        .padding(.top, Spacing.x1)
                    StationCodeView(station: booking.to, alignment: .trailing, time: booking.arrival)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(booking.from.name) \(booking.departure.timeText) to \(booking.to.name) \(booking.arrival.timeText)")

                Grid(alignment: .leading, horizontalSpacing: Spacing.x2, verticalSpacing: Spacing.x2) {
                    GridRow {
                        InfoField(title: "Date", value: booking.departure.dayText)
                        InfoField(title: "Class", value: booking.seatClass.title)
                    }
                    GridRow {
                        InfoField(title: booking.passengers.count == 1 ? "Seat" : "Seats",
                                  value: booking.seatIDs.joined(separator: ", "), monospaced: true)
                        InfoField(title: "PNR", value: booking.pnr, monospaced: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(Spacing.x2 + 4)
        } stub: {
            if booking.status == .confirmed {
                VStack(spacing: Spacing.x1 + 4) {
                    QRCodeView(payload: booking.qrPayload, pnr: booking.pnr)
                    Text("Show this code and a photo ID to the ticket checker.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.x2 + 4)
                .frame(maxWidth: .infinity)
            } else {
                Label("This ticket is no longer valid for travel.", systemImage: "xmark.octagon")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(Spacing.x2 + 4)
                    .frame(maxWidth: .infinity)
            }
        }
        .opacity(booking.status == .cancelled ? 0.75 : 1)
        .enableInjection()
    }
}

private struct ConfirmationHeader: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64
    @State private var didAppear = false
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: Spacing.x1 + 4) {
            Image(systemName: "checkmark")
                .font(.system(size: iconSize * 0.45, weight: .bold))
                .foregroundStyle(Color.onAccent)
                .frame(width: iconSize, height: iconSize)
                .background(.tint, in: Circle())
                .scaleEffect(didAppear ? 1 : 0.4)
                .opacity(didAppear ? 1 : 0)
                .accessibilityHidden(true)
            VStack(spacing: Spacing.half) {
                Text("You're booked")
                    .font(.title.bold())
                Text("Your e‑ticket is saved in My Trips.")
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.x2)
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.1)) { didAppear = true }
        }
        .sensoryFeedback(.success, trigger: didAppear) { _, new in new }
        .enableInjection()
    }
}

struct QRCodeView: View {
    let payload: String
    let pnr: String
    @ScaledMetric private var size: CGFloat = 196
    @ObserveInjection var inject

    var body: some View {
        Group {
            if let image = QRCode.image(for: payload) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(size, 260), height: min(size, 260))
                    .padding(Spacing.x2)
                    // QR codes need a light quiet zone to scan, including in Dark Mode.
                    .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ticket QR code for PNR \(pnr)")
        .accessibilityAddTraits(.isImage)
        .enableInjection()
    }
}
