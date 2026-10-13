import SwiftUI

struct TrainResultsView: View {
    @State private var model: TrainResultsViewModel
    @ObserveInjection var inject

    init(query: SearchQuery, trains: TrainRepository) {
        _model = State(initialValue: TrainResultsViewModel(query: query, trains: trains))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas)
            .safeAreaInset(edge: .top, spacing: 0) {
                DateStrip(dates: model.dates, selection: $model.query.date)
                    .background(.bar)
                .overlay(alignment: .bottom) { Divider() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        HStack(spacing: Spacing.half) {
                            Text(model.query.from.code)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tint)
                            Text(model.query.to.code)
                        }
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        Text(model.query.date.dayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(model.query.from.name) to \(model.query.to.name), \(model.query.date.dayText)")
                    .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort by", selection: $model.sortOrder) {
                            ForEach(TrainResultsViewModel.SortOrder.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .task(id: model.query.date) { await model.load() }
            .sensoryFeedback(.selection, trigger: model.query.date)
            .enableInjection()
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load trains", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { Task { await model.load() } }
            }
        case .loaded where model.results.isEmpty:
            ContentUnavailableView {
                Label("No trains", systemImage: "tram")
            } description: {
                Text("No trains run from \(model.query.from.name) to \(model.query.to.name) on \(model.query.date.dayText). Try another date.")
            }
        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
                    Text(summary)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.half)
                    ForEach(model.results) { result in
                        TrainResultRow(result: result,
                                       offer: model.offer(for: result),
                                       searchedClass: model.query.seatClass) { seatClass in
                            withAnimation(.snappy) { model.choose(seatClass, for: result) }
                        }
                    }
                    Text("Fares are per seat and include VAT. A \(FarePolicy.serviceChargePerSeat.taka) service charge per seat is added at payment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.half)
                }
                .padding(Spacing.x2)
                .animation(.snappy, value: model.sortOrder)
            }
        }
    }

    private var summary: String {
        let total = model.results.count
        let matching = model.matchingCount
        let trains = "\(total) \(total == 1 ? "train" : "trains")"
        guard matching < total else { return "\(trains) with \(model.query.seatClass.title)" }
        return "\(trains) · \(matching) with \(model.query.seatClass.title)"
    }
}

/// Ticket-shaped result: train and times above the tear line; seat type and the way forward below.
struct TrainResultRow: View {
    let result: TrainResult
    let offer: TrainOffer
    let searchedClass: SeatClass
    let onChoose: (SeatClass) -> Void
    @ObserveInjection var inject

    var body: some View {
        TicketCard {
            NavigationLink(value: SearchRoute.detail(offer)) {
                VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.x1) {
                        Text(result.train.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(result.train.number)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.well, in: Capsule())
                        Spacer(minLength: Spacing.x1)
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    JourneyTimesView(departure: offer.departure, arrival: offer.arrival,
                                     from: offer.from.name, to: offer.to.name)
                        .foregroundStyle(.primary)
                }
                .padding(Spacing.x2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityHint("Shows route and class details")
        } stub: {
            VStack(alignment: .leading, spacing: Spacing.x1 + Spacing.half) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.x1) {
                        ForEach(result.offers) { classOffer in
                            SeatClassPill(seatClass: classOffer.seatClass,
                                          isSelected: classOffer.seatClass == offer.seatClass,
                                          fare: classOffer.fare.perSeat.taka,
                                          available: classOffer.availableSeats,
                                          isEnabled: !classOffer.isSoldOut) {
                                onChoose(classOffer.seatClass)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.x2)
                }

                HStack(spacing: Spacing.x1) {
                    availability
                    Spacer(minLength: Spacing.x1)
                    NavigationLink(value: SearchRoute.seats(offer)) {
                        HStack(spacing: Spacing.half) {
                            Text("Select seats")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.onAccent)
                        .padding(.horizontal, Spacing.x2 - 2)
                        .frame(minHeight: 36)
                        .background(.tint, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .disabled(offer.isSoldOut)
                    .opacity(offer.isSoldOut ? 0.4 : 1)
                }
                .padding(.horizontal, Spacing.x2)
            }
            .padding(.vertical, Spacing.x1 + Spacing.half)
        }
        .enableInjection()
    }

    @ViewBuilder
    private var availability: some View {
        VStack(alignment: .leading, spacing: 0) {
            if offer.isSoldOut {
                Label("Not enough seats", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            } else {
                let isLow = offer.availableSeats < 20
                Label(isLow ? "Only \(offer.availableSeats) left" : "\(offer.availableSeats) \(offer.seatClass.seatNoun)s free",
                      systemImage: isLow ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
            if result.offer(for: searchedClass) == nil {
                Text("No \(searchedClass.title) on this train")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
}

/// Horizontal day selector covering the booking window.
private struct DateStrip: View {
    let dates: [Date]
    @Binding var selection: Date
    @ObserveInjection var inject

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.x1) {
                    ForEach(dates, id: \.self) { date in
                        dayButton(date)
                            .id(date)
                    }
                }
                .padding(.horizontal, Spacing.x2)
                .padding(.vertical, Spacing.x1)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { withAnimation(.snappy) { proxy.scrollTo(selection, anchor: .center) } }
        }
        .enableInjection()
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selection)
        return Button {
            withAnimation(.snappy) { selection = date }
        } label: {
            HStack(spacing: Spacing.half) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .opacity(isSelected ? 0.9 : 0.6)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, Spacing.x1 + Spacing.half)
            .frame(minHeight: 36)
            .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(date.longDayText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
