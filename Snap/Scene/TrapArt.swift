import CoreGraphics
import Foundation

/// The game's colours (ARCHITECTURE "Scene API"): a sunlit bog, a glossy crimson trap, gold nectar.
/// - `bog`, `bogDeep`, `moss`: the bog's greens (mid, darkest, lightest).
/// - `lobeOuter`: the lobe's inner face towards its outer edge (bright crimson-pink).
/// - `lobeInner`: the face by the midrib (deep crimson).
/// - `lobeGloss`: the wet highlight. `rim`: the lime margin and outer skin. `teeth`: the pale cilia.
/// - `nectar`: the drops (translucent amber). `gold`: score pops only (R2: sip rings are lime-white).
/// - `danger`: wasps, stings. `text` / `ink`: light / dark type.
struct SnapPalette: Equatable, Sendable {
    let bog: RGBA
    let bogDeep: RGBA
    let moss: RGBA
    let lobeOuter: RGBA
    let lobeInner: RGBA
    let lobeGloss: RGBA
    let rim: RGBA
    let teeth: RGBA
    let nectar: RGBA
    let gold: RGBA
    let danger: RGBA
    let text: RGBA
    let ink: RGBA
}

/// One cilium (tooth) on a lobe's outer rim, in scene space, as drawn with the trap open.
struct TrapTooth: Equatable, Sendable {
    /// Where it grows from (on the lime margin, just inside the zone's edge).
    var root: CGPoint
    /// The outward direction it points when the trap is open (radians, 0 = +x).
    var angle: CGFloat
    var length: CGFloat
    var width: CGFloat
    /// −1 / +1: which way its tip curls (alternates, for an organic row).
    var curl: CGFloat
}

/// The trap, bugs and nectar drawn with CoreGraphics paths, so SwiftUI (Home, Bug Book, icon) and SpriteKit share one
/// art source. Pure functions: no UIKit, no SpriteKit, no actor isolation (safe in `Shape.path(in:)` and tests).
///
/// Conventions: scene space (points, y up). Lobe and teeth paths are in the scene space of `geometry`. Bug paths are
/// centred at the origin, facing +x, inside a square of half-side `bugExtent(radius:)`.
///
/// **Closure** (`closure01` 0 open … 1 at the snap depth). The scene's still frame agrees with the hands:
/// - each tooth swings over the rim about its root (a 3-D lean seen from above): its projected length is
///   `cos(lean)` with `lean = closure01 × toothMaxLean` — at about 0.75 it points at you, past that it points in;
/// - the lobe foreshortens towards the midrib by up to `lobeSquash` (15 %), as if tilting towards you;
/// - (scene only) a shadow grows in from the outer edges and the gloss slides.
enum TrapArt {
    static let palette = SnapPalette(
        bog: RGBA(hex: 0x1F5E3A),
        bogDeep: RGBA(hex: 0x0C2E1E),
        moss: RGBA(hex: 0x5FA83A),
        lobeOuter: RGBA(hex: 0xD23048),
        lobeInner: RGBA(hex: 0x7A0C26),
        lobeGloss: RGBA(hex: 0xFFD0DC),
        rim: RGBA(hex: 0xB7E34A),
        teeth: RGBA(hex: 0xEAF7B8),
        nectar: RGBA(hex: 0xF5A623),
        gold: RGBA(hex: 0xFFD54A),
        danger: RGBA(hex: 0xFF3B30),
        text: RGBA(hex: 0xFFF8E7),
        ink: RGBA(hex: 0x1E0A10))

