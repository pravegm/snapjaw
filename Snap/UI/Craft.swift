import SwiftUI

// MARK: - R8 (ROUND-8 §3, the founder: "Menus feel cheap"): the crafted pieces every screen is built from
//
// - `DisplayText`: the big display type. SF Rounded Black, inked like a sticker (a dark outline all round), a deep
//   coloured lip under it and a gradient face. Titles, CHOMP!, the score, the level numbers.
// - `LeafShape`: the panels' shape. A leaf, not a rounded rectangle: two big corners and two tight ones, the way a
//   flytrap's lobe is cut. `snapCard()` (every card in the app) draws on it.
// - `PadButton`: a lily pad with its notch, an icon on it and a word under it (Home's Endless, Daily and Zen; the
//   level map's levels are `LevelPad`).
// - `entrance(_:)`: the screens' entry motion, staggered by index (none under Reduce Motion).

/// The big display type (R8). One line; it scales down to fit, every layer by the same amount.
struct DisplayText: View {
    let text: String
    var size: CGFloat
    /// The face, top to bottom.
    var fill: [Color] = [SnapTheme.cream, SnapTheme.limeLight]
    /// The outline (all round) and the lip (a drop under the letters).
    var ink: Color = SnapTheme.night
    var lip: Color = SnapTheme.crimsonDeep
    /// Degrees (a little tilt reads as hand-made: CHOMP!).
    var tilt: Double = 0
    var minScale: CGFloat = 0.5

    /// The outline's width for a size (pure; tested).
    static func inkWidth(_ size: CGFloat) -> CGFloat { max((size * 0.055).rounded(), 2) }

    var body: some View {
        let font = Font.system(size: size, weight: .black, design: .rounded)
        let w = Self.inkWidth(size)
        let drop = max((size * 0.075).rounded(), 3)
        ZStack {
            // The lip: the inked letters again, a drop lower, in the lip colour.
            inked(font, w: w, ink: lip, face: AnyShapeStyle(lip))
                .offset(y: drop)
            inked(font, w: w, ink: ink,
                  face: AnyShapeStyle(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom)))
        }
        .rotationEffect(.degrees(tilt))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func inked(_ font: Font, w: CGFloat, ink: Color, face: AnyShapeStyle) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * Double.pi / 4
                Text(text)
                    .font(font)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(minScale)
                    .offset(x: CGFloat(cos(a)) * w, y: CGFloat(sin(a)) * w)
            }
            Text(text)
                .font(font)
                .foregroundStyle(face)
                .lineLimit(1)
                .minimumScaleFactor(minScale)
        }
    }
}

/// A leaf-cut panel: big corners top-leading and bottom-trailing, tight ones on the other two (R8).
struct LeafShape: Shape {
    var big: CGFloat = 30
    var small: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let b = min(big, rect.width / 2, rect.height / 2)
        let s = min(small, rect.width / 2, rect.height / 2)
        return UnevenRoundedRectangle(topLeadingRadius: b, bottomLeadingRadius: s, bottomTrailingRadius: b,
                                      topTrailingRadius: s, style: .continuous).path(in: rect)
    }
}

/// The panel's paint (R8): a moss body darker at the foot, a midrib vein across it, a lit top edge and a deep shadow.
/// `accent` tints the vein and the edge (gold for good news, crimson for a warning).
struct LeafPanel: View {
    var big: CGFloat = 30
    var small: CGFloat = 10
    var accent: Color = SnapTheme.limeLight
    var opacity: Double = 0.94

    var body: some View {
        let shape = LeafShape(big: big, small: small)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                shape.fill(LinearGradient(colors: [Color(snapHex: 0x1D4A2A).opacity(opacity),
                                                   Color(snapHex: 0x0E2B18).opacity(opacity),
                                                   Color(snapHex: 0x081C10).opacity(opacity)],
                                          startPoint: .top, endPoint: .bottom))
                // The midrib vein, corner to corner, and two side veins off it.
                Path { p in
                    p.move(to: CGPoint(x: w * 0.04, y: h * 0.10))
                    p.addQuadCurve(to: CGPoint(x: w * 0.96, y: h * 0.92), control: CGPoint(x: w * 0.42, y: h * 0.86))
                    p.move(to: CGPoint(x: w * 0.30, y: h * 0.62))
                    p.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.08), control: CGPoint(x: w * 0.34, y: h * 0.26))
                    p.move(to: CGPoint(x: w * 0.62, y: h * 0.84))
                    p.addQuadCurve(to: CGPoint(x: w * 0.94, y: h * 0.30), control: CGPoint(x: w * 0.74, y: h * 0.44))
                }
                .stroke(accent.opacity(0.07), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .clipShape(shape)
                // The lit top edge (a wet leaf catches the light).
                shape.stroke(LinearGradient(colors: [accent.opacity(0.55), accent.opacity(0.08), .clear],
                                            startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                shape.inset(by: 3).stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
        }
        .shadow(color: SnapTheme.shadow.opacity(0.55), radius: 14, y: 8)
    }
}

extension LeafShape: InsettableShape {
    func inset(by amount: CGFloat) -> InsetLeaf { InsetLeaf(base: self, amount: amount) }
}

