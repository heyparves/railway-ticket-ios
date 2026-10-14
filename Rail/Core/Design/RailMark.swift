import SwiftUI

/// Brand palette for the mark and splash. Fixed values: the icon must look the same in light and dark.
enum BrandPalette {
    // Scene
    static let deep = Color(red: 0.020, green: 0.212, blue: 0.137)      // #053623
    static let green = Color(red: 0.039, green: 0.361, blue: 0.231)     // #0A5C3B
    static let leaf = Color(red: 0.090, green: 0.478, blue: 0.318)      // #177A51
    static let sun = Color(red: 0.882, green: 0.235, blue: 0.227)       // #E13C3A, flag red
    static let ivory = Color(red: 0.969, green: 0.937, blue: 0.867)     // #F7EFDD
    static let rail = Color(red: 0.925, green: 0.894, blue: 0.827)

    // Locomotive livery: navy body, sand chevron, red pilot.
    static let navy = Color(red: 0.039, green: 0.290, blue: 0.494)      // #0A4A7E
    static let navySide = Color(red: 0.027, green: 0.231, blue: 0.408)  // #073B68
    static let navyDeep = Color(red: 0.000, green: 0.176, blue: 0.333)  // #002D55
    static let sand = Color(red: 0.984, green: 0.725, blue: 0.420)      // #FBB96B
    static let sandSide = Color(red: 0.878, green: 0.620, blue: 0.345)  // #E09E58
    static let red = Color(red: 0.941, green: 0.157, blue: 0.235)       // #F0283C
    static let redLight = Color(red: 1.000, green: 0.302, blue: 0.369)  // #FF4D5E
    static let amber = Color(red: 0.965, green: 0.698, blue: 0.169)     // #F6B22B
    static let steel = Color(red: 0.788, green: 0.808, blue: 0.839)     // #C9CED6
    static let handrail = Color(red: 0.663, green: 0.706, blue: 0.784)  // #A9B4C8
    static let window = Color(red: 0.180, green: 0.157, blue: 0.161)    // #2E2829
    static let underframe = Color(red: 0.149, green: 0.125, blue: 0.122)
    static let buffer = Color(red: 0.290, green: 0.247, blue: 0.235)
    static let bufferFace = Color(red: 0.471, green: 0.329, blue: 0.282)
    static let sleeper = Color(red: 0.239, green: 0.200, blue: 0.180)

    // Night: livery dimmed toward moonlit blue, windows lit warm.
    static let nightShade = Color(red: 0.50, green: 0.56, blue: 0.70)
    static let windowLit = Color(red: 1.000, green: 0.820, blue: 0.478)  // #FFD17A
}

/// Navy-and-sand diesel in three-quarter view rolling out of a red sun on converging rails.
/// Every phase runs 0...1 so the splash can animate the pieces in; the icon renders all at 1.
/// Kept free of app dependencies so `scripts/render-icon.swift` can compile it for the icon PNG.
struct RailMark: View {
    /// Edge length in points; the mark is always square.
    var size: CGFloat
    var showsBackground = true
    var sun: CGFloat = 1
    var rails: CGFloat = 1
    var train: CGFloat = 1
    var headlight: CGFloat = 1
    /// Dims the livery, lights the windows and throws a beam down the track.
    var night = false
    /// Sleepers streaming toward the viewer, one spacing per 0...1 cycle. Nil leaves plain rails
    /// (icon, splash).
    var trackPhase: CGFloat?
    /// Points the engine rides above the rails, for a running bob.
    var trainLift: CGFloat = 0