    /// The chunky cartoon outline (a warm near-black; the bugs' and the trap's outline).
    static let outline = RGBA(hex: 0x1E0A10)
    /// The lobe's dark green outline against the bog.
    static let lobeOutline = RGBA(hex: 0x123A1C)
    /// R2: the lobe's green back (the exterior band seen beyond the lip) and its shaded edge.
    static let leaf = RGBA(hex: 0x4C9A3C)
    static let leafDark = RGBA(hex: 0x1F5526)
    /// R2: the thin dark-green lip between the crimson face and the green back (no lime rind).
    static let lip = RGBA(hex: 0x1A4720)
    /// R2: how far the green back shows beyond the trap zone's edge (points; the brief's 24–32).
    static let exteriorWidth: CGFloat = 26
    /// R2: the sip ring on a catchable bug (lime-white: gold is kept for nectar and score).
    static let sipRing = RGBA(hex: 0xEEFFC4)
    /// R2: every bug is drawn this much bigger than R1 (Core's `BugInfo.radius` grows by the same factor).
    static let artScale: CGFloat = 1.8
    /// R2: nectar drops are drawn at this fraction of Core's `NectarDrop.radius` (−30 %: the bugs are the subject).
    static let nectarDrawScale: CGFloat = 0.7
    /// R2: a protected bug's ring radius, as a multiple of its art radius.
    static let protectedRingScale: CGFloat = 1.6

    // MARK: Closure

    /// Cilia per lobe.
    static let teethPerSide = 24
    /// The lean (degrees) the teeth reach at `closure01` = 1 (the snap depth).
    static let toothMaxLean: Double = 120
    /// The lean during the jaw slam (the teeth flip right over and interlock).
    static let slamLean: Double = 165
    /// How much the lobe foreshortens towards the midrib at `closure01` = 1 (R2: 3 % → 15 %, so the screen agrees with
    /// the hands).
    static let lobeSquash: CGFloat = 0.15
    /// The slam squeezes each lobe to this x scale towards the midrib for the bite's hold.
    static let slamSqueeze: CGFloat = 0.6
    /// The thin lip's width (points; R1's lime margin was 17).
    static let rimBand: CGFloat = 5
    /// The midrib's half width at its widest (it covers the fold band).
    static let midribHalfWidth: CGFloat = 22

    /// The drawn closure: `snapshot.closure / Tuning.snapDepth`, clamped to 0…1.
    static func closure01(_ closure: Double) -> CGFloat {
        guard closure.isFinite, Tuning.snapDepth > 0 else { return 0 }
        return CGFloat(min(max(closure / Tuning.snapDepth, 0), 1))
    }

    /// The teeth's lean (radians) at a drawn closure.
    static func toothLean(closure01: CGFloat) -> CGFloat {
        let c = min(max(closure01, 0), 1)
        return c * CGFloat(toothMaxLean) * .pi / 180
    }

    /// The projected length factor of a tooth leaning `lean` radians over the rim (1 out, −1 flipped right in). Never
    /// exactly 0 (a sliver stays, so the row never vanishes).
    static func toothReach(lean: CGFloat) -> CGFloat {
        let k = cos(lean)
        if abs(k) < 0.06 { return k < 0 ? -0.06 : 0.06 }
        return k
    }

    // MARK: The lobes

    /// A point on the zone's ellipse at angle `t`, radius fraction `r`, foreshortened towards the midrib by `k`.
    static func ellipsePoint(_ g: TrapGeometry, _ t: CGFloat, _ r: CGFloat = 1, squash k: CGFloat = 1) -> CGPoint {
        CGPoint(x: g.center.x + g.a * cos(t) * r * k, y: g.center.y + g.b * sin(t) * r)
    }

    /// One lobe (side −1 left, +1 right): the half of the trap ellipse on that side of the midrib, closed along the
    /// midrib line. `closure01` foreshortens it towards the midrib by up to `lobeSquash`.
    static func lobePath(side: Int, geometry g: TrapGeometry, closure01: CGFloat) -> CGPath {
        halfEllipse(side: side, geometry: g, radius: 1, squash: 1 - lobeSquash * min(max(closure01, 0), 1))
    }

