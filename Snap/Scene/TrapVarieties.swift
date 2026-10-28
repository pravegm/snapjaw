import CoreGraphics
import Foundation

/// R6 (the Garden): how a variety's cilia are cut.
enum TrapToothKind: Equatable, Sendable {
    /// Long thin hairs (Classic, Red Dragon, B52 chunkier, Cupped, Golden Glow).
    case cilia
    /// Short jagged teeth with a notch on the trailing edge (Sawtooth).
    case saw
    /// Short broad triangles (Shark Tooth).
    case shark
    /// Broad round scallops that touch their neighbours, so the row reads as one frill (Fused Tooth).
    case fused
}

/// R6: one variety's look (`TrapArt.look(_:)`). Cosmetic only: the trap's shape, zone and rules never change (B52's
/// lobes are drawn `spread` wider about the midrib, at most 3 %). Every drawing that takes a `TrapVariety` reads its
/// colours and cuts from here: the play lobes and cilia, the closed trap, the snap glyph and the hero 3/4 trap.
struct TrapLook {
    var variety: TrapVariety
    /// The face's stops by distance from the midrib (0 on it … 1 at the margin).
    var faceStops: [(CGFloat, RGBA)]
    /// The cupped shading's colour and strength (1 = Classic).
    var cup: RGBA
    var cupStrength: Double
    /// The margin's blush.
    var blush: RGBA
    var blushAlpha: Double
    /// The glands' stipple strength (1 = Classic).
    var glands: Double
    /// The thin lip inside the margin, the leaf's back beyond it, and its outline.
    var lip: RGBA
    var leaf: RGBA
    var leafDark: RGBA
    var outline: RGBA
    /// The cilia, base → mid → tip.
    var ciliaBase: RGBA
    var ciliaMid: RGBA
    var ciliaTip: RGBA
    var tooth: TrapToothKind
    /// The cilia's length and width over Classic's.
    var toothLength: CGFloat
    var toothWidth: CGFloat
    /// The play lobes' x scale about the midrib (B52: 1.03; the hero uses `heroLobes`).
    var spread: CGFloat
    /// The wet gloss's strength (1 = Classic; Cupped 1.6).
    var gloss: CGFloat
    /// Golden Glow: a gold sheen along the rim and the cilia; `sparkle`: twinkles on the rim.
    var sheen: RGBA?
    var sparkle: Bool
    /// The closed trap's stops (outer edge 0 → seam 1).
    var closedStops: [(CGFloat, RGBA)]
    /// The snap glyph's crimson: its core, its outer band and its inner (seam) shade.
    var glyphCore: RGBA
    var glyphOuter: RGBA
    var glyphInner: RGBA
    /// The hero 3/4 trap's colours (the icon's for Classic).
    var heroHot: RGBA
    var heroFace: RGBA
    var heroDeep: RGBA
    var heroLipFace: RGBA
    var heroMargin: RGBA
    var heroMarginDeep: RGBA
    var heroLeafLight: RGBA
    var heroLeafDark: RGBA
    var heroCilium: RGBA
    /// R7 (#1): the hero 3/4 trap's own cut, so the 8 read apart at a 120 pt thumbnail (cosmetic: play never changes).
    /// The lobes' scale about the hinge before the tilt (B52 1.15 both ways; Cupped 1.22 tall, a deep cup), the back
    /// crown's tooth count (Classic 13), and its teeth's length and half-width over Classic's.
    var heroLobes = CGSize(width: 1, height: 1)
    var heroTeeth: Int = 13
    var heroToothLength: CGFloat = 1
    var heroToothWidth: CGFloat = 1
    /// R7 (Fused Tooth): the continuous frill under the scallops along the back rim.
    var heroFrill: RGBA?
    /// R7 (Cupped): a dark line along both rims.
    var heroRimLine: RGBA?

