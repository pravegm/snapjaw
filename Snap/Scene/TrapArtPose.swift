import CoreGraphics
import Foundation

/// How `TrapArt.trapImage(style:…)` draws the isolated trap.
enum TrapImageStyle: Equatable, Sendable {
    /// The play trap from above (the scene's own lobes, midrib and cilia): Home's backdrop and the Duo diagrams, which
    /// cut it down the midrib. Never on its own as a hero (it reads as a vertical slit, REVIEW-3 #16).
    case topDown
    /// R5 (REVIEW-4 #6): **the hero trap**, the icon's own drawing (`AppIconArt`): seen 3/4 from the front and above,
    /// tilted like the icon (opening up-right), jaws open. The back lobe's glossy crimson face under a lime margin and a
    /// crown of cream cilia; the front lobe's green outside, its crimson inner band and lime lip with a shorter fringe of
    /// cilia; a broad stem. No stipple, no veins on the face at this size. For Results, the cover, the pose card and
    /// every badge, so all of them and the icon are one trap.
    case threeQuarter
}

/// R5 (#6): the hero trap's drawing, in its own frame (points, y up): the hinge runs along the x axis from
/// (−`halfSpan`, 0) to (+`halfSpan`, 0); the whole trap is then turned by `tilt` (the opening faces up and right).
/// Every curve is the icon's (`AppIconPainter`, a 1024-unit y-down design space with corners at ±320), scaled by
/// `unit` and flipped to y up, so the two drawings stay one shape.
enum TrapPose {
    /// Half the hinge's length.
    static let halfSpan: CGFloat = 150
    /// Points per icon design unit (the icon's corners sit at ±320).
    static let unit: CGFloat = halfSpan / 320
    /// The back lobe's height above the hinge at its peak (the icon's back rim: controls at 365, so 0.75 × 365).
    /// `SceneHooks.threeQuarterPoint` maps `v` 0…1 onto it.
    static let height: CGFloat = 0.75 * 365 * (150.0 / 320.0)
    /// The turn of the whole trap (radians, y up: positive is anticlockwise, so the right corner rises and the
    /// opening faces up-right, like the icon's −0.2 in its y-down space).
    static let tilt: CGFloat = 0.2

    // MARK: The icon's palette (AppIconPainter), as RGBA

    static let faceHot = RGBA(hex: 0xF46A7E)
    static let face = RGBA(hex: 0xD93A56)
    static let faceDeep = RGBA(hex: 0x7E0E2A)
    static let lipFace = RGBA(hex: 0xE04A62)
    static let margin = RGBA(hex: 0xD8EA62)
    static let marginDeep = RGBA(hex: 0x9CC43E)
    static let leafLight = RGBA(hex: 0x6BB548)
    static let leafDark = RGBA(hex: 0x245E2A)
    static let cilium = RGBA(hex: 0xF2F9CC)

    /// A cubic Bézier segment.
    struct Cubic {
        var p0: CGPoint
        var c1: CGPoint
        var c2: CGPoint
        var p3: CGPoint

        func point(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(x: a * p0.x + b * c1.x + c * c2.x + d * p3.x, y: a * p0.y + b * c1.y + c * c2.y + d * p3.y)
        }

        /// The unit tangent at `t`.
        func tangent(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = 3 * u * u, b = 6 * u * t, c = 3 * t * t
            let x = a * (c1.x - p0.x) + b * (c2.x - c1.x) + c * (p3.x - c2.x)
            let y = a * (c1.y - p0.y) + b * (c2.y - c1.y) + c * (p3.y - c2.y)
            let l = max((x * x + y * y).squareRoot(), 0.0001)
            return CGPoint(x: x / l, y: y / l)
        }

        func add(to p: CGMutablePath, move: Bool) {
            if move { p.move(to: p0) } else { p.addLine(to: p0) }
            p.addCurve(to: p3, control1: c1, control2: c2)
        }

        var reversed: Cubic { Cubic(p0: p3, c1: c2, c2: c1, p3: p0) }
    }

