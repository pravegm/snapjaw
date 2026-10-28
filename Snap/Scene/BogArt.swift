import CoreGraphics
import Foundation

/// The scene's static art, drawn once into cached textures (`BogTextures`). Pure CoreGraphics and nonisolated: the
/// texture closures call these directly. Coordinates are y up; the trap layers are drawn in scene space (the caller
/// translates the context to the texture's frame).
enum BogArt {
    // MARK: Constants shared with the scene

    /// The reference tooth the tooth texture is drawn at (sprites scale it to each `TrapTooth`).
    static let toothTexLength: CGFloat = 44
    static let toothTexWidth: CGFloat = 5
    /// The tooth texture's size and where the root sits in it.
    static let toothTexSize = CGSize(width: 20, height: 53)
    static let toothRootY: CGFloat = 6

    /// R3: how far above the trap's lowest point the petiole joins it (inside the bottom notch, under the lobes).
    static let petioleJoin: CGFloat = TrapArt.notchDepth - 4

    /// R3: the closed trap's frame in scene space (`drawClosedTrap`: both lobes squeezed shut, backs included), padded.
    static func closedFrame(geometry g: TrapGeometry, pad: CGFloat = 4) -> CGRect {
        let halfW = (g.a + TrapArt.exteriorWidth) * TrapArt.slamSqueeze + pad
        let halfH = g.b + TrapArt.exteriorWidth + pad
        return CGRect(x: g.center.x - halfW, y: g.center.y - halfH, width: 2 * halfW, height: 2 * halfH)
    }

    /// A lobe layer's frame in scene space (the half ellipse at `reach` × the zone, padded).
    static func lobeFrame(side: Int, geometry g: TrapGeometry, reach: CGFloat = 1, pad: CGFloat = 6) -> CGRect {
        let w = g.a * reach + pad, h = 2 * (g.b * reach + pad)
        let x = side < 0 ? g.center.x - w : g.center.x
        return CGRect(x: x, y: g.center.y - h / 2, width: w, height: h)
    }

    // MARK: The bog

    private static func outside(_ g: TrapGeometry, _ p: CGPoint, _ k: Double) -> Bool { g.normalizedRadius(p) > k }

    /// Where the bog's dew drops sit (the scene twinkles a few of them). Deterministic per scene size.
    static func dewSpots(size: CGSize, geometry g: TrapGeometry) -> [CGPoint] {
        var rng = BogRNG(seed: 0xDE77 &+ UInt64(max(Int(size.width), 1)))
        var out: [CGPoint] = []
        var tries = 0
        let want = 26 + Int(max(size.width - 952, 0) / 40)
        while out.count < want && tries < 4000 {
            tries += 1
            let p = CGPoint(x: rng.range(8, size.width - 8), y: rng.range(84, size.height - 6))
            if outside(g, p, 1.13) { out.append(p) }
        }
        return out
    }

    /// The moss cushions' centres (the four corners' banks plus any extra bog on wide screens).
    static func mossSpots(size: CGSize, geometry g: TrapGeometry) -> [(CGPoint, CGFloat)] {
        let w = size.width, h = size.height
        var out: [(CGPoint, CGFloat)] = [
            (CGPoint(x: 34, y: h - 30), 1.25), (CGPoint(x: w - 40, y: h - 26), 1.3),
            (CGPoint(x: 120, y: h - 8), 0.8), (CGPoint(x: w - 128, y: h - 6), 0.85),
            (CGPoint(x: 10, y: h * 0.62), 0.9), (CGPoint(x: w - 8, y: h * 0.58), 0.95),
            (CGPoint(x: 26, y: 120), 0.95), (CGPoint(x: w - 24, y: 128), 1.0),
            (CGPoint(x: g.center.x - 210, y: h - 2), 0.55), (CGPoint(x: g.center.x + 230, y: h), 0.55),
        ]
        var rng = BogRNG(seed: 0x4055)
        var tries = 0
        let extra = Int(max(w - 952, 0) / 70)
        var added = 0
        while added < extra && tries < 2000 {
            tries += 1
            let p = CGPoint(x: rng.range(0, w), y: rng.range(100, h))
            if outside(g, p, 1.2) {
                out.append((p, rng.range(0.7, 1.2)))
                added += 1
            }
        }
        return out
    }

    /// The whole bog backdrop for a scene of `size` (the trap's shadow included).
    static func drawBackdrop(_ ctx: CGContext, size: CGSize, geometry g: TrapGeometry) {
        let pal = TrapArt.palette
        let w = size.width, h = size.height
        var rng = BogRNG(seed: 0xB06B06)

        // Base: deep at the bottom, sunlit at the top.
        BogPainter.linear(ctx, [pal.bogDeep, pal.bog, BogPaint.lighter(pal.bog, 0.14)], [0, 0.55, 1],
                          from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: h))
        BogPainter.radial(ctx, [RGBA(0.86, 1, 0.5, 0.3), RGBA(0.86, 1, 0.5, 0)], [0, 1],
                          center: CGPoint(x: w * 0.1, y: h * 1.02), radius: w * 0.55)
        BogPainter.radial(ctx, [RGBA(1, 0.95, 0.6, 0.14), RGBA(1, 0.95, 0.6, 0)], [0, 1],
                          center: CGPoint(x: w * 0.92, y: h * 0.98), radius: w * 0.35)

        // Mottled peat and moss light.
        let blobs = Int(w * h / 3800)
        for i in 0..<blobs {
            let c = CGPoint(x: rng.range(-20, w + 20), y: rng.range(-20, h + 20))
            let r = rng.range(14, 58)
            let col = i % 3 == 0 ? BogPaint.alpha(pal.bogDeep, 0.22) : BogPaint.alpha(pal.moss, 0.1)
            BogPainter.radial(ctx, [col, BogPaint.alpha(col, 0)], [0, 1], center: c, radius: r)
        }

        // Water along the bottom edge.
        drawWater(ctx, size: size, rng: &rng)

        // Reeds behind everything else at the sides.
        for side in [CGFloat(-1), CGFloat(1)] {
            for i in 0..<7 {
                let jitter = rng.range(-4, 4)
                let inset: CGFloat = 8 + CGFloat(i) * 13
                let baseX: CGFloat = side < 0 ? inset + jitter : w - inset + jitter
                let top = rng.range(150, 250)
                let lean = side * rng.range(-6, 18)
                drawReed(ctx, base: CGPoint(x: baseX, y: 52 + rng.range(-6, 6)),
                         tip: CGPoint(x: baseX + lean, y: top), width: rng.range(4, 7), shade: rng.unit())
            }
        }

        // (R3: the trap's shadow is a sprite under the lobes, so it squeezes with the bite: `drawTrapShadow`.)

        // Lily pads on the water.
        let pads: [(CGPoint, CGFloat)] = [(CGPoint(x: 52, y: 30), 30), (CGPoint(x: 150, y: 14), 22),
                                         (CGPoint(x: w - 60, y: 28), 31), (CGPoint(x: w - 158, y: 44), 20),
                                         (CGPoint(x: g.center.x - 300, y: -4), 26)]
        for (i, pad) in pads.enumerated() {
            drawLilyPad(ctx, center: pad.0, radius: pad.1, notch: CGFloat(i) * 1.7 + 0.6, flower: i == 2)
        }

        // Moss cushions.
        for (c, k) in mossSpots(size: size, geometry: g) {
            drawMoss(ctx, center: c, scale: k, rng: &rng)
        }

        // Sundews on the banks.
        let dews: [(CGPoint, CGFloat)] = [(CGPoint(x: 74, y: h - 92), 1), (CGPoint(x: w - 70, y: h - 80), 0.95),
                                         (CGPoint(x: 40, y: h - 150), 0.8), (CGPoint(x: 118, y: 96), 0.85),
                                         (CGPoint(x: w - 104, y: 104), 0.9)]
        for (c, k) in dews where outside(g, c, 1.12) {
            drawSundew(ctx, base: CGPoint(x: c.x, y: c.y - 46 * k), head: c, scale: k)
        }
        // Rosettes of spoon leaves.
        for c in [CGPoint(x: 150, y: h - 34), CGPoint(x: w - 30, y: h - 120), CGPoint(x: 30, y: 200)]
            where outside(g, c, 1.1) {
            drawRosette(ctx, center: c, scale: 0.8)
        }

        // Grass tufts along the top edge above the trap.
        for i in 0..<9 {
            let x = g.center.x - 170 + CGFloat(i) * 42 + rng.range(-8, 8)
            let tall = rng.range(16, 30)
            drawTuft(ctx, base: CGPoint(x: x, y: h + 4), height: tall, rng: &rng)
        }

        // Dew.
        for p in dewSpots(size: size, geometry: g) {
            BogPainter.dewDrop(ctx, p, rng.range(1.8, 4.2), tint: RGBA(0.85, 1, 0.92, 0.9))
        }

