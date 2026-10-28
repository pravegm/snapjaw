import CoreGraphics
import Foundation

/// The game's colours (ARCHITECTURE "Scene API"): a sunlit bog, a glossy crimson trap, gold nectar.
/// - `bog`, `bogDeep`, `moss`: the bog's greens (mid, darkest, lightest).
/// - `lobeOuter`: the lobe's face towards the margin (crimson, R3 ≤ #C42A45).
/// - `lobeInner`: the face by the midrib (oxblood, R3 ≤ #9A1A33).
/// - `lobeGloss`: the wet highlight. `rim`: a lime accent (UI). `teeth`: the cilia's cream tips.
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

/// One cilium (tooth) on a lobe's outer margin, in scene space, as drawn with the trap open.
struct TrapTooth: Equatable, Sendable {
    /// Where it grows from (on the margin, at the lobe's thin green back).
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
/// **R3: a Venus flytrap seen from above** (the founder's art direction), never a fruit slice:
/// - two distinct clam-shaped lobes hinged on a midrib seam; the margins dip at the midrib's ends (`notchDepth`) and a
///   narrow dark gap parts the lobes' inner edges there (`seamGap`), so it reads as two leaves, not one ellipse;
/// - no rind: an oxblood → crimson face with a yellow-green blush only in the last ~10 % before the margin, and the
///   leaf's back only as a thin dark-green lip (`exteriorWidth`) that the cilia grow from;
/// - long, thin, slightly curved cilia (`teethPerSide` × 2 = 76), pale green to cream;
/// - a green petiole from the bottom of the midrib into the bog (`BogArt.drawPetiole`).
///
/// Conventions: scene space (points, y up). Lobe and teeth paths are in the scene space of `geometry`. Bug paths are
/// centred at the origin, facing +x, inside a square of half-side `bugExtent(radius:)`.
///
/// **Closure** (`closure01` 0 open … 1 at the snap depth). The scene's still frame agrees with the hands:
/// - each tooth swings over the margin about its root (a 3-D lean seen from above): its projected length is
///   `cos(lean)` with `lean = closure01 × toothMaxLean` — at about 0.75 it points at you, past that it points in;
/// - the lobe foreshortens towards the midrib by up to `lobeSquash` (15 %), as if tilting towards you;
/// - (scene only) a shadow grows in from the outer edges and the gloss slides.
///
/// **The bite** (R3 #1): the lobes squeeze to `slamSqueeze` about the midrib, the margins meet over a dark interior and
/// the cilia interlock across the seam (`closedTrapPath`, `BogArt.drawClosedTrap`). Nothing is ever drawn outside the
/// open trap's outline.
enum TrapArt {
    static let palette = SnapPalette(
        bog: RGBA(hex: 0x1F5E3A),
        bogDeep: RGBA(hex: 0x0C2E1E),
        moss: RGBA(hex: 0x5FA83A),
        lobeOuter: RGBA(hex: 0xC02A42),
        lobeInner: RGBA(hex: 0x5C0B1E),
        lobeGloss: RGBA(hex: 0xFFD0DC),
        rim: RGBA(hex: 0xB7E34A),
        teeth: RGBA(hex: 0xF4EFC6),
        nectar: RGBA(hex: 0xF5A623),
        gold: RGBA(hex: 0xFFD54A),
        danger: RGBA(hex: 0xFF3B30),
        text: RGBA(hex: 0xFFF8E7),
        ink: RGBA(hex: 0x1E0A10))

