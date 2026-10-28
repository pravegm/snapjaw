import SwiftUI
import UIKit

/// The look (GAME-DESIGN §10): a sunlit bog, saturated and glossy. Emerald and moss greens, a crimson-pink trap, gold
/// nectar. SF Pro Rounded throughout: Black for the wordmark and the big numbers, Heavy for titles, Bold for buttons,
/// Semibold for body. Every screen takes colour, type, shape and motion from here; the trap and bug art itself comes
/// from the Scene's `TrapArt` (paths and `TrapArt.palette`).
enum SnapTheme {
    // Bog, darkest → lightest
    static let night = Color(snapHex: 0x05130B)
    static let bogDeep = Color(snapHex: 0x0A2414)
    static let bog = Color(snapHex: 0x12361F)
    static let moss = Color(snapHex: 0x1E4E2C)
    static let mossLight = Color(snapHex: 0x2F6E3C)
    static let lime = Color(snapHex: 0x9BD34B)
    static let limeLight = Color(snapHex: 0xCDEE85)
    // The trap
    static let crimson = Color(snapHex: 0xD62A4E)
    static let crimsonDeep = Color(snapHex: 0x8A1232)
    static let pink = Color(snapHex: 0xFF7A96)
    // Text: primary / secondary / tertiary
    static let cream = Color(snapHex: 0xFFF7E2)
    static let mist = Color(snapHex: 0xC9DEC4)
    static let haze = Color(snapHex: 0x8AAA8D)
    // Gold: the primary action, nectar and earned things
    static let gold = Color(snapHex: 0xFFC83D)
    static let goldLight = Color(snapHex: 0xFFE68C)
    static let goldDeep = Color(snapHex: 0xC4850F)
    // Warnings and bees
    static let danger = Color(snapHex: 0xFF5D3F)
    static let bee = Color(snapHex: 0xFFD43F)
    // Surfaces
    static let surface = Color(snapHex: 0x0F2F1A)
    static let surfaceRaised = Color(snapHex: 0x1A4527)
    static let surfacePressed = Color(snapHex: 0x0B2414)
    static let stroke = Color.white.opacity(0.10)
    /// Text on gold.
    static let ink = Color(snapHex: 0x2B1704)
    static let shadow = Color(snapHex: 0x020805)

    /// Hit targets are never smaller (ROUND-1 App: ≥ 56 pt).
    static let minTap: CGFloat = 56
    static let primaryHeight: CGFloat = 64
    static let secondaryHeight: CGFloat = 56
    static let buttonRadius: CGFloat = 20
    static let cardRadius: CGFloat = 28

    /// UI settle: spring 0.45 / 0.86. Reduce Motion: a 0.2 s crossfade.
    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)
    }

    static func pop(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.3, dampingFraction: 0.6)
    }

    static func pageTransition(_ reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return AnyTransition.offset(x: 0, y: 24).combined(with: .opacity)
    }

    /// The day's light for the HUD's accents (matches the scene's tint by day phase).
    static func dayColor(_ phase: DayPhase) -> Color {
        switch phase {
        case .morning: return Color(snapHex: 0xFFD27A)
        case .noon: return Color(snapHex: 0xFFF3C4)
        case .dusk: return Color(snapHex: 0xFFA27A)
        case .night: return Color(snapHex: 0x9DB8FF)
        }
    }
}

/// The full-screen bog backdrop for pages: deep moss with a warm sunlit glow from the top and a little dew.
struct SnapBackdrop: View {
    var glow: Color = SnapTheme.goldLight

