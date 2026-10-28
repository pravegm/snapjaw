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

/// R4 (REVIEW-3 #16, the founder's P0): the trap on its own (Results, the cover) is never a centred vertical slit. It is
/// the Scene's 3/4 trap (`TrapArt.trapImage(style: .threeQuarter …)`): tilted like the icon, half open, its leaf back
/// and petiole leaf showing, with a housefly sipping on it. If the Scene's image can't be made, the open trap is tilted
/// back and turned by the App, with the fly on its near lobe.
struct TrapHeroImage: View {
    /// A fly sipping on it.
    var withBug = true
    /// R6: the Garden's variety.
    var variety: TrapVariety = .classic

    var body: some View {
        if let hero = TrapImageCache.heroImage(bug: withBug, variety: variety) {
            Image(decorative: hero, scale: TrapImageCache.scale)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    // The shadow it casts on the bog.
                    Ellipse()
                        .fill(RadialGradient(colors: [Color.black.opacity(0.45), Color.black.opacity(0)],
                                             center: .center, startRadius: 0, endRadius: w * 0.48))
                        .frame(width: w * 0.92, height: h * 0.34)
                        .offset(y: h * 0.30)
                    TrapHeroArt()
                        .frame(width: w * 0.94, height: h * 0.86)
                        .offset(y: -h * 0.02)
                    if withBug {
                        BugPortrait(species: .housefly)
                            .frame(width: w * 0.2, height: w * 0.2)
                            .offset(x: w * TrapHeroArt.bugAt.x, y: h * TrapHeroArt.bugAt.y)
                    }
                }
                .frame(width: w, height: h)
            }
            .accessibilityHidden(true)
        }
    }
}

/// The fallback for `TrapHeroImage`: the open trap tilted back about 3/4 (the far half foreshortened) and turned so the
/// midrib runs on a slant.
struct TrapHeroArt: View {
    /// Where the sipping fly sits (fractions of the hero's size from its centre): on the near, right lobe.
    static let bugAt = CGPoint(x: 0.17, y: 0.02)
    /// The tilt back (degrees about the horizontal axis) and the turn (degrees in the plane).
    static let tilt: Double = 46
    static let turn: Double = -16