    /// The face colour at `f` (0 midrib … 1 margin), from `faceStops`.
    func face(at f: CGFloat) -> RGBA {
        guard let first = faceStops.first else { return TrapArt.palette.lobeOuter }
        if f <= first.0 { return first.1 }
        for i in 1..<faceStops.count {
            let a = faceStops[i - 1], b = faceStops[i]
            if f <= b.0 {
                let t = Double((f - a.0) / max(b.0 - a.0, 0.0001))
                return a.1.mixed(with: b.1, t)
            }
        }
        return faceStops[faceStops.count - 1].1
    }
}

extension TrapArt {
    /// R6: every variety's look. Exhaustive: a new variety must say how it looks.
    static func look(_ v: TrapVariety) -> TrapLook {
        let pal = palette
        var k = TrapLook(
            variety: v, faceStops: faceStops, cup: pal.lobeInner, cupStrength: 1, blush: blush,
            blushAlpha: blushAlpha, glands: 1, lip: lip, leaf: leaf, leafDark: leafDark, outline: lobeOutline,
            ciliaBase: ciliaBase, ciliaMid: ciliaMid, ciliaTip: pal.teeth, tooth: .cilia, toothLength: 1,
            toothWidth: 1, spread: 1, gloss: 1, sheen: nil, sparkle: false, closedStops: closedStops,
            glyphCore: lobeCore, glyphOuter: pal.lobeOuter, glyphInner: pal.lobeInner,
            heroHot: TrapPose.faceHot, heroFace: TrapPose.face, heroDeep: TrapPose.faceDeep,
            heroLipFace: TrapPose.lipFace, heroMargin: TrapPose.margin, heroMarginDeep: TrapPose.marginDeep,
            heroLeafLight: TrapPose.leafLight, heroLeafDark: TrapPose.leafDark, heroCilium: TrapPose.cilium)
        switch v {
        case .classic:
            break
        case .redDragon:
            // All crimson, even the leaf's back (the real cultivar is red through and through).
            k.faceStops = [
                (0, RGBA(hex: 0x3E0310)), (0.16, RGBA(hex: 0x5A0717)), (0.5, RGBA(hex: 0x7A0C20)),
                (0.8, RGBA(hex: 0x931229)), (0.92, RGBA(hex: 0x9E152C)), (1, RGBA(hex: 0x7E1026)),
            ]
            k.cup = RGBA(hex: 0x2E020B)
            k.cupStrength = 1.2
            k.blush = RGBA(hex: 0xB0182E)
            k.blushAlpha = 0.25
            k.lip = RGBA(hex: 0x5E0A1A)
            k.leaf = RGBA(hex: 0x7A1424)
            k.leafDark = RGBA(hex: 0x420812)
            k.outline = RGBA(hex: 0x24040C)
            k.ciliaBase = RGBA(hex: 0x8A1C2A)
            k.ciliaMid = RGBA(hex: 0xC85660)
            k.ciliaTip = RGBA(hex: 0xF4C6BC)
            k.gloss = 0.9
            k.closedStops = [
                (0, RGBA(hex: 0x420812)), (0.18, RGBA(hex: 0x7A1424)), (0.45, RGBA(hex: 0x9A2232)),
                (0.66, RGBA(hex: 0x7A1424)), (0.76, RGBA(hex: 0x5A0A1C)), (0.82, RGBA(hex: 0x86142C)),
                (0.9, RGBA(hex: 0xA0182E)), (0.96, RGBA(hex: 0x3E0310)), (1, RGBA(hex: 0x1C0309)),
            ]
            k.glyphCore = RGBA(hex: 0x7A0C20)
            k.glyphOuter = RGBA(hex: 0x9E152C)
            k.glyphInner = RGBA(hex: 0x3E0310)
            k.heroHot = RGBA(hex: 0xC23A50)
            k.heroFace = RGBA(hex: 0x9E152C)
            k.heroDeep = RGBA(hex: 0x4A0414)
            k.heroLipFace = RGBA(hex: 0xB02238)
            k.heroMargin = RGBA(hex: 0xC8404E)
            k.heroMarginDeep = RGBA(hex: 0x7A1424)
            k.heroLeafLight = RGBA(hex: 0x9A2232)
            k.heroLeafDark = RGBA(hex: 0x4A0A16)
            k.heroCilium = RGBA(hex: 0xF4C6BC)
        case .b52:
            // R7 (#1): big. The hero's lobes are 15 % larger (play: 3 % wider, the trap's zone never changes), with
            // few fat, long cilia and a deeper wine face on a dark leaf.
            k.tooth = .cilia
            k.toothLength = 1.4
            k.toothWidth = 2.2
            k.spread = 1.03
            k.ciliaBase = RGBA(hex: 0x4E8A30)
            k.ciliaMid = RGBA(hex: 0xC2DC8A)
            k.leaf = RGBA(hex: 0x24502A)
            k.leafDark = RGBA(hex: 0x0F2E12)
            k.heroLobes = CGSize(width: 1.15, height: 1.15)
            k.heroTeeth = 11
            k.heroToothLength = 1.5
            k.heroToothWidth = 2.3
            k.heroHot = RGBA(hex: 0xE8506A)
            k.heroFace = RGBA(hex: 0xC42444)
            k.heroDeep = RGBA(hex: 0x620820)
            k.heroLeafLight = RGBA(hex: 0x4E9A38)
            k.heroLeafDark = RGBA(hex: 0x163E1C)
        case .sawtooth:
            // R7 (#1): a dense row of short, jagged red saw teeth on an amber margin.
            k.tooth = .saw
            k.toothLength = 0.42
            k.toothWidth = 3
            k.ciliaBase = RGBA(hex: 0x5A7A2C)
            k.ciliaMid = RGBA(hex: 0xC8443A)
            k.ciliaTip = RGBA(hex: 0xF08A72)
            k.lip = RGBA(hex: 0x5E4A1A)
            k.blush = RGBA(hex: 0xD9A23A)
            k.heroTeeth = 25
            k.heroToothLength = 0.5
            k.heroToothWidth = 1.6
            k.heroCilium = RGBA(hex: 0xD8383A)
            k.heroMargin = RGBA(hex: 0xE0AE40)
            k.heroMarginDeep = RGBA(hex: 0x9A7A2A)
        case .sharkTooth:
            // R7 (#1): a few wide ivory triangles, and a hotter scarlet-coral face.
            k.tooth = .shark
            k.toothLength = 0.7
            k.toothWidth = 3.4
            k.ciliaBase = RGBA(hex: 0xC8D49A)
            k.ciliaMid = RGBA(hex: 0xF2F0D6)
            k.ciliaTip = RGBA(hex: 0xFFFFF2)
            k.faceStops = [
                (0, RGBA(hex: 0x6A1A0E)), (0.16, RGBA(hex: 0x8A2614)), (0.5, RGBA(hex: 0xB8341E)),
                (0.8, RGBA(hex: 0xD0442A)), (0.92, RGBA(hex: 0xDA4C2E)), (1, RGBA(hex: 0xB43A22)),
            ]
            k.glyphCore = RGBA(hex: 0xB8341E)
            k.glyphOuter = RGBA(hex: 0xDA4C2E)
            k.glyphInner = RGBA(hex: 0x6A1A0E)
            k.heroTeeth = 9
            k.heroToothLength = 0.8
            k.heroToothWidth = 3.6
            k.heroCilium = RGBA(hex: 0xFFFBEA)
            k.heroHot = RGBA(hex: 0xFF8A5C)
            k.heroFace = RGBA(hex: 0xE84A30)
            k.heroDeep = RGBA(hex: 0x8A1E12)
            k.heroLipFace = RGBA(hex: 0xF05A3A)
        case .fusedTooth:
            // R7 (#1): one continuous lime frill, never single cilia.
            k.tooth = .fused
            k.toothLength = 0.6
            k.toothWidth = 6
            k.ciliaBase = RGBA(hex: 0x5E9A34)
            k.ciliaMid = RGBA(hex: 0xA8D24E)
            k.ciliaTip = RGBA(hex: 0xDCEE8A)
            k.heroTeeth = 15
            k.heroToothLength = 0.85
            k.heroToothWidth = 3.6
            k.heroCilium = RGBA(hex: 0xD6EC7A)
            k.heroFrill = RGBA(hex: 0x9CCB3E)
        case .cupped:
            // R7 (#1): a deep cup (the hero's lobes 22 % taller), a strong wet gloss and a dark rim.
            k.cupStrength = 2.4
            k.glands = 0.8
            k.gloss = 1.9
            k.blushAlpha = 0.18
            k.lip = RGBA(hex: 0x1E3A14)
            k.leaf = RGBA(hex: 0x23491F)
            k.leafDark = RGBA(hex: 0x0F2A10)
            k.heroLobes = CGSize(width: 1, height: 1.22)
            k.heroFace = RGBA(hex: 0xC8304C)
            k.heroDeep = RGBA(hex: 0x4A0618)
            k.heroMargin = RGBA(hex: 0x6E9A34)
            k.heroMarginDeep = RGBA(hex: 0x355E22)
            k.heroRimLine = RGBA(hex: 0x14280E)
        case .goldenGlow:
            // The fantasy finale: R7 (#1) a gold interior, a gold sheen on the rim and the cilia, and twinkles. The
            // play face is a deep amber at the midrib, so the nectar's bright beads still read on it.
            k.sheen = pal.gold
            k.sparkle = true
            k.gloss = 1.2
            k.faceStops = [
                (0, RGBA(hex: 0x5A3606)), (0.16, RGBA(hex: 0x7A4A0A)), (0.5, RGBA(hex: 0xA8701A)),
                (0.8, RGBA(hex: 0xC99028)), (0.92, RGBA(hex: 0xD8A030)), (1, RGBA(hex: 0xB8862A)),
            ]
            k.cup = RGBA(hex: 0x3A2204)
            k.blush = RGBA(hex: 0xFFE27A)
            k.blushAlpha = 0.3
            k.glands = 0.35
            k.lip = RGBA(hex: 0xB8952E)
            k.ciliaBase = RGBA(hex: 0xB08A2A)
            k.ciliaMid = RGBA(hex: 0xF0CF62)
            k.ciliaTip = RGBA(hex: 0xFFF6C8)
            k.closedStops = [
                (0, RGBA(hex: 0x173D19)), (0.18, RGBA(hex: 0x2F5F2B)), (0.45, RGBA(hex: 0x41763A)),
                (0.66, RGBA(hex: 0x2F5F2B)), (0.76, RGBA(hex: 0x6A4A10)), (0.82, RGBA(hex: 0xA8701A)),
                (0.9, RGBA(hex: 0xD8A030)), (0.96, RGBA(hex: 0x5A3606)), (1, RGBA(hex: 0x1C0E03)),
            ]
            k.glyphCore = RGBA(hex: 0xA8701A)
            k.glyphOuter = RGBA(hex: 0xD8A030)
            k.glyphInner = RGBA(hex: 0x5A3606)
            k.heroHot = RGBA(hex: 0xFFF0A0)
            k.heroFace = RGBA(hex: 0xF2C040)
            k.heroDeep = RGBA(hex: 0x8A5410)
            k.heroLipFace = RGBA(hex: 0xF8CC50)
            k.heroMargin = pal.gold
            k.heroMarginDeep = RGBA(hex: 0xC9962E)
            k.heroCilium = RGBA(hex: 0xFFF1B0)
        }
        return k
    }

