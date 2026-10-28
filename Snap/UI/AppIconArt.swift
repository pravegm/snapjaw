import SwiftUI

/// The App Store icon (R2, juror P2 #10): the trap's two lobes open like a mouth round a fat cartoon fly, in the game's
/// own look: a green leaf outside, a deep glossy crimson face (#7A0C26 → #D23048 at the rim), a dark throat, and long
/// thin pale CILIA along both rims (not fangs). The fly sits in FRONT of everything, so no line runs through it. The
/// subject fills ~88 % of the canvas, and the big shapes (green jaws, dark throat, the fly's two white eyes) read at
/// 60 px.
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
    static let bogCenter = Color(snapHex: 0x2F7A45)
    static let bogEdge = Color(snapHex: 0x0A2614)
    static let leafLight = Color(snapHex: 0x7DBF45)
    static let leafDark = Color(snapHex: 0x2F6A2C)
    static let faceRim = Color(snapHex: 0xD23048)
    static let faceDeep = Color(snapHex: 0x7A0C26)
    static let throat = Color(snapHex: 0x33040F)
    static let cilium = Color(snapHex: 0xF2F7DA)
    static let ink = Color(snapHex: 0x10220D)
    static let flyBody = Color(snapHex: 0x2E3348)
    static let flyBelly = Color(snapHex: 0x59627E)
    static let wing = Color(snapHex: 0xDDF2FF)

    /// The hinge (left) and the two jaw tips (right): the lobes open to the right like a mouth.
    static let hinge = CGPoint(x: 84, y: 524)
    static let upperTip = CGPoint(x: 972, y: 318)
    static let lowerTip = CGPoint(x: 972, y: 730)

    static func paint(_ ctx: inout GraphicsContext) {
        background(&ctx)
        throatFill(&ctx)
        lobe(&ctx, upper: false)
        lobe(&ctx, upper: true)
        cilia(&ctx)
        fly(&ctx)
    }

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [bogCenter, bogEdge]), center: CGPoint(x: 512, y: 470),
                                            startRadius: 40, endRadius: 760))
        // Dew in the corners.
        for (x, y, r) in [(70.0, 90.0, 14.0), (950.0, 80.0, 11.0), (60.0, 960.0, 11.0), (960.0, 958.0, 15.0)] {
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.2)))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.55, dy: r * 0.55).offsetBy(dx: -r * 0.2, dy: -r * 0.25)),
                     with: .color(Color.white.opacity(0.7)))
        }
    }

    // MARK: Lobes

    /// The outer curve of a lobe (hinge → tip).
    static func outerControls(upper: Bool) -> (CGPoint, CGPoint) {
        upper ? (CGPoint(x: 92, y: 70), CGPoint(x: 780, y: 20)) : (CGPoint(x: 92, y: 980), CGPoint(x: 780, y: 1030))
    }

    /// The rim (tip → hinge).
    static func rimControls(upper: Bool) -> (CGPoint, CGPoint) {
        upper ? (CGPoint(x: 720, y: 420), CGPoint(x: 330, y: 492)) : (CGPoint(x: 720, y: 630), CGPoint(x: 330, y: 556))
    }

    static func lobePath(upper: Bool) -> Path {
        let tip = upper ? upperTip : lowerTip
        let o = outerControls(upper: upper)
        let r = rimControls(upper: upper)
        var p = Path()
        p.move(to: hinge)
        p.addCurve(to: tip, control1: o.0, control2: o.1)
        p.addCurve(to: hinge, control1: r.0, control2: r.1)
        p.closeSubpath()
        return p
    }

    /// The crimson inner face: a broad band inside the leaf, along the rim.
    static func facePath(upper: Bool) -> Path {
        let tip = upper ? upperTip : lowerTip
        let r = rimControls(upper: upper)
        let k: CGFloat = upper ? 1 : -1
        var p = Path()
        p.move(to: CGPoint(x: hinge.x + 46, y: hinge.y - k * 6))
        p.addCurve(to: CGPoint(x: tip.x - 34, y: tip.y - k * 28),
                   control1: CGPoint(x: 180, y: upper ? 250 : 800),
                   control2: CGPoint(x: 720, y: upper ? 170 : 880))
        p.addCurve(to: CGPoint(x: hinge.x + 46, y: hinge.y - k * 6), control1: r.0, control2: r.1)
        p.closeSubpath()
        return p
    }

    /// The dark throat between the two rims (the mouth reads at any size).
    static func throatFill(_ ctx: inout GraphicsContext) {
        let up = rimControls(upper: true)
        let low = rimControls(upper: false)
        var p = Path()
        p.move(to: hinge)
        p.addCurve(to: upperTip, control1: up.1, control2: up.0)
        p.addLine(to: lowerTip)
        p.addCurve(to: hinge, control1: low.0, control2: low.1)
        p.closeSubpath()
        ctx.fill(p, with: .radialGradient(Gradient(colors: [Color(snapHex: 0x5A0A1E), throat]),
                                          center: CGPoint(x: 600, y: 524), startRadius: 20, endRadius: 420))
    }

    static func lobe(_ ctx: inout GraphicsContext, upper: Bool) {
        let outer = lobePath(upper: upper)
        let face = facePath(upper: upper)
        ctx.stroke(outer, with: .color(ink), style: StrokeStyle(lineWidth: 26, lineJoin: .round))
        ctx.fill(outer, with: .linearGradient(Gradient(colors: upper ? [leafLight, leafDark] : [leafDark, leafLight]),
                                              startPoint: CGPoint(x: 512, y: upper ? 40 : 560),
                                              endPoint: CGPoint(x: 512, y: upper ? 500 : 1010)))
        // The deep face: darkest inside, brightest at the rim.
        ctx.fill(face, with: .linearGradient(Gradient(colors: [faceDeep, faceRim]),
                                             startPoint: CGPoint(x: 512, y: upper ? 210 : 840),
                                             endPoint: CGPoint(x: 512, y: upper ? 480 : 570)))
        // The wet gloss: a long soft streak on the face and a highlight on the leaf.
        var gloss = ctx
        gloss.clip(to: face)
        let streak = upper ? CGRect(x: 330, y: 250, width: 420, height: 70) : CGRect(x: 360, y: 760, width: 360, height: 56)
        gloss.fill(Path(ellipseIn: streak), with: .color(Color.white.opacity(0.34)))
        var sheen = ctx
        sheen.clip(to: outer)
        let leafShine = upper ? CGRect(x: 160, y: 110, width: 380, height: 60) : CGRect(x: 200, y: 905, width: 300, height: 40)
        sheen.fill(Path(ellipseIn: leafShine), with: .color(Color.white.opacity(upper ? 0.30 : 0.14)))
        // A thin dark lip along the rim.
        var rim = Path()
        let tip = upper ? upperTip : lowerTip
        let r = rimControls(upper: upper)
        rim.move(to: tip)
        rim.addCurve(to: hinge, control1: r.0, control2: r.1)
        ctx.stroke(rim, with: .color(Color(snapHex: 0x173D17)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }

    // MARK: Cilia

    /// A point on the rim curve (tip → hinge) at `t` (0 tip … 1 hinge).
    static func rimPoint(upper: Bool, t: CGFloat) -> CGPoint {
        let p0 = upper ? upperTip : lowerTip
        let c = rimControls(upper: upper)
        let p1 = c.0
        let p2 = c.1
        let p3 = hinge
        let u = 1 - t
        let x = u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x
        let y = u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
        return CGPoint(x: x, y: y)
    }

    /// One cilium: a long, thin, slightly curved hair from `base` along `dir` (unit).
    static func ciliumPath(base: CGPoint, dir: CGPoint, length: CGFloat, width: CGFloat) -> Path {
        let n = CGPoint(x: -dir.y, y: dir.x)
        let tip = CGPoint(x: base.x + dir.x * length, y: base.y + dir.y * length)
        var p = Path()
        p.move(to: CGPoint(x: base.x - n.x * width, y: base.y - n.y * width))
        p.addQuadCurve(to: tip, control: CGPoint(x: base.x + dir.x * length * 0.55 - n.x * width * 0.35,
                                                 y: base.y + dir.y * length * 0.55 - n.y * width * 0.35))
        p.addQuadCurve(to: CGPoint(x: base.x + n.x * width, y: base.y + n.y * width),
                       control: CGPoint(x: base.x + dir.x * length * 0.5 + n.x * width * 0.7,
                                        y: base.y + dir.y * length * 0.5 + n.y * width * 0.7))
        p.closeSubpath()
        return p
    }

    /// Interlocking cilia along both rims, leaning toward the tips; drawn before the fly so none crosses it.
    static func cilia(_ ctx: inout GraphicsContext) {
        let count = 12
        for upper in [true, false] {
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(count - 1) * 0.8 + (upper ? 0.02 : 0.06)
                let base = rimPoint(upper: upper, t: t)
                let lean: CGFloat = 0.38
                // Across the throat toward the other jaw (they interlock when it shuts), leaning to the tips.
                let dy: CGFloat = upper ? 1 : -1
                let len = (lean * lean + 1).squareRoot()
                let dir = CGPoint(x: lean / len, y: dy / len)
                let length: CGFloat = 118 - CGFloat(i) * 4
                let hair = ciliumPath(base: base, dir: dir, length: length, width: 10)
                ctx.stroke(hair, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
                ctx.fill(hair, with: .color(cilium))
            }
        }
    }

    // MARK: The fly (in front of everything)

    static let flyCenter = CGPoint(x: 566, y: 528)

    static func fly(_ ctx: inout GraphicsContext) {
        // Wings peeking up behind the body.
        for (dx, rot) in [(-78.0, -0.5), (34.0, 0.35)] {
            var wingCtx = ctx
            wingCtx.translateBy(x: flyCenter.x + CGFloat(dx), y: flyCenter.y - 124)
            wingCtx.rotate(by: Angle(radians: rot))
            let wingRect = CGRect(x: -66, y: -116, width: 132, height: 222)
            wingCtx.stroke(Path(ellipseIn: wingRect), with: .color(ink), lineWidth: 12)
            wingCtx.fill(Path(ellipseIn: wingRect), with: .color(wing.opacity(0.94)))
            wingCtx.fill(Path(ellipseIn: CGRect(x: -40, y: -90, width: 30, height: 120)),
                         with: .color(Color.white.opacity(0.6)))
        }
        // The fat body with a glossy highlight.
        let bodyRect = CGRect(x: flyCenter.x - 176, y: flyCenter.y - 124, width: 340, height: 248)
        ctx.stroke(Path(ellipseIn: bodyRect), with: .color(ink), lineWidth: 18)
        ctx.fill(Path(ellipseIn: bodyRect), with: .radialGradient(Gradient(colors: [flyBelly, flyBody]),
                                                                   center: CGPoint(x: flyCenter.x - 40,
                                                                                   y: flyCenter.y - 60),
                                                                   startRadius: 10, endRadius: 210))
        ctx.fill(Path(ellipseIn: CGRect(x: flyCenter.x - 130, y: flyCenter.y - 96, width: 120, height: 46)),
                 with: .color(Color.white.opacity(0.28)))
        // Two huge eyes and a worried little mouth.
        for dx in [-24.0, 92.0] {
            let c = CGPoint(x: flyCenter.x + CGFloat(dx), y: flyCenter.y - 30)
            let eye = CGRect(x: c.x - 64, y: c.y - 64, width: 128, height: 128)
            ctx.stroke(Path(ellipseIn: eye), with: .color(ink), lineWidth: 14)
            ctx.fill(Path(ellipseIn: eye), with: .color(.white))
            let pupil = CGRect(x: c.x - 22, y: c.y - 34, width: 54, height: 62)
            ctx.fill(Path(ellipseIn: pupil), with: .color(ink))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 28, width: 19, height: 19)), with: .color(.white))
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: flyCenter.x + 12, y: flyCenter.y + 74))
        mouth.addQuadCurve(to: CGPoint(x: flyCenter.x + 66, y: flyCenter.y + 74),
                           control: CGPoint(x: flyCenter.x + 39, y: flyCenter.y + 52))
        ctx.stroke(mouth, with: .color(Color.white.opacity(0.85)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }
}