    var body: some View {
        ZStack {
            LinearGradient(colors: [SnapTheme.moss, SnapTheme.bog, SnapTheme.bogDeep, SnapTheme.night],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [glow.opacity(0.20), glow.opacity(0)], center: UnitPoint(x: 0.5, y: 0.08),
                           startRadius: 10, endRadius: 520)
            DewField()
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// The menus' backdrop (juror 7: "menus have no world"): the bog as the scene last drew it, blurred and dimmed, with
/// the page glow on top, so Results, the Bug Book, Settings and the Daily sit in the same place as play. Before the
/// scene has drawn anything it is the painted gradient.
struct BogBackdrop: View {
    @ObservedObject var controller: GameController
    var glow: Color = SnapTheme.goldLight

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let still = controller.bogStill {
                    Image(uiImage: still)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 12, opaque: true)
                        .clipped()
                    Color.black.opacity(0.45)
                    RadialGradient(colors: [glow.opacity(0.14), glow.opacity(0)], center: UnitPoint(x: 0.5, y: 0.08),
                                   startRadius: 10, endRadius: 520)
                } else {
                    SnapBackdrop(glow: glow)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { controller.ensureStill() }
    }
}

/// A sprinkle of dew (fixed positions, so frames are stable).
struct DewField: View {
    static let drops: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.06, 0.18, 3), (0.14, 0.72, 2), (0.22, 0.38, 2.5), (0.31, 0.88, 3), (0.42, 0.12, 2), (0.57, 0.80, 2.5),
        (0.66, 0.30, 2), (0.74, 0.62, 3), (0.83, 0.16, 2.5), (0.91, 0.84, 2), (0.96, 0.46, 3), (0.48, 0.55, 1.5),
    ]

    var body: some View {
        Canvas { context, size in
            for d in DewField.drops {
                let c = CGPoint(x: d.x * size.width, y: d.y * size.height)
                let rect = CGRect(x: c.x - d.r, y: c.y - d.r, width: d.r * 2, height: d.r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.16)))
                let glint = CGRect(x: c.x - d.r * 0.5, y: c.y - d.r * 0.6, width: d.r * 0.6, height: d.r * 0.6)
                context.fill(Path(ellipseIn: glint), with: .color(Color.white.opacity(0.5)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The type scale. `compact` = a short canvas (an iPhone in landscape, ~390 pt tall).
enum SnapType {
    static func wordmark(_ c: Bool) -> Font { .system(size: c ? 54 : 78, weight: .black, design: .rounded) }
    static func hero(_ c: Bool) -> Font { .system(size: c ? 56 : 80, weight: .black, design: .rounded).monospacedDigit() }
    static func title(_ c: Bool) -> Font { .system(size: c ? 24 : 30, weight: .heavy, design: .rounded) }
    static func headline(_ c: Bool) -> Font { .system(size: c ? 18 : 21, weight: .bold, design: .rounded) }
    static func hint(_ c: Bool) -> Font { .system(size: c ? 19 : 23, weight: .heavy, design: .rounded) }
    static func button(_ c: Bool) -> Font { .system(size: c ? 19 : 22, weight: .bold, design: .rounded) }
    static func body(_ c: Bool) -> Font { .system(size: c ? 15 : 17, weight: .semibold, design: .rounded) }
    static func caption(_ c: Bool) -> Font { .system(size: c ? 12 : 14, weight: .medium, design: .rounded) }
    static func overline(_ c: Bool) -> Font { .system(size: c ? 11 : 13, weight: .heavy, design: .rounded) }
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded).monospacedDigit() }
}

extension Color {
    /// 0xRRGGBB.
    init(snapHex hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }

    /// A palette colour (Contracts' platform-neutral RGBA, e.g. `TrapArt.palette`).
    init(snapRGBA c: RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

// MARK: - Buttons

struct SnapButtonStyle: ButtonStyle {
    /// `primary` gold (one per screen), `secondary` moss, `quiet` text only, `crimson` the trap's own (Feed on Home).
    enum Kind { case primary, secondary, quiet, crimson }
    var kind: Kind = .primary
    var height: CGFloat = SnapTheme.primaryHeight
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let h = max(height, SnapTheme.minTap)
        return configuration.label
            .font(kind == .quiet ? SnapType.body(compact) : SnapType.button(compact))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: h)
            .padding(.horizontal, 14)
            .background(SnapButtonBackground(kind: kind, pressed: pressed).frame(minHeight: h))
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(kind == .quiet && pressed ? 0.6 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return SnapTheme.ink
        case .secondary, .crimson: return SnapTheme.cream
        case .quiet: return SnapTheme.mist
        }
    }
}

struct SnapButtonBackground: View {
    let kind: SnapButtonStyle.Kind
    let pressed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SnapTheme.buttonRadius, style: .continuous)
        ZStack {
            switch kind {
            case .primary:
                // A 5 pt lip that presses to 1 pt: a chunky, juicy button.
                shape.fill(SnapTheme.goldDeep).offset(y: pressed ? 1 : 5)
                shape.fill(LinearGradient(colors: [SnapTheme.goldLight, SnapTheme.gold], startPoint: .top,
                                          endPoint: .bottom))
                    .overlay(shape.inset(by: 3).stroke(Color.white.opacity(0.35), lineWidth: 2)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)))
                    .offset(y: pressed ? 4 : 0)
                    .shadow(color: SnapTheme.gold.opacity(0.30), radius: 14, y: 4)
            case .crimson:
                shape.fill(SnapTheme.crimsonDeep).offset(y: pressed ? 1 : 5)
                shape.fill(LinearGradient(colors: [SnapTheme.pink, SnapTheme.crimson], startPoint: .top,
                                          endPoint: .bottom))
                    .overlay(shape.stroke(SnapTheme.lime, lineWidth: 3))
                    .offset(y: pressed ? 4 : 0)
                    .shadow(color: SnapTheme.crimson.opacity(0.35), radius: 14, y: 4)
            case .secondary:
                shape.fill(pressed ? SnapTheme.surfacePressed : SnapTheme.surfaceRaised)
                    .overlay(shape.stroke(SnapTheme.lime.opacity(0.28), lineWidth: 1.5))
            case .quiet:
                Color.clear
            }
        }
    }
}