    /// The chunky cartoon outline (a warm near-black; the bugs' outline).
    static let outline = RGBA(hex: 0x1E0A10)
    /// The lobe's dark green outline against the bog.
    static let lobeOutline = RGBA(hex: 0x10301A)
    /// R3: the crimson core of the face (between the oxblood midrib and the crimson margin).
    static let lobeCore = RGBA(hex: 0x9A1A33)
    /// R4 (#5): the oxblood the face starts from at the midrib; the face runs from it to `palette.lobeOuter` across the
    /// whole lobe.
    static let lobeMidrib = RGBA(hex: 0x892934)
    /// R4 (#5): the yellow-green blush, only in the last `blushStart`…1 of the face's radius, at most `blushAlpha`.
    static let blush = RGBA(hex: 0xB8C25A)
    static let blushAlpha: Double = 0.38
    static let blushStart: CGFloat = 0.905
    /// R4 (#5): the face's stops by distance from the midrib (0 on it … 1 at the margin), as drawn under the blush.
    static let faceStops: [(CGFloat, RGBA)] = [
        (0, RGBA(hex: 0x6E1426)), (0.16, RGBA(hex: 0x892934)), (0.5, RGBA(hex: 0xA22239)),
        (0.8, RGBA(hex: 0xB6273F)), (0.92, RGBA(hex: 0xC02A42)), (1, RGBA(hex: 0xA42440)),
    ]
    /// R3: the leaf's back, seen only as a thin lip beyond the margin, and its shaded edge.
    static let leaf = RGBA(hex: 0x2F5F2B)
    static let leafDark = RGBA(hex: 0x173D19)
    /// R4 (#6): the closed trap's lobes, from the outer edge (0) to the seam (1): leaf green over the outer ~70 %
    /// (darker at the edge, lit on the bulge), crimson only in the last ~22 % by the seam, then the dark interior.
    static let closedStops: [(CGFloat, RGBA)] = [
        (0, RGBA(hex: 0x173D19)), (0.18, RGBA(hex: 0x2F5F2B)), (0.45, RGBA(hex: 0x41763A)),
        (0.66, RGBA(hex: 0x2F5F2B)), (0.76, RGBA(hex: 0x5A2A22)), (0.82, RGBA(hex: 0x9A1A33)),
        (0.9, RGBA(hex: 0xC02A42)), (0.96, RGBA(hex: 0x5C0B1E)), (1, RGBA(hex: 0x1C0309)),
    ]
    /// Where the crimson starts on the closed lobe (fraction from the outer edge towards the seam; tests).
    static let closedCrimsonFrom: CGFloat = 0.76

    /// The thin green lip between the face and the back (no lime rind; R4: a touch more leaf so the margin reads green).
    static let lip = RGBA(hex: 0x2E5A22)
    /// R3: the cilia, from a green base to a cream tip (`palette.teeth`).
    static let ciliaBase = RGBA(hex: 0x6A9A40)
    static let ciliaMid = RGBA(hex: 0xCFE39A)
    /// R3: the dark interior (the seam's gap, the closed trap's inside).
    static let interior = RGBA(hex: 0x1C0309)
    /// R3: the petiole (the leaf stalk into the bog).
    static let petiole = RGBA(hex: 0x4E9338)
    /// How far the leaf's back shows beyond the margin (R3: a thin lip, not a band).
    static let exteriorWidth: CGFloat = 9
    /// R2: the sip ring on a catchable bug (lime-white: gold is kept for nectar and score).
    static let sipRing = RGBA(hex: 0xEEFFC4)
    /// R2: every bug is drawn this much bigger than R1 (Core's `BugInfo.radius` grows by the same factor).
    static let artScale: CGFloat = 1.8
    /// R2: nectar drops are drawn at this fraction of Core's `NectarDrop.radius` (−30 %: the bugs are the subject).
    static let nectarDrawScale: CGFloat = 0.7
    /// R2: a protected bug's ring radius, as a multiple of its art radius.
    static let protectedRingScale: CGFloat = 1.6

    // MARK: The lobes' shape

    /// R3: how far the margin dips at each end of the midrib (points), and the dip's half-width.
    static let notchDepth: CGFloat = 40
    static let notchWidth: CGFloat = 56
    /// R3: how far each lobe's inner edge parts from the midrib line at its ends (points; 0 in the middle).
    static let seamGap: CGFloat = 7

    // MARK: Closure

