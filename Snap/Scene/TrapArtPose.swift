import CoreGraphics
import Foundation

/// How `TrapArt.trapImage(style:…)` draws the isolated trap.
enum TrapImageStyle: Equatable, Sendable {
    /// The play trap from above (the scene's own lobes, midrib and cilia): Home's backdrop and the Duo diagrams, which
    /// cut it down the midrib. Never on its own as a hero (it reads as a vertical slit, REVIEW-3 #16).
    case topDown
    /// R4 (#16): the isolated trap seen 3/4 from the front and above, tilted like the icon, half open: the back lobe's
    /// crimson face (the oxblood gradient, the yellow-green blush at the margin) under a crown of cilia, the front lobe's
    /// green leaf back with its yellow-green lip and crimson edge, and a winged petiole leaf. For Results, the cover,
    /// the pose card and every badge.
    case threeQuarter
}

/// R4 (#16): the 3/4 trap's drawing, in its own frame (points, y up): the hinge runs along the x axis from
/// (−`halfSpan`, 0) to (+`halfSpan`, 0); the whole trap is then turned by `tilt` (the opening faces up and right).
enum TrapPose {
    /// Half the hinge's length and the back lobe's height.
    static let halfSpan: CGFloat = 150
    static let height: CGFloat = 120
    /// The turn of the whole trap (radians, y up: negative is clockwise, so the opening faces up-right like the icon).
    static let tilt: CGFloat = -0.18
    /// The back crown's cilia.
    static let ciliaCount = 32

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

        /// The (unnormalised) tangent at `t`.
        func tangent(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = 3 * u * u, b = 6 * u * t, c = 3 * t * t
            return CGPoint(x: a * (c1.x - p0.x) + b * (c2.x - c1.x) + c * (p3.x - c2.x),
                           y: a * (c1.y - p0.y) + b * (c2.y - c1.y) + c * (p3.y - c2.y))
        }

        func add(to p: CGMutablePath, move: Bool) {
            if move { p.move(to: p0) } else { p.addLine(to: p0) }
            p.addCurve(to: p3, control1: c1, control2: c2)
        }