    var body: some View {
        TrapArtImage()
            .rotation3DEffect(.degrees(Self.tilt), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
            .rotationEffect(.degrees(Self.turn))
            .accessibilityHidden(true)
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

    private static var heroCache: [String: CGImage] = [:]
    private static var heroTried: Set<String> = []

    /// R4 (REVIEW-3 #16): the Scene's own 3/4 trap, `bug`: with a fly sipping on it (nil: the App tilts the open trap
    /// instead). R6: in `variety` (the Garden), each look drawn once.
    static func heroImage(bug: Bool = false, variety: TrapVariety = .classic) -> CGImage? {
        let key = variety.rawValue + (bug ? ".bug" : "")
        if let hit = heroCache[key] { return hit }
        guard !heroTried.contains(key) else { return nil }
        heroTried.insert(key)
        let made = SceneHooks.threeQuarterTrap(width: width, scale: scale, bug: bug, variety: variety)
        heroCache[key] = made
        return made
    }

    private static var halvesCache: (CGImage, CGImage)?

    /// The trap image cut down its midrib: the left and right lobes (the Duo diagrams put one on each half).
    static func halves() -> (left: CGImage, right: CGImage)? {
        if let hit = halvesCache { return (hit.0, hit.1) }
        guard let whole = image(), whole.width > 1, whole.height > 1 else { return nil }
        let w = whole.width / 2
        guard let l = whole.cropping(to: CGRect(x: 0, y: 0, width: w, height: whole.height)),
              let r = whole.cropping(to: CGRect(x: whole.width - w, y: 0, width: w, height: whole.height)) else {
            return nil
        }
        halvesCache = (l, r)
        return (l, r)
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

// MARK: - The snap glyph (REVIEW-2 #11)

/// One HUD snap: a mini CLOSED trap seen from above (founder art direction #2): two green leaf backs pressed together,
/// the crimson seam between them and the cilia interlocked across it. Never a melon slice: no pink face, no rind.
/// An empty slot is a grey outline of the same shape. Everything draws through `draw(_:in:filled:drain:hot:)`, so the
/// Scene's `TrapArt.snapGlyph` (Scene R3) can replace it in one place.
enum SnapGlyphArt {
    static let leaf = Color(snapHex: 0x4C9A3C)
    static let leafDark = Color(snapHex: 0x1F5526)
    static let seam = Color(snapHex: 0x9A1A33)
    static let seamLight = Color(snapHex: 0xC42A45)
    static let cilia = Color(snapHex: 0xEAF7B8)
    static let lip = Color(snapHex: 0x123A1C)
    static let spent = Color(snapHex: 0x8AAA8D)

    /// The closed trap's outline: a clam with pointed ends, the seam along its long axis.
    static func shell(in r: CGRect) -> Path {
        var p = Path()
        let y = r.midY
        p.move(to: CGPoint(x: r.minX + r.width * 0.03, y: y))
        p.addCurve(to: CGPoint(x: r.maxX - r.width * 0.03, y: y),
                   control1: CGPoint(x: r.minX + r.width * 0.18, y: r.minY - r.height * 0.12),
                   control2: CGPoint(x: r.maxX - r.width * 0.18, y: r.minY - r.height * 0.12))
        p.addCurve(to: CGPoint(x: r.minX + r.width * 0.03, y: y),
                   control1: CGPoint(x: r.maxX - r.width * 0.18, y: r.maxY + r.height * 0.12),
                   control2: CGPoint(x: r.minX + r.width * 0.18, y: r.maxY + r.height * 0.12))
        p.closeSubpath()
        return p
    }

    /// The crimson seam where the two margins meet (a thin lens along the middle).
    static func seamPath(in r: CGRect) -> Path {
        var p = Path()
        let y = r.midY
        let h = r.height * 0.17
        p.move(to: CGPoint(x: r.minX + r.width * 0.10, y: y))
        p.addQuadCurve(to: CGPoint(x: r.maxX - r.width * 0.10, y: y), control: CGPoint(x: r.midX, y: y - h))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.10, y: y), control: CGPoint(x: r.midX, y: y + h))
        p.closeSubpath()
        return p
    }

    /// The cilia, interlocked like fingers across the seam (alternately from the upper and the lower lobe).
    static func ciliaPath(in r: CGRect) -> Path {
        var p = Path()
        let n = 7
        let reach = r.height * 0.30
        for i in 0..<n {
            let u = (CGFloat(i) + 0.5) / CGFloat(n)
            let x = r.minX + r.width * (0.14 + 0.72 * u)
            let fromTop = i % 2 == 0
            let lean = r.width * 0.025
            p.move(to: CGPoint(x: x - lean, y: r.midY + (fromTop ? -reach : reach)))
            p.addLine(to: CGPoint(x: x + lean, y: r.midY + (fromTop ? reach * 0.7 : -reach * 0.7)))
        }
        return p
    }

    /// Draws one slot from the Scene's glyph images (`TrapArt.snapGlyph`, the same drawing as its Feast flights and
    /// sting cracks), or from the App's own paths when there are none. `filled` false: the grey outline. `drain` 0…1:
    /// hunger has drained that much of the fill (from the top) and the rest greys. `hot` 0…1: the hungry pulse (a
    /// crimson glow round the glyph).
    static func draw(_ ctx: inout GraphicsContext, in rect: CGRect, filled: Bool, drain: Double, hot: Double,
                     full fullImage: CGImage?, empty emptyImage: CGImage?) {
        guard let fullImage, let emptyImage else {
            draw(&ctx, in: rect, filled: filled, drain: drain, hot: hot)
            return
        }
        let k = min(max(hot.isFinite ? hot : 0, 0), 1)
        if filled && k > 0.01 {
            let glow = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.10))
            ctx.stroke(glow, with: .color(SnapTheme.crimson.opacity(0.45 + 0.55 * k)),
                       lineWidth: max(rect.height * 0.10, 1.2) * CGFloat(1 + k))
        }
        guard filled else {
            ctx.draw(Image(decorative: emptyImage, scale: SnapGlyphCache.scale), in: rect)
            return
        }
        let d = CGFloat(min(max(drain.isFinite ? drain : 0, 0), 1))
        if d > 0.001 { ctx.draw(Image(decorative: emptyImage, scale: SnapGlyphCache.scale), in: rect) }
        var part = ctx
        part.clip(to: Path(CGRect(x: rect.minX, y: rect.minY + rect.height * d, width: rect.width,
                                  height: rect.height * (1 - d))))
        if d > 0.001 { part.addFilter(.saturation(1 - Double(d) * 0.85)) }
        part.draw(Image(decorative: fullImage, scale: SnapGlyphCache.scale), in: rect)
    }

