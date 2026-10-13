import SwiftUI

/// Looks up any ticket on this device by PNR and the mobile number used to book it.
struct VerifyTicketView: View {
    let repository: BookingRepository

    @Environment(\.dismiss) private var dismiss
    @State private var pnr = ""
    @State private var phone = ""
    @State private var result: Booking?
    @State private var errorMessage: String?
    @State private var isChecking = false

    private var canVerify: Bool { pnr.trimmed.count >= 6 && Validation.isMobile(phone) && !isChecking }

    @FocusState private var focus: Field?

    private enum Field { case pnr, phone }
    @ObserveInjection var inject

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.x3) {
                    HStack(alignment: .top, spacing: Spacing.x2) {
                        IconBadge(systemName: "checkmark.shield.fill", size: 44)
                        Text("Enter the PNR from the e‑ticket and the mobile number used to book it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: Spacing.x2) {
                        InputField(label: "PNR", symbol: "number", isFocused: focus == .pnr) {
                            TextField("PNR", text: $pnr, prompt: Text("e.g. R7K2QX"))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.body.monospaced())
                                .focused($focus, equals: .pnr)
                                .submitLabel(.next)
                                .onSubmit { focus = .phone }
                        }
                        InputField(label: "Mobile number", symbol: "phone", isFocused: focus == .phone) {
                            TextField("Mobile number", text: $phone, prompt: Text("01XXXXXXXXX"))
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .monospacedDigit()
                                .focused($focus, equals: .phone)
                        }
                    }

                    Button {
                        focus = nil
                        Task { await verify() }
                    } label: {
                        ZStack {
                            Text("Verify Ticket").opacity(isChecking ? 0 : 1)
                            if isChecking { ProgressView().tint(Color.onAccent) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .primaryAction()
                    .disabled(!canVerify)

                    if let result {
                        resultCard(result)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "questionmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .surface()
                    }
                }
                .padding(Spacing.x2)
                .animation(.snappy, value: result?.id)
            }
            .background(Color.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Verify Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: pnr) { result = nil; errorMessage = nil }
            .onChange(of: phone) { result = nil; errorMessage = nil }
            .sensoryFeedback(trigger: result?.id) { _, _ in
                guard let result else { return nil }
                return result.status == .confirmed ? .success : .warning
            }
        }
        .enableInjection()
    }

    private func resultCard(_ result: Booking) -> some View {
        let isValid = result.status == .confirmed
        return VStack(alignment: .leading, spacing: Spacing.x2) {
            Label {
                Text(isValid ? "Valid ticket" : "Cancelled ticket")
                    .font(.headline)
            } icon: {
                Image(systemName: isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(isValid ? AnyShapeStyle(.tint) : AnyShapeStyle(.red))
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: Spacing.x2, verticalSpacing: Spacing.x2) {
                GridRow {
                    InfoField(title: "Train", value: result.trainDisplayName)
                    InfoField(title: "Departs", value: "\(result.departure.dayText), \(result.departure.timeText)")
                }
                GridRow {
                    InfoField(title: "Route", value: "\(result.from.code) → \(result.to.code)")
                    InfoField(title: "Seats", value: result.seatIDs.joined(separator: ", "), monospaced: true)
                }
            }
        }
        .surface(radius: Radius.xlarge)
    }

    private func verify() async {
        isChecking = true
        defer { isChecking = false }
        do {
            result = try await repository.verify(pnr: pnr, phone: phone)
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
    }
}