    /// Cilia per lobe (R3: 60–80 in total).
    static let teethPerSide = 38
    /// The lean (degrees) the teeth reach at `closure01` = 1 (the snap depth).
    static let toothMaxLean: Double = 120
    /// The lean during the jaw slam (the teeth flip right over).
    static let slamLean: Double = 165
    /// How much the lobe foreshortens towards the midrib at `closure01` = 1 (R2: 3 % → 15 %, so the screen agrees with
    /// the hands).
    static let lobeSquash: CGFloat = 0.15
    /// R3: the bite squeezes each lobe to this x scale about the midrib (the margins meet; the closed trap).
    static let slamSqueeze: CGFloat = 0.3
    /// The thin lip's width inside the margin (points).
    static let rimBand: CGFloat = 4
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

    // MARK: R8 closing cues (hinge input: the phone IS the trap)

    /// R8: with the hinge the lobes are always drawn open; the closing shows as cues that follow the closure
    /// (degrees from the open reference, 0 … about 150 at the shut). They start at `cueStart` (under the hinge's
    /// noise) and are full at `cueFull`: subtle at 10°, strong at 80°, the edges near-black by 120°.
    static let cueStart: Double = 3
    static let cueFull: Double = 120
    /// R8: the cilia's lean at a full cue (degrees: just past pointing at you, so they read as leaning in).
    static let cueLean: Double = 100
    /// R8: the rim shadow's alpha and the edge dim's alpha at a full cue.
    static let rimShadowMax: CGFloat = 0.9
    static let edgeDimMax: CGFloat = 0.96
    /// R8: how fast the bugs' panic rises with the cue (full by a cue of 1 / `panicGain`, about 87°).
    static let panicGain: CGFloat = 1.4

    /// R8: the closing cue (0 open … 1 at `cueFull`), linear in the closure.
    static func closingCue(_ closure: Double) -> CGFloat {
        guard closure.isFinite, cueFull > cueStart else { return 0 }
        return CGFloat(min(max((closure - cueStart) / (cueFull - cueStart), 0), 1))
    }

    /// R8: the cilia's lean (radians) at closing cue `cue`.
    static func cueLeanAngle(_ cue: CGFloat) -> CGFloat {
        let c = cue.isFinite ? min(max(cue, 0), 1) : 0
        return c * CGFloat(cueLean) * .pi / 180
    }

    /// R8: the rim shadow on the lobes at closing cue `cue`.
    static func rimShadow(_ cue: CGFloat) -> CGFloat {
        rimShadowMax * (cue.isFinite ? min(max(cue, 0), 1) : 0)
    }

    /// R8: the edge dim's alpha at closing cue `cue` (its texture is opaque at the edges).
    static func edgeDim(_ cue: CGFloat) -> CGFloat {
        edgeDimMax * (cue.isFinite ? min(max(cue, 0), 1) : 0)
    }

    /// R8: how hard the bugs in the trap panic (buzz and jitter) at closing cue `cue` (0 calm … 1).
    static func panicLevel(_ cue: CGFloat) -> CGFloat {
        cue.isFinite ? min(max(cue * panicGain, 0), 1) : 0
    }

    // MARK: The lobes

    /// A point on the zone's ellipse at angle `t`, radius fraction `r`, foreshortened towards the midrib by `k`.
    static func ellipsePoint(_ g: TrapGeometry, _ t: CGFloat, _ r: CGFloat = 1, squash k: CGFloat = 1) -> CGPoint {
        CGPoint(x: g.center.x + g.a * cos(t) * r * k, y: g.center.y + g.b * sin(t) * r)
    }

    /// The notch's weight at `x` points from the midrib: 1 on it, falling off over `notchWidth`.
    static func notchWeight(_ x: CGFloat) -> CGFloat {
        let u = x / notchWidth
        return exp(-u * u)
    }