    /// The App's own drawing of the glyph (the fallback).
    static func draw(_ ctx: inout GraphicsContext, in rect: CGRect, filled: Bool, drain: Double, hot: Double) {
        let r = rect.insetBy(dx: 1, dy: 1)
        let body = shell(in: r)
        let line = max(r.height * 0.09, 1)
        guard filled else {
            ctx.fill(body, with: .color(Color.black.opacity(0.22)))
            ctx.stroke(body, with: .color(spent.opacity(0.75)), lineWidth: max(line * 0.9, 1.1))
            return
        }
        let d = CGFloat(min(max(drain.isFinite ? drain : 0, 0), 1))
        // The drained top shows as an empty slot.
        if d > 0.001 {
            ctx.fill(body, with: .color(Color.black.opacity(0.22)))
        }
        var full = ctx
        full.clip(to: Path(CGRect(x: rect.minX, y: rect.minY + rect.height * d, width: rect.width,
                                  height: rect.height * (1 - d))))
        full.fill(body, with: .linearGradient(Gradient(colors: [leaf, leafDark]), startPoint: CGPoint(x: r.midX, y: r.minY),
                                              endPoint: CGPoint(x: r.midX, y: r.maxY)))
        full.fill(seamPath(in: r), with: .linearGradient(Gradient(colors: [seamLight, seam]),
                                                         startPoint: CGPoint(x: r.midX, y: r.midY - r.height * 0.2),
                                                         endPoint: CGPoint(x: r.midX, y: r.midY + r.height * 0.2)))
        full.stroke(ciliaPath(in: r), with: .color(cilia),
                    style: StrokeStyle(lineWidth: max(r.width * 0.045, 0.9), lineCap: .round))
        // A wet glint on the upper lobe.
        full.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.30, y: r.minY + r.height * 0.12, width: r.width * 0.22,
                                         height: r.height * 0.14)), with: .color(Color.white.opacity(0.28)))
        if d > 0.001 {
            // Greying as a wilt nears.
            full.fill(body, with: .color(Color(snapHex: 0x6E7468).opacity(Double(d) * 0.8)))
        }
        let k = min(max(hot.isFinite ? hot : 0, 0), 1)
        ctx.stroke(body, with: .color(k > 0.01 ? SnapTheme.crimson.opacity(0.55 + 0.45 * k) : lip),
                   lineWidth: k > 0.01 ? line * (1.2 + 1.3 * CGFloat(k)) : line)
    }
}

/// The Scene's snap glyph images, per size (`TrapArt.snapGlyph`), kept for the app's life.
@MainActor
enum SnapGlyphCache {
    static let scale: CGFloat = 3
    private static var cache: [String: CGImage] = [:]
    private static var failed: Set<String> = []

    static func image(width: CGFloat, empty: Bool) -> CGImage? {
        let w = max((width * 2).rounded() / 2, 4)
        let key = "\(w).\(empty ? 1 : 0)"
        if let hit = cache[key] { return hit }
        guard !failed.contains(key) else { return nil }
        guard let made = TrapArt.snapGlyph(width: w, height: w * HUDLayout.glyphAspect, scale: scale, empty: empty) else {
            failed.insert(key)
            return nil
        }
        cache[key] = made
        return made
    }
}

/// One snap glyph in the HUD (`SnapGlyphArt`), `size` wide.
struct SnapSlot: View {
    let filled: Bool
    var drain: Double = 0
    var hot: Double = 0
    let size: CGFloat

    var body: some View {
        let full = SnapGlyphCache.image(width: size, empty: false)
        let empty = SnapGlyphCache.image(width: size, empty: true)
        Canvas { ctx, sz in
            SnapGlyphArt.draw(&ctx, in: CGRect(origin: .zero, size: sz), filled: filled, drain: drain, hot: hot,
                              full: full, empty: empty)
        }
        .frame(width: size, height: size * HUDLayout.glyphAspect)
        .accessibilityHidden(true)
    }
}

// MARK: - The Duo's fold as the input (ROUND-3 founder call)

/// One half of a Duo seen from the front: a dark body, its screen showing its half of ONE play trap (R4, REVIEW-3 #8:
/// the trap spans the hinge, one stem, not two images): the whole `TrapArt.trapImage` is laid across both screens and
/// each half shows its side of it, so the midrib sits on the hinge.
struct DuoHalfView: View {
    let left: Bool