    /// One cilium: a tapered, gently curved hair from `base` along the unit `dir`.
    struct Hair {
        var base: CGPoint
        var dir: CGPoint
        var length: CGFloat
        var width: CGFloat
        /// Curls the tip sideways (× length).
        var bend: CGFloat

        var tip: CGPoint {
            let perp = CGPoint(x: -dir.y, y: dir.x)
            return CGPoint(x: base.x + dir.x * length + perp.x * bend * length,
                           y: base.y + dir.y * length + perp.y * bend * length)
        }

        var path: CGPath {
            let perp = CGPoint(x: -dir.y, y: dir.x)
            let mid = CGPoint(x: base.x + dir.x * length * 0.6, y: base.y + dir.y * length * 0.6)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: base.x + perp.x * width, y: base.y + perp.y * width))
            p.addQuadCurve(to: tip, control: CGPoint(x: mid.x + perp.x * width * 0.5, y: mid.y + perp.y * width * 0.5))
            p.addQuadCurve(to: CGPoint(x: base.x - perp.x * width, y: base.y - perp.y * width),
                           control: CGPoint(x: mid.x - perp.x * width * 0.5, y: mid.y - perp.y * width * 0.5))
            p.closeSubpath()
            return p
        }
    }

    /// An icon design-space point (y down, trap frame) in this frame (points, y up).
    static func icon(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: -y * unit) }

    static var cornerL: CGPoint { CGPoint(x: -halfSpan, y: 0) }
    static var cornerR: CGPoint { CGPoint(x: halfSpan, y: 0) }

    /// The back lobe's margin (the top arc, left corner → right corner).
    static var backRim: Cubic {
        Cubic(p0: cornerL, c1: icon(-320 * 0.92, -365), c2: icon(320 * 0.92, -365), p3: cornerR)
    }

    /// The front lobe's lip, sagging towards the viewer (below the hinge, so the mouth is open).
    static var frontLip: Cubic {
        Cubic(p0: cornerL, c1: icon(-320 * 0.62, 165), c2: icon(320 * 0.62, 165), p3: cornerR)
    }

    /// Where the front lobe's crimson inner face disappears towards the hinge (its band's upper edge).
    static var frontInner: Cubic {
        Cubic(p0: cornerL, c1: icon(-320 * 0.62, 66), c2: icon(320 * 0.62, 66), p3: cornerR)
    }

    /// The front lobe's underside.
    static var frontBelly: Cubic {
        Cubic(p0: cornerL, c1: icon(-320 * 0.85, 320), c2: icon(320 * 0.85, 320), p3: cornerR)
    }

    /// The width of the back lobe's green band beyond its margin, and of the lime margins (the icon's strokes).
    static var backBandWidth: CGFloat { 74 * unit }
    static var backMarginWidth: CGFloat { 44 * unit }
    static var frontMarginWidth: CGFloat { 40 * unit }

    /// The closed region along `a`, then back along `b` (both run left corner → right corner).
    static func region(_ a: Cubic, _ b: Cubic) -> CGPath {
        let p = CGMutablePath()
        a.add(to: p, move: true)
        let r = b.reversed
        p.addCurve(to: r.p3, control1: r.c1, control2: r.c2)
        p.closeSubpath()
        return p
    }

    /// The back lobe's crimson face: between its margin and the front lip (the open mouth).
    static func facePath() -> CGPath { region(backRim, frontLip) }
    /// The front lobe's green outside: between its lip and its belly.
    static func frontLobePath() -> CGPath { region(frontLip, frontBelly) }
    /// The front lobe's crimson inner band, just inside its lip.
    static func frontBandPath() -> CGPath { region(frontInner, frontLip) }

    static func curvePath(_ c: Cubic) -> CGPath {
        let p = CGMutablePath()
        c.add(to: p, move: true)
        return p
    }

    /// The back crown: 13 long cilia along the back margin, fanning out at the corners, pointing away from the face.
    static func backCilia() -> [Hair] {
        let n = 13
        var out: [Hair] = []
        let rim = backRim
        for i in 0..<n {
            let t = 0.04 + 0.92 * CGFloat(i) / CGFloat(n - 1)
            let q = rim.point(t)
            let along = rim.tangent(t)
            // Outward (away from the crimson): the tangent of a ∩ arc run left to right, turned anticlockwise.
            let normal = CGPoint(x: -along.y, y: along.x)
            let fan = (t - 0.5) * 0.9
            let dir = normalized(CGPoint(x: normal.x + along.x * fan, y: normal.y + along.y * fan))
            let length = 112 * unit * (0.55 + 0.45 * sin(.pi * t))
            let side: CGFloat = t < 0.5 ? -1 : 1
            out.append(Hair(base: CGPoint(x: q.x - normal.x * 14 * unit, y: q.y - normal.y * 14 * unit), dir: dir,
                            length: length, width: 12 * unit, bend: 0.18 * side))
        }
        return out
    }

    /// The front fringe: 8 shorter cilia from the lip down and out over the leaf's green outside, fanning to the
    /// sides. The middle (where a fly peeks over) stays bare, so nothing reads as teeth.
    static func frontCilia() -> [Hair] {
        let spots: [CGFloat] = [0.07, 0.17, 0.27, 0.36, 0.64, 0.73, 0.83, 0.93]
        var out: [Hair] = []
        let lip = frontLip
        for t in spots {
            let q = lip.point(t)
            let along = lip.tangent(t)
            // Outward (down, towards the viewer): the tangent turned clockwise.
            let normal = CGPoint(x: along.y, y: -along.x)
            let fan = (t - 0.5) * 1.4
            let dir = normalized(CGPoint(x: normal.x + along.x * fan, y: normal.y + along.y * fan))
            let length = 78 * unit * (0.6 + 0.4 * sin(.pi * t))
            let side: CGFloat = t < 0.5 ? -1 : 1
            out.append(Hair(base: CGPoint(x: q.x + normal.x * 6 * unit, y: q.y + normal.y * 6 * unit), dir: dir,
                            length: length, width: 10 * unit, bend: 0.2 * side))
        }
        return out
    }

    /// The broad stem from under the front lobe, down and to the left (the icon's, cut short in a rounded foot so the
    /// hero fits a square badge and never breaks its ring).
    static func stemPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: icon(-120, 150))
        p.addCurve(to: icon(-185, 300), control1: icon(-140, 220), control2: icon(-170, 270))
        p.addQuadCurve(to: icon(-85, 305), control: icon(-135, 330))
        p.addCurve(to: icon(60, 160), control1: icon(-65, 260), control2: icon(20, 210))
        p.closeSubpath()
        return p
    }

    /// The ground shadow under the stem's foot (centre and semi-axes).
    static var groundShadow: (center: CGPoint, rx: CGFloat, ry: CGFloat) {
        (icon(-80, 300), 150 * unit, 24 * unit)
    }

    /// Where a sipping bug sits (on the back face, just above the open mouth), its heading (facing down-left, towards
    /// the viewer) and its art radius (the fly is about a fifth of the trap's span: the trap is the subject).
    static var bugSpot: CGPoint { icon(20, -110) }
    static let bugHeading: CGFloat = -.pi * 0.62
    static var bugRadius: CGFloat { halfSpan * 0.15 }

    /// The tilt as a transform (trap frame → drawing frame).
    static var turn: CGAffineTransform { CGAffineTransform(rotationAngle: tilt) }

    static func normalized(_ p: CGPoint) -> CGPoint {
        let l = max((p.x * p.x + p.y * p.y).squareRoot(), 0.0001)
        return CGPoint(x: p.x / l, y: p.y / l)
    }

    /// The drawing's bounds (after the tilt), everything included, padded.
    static func bounds() -> CGRect {
        var pts: [CGPoint] = []
        let rim = backRim
        let band = backBandWidth / 2 + 2
        for i in 0...40 {
            let t = CGFloat(i) / 40
            let q = rim.point(t)
            let d = rim.tangent(t)
            pts.append(CGPoint(x: q.x - d.y * band, y: q.y + d.x * band))
            pts.append(frontBelly.point(t))
        }
        // The band's round caps at the corners.
        for c in [cornerL, cornerR] {
            for a in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 4) {
                pts.append(CGPoint(x: c.x + band * CGFloat(cos(a)), y: c.y + band * CGFloat(sin(a))))
            }
        }
        for h in backCilia() + frontCilia() {
            let t = h.tip
            pts.append(CGPoint(x: t.x + h.dir.x * 3, y: t.y + h.dir.y * 3))
        }
        let sh = groundShadow
        pts += [CGPoint(x: sh.center.x - sh.rx, y: sh.center.y), CGPoint(x: sh.center.x + sh.rx, y: sh.center.y),
                CGPoint(x: sh.center.x, y: sh.center.y - sh.ry)]
        var box = CGRect.null
        var k = turn
        for p in pts { box = box.union(CGRect(origin: p.applying(k), size: .zero)) }
        // The stem, turned (its own tight bounds, outline included).
        if let stem = stemPath().copy(using: &k) {
            box = box.union(stem.boundingBoxOfPath.insetBy(dx: -1.5, dy: -1.5))
        }
        return box.insetBy(dx: -8, dy: -8)
    }

    /// Strokes `path` `width` wide with a linear gradient.
    static func strokeGradient(_ ctx: CGContext, _ path: CGPath, width: CGFloat, _ colors: [RGBA],
                               _ locations: [CGFloat], from a: CGPoint, to b: CGPoint) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        BogPainter.linear(ctx, colors, locations, from: a, to: b)
        ctx.restoreGState()
    }

    /// Cilia with a soft drop shadow, a fine dark outline (the bugs drawn on the trap have one) and the icon's cream.
    private static func drawHairs(_ ctx: CGContext, _ hairs: [Hair], shadow: CGPoint, shadowColor: RGBA,
                                  shadowAlpha: Double) {
        let all = CGMutablePath()
        for h in hairs { all.addPath(h.path) }
        ctx.saveGState()
        ctx.translateBy(x: shadow.x, y: shadow.y)
        BogPainter.fill(ctx, all, shadowColor, shadowAlpha)
        ctx.restoreGState()
        BogPainter.stroke(ctx, all, TrapArt.lobeOutline, width: 1.1, 0.55)
        BogPainter.fill(ctx, all, cilium)
    }

    /// Draws the hero trap in its drawing frame (call after mapping `bounds()` onto the target).
    static func draw(_ ctx: CGContext, sippingBug: BugSpecies?) {
        ctx.saveGState()
        ctx.concatenate(turn)
        let u = unit

        // The soft ground shadow and the stem, behind the trap.
        let sh = groundShadow
        BogPainter.ellipticalRadial(ctx, [RGBA(0, 0.05, 0.02, 0.45), RGBA(0, 0.05, 0.02, 0.3), RGBA(0, 0.05, 0.02, 0)],
                                    [0, 0.55, 1], center: sh.center, rx: sh.rx, ry: sh.ry)
        let stem = stemPath()
        BogPainter.stroke(ctx, stem, TrapArt.lobeOutline, width: 2.2, 0.8)
        BogPainter.gradient(ctx, stem, [leafDark, leafLight, leafDark], [0, 0.5, 1], from: icon(-270, 0),
                            to: icon(40, 0))

        // The back crown of cilia (their roots tuck under the green band).
        drawHairs(ctx, backCilia(), shadow: CGPoint(x: 3 * u, y: -7 * u), shadowColor: RGBA(hex: 0x051E0C),
                  shadowAlpha: 0.35)

        // The back lobe: its green outside as a band beyond the margin, then the lime margin.
        let rim = curvePath(backRim)
        BogPainter.stroke(ctx, rim, TrapArt.lobeOutline, width: backBandWidth + 3, 0.85)
        BogPainter.stroke(ctx, rim, leafDark, width: backBandWidth)
        strokeGradient(ctx, rim, width: backMarginWidth, [margin, marginDeep], [0, 1], from: icon(0, -300),
                       to: icon(0, 0))

        // The glossy crimson face: hot at the top, deep down towards the hidden hinge. No stipple, no veins.
        let mouth = facePath()
        ctx.saveGState()
        ctx.addPath(mouth)
        ctx.clip()
        BogPainter.radial(ctx, [faceHot, TrapPose.face, faceDeep], [0, 0.5, 1], center: icon(-70, -180),
                          radius: 380 * u, extend: true)
        BogPainter.linear(ctx, [RGBA(hex: 0x3C0414, alpha: 0.95), RGBA(hex: 0x3C0414, alpha: 0)], [0, 1],
                          from: icon(0, 120), to: icon(0, -90))
        // The wet gloss: a crescent upper-left and a small glint.
        let crescent = CGMutablePath()
        crescent.move(to: icon(-250, -80))
        crescent.addCurve(to: icon(-20, -272), control1: icon(-240, -200), control2: icon(-150, -262))
        crescent.addCurve(to: icon(-250, -80), control1: icon(-130, -232), control2: icon(-200, -170))
        crescent.closeSubpath()
        BogPainter.fill(ctx, crescent, RGBA(1, 1, 1), 0.55)
        BogPainter.fill(ctx, BogPainter.ellipse(icon(70, -262), 22 * u, 13 * u, rotation: 0.1), RGBA(1, 1, 1), 0.45)
        ctx.restoreGState()

        // The bug, sipping on the back face (the front lip never reaches it).
        if let sp = sippingBug { drawSipper(ctx, sp) }

        // The front lobe: its green outside with a soft sheen…
        let front = frontLobePath()
        BogPainter.stroke(ctx, front, TrapArt.lobeOutline, width: 2.4, 0.85)
        BogPainter.gradient(ctx, front, [leafLight, leafDark], [0, 1], from: icon(0, 60), to: icon(0, 330))
        ctx.saveGState()
        ctx.addPath(front)
        ctx.clip()
        BogPainter.fill(ctx, BogPainter.ellipse(icon(-120, 215), 150 * u, 26 * u, rotation: -0.25), RGBA(1, 1, 1),
                        0.22)
        ctx.restoreGState()
        // …its own crimson inner face, a band just inside the lip (deep at the hinge, bright at the margin)…
        let band = frontBandPath()
        BogPainter.gradient(ctx, band, [faceDeep, TrapPose.face, lipFace], [0, 0.5, 1], from: icon(0, 46),
                            to: icon(0, 116))
        ctx.saveGState()
        ctx.addPath(band)
        ctx.clip()
        BogPainter.fill(ctx, BogPainter.ellipse(icon(-150, 82), 72 * u, 7 * u, rotation: -0.2), RGBA(1, 1, 1), 0.3)
        ctx.restoreGState()
        // …its lime lip, and the fringe of cilia over the outside.
        strokeGradient(ctx, curvePath(frontLip), width: frontMarginWidth, [margin, marginDeep], [0, 1],
                       from: icon(0, 0), to: icon(0, 170))
        drawHairs(ctx, frontCilia(), shadow: CGPoint(x: 3 * u, y: -6 * u), shadowColor: RGBA(hex: 0x0E3A16),
                  shadowAlpha: 0.4)
        ctx.restoreGState()
    }

    /// A bug sipping a nectar drop on the back face (the game's own art), a little foreshortened by the 3/4 view.
    private static func drawSipper(_ ctx: CGContext, _ s: BugSpecies) {
        let r = bugRadius
        let p = bugSpot
        let h = bugHeading
        let head = CGPoint(x: p.x + cos(h) * r * 1.15, y: p.y + sin(h) * r * 1.15)
        let dr = max(r * 0.42, 3)
        // A dark halo on the crimson, so the grey fly separates from the face by value (the icon's).
        BogPainter.ellipticalRadial(ctx, [RGBA(hex: 0x2A000C, alpha: 0.5), RGBA(hex: 0x2A000C, alpha: 0)], [0, 1],
                                    center: CGPoint(x: p.x + 2, y: p.y - 2), rx: r * 2.1, ry: r * 1.6)
        ctx.saveGState()
        ctx.translateBy(x: head.x - 1.5 * dr, y: head.y - 1.5 * dr)
        BogArt.drawNectar(ctx, size: CGSize(width: 3 * dr, height: 3 * dr), radius: dr)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.scaleBy(x: 1, y: 0.9)
        ctx.rotate(by: h)
        TrapArt.drawBug(ctx, s, radius: r)
        let spread = TrapArt.bugStyle(s).restSpread
        if spread > 0.03 {
            ctx.scaleBy(x: 1, y: min(spread, 1.2))
            TrapArt.drawWings(ctx, s, radius: r)
        }
        ctx.restoreGState()
    }
}

