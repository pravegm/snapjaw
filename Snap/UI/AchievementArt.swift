import SwiftUI

/// Game Center achievement images (R3, ROUND-3 "Badges"): one 1024 × 1024 opaque image per achievement (drawn in a
/// 512-point design space and scaled), a round medallion in the game's look (the bog's greens, a rim by tier: bronze,
/// silver, gold) with a drawn subject from the Scene's own `TrapArt` (the trap, the bugs) and at most a short numeral.
/// Rendered by demo `screen=badges` (`BadgeExport` in App/DemoMode.swift, after Swoop's). Unknown ids draw the trap.
struct AchievementBadge: View {
    let id: String
    var side: CGFloat = 1024

    var body: some View {
        let art = BadgeArt.load(for: id)
        Canvas(opaque: true, rendersAsynchronously: false) { context, size in
            let k = min(size.width, size.height) / BadgePainter.design
            context.scaleBy(x: k, y: k)
            BadgePainter.paint(&context, id: id, art: art)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

/// The images a badge draws, made once on the main actor before the Canvas runs.
struct BadgeArt {
    var trap: CGImage?
    var bugs: [BugSpecies: CGImage] = [:]

    /// Bugs are drawn big (radius 70 pt at 4×), so they stay crisp at 1024 px.
    static let bugRadius: CGFloat = 70

    @MainActor
    static func load(for id: String) -> BadgeArt {
        var art = BadgeArt(trap: TrapImageCache.image())
        for s in BadgePainter.species(for: id) {
            art.bugs[s] = TrapArt.bugImage(s, radius: bugRadius, scale: 4, wingSpread: s == .dragonfly ? 1 : 0.8)
        }
        return art
    }
}

enum BadgePainter {
    /// The design space (points).
    static let design: CGFloat = 512
    static let center = CGPoint(x: 256, y: 256)

    enum Tier { case bronze, silver, gold }

    static func tier(for id: String) -> Tier {
        switch id {
        case Achievements.monarch.id, Achievements.bugbook.id, Achievements.score10k.id, Achievements.chain4.id,
             Achievements.scarab.id:
            return .gold
        case Achievements.bite5.id, Achievements.spare50.id, Achievements.nobees.id, Achievements.night.id,
             Achievements.dragonfly.id:
            return .silver
        default:
            return .bronze
        }
    }

    /// The bugs each badge draws (loaded up front).
    static func species(for id: String) -> [BugSpecies] {
        switch id {
        case Achievements.feast.id: return [.housefly, .gnat, .fruitFly]
        case Achievements.bite5.id: return [.housefly, .bluebottle, .gnat, .ladybird, .fruitFly]
        case Achievements.scarab.id: return [.goldenScarab]
        case Achievements.dragonfly.id: return [.dragonfly]
        case Achievements.spare50.id, Achievements.nobees.id: return [.bee]
        case Achievements.bugbook.id: return [.ladybird, .moth]
        case Achievements.night.id: return [.firefly]
        default: return []
        }
    }

    static func paint(_ ctx: inout GraphicsContext, id: String, art: BadgeArt) {
        let night = id == Achievements.night.id
        background(&ctx)
        medallion(&ctx, tier: tier(for: id), night: night)
        switch id {
        case Achievements.feast.id:
            trap(&ctx, art, width: 330, y: 268)
            bugs(&ctx, art, [(.housefly, -74, -18, 92), (.gnat, 70, 22, 78), (.fruitFly, 6, 58, 76)])
        case Achievements.bite5.id:
            trap(&ctx, art, width: 330, y: 250)
            bugs(&ctx, art, [(.housefly, -86, -30, 80), (.bluebottle, 76, -36, 80), (.gnat, -46, 44, 66),
                             (.ladybird, 52, 40, 70), (.fruitFly, 4, -2, 66)])
            coin(&ctx, "5", at: CGPoint(x: 256, y: 378))
        case Achievements.chain4.id:
            chain(&ctx)
            coin(&ctx, "×4", at: CGPoint(x: 256, y: 372))
        case Achievements.scarab.id:
            glow(&ctx, at: center, radius: 170, color: SnapTheme.goldLight)
            bugs(&ctx, art, [(.goldenScarab, 0, 0, 250)])
            sparkles(&ctx)
        case Achievements.dragonfly.id:
            bugs(&ctx, art, [(.dragonfly, 0, 0, 290)])
        case Achievements.spare50.id:
            halo(&ctx)
            bugs(&ctx, art, [(.bee, 0, -12, 190)])
            coin(&ctx, "50", at: CGPoint(x: 256, y: 380))
        case Achievements.bugbook.id:
            book(&ctx, art)
            coin(&ctx, "16", at: CGPoint(x: 256, y: 384))
        case Achievements.monarch.id:
            trap(&ctx, art, width: 320, y: 300)
            crown(&ctx)
        case Achievements.night.id:
            moon(&ctx)
            glow(&ctx, at: CGPoint(x: 232, y: 300), radius: 110, color: Color(snapHex: 0xF6FF8A))
            bugs(&ctx, art, [(.firefly, -24, 44, 170)])
        case Achievements.daily.id:
            sun(&ctx)
            trap(&ctx, art, width: 300, y: 312)
        case Achievements.score10k.id:
            trap(&ctx, art, width: 220, y: 190)
            numeral(&ctx, "10K", size: 128, at: CGPoint(x: 256, y: 336))
        case Achievements.nobees.id:
            trap(&ctx, art, width: 300, y: 320)
            halo(&ctx, at: CGPoint(x: 256, y: 168), radius: 72)
            bugs(&ctx, art, [(.bee, 0, -88, 120)])
            coin(&ctx, "30", at: CGPoint(x: 360, y: 384))
        default:
            trap(&ctx, art, width: 330, y: 256)
        }
    }

    // MARK: Ground and medallion

    static func background(_ ctx: inout GraphicsContext) {
        let all = Path(CGRect(x: 0, y: 0, width: design, height: design))
        ctx.fill(all, with: .linearGradient(Gradient(colors: [SnapTheme.moss, SnapTheme.bogDeep, SnapTheme.night]),
                                            startPoint: CGPoint(x: 256, y: 0), endPoint: CGPoint(x: 256, y: design)))
    }

    static func medallion(_ ctx: inout GraphicsContext, tier: Tier, night: Bool) {
        let ring: Gradient
        switch tier {
        case .bronze: ring = Gradient(colors: [Color(snapHex: 0xE8B48A), Color(snapHex: 0xC98A5A), Color(snapHex: 0x8F5E38)])
        case .silver: ring = Gradient(colors: [Color(snapHex: 0xF1F5F7), Color(snapHex: 0xC9D3DC), Color(snapHex: 0x8E9AA6)])
        case .gold: ring = Gradient(colors: [Color(snapHex: 0xFFE69C), Color(snapHex: 0xF7C75B), Color(snapHex: 0xC98A2A)])
        }
        let outer = CGRect(x: 256 - 226, y: 256 - 226, width: 452, height: 452)
        ctx.fill(Path(ellipseIn: outer.offsetBy(dx: 0, dy: 10)), with: .color(Color.black.opacity(0.35)))
        ctx.fill(Path(ellipseIn: outer), with: .linearGradient(ring, startPoint: CGPoint(x: 256, y: 30),
                                                                endPoint: CGPoint(x: 256, y: 482)))
        let inner = outer.insetBy(dx: 26, dy: 26)
        let disc: [Color] = night
            ? [Color(snapHex: 0x2B3F7A), Color(snapHex: 0x15224A), Color(snapHex: 0x0A1230)]
            : [SnapTheme.mossLight, SnapTheme.moss, SnapTheme.bogDeep]
        ctx.fill(Path(ellipseIn: inner), with: .radialGradient(Gradient(colors: disc),
                                                                center: CGPoint(x: 256, y: 190), startRadius: 10,
                                                                endRadius: 260))
        // A soft sunlit lift at the top of the disc, and a dark inner lip.
        var inside = ctx
        inside.clip(to: Path(ellipseIn: inner))
        inside.fill(Path(ellipseIn: CGRect(x: 96, y: 40, width: 320, height: 200)),
                    with: .radialGradient(Gradient(colors: [Color.white.opacity(night ? 0.06 : 0.12), .clear]),
                                          center: CGPoint(x: 256, y: 120), startRadius: 0, endRadius: 170))
        ctx.stroke(Path(ellipseIn: inner), with: .color(Color.black.opacity(0.35)), lineWidth: 6)
        if tier == .gold {
            for i in 0..<12 {
                let a = Double(i) / 12 * 2 * Double.pi
                let x = 256 + CGFloat(cos(a)) * 213
                let y = 256 + CGFloat(sin(a)) * 213
                ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                         with: .color(Color(snapHex: 0xFFF3C4)))
            }
        }
    }

    // MARK: Subjects

    /// An image fitted to `width`, centred on `c`, turned by `degrees`.
    static func image(_ ctx: inout GraphicsContext, _ cg: CGImage?, center c: CGPoint, width: CGFloat,
                      degrees: Double = 0) {
        guard let cg, cg.width > 0, cg.height > 0 else { return }
        let h = width * CGFloat(cg.height) / CGFloat(cg.width)
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        if degrees != 0 { g.rotate(by: .degrees(degrees)) }
        g.draw(Image(decorative: cg, scale: 1), in: CGRect(x: -width / 2, y: -h / 2, width: width, height: h))
    }

    static func trap(_ ctx: inout GraphicsContext, _ art: BadgeArt, width: CGFloat, y: CGFloat) {
        if art.trap != nil {
            image(&ctx, art.trap, center: CGPoint(x: 256, y: y), width: width)
        } else {
            // No image: a plain crimson pair of lobes with a midrib.
            let r = CGRect(x: 256 - width / 2, y: y - width * 0.34, width: width, height: width * 0.68)
            ctx.fill(Path(ellipseIn: r), with: .color(Color(snapHex: 0x9A1A33)))
            var rib = Path()
            rib.move(to: CGPoint(x: 256, y: r.minY + 6))
            rib.addLine(to: CGPoint(x: 256, y: r.maxY - 6))
            ctx.stroke(rib, with: .color(Color(snapHex: 0x4E0716)), lineWidth: 8)
        }
    }

    /// Bugs at (dx, dy) from the centre, `w` wide, facing up and to the right like the game's portraits.
    static func bugs(_ ctx: inout GraphicsContext, _ art: BadgeArt, _ list: [(BugSpecies, CGFloat, CGFloat, CGFloat)]) {
        for (s, dx, dy, w) in list {
            image(&ctx, art.bugs[s], center: CGPoint(x: 256 + dx, y: 256 + dy), width: w, degrees: -24)
        }
    }

    static func glow(_ ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat, color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(Gradient(colors: [color.opacity(0.55), color.opacity(0)]), center: c,
                                       startRadius: 0, endRadius: r))
    }

    /// A gold coin with a short numeral.
    static func coin(_ ctx: inout GraphicsContext, _ text: String, at c: CGPoint) {
        let r: CGFloat = text.count > 2 ? 52 : 46
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        ctx.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 5)), with: .color(Color.black.opacity(0.35)))
        ctx.fill(Path(ellipseIn: rect), with: .linearGradient(Gradient(colors: [SnapTheme.goldLight, SnapTheme.gold,
                                                                               SnapTheme.goldDeep]),
                                                               startPoint: CGPoint(x: c.x, y: rect.minY),
                                                               endPoint: CGPoint(x: c.x, y: rect.maxY)))
        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 5, dy: 5)), with: .color(Color.white.opacity(0.45)), lineWidth: 3)
        ctx.draw(Text(text).font(.system(size: text.count > 2 ? 40 : 48, weight: .black, design: .rounded))
                    .foregroundColor(SnapTheme.ink), at: c)
    }

    static func numeral(_ ctx: inout GraphicsContext, _ text: String, size: CGFloat, at c: CGPoint) {
        ctx.draw(Text(text).font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundColor(SnapTheme.crimsonDeep), at: CGPoint(x: c.x, y: c.y + 7))
        ctx.draw(Text(text).font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundColor(SnapTheme.goldLight), at: c)
    }

    /// Three gold links, interlocked.
    static func chain(_ ctx: inout GraphicsContext) {
        for (i, x) in [CGFloat(150), 256, 362].enumerated() {
            var g = ctx
            g.translateBy(x: x, y: 236)
            g.rotate(by: .degrees(i % 2 == 0 ? -28 : 28))
            let link = Path(roundedRect: CGRect(x: -74, y: -40, width: 148, height: 80), cornerRadius: 40)
            g.stroke(link, with: .color(Color.black.opacity(0.35)), lineWidth: 30)
            g.stroke(link, with: .linearGradient(Gradient(colors: [SnapTheme.goldLight, SnapTheme.goldDeep]),
                                                 startPoint: CGPoint(x: 0, y: -40), endPoint: CGPoint(x: 0, y: 40)),
                     lineWidth: 22)
        }
    }

    /// The protected bug's dashed white halo (the game's "wait" ring).
    static func halo(_ ctx: inout GraphicsContext, at c: CGPoint = CGPoint(x: 256, y: 244), radius r: CGFloat = 128) {
        let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        ctx.stroke(ring, with: .color(Color.black.opacity(0.3)), lineWidth: 14)
        ctx.stroke(ring, with: .color(Color.white.opacity(0.9)), style: StrokeStyle(lineWidth: 8, dash: [22, 14]))
    }

    static func sparkles(_ ctx: inout GraphicsContext) {
        for (x, y, s) in [(CGFloat(150), CGFloat(150), CGFloat(22)), (370, 176, 16), (352, 352, 20), (162, 344, 14)] {
            var p = Path()
            p.move(to: CGPoint(x: x, y: y - s))
            p.addQuadCurve(to: CGPoint(x: x + s, y: y), control: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x, y: y + s), control: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x - s, y: y), control: CGPoint(x: x, y: y))
            p.addQuadCurve(to: CGPoint(x: x, y: y - s), control: CGPoint(x: x, y: y))
            ctx.fill(p, with: .color(Color(snapHex: 0xFFF3C4)))
        }
    }

    /// An open Bug Book: two cream pages, a bug on each.
    static func book(_ ctx: inout GraphicsContext, _ art: BadgeArt) {
        for side in [CGFloat(-1), 1] {
            var page = Path()
            let x0: CGFloat = 256
            let x1: CGFloat = 256 + side * 150
            page.move(to: CGPoint(x: x0, y: 168))
            page.addQuadCurve(to: CGPoint(x: x1, y: 150), control: CGPoint(x: (x0 + x1) / 2, y: 140))
            page.addLine(to: CGPoint(x: x1, y: 322))
            page.addQuadCurve(to: CGPoint(x: x0, y: 340), control: CGPoint(x: (x0 + x1) / 2, y: 312))
            page.closeSubpath()
            ctx.fill(page.offsetBy(dx: 0, dy: 8), with: .color(Color.black.opacity(0.3)))
            ctx.fill(page, with: .color(SnapTheme.cream))
            ctx.stroke(page, with: .color(SnapTheme.goldDeep), lineWidth: 4)
        }
        var spine = Path()
        spine.move(to: CGPoint(x: 256, y: 168))
        spine.addLine(to: CGPoint(x: 256, y: 340))
        ctx.stroke(spine, with: .color(SnapTheme.goldDeep), lineWidth: 6)
        bugs(&ctx, art, [(.ladybird, -76, -10, 104), (.moth, 76, -10, 116)])
    }

    static func crown(_ ctx: inout GraphicsContext) {
        var p = Path()
        p.move(to: CGPoint(x: 170, y: 190))
        p.addLine(to: CGPoint(x: 160, y: 104))
        p.addLine(to: CGPoint(x: 210, y: 146))
        p.addLine(to: CGPoint(x: 256, y: 84))
        p.addLine(to: CGPoint(x: 302, y: 146))
        p.addLine(to: CGPoint(x: 352, y: 104))
        p.addLine(to: CGPoint(x: 342, y: 190))
        p.closeSubpath()
        ctx.fill(p.offsetBy(dx: 0, dy: 6), with: .color(Color.black.opacity(0.35)))
        ctx.fill(p, with: .linearGradient(Gradient(colors: [SnapTheme.goldLight, SnapTheme.gold, SnapTheme.goldDeep]),
                                          startPoint: CGPoint(x: 256, y: 84), endPoint: CGPoint(x: 256, y: 190)))
        for (x, y) in [(CGFloat(160), CGFloat(104)), (256, 84), (352, 104)] {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 10, y: y - 10, width: 20, height: 20)),
                     with: .color(SnapTheme.crimson))
        }
    }

    static func moon(_ ctx: inout GraphicsContext) {
        let full = Path(ellipseIn: CGRect(x: 268, y: 92, width: 132, height: 132))
        var lit = ctx
        lit.clipToLayer { layer in
            layer.fill(full, with: .color(.white))
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: 302, y: 76, width: 132, height: 132)), with: .color(.white))
        }
        lit.fill(full, with: .color(Color(snapHex: 0xFFF3C4)))
        for (x, y) in [(CGFloat(140), CGFloat(140)), (190, 96), (120, 230), (400, 270), (368, 360), (150, 372)] {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)), with: .color(.white.opacity(0.8)))
        }
    }

    static func sun(_ ctx: inout GraphicsContext) {
        let c = CGPoint(x: 256, y: 196)
        for i in 0..<12 {
            let a = Double(i) / 12 * 2 * Double.pi
            var ray = Path()
            ray.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * 104, y: c.y + CGFloat(sin(a)) * 104))
            ray.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * 140, y: c.y + CGFloat(sin(a)) * 140))
            ctx.stroke(ray, with: .color(SnapTheme.goldLight), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - 88, y: c.y - 88, width: 176, height: 176)),
                 with: .radialGradient(Gradient(colors: [SnapTheme.goldLight, SnapTheme.gold]), center: c,
                                       startRadius: 0, endRadius: 88))
    }
}
