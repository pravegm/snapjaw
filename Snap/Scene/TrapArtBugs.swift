import CoreGraphics
import Foundation

/// One bug's art, centred at the origin, facing +x, y up, in points. Draw order (`TrapArt.drawBug`): legs and
/// antennae (outline colour), the silhouette's outline, the body (gradient), the markings (`accent`, `accent2`,
/// clipped to the silhouette), the head, the shine, cheeks, eyes with pupils and glints, brows. Wings are drawn
/// separately (`TrapArt.drawWings`) so the scene can flap them.
struct TrapBugArt {
    var body: CGPath
    var head: CGPath
    var accent: CGPath
    var accent2: CGPath
    var legs: CGPath
    var antennae: CGPath
    var eyes: CGPath
    var pupils: CGPath
    var glints: CGPath
    var brows: CGPath
    var cheeks: CGPath
    var shine: CGPath
    var wings: CGPath
    var wingVeins: CGPath
    var wingSpots: CGPath
    var legWidth: CGFloat
    var outlineWidth: CGFloat
    /// Where a firefly's lantern is (bug space), for the glow.
    var lantern: CGPoint?
}

/// A species' colours and wing behaviour.
struct TrapBugStyle: Equatable, Sendable {
    var body: RGBA
    var head: RGBA
    var accent: RGBA
    var accent2: RGBA
    var wing: RGBA
    var eye: RGBA
    var pupil: RGBA
    var cheek: RGBA
    /// Wing beats per second when flying (0 = never flaps: ants, crickets).
    var flapHz: Double
    /// The wings' spread when landed (0 hidden under wing cases, ≈ 0.3 folded back, 1 spread like a moth).
    var restSpread: CGFloat
    /// A fuzzy fringe (bees, moths).
    var fuzzy: Bool
}

/// The cartoon builder: every coordinate is in units of the bug's radius.
private final class BugSketch {
    let r: CGFloat
    let body = CGMutablePath()
    let head = CGMutablePath()
    let accent = CGMutablePath()
    let accent2 = CGMutablePath()
    let legs = CGMutablePath()
    let antennae = CGMutablePath()
    let eyes = CGMutablePath()
    let pupils = CGMutablePath()
    let glints = CGMutablePath()
    let brows = CGMutablePath()
    let cheeks = CGMutablePath()
    let shine = CGMutablePath()
    let wings = CGMutablePath()
    let veins = CGMutablePath()
    let spots = CGMutablePath()
    var lantern: CGPoint?

    init(_ r: CGFloat) { self.r = max(r, 1) }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * r, y: y * r) }

    func oval(_ path: CGMutablePath, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat = 0) {
        let t = CGAffineTransform(translationX: x * r, y: y * r).rotated(by: rot)
        path.addEllipse(in: CGRect(x: -rx * r, y: -ry * r, width: 2 * rx * r, height: 2 * ry * r), transform: t)
    }

    /// Two ovals mirrored about the body axis (y → −y, rotation → −rotation).
    func ovalPair(_ path: CGMutablePath, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                  _ rot: CGFloat = 0) {
        oval(path, x, y, rx, ry, rot)
        oval(path, x, -y, rx, ry, -rot)
    }

    func circle(_ path: CGMutablePath, _ x: CGFloat, _ y: CGFloat, _ rr: CGFloat) { oval(path, x, y, rr, rr) }

    /// A band across the body from x0 to x1 (clipped to the silhouette when drawn).
    func band(_ path: CGMutablePath, _ x0: CGFloat, _ x1: CGFloat) {
        path.addRect(CGRect(x: min(x0, x1) * r, y: -2 * r, width: abs(x1 - x0) * r, height: 4 * r))
    }

    func poly(_ path: CGMutablePath, _ pts: [(CGFloat, CGFloat)]) {
        guard let f = pts.first else { return }
        path.move(to: p(f.0, f.1))
        for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1)) }
        path.closeSubpath()
    }

    func polyPair(_ path: CGMutablePath, _ pts: [(CGFloat, CGFloat)]) {
        poly(path, pts)
        poly(path, pts.map { ($0.0, -$0.1) })
    }

    /// An open polyline (legs, antennae: stroked).
    func line(_ path: CGMutablePath, _ pts: [(CGFloat, CGFloat)]) {
        guard let f = pts.first else { return }
        path.move(to: p(f.0, f.1))
        for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1)) }
    }

    func linePair(_ path: CGMutablePath, _ pts: [(CGFloat, CGFloat)]) {
        line(path, pts)
        line(path, pts.map { ($0.0, -$0.1) })
    }

    /// An antenna pair from the head, curving out, with an optional club.
    func antennaPair(_ pts: [(CGFloat, CGFloat)], club: CGFloat = 0) {
        let path = CGMutablePath()
        guard let f = pts.first else { return }
        path.move(to: p(f.0, f.1))
        if pts.count == 3 {
            path.addQuadCurve(to: p(pts[2].0, pts[2].1), control: p(pts[1].0, pts[1].1))
        } else {
            for q in pts.dropFirst() { path.addLine(to: p(q.0, q.1)) }
        }
        antennae.addPath(path)
        antennae.addPath(path, transform: CGAffineTransform(scaleX: 1, y: -1))
        if club > 0, let last = pts.last {
            circle(head, last.0, last.1, club)
            circle(head, last.0, -last.1, club)
        }
    }

    /// Six legs from the thorax at `x0`: front pair forward, middle out, back pair backward.
    func sixLegs(_ x0: CGFloat, spread s: CGFloat, length L: CGFloat) {
        linePair(legs, [(x0 + 0.1, 0.2), (x0 + 0.1 + 0.22 * L, 0.2 + 0.32 * s * L),
                        (x0 + 0.1 + 0.42 * L, 0.2 + 0.48 * s * L)])
        linePair(legs, [(x0 - 0.02, 0.22), (x0 - 0.02 + 0.02 * L, 0.22 + 0.4 * s * L),
                        (x0 - 0.02 - 0.1 * L, 0.22 + 0.6 * s * L)])
        linePair(legs, [(x0 - 0.14, 0.2), (x0 - 0.14 - 0.24 * L, 0.2 + 0.32 * s * L),
                        (x0 - 0.14 - 0.5 * L, 0.2 + 0.46 * s * L)])
    }

    /// Big cartoon eyes on the head at (x, ±y), radius `er`, pupils looking forward.
    func eyePair(_ x: CGFloat, _ y: CGFloat, _ er: CGFloat, look: CGFloat = 0.3) {
        for sy in [CGFloat(1), CGFloat(-1)] {
            circle(eyes, x, sy * y, er)
            let px = x + er * look, py = sy * y * 0.97
            circle(pupils, px, py, er * 0.56)
            circle(glints, px - er * 0.1, py + er * 0.24, er * 0.22)
        }
    }

    /// A wing pair: ovals from the thorax angled back and out, a vein along each.
    func wingPair(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ rot: CGFloat) {
        ovalPair(wings, x, y, rx, ry, rot)
        for sy in [CGFloat(1), CGFloat(-1)] {
            let a = sy * rot
            let c = CGPoint(x: x, y: sy * y)
            let dx = cos(a) * rx * 0.85, dy = sin(a) * rx * 0.85
            veins.move(to: p(c.x + dx, c.y + dy))
            veins.addLine(to: p(c.x - dx, c.y - dy))
            veins.move(to: p(c.x, c.y))
            veins.addLine(to: p(c.x - dx * 0.7 - sin(a) * ry * 0.5, c.y - dy * 0.7 + cos(a) * ry * 0.5))
        }
    }

    func art(legWidth: CGFloat, outline: CGFloat) -> TrapBugArt {
        TrapBugArt(body: body, head: head, accent: accent, accent2: accent2, legs: legs, antennae: antennae,
                   eyes: eyes, pupils: pupils, glints: glints, brows: brows, cheeks: cheeks, shine: shine,
                   wings: wings, wingVeins: veins, wingSpots: spots, legWidth: legWidth, outlineWidth: outline,
                   lantern: lantern)
    }
}

