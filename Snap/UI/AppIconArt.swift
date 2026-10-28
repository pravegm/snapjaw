import SwiftUI

/// The App Store icon. R3 (REVIEW-2 #13 / juror P1-5): one idea, readable at 29 px. A Venus flytrap seen from 3/4
/// above, half shut round a little fly who is peeking over the front lip, hands on the rim, eyes looking up at the
/// jaw about to close.
///
/// R4 (REVIEW-3 #17): the same composition, made the game's own trap and fly.
/// - The fly is the in-game **housefly** (`TrapArt.bugStyle(.housefly)`): a grey-blue body (#9AA5B5 → #575E6B →
///   #2E323A), a darker head (#3F444E), cream eyes with dark pupils, pink cheeks and glassy pale-blue wings. It is
///   about 35 % of the trap's width, wings included (it was over 70 %), so the trap is the subject and the fly the
///   joke.
/// - **Both lobes show their crimson edge.** The BACK lobe's glossy crimson inner face (#F46A7E → #D93A56 →
///   #7E0E2A) runs up to its yellow-green margin; the FRONT lobe's inner face shows as a crimson band just inside its
///   lip (#7E0E2A deep at the hinge → #E04A62 at the margin), over the fly's lower half, so the fly is visibly INSIDE.
/// - **Cilia frame the mouth:** a crown of long pale cilia on the back rim against the dark bog, and a shorter fringe
///   on the front rim, fanning out to the sides over the green outside of the leaf. They all point away from the
///   mouth and none crosses the crimson or the fly (cilia, never fangs); the fringe leaves the middle, under the fly,
///   bare.
/// - The trap is tilted −0.2 rad (opening up-right) so it never reads as an eye, a melon or lips.
/// - No outlines: separation is colour and value (crimson / green / grey fly with a dark halo / cream eyes) plus soft
///   shadows. The trap, cilia and fly sit inside the central ~80 %; only the background and the stem reach the edges.
///
/// Pure vector in a 1024-unit design space (y down), full-bleed, opaque and square-cornered: the system applies the
/// mask. Rendered to Documents/AppIcon-1024.png by demo `screen=icon` (IconExport).
struct AppIconArt: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            Canvas(opaque: true, rendersAsynchronously: false) { context, size in
                let scale = min(size.width, size.height) / 1024
                context.scaleBy(x: scale, y: scale)
                AppIconPainter.paint(&context)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

enum AppIconPainter {
    // MARK: Palette

    static let bogGlow = Color(snapHex: 0x4A9E5C)
    static let bogMid = Color(snapHex: 0x1C5E33)
    static let bogEdge = Color(snapHex: 0x05200E)
    static let leafLight = Color(snapHex: 0x6BB548)
    static let leafDark = Color(snapHex: 0x245E2A)
    static let margin = Color(snapHex: 0xD8EA62)
    static let marginDeep = Color(snapHex: 0x9CC43E)
    static let faceHot = Color(snapHex: 0xF46A7E)
    static let face = Color(snapHex: 0xD93A56)
    static let faceDeep = Color(snapHex: 0x7E0E2A)
    /// The front lobe's inner face at its lip (a touch deeper than the back face, so the two lobes separate).
    static let lipFace = Color(snapHex: 0xE04A62)
    static let cilium = Color(snapHex: 0xF2F9CC)
    // The in-game housefly (TrapArt.bugStyle(.housefly)).
    static let flyLight = Color(snapHex: 0x9AA5B5)
    static let flyBody = Color(snapHex: 0x575E6B)
    static let flyHead = Color(snapHex: 0x3F444E)
    static let flyDeep = Color(snapHex: 0x2E323A)
    static let flyEye = Color(snapHex: 0xFFF6F0)
    static let flyPupil = Color(snapHex: 0x1A0E10)
    static let flyCheek = Color(snapHex: 0xFF8FA8)
    static let flyWing = Color(snapHex: 0xDDEBFF)

    // MARK: Geometry (trap frame: midrib horizontal through the origin, corners at ±cornerX)