    /// The lobe's inner (crimson) face: the lobe inset by the lime margin.
    static func lobeFacePath(side: Int, geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        let s: CGFloat = side < 0 ? -1 : 1
        let ia = g.a - rimBand, ib = g.b - rimBand
        let n = 120
        p.move(to: CGPoint(x: g.center.x, y: g.center.y + ib))
        for i in 1...n {
            let t = CGFloat.pi / 2 - CGFloat(i) / CGFloat(n) * .pi
            p.addLine(to: CGPoint(x: g.center.x + s * ia * cos(t), y: g.center.y + ib * sin(t)))
        }
        p.closeSubpath()
        return p
    }

    /// The half ellipse on `side` at radius fraction `radius` (closed along the midrib line).
    static func halfEllipse(side: Int, geometry g: TrapGeometry, radius r: CGFloat, squash k: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let s: CGFloat = side < 0 ? -1 : 1
        let n = 120
        p.move(to: CGPoint(x: g.center.x, y: g.center.y + g.b * r))
        for i in 1...n {
            // From the top (π/2) round the outer side to the bottom (−π/2), mirrored by `s`.
            let t = CGFloat.pi / 2 - CGFloat(i) / CGFloat(n) * .pi
            p.addLine(to: CGPoint(x: g.center.x + s * g.a * r * k * cos(t), y: g.center.y + g.b * r * sin(t)))
        }
        p.closeSubpath()
        return p
    }

    /// The half ellipse on `side` with semi-axes `rx`, `ry` about the trap centre (closed along the midrib line): the
    /// green back is a constant-width band, so it can't be a radius fraction.
    static func halfEllipse(side: Int, geometry g: TrapGeometry, rx: CGFloat, ry: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let s: CGFloat = side < 0 ? -1 : 1
        let n = 120
        p.move(to: CGPoint(x: g.center.x, y: g.center.y + ry))
        for i in 1...n {
            let t = CGFloat.pi / 2 - CGFloat(i) / CGFloat(n) * .pi
            p.addLine(to: CGPoint(x: g.center.x + s * rx * cos(t), y: g.center.y + ry * sin(t)))
        }
        p.closeSubpath()
        return p
    }

    /// The lobe's green back: the half ellipse `exteriorWidth` beyond the zone's edge.
    static func exteriorPath(side: Int, geometry g: TrapGeometry) -> CGPath {
        halfEllipse(side: side, geometry: g, rx: g.a + exteriorWidth, ry: g.b + exteriorWidth)
    }

    /// The midrib (the trap's hinge, on the fold band): a lens from the top of the zone to the bottom.
    static func midribPath(geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        let cx = g.center.x, top = g.center.y + g.b - 4, bottom = g.center.y - g.b + 4
        let w = midribHalfWidth
        p.move(to: CGPoint(x: cx, y: top))
        p.addCurve(to: CGPoint(x: cx, y: bottom), control1: CGPoint(x: cx + w * 1.32, y: top - g.b * 0.45),
                   control2: CGPoint(x: cx + w * 1.32, y: bottom + g.b * 0.45))
        p.addCurve(to: CGPoint(x: cx, y: top), control1: CGPoint(x: cx - w * 1.32, y: bottom + g.b * 0.45),
                   control2: CGPoint(x: cx - w * 1.32, y: top - g.b * 0.45))
        p.closeSubpath()
        return p
    }

