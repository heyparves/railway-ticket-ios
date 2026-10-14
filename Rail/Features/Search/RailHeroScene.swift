import SwiftUI

/// Search header backdrop: the brand engine running toward the viewer through a green landscape
/// that fades into the screen background. Day has the red sun and drifting clouds; dark mode turns
/// it to night with a moon, twinkling stars, lit windows and a headlight beam on the track.
/// The camera rides with the train, so the motion is in the world: sleepers and lineside poles
/// stream past, hills and clouds slide by, and the engine bobs on its springs.
struct RailHeroScene: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isNight: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion)) { context in
                // Bounded so the trig below keeps full precision.
                let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                scene(size: proxy.size, time: time)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Layout

    /// Where the square train mark sits: vanishing point just inside the right edge, near ends of
    /// the rails at the bottom edge.
    private struct Frame {
        let side: CGFloat
        let origin: CGPoint
        var horizon: CGFloat { origin.y + MarkGeometry.vanish.y * side }

        init(size: CGSize) {
            side = min(size.width * 0.6, 260)
            origin = CGPoint(x: size.width - side * MarkGeometry.vanish.x - 4, y: size.height - side * 0.95)
        }

        func point(_ unit: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + unit.x * side, y: origin.y + unit.y * side)
        }
    }

    private func scene(size: CGSize, time: Double) -> some View {
        let frame = Frame(size: size)
        return ZStack(alignment: .topLeading) {
            backdrop
            ground(size: size, horizon: frame.horizon)
            if isNight {
                stars(size: size, horizon: frame.horizon, time: time)
                moon(radius: frame.side * 0.085)
                    .position(frame.point(CGPoint(x: 0.86, y: 0.02)))
            }
            clouds(size: size, horizon: frame.horizon, time: time)
            landscape(size: size, frame: frame, time: time)
            RailMark(size: frame.side, showsBackground: false,
                     sun: isNight ? 0 : 1,
                     headlight: isNight ? 1 : 0.6,
                     night: isNight,
                     trackPhase: CGFloat((time * 2.2).truncatingRemainder(dividingBy: 1)),
                     trainLift: CGFloat(sin(time * 11) * 0.6 + sin(time * 3.1) * 0.5 + 0.6))
                .offset(x: frame.origin.x, y: frame.origin.y)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        // Soft bottom edge so the rails sink into the page instead of stopping on a line.
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
    }

    // MARK: Sky

    /// Primary green at the top easing into the screen background.
    private var backdrop: some View {
        let stops: [Gradient.Stop] = isNight
            ? [.init(color: Color(red: 0.012, green: 0.071, blue: 0.047), location: 0),
               .init(color: Color(red: 0.027, green: 0.153, blue: 0.102), location: 0.55),
               .init(color: .canvas, location: 1)]
            : [.init(color: BrandPalette.green, location: 0),
               .init(color: BrandPalette.leaf, location: 0.5),
               .init(color: .canvas, location: 1)]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private func ground(size: CGSize, horizon: CGFloat) -> some View {
        LinearGradient(colors: [BrandPalette.deep.opacity(isNight ? 0.6 : 0.3), BrandPalette.deep.opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(width: size.width, height: max(size.height - horizon, 0))
            .offset(y: horizon)
    }

    private func moon(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(BrandPalette.ivory.opacity(0.18))
                .frame(width: radius * 4.5, height: radius * 4.5)
                .blur(radius: radius)
            // Crescent: a disc with an offset disc cut out of it.
            Circle()
                .fill(BrandPalette.ivory)
                .frame(width: radius * 2, height: radius * 2)
                .overlay {
                    Circle()
                        .frame(width: radius * 1.8, height: radius * 1.8)
                        .offset(x: radius * 0.62, y: -radius * 0.38)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .shadow(color: BrandPalette.ivory.opacity(0.6), radius: radius * 0.4)
        }
    }

    /// Fixed field of stars, each twinkling at its own rate, plus a shooting star every few seconds.
    private func stars(size: CGSize, horizon: CGFloat, time: Double) -> some View {
        Canvas { context, _ in
            let skyHeight = horizon - 24
            guard skyHeight > 0 else { return }
            for index in 0..<46 {
                let x = Self.noise(index, 1) * size.width
                let y = 6 + Self.noise(index, 2) * skyHeight
                // Fainter toward the horizon glow.
                let depth = 1 - Double(y / horizon) * 0.6
                let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(time * (0.7 + Double(Self.noise(index, 3)) * 2.2)
                                                                + Double(Self.noise(index, 4)) * 6.28))
                let radius = 0.5 + Self.noise(index, 5) * 1.1
                context.opacity = twinkle * depth
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(.white))
            }

            // Shooting star: crosses in the first 0.8s of every 7s.
            let cycle = time.truncatingRemainder(dividingBy: 7)
            if cycle < 0.8 {
                let progress = CGFloat(cycle / 0.8)
                let start = CGPoint(x: size.width * 0.62, y: skyHeight * 0.18)
                let travel = CGVector(dx: -size.width * 0.28, dy: skyHeight * 0.32)
                let head = CGPoint(x: start.x + travel.dx * progress, y: start.y + travel.dy * progress)
                let tail = CGPoint(x: head.x - travel.dx * 0.35, y: head.y - travel.dy * 0.35)
                var streak = Path()
                streak.move(to: tail)
                streak.addLine(to: head)
                context.opacity = Double(sin(progress * .pi))
                context.stroke(streak,
                               with: .linearGradient(Gradient(colors: [.white.opacity(0), .white]), startPoint: tail, endPoint: head),
                               style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }

    /// Clouds drifting slowly right as the train heads left; each wraps round the edges.
    private func clouds(size: CGSize, horizon: CGFloat, time: Double) -> some View {
        let specs: [(scale: CGFloat, y: CGFloat, speed: Double, start: CGFloat)] = [
            (0.34, 0.30, 5, 0.10),
            (0.22, 0.55, 8, 0.65),
            (0.28, 0.78, 11, 0.35),
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(specs.indices, id: \.self) { index in
                let spec = specs[index]
                let width = size.width * spec.scale
                let span = size.width + width
                let x = (spec.start * span + CGFloat(time * spec.speed)).truncatingRemainder(dividingBy: span) - width
                CloudBank(scale: width)
                    .offset(x: x, y: horizon * spec.y - width * 0.6)
            }
        }
        .foregroundStyle(isNight ? Color.white.opacity(0.03) : BrandPalette.ivory.opacity(0.14))
    }

    // MARK: Land

    /// Two ranges of hills sliding at different speeds, then lineside poles and wires running
    /// down the far side of the track at the same pace as the sleepers.
    private func landscape(size: CGSize, frame: Frame, time: Double) -> some View {
        Canvas { context, _ in
            let horizon = frame.horizon
            let ranges: [(height: CGFloat, wave: CGFloat, speed: Double, color: Color)] = [
                (14, 46, 4, isNight ? .black.opacity(0.28) : BrandPalette.deep.opacity(0.22)),
                (9, 28, 10, isNight ? .black.opacity(0.4) : BrandPalette.deep.opacity(0.32)),
            ]
            for range in ranges {
                let shift = CGFloat(time * range.speed)
                var hills = Path()
                hills.move(to: CGPoint(x: 0, y: horizon + 1))
                for x in stride(from: CGFloat(0), through: size.width, by: 3) {
                    let u = (x - shift) / range.wave
                    let lift = range.height * (0.55 + 0.3 * sin(u) + 0.15 * sin(u * 2.3 + 1))
                    hills.addLine(to: CGPoint(x: x, y: horizon - lift))
                }
                hills.addLine(to: CGPoint(x: size.width, y: horizon + 1))
                hills.closeSubpath()
                context.fill(hills, with: .color(range.color))
            }

            // Poles stand along a line outside the far rail, receding to the vanishing point.
            let base = MarkGeometry.lerp(MarkGeometry.nearRail, MarkGeometry.farRail, 2.2)
            let phase = CGFloat((time * 0.5).truncatingRemainder(dividingBy: 1))
            let poleColor: Color = isNight ? .black.opacity(0.55) : BrandPalette.deep.opacity(0.5)
            // Where the wire meets a pole at a given distance along the line. Pole tops all sit on one
            // straight line to the vanishing point, so this also extends the wire past the end poles.
            func wireAnchor(_ along: CGFloat) -> CGPoint {
                let foot = frame.point(MarkGeometry.lerp(base, MarkGeometry.vanish, along))
                return CGPoint(x: foot.x, y: foot.y - frame.side * 0.5 * (1 - along) * 0.93)
            }
            // Start well off-screen at the near end so the wire never pops in as a new pole arrives.
            var tops: [CGPoint] = [wireAnchor(-4)]
            for index in 0..<14 {
                // Same direction as the sleepers: poles recede as the train runs at the viewer. New ones
                // enter off-screen at the near end, past the left edge.
                let depth = 0.5 + 1.3 * (CGFloat(index) + phase)
                let along = 1 - 1 / depth
                let scale = 1 - along
                let foot = frame.point(MarkGeometry.lerp(base, MarkGeometry.vanish, along))
                let height = frame.side * 0.5 * scale
                let width = max(1, frame.side * 0.012 * scale)
                let top = CGPoint(x: foot.x, y: foot.y - height)
                context.fill(Path(CGRect(x: foot.x - width / 2, y: top.y, width: width, height: height)), with: .color(poleColor))
                let arm = frame.side * 0.07 * scale
                context.fill(Path(CGRect(x: foot.x - arm / 2, y: top.y + height * 0.06, width: arm, height: max(0.8, width * 0.6))),
                             with: .color(poleColor))
                tops.append(CGPoint(x: foot.x, y: top.y + height * 0.07))
            }
            // Finish at the vanishing point so the far end never stops short at the last pole.
            tops.append(wireAnchor(1))
            // One continuous wire that sags a little between neighbouring poles; the two extensions
            // past the end poles stay straight.
            var wires = Path()
            wires.move(to: tops[0])
            for (offset, (a, b)) in zip(tops, tops.dropFirst()).enumerated() {
                if offset == 0 || offset == tops.count - 2 {
                    wires.addLine(to: b)
                } else {
                    wires.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + abs(b.x - a.x) * 0.08))
                }
            }
            context.stroke(wires, with: .color(poleColor.opacity(0.7)), lineWidth: 0.6)
        }
    }

    /// Stable pseudo-random value in 0..<1 for star placement.
    private static func noise(_ index: Int, _ salt: Int) -> CGFloat {
        let value = sin(Double(index * 127 + salt * 311)) * 43758.5453
        return CGFloat(value - value.rounded(.down))
    }
}

#Preview("Day") {
    RailHeroScene()
        .frame(height: 340)
        .ignoresSafeArea()
        .preferredColorScheme(.light)
}

#Preview("Night") {
    RailHeroScene()
        .frame(height: 340)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
}