    var body: some View {
        let side = size
        ZStack {
            if showsBackground {
                RadialGradient(colors: [BrandPalette.leaf, BrandPalette.green, BrandPalette.deep],
                               center: UnitPoint(x: 0.7, y: 0.3), startRadius: 0, endRadius: side * 0.95)
            }
            // Sun sets behind the horizon line, so only its upper part shows.
            MarkPart(.sun)
                .fill(BrandPalette.sun.gradient)
                .offset(y: (1 - sun) * side * 0.35)
                .opacity(Double(sun))
                .mask(alignment: .top) { Rectangle().frame(width: side, height: side * MarkGeometry.vanish.y) }
            // Sky and ground belong to the background; a full-bleed host draws its own.
            if showsBackground {
                MarkPart(.horizon).fill(BrandPalette.deep.opacity(0.35))
            }
            railLayer(side: side)
            if night {
                // Light thrown ahead onto the track; the nose covers where it leaves the lamps.
                // Outside the rail layer so the draw-in mask doesn't cut it off at the square's edge.
                MarkPart(.headlightBeam)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.32), Color.white.opacity(0)],
                                         startPoint: UnitPoint(x: MarkGeometry.centre, y: MarkGeometry.roof),
                                         endPoint: UnitPoint(x: 0.0, y: 1.25)))
                    .blur(radius: side * 0.02)
                    .opacity(Double(headlight))
            }
            trainLayer(side: side)
                .offset(y: -trainLift)
                .scaleEffect(0.12 + 0.88 * train, anchor: UnitPoint(x: MarkGeometry.vanish.x, y: MarkGeometry.vanish.y))
                .opacity(Double(min(1, train * 3)))
        }
        .frame(width: side, height: side)
        // A full-bleed host lets the rails run on past the square to the screen edge.
        .clipShape(Rectangle().inset(by: showsBackground ? 0 : -side))
        .accessibilityHidden(true)
    }

    private func railLayer(side: CGFloat) -> some View {
        ZStack {
            MarkPart(.ballast).fill(BrandPalette.deep.opacity(0.55))
            if let trackPhase {
                TrackSleepers(phase: trackPhase).fill(BrandPalette.sleeper.opacity(night ? 0.9 : 0.6))
            }
            MarkPart(.rails).fill(BrandPalette.rail.opacity(0.9))
        }
        // Rails draw from the near end out to the vanishing point.
        .mask(alignment: .leading) {
            // Tall enough for the rails a full-bleed host lets run on below the square, and
            // reaching left past the square so the near ends aren't cut on its edge.
            Rectangle().frame(width: side * (rails + 1), height: side * 3).offset(x: -side)
        }
    }

    private func trainLayer(side: CGFloat) -> some View {
        ZStack {
            trainBody
                .colorMultiply(night ? BrandPalette.nightShade : .white)
            if night {
                Group {
                    MarkPart(.coachWindows)
                    MarkPart(.sideWindows)
                }
                .foregroundStyle(BrandPalette.windowLit.opacity(0.9))
                .shadow(color: BrandPalette.windowLit.opacity(0.7), radius: side * 0.012)
                MarkPart(.markerLamps)
                    .fill(BrandPalette.amber)
                    .shadow(color: BrandPalette.amber, radius: side * 0.015)
            }

            // Twin headlights in their housing on the roof line.
            MarkPart(.headlightGlow)
                .fill(Color.white.opacity(night ? 0.8 : 0.4))
                .blur(radius: side * (night ? 0.04 : 0.025))
                .scaleEffect(night ? 1.5 : 1, anchor: UnitPoint(x: MarkGeometry.centre, y: MarkGeometry.roof))
                .opacity(Double(headlight))
            MarkPart(.headlightHousing).fill(night ? BrandPalette.handrail : BrandPalette.steel)
            MarkPart(.headlights).fill(Color.white)
        }
    }

    private var trainBody: some View {
        ZStack {
            // Coach behind the engine.
            MarkPart(.coach).fill(BrandPalette.navySide.opacity(0.9))
            MarkPart(.coachBand).fill(BrandPalette.sandSide.opacity(0.9))
            MarkPart(.coachWindows).fill(BrandPalette.window.opacity(0.85))

            // Engine side.
            MarkPart(.side).fill(BrandPalette.navySide)
            MarkPart(.sideBand).fill(BrandPalette.sandSide)
            MarkPart(.sideWindows).fill(BrandPalette.window)
            MarkPart(.sideWalkway).fill(BrandPalette.navyDeep)
            MarkPart(.sideUnderframe).fill(BrandPalette.underframe)
            MarkPart(.sideHandrail).fill(BrandPalette.handrail)

            // Engine nose.
            MarkPart(.front).fill(BrandPalette.navy)
            MarkPart(.chevron).fill(BrandPalette.sand)
            MarkPart(.frontHandrail).fill(BrandPalette.handrail)
            MarkPart(.roundel).fill(BrandPalette.red)
            MarkPart(.roundelRing).fill(Color.white)
            MarkPart(.roundelGlyph).fill(Color.white)
            MarkPart(.markerLamps).fill(BrandPalette.amber)
            MarkPart(.pilot).fill(BrandPalette.red)
            MarkPart(.pilotFacet).fill(BrandPalette.redLight)
            MarkPart(.beam).fill(BrandPalette.navyDeep)
            MarkPart(.tailLampPlate).fill(BrandPalette.navySide)
            MarkPart(.tailLamps).fill(BrandPalette.red)
            MarkPart(.buffers).fill(BrandPalette.buffer)
            MarkPart(.bufferFaces).fill(BrandPalette.bufferFace)
        }
    }
}

