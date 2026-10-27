import CoreGraphics
import Foundation

/// The scene's static art, drawn once into cached textures (`BogTextures`). Pure CoreGraphics and nonisolated: the
/// texture closures call these directly. Coordinates are y up; the trap layers are drawn in scene space (the caller
/// translates the context to the texture's frame).
enum BogArt {
    // MARK: Constants shared with the scene

    /// The reference tooth the tooth texture is drawn at (sprites scale it to each `TrapTooth`).
    static let toothTexLength: CGFloat = 44
    static let toothTexWidth: CGFloat = 12
    /// The tooth texture's size and where the root sits in it.
    static let toothTexSize = CGSize(width: 26, height: 53)
    static let toothRootY: CGFloat = 6

    /// The radius fraction the slam jaw's dark band reaches out to (it sweeps in from beyond the edge).
    static let jawOuter: CGFloat = 1.16
    static let jawInner: CGFloat = 0.93

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

        // The trap's soft shadow on the bog (contact shadow just past the rim).
        BogPainter.ellipticalRadial(ctx, [RGBA(0, 0.03, 0.01, 0.6), RGBA(0, 0.03, 0.01, 0.55),
                                          RGBA(0, 0.03, 0.01, 0)], [0, 0.86, 1],
                                    center: CGPoint(x: g.center.x + 4, y: g.center.y - 10), rx: g.a * 1.17,
                                    ry: g.b * 1.17)

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

