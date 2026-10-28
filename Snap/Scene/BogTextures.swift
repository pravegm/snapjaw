import CoreGraphics
import SpriteKit
import UIKit

/// Textures generated in code once and cached (no per-frame texture work). Every drawing closure calls only
/// nonisolated code (`BogArt`, `TrapArt`, `BogPainter`).
@MainActor
enum BogTextures {
    private static var cache: [String: SKTexture] = [:]

    /// Number of textures built so far (tests: the frame loop never adds any once warm).
    static var count: Int { cache.count }

    static func has(_ key: String) -> Bool { cache[key] != nil }

    /// Draws into a fresh image (y up, origin bottom-left, in points) and caches it under `key`. The texture's
    /// `size()` is in points.
    static func make(_ key: String, width: CGFloat, height: CGFloat, scale: CGFloat = 2,
                     draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let t: SKTexture
        if let img = BogPainter.image(width: width, height: height, scale: scale, draw: draw) {
            t = SKTexture(image: UIImage(cgImage: img, scale: max(scale, 0.25), orientation: .up))
        } else {
            t = SKTexture()
        }
        t.filteringMode = .linear
        cache[key] = t
        return t
    }

    /// Drops one cached texture (the backdrop when the scene's width changes).
    static func forget(_ key: String) { cache[key] = nil }

    /// White at alpha `a` (nonisolated: the drawing closures call it).
    nonisolated private static func w(_ a: Double) -> RGBA { RGBA(1, 1, 1, a) }

    // MARK: Soft shapes (white; tint with the sprite colour)

    static var dot: SKTexture {
        make("dot", width: 32, height: 32) { ctx, s in
            BogPainter.radial(ctx, [w(1), w(1), w(0)], [0, 0.55, 1], center: CGPoint(x: s.width / 2, y: s.height / 2),
                              radius: s.width / 2)
        }
    }

    static var soft: SKTexture {
        make("soft", width: 64, height: 64, scale: 1) { ctx, s in
            BogPainter.radial(ctx, [w(1), w(0.5), w(0)], [0, 0.42, 1], center: CGPoint(x: s.width / 2, y: s.height / 2),
                              radius: s.width / 2)
        }
    }

    static var glow: SKTexture {
        make("glow", width: 128, height: 128) { ctx, s in
            BogPainter.radial(ctx, [w(1), w(0.42), w(0.12), w(0)], [0, 0.22, 0.55, 1],
                              center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width / 2)
        }
    }