    /// R6: one tooth in its own frame (root at the origin, tucked 3 pt under the margin, pointing +y) for a cut.
    static func toothShape(length L: CGFloat, width w: CGFloat, curl: CGFloat, kind: TrapToothKind) -> CGPath {
        let h = w / 2
        switch kind {
        case .cilia:
            return toothShape(length: L, width: w, curl: curl)
        case .saw:
            // A jagged tooth: up the leading edge to a tip leaning with the curl, a notch down the trailing edge.
            let p = CGMutablePath()
            let tipX = curl * h * 0.55
            p.move(to: CGPoint(x: -h, y: -3))
            p.addLine(to: CGPoint(x: tipX, y: L))
            p.addLine(to: CGPoint(x: h * 0.3, y: L * 0.5))
            p.addLine(to: CGPoint(x: h * 0.85, y: L * 0.6))
            p.addLine(to: CGPoint(x: h, y: -3))
            p.closeSubpath()
            return p
        case .shark:
            // A broad triangle with slightly hollow sides.
            let p = CGMutablePath()
            let tipX = curl * h * 0.2
            p.move(to: CGPoint(x: -h, y: -3))
            p.addQuadCurve(to: CGPoint(x: tipX, y: L), control: CGPoint(x: -h * 0.3, y: L * 0.42))
            p.addQuadCurve(to: CGPoint(x: h, y: -3), control: CGPoint(x: h * 0.3, y: L * 0.42))
            p.closeSubpath()
            return p
        case .fused:
            // A round scallop as wide as the gap to the next one: the row reads as one frill.
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -h, y: -3))
            p.addCurve(to: CGPoint(x: h, y: -3), control1: CGPoint(x: -h * 1.05, y: L * 1.3),
                       control2: CGPoint(x: h * 1.05, y: L * 1.3))
            p.closeSubpath()
            return p
        }
    }

    /// R6: where a Golden Glow trap twinkles on one lobe (scene space, just inside the margin).
    static func sparkleSpots(side: Int, geometry g: TrapGeometry) -> [CGPoint] {
        [0.95, 0.55, 0.12, -0.4, -0.85].map { t in
            marginPoint(g, side: side, t: CGFloat(t), a: g.a - 4, b: g.b - 4)
        }
    }

    /// R6: a four-point twinkle (Golden Glow) of radius `r` at `c`.
    static func twinklePath(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let k = r * 0.14
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }

    /// R6: the scale about the trap centre that widens a variety's lobes (B52).
    static func spreadTransform(_ v: TrapVariety, geometry g: TrapGeometry) -> CGAffineTransform {
        let s = look(v).spread
        return CGAffineTransform(translationX: g.center.x, y: 0).scaledBy(x: s, y: 1)
            .translatedBy(x: -g.center.x, y: 0)
    }
}