    /// The body's bezel; thinner on the hinge side, so the two screens meet.
    static let bezel: CGFloat = 3
    static let hingeBezel: CGFloat = 1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        GeometryReader { geo in
            let screenW = max(geo.size.width - Self.bezel - Self.hingeBezel, 1)
            let screenH = max(geo.size.height - 2 * Self.bezel, 1)
            ZStack {
                shape.fill(Color(snapHex: 0x14181C))
                ZStack {
                    SnapTheme.bog
                    if let whole = TrapImageCache.image() {
                        // Twice the screen's width (both screens), this half's side showing.
                        Image(decorative: whole, scale: TrapImageCache.scale)
                            .resizable()
                            .interpolation(.medium)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: (screenW + Self.hingeBezel) * 2, height: screenH)
                            .offset(x: left ? screenW / 2 + Self.hingeBezel : -(screenW / 2 + Self.hingeBezel))
                    } else {
                        LinearGradient(colors: left ? [SnapTheme.crimson, SnapTheme.crimsonDeep]
                                                    : [SnapTheme.crimsonDeep, SnapTheme.crimson],
                                       startPoint: .leading, endPoint: .trailing)
                            .padding(.vertical, 8)
                    }
                }
                .frame(width: screenW, height: screenH)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(x: left ? (Self.bezel - Self.hingeBezel) / 2 : (Self.hingeBezel - Self.bezel) / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// The Duo held like a book at hinge angle `theta` (degrees between the halves, 180 = flat), seen from the front: each
/// half turns (180 − θ) / 2 about the hinge. `arrows` 0…1 shows the "snap it shut" chevrons at the outer edges.
struct DuoFoldView: View {
    var theta: Double
    var arrows: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let halfW = max(w / 2 - 1, 1)
            let tilt = min(max((180 - (theta.isFinite ? theta : 160)) / 2, 0), 80)
            ZStack {
                HStack(spacing: 2) {
                    DuoHalfView(left: true)
                        .frame(width: halfW, height: h)
                        .rotation3DEffect(.degrees(tilt), axis: (x: 0, y: 1, z: 0), anchor: .trailing,
                                          perspective: 0.55)
                    DuoHalfView(left: false)
                        .frame(width: halfW, height: h)
                        .rotation3DEffect(.degrees(-tilt), axis: (x: 0, y: 1, z: 0), anchor: .leading,
                                          perspective: 0.55)
                }
                if arrows > 0.01 {
                    let a = min(max(arrows, 0), 1)
                    HStack {
                        Image(systemName: "chevron.right")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.left")
                    }
                    .font(.system(size: max(h * 0.26, 10), weight: .black))
                    .foregroundStyle(SnapTheme.limeLight)
                    .shadow(color: SnapTheme.shadow.opacity(0.7), radius: 2, y: 1)
                    .padding(.horizontal, -max(h * 0.2, 8))
                    .opacity(a)
                }
            }
            .frame(width: w, height: h)
        }
        .accessibilityHidden(true)
    }
}

/// The hinge seen from the top: two arms meeting at the fold with the angle between them ("138°").
struct FoldAngleGlyph: View {
    var theta: Double

    var body: some View {
        let th = theta.isFinite ? min(max(theta, 60), 180) : 160
        Canvas { ctx, size in
            // R4 (REVIEW-3 #8: "138°" was clipped by the drawing above it): the angle reads under the hinge, and the
            // arms fit the room above it.
            let fontSize = Self.labelSize(height: size.height)
            let hinge = CGPoint(x: size.width / 2, y: max(size.height - fontSize - 6, size.height * 0.4))
            let lift = CGFloat((180 - th) / 2 * Double.pi / 180)
            let arm = min(size.width * 0.3, 60, max(hinge.y - 3, 4) / max(sin(lift), 0.2))
            var v = Path()
            v.move(to: CGPoint(x: hinge.x - arm * cos(lift), y: hinge.y - arm * sin(lift)))
            v.addLine(to: hinge)
            v.addLine(to: CGPoint(x: hinge.x + arm * cos(lift), y: hinge.y - arm * sin(lift)))
            ctx.stroke(v, with: .color(Color.black.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            ctx.stroke(v, with: .color(SnapTheme.limeLight),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            ctx.draw(Text("\(Int(th.rounded()))°").font(.system(size: fontSize, weight: .heavy, design: .rounded)
                                                            .monospacedDigit())
                        .foregroundColor(SnapTheme.cream),
                     at: CGPoint(x: hinge.x, y: hinge.y + 3), anchor: .top)
        }
        .accessibilityHidden(true)
    }

    /// The angle's type size for a glyph `height` tall. Pure; tested (it fits under the hinge).
    static func labelSize(height: CGFloat) -> CGFloat {
        max(min(height * 0.36, 15), 9)
    }
}

// R8 portrait: `DuoClapDiagram` (the 160° → 138° clap, the old verb) is gone with the pose card, its last user.