extension TrapArt {
    // MARK: Public bug API (ARCHITECTURE)

    /// The bug's silhouette (body and head), centred at the origin, facing +x.
    static func bugBody(_ s: BugSpecies, radius: CGFloat) -> CGPath {
        let a = bugArt(s, radius: radius)
        let p = CGMutablePath()
        p.addPath(a.body)
        p.addPath(a.head)
        return p
    }

    /// The bug's wings, spread (the scene squeezes them to fold or flap). Empty for ants.
    static func bugWings(_ s: BugSpecies, radius: CGFloat) -> CGPath {
        bugArt(s, radius: radius).wings
    }

    static func bugColors(_ s: BugSpecies) -> (body: RGBA, accent: RGBA, wing: RGBA, eye: RGBA) {
        let st = bugStyle(s)
        return (st.body, st.accent, st.wing, st.eye)
    }

    // MARK: Extras for the scene and SwiftUI

    /// Half the side of the square every bug's art fits in.
    static func bugExtent(radius: CGFloat) -> CGFloat { radius * 1.45 + 2 }

    /// The art radius per species: R1's radius × `artScale` (R2: the bugs are the subject, so they are drawn 1.8 ×
    /// bigger; Core's `BugInfo.radius` grows by the same factor, so the art and the rules agree). The scene draws
    /// `max(BugInfo.radius, defaultRadius)`, so a Core that already scaled is never scaled twice.
    static func defaultRadius(_ s: BugSpecies) -> CGFloat {
        (baseRadius(s) * artScale * 10).rounded() / 10
    }

    /// R1's art radius per species (Core's R1 `BugInfo.radius`).
    static func baseRadius(_ s: BugSpecies) -> CGFloat {
        switch s {
        case .housefly: return 14
        case .gnat: return 7
        case .fruitFly: return 9
        case .bluebottle: return 16
        case .ant: return 10
        case .ladybird: return 14
        case .grasshopper: return 18
        case .moth: return 18
        case .mosquito: return 9
        case .dragonfly: return 24
        case .firefly: return 13
        case .cricket: return 17
        case .goldenScarab: return 20
        case .bee: return 16
        case .bumblebee: return 22
        case .wasp: return 16
        }
    }

