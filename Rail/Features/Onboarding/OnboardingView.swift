import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(symbol: nil,
                       companions: ["map", "clock"],
                       title: "Every intercity train,\none search away",
                       message: "Search trains across Bangladesh by station, date and class."),
        OnboardingPage(symbol: "chair.lounge.fill",
                       companions: ["person.2.fill", "checkmark"],
                       title: "Sit together,\nthe way you planned",
                       message: "Browse each coach and pick seats next to the people you travel with."),
        OnboardingPage(symbol: "qrcode",
                       companions: ["iphone", "creditcard.fill"],
                       title: "Pay and board\nwith your phone",
                       message: "Pay with bKash, Nagad or card and keep every e‑ticket on your phone."),
    ]
    @ObserveInjection var inject

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: Spacing.x1) {
                    BrandLogo(size: 28)
                    Text("Rail")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Button("Skip", action: onFinish)
                    .font(.body.weight(.medium))
                    .opacity(isLastPage ? 0 : 1)
                    .disabled(isLastPage)
            }
            .padding(.horizontal, Spacing.x3)
            .frame(minHeight: 44)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index], isActive: page == index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: Spacing.x3) {
                PageDots(count: pages.count, current: page)
                Button {
                    if isLastPage { onFinish() } else { withAnimation(.snappy) { page += 1 } }
                } label: {
                    Text(isLastPage ? "Get Started" : "Continue")
                        .frame(maxWidth: .infinity)
                        .contentTransition(.opacity)
                }
                .primaryAction()
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.bottom, Spacing.x2)
        }
        .background(Color.canvas)
        .sensoryFeedback(.selection, trigger: page)
        .enableInjection()
    }

    private var isLastPage: Bool { page == pages.count - 1 }
}

private struct OnboardingPage {
    /// Nil shows the brand mark instead of a symbol.
    let symbol: String?
    let companions: [String]
    let title: String
    let message: String
}

private struct PageDots: View {
    let count: Int
    let current: Int
    @ObserveInjection var inject

    var body: some View {
        HStack(spacing: Spacing.x1) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.well))
                    .frame(width: index == current ? 28 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
        .enableInjection()
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 220
    @ObserveInjection var inject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.x4) {
                hero
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: Spacing.x2) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text(page.message)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Spacing.x3)
            .padding(.top, Spacing.x4)
            .padding(.bottom, Spacing.x3)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityElement(children: .combine)
        .enableInjection()
    }

    /// A tinted tile holding the page symbol, with two smaller companion tiles orbiting it.
    private var hero: some View {
        let size = min(heroSize, 280)
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
                .frame(width: size, height: size)
            Group {
                if let symbol = page.symbol {
                    RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                        .fill(.tint)
                        .frame(width: size * 0.56, height: size * 0.56)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.system(size: size * 0.24, weight: .semibold))
                                .foregroundStyle(Color.onAccent)
                                .symbolEffect(.bounce, value: isActive)
                        }
                } else {
                    BrandLogo(size: size * 0.64)
                        .shadow(color: BrandPalette.deep.opacity(0.3), radius: 18, y: 10)
                }
            }
            .rotationEffect(.degrees(isActive ? -6 : 0))
            companion(page.companions[0], size: size * 0.24)
                .offset(x: -size * 0.42, y: -size * 0.32)
                .offset(y: isActive ? 0 : 12)
            companion(page.companions[1], size: size * 0.2)
                .offset(x: size * 0.42, y: size * 0.34)
                .offset(y: isActive ? 0 : -12)
        }
        .frame(height: size * 1.1)
        .opacity(isActive ? 1 : 0.4)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isActive)
        .accessibilityHidden(true)
    }

    private func companion(_ symbol: String, size: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(Color.raised, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

#Preview {
    OnboardingView {}
}
