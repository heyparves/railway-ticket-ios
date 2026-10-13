import SwiftUI

/// 8pt spacing grid. `half` exists only for tight icon/text pairings.
enum Spacing {
    static let half: CGFloat = 4
    static let x1: CGFloat = 8
    static let x2: CGFloat = 16
    static let x3: CGFloat = 24
    static let x4: CGFloat = 32
    static let x6: CGFloat = 48
}

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 24
}

extension Color {
    /// Screen background behind surfaces.
    static let canvas = Color(uiColor: .systemGroupedBackground)
    /// Raised content surface, one step above the canvas.
    static let raised = Color(uiColor: .secondarySystemGroupedBackground)
    /// Inset well inside a surface (fields, tracks, chips).
    static let well = Color(uiColor: .tertiarySystemFill)
    /// Text and symbols placed on a solid accent fill.
    static let onAccent = Color.white
}

extension View {
    /// Full-width prominent action, the one primary button per screen.
    func primaryAction() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    /// Raised rounded surface used for the few grouped blocks on a screen.
    func surface(radius: CGFloat = Radius.large, padding: CGFloat = Spacing.x2) -> some View {
        self.padding(padding)
            .background(Color.raised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Solid accent capsule with press feedback. Disabled state drops to a neutral fill.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? Color.onAccent : Color.secondary)
            .padding(.horizontal, Spacing.x3)
            .frame(minHeight: 50)
            .background(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well),
                        in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }
}

/// Subtle shrink on press for tappable surfaces that aren't buttons-with-chrome.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// Pinned footer for a screen's primary action, using the system bar material.
/// Kept to a single row where possible so the content above keeps the room.
struct BottomBar<Content: View>: View {
    @ViewBuilder var content: Content
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: Spacing.x1) {
            content
        }
        .padding(.horizontal, Spacing.x2)
        .padding(.top, Spacing.x1 + Spacing.half)
        .padding(.bottom, Spacing.half)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .enableInjection()
    }
}

/// Running total for a checkout bar: amount on top, one line of context underneath.
struct BarTotal<Detail: View>: View {
    let amount: Int
    @ViewBuilder var detail: Detail
    @ObserveInjection var inject

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(amount.taka)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            detail
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .animation(.snappy, value: amount)
        .enableInjection()
    }
}

/// Small label for ticket state, tinted rather than filled.
struct StatusLabel: View {
    enum Style { case accent, neutral, destructive }

    let text: String
    let style: Style
    @ObserveInjection var inject

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.x1)
            .padding(.vertical, Spacing.half)
            .background(color.opacity(0.12), in: Capsule())
            .enableInjection()
    }

    private var color: Color {
        switch style {
        case .accent: .accentColor
        case .neutral: .secondary
        case .destructive: .red
        }
    }
}

extension Booking {
    var statusLabel: StatusLabel {
        switch status {
        case .cancelled: StatusLabel(text: "Cancelled", style: .destructive)
        case .confirmed: isUpcoming ? StatusLabel(text: "Confirmed", style: .accent) : StatusLabel(text: "Completed", style: .neutral)
        }
    }
}