        // R3: the trap's petiole, from the bottom of the midrib down into the bog (so the trap is plainly a plant).
        drawPetiole(ctx, geometry: g, length: g.center.y - g.b + petioleJoin + 30)

        // Corner shade.
        for c in [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: 0, y: h), CGPoint(x: w, y: h)] {
            BogPainter.radial(ctx, [RGBA(0, 0.05, 0.02, 0.35), RGBA(0, 0.05, 0.02, 0)], [0, 1], center: c,
                              radius: 170)
        }
    }

    private static func drawWater(_ ctx: CGContext, size: CGSize, rng: inout BogRNG) {
        let w = size.width
        let water = CGMutablePath()
        // (From well below and beyond the edges: the backdrop has a bleed, so the bite's shake never shows a seam.)
        water.move(to: CGPoint(x: -30, y: -30))
        water.addLine(to: CGPoint(x: -30, y: 66))
        water.addLine(to: CGPoint(x: -4, y: 66))
        var x: CGFloat = -4
        var y: CGFloat = 66
        while x < w + 4 {
            let nx = min(x + rng.range(60, 120), w + 4)
            let ny = rng.range(46, 74)
            water.addQuadCurve(to: CGPoint(x: nx, y: ny), control: CGPoint(x: (x + nx) / 2, y: max(y, ny) + 8))
            x = nx
            y = ny
        }
        water.addLine(to: CGPoint(x: w + 30, y: y))
        water.addLine(to: CGPoint(x: w + 30, y: -30))
        water.closeSubpath()
        BogPainter.stroke(ctx, water, RGBA(hex: 0x7CC49A), width: 7, 0.35)
        BogPainter.gradient(ctx, water, [RGBA(hex: 0x0A2628), RGBA(hex: 0x123F42), RGBA(hex: 0x1C5652)],
                            [0, 0.6, 1], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 74))
        ctx.saveGState()
        ctx.addPath(water)
        ctx.clip()
        // Sky glints and ripples.
        for _ in 0..<Int(w / 60) {
            let c = CGPoint(x: rng.range(0, w), y: rng.range(6, 50))
            let rw = rng.range(14, 40)
            BogPainter.stroke(ctx, BogPainter.oval(CGRect(x: c.x - rw, y: c.y - rw * 0.22, width: 2 * rw,
                                                          height: rw * 0.44)),
                              RGBA(1, 1, 1), width: 1.2, 0.12)
        }
        for _ in 0..<Int(w / 90) {
            let c = CGPoint(x: rng.range(0, w), y: rng.range(4, 44))
            BogPainter.stroke(ctx, BogPainter.polygon([c, CGPoint(x: c.x + rng.range(18, 44), y: c.y)]),
                              RGBA(0.8, 1, 0.95), width: 1.6, 0.16)
        }
        ctx.restoreGState()
    }

    private static func drawReed(_ ctx: CGContext, base: CGPoint, tip: CGPoint, width: CGFloat, shade: CGFloat) {
        let p = CGMutablePath()
        let mid = CGPoint(x: (base.x + tip.x) / 2 + (tip.x - base.x) * 0.3, y: (base.y + tip.y) / 2)
        p.move(to: CGPoint(x: base.x - width / 2, y: base.y))
        p.addQuadCurve(to: tip, control: CGPoint(x: mid.x - width * 0.3, y: mid.y))
        p.addQuadCurve(to: CGPoint(x: base.x + width / 2, y: base.y), control: CGPoint(x: mid.x + width * 0.4, y: mid.y))
        p.closeSubpath()
        let col = RGBA(hex: 0x2F7A3A).mixed(with: RGBA(hex: 0x4E9A3A), Double(shade))
        BogPainter.stroke(ctx, p, RGBA(hex: 0x0A2414), width: 1.4, 0.6)
        BogPainter.gradient(ctx, p, [BogPaint.darker(col, 0.35), col, BogPaint.lighter(col, 0.25)], [0, 0.6, 1],
                            from: base, to: tip)
    }

    private static func drawLilyPad(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat, notch: CGFloat,
                                    flower: Bool) {
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.scaleBy(x: 1, y: 0.58)
        let pad = CGMutablePath()
        pad.move(to: .zero)
        pad.addArc(center: .zero, radius: r, startAngle: notch + 0.22, endAngle: notch - 0.22 + 2 * .pi,
                   clockwise: false)
        pad.closeSubpath()
        BogPainter.fill(ctx, BogPainter.circle(CGPoint(x: 2, y: -5), r * 1.04), RGBA(0, 0, 0), 0.3)
        BogPainter.stroke(ctx, pad, RGBA(hex: 0x0D2A16), width: 2.4, 0.85)
        BogPainter.radialFill(ctx, pad, [RGBA(hex: 0x9AD65A), RGBA(hex: 0x5FA83A), RGBA(hex: 0x2F6E2C)], [0, 0.6, 1],
                              center: CGPoint(x: -r * 0.3, y: r * 0.3), radius: r * 1.3)
        let veins = CGMutablePath()
        for i in 0..<9 {
            let a = notch + 0.5 + CGFloat(i) * (2 * .pi - 1) / 8
            veins.move(to: .zero)
            veins.addLine(to: CGPoint(x: cos(a) * r * 0.9, y: sin(a) * r * 0.9))
        }
        BogPainter.stroke(ctx, veins, RGBA(hex: 0xC6F08A), width: 1.1, 0.4)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: -r * 0.35, y: r * 0.4), r * 0.3, r * 0.12, rotation: 0.4),
                        RGBA(1, 1, 1), 0.25)
        ctx.restoreGState()
        if flower {
            let f = CGPoint(x: c.x - r * 0.25, y: c.y + r * 0.12)
            for i in 0..<7 {
                let a = CGFloat(i) / 7 * 2 * .pi
                let pc = CGPoint(x: f.x + cos(a) * 6, y: f.y + sin(a) * 4)
                let petal = BogPainter.ellipse(pc, 6.5, 3.6, rotation: a)
                BogPainter.stroke(ctx, petal, RGBA(hex: 0x6E2240), width: 1.2, 0.6)
                BogPainter.gradient(ctx, petal, [RGBA(hex: 0xFFFFFF), RGBA(hex: 0xFFB3CB)], [0, 1], from: f, to: pc)
            }
            BogPainter.fill(ctx, BogPainter.circle(f, 3.4), RGBA(hex: 0xFFD54A))
        }
    }

    private static func drawMoss(_ ctx: CGContext, center c: CGPoint, scale k: CGFloat, rng: inout BogRNG) {
        let pal = TrapArt.palette
        var bumps: [(CGPoint, CGFloat, CGFloat)] = []
        let n = 16
        for _ in 0..<n {
            let a = rng.range(0, 2 * .pi)
            let d = rng.range(0, 62) * k
            let br = rng.range(11, 26) * k
            bumps.append((CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d * 0.7), br, rng.unit()))
        }
        // Back to front (higher first: lower bumps overlap them).
        bumps.sort { $0.0.y > $1.0.y }
        for (p, br, t) in bumps {
            let base = pal.moss.mixed(with: RGBA(hex: 0x3E8A2E), Double(t))
            BogPainter.fill(ctx, BogPainter.circle(CGPoint(x: p.x + 1, y: p.y - br * 0.25), br * 1.04), RGBA(0, 0.1, 0.03),
                            0.35)
            BogPainter.radialFill(ctx, BogPainter.circle(p, br),
                                  [BogPaint.lighter(base, 0.4), base, BogPaint.darker(base, 0.45)], [0, 0.5, 1],
                                  center: CGPoint(x: p.x - br * 0.35, y: p.y + br * 0.4), radius: br * 1.5)
            // Stipple: tiny moss stars.
            for _ in 0..<5 {
                let q = CGPoint(x: p.x + rng.range(-br * 0.6, br * 0.6), y: p.y + rng.range(-br * 0.5, br * 0.6))
                BogPainter.fill(ctx, BogPainter.circle(q, rng.range(0.8, 1.8)), BogPaint.lighter(base, 0.55), 0.55)
            }
        }
    }

    private static func drawSundew(_ ctx: CGContext, base: CGPoint, head: CGPoint, scale k: CGFloat) {
        let stalk = CGMutablePath()
        stalk.move(to: base)
        stalk.addQuadCurve(to: head, control: CGPoint(x: base.x + 14 * k, y: (base.y + head.y) / 2))
        BogPainter.stroke(ctx, stalk, RGBA(hex: 0x0D2414), width: 4.6 * k, 0.7)
        BogPainter.stroke(ctx, stalk, RGBA(hex: 0x8A3A2E), width: 2.6 * k)
        let n = 15
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi + 0.2
            let len = (8 + 3 * sin(CGFloat(i) * 1.7)) * k
            let tip = CGPoint(x: head.x + cos(a) * (6 * k + len), y: head.y + sin(a) * (6 * k + len) * 0.85)
            BogPainter.stroke(ctx, BogPainter.polygon([head, tip]), RGBA(hex: 0xD8344A), width: 1.4 * k)
            BogPainter.dewDrop(ctx, tip, 2.3 * k, tint: RGBA(1, 0.9, 0.92, 0.95))
        }
        let disc = BogPainter.circle(head, 7 * k)
        BogPainter.stroke(ctx, disc, RGBA(hex: 0x3A0A12), width: 1.6 * k, 0.8)
        BogPainter.radialFill(ctx, disc, [RGBA(hex: 0xFF8A7A), RGBA(hex: 0xC8283E)], [0, 1],
                              center: CGPoint(x: head.x - 2 * k, y: head.y + 2 * k), radius: 8 * k)
    }

    private static func drawRosette(_ ctx: CGContext, center c: CGPoint, scale k: CGFloat) {
        for i in 0..<7 {
            let a = CGFloat(i) / 7 * 2 * .pi
            let tip = CGPoint(x: c.x + cos(a) * 20 * k, y: c.y + sin(a) * 15 * k)
            let leaf = BogPainter.ellipse(CGPoint(x: (c.x + tip.x) / 2, y: (c.y + tip.y) / 2), 11 * k, 4.4 * k,
                                          rotation: a)
            BogPainter.stroke(ctx, leaf, RGBA(hex: 0x2A0A10), width: 1.4, 0.6)
            BogPainter.gradient(ctx, leaf, [RGBA(hex: 0x6FAE3A), RGBA(hex: 0xC8384A)], [0, 1], from: c, to: tip)
            BogPainter.dewDrop(ctx, CGPoint(x: c.x + cos(a) * 16 * k, y: c.y + sin(a) * 12 * k), 2 * k,
                               tint: RGBA(1, 0.9, 0.92, 0.95))
        }
    }

    private static func drawTuft(_ ctx: CGContext, base: CGPoint, height: CGFloat, rng: inout BogRNG) {
        for _ in 0..<4 {
            let tip = CGPoint(x: base.x + rng.range(-10, 10), y: base.y - height * rng.range(0.6, 1))
            let blade = CGMutablePath()
            blade.move(to: CGPoint(x: base.x - 2.5, y: base.y))
            blade.addQuadCurve(to: tip, control: CGPoint(x: (base.x + tip.x) / 2 - 2, y: (base.y + tip.y) / 2))
            blade.addQuadCurve(to: CGPoint(x: base.x + 2.5, y: base.y),
                               control: CGPoint(x: (base.x + tip.x) / 2 + 2, y: (base.y + tip.y) / 2))
            blade.closeSubpath()
            BogPainter.stroke(ctx, blade, RGBA(hex: 0x0A2414), width: 1.2, 0.6)
            BogPainter.fill(ctx, blade, RGBA(hex: 0x4E9A3A).mixed(with: RGBA(hex: 0x8CCB55), Double(rng.unit())))
        }
    }

    // MARK: The lobes (scene space; the caller translates to the texture frame)

    /// R3: one lobe's static face, open: a Venus flytrap's leaf seen from above. From the outside in:
    /// - the leaf's back, only as a thin dark-green lip beyond the margin (`exteriorWidth`), outlined;
    /// - the thin lip inside the margin (`rimBand`);
    /// - the face: oxblood along the midrib → a crimson core → crimson, with a warm yellow-green blush only in the last
    ///   ~10 % before the margin; cupped (darker just under the lip), stippled with many tiny dark-red glands clustered
    ///   towards the midrib, and fine veins radiating from it. No rind, no pale dots.
    /// R6: in `variety`'s colours (`TrapArt.look`): Red Dragon crimson even on the back, Cupped deeper with a second
    /// glint, Golden Glow with a gold sheen along the rim.
    static func drawLobe(_ ctx: CGContext, side: Int, geometry g: TrapGeometry, variety: TrapVariety = .classic) {
        let pal = TrapArt.palette
        let vl = TrapArt.look(variety)
        let s: CGFloat = side < 0 ? -1 : 1
        let back = TrapArt.exteriorPath(side: side, geometry: g)
        let outer = TrapArt.lobePath(side: side, geometry: g, closure01: 0)
        let face = TrapArt.lobeFacePath(side: side, geometry: g)
        let top = CGPoint(x: g.center.x, y: g.center.y + g.b), bottom = CGPoint(x: g.center.x, y: g.center.y - g.b)
        let ia = g.a - TrapArt.rimBand, ib = g.b - TrapArt.rimBand

        // The leaf's back: a thin lip beyond the margin, lit from the top.
        BogPainter.stroke(ctx, back, vl.outline, width: 2.4, 0.9)
        BogPainter.gradient(ctx, back, [vl.leafDark, vl.leaf, BogPaint.lighter(vl.leaf, 0.14)],
                            [0, 0.55, 1], from: bottom, to: top)

        // The lip inside the margin, with a faint wet line along it.
        BogPainter.fill(ctx, outer, vl.lip)
        BogPainter.stroke(ctx, TrapArt.marginCurve(side: side, geometry: g, inset: 1.2),
                          BogPaint.lighter(vl.leaf, 0.3), width: 0.9, 0.4)

        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        // R4 (#5): the oxblood gradient across the whole lobe, from #892934 by the midrib to crimson (≤ #C02A42) at
        // the margin, by distance from the midrib (so the lobe's base by the notches is dark too).
        BogPainter.linear(ctx, vl.faceStops.map { $0.1 }, vl.faceStops.map { $0.0 },
                          from: CGPoint(x: g.center.x, y: g.center.y), to: CGPoint(x: g.center.x + s * ia, y: g.center.y))
        // Cupped: a little deeper towards the middle of the face (never lighter than the stops). R6: the Cupped Trap
        // is twice as deep.
        let cupK = vl.cupStrength
        BogPainter.ellipticalRadial(ctx, [BogPaint.alpha(vl.cup, min(0.4 * cupK, 0.85)),
                                          BogPaint.alpha(vl.cup, min(0.18 * cupK, 0.6)), BogPaint.alpha(vl.cup, 0)],
                                    [0, 0.45, 0.85], center: g.center, rx: g.a * 0.6, ry: g.b * 0.98)
        // Glands: many tiny darker dots, clustered towards the midrib (never pale).
        var rng = BogRNG(seed: side < 0 ? 0x61A9D : 0x61A9E)
        let dots = CGMutablePath()
        let darkDots = CGMutablePath()
        for i in 0..<1300 {
            let u = rng.unit(), v = rng.unit()
            let fx = pow(u, 1.8) * 0.95
            let span = ib * max(1 - fx * fx, 0).squareRoot() * 0.96
            let q = CGPoint(x: g.center.x + s * fx * ia, y: g.center.y + (2 * v - 1) * span)
            let pr = rng.range(0.55, 1.45) * (1.15 - 0.45 * fx)
            let rect = CGRect(x: q.x - pr, y: q.y - pr, width: 2 * pr, height: 2 * pr)
            if i % 3 == 0 { darkDots.addEllipse(in: rect) } else { dots.addEllipse(in: rect) }
        }
        BogPainter.fill(ctx, dots, RGBA(hex: 0x3A0612), min(0.32 * vl.glands, 1))
        BogPainter.fill(ctx, darkDots, RGBA(hex: 0x26020A), min(0.5 * vl.glands, 1))
        // Fine veins radiating from the midrib.
        let veins = TrapArt.veinsPath(side: side, geometry: g)
        BogPainter.stroke(ctx, veins, RGBA(hex: 0x3A0612), width: 1.5, 0.3)
        ctx.saveGState()
        ctx.translateBy(x: 0.7, y: 0.9)
        BogPainter.stroke(ctx, veins, BogPaint.lighter(pal.lobeOuter, 0.3), width: 0.6, 0.13)
        ctx.restoreGState()
        // R4 (#5): the blush, yellow-green, only in the last ~9 % of the face's radius (≤ 38 %: never a peach band),
        // and never along the midrib (the notches sit well inside it).
        drawBlush(ctx, center: g.center, rx: ia, ry: ib, color: vl.blush, maxAlpha: vl.blushAlpha)
        // Cupped: the face falls into a little shadow just under the lip.
        let rim = TrapArt.marginCurve(side: side, geometry: g, inset: TrapArt.rimBand)
        BogPainter.stroke(ctx, rim, RGBA(hex: 0x2A0A10), width: 3 * CGFloat(min(cupK, 2)), min(0.22 * cupK, 0.5))
        if vl.gloss > 1.3 {
            // R6 (Cupped Trap): a second wet glint low on the deep face.
            let c = CGPoint(x: g.center.x + s * g.a * 0.46, y: g.center.y - g.b * 0.42)
            BogPainter.fill(ctx, BogPainter.ellipse(c, 70, 16, rotation: s * 0.35), RGBA(1, 0.94, 0.96), 0.14)
            BogPainter.fill(ctx, BogPainter.ellipse(c, 34, 6, rotation: s * 0.35), RGBA(1, 1, 1), 0.3)
        }
        ctx.restoreGState()

        // The lip's inner crease.
        BogPainter.stroke(ctx, face, RGBA(0.1, 0.02, 0.03), width: 1.2, 0.45)
        if let gold = vl.sheen {
            // R6 (Golden Glow): a gold sheen along the rim, brightest at the top.
            let m = TrapArt.marginCurve(side: side, geometry: g, inset: 1.5)
            BogPainter.stroke(ctx, m, gold, width: 7, 0.25)
            BogPainter.stroke(ctx, m, gold, width: 3, 0.85)
            BogPainter.stroke(ctx, m, RGBA(1, 0.98, 0.85), width: 1, 0.7)
        }
    }

    /// R4 (#5): the blush's alpha at normalised face radius `r` (0 centre … 1 the margin): 0 until
    /// `TrapArt.blushStart`, then rising smoothly to `TrapArt.blushAlpha` at the margin.
    static func blushAlpha(at r: CGFloat) -> Double {
        // Weighted hard towards the lip (R4, the Duo's store-03: the R3 band was ~40 pt of stacked strokes): most of
        // the colour sits in the last ~4 %, so it reads as the leaf's margin, never as a band.
        let u = Double(BogMath.smoothstep(TrapArt.blushStart, 1, r))
        return TrapArt.blushAlpha * pow(u, 2.5)
    }

    /// The blush ring (normal alpha) over a face of semi-axes `rx`, `ry` about `center`; the caller clips to the face.
    static func drawBlush(_ ctx: CGContext, center: CGPoint, rx: CGFloat, ry: CGFloat, color: RGBA = TrapArt.blush,
                          maxAlpha: Double = TrapArt.blushAlpha) {
        let stops: [CGFloat] = [0, TrapArt.blushStart, 0.93, 0.95, 0.965, 0.978, 0.99, 1]
        let k = TrapArt.blushAlpha > 0 ? maxAlpha / TrapArt.blushAlpha : 0
        let colors = stops.map { BogPaint.alpha(color, blushAlpha(at: $0) * k) }
        BogPainter.ellipticalRadial(ctx, colors, stops, center: center, rx: rx, ry: ry, extend: true)
    }

    /// A lobe's silhouette, back included (white: the day overlay and the hunger wilt are tinted copies).
    static func drawLobeSilhouette(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        BogPainter.fill(ctx, TrapArt.exteriorPath(side: side, geometry: g), RGBA(1, 1, 1))
    }

    /// R6 (#17): the lobe's face alone, inside the lip (white: the tired trap's dim and the hunger wilt are tinted
    /// copies, so the green margin and back never darken).
    static func drawLobeFaceSilhouette(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        BogPainter.fill(ctx, TrapArt.lobeFacePath(side: side, geometry: g), RGBA(1, 1, 1))
    }

    /// The closure shade: dark from normalised radius `start` out to the edge (and over the back).
    static func drawLobeShade(_ ctx: CGContext, side: Int, geometry g: TrapGeometry, start: CGFloat) {
        let outer = TrapArt.lobeShape(side: side, geometry: g, inset: -(TrapArt.exteriorWidth + 2))
        ctx.saveGState()
        ctx.addPath(outer)
        ctx.clip()
        let dark = RGBA(hex: 0x24030D)
        BogPainter.ellipticalRadial(ctx, [BogPaint.alpha(dark, 0), BogPaint.alpha(dark, 0), BogPaint.alpha(dark, 0.6),
                                          BogPaint.alpha(dark, 0.95)],
                                    [0, max(min(start, 0.95), 0), max(min(start + (1 - start) * 0.6, 0.98), 0.01), 1],
                                    center: g.center, rx: g.a, ry: g.b, extend: true)
        ctx.restoreGState()
    }

    /// R3: one soft wet specular per lobe, high on the outer face (white; the scene slides and fades it).
    static func drawGloss(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        let s: CGFloat = side < 0 ? -1 : 1
        let face = TrapArt.lobeFacePath(side: side, geometry: g)
        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        func streak(_ t0: CGFloat, _ t1: CGFloat, _ r: CGFloat, _ thick: CGFloat) -> CGPath {
            let p = CGMutablePath()
            let n = 40
            var outerPts: [CGPoint] = []
            var innerPts: [CGPoint] = []
            for i in 0...n {
                let u = CGFloat(i) / CGFloat(n)
                let t = t0 + (t1 - t0) * u
                let k = sin(.pi * u)
                let ro = r + thick * k * 0.5, ri = r - thick * k * 0.5
                outerPts.append(CGPoint(x: g.center.x + s * g.a * ro * cos(t), y: g.center.y + g.b * ro * sin(t)))
                innerPts.append(CGPoint(x: g.center.x + s * g.a * ri * cos(t), y: g.center.y + g.b * ri * sin(t)))
            }
            p.move(to: outerPts[0])
            for q in outerPts.dropFirst() { p.addLine(to: q) }
            for q in innerPts.reversed() { p.addLine(to: q) }
            p.closeSubpath()
            return p
        }
        // A broad soft sheen, then the one streak (soft halo passes, then a crisp core). R4 (#5): fainter, so the face
        // samples crimson (≤ #C02A42), not salmon.
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 0.94, 0.96, 0.06), RGBA(1, 0.94, 0.96, 0)], [0, 1],
                                    center: CGPoint(x: g.center.x + s * g.a * 0.52, y: g.center.y + g.b * 0.46),
                                    rx: 150, ry: 84)
        for (thick, a) in [(CGFloat(0.13), 0.04), (CGFloat(0.085), 0.09), (CGFloat(0.048), 0.2),
                           (CGFloat(0.022), 0.55)] {
            BogPainter.fill(ctx, streak(1.1, 0.48, 0.72, thick), RGBA(1, 1, 1), a)
        }
        ctx.restoreGState()
    }

    /// R3 (#1): the closed trap for the bite's hold, in scene space about the trap centre: both lobes pressed shut
    /// (squeezed to `slamSqueeze`), lit crimson on their bulge and darkening into the seam, a dark interior between the
    /// margins, the cilia interlocked across it like laced fingers, a thin dark-green lip round each lobe, one soft
    /// specular each. Everything lies inside the open trap's outline (`TrapArt.closedTrapPath`).
    static func drawClosedTrap(_ ctx: CGContext, geometry g: TrapGeometry, variety: TrapVariety = .classic) {
        let vl = TrapArt.look(variety)
        let k = TrapArt.slamSqueeze
        let cx = g.center.x, cy = g.center.y
        let halfW = (g.a + TrapArt.exteriorWidth) * k
        for side in [-1, 1] {
            let s = CGFloat(side)
            let shell = TrapArt.closedLobePath(side: side, geometry: g, inset: -TrapArt.exteriorWidth)
            let body = TrapArt.closedLobePath(side: side, geometry: g, inset: 0)
            BogPainter.stroke(ctx, shell, vl.outline, width: 2.4, 0.9)
            BogPainter.fill(ctx, shell, vl.leaf)
            ctx.saveGState()
            ctx.addPath(body)
            ctx.clip()
            // R4 (#6): a shut flytrap from above shows its green leaf backs. The outer part of each closed lobe is leaf
            // green (lit on its bulge); crimson shows only in a narrow band at the seam, falling into the dark interior.
            // (R6: Red Dragon's backs are crimson too.)
            BogPainter.linear(ctx, vl.closedStops.map { $0.1 }, vl.closedStops.map { $0.0 },
                              from: CGPoint(x: cx + s * halfW, y: cy), to: CGPoint(x: cx, y: cy))
            // A few fine veins on the green backs, running out from the seam (it reads as a leaf, not a pod).
            let veins = CGMutablePath()
            let h0 = g.b - TrapArt.notchDepth
            for i in 0..<7 {
                let u = (CGFloat(i) + 0.5) / 7
                let y0 = cy + h0 * 0.85 * (1 - 2 * u)
                let y1 = cy + (g.b - 10) * (1 - 2 * u) * 1.02
                veins.move(to: CGPoint(x: cx + s * halfW * 0.42, y: y0))
                veins.addQuadCurve(to: CGPoint(x: cx + s * halfW * 0.95, y: y1),
                                   control: CGPoint(x: cx + s * halfW * 0.8, y: y0 + (y1 - y0) * 0.25))
            }
            BogPainter.stroke(ctx, veins, BogPaint.lighter(vl.leaf, 0.35), width: 1.1, 0.3)
            // Rounded: darker towards the ends.
            BogPainter.linear(ctx, [RGBA(0.02, 0.06, 0.02, 0.5), RGBA(0.02, 0.06, 0.02, 0), RGBA(0.02, 0.06, 0.02, 0),
                                    RGBA(0.02, 0.06, 0.02, 0.5)], [0, 0.24, 0.76, 1],
                              from: CGPoint(x: cx, y: cy - g.b), to: CGPoint(x: cx, y: cy + g.b))
            // One soft specular on the green bulge.
            BogPainter.ellipticalRadial(ctx, [RGBA(1, 1, 1, 0.34), RGBA(1, 1, 1, 0.1), RGBA(1, 1, 1, 0)], [0, 0.45, 1],
                                        center: CGPoint(x: cx + s * halfW * 0.62, y: cy + g.b * 0.36),
                                        rx: halfW * 0.2, ry: g.b * 0.2)
            ctx.restoreGState()
            BogPainter.stroke(ctx, shell, BogPaint.lighter(vl.leaf, 0.3), width: 0.9, 0.4)
            if let gold = vl.sheen { BogPainter.stroke(ctx, shell, gold, width: 2.2, 0.8) }
        }
        // The dark interior between the margins.
        let h = g.b - TrapArt.notchDepth
        let seam = CGMutablePath()
        seam.move(to: CGPoint(x: cx, y: cy + h))
        seam.addQuadCurve(to: CGPoint(x: cx, y: cy - h), control: CGPoint(x: cx + 18, y: cy))
        seam.addQuadCurve(to: CGPoint(x: cx, y: cy + h), control: CGPoint(x: cx - 18, y: cy))
        seam.closeSubpath()
        BogPainter.fill(ctx, seam, TrapArt.interior)
        // The cilia, interlocked across the seam: a soft shadow, then each lobe's row from its base to its tip.
        let cilia = TrapArt.interlockedCilia(geometry: g)
        for side in [-1, 1] {
            let s = CGFloat(side)
            let row = CGMutablePath()
            for c in cilia where (c.root.x < cx) == (side < 0) {
                // R6: the variety's cut, its length capped so the row never leaves the closed trap.
                let len = min(c.length * vl.toothLength, halfW * 0.9)
                let shape = TrapArt.toothShape(length: len, width: 3.2 * min(vl.toothWidth, 3), curl: c.curl,
                                               kind: vl.tooth)
                row.addPath(shape, transform: CGAffineTransform(translationX: c.root.x, y: c.root.y)
                    .rotated(by: c.angle - .pi / 2))
            }
            ctx.saveGState()
            ctx.translateBy(x: 1.2, y: -2)
            BogPainter.fill(ctx, row, RGBA(0.05, 0, 0.02), 0.4)
            ctx.restoreGState()
            BogPainter.stroke(ctx, row, vl.outline, width: 1.2, 0.8)
            BogPainter.gradient(ctx, row, [vl.ciliaBase, vl.ciliaMid, vl.ciliaTip], [0, 0.45, 1],
                                from: CGPoint(x: cx + s * 12, y: cy), to: CGPoint(x: cx - s * 26, y: cy))
        }
    }

    /// R3 (#10): the rim light on one lobe (white; additive, tinted by the day: gold morning, peach dusk, moonlight):
    /// soft along the margin, strongest at the top where the low light comes from.
    static func drawLobeGlow(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        let face = TrapArt.lobeFacePath(side: side, geometry: g)
        let rim = TrapArt.marginCurve(side: side, geometry: g, inset: TrapArt.rimBand)
        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        // R4: a thin rim (≤ ~10 pt in), never a broad band (the Duo's dusk frame read as a cream rind).
        for i in 0..<5 {
            BogPainter.stroke(ctx, rim, RGBA(1, 1, 1), width: 3 + CGFloat(i) * 4, 0.17)
        }
        // Fade the lower half out (the light comes from above).
        ctx.setBlendMode(.destinationOut)
        BogPainter.linear(ctx, [RGBA(1, 1, 1, 0.85), RGBA(1, 1, 1, 0.35), RGBA(1, 1, 1, 0)], [0, 0.45, 1],
                          from: CGPoint(x: g.center.x, y: g.center.y - g.b), to: CGPoint(x: g.center.x, y: g.center.y + g.b))
        ctx.restoreGState()
    }

    /// R3: the trap's soft shadow on the bog (white: the sprite tints it dark), filling `size`.
    static func drawTrapShadow(_ ctx: CGContext, size: CGSize) {
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 1, 1, 1), RGBA(1, 1, 1, 0.9), RGBA(1, 1, 1, 0)], [0, 0.84, 1],
                                    center: CGPoint(x: size.width / 2, y: size.height / 2), rx: size.width / 2,
                                    ry: size.height / 2)
    }

    /// R3: the petiole, the flat leaf stalk from the bottom of the midrib (`petioleJoin` above the trap's lowest
    /// point, inside the notch) `length` points down into the bog, widening as it goes.
    static func drawPetiole(_ ctx: CGContext, geometry g: TrapGeometry, length: CGFloat) {
        let top = CGPoint(x: g.center.x, y: g.center.y - g.b + petioleJoin)
        let L = max(length, 20)
        let n = 24
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        let vein = CGMutablePath()
        for i in 0...n {
            let u = CGFloat(i) / CGFloat(n)
            let y = top.y - L * u
            let sway = 6 * sin(u * 1.6)
            let hw = 5 + 28 * BogMath.smoothstep(0.1, 0.8, u) * (1 - 0.15 * u)
            left.append(CGPoint(x: top.x + sway - hw, y: y))
            right.append(CGPoint(x: top.x + sway + hw, y: y))
            let v = CGPoint(x: top.x + sway, y: y)
            if i == 0 { vein.move(to: v) } else { vein.addLine(to: v) }
        }
        let p = CGMutablePath()
        p.move(to: left[0])
        for q in left.dropFirst() { p.addLine(to: q) }
        for q in right.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        ctx.saveGState()
        ctx.translateBy(x: 3, y: -4)
        BogPainter.fill(ctx, p, RGBA(0, 0.04, 0.02), 0.35)
        ctx.restoreGState()
        BogPainter.stroke(ctx, p, TrapArt.lobeOutline, width: 2, 0.85)
        BogPainter.gradient(ctx, p, [BogPaint.lighter(TrapArt.petiole, 0.22), TrapArt.petiole,
                                     BogPaint.darker(TrapArt.petiole, 0.3)], [0, 0.5, 1],
                            from: CGPoint(x: top.x - 30, y: top.y), to: CGPoint(x: top.x + 30, y: top.y))
        BogPainter.stroke(ctx, vein, BogPaint.lighter(TrapArt.petiole, 0.45), width: 1.6, 0.55)
    }

    /// The midrib in scene space: the narrow dark gap between the lobes at its ends, then the seam itself (a dark
    /// oxblood lens with a fine wet ridge and a crease).
    static func drawMidrib(_ ctx: CGContext, geometry g: TrapGeometry) {
        let pal = TrapArt.palette
        BogPainter.fill(ctx, TrapArt.seamGapPath(geometry: g), TrapArt.interior, 0.92)
        let p = TrapArt.midribPath(geometry: g)
        let cx = g.center.x
        let half = g.b - TrapArt.notchDepth
        BogPainter.stroke(ctx, p, TrapArt.interior, width: 2, 0.55)
        BogPainter.gradient(ctx, p, [BogPaint.darker(pal.lobeInner, 0.35), BogPaint.lighter(pal.lobeInner, 0.12),
                                     pal.lobeInner, BogPaint.darker(pal.lobeInner, 0.45)],
                            [0, 0.42, 0.6, 1], from: CGPoint(x: cx - 26, y: g.center.y),
                            to: CGPoint(x: cx + 26, y: g.center.y))
        let ridge = CGMutablePath()
        ridge.move(to: CGPoint(x: cx - 3, y: g.center.y + half - 24))
        ridge.addQuadCurve(to: CGPoint(x: cx - 3, y: g.center.y - half + 24),
                           control: CGPoint(x: cx - 8, y: g.center.y))
        BogPainter.stroke(ctx, ridge, pal.lobeGloss, width: 3.4, 0.12)
        BogPainter.stroke(ctx, ridge, pal.lobeGloss, width: 1.2, 0.4)
        BogPainter.stroke(ctx, BogPainter.polygon([CGPoint(x: cx + 2.5, y: g.center.y + half - 12),
                                                   CGPoint(x: cx + 2.5, y: g.center.y - half + 12)]),
                          TrapArt.interior, width: 1.6, 0.6)
    }

    /// The fold band across the whole scene height (only with a real fold): a soft crease shadow (white; tint black).
    static func drawFoldBand(_ ctx: CGContext, size: CGSize) {
        BogPainter.linear(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0.85), RGBA(1, 1, 1, 1), RGBA(1, 1, 1, 0.85),
                                RGBA(1, 1, 1, 0)], [0, 0.3, 0.5, 0.7, 1],
                          from: CGPoint(x: 0, y: 0), to: CGPoint(x: size.width, y: 0))
    }

    /// One cilium (the reference size) for the sprites: a subtle shadow, a thin dark keyline, green at the base to
    /// pale green to cream at the tip.
    static func drawTooth(_ ctx: CGContext, size: CGSize, curl: CGFloat, variety: TrapVariety = .classic) {
        let vl = TrapArt.look(variety)
        let L = toothTexLength * vl.toothLength, W = toothTexWidth * vl.toothWidth
        let shape = TrapArt.toothShape(length: L, width: W, curl: curl, kind: vl.tooth)
        ctx.saveGState()
        ctx.translateBy(x: size.width / 2, y: toothRootY)
        ctx.saveGState()
        ctx.translateBy(x: 1.6, y: -1.4)
        BogPainter.fill(ctx, shape, RGBA(0.02, 0.06, 0.02), 0.3)
        ctx.restoreGState()
        BogPainter.stroke(ctx, shape, vl.outline, width: 1.1, 0.7)
        BogPainter.gradient(ctx, shape, [vl.ciliaBase, vl.ciliaMid, vl.ciliaTip], [0.05, 0.5, 1],
                            from: CGPoint(x: 0, y: 0), to: CGPoint(x: curl * 4, y: L))
        if vl.tooth == .cilia {
            let shine = CGMutablePath()
            shine.move(to: CGPoint(x: -W * 0.16, y: 4))
            shine.addQuadCurve(to: CGPoint(x: curl * 3.4 * vl.toothLength - 0.3, y: L - 6),
                               control: CGPoint(x: -W * 0.18, y: L * 0.6))
            BogPainter.stroke(ctx, shine, RGBA(1, 1, 1), width: 0.7 * vl.toothWidth, 0.45)
        } else {
            // The cut teeth catch the light on their leading edge.
            let edge = CGMutablePath()
            edge.move(to: CGPoint(x: -W * 0.42, y: 0))
            edge.addLine(to: CGPoint(x: -W * 0.08, y: L * 0.8))
            BogPainter.stroke(ctx, edge, RGBA(1, 1, 1), width: 0.9, 0.35)
        }
        if let gold = vl.sheen { BogPainter.stroke(ctx, shape, gold, width: 0.8, 0.6) }
        ctx.restoreGState()
    }

    /// R6: the tooth texture's size for `variety` (Classic: `toothTexSize`), room for its reference tooth.
    static func varietyToothTexSize(_ variety: TrapVariety) -> CGSize {
        let vl = TrapArt.look(variety)
        let L = toothTexLength * vl.toothLength, W = toothTexWidth * vl.toothWidth
        if variety == .classic { return toothTexSize }
        return CGSize(width: max(toothTexSize.width, (W * 1.25 + 15).rounded(.up)), height: (L * 1.3 + 9).rounded(.up))
    }

    /// A glistening drop of translucent amber nectar, radius `r`, centred in `size` (R2: the face shows through it,
    /// so it reads as a liquid bead, not a gold coin).
    static func drawNectar(_ ctx: CGContext, size: CGSize, radius r: CGFloat) {
        let pal = TrapArt.palette
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + r * 0.08)
        BogPainter.ellipticalRadial(ctx, [RGBA(0.2, 0, 0.05, 0.4), RGBA(0.2, 0, 0.05, 0)], [0, 1],
                                    center: CGPoint(x: c.x + 1.5, y: c.y - r * 0.4), rx: r * 1.25, ry: r * 0.75)
        let dome = BogPainter.circle(c, r)
        BogPainter.radialFill(ctx, dome, [RGBA(1, 0.95, 0.75, 0.8), BogPaint.alpha(pal.nectar, 0.55),
                                          BogPaint.alpha(BogPaint.darker(pal.nectar, 0.3), 0.8)],
                              [0, 0.5, 1], center: CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.35), radius: r * 1.5)
        // Light caught inside the bead (lower right), as in a real drop.
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 0.85, 0.4, 0.55), RGBA(1, 0.85, 0.4, 0)], [0, 1],
                                    center: CGPoint(x: c.x + r * 0.3, y: c.y - r * 0.35), rx: r * 0.55, ry: r * 0.4)
        BogPainter.stroke(ctx, dome, BogPaint.darker(pal.nectar, 0.55), width: max(r * 0.1, 0.8), 0.55)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x + r * 0.28, y: c.y - r * 0.38), r * 0.36, r * 0.17,
                                                rotation: 0.35), RGBA(1, 0.98, 0.8), 0.35)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x - r * 0.32, y: c.y + r * 0.36), r * 0.34, r * 0.2,
                                                rotation: 0.6), RGBA(1, 1, 1), 0.95)
        BogPainter.fill(ctx, BogPainter.circle(CGPoint(x: c.x + r * 0.08, y: c.y + r * 0.58), r * 0.08), RGBA(1, 1, 1),
                        0.85)
    }

    /// A trigger hair seen from above: a fine crimson bristle from a small bulb, pale only at the very tip (R2: thin and
    /// in the face's colour, so the hairs never read as seeds). Size ≈ 14 × 24.
    static func drawHair(_ ctx: CGContext, size: CGSize) {
        let pal = TrapArt.palette
        let base = CGPoint(x: size.width / 2, y: 5)
        let tip = CGPoint(x: size.width / 2 + 1.5, y: size.height - 2)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: base.x - 1.3, y: base.y))
        p.addQuadCurve(to: tip, control: CGPoint(x: base.x - 0.4, y: size.height * 0.6))
        p.addQuadCurve(to: CGPoint(x: base.x + 1.3, y: base.y), control: CGPoint(x: base.x + 1.1, y: size.height * 0.6))
        p.closeSubpath()
        BogPainter.stroke(ctx, p, BogPaint.darker(pal.lobeInner, 0.45), width: 1.2, 0.6)
        BogPainter.gradient(ctx, p, [BogPaint.lighter(pal.lobeOuter, 0.1), BogPaint.lighter(pal.lobeOuter, 0.3),
                                     RGBA(1, 0.9, 0.9)], [0, 0.75, 1], from: base, to: tip)
        let bulb = BogPainter.circle(base, 2.6)
        BogPainter.stroke(ctx, bulb, BogPaint.darker(pal.lobeInner, 0.4), width: 1.2, 0.7)
        BogPainter.radialFill(ctx, bulb, [RGBA(1, 0.85, 0.9), BogPaint.lighter(pal.lobeOuter, 0.2)], [0, 1],
                              center: CGPoint(x: base.x - 1, y: base.y + 1), radius: 4)
    }

    /// A nectar glisten (pale green-gold, glossy droplets; never gore: the game is 4+) filling `size`.
    static func drawSplat(_ ctx: CGContext, size: CGSize, seed: UInt64) {
        var rng = BogRNG(seed: seed)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = min(size.width, size.height) * 0.3
        // R6: caught-bug juice is nectar gold everywhere (never beige, never red: 4+).
        let juice = RGBA(hex: 0xFFD866)
        let edge = RGBA(hex: 0xD9A21E)
        var pts: [CGPoint] = []
        let n = 13
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let rr = R * rng.range(0.7, 1.2)
            pts.append(CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr))
        }
        let blob = CGMutablePath()
        let m0 = CGPoint(x: (pts[n - 1].x + pts[0].x) / 2, y: (pts[n - 1].y + pts[0].y) / 2)
        blob.move(to: m0)
        for i in 0..<n {
            let a = pts[i], b = pts[(i + 1) % n]
            blob.addQuadCurve(to: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), control: a)
        }
        blob.closeSubpath()
        for _ in 0..<8 {
            let a = rng.range(0, 2 * .pi)
            let d = R * rng.range(1.25, 1.9)
            let dr = R * rng.range(0.08, 0.2)
            blob.addEllipse(in: CGRect(x: c.x + cos(a) * d - dr, y: c.y + sin(a) * d - dr, width: 2 * dr, height: 2 * dr))
        }
        BogPainter.stroke(ctx, blob, edge, width: 2.2, 0.8)
        BogPainter.radialFill(ctx, blob, [RGBA(hex: 0xFFF6C8), juice, RGBA(hex: 0xF2B630)], [0, 0.5, 1],
                              center: CGPoint(x: c.x - R * 0.3, y: c.y + R * 0.3), radius: R * 2)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x - R * 0.3, y: c.y + R * 0.32), R * 0.3, R * 0.14,
                                                rotation: 0.5), RGBA(1, 1, 1), 0.8)
    }

    /// Three motion lines (white), trailing to the left, bright at the right end.
    static func drawWhiff(_ ctx: CGContext, size: CGSize) {
        for (y, len) in [(CGFloat(0.25), CGFloat(0.7)), (0.5, 1.0), (0.75, 0.6)] {
            let p = CGMutablePath()
            let yy = size.height * y
            p.move(to: CGPoint(x: size.width * (1 - len), y: yy))
            p.addLine(to: CGPoint(x: size.width - 3, y: yy))
            ctx.saveGState()
            ctx.addPath(p)
            ctx.setLineWidth(3)
            ctx.setLineCap(.round)
            ctx.replacePathWithStrokedPath()
            ctx.clip()
            BogPainter.linear(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 1)], [0, 1],
                              from: CGPoint(x: size.width * (1 - len), y: yy), to: CGPoint(x: size.width, y: yy))
            ctx.restoreGState()
        }
    }

    /// A startle burst: three short strokes fanning up (white with a dark edge).
    static func drawStartle(_ ctx: CGContext, size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height * 0.2)
        let p = CGMutablePath()
        for a in [CGFloat(0.95), 1.5708, 2.19] {
            p.move(to: CGPoint(x: c.x + cos(a) * size.width * 0.18, y: c.y + sin(a) * size.height * 0.18))
            p.addLine(to: CGPoint(x: c.x + cos(a) * size.width * 0.44, y: c.y + sin(a) * size.height * 0.7))
        }
        BogPainter.stroke(ctx, p, TrapArt.outline, width: 5, 0.8)
        BogPainter.stroke(ctx, p, RGBA(1, 1, 1), width: 2.6)
    }

    /// A cross "anger" mark (red with a white edge).
    static func drawAnger(_ ctx: CGContext, size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = min(size.width, size.height) * 0.36
        let p = CGMutablePath()
        for i in 0..<4 {
            let a = CGFloat(i) * .pi / 2 + .pi / 4
            let q = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            p.move(to: CGPoint(x: c.x + cos(a) * r * 0.35 + cos(a + .pi / 2) * r * 0.4,
                               y: c.y + sin(a) * r * 0.35 + sin(a + .pi / 2) * r * 0.4))
            p.addQuadCurve(to: CGPoint(x: c.x + cos(a) * r * 0.35 - cos(a + .pi / 2) * r * 0.4,
                                       y: c.y + sin(a) * r * 0.35 - sin(a + .pi / 2) * r * 0.4), control: q)
        }
        BogPainter.stroke(ctx, p, RGBA(1, 1, 1), width: 4.4)
        BogPainter.stroke(ctx, p, TrapArt.palette.danger, width: 2.4)
    }

    /// A soft annulus (white; tint it): bright at `peak` of the radius.
    static func drawRing(_ ctx: CGContext, size: CGSize, peak: CGFloat, width: CGFloat) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let lo = max(peak - width, 0.01), hi = min(peak + width, 0.999)
        BogPainter.radial(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 1), RGBA(1, 1, 1, 0),
                                RGBA(1, 1, 1, 0)], [0, lo, peak, hi, 1], center: c, radius: size.width / 2)
    }

    /// The protected halo: a crisp ring with a soft glow either side (white; tint it).
    static func drawHalo(_ ctx: CGContext, size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        BogPainter.radial(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0.35), RGBA(1, 1, 1, 1),
                                RGBA(1, 1, 1, 0.3), RGBA(1, 1, 1, 0)], [0, 0.66, 0.8, 0.86, 0.91, 1], center: c,
                          radius: size.width / 2)
    }

    /// R2: a protected bug's ring: a crisp 3 pt circle of radius `r` in `color` (centred in `size`), a thin dark
    /// keyline inside and a faint glow outside, so it reads on the crimson face and on the bog alike.
    static func drawProtectedRing(_ ctx: CGContext, size: CGSize, radius r: CGFloat, color: RGBA) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        BogPainter.stroke(ctx, BogPainter.circle(c, r), color, width: 8, 0.16)
        BogPainter.stroke(ctx, BogPainter.circle(c, r - 2.1), RGBA(0.1, 0.03, 0.05), width: 1.2, 0.4)
        BogPainter.stroke(ctx, BogPainter.circle(c, r), color, width: 3)
    }

}