    /// A point on lobe `side`'s margin at angle `t` (π/2 the top of the midrib, 0 the outer middle, −π/2 its bottom)
    /// for semi-axes `a`, `b`, foreshortened towards the midrib by `k`. The margin dips by `notchDepth` and parts by
    /// `gap` at the midrib's ends: a clam shape, not a half ellipse.
    static func marginPoint(_ g: TrapGeometry, side: Int, t: CGFloat, a: CGFloat, b: CGFloat, squash k: CGFloat = 1,
                            gap: CGFloat = TrapArt.seamGap) -> CGPoint {
        let s: CGFloat = side < 0 ? -1 : 1
        let c = max(cos(t), 0), sn = sin(t)
        let x0 = a * c
        let w = notchWeight(x0)
        let x = (x0 + gap * w * abs(sn)) * k
        let y = (b - notchDepth * w) * sn
        return CGPoint(x: g.center.x + s * x, y: g.center.y + y)
    }

    /// R3: one lobe's outline (side −1 left, +1 right), `inset` points inside the margin (negative: outside it),
    /// foreshortened towards the midrib by `k`. The inner edge runs along the midrib: the lobes touch in the middle
    /// and part at the ends. `semiAxisX` replaces the lobe's width (the closed trap: a narrower lobe with the same
    /// notch and seam, so it lies inside the open one point for point).
    static func lobeShape(side: Int, geometry g: TrapGeometry, inset: CGFloat = 0, squash k: CGFloat = 1,
                            semiAxisX: CGFloat? = nil) -> CGPath {
        let s: CGFloat = side < 0 ? -1 : 1
        let a = max(semiAxisX ?? (g.a - inset), 10), b = max(g.b - inset, 10)
        let gap = seamGap + max(inset, 0) * 0.6
        let n = 160
        let p = CGMutablePath()
        let top = marginPoint(g, side: side, t: .pi / 2, a: a, b: b, squash: k, gap: gap)
        p.move(to: top)
        for i in 1...n {
            let t = CGFloat.pi / 2 - CGFloat(i) / CGFloat(n) * .pi
            p.addLine(to: marginPoint(g, side: side, t: t, a: a, b: b, squash: k, gap: gap))
        }
        p.addQuadCurve(to: top, control: CGPoint(x: g.center.x - s * gap * k, y: g.center.y))
        p.closeSubpath()
        return p
    }

    /// R3: the margin alone, an open curve from the top of the midrib round the outer side to its bottom, `inset`
    /// points inside (the blush and the rim light are strokes along it, never along the midrib).
    static func marginCurve(side: Int, geometry g: TrapGeometry, inset: CGFloat = 0, squash k: CGFloat = 1) -> CGPath {
        let a = max(g.a - inset, 10), b = max(g.b - inset, 10)
        let gap = seamGap + max(inset, 0) * 0.6
        let n = 160
        let p = CGMutablePath()
        p.move(to: marginPoint(g, side: side, t: .pi / 2, a: a, b: b, squash: k, gap: gap))
        for i in 1...n {
            let t = CGFloat.pi / 2 - CGFloat(i) / CGFloat(n) * .pi
            p.addLine(to: marginPoint(g, side: side, t: t, a: a, b: b, squash: k, gap: gap))
        }
        return p
    }

    /// One lobe's margin outline: `closure01` foreshortens it towards the midrib by up to `lobeSquash`.
    static func lobePath(side: Int, geometry g: TrapGeometry, closure01: CGFloat) -> CGPath {
        lobeShape(side: side, geometry: g, inset: 0, squash: 1 - lobeSquash * min(max(closure01, 0), 1))
    }

    /// The lobe's crimson face: the lobe inset by the thin lip.
    static func lobeFacePath(side: Int, geometry g: TrapGeometry) -> CGPath {
        lobeShape(side: side, geometry: g, inset: rimBand)
    }

    /// The half ellipse on `side` at radius fraction `radius` (closed along the midrib line).
    static func halfEllipse(side: Int, geometry g: TrapGeometry, radius r: CGFloat, squash k: CGFloat) -> CGPath {
        halfEllipse(side: side, geometry: g, rx: g.a * r * k, ry: g.b * r)
    }

