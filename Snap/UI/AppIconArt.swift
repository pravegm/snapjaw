import SwiftUI

/// The App Store icon: the trap's two lobes snapping on a fat cartoon fly, teeth interlocking, glossy crimson on deep
/// bog green. Big shapes only, so it reads at 60 px: the lime lobes, the crimson mouth, the cream teeth, the fly's two
/// white eyes.
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
    static let bogEdge = Color(snapHex: 0x0B2C17)
    static let skinLight = Color(snapHex: 0xB6E05A)
    static let skinDark = Color(snapHex: 0x5E9A2A)
    static let crimsonLight = Color(snapHex: 0xFF6A88)
    static let crimson = Color(snapHex: 0xD3204A)
    static let crimsonDeep = Color(snapHex: 0x7E0E2B)
    static let tooth = Color(snapHex: 0xF4FBDF)
    static let ink = Color(snapHex: 0x13280F)
    static let flyBody = Color(snapHex: 0x2E3140)
    static let flyBelly = Color(snapHex: 0x4A5066)
    static let wing = Color(snapHex: 0xD9F1FF)
    static let eyeRed = Color(snapHex: 0xC0182E)

    /// The hinge (left) and the two jaw tips (right): the lobes open to the right like a mouth.
    static let hinge = CGPoint(x: 150, y: 548)
    static let upperTip = CGPoint(x: 905, y: 430)
    static let lowerTip = CGPoint(x: 905, y: 668)

    static func paint(_ ctx: inout GraphicsContext) {
        background(&ctx)
        lobe(&ctx, upper: false)
        lobe(&ctx, upper: true)
        fly(&ctx)
        teeth(&ctx)
        flyFace(&ctx)
    }

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        ctx.fill(all, with: .radialGradient(Gradient(colors: [bogCenter, bogEdge]), center: CGPoint(x: 512, y: 470),
                                            startRadius: 40, endRadius: 760))
        // Dew.
        for (x, y, r) in [(120.0, 170.0, 16.0), (860.0, 140.0, 12.0), (90.0, 880.0, 12.0), (930.0, 900.0, 18.0)] {
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.22)))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.55, dy: r * 0.55).offsetBy(dx: -r * 0.2, dy: -r * 0.25)),
                     with: .color(Color.white.opacity(0.7)))
        }
    }

    // MARK: Lobes

    /// The outer curve of a lobe (hinge → tip) and its rim (tip → hinge).
    static func outerControls(upper: Bool) -> (CGPoint, CGPoint) {
        upper ? (CGPoint(x: 160, y: 190), CGPoint(x: 760, y: 110)) : (CGPoint(x: 160, y: 910), CGPoint(x: 760, y: 990))
    }

    static func rimControls(upper: Bool) -> (CGPoint, CGPoint) {
        upper ? (CGPoint(x: 700, y: 520), CGPoint(x: 360, y: 545)) : (CGPoint(x: 700, y: 585), CGPoint(x: 360, y: 556))
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

    /// The crimson inner face: a band inside the outer skin, along the rim.
    static func facePath(upper: Bool) -> Path {
        let tip = upper ? upperTip : lowerTip
        let r = rimControls(upper: upper)
        let inset: CGFloat = upper ? 1 : -1
        var p = Path()
        p.move(to: CGPoint(x: hinge.x + 40, y: hinge.y - inset * 8))
        p.addCurve(to: CGPoint(x: tip.x - 30, y: tip.y - inset * 26),
                   control1: CGPoint(x: 230, y: upper ? 300 : 800),
                   control2: CGPoint(x: 720, y: upper ? 250 : 850))
        p.addCurve(to: CGPoint(x: hinge.x + 40, y: hinge.y - inset * 8), control1: r.0, control2: r.1)
        p.closeSubpath()
        return p
    }

    static func lobe(_ ctx: inout GraphicsContext, upper: Bool) {
        let outer = lobePath(upper: upper)
        let face = facePath(upper: upper)
        ctx.stroke(outer, with: .color(ink), style: StrokeStyle(lineWidth: 30, lineJoin: .round))
        ctx.fill(outer, with: .linearGradient(Gradient(colors: upper ? [skinLight, skinDark] : [skinDark, skinLight]),
                                              startPoint: CGPoint(x: 512, y: upper ? 120 : 600),
                                              endPoint: CGPoint(x: 512, y: upper ? 540 : 980)))
        ctx.fill(face, with: .linearGradient(Gradient(colors: upper ? [crimsonDeep, crimson, crimsonLight]
                                                                    : [crimsonLight, crimson, crimsonDeep]),
                                             startPoint: CGPoint(x: 512, y: upper ? 260 : 560),
                                             endPoint: CGPoint(x: 512, y: upper ? 540 : 860)))
        // The wet sheen.
        var gloss = ctx
        gloss.clip(to: face)
        let streak = upper ? CGRect(x: 420, y: 300, width: 300, height: 70) : CGRect(x: 420, y: 760, width: 260, height: 60)
        gloss.fill(Path(ellipseIn: streak), with: .color(Color.white.opacity(0.38)))
        // The rim line.
        var rim = Path()
        let tip = upper ? upperTip : lowerTip
        let r = rimControls(upper: upper)
        rim.move(to: tip)
        rim.addCurve(to: hinge, control1: r.0, control2: r.1)
        ctx.stroke(rim, with: .color(skinLight), style: StrokeStyle(lineWidth: 16, lineCap: .round))
    }

    // MARK: Teeth

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

    static func teeth(_ ctx: inout GraphicsContext) {
        let count = 7
        for upper in [true, false] {
            for i in 0..<count {
                let t = CGFloat(i) / CGFloat(count) * 0.78 + (upper ? 0.02 : 0.07)
                let base = rimPoint(upper: upper, t: t)
                let length: CGFloat = 92 - CGFloat(i) * 6
                let half: CGFloat = 17
                let dir: CGFloat = upper ? 1 : -1
                var tooth = Path()
                tooth.move(to: CGPoint(x: base.x - half, y: base.y - dir * 4))
                tooth.addQuadCurve(to: CGPoint(x: base.x + 6, y: base.y + dir * length),
                                   control: CGPoint(x: base.x - half * 0.6, y: base.y + dir * length * 0.6))
                tooth.addQuadCurve(to: CGPoint(x: base.x + half, y: base.y - dir * 4),
                                   control: CGPoint(x: base.x + half * 0.8, y: base.y + dir * length * 0.4))
                tooth.closeSubpath()
                ctx.stroke(tooth, with: .color(ink), style: StrokeStyle(lineWidth: 9, lineJoin: .round))
                ctx.fill(tooth, with: .color(Self.tooth))
            }
        }
    }

    // MARK: The fly

    static let flyCenter = CGPoint(x: 610, y: 552)

    static func fly(_ ctx: inout GraphicsContext) {
        // Wings peeking up out of the jaws.
        for (dx, rot) in [(-70.0, -0.5), (40.0, 0.35)] {
            var wingCtx = ctx
            wingCtx.translateBy(x: flyCenter.x + CGFloat(dx), y: flyCenter.y - 120)
            wingCtx.rotate(by: Angle(radians: rot))
            let wingRect = CGRect(x: -62, y: -110, width: 124, height: 210)
            wingCtx.stroke(Path(ellipseIn: wingRect), with: .color(ink), lineWidth: 12)
            wingCtx.fill(Path(ellipseIn: wingRect), with: .color(wing.opacity(0.92)))
            wingCtx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: 90))
                p.addLine(to: CGPoint(x: 0, y: -80))
            }, with: .color(ink.opacity(0.35)), lineWidth: 6)
        }
        // The fat body.
        let bodyRect = CGRect(x: flyCenter.x - 170, y: flyCenter.y - 120, width: 330, height: 240)
        ctx.stroke(Path(ellipseIn: bodyRect), with: .color(ink), lineWidth: 18)
        ctx.fill(Path(ellipseIn: bodyRect), with: .radialGradient(Gradient(colors: [flyBelly, flyBody]),
                                                                   center: CGPoint(x: flyCenter.x - 30,
                                                                                   y: flyCenter.y - 50),
                                                                   startRadius: 10, endRadius: 200))
    }

    /// The fly's face, over the teeth so it reads: two huge eyes and a worried little mouth.
    static func flyFace(_ ctx: inout GraphicsContext) {
        for dx in [-20.0, 92.0] {
            let c = CGPoint(x: flyCenter.x + CGFloat(dx), y: flyCenter.y - 34)
            let eye = CGRect(x: c.x - 62, y: c.y - 62, width: 124, height: 124)
            ctx.stroke(Path(ellipseIn: eye), with: .color(ink), lineWidth: 14)
            ctx.fill(Path(ellipseIn: eye), with: .color(.white))
            let pupil = CGRect(x: c.x - 22, y: c.y - 36, width: 52, height: 60)
            ctx.fill(Path(ellipseIn: pupil), with: .color(ink))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 30, width: 18, height: 18)), with: .color(.white))
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: flyCenter.x + 14, y: flyCenter.y + 66))
        mouth.addQuadCurve(to: CGPoint(x: flyCenter.x + 66, y: flyCenter.y + 66),
                           control: CGPoint(x: flyCenter.x + 40, y: flyCenter.y + 46))
        ctx.stroke(mouth, with: .color(Color.white.opacity(0.85)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }
}