        // Corner shade.
        for c in [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: 0, y: h), CGPoint(x: w, y: h)] {
            BogPainter.radial(ctx, [RGBA(0, 0.05, 0.02, 0.35), RGBA(0, 0.05, 0.02, 0)], [0, 1], center: c,
                              radius: 170)
        }
    }

    private static func drawWater(_ ctx: CGContext, size: CGSize, rng: inout BogRNG) {
        let w = size.width
        let water = CGMutablePath()
        water.move(to: CGPoint(x: -4, y: -4))
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
        water.addLine(to: CGPoint(x: w + 4, y: -4))
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

    /// One lobe's static face, open: the dark outline, the lime margin, the crimson face with veins, glands,
    /// pores, the midrib's shade and a broad sheen.
    static func drawLobe(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        let pal = TrapArt.palette
        let s: CGFloat = side < 0 ? -1 : 1
        let outer = TrapArt.lobePath(side: side, geometry: g, closure01: 0)
        let face = TrapArt.lobeFacePath(side: side, geometry: g)
        let outerX = g.center.x + s * g.a
        let top = CGPoint(x: g.center.x, y: g.center.y + g.b), bottom = CGPoint(x: g.center.x, y: g.center.y - g.b)

        // The outline and the lime margin (the outer skin showing at the edge).
        BogPainter.stroke(ctx, outer, TrapArt.lobeOutline, width: 6, 0.92)
        BogPainter.gradient(ctx, outer, [BogPaint.lighter(pal.rim, 0.3), pal.rim, BogPaint.darker(pal.rim, 0.32)],
                            [0, 0.5, 1], from: top, to: bottom)
        // A wet highlight along the top of the margin.
        ctx.saveGState()
        ctx.addPath(outer)
        ctx.addPath(face)
        ctx.clip(using: .evenOdd)
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 1, 0.9, 0), RGBA(1, 1, 0.9, 0), RGBA(1, 1, 0.9, 0.5),
                                          RGBA(1, 1, 0.9, 0)], [0, 0.955, 0.975, 1],
                                    center: CGPoint(x: g.center.x - s * 6, y: g.center.y - 8), rx: g.a, ry: g.b)
        ctx.restoreGState()

        // The crimson face: deep by the midrib, bright towards the rim.
        BogPainter.gradient(ctx, face, [pal.lobeInner, pal.lobeInner.mixed(with: pal.lobeOuter, 0.55), pal.lobeOuter,
                                        BogPaint.lighter(pal.lobeOuter, 0.12)], [0, 0.3, 0.78, 1],
                            from: CGPoint(x: g.center.x, y: g.center.y), to: CGPoint(x: outerX, y: g.center.y))
        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        // Darker towards the top and bottom ends (the lobe curls there).
        BogPainter.linear(ctx, [RGBA(0.2, 0, 0.05, 0.35), RGBA(0.2, 0, 0.05, 0), RGBA(0.2, 0, 0.05, 0),
                                RGBA(0.2, 0, 0.05, 0.4)], [0, 0.22, 0.78, 1], from: bottom, to: top)
        // The fleshy coral glow at the margin.
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 0.5, 0.45, 0), RGBA(1, 0.5, 0.45, 0), RGBA(1, 0.55, 0.5, 0.32),
                                          RGBA(1, 0.6, 0.5, 0.55)], [0, 0.8, 0.93, 1],
                                    center: g.center, rx: g.a - TrapArt.rimBand, ry: g.b - TrapArt.rimBand,
                                    extend: true)
        // The rim zone (normalised radius ≥ rimStart): a touch lighter, so the "half in" band reads.
        let rimEdge = TrapArt.halfEllipse(side: side, geometry: g, radius: CGFloat(TrapGeometry.rimStart), squash: 1)
        ctx.saveGState()
        ctx.addPath(face)
        ctx.addPath(rimEdge)
        ctx.clip(using: .evenOdd)
        BogPainter.fill(ctx, BogPainter.rect(lobeFrame(side: side, geometry: g)), RGBA(1, 0.8, 0.85), 0.08)
        ctx.restoreGState()
        // Pores.
        var rng = BogRNG(seed: side < 0 ? 0x10BE : 0x10BF)
        let frame = lobeFrame(side: side, geometry: g, pad: 0)
        for i in 0..<420 {
            let q = CGPoint(x: rng.range(frame.minX, frame.maxX), y: rng.range(frame.minY, frame.maxY))
            let pr = rng.range(0.7, 2.0)
            BogPainter.fill(ctx, BogPainter.circle(q, pr), i % 2 == 0 ? RGBA(0.3, 0, 0.08) : RGBA(1, 0.75, 0.82),
                            i % 2 == 0 ? 0.12 : 0.1)
        }
        // Veins: a dark groove with a light ridge beside it.
        let veins = TrapArt.veinsPath(side: side, geometry: g)
        BogPainter.stroke(ctx, veins, BogPaint.darker(pal.lobeInner, 0.25), width: 3.6, 0.42)
        ctx.saveGState()
        ctx.translateBy(x: 1, y: 1.2)
        BogPainter.stroke(ctx, veins, BogPaint.lighter(pal.lobeOuter, 0.45), width: 1.2, 0.3)
        ctx.restoreGState()
        // Glands along the rim's start.
        for q in TrapArt.rimGlands(side: side, geometry: g) {
            BogPainter.fill(ctx, BogPainter.circle(CGPoint(x: q.x, y: q.y - 0.8), 2.8), RGBA(0.3, 0, 0.08), 0.3)
            BogPainter.fill(ctx, BogPainter.circle(q, 2.3), BogPaint.lighter(pal.lobeOuter, 0.25), 0.85)
            BogPainter.fill(ctx, BogPainter.circle(CGPoint(x: q.x - 0.7, y: q.y + 0.7), 0.8), RGBA(1, 1, 1), 0.8)
        }
        // The midrib's shade.
        BogPainter.linear(ctx, [RGBA(0.12, 0, 0.03, 0.45), RGBA(0.12, 0, 0.03, 0)], [0, 1],
                          from: CGPoint(x: g.center.x, y: g.center.y), to: CGPoint(x: g.center.x + s * 90, y: g.center.y))
        // A broad soft sheen high on the face.
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 0.92, 0.95, 0.2), RGBA(1, 0.92, 0.95, 0)], [0, 1],
                                    center: CGPoint(x: g.center.x + s * g.a * 0.5, y: g.center.y + g.b * 0.4),
                                    rx: 170, ry: 110)
        ctx.restoreGState()

        // The margin's inner crease.
        BogPainter.stroke(ctx, face, BogPaint.darker(pal.rim, 0.55), width: 2.2, 0.55)
    }

    /// The closure shade: dark from normalised radius `start` out to the edge (and over the margin).
    static func drawLobeShade(_ ctx: CGContext, side: Int, geometry g: TrapGeometry, start: CGFloat) {
        let outer = TrapArt.halfEllipse(side: side, geometry: g, radius: 1.012, squash: 1)
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

    /// The wet specular streaks on a lobe (white; the scene slides and fades it with the closure).
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
        // Soft halo passes, then the crisp streak.
        for (thick, a) in [(CGFloat(0.12), 0.08), (CGFloat(0.08), 0.14), (CGFloat(0.045), 0.3), (CGFloat(0.022), 0.75)] {
            BogPainter.fill(ctx, streak(1.18, 0.38, 0.76, thick), RGBA(1, 1, 1), a)
        }
        for (thick, a) in [(CGFloat(0.06), 0.1), (CGFloat(0.03), 0.25), (CGFloat(0.014), 0.6)] {
            BogPainter.fill(ctx, streak(-0.35, -0.8, 0.62, thick), RGBA(1, 1, 1), a)
        }
        // Wet beads.
        let beads: [(CGFloat, CGFloat, CGFloat)] = [(0.42, 0.55, 3.2), (0.55, 0.3, 2.2), (0.3, -0.2, 2.6),
                                                    (0.66, -0.36, 1.8), (0.2, 0.62, 2.0), (0.48, 0.04, 1.6)]
        for (bx, by, br) in beads {
            let c = CGPoint(x: g.center.x + s * g.a * bx, y: g.center.y + g.b * by)
            BogPainter.radial(ctx, [RGBA(1, 1, 1, 0.35), RGBA(1, 1, 1, 0)], [0, 1], center: c, radius: br * 3)
            BogPainter.fill(ctx, BogPainter.circle(c, br), RGBA(1, 1, 1), 0.9)
        }
        ctx.restoreGState()
    }

    /// The slam: the far lobe's dark jaw closing over the outer edge, its teeth (dark silhouettes) interlocking
    /// between ours, and the far lobe's lime edge pressing in.
    static func drawJaw(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        let pal = TrapArt.palette
        ctx.saveGState()
        // Only this side, inside the jaw's reach (never a rectangle over the bog).
        ctx.addPath(TrapArt.halfEllipse(side: side, geometry: g, radius: jawOuter, squash: 1))
        ctx.clip()
        // The inner shadow the closing jaw casts; the gradient runs over radius × jawOuter, so the stops are divided.
        let dark = RGBA(hex: 0x1A020A)
        let o = jawOuter
        BogPainter.ellipticalRadial(ctx, [BogPaint.alpha(dark, 0), BogPaint.alpha(dark, 0), BogPaint.alpha(dark, 0.55),
                                          BogPaint.alpha(dark, 0.97), BogPaint.alpha(dark, 1), BogPaint.alpha(dark, 0)],
                                    [0, 0.72 / o, (jawInner - 0.005) / o, (jawInner + 0.01) / o, 1.08 / o, 1],
                                    center: g.center, rx: g.a * o, ry: g.b * o)
        // The far lobe's margin pressing in.
        let edge = TrapArt.halfEllipse(side: side, geometry: g, radius: jawInner + 0.004, squash: 1)
        BogPainter.stroke(ctx, edge, BogPaint.darker(pal.rim, 0.5), width: 3.2, 0.75)
        // The far lobe's teeth: dark silhouettes between ours, pointing in.
        let ours = TrapArt.teeth(side: side, geometry: g)
        for i in 1..<max(ours.count, 1) {
            let a = ours[i], b = ours[i - 1]
            let midRoot = CGPoint(x: (a.root.x + b.root.x) / 2, y: (a.root.y + b.root.y) / 2)
            let angle = atan2(sin(a.angle) + sin(b.angle), cos(a.angle) + cos(b.angle))
            // Pull the root in to the far margin's edge.
            let dx = midRoot.x - g.center.x, dy = midRoot.y - g.center.y
            let k = CGFloat(jawInner) / 0.985
            let root = CGPoint(x: g.center.x + dx * k, y: g.center.y + dy * k)
            let len = (a.length + b.length) * 0.5 * 0.85
            let shape = TrapArt.toothShape(length: len, width: (a.width + b.width) * 0.5, curl: i % 2 == 0 ? 1 : -1)
            let t = CGAffineTransform(translationX: root.x, y: root.y).rotated(by: angle + .pi / 2)
            let p = CGMutablePath()
            p.addPath(shape, transform: t)
            BogPainter.fill(ctx, p, BogPaint.darker(pal.lobeInner, 0.62))
            BogPainter.stroke(ctx, p, BogPaint.darker(pal.lobeOuter, 0.35), width: 1.2, 0.8)
        }
        ctx.restoreGState()
    }

    /// The trap's night glow on one lobe (white-pink; additive).
    static func drawLobeGlow(_ ctx: CGContext, side: Int, geometry g: TrapGeometry) {
        let s: CGFloat = side < 0 ? -1 : 1
        let face = TrapArt.lobeFacePath(side: side, geometry: g)
        ctx.saveGState()
        ctx.addPath(face)
        ctx.clip()
        BogPainter.ellipticalRadial(ctx, [RGBA(1, 0.55, 0.7, 0.9), RGBA(1, 0.45, 0.6, 0.45), RGBA(1, 0.4, 0.55, 0)],
                                    [0, 0.55, 1], center: CGPoint(x: g.center.x + s * g.a * 0.42, y: g.center.y),
                                    rx: g.a * 0.62, ry: g.b * 0.95)
        ctx.restoreGState()
    }

    /// The midrib in scene space.
    static func drawMidrib(_ ctx: CGContext, geometry g: TrapGeometry) {
        let pal = TrapArt.palette
        let p = TrapArt.midribPath(geometry: g)
        let cx = g.center.x
        BogPainter.stroke(ctx, p, TrapArt.outline, width: 3, 0.7)
        BogPainter.gradient(ctx, p, [BogPaint.darker(pal.lobeInner, 0.45), BogPaint.lighter(pal.lobeInner, 0.12),
                                     BogPaint.darker(pal.lobeInner, 0.2), BogPaint.darker(pal.lobeInner, 0.5)],
                            [0, 0.42, 0.62, 1], from: CGPoint(x: cx - 30, y: g.center.y),
                            to: CGPoint(x: cx + 30, y: g.center.y))
        let ridge = CGMutablePath()
        ridge.move(to: CGPoint(x: cx - 3, y: g.center.y + g.b - 26))
        ridge.addQuadCurve(to: CGPoint(x: cx - 3, y: g.center.y - g.b + 26),
                           control: CGPoint(x: cx - 9, y: g.center.y))
        BogPainter.stroke(ctx, ridge, pal.lobeGloss, width: 4, 0.18)
        BogPainter.stroke(ctx, ridge, pal.lobeGloss, width: 1.6, 0.55)
        // A crease line down the centre.
        BogPainter.stroke(ctx, BogPainter.polygon([CGPoint(x: cx + 3, y: g.center.y + g.b - 16),
                                                   CGPoint(x: cx + 3, y: g.center.y - g.b + 16)]),
                          RGBA(0.1, 0, 0.03), width: 1.4, 0.45)
    }

    /// The fold band across the whole scene height (only with a real fold): a soft crease shadow (white; tint black).
    static func drawFoldBand(_ ctx: CGContext, size: CGSize) {
        BogPainter.linear(ctx, [RGBA(1, 1, 1, 0), RGBA(1, 1, 1, 0.85), RGBA(1, 1, 1, 1), RGBA(1, 1, 1, 0.85),
                                RGBA(1, 1, 1, 0)], [0, 0.3, 0.5, 0.7, 1],
                          from: CGPoint(x: 0, y: 0), to: CGPoint(x: size.width, y: 0))
    }

    /// One tooth (the reference size) for the sprites: a lime root, a pale shaft, a bright tip.
    static func drawTooth(_ ctx: CGContext, size: CGSize, curl: CGFloat) {
        let pal = TrapArt.palette
        let shape = TrapArt.toothShape(length: toothTexLength, width: toothTexWidth, curl: curl)
        ctx.saveGState()
        ctx.translateBy(x: size.width / 2, y: toothRootY)
        BogPainter.stroke(ctx, shape, TrapArt.lobeOutline, width: 2.6, 0.9)
        BogPainter.gradient(ctx, shape, [pal.rim, pal.teeth, BogPaint.lighter(pal.teeth, 0.5)], [0.05, 0.4, 1],
                            from: CGPoint(x: 0, y: 0), to: CGPoint(x: curl * 5, y: toothTexLength))
        let shine = CGMutablePath()
        shine.move(to: CGPoint(x: -toothTexWidth * 0.18, y: 4))
        shine.addQuadCurve(to: CGPoint(x: curl * 4.2 - 0.6, y: toothTexLength - 6),
                           control: CGPoint(x: -toothTexWidth * 0.2, y: toothTexLength * 0.6))
        BogPainter.stroke(ctx, shine, RGBA(1, 1, 1), width: 1.4, 0.6)
        ctx.restoreGState()
    }

    /// A glistening gold nectar dome of radius `r` centred in `size`.
    static func drawNectar(_ ctx: CGContext, size: CGSize, radius r: CGFloat) {
        let pal = TrapArt.palette
        let c = CGPoint(x: size.width / 2, y: size.height / 2 + r * 0.08)
        BogPainter.ellipticalRadial(ctx, [RGBA(0.2, 0, 0.05, 0.45), RGBA(0.2, 0, 0.05, 0)], [0, 1],
                                    center: CGPoint(x: c.x + 1.5, y: c.y - r * 0.4), rx: r * 1.25, ry: r * 0.75)
        BogPainter.stroke(ctx, BogPainter.circle(c, r * 1.2), pal.nectar, width: r * 0.32, 0.16)
        let dome = BogPainter.circle(c, r)
        BogPainter.radialFill(ctx, dome, [RGBA(hex: 0xFFF6C8), pal.nectar, BogPaint.darker(pal.nectar, 0.38)],
                              [0, 0.45, 1], center: CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.35), radius: r * 1.5)
        BogPainter.stroke(ctx, dome, BogPaint.darker(pal.nectar, 0.58), width: max(r * 0.12, 1), 0.75)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x + r * 0.28, y: c.y - r * 0.38), r * 0.36, r * 0.17,
                                                rotation: 0.35), RGBA(1, 0.98, 0.8), 0.45)
        BogPainter.fill(ctx, BogPainter.ellipse(CGPoint(x: c.x - r * 0.32, y: c.y + r * 0.36), r * 0.34, r * 0.2,
                                                rotation: 0.6), RGBA(1, 1, 1), 0.95)
        BogPainter.fill(ctx, BogPainter.circle(CGPoint(x: c.x + r * 0.08, y: c.y + r * 0.58), r * 0.08), RGBA(1, 1, 1),
                        0.85)
    }

    /// A trigger hair seen from above: a pale bristle from a pink bulb (size ≈ 14 × 24).
    static func drawHair(_ ctx: CGContext, size: CGSize) {
        let pal = TrapArt.palette
        let base = CGPoint(x: size.width / 2, y: 5)
        let tip = CGPoint(x: size.width / 2 + 1.5, y: size.height - 2)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: base.x - 2, y: base.y))
        p.addQuadCurve(to: tip, control: CGPoint(x: base.x - 0.6, y: size.height * 0.6))
        p.addQuadCurve(to: CGPoint(x: base.x + 2, y: base.y), control: CGPoint(x: base.x + 1.6, y: size.height * 0.6))
        p.closeSubpath()
        BogPainter.stroke(ctx, p, BogPaint.darker(pal.lobeInner, 0.4), width: 1.6, 0.7)
        BogPainter.gradient(ctx, p, [BogPaint.lighter(pal.lobeOuter, 0.3), RGBA(1, 0.95, 0.9)], [0, 1], from: base,
                            to: tip)
        let bulb = BogPainter.circle(base, 3.4)
        BogPainter.stroke(ctx, bulb, BogPaint.darker(pal.lobeInner, 0.4), width: 1.2, 0.7)
        BogPainter.radialFill(ctx, bulb, [RGBA(1, 0.85, 0.9), BogPaint.lighter(pal.lobeOuter, 0.2)], [0, 1],
                              center: CGPoint(x: base.x - 1, y: base.y + 1), radius: 4)
    }

    /// A nectar glisten (pale green-gold, glossy droplets; never gore: the game is 4+) filling `size`.
    static func drawSplat(_ ctx: CGContext, size: CGSize, seed: UInt64) {
        var rng = BogRNG(seed: seed)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let R = min(size.width, size.height) * 0.3
        let juice = RGBA(hex: 0xE6F7A4)
        let edge = RGBA(hex: 0xB9C85A)
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
        BogPainter.radialFill(ctx, blob, [RGBA(hex: 0xFFFDE0), juice, RGBA(hex: 0xF2D978)], [0, 0.5, 1],
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
}