        var reversed: Cubic { Cubic(p0: p3, c1: c2, c2: c1, p3: p0) }
    }

    static var cornerL: CGPoint { CGPoint(x: -halfSpan, y: 0) }
    static var cornerR: CGPoint { CGPoint(x: halfSpan, y: 0) }

    /// The back lobe's margin (its crimson face lies under it, down to the hinge).
    static var backRim: Cubic {
        Cubic(p0: cornerL, c1: CGPoint(x: -halfSpan * 1.02, y: height * 1.3),
              c2: CGPoint(x: halfSpan * 1.02, y: height * 1.3), p3: cornerR)
    }

    /// The back lobe's leaf back, seen edge-on as a thin green band beyond its margin.
    static var backShell: Cubic {
        Cubic(p0: CGPoint(x: -halfSpan - 5, y: -1), c1: CGPoint(x: -halfSpan * 1.07, y: height * 1.37),
              c2: CGPoint(x: halfSpan * 1.07, y: height * 1.37), p3: CGPoint(x: halfSpan + 5, y: -1))
    }

    /// The front lobe's lip (it rises towards the viewer, so it arcs above the hinge and hides it).
    static var frontLip: Cubic {
        Cubic(p0: cornerL, c1: CGPoint(x: -halfSpan * 0.62, y: height * 0.42),
              c2: CGPoint(x: halfSpan * 0.62, y: height * 0.42), p3: cornerR)
    }

    /// The front lobe's belly (its green outside, curving down under the trap).
    static var frontBelly: Cubic {
        Cubic(p0: cornerL, c1: CGPoint(x: -halfSpan * 0.82, y: -height * 1.25),
              c2: CGPoint(x: halfSpan * 0.82, y: -height * 1.25), p3: cornerR)
    }

    /// The back face's gradient centre and semi-axes (normalised radius ≈ 1 along the back rim).
    static var faceCenter: CGPoint { CGPoint(x: 0, y: -height * 0.1) }
    static var faceRx: CGFloat { halfSpan * 1.02 }
    static var faceRy: CGFloat { height * 1.05 }

    /// The region under the back rim, closed along the hinge.
    static func backFacePath() -> CGPath {
        let p = CGMutablePath()
        backRim.add(to: p, move: true)
        p.closeSubpath()
        return p
    }

    static func backShellPath() -> CGPath {
        let p = CGMutablePath()
        backShell.add(to: p, move: true)
        p.closeSubpath()
        return p
    }

    /// The front lobe: between its lip (top) and its belly (bottom).
    static func frontLobePath() -> CGPath {
        let p = CGMutablePath()
        frontLip.add(to: p, move: true)
        frontBelly.reversed.add(to: p, move: false)
        p.closeSubpath()
        return p
    }

    static func curvePath(_ c: Cubic) -> CGPath {
        let p = CGMutablePath()
        c.add(to: p, move: true)
        return p
    }

    /// One cilium of the back crown: (root, outward angle, length, curl).
    static func crown() -> [(root: CGPoint, angle: CGFloat, length: CGFloat, curl: CGFloat)] {
        var out: [(root: CGPoint, angle: CGFloat, length: CGFloat, curl: CGFloat)] = []
        let n = ciliaCount
        let shell = backShell
        for i in 0..<n {
            let t = 0.035 + 0.93 * (CGFloat(i) + 0.5) / CGFloat(n)
            let root = shell.point(t)
            let d = shell.tangent(t)
            // The outward normal of a ∩ arc run left to right: the tangent turned a quarter anticlockwise.
            let angle = atan2(d.x, -d.y)
            let bulge = pow(sin(CGFloat.pi * t), 0.7)
            out.append((root: root, angle: angle, length: 24 + 30 * bulge, curl: i % 2 == 0 ? 1 : -1))
        }
        return out
    }

    /// The petiole leaf's outline and midvein (it leaves the front lobe's belly down and to the left).
    static func petiole() -> (blade: CGPath, vein: CGPath, points: [CGPoint]) {
        let root = CGPoint(x: -halfSpan * 0.1, y: -height * 0.78)
        let tip = CGPoint(x: -halfSpan * 0.95, y: -height * 1.62)
        let dx = tip.x - root.x, dy = tip.y - root.y
        let len = max((dx * dx + dy * dy).squareRoot(), 1)
        let nx = -dy / len, ny = dx / len
        let n = 28
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        let vein = CGMutablePath()
        for i in 0...n {
            let u = CGFloat(i) / CGFloat(n)
            let sway = 10 * sin(CGFloat.pi * u)
            let spine = CGPoint(x: root.x + dx * u + nx * sway, y: root.y + dy * u + ny * sway)
            // A winged leaf: narrow at the trap, broad in the middle, a rounded end.
            let hw = 5 + 22 * BogMath.smoothstep(0, 0.45, u) * (1 - 0.85 * BogMath.smoothstep(0.7, 1, u))
            left.append(CGPoint(x: spine.x + nx * hw, y: spine.y + ny * hw))
            right.append(CGPoint(x: spine.x - nx * hw, y: spine.y - ny * hw))
            if i == 0 { vein.move(to: spine) } else if i < n { vein.addLine(to: spine) }
        }
        let blade = CGMutablePath()
        blade.move(to: left[0])
        for q in left.dropFirst() { blade.addLine(to: q) }
        for q in right.reversed() { blade.addLine(to: q) }
        blade.closeSubpath()
        return (blade, vein, left + right)
    }

    /// Where a sipping bug sits (on the back face, right of centre) and its nectar drop, with its heading.
    static var bugSpot: CGPoint { CGPoint(x: halfSpan * 0.3, y: height * 0.6) }
    static let bugHeading: CGFloat = .pi * 1.1
    /// The bug's art radius (≈ 20 % of the trap's span drawn, like the icon's ~35 % fly but smaller: the trap is the
    /// subject here).
    static var bugRadius: CGFloat { halfSpan * 0.135 }

    /// The tilt as a transform (trap frame → drawing frame).
    static var turn: CGAffineTransform { CGAffineTransform(rotationAngle: tilt) }

    /// The drawing's bounds (after the tilt), everything included, padded.
    static func bounds() -> CGRect {
        var pts: [CGPoint] = []
        for c in [backShell, frontBelly] {
            for i in 0...40 { pts.append(c.point(CGFloat(i) / 40)) }
        }
        for c in crown() {
            pts.append(CGPoint(x: c.root.x + cos(c.angle) * (c.length + 3), y: c.root.y + sin(c.angle) * (c.length + 3)))
        }
        pts += petiole().points
        // The ground shadow.
        pts.append(CGPoint(x: -halfSpan * 1.12, y: -height * 0.95))
        pts.append(CGPoint(x: halfSpan * 1.12, y: -height * 0.95))
        pts.append(CGPoint(x: 0, y: -height * 1.25))
        var box = CGRect.null
        let k = turn
        for p in pts { box = box.union(CGRect(origin: p.applying(k), size: .zero)) }
        return box.insetBy(dx: -8, dy: -8)
    }

    /// Draws the 3/4 trap in its drawing frame (call after mapping `bounds()` onto the target).
    static func draw(_ ctx: CGContext, sippingBug: BugSpecies?) {
        let pal = TrapArt.palette
        ctx.saveGState()
        ctx.concatenate(turn)
        let L = halfSpan, H = height

        // The soft ground shadow, then the petiole leaf behind the trap.
        BogPainter.ellipticalRadial(ctx, [RGBA(0, 0.04, 0.02, 0.32), RGBA(0, 0.04, 0.02, 0.24), RGBA(0, 0.04, 0.02, 0)],
                                    [0, 0.6, 1], center: CGPoint(x: 10, y: -H * 0.98), rx: L * 1.1, ry: H * 0.26)
        let pet = petiole()
        ctx.saveGState()
        ctx.translateBy(x: 3, y: -4)
        BogPainter.fill(ctx, pet.blade, RGBA(0, 0.04, 0.02), 0.3)
        ctx.restoreGState()
        BogPainter.stroke(ctx, pet.blade, TrapArt.lobeOutline, width: 2, 0.85)
        BogPainter.gradient(ctx, pet.blade, [BogPaint.lighter(TrapArt.petiole, 0.25), TrapArt.petiole,
                                             BogPaint.darker(TrapArt.petiole, 0.3)], [0, 0.5, 1],
                            from: CGPoint(x: -L * 0.7, y: -H * 1.0), to: CGPoint(x: -L * 0.2, y: -H * 1.6))
        BogPainter.stroke(ctx, pet.vein, BogPaint.lighter(TrapArt.petiole, 0.45), width: 1.8, 0.6)

        // The back crown of cilia (behind the shell, their roots tucked under it).
        let cilia = crown()
        let ciliaShadow = CGMutablePath()
        var shapes: [(CGPath, CGPoint, CGPoint)] = []
        for c in cilia {
            let shape = TrapArt.toothShape(length: c.length, width: 3.6, curl: c.curl)
            let p = CGMutablePath()
            p.addPath(shape, transform: CGAffineTransform(translationX: c.root.x, y: c.root.y)
                .rotated(by: c.angle - .pi / 2))
            ciliaShadow.addPath(p)
            let tip = CGPoint(x: c.root.x + cos(c.angle) * c.length, y: c.root.y + sin(c.angle) * c.length)
            shapes.append((p, c.root, tip))
        }
        ctx.saveGState()
        ctx.translateBy(x: 1.6, y: -2.2)
        BogPainter.fill(ctx, ciliaShadow, RGBA(0, 0.05, 0.02), 0.28)
        ctx.restoreGState()
        for (p, root, tip) in shapes {
            BogPainter.stroke(ctx, p, TrapArt.lobeOutline, width: 1.2, 0.75)
            BogPainter.gradient(ctx, p, [TrapArt.ciliaBase, TrapArt.ciliaMid, pal.teeth], [0.05, 0.5, 1],
                                from: root, to: tip)
        }

        // The back lobe's leaf back (a thin green band beyond its margin), then its crimson face.
        let shell = backShellPath()
        BogPainter.stroke(ctx, shell, TrapArt.lobeOutline, width: 2.4, 0.9)
        BogPainter.gradient(ctx, shell, [BogPaint.lighter(TrapArt.leaf, 0.18), TrapArt.leaf, TrapArt.leafDark],
                            [0, 0.5, 1], from: CGPoint(x: 0, y: H * 1.05), to: CGPoint(x: 0, y: 0))
        let face = backFacePath()
        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        // The oxblood gradient from the hinge to the margin (R4 #5: the same stops as the play face).
        let stops = TrapArt.faceStops
        BogPainter.ellipticalRadial(ctx, stops.map { $0.1 }, stops.map { $0.0 }, center: faceCenter, rx: faceRx,
                                    ry: faceRy, extend: true)
        // Glands: tiny darker dots, more of them down towards the hinge.
        var rng = BogRNG(seed: 0x3A4E)
        let dots = CGMutablePath()
        var placed = 0, tries = 0
        while placed < 420 && tries < 4000 {
            tries += 1
            let u = rng.unit(), v = rng.unit()
            let q = CGPoint(x: (2 * u - 1) * L, y: pow(v, 1.6) * H)
            guard face.contains(q) else { continue }
            let pr = rng.range(0.6, 1.4)
            dots.addEllipse(in: CGRect(x: q.x - pr, y: q.y - pr, width: 2 * pr, height: 2 * pr))
            placed += 1
        }
        BogPainter.fill(ctx, dots, RGBA(hex: 0x3A0612), 0.35)
        // Fine veins fanning from the hinge to the margin.
        let veins = CGMutablePath()
        let rim = backRim
        for i in 0..<11 {
            let t = (CGFloat(i) + 0.5) / 11
            let end = rim.point(t)
            let start = CGPoint(x: end.x * 0.25, y: 0)
            veins.move(to: start)
            veins.addQuadCurve(to: CGPoint(x: start.x + (end.x - start.x) * 0.94, y: start.y + (end.y - start.y) * 0.94),
                               control: CGPoint(x: start.x + (end.x - start.x) * 0.55, y: end.y * 0.35))
        }
        BogPainter.stroke(ctx, veins, RGBA(hex: 0x3A0612), width: 1.3, 0.28)
        // The yellow-green blush, only in the last ~9 % before the margin (≤ 38 %).
        BogArt.drawBlush(ctx, center: faceCenter, rx: faceRx, ry: faceRy)
        // One soft wet specular, high on the left of the face.
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: -L * 0.42, y: H * 0.7), L * 0.2, H * 0.06, rotation: 0.5),
                        RGBA(1, 1, 1), 0.16)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: -L * 0.42, y: H * 0.7), L * 0.12, H * 0.025, rotation: 0.5),
                        RGBA(1, 1, 1), 0.42)
        ctx.restoreGState()
        BogPainter.stroke(ctx, curvePath(rim), RGBA(0.1, 0.02, 0.03), width: 1.2, 0.4)

        // The bug, sipping on the back face (under the front lobe's lip, which never reaches it).
        if let sp = sippingBug { drawSipper(ctx, sp) }

        // The front lobe: its crimson inner edge just above the lip, the mouth's shadow over it, then the green back.
        let lip = curvePath(frontLip)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: 3.5)
        BogPainter.stroke(ctx, lip, TrapArt.interior, width: 6, 0.45)
        ctx.restoreGState()
        BogPainter.stroke(ctx, lip, pal.lobeOuter, width: 6)
        let front = frontLobePath()
        BogPainter.stroke(ctx, front, TrapArt.lobeOutline, width: 2.4, 0.9)
        BogPainter.gradient(ctx, front, [BogPaint.lighter(TrapArt.leaf, 0.24), TrapArt.leaf,
                                         BogPaint.darker(TrapArt.leaf, 0.12), TrapArt.leafDark], [0, 0.35, 0.7, 1],
                            from: CGPoint(x: -L * 0.3, y: H * 0.3), to: CGPoint(x: L * 0.2, y: -H * 0.9))
        ctx.saveGState()
        ctx.addPath(front)
        ctx.clip()
        // The leaf back's veins, from its base up to the lip.
        let backVeins = CGMutablePath()
        for i in 0..<9 {
            let t = 0.1 + 0.8 * (CGFloat(i) + 0.5) / 9
            let end = frontLip.point(t)
            let start = CGPoint(x: end.x * 0.2, y: -H * 0.8)
            backVeins.move(to: start)
            backVeins.addQuadCurve(to: end, control: CGPoint(x: end.x * 0.85, y: -H * 0.35))
        }
        BogPainter.stroke(ctx, backVeins, BogPaint.lighter(TrapArt.leaf, 0.4), width: 1.2, 0.3)
        // Lit from the top left, a soft sheen.
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 1, 0.9, 0.22), RGBA(1, 1, 0.9, 0)], [0, 1],
                                    center: CGPoint(x: -L * 0.38, y: -H * 0.05), rx: L * 0.42, ry: H * 0.22)
        ctx.restoreGState()
        // The front lobe's yellow-green lip, with a wet highlight.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: -1.6)
        BogPainter.stroke(ctx, lip, RGBA(hex: 0x9DB24A), width: 3.2, 0.9)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.translateBy(x: -1, y: -0.6)
        BogPainter.stroke(ctx, lip, RGBA(1, 1, 0.9), width: 0.9, 0.35)
        ctx.restoreGState()
        ctx.restoreGState()
    }

    /// A bug sipping a nectar drop on the back face (the game's own art), a little foreshortened by the 3/4 view.
    private static func drawSipper(_ ctx: CGContext, _ s: BugSpecies) {
        let r = bugRadius
        let p = bugSpot
        let h = bugHeading
        let head = CGPoint(x: p.x + cos(h) * r * 1.15, y: p.y + sin(h) * r * 1.15)
        let dr = max(r * 0.42, 3)
        ctx.saveGState()
        ctx.translateBy(x: head.x - 1.5 * dr, y: head.y - 1.5 * dr)
        BogArt.drawNectar(ctx, size: CGSize(width: 3 * dr, height: 3 * dr), radius: dr)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.translateBy(x: p.x, y: p.y)
        ctx.scaleBy(x: 1, y: 0.88)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: 3, y: -4), r * 1.05, r * 0.8), RGBA(0.08, 0, 0.03), 0.3)
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
    /// R4 (#16): the trap as an image `width` points wide, in `style`, optionally with a bug sipping on it.
    /// - `.threeQuarter` (Results, the cover, the pose card, badges): the 3/4-tilted half-open trap with its leaf back
    ///   and petiole leaf (`TrapPose`); height ≈ `threeQuarterAspect` × width. `sippingBug` sits on the back face with
    ///   a nectar drop (e.g. `.housefly`).
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

    /// R4 (#16): the 3/4 trap's height over its width.
    static var threeQuarterAspect: CGFloat {
        let b = TrapPose.bounds()
        return b.height / max(b.width, 1)
    }

    /// R4 (#16): the 3/4 trap drawn into any context (y up), fitted and centred in `size` (badges, the pose card).
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