    /// A cubic Bézier segment.
    struct Seg {
        var p0: CGPoint
        var c1: CGPoint
        var c2: CGPoint
        var p3: CGPoint

        var reversed: Seg { Seg(p0: p3, c1: c2, c2: c1, p3: p0) }

        func point(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(x: a * p0.x + b * c1.x + c * c2.x + d * p3.x,
                           y: a * p0.y + b * c1.y + c * c2.y + d * p3.y)
        }

        /// Unit tangent at `t`.
        func tangent(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            let x = 3 * u * u * (c1.x - p0.x) + 6 * u * t * (c2.x - c1.x) + 3 * t * t * (p3.x - c2.x)
            let y = 3 * u * u * (c1.y - p0.y) + 6 * u * t * (c2.y - c1.y) + 3 * t * t * (p3.y - c2.y)
            let l = max((x * x + y * y).squareRoot(), 0.0001)
            return CGPoint(x: x / l, y: y / l)
        }
    }

    static let cornerX: CGFloat = 320
    /// The trap's tilt (radians, y down: negative turns the opening up-right).
    static let tilt: CGFloat = -0.20
    static let trapCenter = CGPoint(x: 522, y: 585)

    /// The back lobe's rim (the top arc, left corner → right corner).
    static let backRim = Seg(p0: CGPoint(x: -cornerX, y: 0), c1: CGPoint(x: -cornerX * 0.92, y: -365),
                             c2: CGPoint(x: cornerX * 0.92, y: -365), p3: CGPoint(x: cornerX, y: 0))
    /// The front lobe's lip (sagging toward the viewer).
    static let frontRim = Seg(p0: CGPoint(x: -cornerX, y: 0), c1: CGPoint(x: -cornerX * 0.62, y: 165),
                              c2: CGPoint(x: cornerX * 0.62, y: 165), p3: CGPoint(x: cornerX, y: 0))
    /// R4: where the front lobe's crimson inner face disappears toward the hinge (the band's upper edge).
    static let frontInner = Seg(p0: CGPoint(x: -cornerX, y: 0), c1: CGPoint(x: -cornerX * 0.62, y: 66),
                                c2: CGPoint(x: cornerX * 0.62, y: 66), p3: CGPoint(x: cornerX, y: 0))
    /// The front lobe's underside.
    static let frontBelly = Seg(p0: CGPoint(x: -cornerX, y: 0), c1: CGPoint(x: -cornerX * 0.85, y: 320),
                                c2: CGPoint(x: cornerX * 0.85, y: 320), p3: CGPoint(x: cornerX, y: 0))

    /// R4: the fly's centre in the trap frame (its thorax; the head sits below it, peeking over the front lobe).
    static let flyCenter = CGPoint(x: -6, y: 0)
    /// R4: the fly's hands on the lip, either side of it (trap-frame x offsets).
    static let handOffsets: [CGFloat] = [-54, 54]

    // MARK: Paint

    static func paint(_ ctx: inout GraphicsContext) {
        background(&ctx)
        softEllipse(&ctx, center: CGPoint(x: 520, y: 820), rx: 360, ry: 90, hex: 0x000C04, alpha: 0.5)
        stem(&ctx)
        backLobe(&ctx)
        fly(&ctx)
        frontLobe(&ctx)
        hands(&ctx)
    }

    // MARK: Helpers