    static func bugStyle(_ s: BugSpecies) -> TrapBugStyle {
        let white = RGBA(hex: 0xFFFFFF)
        let pupil = RGBA(hex: 0x1A0E10)
        let pink = RGBA(hex: 0xFF8FA8)
        switch s {
        case .housefly:
            return TrapBugStyle(body: RGBA(hex: 0x575E6B), head: RGBA(hex: 0x3F444E), accent: RGBA(hex: 0x9AA5B5),
                                accent2: RGBA(hex: 0x2E323A), wing: RGBA(hex: 0xDDEBFF, alpha: 0.55),
                                eye: RGBA(hex: 0xFFF6F0), pupil: pupil, cheek: pink, flapHz: 38, restSpread: 0.32,
                                fuzzy: false)
        case .gnat:
            return TrapBugStyle(body: RGBA(hex: 0x6B5A4E), head: RGBA(hex: 0x4E4038), accent: RGBA(hex: 0x9C8A7A),
                                accent2: RGBA(hex: 0x3E332C), wing: RGBA(hex: 0xEAF2FF, alpha: 0.5), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 44, restSpread: 0.35, fuzzy: false)
        case .fruitFly:
            return TrapBugStyle(body: RGBA(hex: 0xE0A85C), head: RGBA(hex: 0xCF9145), accent: RGBA(hex: 0x6B3B1E),
                                accent2: RGBA(hex: 0xF3D29A), wing: RGBA(hex: 0xF0F6FF, alpha: 0.55),
                                eye: RGBA(hex: 0xFF5A4C), pupil: RGBA(hex: 0x3A0A08), cheek: pink, flapHz: 40,
                                restSpread: 0.35, fuzzy: false)
        case .bluebottle:
            return TrapBugStyle(body: RGBA(hex: 0x2F78E0), head: RGBA(hex: 0x263556), accent: RGBA(hex: 0x9BE0FF),
                                accent2: RGBA(hex: 0x1B3F86), wing: RGBA(hex: 0xD8E8FF, alpha: 0.55), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 42, restSpread: 0.3, fuzzy: false)
        case .ant:
            return TrapBugStyle(body: RGBA(hex: 0x40281F), head: RGBA(hex: 0x352019), accent: RGBA(hex: 0x8A5642),
                                accent2: RGBA(hex: 0x24140F), wing: RGBA(hex: 0xFFFFFF, alpha: 0), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 0, restSpread: 0, fuzzy: false)
        case .ladybird:
            return TrapBugStyle(body: RGBA(hex: 0xFF6A1F), head: RGBA(hex: 0x1F1A1C), accent: RGBA(hex: 0x1F1A1C),
                                accent2: RGBA(hex: 0xFFFFFF), wing: RGBA(hex: 0xF2E8E0, alpha: 0.55), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 30, restSpread: 0, fuzzy: false)
        case .grasshopper:
            return TrapBugStyle(body: RGBA(hex: 0x8DCC46), head: RGBA(hex: 0x7CBB3A), accent: RGBA(hex: 0x4F8A2A),
                                accent2: RGBA(hex: 0xD2EE86), wing: RGBA(hex: 0xC8F09A, alpha: 0.6), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 24, restSpread: 0, fuzzy: false)
        case .moth:
            return TrapBugStyle(body: RGBA(hex: 0xC8A877), head: RGBA(hex: 0xB89668), accent: RGBA(hex: 0x6E5236),
                                accent2: RGBA(hex: 0xF5E7C6), wing: RGBA(hex: 0xEBD9B2, alpha: 0.96), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 9, restSpread: 1, fuzzy: true)
        case .mosquito:
            return TrapBugStyle(body: RGBA(hex: 0x50566A), head: RGBA(hex: 0x3E4354), accent: RGBA(hex: 0xF2F2F7),
                                accent2: RGBA(hex: 0x30343F), wing: RGBA(hex: 0xE6EEFF, alpha: 0.5), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 48, restSpread: 0.3, fuzzy: false)
        case .dragonfly:
            return TrapBugStyle(body: RGBA(hex: 0x2DB9CB), head: RGBA(hex: 0x1C8FA6), accent: RGBA(hex: 0x12597A),
                                accent2: RGBA(hex: 0x8FF0F5), wing: RGBA(hex: 0xDDF6FF, alpha: 0.45), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 22, restSpread: 1, fuzzy: false)
        case .firefly:
            return TrapBugStyle(body: RGBA(hex: 0x3E312B), head: RGBA(hex: 0xE8673A), accent: RGBA(hex: 0xE6FF6E),
                                accent2: RGBA(hex: 0x241B17), wing: RGBA(hex: 0xEDEFE0, alpha: 0.5), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 26, restSpread: 0, fuzzy: false)
        case .cricket:
            return TrapBugStyle(body: RGBA(hex: 0x4A3427), head: RGBA(hex: 0x33241B), accent: RGBA(hex: 0x8A6A50),
                                accent2: RGBA(hex: 0x2A1D16), wing: RGBA(hex: 0x8A6A50, alpha: 0), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 0, restSpread: 0, fuzzy: false)
        case .goldenScarab:
            return TrapBugStyle(body: RGBA(hex: 0xF6C632), head: RGBA(hex: 0xDDA51C), accent: RGBA(hex: 0x9A680A),
                                accent2: RGBA(hex: 0xFFF3B0), wing: RGBA(hex: 0xFFF2C8, alpha: 0.55), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 28, restSpread: 0, fuzzy: false)
        case .bee:
            return TrapBugStyle(body: RGBA(hex: 0xFFD23A), head: RGBA(hex: 0x3A2A1C), accent: RGBA(hex: 0x2B2118),
                                accent2: RGBA(hex: 0xFFE98A), wing: RGBA(hex: 0xF4FAFF, alpha: 0.72), eye: white,
                                pupil: pupil, cheek: RGBA(hex: 0xFF7E95), flapHz: 34, restSpread: 0.45,
                                fuzzy: true)
        case .bumblebee:
            return TrapBugStyle(body: RGBA(hex: 0xFFC52E), head: RGBA(hex: 0x241B14), accent: RGBA(hex: 0x241B14),
                                accent2: RGBA(hex: 0xFFF4E0), wing: RGBA(hex: 0xF2F7FF, alpha: 0.72), eye: white,
                                pupil: pupil, cheek: RGBA(hex: 0xFF7E95), flapHz: 26, restSpread: 0.45,
                                fuzzy: true)
        case .wasp:
            return TrapBugStyle(body: RGBA(hex: 0xFFCC1A), head: RGBA(hex: 0xF2B70E), accent: RGBA(hex: 0x1A1410),
                                accent2: RGBA(hex: 0xFF8A1A), wing: RGBA(hex: 0xFFE2A0, alpha: 0.5), eye: white,
                                pupil: pupil, cheek: pink, flapHz: 32, restSpread: 0.3, fuzzy: false)
        }
    }

