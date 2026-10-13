import SwiftUI

struct PaymentView: View {
    @Environment(SessionStore.self) private var session
    @Environment(SearchRouter.self) private var router
    @State private var model: PaymentViewModel
    @FocusState private var focusedField: Field?

    private enum Field { case wallet, cardNumber, expiry, cvc, holder }

    @ObserveInjection var inject

    init(draft: BookingDraft, payments: PaymentService, bookings: BookingRepository) {
        _model = State(initialValue: PaymentViewModel(draft: draft, payments: payments, bookings: bookings))
    }

    private var offer: TrainOffer { model.draft.offer }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x3) {
                StepHeader(step: 4, title: "Review and pay")
                journeyCard
                fareCard
                methodSection
                detailsSection
            }
            .padding(Spacing.x2)
        }
        .background(Color.canvas)
        .navigationTitle("Payment")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isProcessing)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar {
                Button {
                    focusedField = nil
                    Task {
                        if let booking = await model.pay(for: session.user) {
                            router.finish(with: booking)
                        }
                    }
                } label: {
                    ZStack {
                        Label("Pay \(model.fare.total.taka)", systemImage: "lock.fill")
                            .opacity(model.isProcessing ? 0 : 1)
                        if model.isProcessing { ProgressView().tint(Color.onAccent) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .primaryAction()
                .disabled(!model.canPay)
                .accessibilityLabel(model.isProcessing ? "Processing payment" : "Pay \(model.fare.total.takaSpoken)")
            }
        }
        .sensoryFeedback(.error, trigger: model.errorMessage) { _, new in new != nil }
        .sensoryFeedback(.selection, trigger: model.method)
        .enableInjection()
    }

    // MARK: Journey

    private var journeyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x2) {
            HStack(alignment: .top, spacing: Spacing.x1) {
                StationCodeView(station: offer.from, time: offer.departure)
                RouteTrack(caption: offer.duration.durationText)
                    .frame(maxWidth: 110)
                    .padding(.top, Spacing.x1)
                StationCodeView(station: offer.to, alignment: .trailing, time: offer.arrival)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(offer.from.name) \(offer.departure.timeText) to \(offer.to.name) \(offer.arrival.timeText)")
            Divider()
            Grid(alignment: .leading, horizontalSpacing: Spacing.x2, verticalSpacing: Spacing.x2) {
                GridRow {
                    InfoField(title: "Train", value: offer.train.displayName)
                    InfoField(title: "Date", value: offer.departure.dayText)
                }
                GridRow {
                    InfoField(title: "Class", value: offer.seatClass.title)
                    InfoField(title: model.draft.seats.count == 1 ? "Seat" : "Seats",
                              value: model.draft.seats.map(\.id).joined(separator: ", "), monospaced: true)
                }
            }
        }
        .surface(radius: Radius.xlarge, padding: Spacing.x2 + 4)
    }

    // MARK: Fare

    private var fareCard: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle("Fare")
            VStack(spacing: Spacing.x1 + 4) {
                fareRow("Fare (\(model.fare.seats) × \(model.fare.perSeat.base.taka))", model.fare.base)
                if model.fare.vat > 0 { fareRow("VAT", model.fare.vat) }
                if model.fare.bedding > 0 { fareRow("Bedding", model.fare.bedding) }
                fareRow("Service charge", model.fare.serviceCharge)
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(model.fare.total.taka)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Total, \(model.fare.total.takaSpoken)")
            }
            .surface(radius: Radius.xlarge)
        }
    }

    private func fareRow(_ title: String, _ amount: Int) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(amount.taka).monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(amount.takaSpoken)")
    }

    // MARK: Method

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle("Pay with")
            HStack(spacing: Spacing.x1) {
                ForEach(PaymentMethod.allCases) { method in
                    methodTile(method)
                }
            }
        }
    }

    private func methodTile(_ method: PaymentMethod) -> some View {
        let isSelected = model.method == method
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        return Button {
            withAnimation(.snappy) {
                model.method = method
                model.errorMessage = nil
            }
        } label: {
            VStack(spacing: Spacing.x1) {
                Image(systemName: method.tileSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(height: 28)
                Text(method.shortTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(Color.raised), in: shape)
            .overlay(shape.strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear), lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                        .padding(Spacing.x1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(method.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.x1 + 4) {
            SectionTitle(model.method.isWallet ? "\(model.method.title) account" : "Card details")
            VStack(alignment: .leading, spacing: Spacing.x2) {
                if model.method.isWallet {
                    InputField(label: "Account number", symbol: "iphone", isFocused: focusedField == .wallet) {
                        TextField("Account number", text: $model.walletNumber, prompt: Text("01XXXXXXXXX"))
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focusedField, equals: .wallet)
                    }
                } else {
                    InputField(label: "Card number", symbol: "creditcard", isFocused: focusedField == .cardNumber) {
                        TextField("Card number", text: $model.cardNumber, prompt: Text("1234 5678 9012 3456"))
                            .keyboardType(.numberPad)
                            .textContentType(.creditCardNumber)
                            .monospacedDigit()
                            .focused($focusedField, equals: .cardNumber)
                            .onChange(of: model.cardNumber) { model.formatCardNumber() }
                    }
                    HStack(spacing: Spacing.x1 + 4) {
                        InputField(label: "Expiry", isFocused: focusedField == .expiry) {
                            TextField("Expiry", text: $model.cardExpiry, prompt: Text("MM/YY"))
                                .keyboardType(.numberPad)
                                .monospacedDigit()
                                .focused($focusedField, equals: .expiry)
                                .onChange(of: model.cardExpiry) { model.formatExpiry() }
                                .accessibilityLabel("Expiry date, month and year")
                        }
                        InputField(label: "CVC", isFocused: focusedField == .cvc) {
                            SecureField("CVC", text: $model.cardCVC, prompt: Text("123"))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .cvc)
                                .onChange(of: model.cardCVC) { model.formatCVC() }
                                .accessibilityLabel("Security code")
                        }
                    }
                    InputField(label: "Name on card", symbol: "person", isFocused: focusedField == .holder) {
                        TextField("Name on card", text: $model.cardHolder)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .holder)
                    }
                }

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
            .surface(radius: Radius.xlarge)

            Label("Demo payment. No money is charged and card details are never stored. The service charge is non-refundable.",
                  systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.half)
        }
    }
}

private extension PaymentMethod {
    var shortTitle: String { self == .card ? "Card" : title }

    var tileSymbol: String {
        switch self {
        case .bkash: "iphone.gen3"
        case .nagad: "iphone.gen3.radiowaves.left.and.right"
        case .card: "creditcard.fill"
        }
    }
}