    /// The veins radiating from the midrib across one lobe's face (a path to stroke).
    static func veinsPath(side: Int, geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        let s: CGFloat = side < 0 ? -1 : 1
        let n = 11
        for i in 0..<n {
            let u = (CGFloat(i) + 0.5) / CGFloat(n)            // 0 top … 1 bottom
            let t = CGFloat.pi / 2 - u * .pi                    // the vein's end angle on the face edge
            let startY = g.center.y + g.b * 0.78 * (1 - 2 * u)
            let start = CGPoint(x: g.center.x + s * midribHalfWidth * 0.6, y: startY)
            let end = ellipsePoint(g, t, 0.9)
            let endX = g.center.x + s * abs(end.x - g.center.x)
            let ctrl = CGPoint(x: g.center.x + s * abs(end.x - g.center.x) * 0.45,
                               y: startY + (end.y - startY) * 0.25)
            p.move(to: start)
            p.addQuadCurve(to: CGPoint(x: endX, y: end.y), control: ctrl)
            // A small side branch on every other vein.
            if i % 2 == 1 {
                let mid = CGPoint(x: g.center.x + s * abs(end.x - g.center.x) * 0.55,
                                  y: startY + (end.y - startY) * 0.5)
                let bt = t + (u < 0.5 ? 0.12 : -0.12)
                let bEnd = ellipsePoint(g, bt, 0.82)
                p.move(to: mid)
                p.addQuadCurve(to: CGPoint(x: g.center.x + s * abs(bEnd.x - g.center.x), y: bEnd.y),
                               control: CGPoint(x: g.center.x + s * abs(bEnd.x - g.center.x) * 0.8,
                                                y: mid.y + (bEnd.y - mid.y) * 0.3))
            }
        }
        return p
    }

    /// The three trigger hairs on a lobe (scene space): a loose triangle in the middle of the face.
    static func triggerHairs(side: Int, geometry g: TrapGeometry) -> [CGPoint] {
        let s: CGFloat = side < 0 ? -1 : 1
        let spots: [(CGFloat, CGFloat)] = [(0.36, 0.34), (0.58, -0.04), (0.32, -0.40)]
        return spots.map { CGPoint(x: g.center.x + s * g.a * $0.0, y: g.center.y + g.b * $0.1) }
    }

    /// The rim's start (normalised radius `TrapGeometry.rimStart`) on one lobe: points for the row of tiny glands
    /// that marks where bugs are "half in".
    static func rimGlands(side: Int, geometry g: TrapGeometry) -> [CGPoint] {
        let s: CGFloat = side < 0 ? -1 : 1
        let n = 34
        let r = CGFloat(TrapGeometry.rimStart)
        return (0..<n).map { i -> CGPoint in
            let t = CGFloat.pi / 2 - (CGFloat(i) + 0.5) / CGFloat(n) * .pi
            return CGPoint(x: g.center.x + s * g.a * r * cos(t), y: g.center.y + g.b * r * sin(t))
        }
    }

    // MARK: The teeth