    /// The full layered art for a species at `radius`.
    static func bugArt(_ s: BugSpecies, radius: CGFloat) -> TrapBugArt {
        let k = BugSketch(radius)
        let r = k.r
        let legW = max(r * 0.085, 1.1)
        let ow = max(r * 0.085, 1.2)
        switch s {
        case .housefly:
            k.oval(k.body, -0.36, 0, 0.62, 0.48)
            k.oval(k.body, 0.16, 0, 0.40, 0.42)
            k.oval(k.head, 0.62, 0, 0.34, 0.37)
            for y in [CGFloat(-0.17), 0, 0.17] {
                k.accent.addPath(BogPainter.roundRect(CGRect(x: -0.02 * r, y: (y - 0.035) * r, width: 0.4 * r,
                                                             height: 0.07 * r), 0.035 * r))
            }
            k.ovalPair(k.accent2, -0.46, 0.2, 0.16, 0.1, 0.2)
            k.sixLegs(0.14, spread: 0.75, length: 1)
            k.antennaPair([(0.88, 0.1), (0.98, 0.16), (1.06, 0.24)])
            k.eyePair(0.7, 0.2, 0.2)
            k.oval(k.shine, -0.5, 0.24, 0.2, 0.09, 0.25)
            k.wingPair(-0.3, 0.44, 0.56, 0.22, -0.58)
        case .gnat:
            k.oval(k.body, -0.38, 0, 0.58, 0.3)
            k.oval(k.body, 0.1, 0, 0.32, 0.32)
            k.oval(k.head, 0.5, 0, 0.28, 0.29)
            k.band(k.accent, -0.62, -0.54)
            k.band(k.accent, -0.42, -0.34)
            k.sixLegs(0.1, spread: 0.95, length: 1.3)
            k.antennaPair([(0.72, 0.1), (0.86, 0.2), (0.98, 0.34)])
            k.eyePair(0.56, 0.15, 0.2)
            k.oval(k.shine, -0.5, 0.12, 0.2, 0.07, 0.1)
            k.wingPair(-0.32, 0.38, 0.55, 0.2, -0.5)
        case .fruitFly:
            k.oval(k.body, -0.34, 0, 0.58, 0.46)
            k.oval(k.body, 0.14, 0, 0.4, 0.4)
            k.oval(k.head, 0.58, 0, 0.32, 0.34)
            k.band(k.accent, -0.76, -0.66)
            k.band(k.accent, -0.54, -0.44)
            k.band(k.accent, -0.32, -0.24)
            k.oval(k.accent2, 0.16, 0, 0.22, 0.1)
            k.sixLegs(0.14, spread: 0.75, length: 1)
            k.antennaPair([(0.82, 0.1), (0.92, 0.16), (1.0, 0.22)])
            k.eyePair(0.64, 0.19, 0.22)
            k.oval(k.shine, -0.46, 0.22, 0.2, 0.08, 0.25)
            k.wingPair(-0.28, 0.42, 0.55, 0.22, -0.55)
        case .bluebottle:
            k.oval(k.body, -0.36, 0, 0.66, 0.56)
            k.oval(k.body, 0.18, 0, 0.4, 0.44)
            k.oval(k.head, 0.64, 0, 0.32, 0.36)
            k.oval(k.accent, -0.44, 0.22, 0.3, 0.12, 0.18)
            k.oval(k.accent, -0.28, -0.3, 0.2, 0.07, -0.2)
            k.oval(k.accent2, 0.18, 0, 0.26, 0.3)
            k.sixLegs(0.16, spread: 0.75, length: 1)
            k.antennaPair([(0.9, 0.1), (1.0, 0.16), (1.08, 0.24)])
            k.eyePair(0.7, 0.2, 0.19)
            k.oval(k.shine, -0.56, 0.3, 0.16, 0.08, 0.4)
            k.circle(k.shine, 0.24, 0.22, 0.07)
            k.wingPair(-0.3, 0.48, 0.6, 0.24, -0.58)
        case .ant:
            k.oval(k.body, -0.52, 0, 0.42, 0.34)
            k.oval(k.body, -0.1, 0, 0.11, 0.09)
            k.oval(k.body, 0.12, 0, 0.24, 0.15)
            k.oval(k.head, 0.5, 0, 0.27, 0.26)
            k.oval(k.accent, -0.58, 0.12, 0.2, 0.08, 0.2)
            k.sixLegs(0.12, spread: 0.85, length: 1.15)
            k.antennaPair([(0.7, 0.12), (0.82, 0.34), (1.05, 0.42)])
            k.eyePair(0.58, 0.13, 0.15)
            k.oval(k.shine, -0.6, 0.16, 0.16, 0.07, 0.2)
        case .ladybird:
            k.oval(k.body, -0.08, 0, 0.74, 0.7)
            k.oval(k.head, 0.48, 0, 0.24, 0.42)
            k.oval(k.head, 0.72, 0, 0.2, 0.27)
            k.circle(k.accent, -0.36, 0.36, 0.14)
            k.circle(k.accent, -0.36, -0.36, 0.14)
            k.circle(k.accent, 0.04, 0.4, 0.12)
            k.circle(k.accent, 0.04, -0.4, 0.12)
            k.circle(k.accent, -0.62, 0.14, 0.1)
            k.circle(k.accent, -0.62, -0.14, 0.1)
            k.circle(k.accent, 0.12, 0, 0.13)
            k.accent.addRect(CGRect(x: -0.86 * r, y: -0.028 * r, width: 1.2 * r, height: 0.056 * r))
            k.ovalPair(k.accent2, 0.5, 0.27, 0.09, 0.08)
            k.sixLegs(0.2, spread: 0.75, length: 0.65)
            k.antennaPair([(0.86, 0.1), (0.96, 0.18), (1.02, 0.26)])
            k.eyePair(0.76, 0.14, 0.14)
            k.oval(k.shine, -0.3, 0.38, 0.28, 0.12, 0.35)
            k.circle(k.shine, 0.2, 0.42, 0.06)
            k.wingPair(-0.36, 0.56, 0.6, 0.25, -0.75)
        case .grasshopper:
            k.oval(k.body, -0.48, 0, 0.62, 0.22)
            k.oval(k.body, 0.12, 0, 0.32, 0.26)
            k.ovalPair(k.body, -0.24, 0.32, 0.44, 0.12, -0.36)
            k.oval(k.head, 0.56, 0, 0.3, 0.27)
            k.accent.addRect(CGRect(x: -1.0 * r, y: -0.05 * r, width: 1.2 * r, height: 0.1 * r))
            k.band(k.accent2, -0.86, -0.82)
            k.band(k.accent2, -0.66, -0.62)
            k.band(k.accent2, -0.46, -0.42)
            k.linePair(k.legs, [(0.22, 0.2), (0.38, 0.44), (0.56, 0.54)])
            k.linePair(k.legs, [(0.06, 0.22), (0.06, 0.5), (-0.04, 0.62)])
            k.linePair(k.legs, [(-0.6, 0.5), (-0.94, 0.34), (-1.08, 0.38)])
            k.antennaPair([(0.8, 0.08), (1.1, 0.16), (1.36, 0.3)])
            k.eyePair(0.62, 0.15, 0.16)
            k.oval(k.shine, -0.4, 0.1, 0.34, 0.06, 0.05)
            k.wingPair(-0.32, 0.42, 0.62, 0.2, -0.45)
        case .moth:
            k.oval(k.body, -0.25, 0, 0.55, 0.26)
            k.oval(k.head, 0.36, 0, 0.24, 0.23)
            k.band(k.accent, -0.5, -0.44)
            k.band(k.accent, -0.3, -0.24)
            k.sixLegs(0.06, spread: 0.6, length: 0.6)
            // Feathery antennae.
            k.antennaPair([(0.5, 0.1), (0.72, 0.3), (0.86, 0.5)])
            for i in 0..<4 {
                let t = 0.25 + CGFloat(i) * 0.2
                let x = 0.5 + 0.36 * t, y = 0.1 + 0.4 * t
                k.linePair(k.antennae, [(x, y), (x + 0.1, y - 0.03)])
                k.linePair(k.antennae, [(x, y), (x - 0.03, y + 0.1)])
            }
            k.eyePair(0.42, 0.13, 0.13)
            k.oval(k.shine, -0.3, 0.1, 0.26, 0.06, 0)
            // Broad wings, spread flat at rest (a soft delta).
            for sy in [CGFloat(1), CGFloat(-1)] {
                let w = CGMutablePath()
                w.move(to: k.p(0.14, sy * 0.1))
                w.addCurve(to: k.p(-0.12, sy * 1.05), control1: k.p(0.3, sy * 0.5), control2: k.p(0.14, sy * 1.0))
                w.addCurve(to: k.p(-0.62, sy * 0.62), control1: k.p(-0.4, sy * 1.12), control2: k.p(-0.7, sy * 0.9))
                w.addCurve(to: k.p(-0.3, sy * 0.1), control1: k.p(-0.56, sy * 0.36), control2: k.p(-0.42, sy * 0.16))
                w.closeSubpath()
                k.wings.addPath(w)
                let h = CGMutablePath()
                h.move(to: k.p(-0.3, sy * 0.12))
                h.addCurve(to: k.p(-0.9, sy * 0.5), control1: k.p(-0.5, sy * 0.4), control2: k.p(-0.8, sy * 0.66))
                h.addCurve(to: k.p(-0.6, sy * 0.1), control1: k.p(-0.98, sy * 0.3), control2: k.p(-0.8, sy * 0.12))
                h.closeSubpath()
                k.wings.addPath(h)
                k.veins.move(to: k.p(0.1, sy * 0.14))
                k.veins.addQuadCurve(to: k.p(-0.1, sy * 0.95), control: k.p(0.12, sy * 0.6))
                k.veins.move(to: k.p(-0.1, sy * 0.16))
                k.veins.addQuadCurve(to: k.p(-0.5, sy * 0.66), control: k.p(-0.24, sy * 0.48))
                k.circle(k.spots, -0.24, sy * 0.62, 0.13)
                k.circle(k.spots, -0.7, sy * 0.38, 0.06)
            }
        case .mosquito:
            k.oval(k.body, -0.45, 0, 0.52, 0.17)
            k.oval(k.body, 0.06, 0, 0.25, 0.23)
            k.oval(k.head, 0.38, 0, 0.17, 0.17)
            for x in [CGFloat(-0.82), -0.64, -0.46, -0.28] { k.band(k.accent, x, x + 0.06) }
            k.sixLegs(0.06, spread: 1.2, length: 1.5)
            k.line(k.antennae, [(0.52, 0), (0.98, 0)])
            k.antennaPair([(0.5, 0.06), (0.62, 0.16), (0.7, 0.3)])
            k.eyePair(0.42, 0.1, 0.15)
            k.wingPair(-0.3, 0.3, 0.5, 0.13, -0.35)
        case .dragonfly:
            k.body.addPath(BogPainter.roundRect(CGRect(x: -1.32 * r, y: -0.085 * r, width: 1.3 * r,
                                                       height: 0.17 * r), 0.085 * r))
            k.oval(k.body, 0.1, 0, 0.22, 0.18)
            k.oval(k.head, 0.38, 0, 0.16, 0.22)
            var x: CGFloat = -1.14
            while x < -0.1 {
                k.band(k.accent, x, x + 0.035)
                x += 0.17
            }
            k.oval(k.accent2, 0.1, 0, 0.12, 0.06)
            k.sixLegs(0.12, spread: 0.45, length: 0.45)
            k.antennaPair([(0.52, 0.05), (0.58, 0.08), (0.62, 0.12)])
            k.eyePair(0.4, 0.13, 0.13, look: 0.25)
            k.oval(k.shine, -0.6, 0.03, 0.5, 0.025, 0)
            k.ovalPair(k.wings, 0.14, 0.58, 0.12, 0.52, -0.12)
            k.ovalPair(k.wings, -0.08, 0.56, 0.14, 0.5, 0.16)
            for sy in [CGFloat(1), CGFloat(-1)] {
                k.veins.move(to: k.p(0.14, sy * 0.1))
                k.veins.addLine(to: k.p(0.2, sy * 1.06))
                k.veins.move(to: k.p(-0.08, sy * 0.1))
                k.veins.addLine(to: k.p(-0.17, sy * 1.02))
                k.circle(k.spots, 0.21, sy * 0.98, 0.035)
                k.circle(k.spots, -0.16, sy * 0.95, 0.035)
            }
        case .firefly:
            k.oval(k.body, -0.2, 0, 0.6, 0.38)
            k.oval(k.body, -0.66, 0, 0.24, 0.3)
            k.oval(k.head, 0.42, 0, 0.24, 0.34)
            k.oval(k.head, 0.64, 0, 0.17, 0.21)
            k.oval(k.accent, -0.66, 0, 0.24, 0.3)
            k.accent2.addRect(CGRect(x: -0.5 * r, y: -0.025 * r, width: 0.72 * r, height: 0.05 * r))
            k.oval(k.accent2, 0.42, 0, 0.08, 0.1)
            k.sixLegs(0.2, spread: 0.7, length: 0.75)
            k.antennaPair([(0.78, 0.1), (0.92, 0.22), (1.0, 0.34)])
            k.eyePair(0.68, 0.12, 0.14)
            k.oval(k.shine, -0.2, 0.2, 0.3, 0.08, 0.15)
            k.circle(k.shine, -0.72, 0.12, 0.07)
            k.wingPair(-0.3, 0.46, 0.55, 0.22, -0.6)
            k.lantern = k.p(-0.66, 0)
        case .cricket:
            k.oval(k.body, -0.25, 0, 0.6, 0.34)
            k.ovalPair(k.body, -0.18, 0.32, 0.42, 0.12, -0.3)
            k.oval(k.head, 0.46, 0, 0.29, 0.29)
            k.accent.addPath(BogPainter.ellipse(k.p(-0.3, 0), 0.5 * r, 0.03 * r))
            k.oval(k.accent, -0.3, 0.17, 0.4, 0.025)
            k.oval(k.accent, -0.3, -0.17, 0.4, 0.025)
            k.linePair(k.legs, [(0.2, 0.2), (0.34, 0.44), (0.5, 0.52)])
            k.linePair(k.legs, [(0.02, 0.24), (0.0, 0.5), (-0.1, 0.6)])
            k.linePair(k.legs, [(-0.52, 0.48), (-0.86, 0.34), (-1.0, 0.42)])
            k.linePair(k.antennae, [(-0.82, 0.08), (-1.1, 0.18)])
            k.antennaPair([(0.7, 0.1), (1.06, 0.3), (1.3, 0.7)])
            k.eyePair(0.54, 0.15, 0.16)
            k.oval(k.shine, -0.36, 0.14, 0.3, 0.07, 0.1)
        case .goldenScarab:
            k.oval(k.body, -0.12, 0, 0.7, 0.62)
            k.oval(k.head, 0.46, 0, 0.28, 0.46)
            k.oval(k.head, 0.74, 0, 0.17, 0.25)
            k.poly(k.head, [(0.82, 0.08), (1.1, 0.02), (1.1, -0.02), (0.82, -0.08)])
            k.accent.addRect(CGRect(x: -0.84 * r, y: -0.03 * r, width: 1.06 * r, height: 0.06 * r))
            k.oval(k.accent2, -0.34, 0.3, 0.3, 0.07, 0.25)
            k.oval(k.accent2, -0.34, -0.3, 0.3, 0.07, -0.25)
            k.sixLegs(0.25, spread: 0.8, length: 0.72)
            k.antennaPair([(0.88, 0.14), (0.98, 0.22), (1.04, 0.3)], club: 0.05)
            k.eyePair(0.76, 0.15, 0.13)
            k.oval(k.shine, -0.36, 0.34, 0.3, 0.12, 0.3)
            k.circle(k.shine, 0.4, 0.3, 0.08)
            k.wingPair(-0.36, 0.56, 0.6, 0.25, -0.72)
        case .bee:
            k.oval(k.body, -0.22, 0, 0.62, 0.5)
            k.poly(k.body, [(-0.8, 0.07), (-1.02, 0), (-0.8, -0.07)])
            k.oval(k.head, 0.52, 0, 0.33, 0.35)
            k.band(k.accent, -0.74, -0.6)
            k.band(k.accent, -0.47, -0.33)
            k.band(k.accent, -0.2, -0.08)
            k.oval(k.accent2, 0.12, 0, 0.18, 0.28)
            k.sixLegs(0.1, spread: 0.7, length: 0.7)
            k.antennaPair([(0.78, 0.12), (0.92, 0.2), (0.98, 0.32)], club: 0.05)
            k.eyePair(0.6, 0.17, 0.18)
            k.ovalPair(k.cheeks, 0.48, 0.28, 0.08, 0.06)
            k.oval(k.shine, -0.3, 0.26, 0.24, 0.09, 0.2)
            k.wingPair(-0.12, 0.5, 0.42, 0.24, -0.7)
        case .bumblebee:
            k.oval(k.body, -0.15, 0, 0.7, 0.64)
            k.oval(k.head, 0.6, 0, 0.3, 0.34)
            k.band(k.accent, -0.45, -0.12)
            k.band(k.accent2, -1.0, -0.66)
            k.sixLegs(0.18, spread: 0.65, length: 0.6)
            k.antennaPair([(0.84, 0.12), (0.96, 0.2), (1.0, 0.3)], club: 0.05)
            k.eyePair(0.66, 0.17, 0.16)
            k.ovalPair(k.cheeks, 0.56, 0.27, 0.07, 0.055)
            k.oval(k.shine, -0.2, 0.36, 0.26, 0.1, 0.25)
            k.wingPair(-0.05, 0.56, 0.42, 0.22, -0.7)
        case .wasp:
            k.oval(k.body, -0.48, 0, 0.46, 0.3)
            k.poly(k.body, [(-0.84, 0.15), (-1.1, 0), (-0.84, -0.15)])
            k.oval(k.body, -0.06, 0, 0.09, 0.07)
            k.oval(k.body, 0.12, 0, 0.26, 0.24)
            k.oval(k.head, 0.5, 0, 0.25, 0.28)
            for c in [CGFloat(-0.28), -0.55, -0.82] {
                k.poly(k.accent, [(c + 0.07, 0.4), (c - 0.05, 0), (c + 0.07, -0.4), (c - 0.04, -0.4),
                                  (c - 0.16, 0), (c - 0.04, 0.4)])
            }
            k.oval(k.accent, 0.12, 0, 0.26, 0.24)
            k.oval(k.accent, 0.42, 0, 0.14, 0.28)
            k.ovalPair(k.accent2, 0.14, 0.12, 0.06, 0.05)
            k.sixLegs(0.12, spread: 0.75, length: 0.9)
            k.antennaPair([(0.7, 0.1), (0.9, 0.24), (1.02, 0.36)])
            k.eyePair(0.56, 0.15, 0.15, look: 0.35)
            // Mean brows, slanting down to the front.
            k.polyPair(k.brows, [(0.4, 0.33), (0.74, 0.2), (0.74, 0.13), (0.42, 0.25)])
            k.oval(k.shine, -0.5, 0.17, 0.2, 0.06, 0.15)
            k.wingPair(-0.3, 0.4, 0.56, 0.15, -0.4)
        }
        return k.art(legWidth: legW, outline: ow)
    }