/// `LeafShape` inset (for the inner highlight).
struct InsetLeaf: InsettableShape {
    var base: LeafShape
    var amount: CGFloat

    func path(in rect: CGRect) -> Path {
        var b = base
        b.big = max(base.big - amount, 0)
        b.small = max(base.small - amount, 0)
        return b.path(in: rect.insetBy(dx: amount, dy: amount))
    }

    func inset(by more: CGFloat) -> InsetLeaf { InsetLeaf(base: base, amount: amount + more) }
}

/// A lily pad with its notch (R8): Home's secondary actions and the level map's stones.
struct LilyPadShape: Shape {
    /// The notch's half-angle (radians) and where it points (radians, 0 = right, y down).
    var notch: Double = 0.30
    var facing: Double = -Double.pi / 2 - 0.5

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r, startAngle: .radians(facing + notch), endAngle: .radians(facing - notch + 2 * .pi),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// A round pad button (R8): the pad, an icon on it, a word (and a small line) under it.
struct PadButton<Icon: View>: View {
    let title: String
    var detail: String?
    var size: CGFloat = 84
    var tint: Color = SnapTheme.mossLight
    var badge: String?
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    LilyPadShape()
                        .fill(SnapTheme.night.opacity(0.9))
                        .offset(y: 4)
                    LilyPadShape()
                        .fill(RadialGradient(colors: [tint, SnapTheme.moss, SnapTheme.bog], center: UnitPoint(x: 0.4,
                                                                                                         y: 0.35),
                                             startRadius: 2, endRadius: size * 0.62))
                    LilyPadShape()
                        .stroke(SnapTheme.night, lineWidth: 3)
                    // The pad's veins.
                    PadVeins()
                        .stroke(SnapTheme.limeLight.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    icon()
                        .frame(width: size * 0.52, height: size * 0.52)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(SnapTheme.cream)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(SnapTheme.crimson))
                            .overlay(Capsule().stroke(SnapTheme.night, lineWidth: 2))
                            .fixedSize()
                            .offset(x: size * 0.36, y: -size * 0.36)
                    }
                }
                .frame(width: size, height: size)
                Text(title)
                    .font(.system(size: size < 76 ? 15 : 17, weight: .black, design: .rounded))
                    .foregroundStyle(SnapTheme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .snapLegible()
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(SnapTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .snapLegible()
                }
            }
            .frame(minWidth: max(size, SnapTheme.minTap), minHeight: max(size, SnapTheme.minTap))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(title + (detail.map { ", " + $0 } ?? ""))
    }
}

/// A pad's veins, from the notch's foot outwards.
struct PadVeins: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let a = Double(i) * Double.pi / 3 + 0.3
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.82, y: c.y + CGFloat(sin(a)) * r * 0.82))
        }
        return p
    }
}

/// Press feedback for custom buttons: a squash and a dim.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A screen's big header (R8): the display title, and a short line under it.
struct ScreenTitle: View {
    let title: String
    var line: String?
    var compact = false
    var fill: [Color] = [SnapTheme.cream, SnapTheme.limeLight]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            DisplayText(text: title, size: compact ? 34 : 46, fill: fill)
                .fixedSize(horizontal: false, vertical: true)
            if let line {
                Text(line)
                    .font(SnapType.body(compact))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .snapLegible()
            }
        }
    }
}

/// Stars (R8 levels): `earned` of 3, gold and inked; the rest dark seeds.
struct StarRow: View {
    let earned: Int
    var size: CGFloat = 18
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                StarGlyph(lit: i < earned, size: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(max(min(earned, 3), 0)) of 3 stars")
    }
}

/// One star, inked.
struct StarGlyph: View {
    let lit: Bool
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            StarShape().fill(SnapTheme.night).offset(y: size * 0.08)
            StarShape().fill(lit ? AnyShapeStyle(LinearGradient(colors: [SnapTheme.goldLight, SnapTheme.gold,
                                                                        SnapTheme.goldDeep],
                                                               startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(Color.black.opacity(0.35)))
            StarShape().stroke(SnapTheme.night, lineWidth: max(size * 0.09, 1.5))
            if lit {
                StarShape().fill(Color.white.opacity(0.35)).scaleEffect(0.34).offset(x: -size * 0.1, y: -size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A plump five-pointed star.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04)
        let r = min(rect.width, rect.height) / 2
        let inner = r * 0.5
        var p = Path()
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5
            let rr = i % 2 == 0 ? r : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// R8: a screen's entry motion: each piece rises into place, `index` × 60 ms after the last (none under Reduce
/// Motion).
struct Entrance: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    @State private var shown = false

    /// The stagger between pieces (s).
    static let stagger: Double = 0.06

    func body(content: Content) -> some View {
        let on = shown || reduceMotion
        return content
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 22)
            .scaleEffect(on ? 1 : 0.96)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(Double(max(index, 0)) * Self.stagger)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// R8: the screen's entry motion (`Entrance`).
    func entrance(_ index: Int, reduceMotion: Bool) -> some View {
        modifier(Entrance(index: index, reduceMotion: reduceMotion))
    }
}