/// R6: the FEAST event rule (pure and nonisolated, so Feel and the App can share it): a clean bite (no stinger) of
/// `count`+ bugs, or one scored at a chain of `chain` or more. A 3–4 bug Feast keeps the R5 treatment.
enum FeastEvent {
    static let count: Int = Tuning.bigFeastCount
    static let chain: Double = 4
    /// The longest gap between two caught bugs' gulps, and the most time all the gulps may take (a big crowd goes
    /// faster, so the last one is in well inside Core's 0.5 s caught moment).
    static let gulpGap: Double = 0.07
    static let gulpSpan: Double = 0.34

    static func isBig(caught: Int, chainMultiplier: Double, stung: Bool) -> Bool {
        guard !stung, caught > 0 else { return false }
        return caught >= count || (chainMultiplier.isFinite && chainMultiplier >= chain - 0.0001)
    }

    static func isBig(_ r: BiteReport) -> Bool {
        isBig(caught: r.caught.count, chainMultiplier: r.chainMultiplier, stung: !r.stingers.isEmpty)
    }

    /// The delay (s into the caught moment) before each of `n` caught bugs is gulped, in gulp order.
    static func gulpDelays(count n: Int) -> [Double] {
        guard n > 0 else { return [] }
        let gap = n > 1 ? min(gulpGap, gulpSpan / Double(n - 1)) : 0
        return (0..<n).map { 0.03 + Double($0) * gap }
    }
}