    // MARK: Drawing (pure CoreGraphics; the scene's textures and SwiftUI images use these)

    /// Draws the bug (no wings) centred at the context's origin, y up.
    static func drawBug(_ ctx: CGContext, _ s: BugSpecies, radius: CGFloat) {
        let a = bugArt(s, radius: radius)
        let st = bugStyle(s)
        let ink = outline
        let r = max(radius, 1)
        BogPainter.stroke(ctx, a.legs, ink, width: a.legWidth, 0.95)
        BogPainter.stroke(ctx, a.antennae, ink, width: max(a.legWidth * 0.8, 1), 0.95)
        let sil = CGMutablePath()
        sil.addPath(a.body)
        sil.addPath(a.head)
        BogPainter.stroke(ctx, sil, ink, width: a.outlineWidth * 2, 1)
        if st.fuzzy {
            // A fuzzy fringe: little bumps of body colour over the outline.
            ctx.saveGState()
            ctx.setLineDash(phase: 0, lengths: [max(r * 0.07, 1), max(r * 0.12, 1.6)])
            BogPainter.stroke(ctx, a.body, BogPaint.lighter(st.body, 0.15), width: a.outlineWidth * 2.2, 1)
            ctx.restoreGState()
            BogPainter.stroke(ctx, a.body, ink, width: a.outlineWidth * 0.8, 0.5)
        }
        BogPainter.radialFill(ctx, a.body, [BogPaint.lighter(st.body, 0.45), st.body, BogPaint.darker(st.body, 0.32)],
                              [0, 0.5, 1], center: CGPoint(x: -0.1 * r, y: 0.38 * r), radius: 1.5 * r)
        ctx.saveGState()
        ctx.addPath(sil)
        ctx.clip()
        BogPainter.fill(ctx, a.accent, st.accent)
        BogPainter.fill(ctx, a.accent2, st.accent2)
        ctx.restoreGState()
        BogPainter.radialFill(ctx, a.head, [BogPaint.lighter(st.head, 0.35), st.head, BogPaint.darker(st.head, 0.3)],
                              [0, 0.55, 1], center: CGPoint(x: 0.5 * r, y: 0.3 * r), radius: 0.9 * r)
        if let lantern = a.lantern {
            ctx.saveGState()
            ctx.addPath(a.body)
            ctx.clip()
            BogPainter.radial(ctx, [RGBA(1, 1, 0.85, 0.95), BogPaint.alpha(st.accent, 0.9), BogPaint.alpha(st.accent, 0)],
                              [0, 0.5, 1], center: lantern, radius: 0.32 * r)
            ctx.restoreGState()
        }
        BogPainter.fill(ctx, a.shine, RGBA(1, 1, 1), 0.55)
        BogPainter.fill(ctx, a.cheeks, st.cheek, 0.75)
        BogPainter.fill(ctx, a.eyes, st.eye)
        BogPainter.stroke(ctx, a.eyes, ink, width: max(a.outlineWidth * 0.75, 0.9), 1)
        BogPainter.fill(ctx, a.pupils, st.pupil)
        BogPainter.fill(ctx, a.glints, RGBA(1, 1, 1))
        BogPainter.fill(ctx, a.brows, ink)
    }

