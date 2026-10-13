import SwiftUI

/// Rounded ticket outline with a semicircular notch cut into each side at `notchOffset` from the top.
/// Pair with `PerforationLine` at the same offset to read as a tear-off stub.
struct TicketShape: Shape {
    var cornerRadius: CGFloat = Radius.xlarge
    var notchOffset: CGFloat
    var notchRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let body = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        let y = rect.minY + min(max(notchOffset, cornerRadius + notchRadius), rect.height - cornerRadius - notchRadius)
        var notches = Path()
        notches.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        notches.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius, width: notchRadius * 2, height: notchRadius * 2))
        return body.subtracting(notches)
    }
}

extension View {
    /// Fills the view with a ticket outline whose notches sit `notchOffset` points from the top.
    func ticketBackground(_ style: some ShapeStyle = Color.raised, notchOffset: CGFloat) -> some View {
        background(style, in: TicketShape(notchOffset: notchOffset))
    }
}

/// Two-part ticket: a main body and a tear-off stub, separated by a perforation with side notches.
struct TicketCard<Main: View, Stub: View>: View {
    var fill: Color = .raised
    var notchRadius: CGFloat = 12
    @ViewBuilder var main: Main
    @ViewBuilder var stub: Stub

    @State private var mainHeight: CGFloat = 0
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: 0) {
            main
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mainHeight = $0 }
            PerforationLine()
                .padding(.horizontal, notchRadius + Spacing.half)
            stub
        }
        .background(fill, in: TicketShape(notchOffset: mainHeight, notchRadius: notchRadius))
        .enableInjection()
    }
}

/// Dashed tear line used across ticket stubs.
struct PerforationLine: View {
    @ObserveInjection var inject

    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 6]))
            .foregroundStyle(Color(uiColor: .separator))
            .frame(height: 1.5)
            .accessibilityHidden(true)
            .enableInjection()
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

/// Origin ○──── 🚆 ────● destination track drawn between two endpoints.
struct RouteTrack: View {
    var caption: String?
    var tint: AnyShapeStyle = AnyShapeStyle(.tint)
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: Spacing.half) {
            if let caption {
                Text(caption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            HStack(spacing: Spacing.half) {
                Circle()
                    .strokeBorder(tint, lineWidth: 2)
                    .frame(width: 9, height: 9)
                dashes
                Image(systemName: "tram.fill")
                    .font(.caption)
                    .foregroundStyle(tint)
                dashes
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)
            }
        }
        .accessibilityHidden(true)
        .enableInjection()
    }

    private var dashes: some View {
        Capsule()
            .fill(Color(uiColor: .separator))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

/// Large station code with the full name underneath, the anchor of every journey header.
struct StationCodeView: View {
    let station: Station
    var alignment: HorizontalAlignment = .leading
    var time: Date?
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(station.code)
                .font(.system(.title, design: .rounded, weight: .bold))
                .tracking(0.5)
            Text(station.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if let time {
                Text(time.timeText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .enableInjection()
    }
}

/// Uppercase eyebrow label over a value, used in ticket and summary grids.
struct InfoField: View {
    let title: String
    let value: String
    var monospaced = false
    var alignment: HorizontalAlignment = .leading
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .body.weight(.semibold).monospaced() : .body.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .combine)
        .enableInjection()
    }
}

/// Screen-level section header that sits on the canvas, outside surfaces.
struct SectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @ObserveInjection var inject

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.x1)
            trailing
                .font(.subheadline)
        }
        .enableInjection()
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// Selectable pill. Selected chips take the accent fill; the rest sit in a neutral well.
struct ChoiceChip: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    @ObserveInjection var inject

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .opacity(0.8)
                }
            }
            .lineLimit(1)
            .padding(.horizontal, Spacing.x2)
            .padding(.vertical, Spacing.x1 + 2)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well),
                        in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .enableInjection()
    }
}

/// Labelled input well. Wraps any field so text inputs share one look outside of `Form`.
struct InputField<Content: View>: View {
    let label: String
    var symbol: String?
    var isFocused = false
    @ViewBuilder var content: Content
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.half + 2) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            HStack(spacing: Spacing.x1 + 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.body)
                        .foregroundStyle(isFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .frame(width: 22)
                        .accessibilityHidden(true)
                }
                content
                    .font(.body)
            }
            .padding(.horizontal, Spacing.x2)
            .frame(minHeight: 52)
            .background(Color.well, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(isFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.clear), lineWidth: 1.5))
            .animation(.snappy(duration: 0.2), value: isFocused)
        }
        .enableInjection()
    }
}

/// Label-over-value row for grouped forms. Rows stack inside one surface, split by hairlines,
/// so a form reads as a single block instead of a pile of separate wells.
struct FieldRow<Content: View>: View {
    let label: String
    var isFocused = false
    var error: String?
    @ViewBuilder var content: Content
    @ObserveInjection var inject

    private var labelStyle: AnyShapeStyle {
        if error != nil { return AnyShapeStyle(Color.red) }
        return isFocused ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.half) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(labelStyle)
                .accessibilityHidden(true)
            content
                .font(.body)
                .frame(minHeight: 30)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.vertical, Spacing.x1 + 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isFocused ? Color.accentColor.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.2), value: isFocused)
        .animation(.snappy(duration: 0.2), value: error)
        .enableInjection()
    }
}

/// SF Symbol set in a softly tinted rounded square.
struct IconBadge: View {
    let systemName: String
    var size: CGFloat = 36
    var filled = false
    @ObserveInjection var inject

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(filled ? AnyShapeStyle(Color.onAccent) : AnyShapeStyle(.tint))
            .frame(width: size, height: size)
            .background(filled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.accentColor.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
            .enableInjection()
    }
}

/// Calendar-style day block: weekday over a big day number.
struct DayBlock: View {
    let date: Date
    var isSelected = false
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
            Text(date.formatted(.dateTime.day()))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(date.formatted(.dateTime.month(.abbreviated)))
                .font(.caption2)
                .opacity(0.8)
        }
        .frame(minWidth: 52)
        .padding(.vertical, Spacing.x1)
        .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
        .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.raised),
                    in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .enableInjection()
    }
}