    /// The half ellipse on `side` with semi-axes `rx`, `ry` about the trap centre (closed along the midrib line).
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

    /// The lobe's back: the thin dark-green lip `exteriorWidth` beyond the margin.
    static func exteriorPath(side: Int, geometry g: TrapGeometry) -> CGPath {
        lobeShape(side: side, geometry: g, inset: -exteriorWidth)
    }

    /// R3: the closed trap (the bite's hold): both lobes, backs included, `slamSqueeze` of their open width about the
    /// midrib, with the same notches and seam. It lies inside the open trap's outline point for point.
    static func closedTrapPath(geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        for side in [-1, 1] { p.addPath(closedLobePath(side: side, geometry: g, inset: -exteriorWidth)) }
        return p
    }

    /// One closed lobe, `inset` points inside its margin (negative: its back).
    static func closedLobePath(side: Int, geometry g: TrapGeometry, inset: CGFloat) -> CGPath {
        lobeShape(side: side, geometry: g, inset: inset, semiAxisX: (g.a - inset) * slamSqueeze)
    }

    /// The midrib (the trap's hinge, on the fold band): a lens down the seam, ending inside the notches.
    static func midribPath(geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        let half = g.b - notchDepth + 2
        let cx = g.center.x, top = g.center.y + half, bottom = g.center.y - half
        let w = midribHalfWidth
        p.move(to: CGPoint(x: cx, y: top))
        p.addCurve(to: CGPoint(x: cx, y: bottom), control1: CGPoint(x: cx + w * 1.32, y: top - half * 0.45),
                   control2: CGPoint(x: cx + w * 1.32, y: bottom + half * 0.45))
        p.addCurve(to: CGPoint(x: cx, y: top), control1: CGPoint(x: cx - w * 1.32, y: bottom + half * 0.45),
                   control2: CGPoint(x: cx - w * 1.32, y: top - half * 0.45))
        p.closeSubpath()
        return p
    }

    /// R3: the narrow dark gap between the two lobes' inner edges (widest at the midrib's ends, closed in the middle).
    static func seamGapPath(geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        let cx = g.center.x, cy = g.center.y
        let h = g.b - notchDepth
        let gap = seamGap + 1
        p.move(to: CGPoint(x: cx - gap, y: cy + h))
        p.addQuadCurve(to: CGPoint(x: cx - gap, y: cy - h), control: CGPoint(x: cx + gap, y: cy))
        p.addLine(to: CGPoint(x: cx + gap, y: cy - h))
        p.addQuadCurve(to: CGPoint(x: cx + gap, y: cy + h), control: CGPoint(x: cx - gap, y: cy))
        p.closeSubpath()
        return p
    }