    /// A four-point twinkle with a soft halo.
    static var sparkle: SKTexture {
        make("sparkle", width: 48, height: 48) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            BogPainter.radial(ctx, [w(0.6), w(0)], [0, 1], center: c, radius: s.width * 0.3)
            let r = s.width * 0.48, k = s.width * 0.06
            let p = CGMutablePath()
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
            p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
            p.closeSubpath()
            BogPainter.fill(ctx, p, RGBA(1, 1, 1))
        }
    }

    /// Edges dark, centre clear (white: tint it).
    static var vignette: SKTexture {
        make("vignette", width: 256, height: 256, scale: 1) { ctx, s in
            BogPainter.radial(ctx, [w(0), w(0), w(0.5), w(1)], [0, 0.5, 0.8, 1],
                              center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width * 0.62, extend: true)
        }
    }

    /// R8: the closing dim, stretched over the scene (white: tint it black): opaque at the edges, a faint veil in the
    /// middle, so the screen darkens in from its edges as the phone closes.
    static var closingDim: SKTexture {
        make("closingDim", width: 256, height: 256, scale: 1) { ctx, s in
            BogPainter.radial(ctx, [w(0.12), w(0.2), w(0.62), w(1)], [0, 0.42, 0.78, 1],
                              center: CGPoint(x: s.width / 2, y: s.height / 2), radius: s.width * 0.5, extend: true)
        }
    }

    /// A vertical ramp, transparent at the bottom, white at the top (the day's haze from the sky).
    static var haze: SKTexture {
        make("haze", width: 4, height: 256, scale: 1) { ctx, s in
            BogPainter.linear(ctx, [w(0), w(0.25), w(1)], [0, 0.45, 1], from: CGPoint(x: 2, y: 0),
                              to: CGPoint(x: 2, y: s.height))
        }
    }

    /// A soft dark ellipse for a bug's shadow (white: tint it).
    static var shadow: SKTexture {
        make("shadow", width: 64, height: 64, scale: 1) { ctx, s in
            BogPainter.radial(ctx, [w(0.95), w(0.55), w(0)], [0, 0.5, 1], center: CGPoint(x: s.width / 2, y: s.height / 2),
                              radius: s.width / 2)
        }
    }

    static var ring: SKTexture {
        make("ring", width: 96, height: 96) { ctx, s in BogArt.drawRing(ctx, size: s, peak: 0.8, width: 0.16) }
    }

    /// A thin crisp ring (landing ripples).
    static var ripple: SKTexture {
        make("ripple", width: 96, height: 96) { ctx, s in BogArt.drawRing(ctx, size: s, peak: 0.9, width: 0.07) }
    }

    static var halo: SKTexture {
        make("halo", width: 128, height: 128) { ctx, s in BogArt.drawHalo(ctx, size: s) }
    }

    static var whiff: SKTexture {
        make("whiff", width: 72, height: 26) { ctx, s in BogArt.drawWhiff(ctx, size: s) }
    }

    static var startle: SKTexture {
        make("startle", width: 36, height: 36) { ctx, s in BogArt.drawStartle(ctx, size: s) }
    }

    static var anger: SKTexture {
        make("anger", width: 28, height: 28, scale: 3) { ctx, s in BogArt.drawAnger(ctx, size: s) }
    }

    static func splat(_ variant: Int) -> SKTexture {
        let v = ((variant % 3) + 3) % 3
        return make("splat-\(v)", width: 96, height: 96) { ctx, s in
            BogArt.drawSplat(ctx, size: s, seed: 0x5A1A7 &+ UInt64(v) &* 977)
        }
    }

    // MARK: The trap

    /// How far the backdrop runs past every edge of the scene (QA-1 #20: the bite's shake never shows a dark sliver).
    static let backdropBleed: CGFloat = 24

    /// The bog for a scene of `size`, with `backdropBleed` on every side (one per width; the old one is dropped when
    /// the width changes). Place it at (−bleed, −bleed), sized `size` + 2 × bleed.
    static func backdrop(size: CGSize) -> SKTexture {
        let key = backdropKey(size: size)
        let g = TrapGeometry(sceneSize: size)
        let b = backdropBleed
        return make(key, width: size.width + 2 * b, height: size.height + 2 * b, scale: 2) { ctx, _ in
            ctx.translateBy(x: b, y: b)
            BogArt.drawBackdrop(ctx, size: size, geometry: g)
        }
    }

    static func backdropKey(size: CGSize) -> String {
        "bog-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    /// A lobe layer drawn in scene space and cropped to `frame` (any scene size: only the centre moves).
    private static func lobeLayer(_ key: String, side: Int, reach: CGFloat, pad: CGFloat, scale: CGFloat,
                                  draw: @escaping (CGContext, Int, TrapGeometry) -> Void) -> SKTexture {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let frame = BogArt.lobeFrame(side: side, geometry: g, reach: reach, pad: pad)
        return make("\(key)-\(side < 0 ? "L" : "R")", width: frame.width, height: frame.height, scale: scale) { ctx, _ in
            ctx.translateBy(x: -frame.minX, y: -frame.minY)
            draw(ctx, side, g)
        }
    }

    /// The anchor that puts a lobe layer's trap centre on its node's origin.
    static func lobeAnchor(side: Int) -> CGPoint { CGPoint(x: side < 0 ? 1 : 0, y: 0.5) }

    static func lobeSize(reach: CGFloat, pad: CGFloat) -> CGSize {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        return BogArt.lobeFrame(side: 1, geometry: g, reach: reach, pad: pad).size
    }

    /// The lobe layers' margin past the zone's edge (R2: room for the green back).
    static let lobePad: CGFloat = TrapArt.exteriorWidth + 6

    /// R6: the variety suffix of a texture key (none for Classic, so its keys are the R5 ones).
    nonisolated static func varietyKey(_ v: TrapVariety) -> String { v == .classic ? "" : "~\(v.rawValue)" }

    static func lobe(side: Int, variety: TrapVariety = .classic) -> SKTexture {
        lobeLayer("lobe" + varietyKey(variety), side: side, reach: 1, pad: lobePad, scale: 2) { ctx, sd, g in
            BogArt.drawLobe(ctx, side: sd, geometry: g, variety: variety)
        }
    }

    /// The lobe's silhouette in white (the night tint is a tinted copy of it).
    static func lobeSilhouette(side: Int) -> SKTexture {
        lobeLayer("lsil", side: side, reach: 1, pad: lobePad, scale: 0.5) { ctx, sd, g in
            BogArt.drawLobeSilhouette(ctx, side: sd, geometry: g)
        }
    }

    /// R6 (#17): the face alone in white (the tired dim and the hunger wilt: the margin and back stay green).
    static func lobeFace(side: Int) -> SKTexture {
        lobeLayer("lface", side: side, reach: 1, pad: lobePad, scale: 0.5) { ctx, sd, g in
            BogArt.drawLobeFaceSilhouette(ctx, side: sd, geometry: g)
        }
    }

    static func lobeShadeNarrow(side: Int) -> SKTexture {
        lobeLayer("shadeN", side: side, reach: 1, pad: lobePad, scale: 1) { ctx, sd, g in
            BogArt.drawLobeShade(ctx, side: sd, geometry: g, start: 0.66)
        }
    }

    static func lobeShadeWide(side: Int) -> SKTexture {
        lobeLayer("shadeW", side: side, reach: 1, pad: lobePad, scale: 1) { ctx, sd, g in
            BogArt.drawLobeShade(ctx, side: sd, geometry: g, start: 0.12)
        }
    }

    static func gloss(side: Int) -> SKTexture {
        lobeLayer("gloss", side: side, reach: 1, pad: lobePad, scale: 1.5) { ctx, sd, g in
            BogArt.drawGloss(ctx, side: sd, geometry: g)
        }
    }

    static func lobeGlow(side: Int) -> SKTexture {
        lobeLayer("lglow", side: side, reach: 1, pad: lobePad, scale: 0.5) { ctx, sd, g in
            BogArt.drawLobeGlow(ctx, side: sd, geometry: g)
        }
    }

    /// R3 (#1): the closed trap for the bite's hold (both lobes squeezed shut, the cilia interlocked), centred on the
    /// trap centre. Its size is `closedSize`.
    static var closedTrap: SKTexture { closedTrap(variety: .classic) }

    /// R6: the closed trap in `variety`'s colours and cut.
    static func closedTrap(variety: TrapVariety) -> SKTexture {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let frame = BogArt.closedFrame(geometry: g)
        return make("closed" + varietyKey(variety), width: frame.width, height: frame.height, scale: 2) { ctx, _ in
            ctx.translateBy(x: -frame.minX, y: -frame.minY)
            BogArt.drawClosedTrap(ctx, geometry: g, variety: variety)
        }
    }

    static var closedSize: CGSize {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        return BogArt.closedFrame(geometry: g).size
    }

    /// R3: the trap's soft shadow on the bog (white: tint it), `trapShadowSize`, centred on the trap.
    static var trapShadow: SKTexture {
        let sz = trapShadowSize
        return make("tshadow", width: sz.width, height: sz.height, scale: 0.5) { ctx, s in
            BogArt.drawTrapShadow(ctx, size: s)
        }
    }

    static var trapShadowSize: CGSize {
        CGSize(width: 2 * TrapGeometry.semiAxisX * 1.14, height: 2 * TrapGeometry.semiAxisY * 1.14)
    }

    /// The midrib, cropped to its own frame (centred on the trap centre).
    static var midribSize: CGSize { CGSize(width: 64, height: 2 * TrapGeometry.semiAxisY + 8) }

    static var midrib: SKTexture {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let sz = midribSize
        let origin = CGPoint(x: g.center.x - sz.width / 2, y: g.center.y - sz.height / 2)
        return make("midrib", width: sz.width, height: sz.height, scale: 2) { ctx, _ in
            ctx.translateBy(x: -origin.x, y: -origin.y)
            BogArt.drawMidrib(ctx, geometry: g)
        }
    }

    static var foldBand: SKTexture {
        make("fold", width: 2 * ScreenLayout.creaseHalfWidth, height: 8, scale: 2) { ctx, s in
            BogArt.drawFoldBand(ctx, size: s)
        }
    }

    /// The reference tooth; `curl` ±1.
    static func tooth(curl: CGFloat, variety: TrapVariety = .classic) -> SKTexture {
        let sz = BogArt.varietyToothTexSize(variety)
        return make((curl < 0 ? "tooth-L" : "tooth-R") + varietyKey(variety), width: sz.width, height: sz.height,
                    scale: 3) { ctx, s in
            BogArt.drawTooth(ctx, size: s, curl: curl < 0 ? -1 : 1, variety: variety)
        }
    }

    static var hair: SKTexture {
        make("hair", width: 14, height: 24, scale: 3) { ctx, s in BogArt.drawHair(ctx, size: s) }
    }

    /// A nectar drop of drawn radius `r` (rounded to whole points). The texture is 3r square.
    static func nectar(radius r: CGFloat) -> SKTexture {
        let rr = max(r.rounded(), 3)
        return make("nectar-\(Int(rr))", width: rr * 3, height: rr * 3, scale: 3) { ctx, s in
            BogArt.drawNectar(ctx, size: s, radius: rr)
        }
    }

    /// The drawn radius for Core's nectar radius `r` (−30 %).
    nonisolated static func nectarDrawnRadius(_ r: CGFloat) -> CGFloat {
        max((max(r, 3) * TrapArt.nectarDrawScale).rounded(), 3)
    }

    /// The economy's snap glyph (≈ 30 × 22 pt) and its two halves (a sting cracks one).
    static let glyphSize = CGSize(width: 30, height: 22)

    static var snapGlyph: SKTexture { snapGlyph(variety: .classic) }

    /// R6: the economy's glyph in `variety`'s colours.
    static func snapGlyph(variety: TrapVariety) -> SKTexture {
        make("glyph" + varietyKey(variety), width: glyphSize.width, height: glyphSize.height, scale: 3) { ctx, s in
            TrapArt.drawSnapGlyph(ctx, size: s, variety: variety)
        }
    }

    /// R6: every texture `variety` adds (built when the scene's variety is set, never mid-frame).
    static func warm(variety: TrapVariety) {
        for side in [-1, 1] { _ = lobe(side: side, variety: variety) }
        _ = tooth(curl: 1, variety: variety)
        _ = tooth(curl: -1, variety: variety)
        _ = closedTrap(variety: variety)
        _ = snapGlyph(variety: variety)
    }

    // MARK: Bugs

    static func bugSide(radius: CGFloat) -> CGFloat { 2 * TrapArt.bugExtent(radius: radius) }

    /// A bug's white silhouette (body, head and outline), for the 2-frame white flash when it is caught.
    static func bugSilhouette(_ s: BugSpecies, radius: CGFloat) -> SKTexture {
        let r = max(radius.rounded(), 3)
        let side = bugSide(radius: r)
        return make("bugsil-\(s.rawValue)-\(Int(r))", width: side, height: side, scale: 1.5) { ctx, sz in
            ctx.translateBy(x: sz.width / 2, y: sz.height / 2)
            let body = TrapArt.bugBody(s, radius: r)
            BogPainter.stroke(ctx, body, RGBA(1, 1, 1), width: max(r * 0.17, 2.4))
            BogPainter.fill(ctx, body, RGBA(1, 1, 1))
        }
    }

    /// The side of a protected bug's ring texture.
    static func protectedRingSide(radius: CGFloat) -> CGFloat {
        2 * (max(radius.rounded(), 3) * TrapArt.protectedRingScale + 6)
    }

    /// A protected bug's crisp ring (bees white, wasps red), radius `protectedRingScale` × the art radius.
    static func protectedRing(_ s: BugSpecies, radius: CGFloat) -> SKTexture {
        let r = max(radius.rounded(), 3)
        let side = protectedRingSide(radius: r)
        let wasp = s == .wasp
        let color = wasp ? RGBA(hex: 0xFF5A3C) : RGBA(1, 1, 1)
        return make("pring-\(wasp ? "w" : "b")-\(Int(r))", width: side, height: side, scale: 3) { ctx, sz in
            BogArt.drawProtectedRing(ctx, size: sz, radius: r * TrapArt.protectedRingScale, color: color)
        }
    }

    static func bug(_ s: BugSpecies, radius: CGFloat) -> SKTexture {
        let r = max(radius.rounded(), 3)
        let side = bugSide(radius: r)
        return make("bug-\(s.rawValue)-\(Int(r))", width: side, height: side, scale: 3) { ctx, sz in
            ctx.translateBy(x: sz.width / 2, y: sz.height / 2)
            TrapArt.drawBug(ctx, s, radius: r)
        }
    }

    static func wings(_ s: BugSpecies, radius: CGFloat) -> SKTexture {
        let r = max(radius.rounded(), 3)
        let side = bugSide(radius: r)
        return make("wings-\(s.rawValue)-\(Int(r))", width: side, height: side, scale: 3) { ctx, sz in
            ctx.translateBy(x: sz.width / 2, y: sz.height / 2)
            TrapArt.drawWings(ctx, s, radius: r)
        }
    }

    /// Builds every texture the frame loop can ask for (call once, before play).
    static func warm(size: CGSize, radius: (BugSpecies) -> CGFloat) {
        _ = dot
        _ = soft
        _ = glow
        _ = sparkle
        _ = vignette
        _ = closingDim
        _ = haze
        _ = shadow
        _ = ring
        _ = ripple
        _ = halo
        _ = whiff
        _ = startle
        _ = anger
        for v in 0..<3 { _ = splat(v) }
        _ = backdrop(size: size)
        for side in [-1, 1] {
            _ = lobe(side: side)
            _ = lobeShadeNarrow(side: side)
            _ = lobeShadeWide(side: side)
            _ = gloss(side: side)
            _ = lobeGlow(side: side)
            _ = lobeSilhouette(side: side)
            _ = lobeFace(side: side)
        }
        _ = closedTrap
        _ = trapShadow
        _ = midrib
        _ = foldBand
        _ = tooth(curl: 1)
        _ = tooth(curl: -1)
        _ = hair
        _ = snapGlyph
        // Every nectar size Core can seed (QA-1 #24: none is drawn mid-run), with a margin either side.
        let lo = Int(nectarDrawnRadius(CGFloat(Tuning.nectarRadiusMin)))
        let hi = Int(nectarDrawnRadius(CGFloat(Tuning.nectarRadiusMax)))
        for r in max(lo - 1, 3)...max(hi + 1, 3) { _ = nectar(radius: CGFloat(r)) }
        for s in BugSpecies.allCases {
            let r = radius(s)
            _ = bug(s, radius: r)
            _ = wings(s, radius: r)
            _ = bugSilhouette(s, radius: r)
            if s.isProtected { _ = protectedRing(s, radius: r) }
        }
    }
}