extension TrapArt {
    /// R3 (#11): the snaps row's glyph, a mini closed flytrap seen from above: two crimson lobes pressed shut along a
    /// dark seam (left to right), their cilia interlocked across it, a thin dark-green lip, one glint. `empty`: a
    /// spent slot, the same trap as a grey outline. Fills `size` (≈ 30 × 22). Pure CoreGraphics (y up).
    static func drawSnapGlyph(_ ctx: CGContext, size: CGSize, empty: Bool = false, variety: TrapVariety = .classic) {
        if size.width < smallGlyphWidth {
            drawSmallSnapGlyph(ctx, size: size, empty: empty, variety: variety)
            return
        }
        let vl = look(variety)
        let w = size.width, h = size.height
        let c = CGPoint(x: w / 2, y: h / 2)
        let rx = w * 0.43, ry = h * 0.36
        let gapY = max(h * 0.025, 0.4)
        func half(_ sy: CGFloat) -> CGPath {
            let p = CGMutablePath()
            let n = 36
            for i in 0...n {
                let t = CGFloat.pi * CGFloat(i) / CGFloat(n)        // 0 … π: right end → left end
                // A clam's margin: fullest in the middle, a little dip at each end (the midrib's notches).
                let ends = exp(-pow(sin(t) / 0.32, 2))
                let q = CGPoint(x: c.x + rx * cos(t), y: c.y + sy * (gapY + (ry - gapY) * sin(t) * (1 - 0.35 * ends)))
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            p.closeSubpath()
            return p
        }
        let upper = half(1), lower = half(-1)
        let both = CGMutablePath()
        both.addPath(upper)
        both.addPath(lower)
        let seam = BogPainter.polygon([CGPoint(x: c.x - rx * 0.92, y: c.y), CGPoint(x: c.x + rx * 0.92, y: c.y)])
        if empty {
            BogPainter.stroke(ctx, both, RGBA(0.66, 0.68, 0.64), width: max(h * 0.06, 1), 0.9)
            BogPainter.stroke(ctx, seam, RGBA(0.66, 0.68, 0.64), width: max(h * 0.04, 0.8), 0.6)
            return
        }
        // The thin dark-green lip (the half outside each lobe shows), then each lobe's crimson.
        BogPainter.stroke(ctx, both, vl.outline, width: max(h * 0.1, 1.6), 0.95)
        BogPainter.stroke(ctx, both, vl.sheen ?? vl.leaf, width: max(h * 0.05, 0.8))
        // R4 (#6, #15): the shut trap's green leaf backs, crimson only by the seam (R6: in the variety's colours).
        for (path, sy) in [(upper, CGFloat(1)), (lower, CGFloat(-1))] {
            BogPainter.gradient(ctx, path, [BogPaint.lighter(vl.leaf, 0.22), vl.leaf, vl.leaf, vl.glyphCore,
                                            vl.glyphOuter, vl.glyphInner], [0, 0.3, 0.55, 0.7, 0.84, 1],
                                from: CGPoint(x: c.x, y: c.y + sy * ry), to: CGPoint(x: c.x, y: c.y))
        }
        // The dark interior along the seam.
        BogPainter.stroke(ctx, seam, interior, width: max(h * 0.07, 1.1))
        // Interlocked cilia: the upper lobe's cross down, the lower lobe's cross up, alternating.
        let cilia = CGMutablePath()
        let n = 6
        for i in 0..<n {
            let u = (CGFloat(i) + 0.5) / CGFloat(n)
            let x = c.x - rx * 0.78 + u * rx * 1.56
            let reach = h * 0.12 * (0.75 + 0.25 * sin(.pi * u))
            cilia.move(to: CGPoint(x: x - 0.3, y: c.y + reach))
            cilia.addLine(to: CGPoint(x: x + 0.3, y: c.y - reach))
            if i < n - 1 {
                let x2 = x + rx * 0.78 / CGFloat(n)
                cilia.move(to: CGPoint(x: x2 + 0.3, y: c.y - reach))
                cilia.addLine(to: CGPoint(x: x2 - 0.3, y: c.y + reach))
            }
        }
        // R6: chunkier strokes for the cut teeth (B52, Sawtooth, Shark Tooth, Fused Tooth).
        let chunk = min(max(vl.toothWidth, 1), 2.2)
        BogPainter.stroke(ctx, cilia, vl.outline, width: max(h * 0.075, 1.2) * chunk, 0.75)
        BogPainter.stroke(ctx, cilia, vl.ciliaTip, width: max(h * 0.038, 0.6) * chunk)
        // One glint on the upper lobe.
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x - rx * 0.32, y: c.y + ry * 0.6), rx * 0.2, ry * 0.13,
                                                rotation: 0.15), RGBA(1, 1, 1), 0.6)
        if vl.sparkle {
            BogPainter.fill(ctx, twinklePath(CGPoint(x: c.x + rx * 0.62, y: c.y + ry * 0.62), h * 0.2), RGBA(1, 1, 0.9))
        }
    }

    /// R4 (#15): under this width (points) the glyph is the simplified silhouette (`drawSmallSnapGlyph`).
    static let smallGlyphWidth: CGFloat = 24
    /// R4 (#15): the small glyph's cilia ticks.
    static let smallGlyphTicks = 3

    /// R4 (#15): the snap glyph under 24 pt, where the full drawing read as tiny lips with teeth: a closed green pod
    /// (the leaf backs, lit from the top), a crimson seam along its middle and three cream cilia ticks across it.
    /// `empty`: the same pod as a grey outline. Fills `size` (y up).
    static func drawSmallSnapGlyph(_ ctx: CGContext, size: CGSize, empty: Bool = false,
                                   variety: TrapVariety = .classic) {
        let vl = look(variety)
        let w = size.width, h = size.height
        let c = CGPoint(x: w / 2, y: h / 2)
        let line = max(h * 0.1, 1)
        let rx = w * 0.5 - line, ry = h * 0.5 - line
        func lens(_ kx: CGFloat, _ ky: CGFloat) -> CGPath {
            let p = CGMutablePath()
            let l = CGPoint(x: c.x - rx * kx, y: c.y), r = CGPoint(x: c.x + rx * kx, y: c.y)
            p.move(to: l)
            p.addCurve(to: r, control1: CGPoint(x: c.x - rx * kx * 0.62, y: c.y + ry * ky * 1.3),
                       control2: CGPoint(x: c.x + rx * kx * 0.62, y: c.y + ry * ky * 1.3))
            p.addCurve(to: l, control1: CGPoint(x: c.x + rx * kx * 0.62, y: c.y - ry * ky * 1.3),
                       control2: CGPoint(x: c.x - rx * kx * 0.62, y: c.y - ry * ky * 1.3))
            p.closeSubpath()
            return p
        }
        let pod = lens(1, 1)
        let seamLine = BogPainter.polygon([CGPoint(x: c.x - rx * 0.8, y: c.y), CGPoint(x: c.x + rx * 0.8, y: c.y)])
        if empty {
            BogPainter.stroke(ctx, pod, RGBA(0.66, 0.68, 0.64), width: max(h * 0.08, 1), 0.9)
            BogPainter.stroke(ctx, seamLine, RGBA(0.66, 0.68, 0.64), width: max(h * 0.06, 0.8), 0.6)
            return
        }
        BogPainter.stroke(ctx, pod, vl.sheen ?? vl.outline, width: line * 1.6, 0.95)
        BogPainter.gradient(ctx, pod, [BogPaint.lighter(vl.leaf, 0.3), vl.leaf, vl.leafDark], [0, 0.5, 1],
                            from: CGPoint(x: c.x, y: c.y + ry), to: CGPoint(x: c.x, y: c.y - ry))
        // The crimson seam: a narrow lens along the middle, dark at its centre line.
        let seam = lens(0.86, 0.3)
        BogPainter.fill(ctx, seam, vl.glyphOuter)
        BogPainter.stroke(ctx, seamLine, interior, width: max(h * 0.055, 0.6), 0.8)
        // Three cilia ticks across the seam.
        let ticks = CGMutablePath()
        for i in 0..<smallGlyphTicks {
            let x = c.x + rx * 0.46 * (CGFloat(i) - CGFloat(smallGlyphTicks - 1) / 2)
            ticks.move(to: CGPoint(x: x - rx * 0.05, y: c.y - ry * 0.5))
            ticks.addLine(to: CGPoint(x: x + rx * 0.05, y: c.y + ry * 0.5))
        }
        let chunk = min(max(vl.toothWidth, 1), 1.8)
        BogPainter.stroke(ctx, ticks, vl.outline, width: max(h * 0.16, 1.4) * chunk, 0.7)
        BogPainter.stroke(ctx, ticks, vl.ciliaTip, width: max(h * 0.085, 0.8) * chunk)
        // One glint on the upper back.
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x - rx * 0.36, y: c.y + ry * 0.55), rx * 0.18, ry * 0.14,
                                                rotation: 0.2), RGBA(1, 1, 1), 0.5)
    }

    /// R3 (#11): the snap glyph as an image for the App's snaps row (`width` × `height` points; `empty` for a spent
    /// slot). The scene's Feast flights and sting cracks use the same drawing. R4 (#15): under `smallGlyphWidth` it is
    /// the simplified pod (`drawSmallSnapGlyph`); at 24 pt and up (the Duo's row) the full mini closed trap.
    static func snapGlyph(width: CGFloat = 30, height: CGFloat = 22, scale: CGFloat = 3,
                          empty: Bool = false, variety: TrapVariety = .classic) -> CGImage? {
        BogPainter.image(width: width, height: height, scale: scale) { ctx, s in
            drawSnapGlyph(ctx, size: s, empty: empty, variety: variety)
        }
    }

    /// R2 (#12, one art language), R3 (#2): the play trap, open (the lips and backs, the oxblood-to-crimson faces with
    /// their blush, the midrib seam, the cilia and the petiole), as a `CGImage` `width` points wide for SwiftUI (Home,
    /// the cover, Results). It is drawn by the same code as the scene's lobes. Height follows the trap (≈ 0.75 × width).
    static func trapImage(width: CGFloat, scale: CGFloat = 2, variety: TrapVariety = .classic) -> CGImage? {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let vl = look(variety)
        let spread = spreadTransform(variety, geometry: g)
        let e = exteriorWidth + 4
        var box = CGRect(x: g.center.x - (g.a + e) * vl.spread, y: g.center.y - g.b - e,
                         width: 2 * (g.a + e) * vl.spread, height: 2 * (g.b + e))
        var all: [TrapTooth] = []
        for side in [-1, 1] { all += teeth(side: side, geometry: g, variety: variety) }
        for t in all {
            let tip = CGPoint(x: t.root.x + cos(t.angle) * (t.length + 3), y: t.root.y + sin(t.angle) * (t.length + 3))
                .applying(spread)
            let pad = 4 + max(t.width - 5, 0) * 0.6
            box = box.union(CGRect(x: tip.x - pad, y: tip.y - pad, width: 2 * pad, height: 2 * pad))
        }
        let stem = g.b * 0.3 + BogArt.petioleJoin
        box = box.union(CGRect(x: g.center.x - 44, y: g.center.y - g.b + BogArt.petioleJoin - stem - 8, width: 88,
                               height: 10))
        let frame = box
        let k = max(width, 1) / max(frame.width, 1)
        let pal = palette
        return BogPainter.image(width: frame.width * k, height: frame.height * k, scale: scale) { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -frame.minX, y: -frame.minY)
            // A soft shadow under the trap, the petiole, then the lobes.
            BogPainter.ellipticalRadial(ctx, [RGBA(0, 0.03, 0.01, 0.35), RGBA(0, 0.03, 0.01, 0.3),
                                              RGBA(0, 0.03, 0.01, 0)], [0, 0.86, 1],
                                        center: CGPoint(x: g.center.x + 4, y: g.center.y - 10), rx: g.a * 1.08,
                                        ry: g.b * 1.08)
            BogArt.drawPetiole(ctx, geometry: g, length: stem)
            ctx.saveGState()
            ctx.concatenate(spread)
            for side in [-1, 1] { BogArt.drawLobe(ctx, side: side, geometry: g, variety: variety) }
            ctx.setAlpha(min(0.8 * vl.gloss, 1))
            for side in [-1, 1] { BogArt.drawGloss(ctx, side: side, geometry: g) }
            ctx.restoreGState()
            BogArt.drawMidrib(ctx, geometry: g)
            // The cilia: a subtle shadow, then each from its green base to its cream tip.
            let shadow = CGMutablePath()
            var paths: [(CGPath, TrapTooth)] = []
            for t in all {
                let shape = toothShape(length: t.length, width: t.width, curl: t.curl, kind: vl.tooth)
                let p = CGMutablePath()
                p.addPath(shape, transform: toothTransform(t, geometry: g, lean: 0, squash: 1).concatenating(spread))
                shadow.addPath(p)
                paths.append((p, t))
            }
            ctx.saveGState()
            ctx.translateBy(x: 1.6, y: -2)
            BogPainter.fill(ctx, shadow, RGBA(0, 0.05, 0.02), 0.3)
            ctx.restoreGState()
            for (p, t) in paths {
                BogPainter.stroke(ctx, p, vl.outline, width: 1.2, 0.75)
                let root = t.root.applying(spread)
                let tip = CGPoint(x: t.root.x + cos(t.angle) * t.length, y: t.root.y + sin(t.angle) * t.length)
                    .applying(spread)
                BogPainter.gradient(ctx, p, [vl.ciliaBase, vl.ciliaMid, vl.ciliaTip], [0.05, 0.5, 1], from: root,
                                    to: tip)
                if let gold = vl.sheen { BogPainter.stroke(ctx, p, gold, width: 0.8, 0.55) }
            }
            if vl.sparkle {
                // R6 (Golden Glow): twinkles on the rim.
                for side in [-1, 1] {
                    for (i, q) in sparkleSpots(side: side, geometry: g).enumerated() {
                        let c = q.applying(spread)
                        BogPainter.fill(ctx, BogPainter.circle(c, 9), pal.gold, 0.25)
                        BogPainter.fill(ctx, twinklePath(c, i % 2 == 0 ? 11 : 7), RGBA(1, 0.98, 0.86))
                    }
                }
            }
        }
    }
}