    /// Draws the bug's wings (spread) centred at the context's origin, y up.
    static func drawWings(_ ctx: CGContext, _ s: BugSpecies, radius: CGFloat) {
        let a = bugArt(s, radius: radius)
        let st = bugStyle(s)
        guard !a.wings.isEmpty, st.wing.a > 0.01 else { return }
        let r = max(radius, 1)
        BogPainter.stroke(ctx, a.wings, outline, width: max(a.outlineWidth * 0.9, 1), 0.55 * min(st.wing.a * 1.6, 1))
        BogPainter.radialFill(ctx, a.wings, [BogPaint.lighter(st.wing, 0.6), st.wing,
                                             BogPaint.alpha(BogPaint.darker(st.wing, 0.12), st.wing.a * 0.85)],
                              [0, 0.55, 1], center: CGPoint(x: 0.1 * r, y: 0), radius: 1.3 * r)
        BogPainter.fill(ctx, a.wingSpots, st.accent, 0.85)
        BogPainter.stroke(ctx, a.wingVeins, BogPaint.darker(st.wing, 0.35), width: max(r * 0.03, 0.6),
                          min(st.wing.a + 0.2, 0.7))
        // A glassy streak.
        ctx.saveGState()
        ctx.addPath(a.wings)
        ctx.clip()
        BogPainter.linear(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0.45), RGBA(1, 1, 1, 0)], [0.3, 0.45, 0.6],
                          from: CGPoint(x: 0.4 * r, y: 0.8 * r), to: CGPoint(x: -0.6 * r, y: -0.2 * r))
        ctx.restoreGState()
    }

    /// The bug rendered for SwiftUI (Bug Book, Home): wings drawn at `wingSpread` (0 none … 1 spread) under a
    /// fully opaque body, facing +x. Side = `2 × bugExtent(radius:)` points; `scale` pixels per point.
    static func bugImage(_ s: BugSpecies, radius: CGFloat, scale: CGFloat = 3, wingSpread: CGFloat = 0.8,
                         silhouette: Bool = false) -> CGImage? {
        let e = bugExtent(radius: radius)
        return BogPainter.image(width: 2 * e, height: 2 * e, scale: scale) { ctx, sz in
            ctx.translateBy(x: sz.width / 2, y: sz.height / 2)
            if silhouette {
                BogPainter.fill(ctx, bugBody(s, radius: radius), outline, 0.85)
                return
            }
            drawBug(ctx, s, radius: radius)
            if wingSpread > 0.01 {
                ctx.saveGState()
                ctx.scaleBy(x: 1, y: min(max(wingSpread, 0.05), 1))
                drawWings(ctx, s, radius: radius)
                ctx.restoreGState()
            }
        }
    }

    /// A path flipped for a y-down space of `height` (SwiftUI `Shape`).
    static func flippedVertically(_ path: CGPath, height: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addPath(path, transform: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height))
        return p
    }
}