    static func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat = 0) -> Path {
        let base = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        let t = CGAffineTransform(rotationAngle: rotation).concatenating(CGAffineTransform(translationX: c.x, y: c.y))
        return base.applying(t)
    }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// A soft-edged blob (shadow or glow): a radial fade squashed into an ellipse.
    static func softEllipse(_ ctx: inout GraphicsContext, center: CGPoint, rx: CGFloat, ry: CGFloat,
                            hex: UInt32, alpha: Double) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.scaleBy(x: 1, y: ry / rx)
        let fade = Gradient(colors: [Color(snapHex: hex, alpha: alpha), Color(snapHex: hex, alpha: 0)])
        c.fill(Path(CGRect(x: -rx, y: -rx, width: rx * 2, height: rx * 2)),
               with: .radialGradient(fade, center: .zero, startRadius: 0, endRadius: rx))
    }

    /// A context in the trap frame (origin at the midrib centre, tilted).
    static func trapContext(_ ctx: GraphicsContext) -> GraphicsContext {
        var c = ctx
        c.translateBy(x: trapCenter.x, y: trapCenter.y)
        c.rotate(by: Angle(radians: Double(tilt)))
        return c
    }

    static func curvePath(_ s: Seg) -> Path {
        var p = Path()
        p.move(to: s.p0)
        p.addCurve(to: s.p3, control1: s.c1, control2: s.c2)
        return p
    }

    /// The closed region from `a` and then back along `b` reversed.
    static func region(_ a: Seg, _ b: Seg) -> Path {
        let r = b.reversed
        var p = Path()
        p.move(to: a.p0)
        p.addCurve(to: a.p3, control1: a.c1, control2: a.c2)
        p.addCurve(to: r.p3, control1: r.c1, control2: r.c2)
        p.closeSubpath()
        return p
    }

    /// The point on the front lip (trap frame) whose x is nearest `x` (the lip is gentle, so 60 samples is plenty).
    static func lipPoint(nearX x: CGFloat) -> CGPoint {
        var best = frontRim.point(0)
        for i in 1...60 {
            let p = frontRim.point(CGFloat(i) / 60)
            if abs(p.x - x) < abs(best.x - x) { best = p }
        }
        return best
    }

    // MARK: Background and stem

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .color(bogEdge))
        let bog = Gradient(stops: [.init(color: bogGlow, location: 0), .init(color: bogMid, location: 0.45),
                                   .init(color: bogEdge, location: 1)])
        ctx.fill(all, with: .radialGradient(bog, center: CGPoint(x: 430, y: 370), startRadius: 0, endRadius: 800))
        // Soft bokeh of light through the leaves (big and blurry, nothing thin).
        let bokeh: [(CGFloat, CGFloat, CGFloat, Double)] = [(200, 210, 110, 0.10), (850, 230, 80, 0.07),
                                                            (880, 830, 120, 0.05)]
        for (x, y, r, a) in bokeh {
            softEllipse(&ctx, center: CGPoint(x: x, y: y), rx: r, ry: r, hex: 0xE6FFC8, alpha: a)
        }
    }

    /// A broad leafy stem leaving the frame bottom-left, behind the trap.
    static func stem(_ ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: 380, y: 700))
        p.addCurve(to: CGPoint(x: 200, y: 1040), control1: CGPoint(x: 330, y: 800), control2: CGPoint(x: 250, y: 900))
        p.addLine(to: CGPoint(x: 470, y: 1040))
        p.addCurve(to: CGPoint(x: 560, y: 720), control1: CGPoint(x: 480, y: 900), control2: CGPoint(x: 520, y: 800))
        p.closeSubpath()
        let shade = Gradient(stops: [.init(color: leafDark, location: 0), .init(color: leafLight, location: 0.5),
                                     .init(color: leafDark, location: 1)])
        ctx.fill(p, with: .linearGradient(shade, startPoint: CGPoint(x: 220, y: 0), endPoint: CGPoint(x: 540, y: 0)))
    }

    // MARK: Cilia

    /// One tapered, gently curved hair from `base` along unit `dir`; `bend` curls the tip sideways (× length).
    static func hair(base: CGPoint, dir: CGPoint, length: CGFloat, width: CGFloat, bend: CGFloat) -> Path {
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let tip = CGPoint(x: base.x + dir.x * length + perp.x * bend * length,
                          y: base.y + dir.y * length + perp.y * bend * length)
        let mid = CGPoint(x: base.x + dir.x * length * 0.6, y: base.y + dir.y * length * 0.6)
        var p = Path()
        p.move(to: CGPoint(x: base.x + perp.x * width, y: base.y + perp.y * width))
        p.addQuadCurve(to: tip, control: CGPoint(x: mid.x + perp.x * width * 0.5, y: mid.y + perp.y * width * 0.5))
        p.addQuadCurve(to: CGPoint(x: base.x - perp.x * width, y: base.y - perp.y * width),
                       control: CGPoint(x: mid.x - perp.x * width * 0.5, y: mid.y - perp.y * width * 0.5))
        p.closeSubpath()
        return p
    }

    /// A crown of cilia along the back rim, fanning out at the corners, each with a soft drop shadow.
    static func cilia(_ c: inout GraphicsContext) {
        let count = 13
        let maxLength: CGFloat = 112
        for i in 0..<count {
            let t = 0.04 + 0.92 * CGFloat(i) / CGFloat(count - 1)
            let q = backRim.point(t)
            let along = backRim.tangent(t)
            let normal = CGPoint(x: along.y, y: -along.x)  // outward (away from the crimson)
            let fan = (t - 0.5) * 0.9
            var dx = normal.x + along.x * fan
            var dy = normal.y + along.y * fan
            let dl = max((dx * dx + dy * dy).squareRoot(), 0.0001)
            dx /= dl
            dy /= dl
            let length = maxLength * (0.55 + 0.45 * CGFloat(sin(Double.pi * Double(t))))
            let side: CGFloat = t < 0.5 ? 1 : -1
            let path = hair(base: CGPoint(x: q.x - normal.x * 14, y: q.y - normal.y * 14),
                            dir: CGPoint(x: dx, y: dy), length: length, width: 12, bend: 0.18 * side)
            var shadow = c
            shadow.translateBy(x: 3, y: 7)
            shadow.fill(path, with: .color(Color(snapHex: 0x051E0C, alpha: 0.35)))
            c.fill(path, with: .color(cilium))
        }
    }

    /// R4: the front lobe's shorter fringe, from the lip's margin down and out over the green outside of the leaf,
    /// fanning to the sides. The middle (under the fly and its hands) stays bare, so nothing reads as teeth.
    static func fringe(_ c: inout GraphicsContext) {
        let spots: [CGFloat] = [0.07, 0.17, 0.27, 0.36, 0.64, 0.73, 0.83, 0.93]
        let maxLength: CGFloat = 78
        for t in spots {
            let q = frontRim.point(t)
            let along = frontRim.tangent(t)
            let normal = CGPoint(x: -along.y, y: along.x)  // outward (down, toward the viewer)
            let fan = (t - 0.5) * 1.4
            var dx = normal.x + along.x * fan
            var dy = normal.y + along.y * fan
            let dl = max((dx * dx + dy * dy).squareRoot(), 0.0001)
            dx /= dl
            dy /= dl
            let length = maxLength * (0.6 + 0.4 * CGFloat(sin(Double.pi * Double(t))))
            let side: CGFloat = t < 0.5 ? 1 : -1
            let path = hair(base: CGPoint(x: q.x + normal.x * 6, y: q.y + normal.y * 6),
                            dir: CGPoint(x: dx, y: dy), length: length, width: 10, bend: 0.2 * side)
            var shadow = c
            shadow.translateBy(x: 3, y: 6)
            shadow.fill(path, with: .color(Color(snapHex: 0x0E3A16, alpha: 0.4)))
            c.fill(path, with: .color(cilium))
        }
    }

    // MARK: Lobes

    static func backLobe(_ ctx: inout GraphicsContext) {
        var c = trapContext(ctx)
        cilia(&c)
        let rim = curvePath(backRim)
        let faceRegion = region(backRim, frontRim)
        c.stroke(rim, with: .color(leafDark), style: StrokeStyle(lineWidth: 74, lineCap: .round, lineJoin: .round))
        let marginShade = Gradient(colors: [margin, marginDeep])
        c.stroke(rim, with: .linearGradient(marginShade, startPoint: CGPoint(x: 0, y: -300), endPoint: .zero),
                 style: StrokeStyle(lineWidth: 44, lineCap: .round, lineJoin: .round))
        // The glossy crimson inner face: hot at the top, deep down toward the hidden hinge.
        let crimson = Gradient(stops: [.init(color: faceHot, location: 0), .init(color: Self.face, location: 0.5),
                                       .init(color: faceDeep, location: 1)])
        c.fill(faceRegion, with: .radialGradient(crimson, center: CGPoint(x: -70, y: -180), startRadius: 10,
                                           endRadius: 380))
        var inside = c
        inside.clip(to: faceRegion)
        let depth = Gradient(colors: [Color(snapHex: 0x3C0414, alpha: 0.95), Color(snapHex: 0x3C0414, alpha: 0)])
        inside.fill(Path(CGRect(x: -cornerX, y: -400, width: cornerX * 2, height: 600)),
                    with: .linearGradient(depth, startPoint: CGPoint(x: 0, y: 120), endPoint: CGPoint(x: 0, y: -90)))
        // The wet gloss: a crescent upper-left and a small glint.
        var crescent = Path()
        crescent.move(to: CGPoint(x: -250, y: -80))
        crescent.addCurve(to: CGPoint(x: -20, y: -272), control1: CGPoint(x: -240, y: -200),
                          control2: CGPoint(x: -150, y: -262))
        crescent.addCurve(to: CGPoint(x: -250, y: -80), control1: CGPoint(x: -130, y: -232),
                          control2: CGPoint(x: -200, y: -170))
        crescent.closeSubpath()
        inside.fill(crescent, with: .color(Color.white.opacity(0.55)))
        inside.fill(ellipse(CGPoint(x: 70, y: -262), 22, 13, rotation: -0.1), with: .color(Color.white.opacity(0.45)))
    }

    static func frontLobe(_ ctx: inout GraphicsContext) {
        var c = trapContext(ctx)
        let outside = region(frontRim, frontBelly)
        let leaf = Gradient(colors: [leafLight, leafDark])
        c.fill(outside, with: .linearGradient(leaf, startPoint: CGPoint(x: 0, y: 60), endPoint: CGPoint(x: 0, y: 330)))
        var sheen = c
        sheen.clip(to: outside)
        sheen.fill(ellipse(CGPoint(x: -120, y: 215), 150, 26, rotation: 0.25), with: .color(Color.white.opacity(0.22)))
        // R4: the front lobe's own crimson inner face, a band just inside the lip: deep toward the hinge, bright at
        // the margin. It hides the fly's lower half, so the fly is inside the trap.
        let band = region(frontInner, frontRim)
        let lip = Gradient(stops: [.init(color: faceDeep, location: 0), .init(color: Self.face, location: 0.5),
                                   .init(color: lipFace, location: 1)])
        c.fill(band, with: .linearGradient(lip, startPoint: CGPoint(x: 0, y: 46), endPoint: CGPoint(x: 0, y: 116)))
        var wet = c
        wet.clip(to: band)
        wet.fill(ellipse(CGPoint(x: -150, y: 82), 72, 7, rotation: 0.2), with: .color(Color.white.opacity(0.3)))
        let marginShade = Gradient(colors: [margin, marginDeep])
        c.stroke(curvePath(frontRim),
                 with: .linearGradient(marginShade, startPoint: .zero, endPoint: CGPoint(x: 0, y: 170)),
                 style: StrokeStyle(lineWidth: 40, lineCap: .round, lineJoin: .round))
        fringe(&c)
    }

    // MARK: The fly (the in-game housefly, in the trap frame)

    static func fly(_ ctx: inout GraphicsContext) {
        var c = trapContext(ctx)
        let f = flyCenter
        // A dark halo on the crimson, so the grey fly separates from the face by value.
        softEllipse(&c, center: CGPoint(x: f.x + 4, y: f.y + 4), rx: 130, ry: 100, hex: 0x2A000C, alpha: 0.55)
        // Glassy wings up and out from the shoulders, behind the body, each with a vein and a glint.
        let wings: [(CGFloat, CGFloat)] = [(-42, -0.95), (42, 0.95)]
        for (dx, rot) in wings {
            var w = c
            w.translateBy(x: f.x + dx, y: f.y - 34)
            w.rotate(by: Angle(radians: Double(rot)))
            w.fill(ellipse(CGPoint(x: 4, y: -40), 25, 48), with: .color(Color(snapHex: 0x2A000C, alpha: 0.3)))
            let glass = Gradient(colors: [Color.white.opacity(0.9), flyWing.opacity(0.6)])
            w.fill(ellipse(CGPoint(x: 0, y: -44), 24, 47),
                   with: .linearGradient(glass, startPoint: CGPoint(x: 0, y: -92), endPoint: CGPoint(x: 0, y: 4)))
            var vein = Path()
            vein.move(to: CGPoint(x: 0, y: -4))
            vein.addQuadCurve(to: CGPoint(x: 2, y: -82), control: CGPoint(x: 6, y: -44))
            w.stroke(vein, with: .color(Color(snapHex: 0x8FA3C0, alpha: 0.55)),
                     style: StrokeStyle(lineWidth: 3, lineCap: .round))
            w.fill(ellipse(CGPoint(x: -9, y: -56), 4.5, 20), with: .color(Color.white.opacity(0.8)))
        }
        // The thorax behind, glossy grey-blue, lit from the upper left.
        let thoraxShade = Gradient(stops: [.init(color: flyLight, location: 0), .init(color: flyBody, location: 0.6),
                                           .init(color: flyDeep, location: 1)])
        c.fill(ellipse(CGPoint(x: f.x, y: f.y - 30), 58, 46),
               with: .radialGradient(thoraxShade, center: CGPoint(x: f.x - 20, y: f.y - 60), startRadius: 4,
                                     endRadius: 100))
        // The head in front, darker; its lower half sinks behind the front lobe.
        let headShade = Gradient(stops: [.init(color: flyBody, location: 0), .init(color: flyHead, location: 0.7),
                                         .init(color: flyDeep, location: 1)])
        c.fill(ellipse(CGPoint(x: f.x, y: f.y + 14), 64, 50),
               with: .radialGradient(headShade, center: CGPoint(x: f.x - 20, y: f.y - 14), startRadius: 4,
                                     endRadius: 90))
        c.fill(ellipse(CGPoint(x: f.x - 34, y: f.y - 16), 16, 7, rotation: -0.5),
               with: .color(Color.white.opacity(0.28)))
        // Cream eyes with dark pupils, looking up at the closing jaw, and pink cheeks.
        let eyeOffsets: [CGFloat] = [-30, 30]
        for dx in eyeOffsets {
            let e = CGPoint(x: f.x + dx, y: f.y + 6)
            c.fill(circle(CGPoint(x: e.x + 2, y: e.y + 4), 26), with: .color(Color(snapHex: 0x0A0E1E, alpha: 0.35)))
            let white = Gradient(colors: [Color.white, flyEye, Color(snapHex: 0xE6DCD6)])
            c.fill(circle(e, 25), with: .radialGradient(white, center: CGPoint(x: e.x - 8, y: e.y - 10),
                                                       startRadius: 2, endRadius: 32))
            c.fill(ellipse(CGPoint(x: e.x + 3, y: e.y - 8), 12, 14), with: .color(flyPupil))
            c.fill(circle(CGPoint(x: e.x - 1, y: e.y - 13), 4.5), with: .color(.white))
            c.fill(ellipse(CGPoint(x: e.x + dx * 0.5, y: e.y + 24), 10, 6), with: .color(flyCheek.opacity(0.45)))
        }
    }

    /// Two little hands gripping the front lip, either side of the fly.
    static func hands(_ ctx: inout GraphicsContext) {
        let c = trapContext(ctx)
        for dx in handOffsets {
            let q = lipPoint(nearX: flyCenter.x + dx)
            let h = CGPoint(x: q.x, y: q.y - 4)
            c.fill(ellipse(CGPoint(x: h.x + 2, y: h.y + 5), 18, 12), with: .color(Color(snapHex: 0x0E3A16, alpha: 0.35)))
            c.fill(ellipse(h, 18, 12), with: .color(flyBody))
            c.fill(ellipse(CGPoint(x: h.x - 5, y: h.y - 5), 7, 3.5), with: .color(Color.white.opacity(0.28)))
        }
    }
}