/// A button with the theme's style (the label is any view).
struct SnapButton<Content: View>: View {
    var kind: SnapButtonStyle.Kind = .primary
    var height: CGFloat = SnapTheme.primaryHeight
    var compact = false
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        Button(action: action) { label() }
            .buttonStyle(SnapButtonStyle(kind: kind, height: height, compact: compact))
    }
}

/// A round icon button (the HUD's pause, a page's back) with a ≥ 56 pt hit area.
struct SnapRoundButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(SnapTheme.surface.opacity(0.88))
                Circle().stroke(SnapTheme.lime.opacity(0.45), lineWidth: 2)
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.38, weight: .heavy))
                    .foregroundStyle(SnapTheme.cream)
            }
            .frame(width: size, height: size)
            .frame(width: max(size, SnapTheme.minTap), height: max(size, SnapTheme.minTap))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Cards and pills

struct SnapCardModifier: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = SnapTheme.cardRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(padding)
            .background(
                shape.fill(LinearGradient(colors: [SnapTheme.surfaceRaised.opacity(0.96), SnapTheme.surface.opacity(0.96)],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.stroke(SnapTheme.lime.opacity(0.22), lineWidth: 1.5))
                    .shadow(color: SnapTheme.shadow.opacity(0.5), radius: 16, y: 6)
            )
    }
}

extension View {
    func snapCard(padding: CGFloat = 18, radius: CGFloat = SnapTheme.cardRadius) -> some View {
        modifier(SnapCardModifier(padding: padding, radius: radius))
    }

    /// Text that must read over the bright trap: a soft dark halo.
    func snapLegible() -> some View {
        shadow(color: SnapTheme.shadow.opacity(0.75), radius: 6, y: 2)
            .shadow(color: SnapTheme.shadow.opacity(0.45), radius: 1, y: 1)
    }
}

/// A small caps label ("PAUSED", "NEW BEST").
struct SnapOverline: View {
    let text: String
    var compact = false
    var color: Color = SnapTheme.limeLight

    var body: some View {
        Text(text.uppercased())
            .font(SnapType.overline(compact))
            .kerning(1.2)
            .foregroundStyle(color)
    }
}

/// A gold pill ("New best!").
struct SnapPill: View {
    let text: String
    var color: Color = SnapTheme.gold
    var textColor: Color = SnapTheme.ink

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(color))
    }
}

/// A rounded progress bar (the rank bar).
struct SnapProgressBar: View {
    let value: Double
    var height: CGFloat = 10
    var fill: Color = SnapTheme.lime

    var body: some View {
        GeometryReader { geo in
            let v = CGFloat(min(max(value.isFinite ? value : 0, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.35))
                Capsule().fill(LinearGradient(colors: [SnapTheme.limeLight, fill], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(geo.size.width * v, v > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}