/// Unit-square coordinates for the mark. The side of the engine recedes to `vanish`.
enum MarkGeometry {
    static let vanish = CGPoint(x: 1.067, y: 0.516)

    static let frontLeft: CGFloat = 0.20
    static let frontRight: CGFloat = 0.50
    static let centre: CGFloat = 0.35
    static let roof: CGFloat = 0.28
    /// Bottom of the painted body; the buffer beam and pilot hang below it.
    static let body: CGFloat = 0.655
    static let beamBottom: CGFloat = 0.745
    static let pilotBottom: CGFloat = 0.84

    /// Near ends of the rails at the left edge. Both run to `vanish`, passing just under the
    /// pilot's corners, so the engine sits on the track.
    static let farRail = CGPoint(x: -0.05, y: 0.947)
    static let nearRail = CGPoint(x: -0.05, y: 1.141)

    /// Point on the engine's side: `u` runs front (0) to rear (1), `v` runs roof (0) to the
    /// bottom of the underframe (1). Front-edge heights map as `y = roof + v * 0.52`.
    static func side(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
        let top = lerp(CGPoint(x: frontRight, y: roof), CGPoint(x: 0.86, y: 0.43), u)
        let bottom = lerp(CGPoint(x: frontRight, y: 0.80), CGPoint(x: 0.86, y: 0.62), u)
        return lerp(top, bottom, v)
    }

    /// Side `v` for a height measured on the front edge.
    static func v(atFrontY y: CGFloat) -> CGFloat { (y - roof) / 0.52 }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // Sand chevron: top edge meets the sides at `chevronTop`, bottom edge at `chevronBottom`.
    static let chevronTop: CGFloat = 0.405
    static let chevronBottom: CGFloat = 0.505
    static let chevronApexTop: CGFloat = 0.545
    static let chevronApexBottom: CGFloat = 0.64
}

struct MarkPart: Shape {
    enum Kind {
        case sun, horizon, rails, ballast
        case coach, coachBand, coachWindows
        case side, sideBand, sideWindows, sideWalkway, sideUnderframe, sideHandrail
        case front, chevron, frontHandrail, roundel, roundelRing, roundelGlyph, markerLamps
        case beam, tailLampPlate, tailLamps, pilot, pilotFacet, buffers, bufferFaces
        case headlightHousing, headlights, headlightGlow, headlightBeam
    }

    let kind: Kind
    init(_ kind: Kind) { self.kind = kind }