    /// The cilia on one lobe, evenly spaced by arc length along the outer rim from near the top of the midrib, round
    /// the outer side, to near its bottom. Longest at the outer middle, shorter towards the midrib's ends.
    static func teeth(side: Int, geometry g: TrapGeometry) -> [TrapTooth] {
        let s: CGFloat = side < 0 ? -1 : 1
        let gap: CGFloat = 0.17
        let t0 = CGFloat.pi / 2 - gap, t1 = -CGFloat.pi / 2 + gap   // the right side, top to bottom
        let samples = 400
        var pts: [CGPoint] = []
        var cum: [CGFloat] = [0]
        pts.reserveCapacity(samples + 1)
        for i in 0...samples {
            let t = t0 + (t1 - t0) * CGFloat(i) / CGFloat(samples)
            let q = CGPoint(x: g.a * cos(t), y: g.b * sin(t))
            if let last = pts.last {
                let dx = q.x - last.x, dy = q.y - last.y
                cum.append(cum[cum.count - 1] + (dx * dx + dy * dy).squareRoot())
            }
            pts.append(q)
        }
        let total = cum[cum.count - 1]
        let n = teethPerSide
        var out: [TrapTooth] = []
        out.reserveCapacity(n)
        var j = 0
        for i in 0..<n {
            let u = (CGFloat(i) + 0.5) / CGFloat(n)
            let target = u * total
            while j < samples - 1 && cum[j + 1] < target { j += 1 }
            let seg = max(cum[j + 1] - cum[j], 0.0001)
            let f = (target - cum[j]) / seg
            let tt = t0 + (t1 - t0) * (CGFloat(j) + f) / CGFloat(samples)
            // The outward normal of the ellipse (the gradient), mirrored for the left side.
            var nx = cos(tt) / g.a, ny = sin(tt) / g.b
            let len = max((nx * nx + ny * ny).squareRoot(), 0.000001)
            nx /= len
            ny /= len
            let rootR: CGFloat = 0.985
            let root = CGPoint(x: g.center.x + s * g.a * rootR * cos(tt), y: g.center.y + g.b * rootR * sin(tt))
            let angle = atan2(ny, s * nx)
            let bulge = sin(CGFloat.pi * u)
            // R2: cilia, not spikes: 1.5 × longer and 40 % thinner than R1, the tip kept 4 pt inside the canvas.
            var length: CGFloat = 30 + 33 * bulge
            let dx = cos(angle), dy = sin(angle)
            let margin: CGFloat = 4
            if dx < -0.0001 { length = min(length, (root.x - margin) / -dx) }
            if dx > 0.0001 { length = min(length, (g.sceneSize.width - margin - root.x) / dx) }
            if dy < -0.0001 { length = min(length, (root.y - margin) / -dy) }
            if dy > 0.0001 { length = min(length, (g.sceneSize.height - margin - root.y) / dy) }
            length = max(length, 18)
            out.append(TrapTooth(root: root, angle: angle, length: length, width: (8.5 + 3 * bulge) * 0.6,
                                 curl: i % 2 == 0 ? 1 : -1))
        }
        return out
    }

    /// One tooth in its own frame: root at the origin (tucked 3 pt under the rim), pointing +y, `length` long.
    static func toothShape(length L: CGFloat, width w: CGFloat, curl: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let h = w / 2
        let tipX = curl * L * 0.12
        p.move(to: CGPoint(x: -h, y: -3))
        p.addCurve(to: CGPoint(x: tipX - 0.7, y: L - 0.6), control1: CGPoint(x: -h * 0.9, y: L * 0.35),
                   control2: CGPoint(x: tipX * 0.6 - h * 0.25, y: L * 0.75))
        p.addQuadCurve(to: CGPoint(x: tipX + 0.7, y: L - 0.6), control: CGPoint(x: tipX, y: L + 0.8))
        p.addCurve(to: CGPoint(x: h, y: -3), control1: CGPoint(x: tipX * 0.6 + h * 0.25, y: L * 0.75),
                   control2: CGPoint(x: h * 0.9, y: L * 0.35))
        p.closeSubpath()
        return p
    }

    /// The transform that places a tooth (`toothShape`) on the rim at a lean, with the lobe foreshortened by `squash`.
    static func toothTransform(_ tooth: TrapTooth, geometry g: TrapGeometry, lean: CGFloat,
                               squash k: CGFloat) -> CGAffineTransform {
        let root = CGPoint(x: g.center.x + (tooth.root.x - g.center.x) * k, y: tooth.root.y)
        return CGAffineTransform(translationX: root.x, y: root.y)
            .rotated(by: tooth.angle - .pi / 2)
            .scaledBy(x: 1, y: toothReach(lean: lean))
    }

    /// Every tooth on one lobe at `closure01` (they lean over the rim as it grows; see the type's notes).
    static func teethPath(side: Int, geometry g: TrapGeometry, closure01: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let c = min(max(closure01, 0), 1)
        let lean = toothLean(closure01: c)
        let k = 1 - lobeSquash * c
        for tooth in teeth(side: side, geometry: g) {
            let shape = toothShape(length: tooth.length, width: tooth.width, curl: tooth.curl)
            p.addPath(shape, transform: toothTransform(tooth, geometry: g, lean: lean, squash: k))
        }
        return p
    }
}
