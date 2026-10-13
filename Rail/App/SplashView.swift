import SwiftUI

/// Brand moment on cold launch, drawn full-bleed: one sky runs edge to edge, the scene from the
/// app icon sits on the bottom edge at full width, and the wordmark is centred in the sky above.
/// The sun rises, rails draw out to the horizon, the engine rolls in and flashes its headlights.
/// Hands over through `onFinish`.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sun: CGFloat = 0
    @State private var rails: CGFloat = 0
    @State private var train: CGFloat = 0
    @State private var headlight: CGFloat = 0
    @State private var showsWordmark = false
    @ObserveInjection var inject

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            // The square scene sits just above the bottom edge (the rails run on off-screen),
            // keeping the engine clear of the home indicator. Sky and ground line up with it.
            let sceneTop = height - width * 1.12
            let horizon = sceneTop + MarkGeometry.vanish.y * width

            ZStack(alignment: .top) {
                sky(height: height, sunY: sceneTop + 0.26 * width)
                clouds(width: width, top: proxy.safeAreaInsets.top, sceneTop: sceneTop)
                ground(height: height - horizon)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                RailMark(size: width, showsBackground: false,
                         sun: sun, rails: rails, train: train, headlight: headlight)
                    .offset(y: sceneTop)

                wordmark
                    .frame(width: width)
                    .position(x: width / 2,
                              y: proxy.safeAreaInsets.top + (sceneTop - proxy.safeAreaInsets.top) * 0.42)
            }
            .frame(width: width, height: height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rail")
        .task { await play() }
        .enableInjection()
    }

    /// Same radial light as the icon, centred on the sun so the glow sits behind it.
    private func sky(height: CGFloat, sunY: CGFloat) -> some View {
        RadialGradient(colors: [BrandPalette.leaf, BrandPalette.green, BrandPalette.deep],
                       center: UnitPoint(x: 0.71, y: sunY / max(height, 1)),
                       startRadius: 0, endRadius: height * 0.75)
    }

    /// Two faint cloud banks mirrored about the centre line, drifting apart as the scene opens.
    private func clouds(width: CGFloat, top: CGFloat, sceneTop: CGFloat) -> some View {
        let y = top + (sceneTop - top) * 0.82
        let drift = width * 0.06 * sun
        return ZStack {
            CloudBank(scale: width * 0.42)
                .position(x: width * 0.18 - drift, y: y)
            CloudBank(scale: width * 0.42)
                .scaleEffect(x: -1)
                .position(x: width * 0.82 + drift, y: y - width * 0.04)
        }
        .foregroundStyle(BrandPalette.ivory.opacity(0.07))
        .opacity(Double(sun))
    }

    /// Ground below the horizon, darkening toward the viewer.
    private func ground(height: CGFloat) -> some View {
        LinearGradient(colors: [BrandPalette.deep.opacity(0.35), BrandPalette.deep.opacity(0.75)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: max(height, 0))
    }

    private var wordmark: some View {
        VStack(spacing: Spacing.x1 + Spacing.half) {
            Text("Rail")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .tracking(-1)
                .foregroundStyle(BrandPalette.ivory)
            Capsule()
                .fill(BrandPalette.sand)
                .frame(width: showsWordmark ? 44 : 0, height: 4)
            Text("Bangladesh Railway tickets")
                .font(.subheadline.weight(.semibold))
                .tracking(0.4)
                .foregroundStyle(BrandPalette.sand)
        }
        .multilineTextAlignment(.center)
        .offset(y: showsWordmark ? 0 : 14)
        .opacity(showsWordmark ? 1 : 0)
    }

    private func play() async {
        if reduceMotion {
            sun = 1; rails = 1; train = 1; headlight = 1; showsWordmark = true
            try? await Task.sleep(for: .milliseconds(700))
            onFinish()
            return
        }
        withAnimation(.easeOut(duration: 0.5)) { showsWordmark = true }
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { sun = 1 }
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) { rails = 1 }
        withAnimation(.spring(duration: 0.9, bounce: 0.12).delay(0.5)) { train = 1 }
        withAnimation(.easeIn(duration: 0.15).delay(1.25)) { headlight = 1 }
        try? await Task.sleep(for: .milliseconds(1400))
        withAnimation(.easeOut(duration: 0.3)) { headlight = 0.7 }
        try? await Task.sleep(for: .milliseconds(600))
        onFinish()
    }
}

/// Flat cloud from overlapping circles on a rounded base, `scale` points wide.
private struct CloudBank: View {
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule().frame(width: scale, height: scale * 0.28)
            Circle().frame(width: scale * 0.42).offset(x: -scale * 0.18, y: -scale * 0.08)
            Circle().frame(width: scale * 0.56).offset(x: scale * 0.08, y: -scale * 0.12)
        }
        .frame(width: scale, height: scale * 0.6, alignment: .bottom)
    }
}

#Preview {
    SplashView {}
}