    func path(in rect: CGRect) -> Path {
        let unit = Self.unitPath(kind)
        return unit.applying(CGAffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.minX, ty: rect.minY))
    }

    private typealias G = MarkGeometry

    private static func poly(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    /// Patch of the side between `u0...u1` and `v0...v1`.
    private static func sidePatch(_ u0: CGFloat, _ u1: CGFloat, _ v0: CGFloat, _ v1: CGFloat) -> Path {
        poly([G.side(u0, v0), G.side(u1, v0), G.side(u1, v1), G.side(u0, v1)])
    }

    private static let roundelCentre = CGPoint(x: G.centre, y: 0.445)
    private static let roundelRadius: CGFloat = 0.045

    private static func unitPath(_ kind: Kind) -> Path {
        switch kind {
        case .sun:
            return Path(ellipseIn: CGRect(x: 0.53, y: 0.08, width: 0.36, height: 0.36))

        case .horizon:
            return Path(CGRect(x: 0, y: G.vanish.y, width: 1, height: 1 - G.vanish.y))

        case .rails:
            // Two rails that thin out as they recede.
            var path = Path()
            for near in [G.farRail, G.nearRail] {
                let nearWidth: CGFloat = 0.022, farWidth: CGFloat = 0.002
                path.addPath(poly([
                    CGPoint(x: near.x, y: near.y - nearWidth / 2),
                    CGPoint(x: G.vanish.x, y: G.vanish.y - farWidth / 2),
                    CGPoint(x: G.vanish.x, y: G.vanish.y + farWidth / 2),
                    CGPoint(x: near.x, y: near.y + nearWidth / 2),
                ]))
            }
            return path

        case .ballast:
            // Track bed: a wedge a little wider than the rails, narrowing to the vanishing point.
            let left = G.lerp(G.nearRail, G.farRail, 1.2)
            let right = G.lerp(G.farRail, G.nearRail, 1.2)
            return poly([left, G.vanish, right])

        // MARK: Coach

        case .coach:
            return sidePatch(1.035, 1.6, 0.03, 0.86)
        case .coachBand:
            return sidePatch(1.035, 1.6, G.v(atFrontY: G.chevronTop), G.v(atFrontY: G.chevronBottom))
        case .coachWindows:
            var path = Path()
            for (u0, u1) in [(1.07, 1.12), (1.16, 1.20), (1.24, 1.27), (1.31, 1.34)] as [(CGFloat, CGFloat)] {
                path.addPath(sidePatch(u0, u1, 0.27, 0.40))
            }
            return path

        // MARK: Engine side

        case .side:
            return sidePatch(0, 1, 0, G.v(atFrontY: G.body))
        case .sideBand:
            return sidePatch(0, 1, G.v(atFrontY: G.chevronTop), G.v(atFrontY: G.chevronBottom))
        case .sideWindows:
            // Engine-room louvres and cab windows let into the sand band.
            var path = Path()
            for (u0, u1) in [(0.12, 0.19), (0.22, 0.29), (0.52, 0.57), (0.60, 0.65), (0.84, 0.88), (0.90, 0.94)] as [(CGFloat, CGFloat)] {
                path.addPath(sidePatch(u0, u1, 0.26, 0.40))
            }
            return path
        case .sideWalkway:
            return sidePatch(0, 1, G.v(atFrontY: G.body), G.v(atFrontY: G.beamBottom))
        case .sideUnderframe:
            return sidePatch(0, 1, G.v(atFrontY: G.beamBottom), 1)
        case .sideHandrail:
            return sidePatch(0, 0.98, 0.1, 0.112)

        // MARK: Nose

        case .front:
            var path = Path()
            path.addRoundedRect(in: CGRect(x: G.frontLeft, y: G.roof, width: G.frontRight - G.frontLeft, height: G.body - G.roof),
                                cornerRadii: RectangleCornerRadii(topLeading: 0.05, bottomLeading: 0,
                                                                  bottomTrailing: 0, topTrailing: 0.02),
                                style: .continuous)
            return path

        case .chevron:
            return poly([
                CGPoint(x: G.frontLeft, y: G.chevronTop),
                CGPoint(x: G.centre, y: G.chevronApexTop),
                CGPoint(x: G.frontRight, y: G.chevronTop),
                CGPoint(x: G.frontRight, y: G.chevronBottom),
                CGPoint(x: G.centre, y: G.chevronApexBottom),
                CGPoint(x: G.frontLeft, y: G.chevronBottom),
            ])

        case .frontHandrail:
            return Path(roundedRect: CGRect(x: G.frontLeft - 0.012, y: 0.336, width: G.frontRight - G.frontLeft + 0.012, height: 0.008),
                        cornerRadius: 0.004)

        case .roundel:
            return circle(roundelCentre.x, roundelCentre.y, roundelRadius)

        case .roundelRing:
            var path = circle(roundelCentre.x, roundelCentre.y, roundelRadius * 0.86)
            path.addPath(circle(roundelCentre.x, roundelCentre.y, roundelRadius * 0.74))
            return path.normalized(eoFill: true)

        case .roundelGlyph:
            // Our own emblem: a short stretch of track, two rails and three sleepers.
            var path = Path()
            let c = roundelCentre, r = roundelRadius
            for dx in [-0.22, 0.22] as [CGFloat] {
                path.addRoundedRect(in: CGRect(x: c.x + dx * r - r * 0.06, y: c.y - r * 0.5, width: r * 0.12, height: r), cornerSize: CGSize(width: r * 0.05, height: r * 0.05))
            }
            for dy in [-0.3, 0, 0.3] as [CGFloat] {
                path.addRect(CGRect(x: c.x - r * 0.42, y: c.y + dy * r - r * 0.045, width: r * 0.84, height: r * 0.09))
            }
            return path

        case .markerLamps:
            var path = Path()
            path.addRoundedRect(in: CGRect(x: 0.214, y: 0.608, width: 0.034, height: 0.03), cornerSize: CGSize(width: 0.006, height: 0.006))
            path.addRoundedRect(in: CGRect(x: 0.452, y: 0.608, width: 0.034, height: 0.03), cornerSize: CGSize(width: 0.006, height: 0.006))
            return path

        case .beam:
            return Path(CGRect(x: G.frontLeft - 0.03, y: G.body, width: G.frontRight - G.frontLeft + 0.06, height: G.beamBottom - G.body))

        case .tailLampPlate:
            return Path(roundedRect: CGRect(x: G.centre - 0.016, y: G.body + 0.006, width: 0.032, height: 0.068), cornerRadius: 0.004)

        case .tailLamps:
            var path = circle(G.centre, G.body + 0.023, 0.011)
            path.addPath(circle(G.centre, G.body + 0.056, 0.011))
            return path

        case .pilot:
            return poly([
                CGPoint(x: G.frontLeft - 0.018, y: G.beamBottom),
                CGPoint(x: G.frontRight + 0.018, y: G.beamBottom),
                CGPoint(x: G.frontRight + 0.01, y: G.pilotBottom),
                CGPoint(x: G.frontLeft - 0.01, y: G.pilotBottom),
            ])

        case .pilotFacet:
            // Lighter cowcatcher face, like light catching the angled plate.
            return poly([
                CGPoint(x: G.frontLeft + 0.02, y: G.pilotBottom),
                CGPoint(x: G.centre - 0.02, y: G.beamBottom + 0.02),
                CGPoint(x: G.centre + 0.06, y: G.pilotBottom),
            ])

        case .buffers:
            var path = Path()
            for x in [G.frontLeft - 0.005, G.frontRight + 0.005] {
                path.addPath(circle(x, G.beamBottom - 0.008, 0.042))
            }
            return path

        case .bufferFaces:
            var path = Path()
            for x in [G.frontLeft - 0.005, G.frontRight + 0.005] {
                path.addPath(circle(x + 0.012, G.beamBottom - 0.012, 0.03))
            }
            return path

        case .headlightHousing:
            return Path(roundedRect: CGRect(x: G.centre - 0.026, y: G.roof - 0.032, width: 0.052, height: 0.094), cornerRadius: 0.018)

        case .headlights:
            var path = circle(G.centre, G.roof - 0.006, 0.017)
            path.addPath(circle(G.centre, G.roof + 0.036, 0.017))
            return path

        case .headlightGlow:
            return circle(G.centre, G.roof - 0.006, 0.06)

        case .headlightBeam:
            // Fans out from the lamps down over the near end of the track.
            return poly([
                CGPoint(x: G.centre - 0.03, y: G.roof),
                CGPoint(x: G.centre + 0.03, y: G.roof),
                CGPoint(x: 0.75, y: 1.35),
                CGPoint(x: -0.55, y: 1.2),
            ])
        }
    }
}