extension TrapArt {
    /// R4 (#16), R5 (#6): the trap as an image `width` points wide, in `style`, optionally with a bug sipping on it.
    /// - `.threeQuarter` (Results, the cover, the pose card, badges): the hero trap, the icon's drawing (`TrapPose`);
    ///   height ≈ `threeQuarterAspect` × width. `sippingBug` sits on the back face with a nectar drop (`.housefly`).
    /// - `.topDown`: the play trap from above (`trapImage(width:scale:)`); `sippingBug` sits on its right lobe.
    static func trapImage(style: TrapImageStyle, width: CGFloat, scale: CGFloat = 2,
                          sippingBug: BugSpecies? = nil) -> CGImage? {
        switch style {
        case .topDown:
            guard let bug = sippingBug else { return trapImage(width: width, scale: scale) }
            return topDownWithBug(width: width, scale: scale, bug: bug)
        case .threeQuarter:
            let box = TrapPose.bounds()
            let k = max(width, 1) / max(box.width, 1)
            return BogPainter.image(width: box.width * k, height: box.height * k, scale: scale) { ctx, _ in
                ctx.scaleBy(x: k, y: k)
                ctx.translateBy(x: -box.minX, y: -box.minY)
                TrapPose.draw(ctx, sippingBug: sippingBug)
            }
        }
    }

