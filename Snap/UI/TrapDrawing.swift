import SwiftUI

/// The trap drawn by SwiftUI from the Scene's own paths (`TrapArt.lobePath`/`teethPath`), in the R2 look: a deep
/// crimson face (#7A0C26 at the midrib → #D23048 at the rim), a thin dark-green lip and the green leaf outside it, no
/// rind and no smudge. Only a fallback now: Home shows the live scene, and the cover card and Results the scene's own
/// `TrapArt.trapImage` (`TrapArtImage`). `closure01` 0 open … 1 snapped. Drawn in scene space (952 × 670, y up).
struct TrapPortrait: View {
    var closure01: Double
    /// Draw the bog corners round it (Home); false: just the trap (cards).
    var showsBog = false

    var body: some View {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let c = CGFloat(min(max(closure01.isFinite ? closure01 : 0, 0), 1))
        let lobes = [Path(TrapArt.lobePath(side: -1, geometry: g, closure01: c)),
                     Path(TrapArt.lobePath(side: 1, geometry: g, closure01: c))]
        let teeth = [Path(TrapArt.teethPath(side: -1, geometry: g, closure01: c)),
                     Path(TrapArt.teethPath(side: 1, geometry: g, closure01: c))]
        let p = TrapArt.palette
        let leaf = Color(snapHex: 0x2F6A2C)
        let lip = Color(snapHex: 0x173D17)
        let faceDeep = Color(snapHex: 0x7A0C26)
        let faceRim = Color(snapHex: 0xD23048)
        let tooth = Color(snapRGBA: p.teeth)
        let ink = Color(snapRGBA: p.ink)
        let center = g.center
        let a = g.a
        let b = g.b
        Canvas { context, size in
            let sw = ScreenLayout.canvasWidth
            let sh = ScreenLayout.canvasHeight
            let s = min(size.width / sw, size.height / sh)
            let ox = (size.width - sw * s) / 2
            let oy = (size.height - sh * s) / 2
            let t = CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: ox, ty: oy + sh * s)
            // A soft shadow under the whole trap.
            let shadowRect = CGRect(x: center.x - a * 1.04, y: center.y - b * 1.08, width: a * 2.08, height: b * 2.08)
            context.fill(Path(ellipseIn: shadowRect).applying(t), with: .color(Color.black.opacity(0.3)))
            // The green leaf outside the lip (both lobes first, so neither paints over the other's face).
            for lobe in lobes {
                context.stroke(lobe.applying(t), with: .color(leaf), style: StrokeStyle(lineWidth: 52 * s,
                                                                                      lineJoin: .round))
            }
            for (i, lobe) in lobes.enumerated() {
                let l = lobe.applying(t)
                let side: CGFloat = i == 0 ? -1 : 1
                // The deep crimson face, darkest at the midrib.
                let mid = CGPoint(x: center.x, y: center.y).applying(t)
                let edge = CGPoint(x: center.x + side * a, y: center.y).applying(t)
                context.fill(l, with: .linearGradient(Gradient(colors: [faceDeep, faceRim]), startPoint: mid,
                                                      endPoint: edge))
                // Closing darkens the outer edges (the screen agrees with your hands).
                if c > 0.01 {
                    context.fill(l, with: .linearGradient(Gradient(colors: [Color.black.opacity(0),
                                                                            Color.black.opacity(0.45 * Double(c))]),
                                                          startPoint: CGPoint(x: (mid.x + edge.x) / 2, y: mid.y),
                                                          endPoint: edge))
                }
                // The wet sheen: one soft white streak per lobe.
                let streak = CGRect(x: center.x + side * a * 0.48 - a * 0.16, y: center.y + b * 0.34,
                                    width: a * 0.32, height: b * 0.12)
                var glossCtx = context
                glossCtx.clip(to: l)
                glossCtx.fill(Path(ellipseIn: streak).applying(t), with: .color(Color.white.opacity(0.16)))
                context.stroke(l, with: .color(lip), style: StrokeStyle(lineWidth: 6 * s, lineJoin: .round))
            }
            // The midrib.
            let ribTop = CGPoint(x: center.x, y: center.y + b * 0.94).applying(t)
            let ribBottom = CGPoint(x: center.x, y: center.y - b * 0.94).applying(t)
            var rib = Path()
            rib.move(to: ribTop)
            rib.addLine(to: ribBottom)
            context.stroke(rib, with: .color(Color(snapHex: 0x4E0716)), style: StrokeStyle(lineWidth: 12 * s,
                                                                                             lineCap: .round))
            for row in teeth {
                let path = row.applying(t)
                context.fill(path, with: .color(tooth))
                context.stroke(path, with: .color(ink.opacity(0.35)), lineWidth: max(1.5 * s, 0.8))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The play trap exactly as the scene paints it (`TrapArt.trapImage`, Scene R2: the same drawing code as the lobes),
/// fitted into the view. Falls back to `TrapPortrait` if the image can't be made.
struct TrapArtImage: View {
    var body: some View {
        if let image = TrapImageCache.image() {
            Image(decorative: image, scale: TrapImageCache.scale)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            TrapPortrait(closure01: 0)
        }
    }
}

/// One render of `TrapArt.trapImage`, kept for the app's life.
@MainActor
enum TrapImageCache {
    static let width: CGFloat = 420
    static let scale: CGFloat = 2
    private static var cached: CGImage?
    private static var tried = false

    static func image() -> CGImage? {
        if let hit = cached { return hit }
        guard !tried else { return nil }
        tried = true
        cached = TrapArt.trapImage(width: width, scale: scale)
        return cached
    }
}

/// A bug exactly as the game paints it (`TrapArt.bugImage`, the Scene's own drawing: stripes, fuzz, faces), facing
/// up-right a little, fitted into the view (REVIEW-1 #12: one art language). `found` false draws its silhouette (the
/// Bug Book's unfound pages). Images are drawn once per look and cached.
struct BugPortrait: View {
    let species: BugSpecies
    var found = true
    /// Wings spread (flying) or half folded.
    var flying = false

    var body: some View {
        if let image = BugArtCache.image(species, found: found, flying: flying) {
            Image(decorative: image, scale: BugArtCache.scale)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .rotationEffect(.degrees(-24))
                .opacity(found ? 1 : 0.85)
                .accessibilityHidden(true)
        } else {
            Circle().fill(Color.black.opacity(0.3)).padding(8)
                .accessibilityHidden(true)
        }
    }
}

/// `TrapArt.bugImage` renders, kept per species and look (they are small: ~75 pt at 3×).
@MainActor
enum BugArtCache {
    /// One radius for every portrait, so the drawing (not the species' size) fills the frame.
    static let radius: CGFloat = 24
    static let scale: CGFloat = 3
    private static var cache: [String: CGImage] = [:]

    static func image(_ s: BugSpecies, found: Bool, flying: Bool) -> CGImage? {
        let key = "\(s.rawValue).\(found ? 1 : 0).\(flying ? 1 : 0)"
        if let hit = cache[key] { return hit }
        guard let made = TrapArt.bugImage(s, radius: radius, scale: scale, wingSpread: flying ? 1 : 0.7,
                                          silhouette: !found) else { return nil }
        cache[key] = made
        return made
    }
}

/// A little trap glyph (the HUD's snaps): two jaws with a gap, round teeth. `filled` false: a spent snap.
struct SnapGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        // Upper jaw.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.46))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.46), control: CGPoint(x: cx, y: rect.minY - h * 0.38))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.46))
        p.closeSubpath()
        // Lower jaw.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.56))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.56))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.56), control: CGPoint(x: cx, y: rect.maxY + h * 0.38))
        p.closeSubpath()
        // Teeth along both rims.
        let n = 4
        for i in 0..<n {
            let x = rect.minX + w * (CGFloat(i) + 0.5) / CGFloat(n)
            let tw = w / CGFloat(n) * 0.5
            p.move(to: CGPoint(x: x - tw / 2, y: rect.minY + h * 0.46))
            p.addLine(to: CGPoint(x: x, y: rect.minY + h * 0.62))
            p.addLine(to: CGPoint(x: x + tw / 2, y: rect.minY + h * 0.46))
            p.closeSubpath()
        }
        return p
    }
}