    /// The fine veins radiating from the midrib across one lobe's face (a path to stroke).
    static func veinsPath(side: Int, geometry g: TrapGeometry) -> CGPath {
        let p = CGMutablePath()
        let s: CGFloat = side < 0 ? -1 : 1
        let n = 17
        let h = g.b - notchDepth
        for i in 0..<n {
            let u = (CGFloat(i) + 0.5) / CGFloat(n)            // 0 top … 1 bottom
            let t = CGFloat.pi / 2 * 0.94 - u * .pi * 0.94      // the vein's end angle on the margin
            let startY = g.center.y + h * 0.92 * (1 - 2 * u)
            let start = CGPoint(x: g.center.x + s * midribHalfWidth * 0.5, y: startY)
            let end = marginPoint(g, side: side, t: t, a: g.a * 0.93, b: g.b * 0.93)
            let ctrl = CGPoint(x: g.center.x + (end.x - g.center.x) * 0.5, y: startY + (end.y - startY) * 0.2)
            p.move(to: start)
            p.addQuadCurve(to: end, control: ctrl)
            // A small side branch on every other vein.
            if i % 2 == 1 {
                let mid = CGPoint(x: g.center.x + (end.x - g.center.x) * 0.52, y: startY + (end.y - startY) * 0.42)
                let bt = t + (u < 0.5 ? 0.1 : -0.1)
                let bEnd = marginPoint(g, side: side, t: bt, a: g.a * 0.86, b: g.b * 0.86)
                p.move(to: mid)
                p.addQuadCurve(to: bEnd, control: CGPoint(x: g.center.x + (bEnd.x - g.center.x) * 0.8,
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

    /// The rim's start (normalised radius `TrapGeometry.rimStart`) on one lobe: where bugs are "half in" (R3: the
    /// blush begins about here; the points are no longer drawn as pale dots).
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

    /// The cilia on one lobe, evenly spaced by arc length along the margin from near the top of the midrib, round the
    /// outer side, to near its bottom. Longest at the outer middle, shorter towards the midrib's ends.
    /// R6: `variety` scales their length and width (`TrapLook.toothLength/toothWidth`), and the tips stay 4 pt inside
    /// the canvas with the lobe drawn `TrapLook.spread` wider about the midrib (B52).
    static func teeth(side: Int, geometry g: TrapGeometry, variety: TrapVariety = .classic) -> [TrapTooth] {
        let vl = look(variety)
        let lf = vl.toothLength, wf = vl.toothWidth, spread = max(vl.spread, 0.5)
        let s: CGFloat = side < 0 ? -1 : 1
        let gapT: CGFloat = 0.22
        let t0 = CGFloat.pi / 2 - gapT, t1 = -CGFloat.pi / 2 + gapT   // the right side, top to bottom
        let samples = 480
        var pts: [CGPoint] = []
        var cum: [CGFloat] = [0]
        pts.reserveCapacity(samples + 1)
        for i in 0...samples {
            let t = t0 + (t1 - t0) * CGFloat(i) / CGFloat(samples)
            let m = marginPoint(g, side: 1, t: t, a: g.a, b: g.b)
            let q = CGPoint(x: m.x - g.center.x, y: m.y - g.center.y)
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
            let f = min(max((target - cum[j]) / seg, 0), 1)
            let q = CGPoint(x: pts[j].x + (pts[j + 1].x - pts[j].x) * f, y: pts[j].y + (pts[j + 1].y - pts[j].y) * f)
            // The outward normal (the tangent turned a quarter clockwise: the right side runs top to bottom).
            let tx = pts[j + 1].x - pts[j].x, ty = pts[j + 1].y - pts[j].y
            let tl = max((tx * tx + ty * ty).squareRoot(), 0.000001)
            let nx = -ty / tl, ny = tx / tl
            let rootR: CGFloat = 0.99
            let root = CGPoint(x: g.center.x + s * q.x * rootR, y: g.center.y + q.y * rootR)
            let angle = atan2(ny, s * nx)
            let bulge = sin(CGFloat.pi * u)
            // R3: long, thin cilia (60–80 in all), the tip kept 4 pt inside the canvas.
            let base: CGFloat = (34 + 30 * bulge) * lf
            var length = base
            let dx = cos(angle), dy = sin(angle)
            let margin: CGFloat = 4
            // (x in the drawn, spread frame: the root and the tip are both scaled about the centre.)
            let relX = root.x - g.center.x
            if dx < -0.0001 { length = min(length, (relX + (g.center.x - margin) / spread) / -dx) }
            if dx > 0.0001 { length = min(length, ((g.sceneSize.width - margin - g.center.x) / spread - relX) / dx) }
            if dy < -0.0001 { length = min(length, (root.y - margin) / -dy) }
            if dy > 0.0001 { length = min(length, (g.sceneSize.height - margin - root.y) / dy) }
            length = max(length, min(18, base))
            out.append(TrapTooth(root: root, angle: angle, length: length, width: (3.6 + 1.1 * bulge) * wf,
                                 curl: i % 2 == 0 ? 1 : -1))
        }
        return out
    }

    /// One tooth in its own frame: root at the origin (tucked 3 pt under the margin), pointing +y, `length` long,
    /// tapering to a fine tip that curls a little.
    static func toothShape(length L: CGFloat, width w: CGFloat, curl: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let h = w / 2
        let tipX = curl * L * 0.09
        p.move(to: CGPoint(x: -h, y: -3))
        p.addCurve(to: CGPoint(x: tipX - 0.45, y: L - 0.5), control1: CGPoint(x: -h * 0.8, y: L * 0.4),
                   control2: CGPoint(x: tipX * 0.7 - h * 0.2, y: L * 0.8))
        p.addQuadCurve(to: CGPoint(x: tipX + 0.45, y: L - 0.5), control: CGPoint(x: tipX, y: L + 0.6))
        p.addCurve(to: CGPoint(x: h, y: -3), control1: CGPoint(x: tipX * 0.7 + h * 0.2, y: L * 0.8),
                   control2: CGPoint(x: h * 0.8, y: L * 0.4))
        p.closeSubpath()
        return p
    }

    /// The transform that places a tooth (`toothShape`) on the margin at a lean, with the lobe foreshortened by `squash`.
    static func toothTransform(_ tooth: TrapTooth, geometry g: TrapGeometry, lean: CGFloat,
                               squash k: CGFloat) -> CGAffineTransform {
        let root = CGPoint(x: g.center.x + (tooth.root.x - g.center.x) * k, y: tooth.root.y)
        return CGAffineTransform(translationX: root.x, y: root.y)
            .rotated(by: tooth.angle - .pi / 2)
            .scaledBy(x: 1, y: toothReach(lean: lean))
    }

    /// Every tooth on one lobe at `closure01` (they lean over the margin as it grows; see the type's notes).
    static func teethPath(side: Int, geometry g: TrapGeometry, closure01: CGFloat,
                          variety: TrapVariety = .classic) -> CGPath {
        let p = CGMutablePath()
        let c = min(max(closure01, 0), 1)
        let lean = toothLean(closure01: c)
        let k = 1 - lobeSquash * c
        let kind = look(variety).tooth
        let spread = spreadTransform(variety, geometry: g)
        for tooth in teeth(side: side, geometry: g, variety: variety) {
            let shape = toothShape(length: tooth.length, width: tooth.width, curl: tooth.curl, kind: kind)
            p.addPath(shape, transform: toothTransform(tooth, geometry: g, lean: lean, squash: k).concatenating(spread))
        }
        return p
    }

    /// R3: the closed trap's interlocking cilia (scene space): each lobe's cilia cross the seam from its own margin,
    /// alternating with the other lobe's, like laced fingers. (root, angle, length) per cilium.
    static func interlockedCilia(geometry g: TrapGeometry) -> [(root: CGPoint, angle: CGFloat, length: CGFloat,
                                                                 curl: CGFloat)] {
        var out: [(root: CGPoint, angle: CGFloat, length: CGFloat, curl: CGFloat)] = []
        let h = g.b - notchDepth - 18
        let n = 24
        let step = 2 * h / CGFloat(n)
        for side in [-1, 1] {
            let s = CGFloat(side)
            for i in 0..<n {
                let y = g.center.y + h - step * (CGFloat(i) + (side < 0 ? 0.25 : 0.75))
                let u = (y - (g.center.y - h)) / (2 * h)
                let bulge = sin(CGFloat.pi * min(max(u, 0), 1))
                let root = CGPoint(x: g.center.x + s * 9, y: y)
                // Pointing across the seam (left lobe → +x), tilted a little alternately.
                let tilt: CGFloat = (i % 2 == 0 ? 0.16 : -0.12) * s
                let angle: CGFloat = (side < 0 ? 0 : .pi) + tilt
                out.append((root: root, angle: angle, length: 24 + 12 * bulge, curl: i % 2 == 0 ? 1 : -1))
            }
        }
        return out
    }
}