    /// The hero trap's height over its width.
    static var threeQuarterAspect: CGFloat {
        let b = TrapPose.bounds()
        return b.height / max(b.width, 1)
    }

    /// The hero trap drawn into any context (y up), fitted and centred in `size` (badges, the pose card).
    static func drawThreeQuarterTrap(_ ctx: CGContext, size: CGSize, sippingBug: BugSpecies? = nil) {
        let box = TrapPose.bounds()
        let k = min(size.width / max(box.width, 1), size.height / max(box.height, 1))
        ctx.saveGState()
        ctx.translateBy(x: (size.width - box.width * k) / 2, y: (size.height - box.height * k) / 2)
        ctx.scaleBy(x: k, y: k)
        ctx.translateBy(x: -box.minX, y: -box.minY)
        TrapPose.draw(ctx, sippingBug: sippingBug)
        ctx.restoreGState()
    }

    /// The top-down trap image with a bug sipping on its right lobe.
    private static func topDownWithBug(width: CGFloat, scale: CGFloat, bug: BugSpecies) -> CGImage? {
        guard let base = trapImage(width: width, scale: scale) else { return nil }
        let w = CGFloat(base.width) / max(scale, 0.25), h = CGFloat(base.height) / max(scale, 0.25)
        return BogPainter.image(width: w, height: h, scale: scale) { ctx, sz in
            ctx.draw(base, in: CGRect(origin: .zero, size: sz))
            let r = sz.width * 0.05
            let p = CGPoint(x: sz.width * 0.68, y: sz.height * 0.6)
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: 2, y: -3), r * 1.05, r * 0.8), RGBA(0.08, 0, 0.03), 0.3)
            ctx.rotate(by: .pi * 0.8)
            drawBug(ctx, bug, radius: r)
            let spread = bugStyle(bug).restSpread
            if spread > 0.03 {
                ctx.scaleBy(x: 1, y: min(spread, 1.2))
                drawWings(ctx, bug, radius: r)
            }
            ctx.restoreGState()
        }
    }
}
