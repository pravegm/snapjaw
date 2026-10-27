import SwiftUI

/// The trap drawn by SwiftUI from the Scene's own paths (`TrapArt.lobePath`/`teethPath`, `TrapArt.palette`), so
/// Home's title trap, the pose and cover cards and the in-game trap are one art source. `closure01` 0 open … 1 snapped.
/// Drawn in scene space (952 × 670, y up) and fitted into the view.
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
        let inner = Color(snapRGBA: p.lobeInner)
        let skin = Color(snapRGBA: p.lobeOuter)
        let gloss = Color(snapRGBA: p.lobeGloss)
        let rim = Color(snapRGBA: p.rim)
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
            let shadowRect = CGRect(x: center.x - a * 1.02, y: center.y - b * 1.06, width: a * 2.04, height: b * 2.04)
            context.fill(Path(ellipseIn: shadowRect).applying(t), with: .color(Color.black.opacity(0.28)))
            for (i, lobe) in lobes.enumerated() {
                let l = lobe.applying(t)
                let side: CGFloat = i == 0 ? -1 : 1
                // The outer skin peeks round the rim, then the crimson face, darker toward the midrib.
                context.stroke(l, with: .color(skin), style: StrokeStyle(lineWidth: 26 * s, lineJoin: .round))
                context.fill(l, with: .color(inner))
                let mid = CGPoint(x: center.x, y: center.y).applying(t)
                let edge = CGPoint(x: center.x + side * a, y: center.y).applying(t)
                context.fill(l, with: .linearGradient(Gradient(colors: [Color.black.opacity(0.32),
                                                                        Color.black.opacity(0)]),
                                                      startPoint: mid, endPoint: CGPoint(x: (mid.x + edge.x) / 2,
                                                                                         y: mid.y)))
                // Closing darkens the outer edges (the screen agrees with your hands).
                if c > 0.01 {
                    context.fill(l, with: .linearGradient(Gradient(colors: [Color.black.opacity(0),
                                                                            Color.black.opacity(0.45 * Double(c))]),
                                                          startPoint: CGPoint(x: (mid.x + edge.x) / 2, y: mid.y),
                                                          endPoint: edge))
                }
                // The wet sheen: one soft streak per lobe.
                let streak = CGRect(x: center.x + side * a * 0.48 - a * 0.16, y: center.y + b * 0.30,
                                    width: a * 0.32, height: b * 0.20)
                var glossCtx = context
                glossCtx.clip(to: l)
                glossCtx.fill(Path(ellipseIn: streak).applying(t), with: .color(gloss.opacity(0.55)))
                context.stroke(l, with: .color(rim), style: StrokeStyle(lineWidth: 9 * s, lineJoin: .round))
            }
            // The midrib.
            let ribTop = CGPoint(x: center.x, y: center.y + b * 0.92).applying(t)
            let ribBottom = CGPoint(x: center.x, y: center.y - b * 0.92).applying(t)
            var rib = Path()
            rib.move(to: ribTop)
            rib.addLine(to: ribBottom)
            context.stroke(rib, with: .color(rim.opacity(0.85)), style: StrokeStyle(lineWidth: 10 * s, lineCap: .round))
            for row in teeth {
                let path = row.applying(t)
                context.fill(path, with: .color(tooth))
                context.stroke(path, with: .color(ink.opacity(0.35)), lineWidth: max(1.5 * s, 0.8))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A bug drawn from the Scene's own paths (`TrapArt.bugBody`/`bugWings`/`bugColors`), facing right, fitted into the
/// view. `found` false draws its silhouette (the Bug Book's unfound pages).
struct BugPortrait: View {
    let species: BugSpecies
    var found = true
    /// Wings a little open (flying) or folded.
    var flying = false

    var body: some View {
        let r = max(BugCatalog.info(species).radius, 4)
        let bodyPath = Path(TrapArt.bugBody(species, radius: r))
        let wingPath = Path(TrapArt.bugWings(species, radius: r))
        let colors = TrapArt.bugColors(species)
        let bodyColor = Color(snapRGBA: colors.body)
        let accent = Color(snapRGBA: colors.accent)
        let wing = Color(snapRGBA: colors.wing)
        let eye = Color(snapRGBA: colors.eye)
        let ink = Color(snapRGBA: TrapArt.palette.ink)
        let box = bodyPath.boundingRect.union(wingPath.boundingRect)
        let bodyBox = bodyPath.boundingRect
        let isFound = found
        let lifted = flying
        Canvas { context, size in
            guard box.width > 0, box.height > 0 else { return }
            let s = min(size.width / box.width, size.height / box.height) * 0.86
            // y flipped (the Scene's paths are y up), centred.
            let t = CGAffineTransform(a: s, b: 0, c: 0, d: -s, tx: size.width / 2 - box.midX * s,
                                      ty: size.height / 2 + box.midY * s)
            let w = wingPath.applying(t)
            let bp = bodyPath.applying(t)
            if !isFound {
                context.fill(w, with: .color(Color.black.opacity(0.35)))
                context.fill(bp, with: .color(Color.black.opacity(0.55)))
                context.stroke(bp, with: .color(SnapTheme.mossLight), lineWidth: 2)
                return
            }
            var wings = context
            wings.opacity = lifted ? 0.75 : 0.9
            wings.fill(w, with: .color(wing))
            wings.stroke(w, with: .color(ink.opacity(0.35)), lineWidth: max(1, 1.2 * s))
            context.fill(bp, with: .linearGradient(Gradient(colors: [bodyColor, accent]),
                                                   startPoint: CGPoint(x: bp.boundingRect.midX, y: bp.boundingRect.minY),
                                                   endPoint: CGPoint(x: bp.boundingRect.midX, y: bp.boundingRect.maxY)))
            context.stroke(bp, with: .color(ink.opacity(0.8)), lineWidth: max(1.2, 1.6 * s))
            // Big cartoon eyes at the front (+x).
            let h = bodyBox.height
            let eyeR = max(h * 0.15, 1)
            for dy in [h * 0.17, -h * 0.17] {
                let c = CGPoint(x: bodyBox.maxX - h * 0.24, y: bodyBox.midY + dy).applying(t)
                let rr = eyeR * s
                context.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                             with: .color(.white))
                let pr = rr * 0.55
                context.fill(Path(ellipseIn: CGRect(x: c.x - pr + rr * 0.25, y: c.y - pr, width: pr * 2, height: pr * 2)),
                             with: .color(eye))
            }
        }
        .accessibilityHidden(true)
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