/// Sleepers across the track, spaced evenly in depth so they bunch toward the vanishing point.
/// Advancing `phase` through 0...1 moves every sleeper one spacing further away, as the ground
/// slides back under an engine running toward the viewer; the loop is seamless.
struct TrackSleepers: Shape {
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private typealias G = MarkGeometry
    private static let count = 36
    private static let spacing: CGFloat = 0.3
    private static let thickness: CGFloat = 0.07

    func path(in rect: CGRect) -> Path {
        // A little wider than the rails on each side.
        let left = G.lerp(G.nearRail, G.farRail, 1.16)
        let right = G.lerp(G.farRail, G.nearRail, 1.16)
        var path = Path()
        for index in 0..<Self.count {
            // Depth 1 is the near end of the rails; screen position runs 1 - 1/depth toward `vanish`.
            let depth = 0.62 + Self.spacing * (CGFloat(index) + phase)
            let near = 1 - 1 / depth
            let far = 1 - 1 / (depth + Self.thickness)
            path.addLines([G.lerp(left, G.vanish, near), G.lerp(right, G.vanish, near),
                           G.lerp(right, G.vanish, far), G.lerp(left, G.vanish, far)])
            path.closeSubpath()
        }
        return path.applying(CGAffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.minX, ty: rect.minY))
    }
}

/// The mark as an app-icon tile, for headers and brand spots inside the app.
struct BrandLogo: View {
    var size: CGFloat = 44

    var body: some View {
        RailMark(size: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        RailMark(size: 320)
            .clipShape(RoundedRectangle(cornerRadius: 72, style: .continuous))
        HStack(spacing: 16) {
            BrandLogo(size: 64)
            BrandLogo(size: 44)
            BrandLogo(size: 29)
        }
    }
}
