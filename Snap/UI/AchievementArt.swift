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
    /// The Scene's own 3/4 trap, when it has one (R4); else the open trap is tilted here.
    var hero: CGImage?
    var bugs: [BugSpecies: CGImage] = [:]

    /// Bugs are drawn big (radius 70 pt at 4×), so they stay crisp at 1024 px.
    static let bugRadius: CGFloat = 70

    @MainActor
    static func load(for id: String) -> BadgeArt {
        var art = BadgeArt(trap: TrapImageCache.image())
        for s in BadgePainter.species(for: id) {
            // R4 (REVIEW-3 #18): the scarab's wings are folded under its own wing cases (drawn by the badge).
            let spread: CGFloat = s == .dragonfly ? 1 : (s == .goldenScarab ? 0 : 0.8)
            art.bugs[s] = TrapArt.bugImage(s, radius: bugRadius, scale: 4, wingSpread: spread)
        }
        art.hero = TrapImageCache.heroImage(bug: false)
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
        case Achievements.nobees.id: return [.bee, .housefly, .gnat]
        case Achievements.daily.id, Achievements.monarch.id, Achievements.score10k.id: return [.housefly]
        case Achievements.scarab.id: return [.goldenScarab]
        case Achievements.dragonfly.id: return [.dragonfly]
        case Achievements.spare50.id: return [.bee]
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
            // R4 (REVIEW-3 #16, #18): the 3/4 trap with a crowd of three sipping on its near lobe (off the midrib).
            let c = CGPoint(x: 256, y: 262)
            hero(&ctx, art, width: 340, center: c)
            heroBugs(&ctx, art, width: 340, center: c, [(.housefly, -0.34, 0.5, 72), (.gnat, 0.34, 0.56, 62),
                                                        (.fruitFly, 0.0, 0.76, 62)])
        case Achievements.bite5.id:
            // R4 (REVIEW-3 #18): no trap here (that is First Feast): five bugs swooping in round the 5.
            swirl(&ctx)
            ringOfBugs(&ctx, art, [.housefly, .bluebottle, .gnat, .ladybird, .fruitFly], radius: 128, width: 92)
            coin(&ctx, "5", at: center)
        case Achievements.chain4.id:
            chain(&ctx)
            coin(&ctx, "×4", at: CGPoint(x: 256, y: 372))
        case Achievements.scarab.id:
            glow(&ctx, at: center, radius: 170, color: SnapTheme.goldLight)
            bugs(&ctx, art, [(.goldenScarab, 0, 0, 250)])
            // R4 (REVIEW-3 #18): a beetle's domed wing cases, not a bee's glassy wings.
            wingCases(&ctx, center: center, width: 250, degrees: -24)
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
            let c = CGPoint(x: 256, y: 316)
            hero(&ctx, art, width: 260, center: c)
            heroBugs(&ctx, art, width: 260, center: c, [(.housefly, 0.3, 0.6, 60)])
            crown(&ctx)
        case Achievements.night.id:
            moon(&ctx)
            glow(&ctx, at: CGPoint(x: 232, y: 300), radius: 110, color: Color(snapHex: 0xF6FF8A))
            bugs(&ctx, art, [(.firefly, -24, 44, 170)])
        case Achievements.daily.id:
            sun(&ctx)
            let c = CGPoint(x: 256, y: 324)
            hero(&ctx, art, width: 250, center: c)
            heroBugs(&ctx, art, width: 250, center: c, [(.housefly, 0.3, 0.6, 58)])
        case Achievements.score10k.id:
            let c = CGPoint(x: 256, y: 176)
            hero(&ctx, art, width: 200, center: c)
            heroBugs(&ctx, art, width: 200, center: c, [(.housefly, 0.3, 0.6, 46)])
            numeral(&ctx, "10K", size: 128, at: CGPoint(x: 256, y: 360))
        case Achievements.nobees.id:
            // R4 (REVIEW-3 #18): unlike Bee Kind (a bee in its halo), the trap feeds on flies while a bee buzzes off
            // free along a dashed trail.
            let c = CGPoint(x: 236, y: 298)
            hero(&ctx, art, width: 290, center: c)
            heroBugs(&ctx, art, width: 290, center: c, [(.housefly, -0.3, 0.52, 60), (.gnat, 0.28, 0.6, 52)])
            beeTrail(&ctx, from: CGPoint(x: 220, y: 214), to: CGPoint(x: 352, y: 132))
            bugs(&ctx, art, [(.bee, 104, -132, 104)])
            coin(&ctx, "30", at: CGPoint(x: 366, y: 388))
        default:
            hero(&ctx, art, width: 340, center: center)
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

    // MARK: The 3/4 trap (R4, REVIEW-3 #16: never a centred vertical slit)

    /// The open trap's tilt for the badges: squashed to 3/4 and turned so the midrib runs on a slant.
    static let heroSquash: CGFloat = 0.62
    static let heroTurn: Double = -16

    /// A point on the tilted trap: (`fx`, `fy`) as fractions of its `width` from its centre, before the tilt (x to the
    /// right, y down). Pure; tested (the bugs sit on the near lobe, off the midrib).
    static func heroPoint(_ fx: CGFloat, _ fy: CGFloat, width: CGFloat, center c: CGPoint) -> CGPoint {
        let x = fx * width
        let y = fy * width * heroSquash
        let a = heroTurn * Double.pi / 180
        let ca = CGFloat(cos(a))
        let sa = CGFloat(sin(a))
        return CGPoint(x: c.x + x * ca - y * sa, y: c.y + x * sa + y * ca)
    }

    /// The trap open and tilted 3/4 on a shadow (the Scene's own 3/4 art when there is one).
    static func hero(_ ctx: inout GraphicsContext, _ art: BadgeArt, width: CGFloat, center c: CGPoint) {
        // The Scene's 3/4 trap brings its own ground shadow and petiole leaf.
        if let threeQuarter = art.hero, threeQuarter.width > 0 {
            image(&ctx, threeQuarter, center: c, width: width)
            return
        }
        let shadow = CGRect(x: c.x - width * 0.46, y: c.y + width * 0.12, width: width * 0.92, height: width * 0.2)
        ctx.fill(Path(ellipseIn: shadow), with: .radialGradient(Gradient(colors: [Color.black.opacity(0.45), .clear]),
                                                                 center: CGPoint(x: shadow.midX, y: shadow.midY),
                                                                 startRadius: 0, endRadius: width * 0.46))
        guard let cg = art.trap, cg.width > 0, cg.height > 0 else {
            trap(&ctx, art, width: width, y: c.y)
            return
        }
        let h = width * CGFloat(cg.height) / CGFloat(cg.width)
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        g.rotate(by: .degrees(heroTurn))
        g.scaleBy(x: 1, y: heroSquash)
        g.draw(Image(decorative: cg, scale: 1), in: CGRect(x: -width / 2, y: -h / 2, width: width, height: h))
    }

    /// Bugs sipping on the 3/4 trap's back face: (species, u, v, w), `u` −1…1 along the hinge and `v` 0…1 up the back
    /// lobe (`SceneHooks.threeQuarterPoint`); on the App's tilted fallback, the near lobe.
    static func heroBugs(_ ctx: inout GraphicsContext, _ art: BadgeArt, width: CGFloat, center c: CGPoint,
                         _ list: [(BugSpecies, CGFloat, CGFloat, CGFloat)]) {
        for (s, u, v, w) in list {
            let p = art.hero != nil
                ? SceneHooks.threeQuarterPoint(u: u, v: v, width: width, center: c)
                : heroPoint(0.16 + u * 0.14, (0.6 - v) * 0.4, width: width, center: c)
            image(&ctx, art.bugs[s], center: p, width: w, degrees: -24)
        }
    }

    /// Mouthful (R4): five bugs in a ring, swooping in toward the centre.
    static func ringOfBugs(_ ctx: inout GraphicsContext, _ art: BadgeArt, _ species: [BugSpecies], radius r: CGFloat,
                           width w: CGFloat) {
        let n = max(species.count, 1)
        for (i, s) in species.enumerated() {
            let a = -Double.pi / 2 + Double(i) / Double(n) * 2 * Double.pi
            let p = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
            // Facing inward (the portraits face +x: turn each toward the centre).
            let facing = (a + Double.pi) * 180 / Double.pi
            image(&ctx, art.bugs[s], center: p, width: w, degrees: facing)
        }
    }

    /// Mouthful's motion: a soft spiral of dashes into the centre.
    static func swirl(_ ctx: inout GraphicsContext) {
        for i in 0..<5 {
            let a0 = -Double.pi / 2 + Double(i) / 5 * 2 * Double.pi
            var p = Path()
            let steps = 14
            for k in 0...steps {
                let f = Double(k) / Double(steps)
                let a = a0 + 0.9 * f
                let r = CGFloat(168 - 100 * f)
                let pt = CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
                if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(Color.white.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [10, 12]))
        }
    }

    /// Bee-Free Diet (R4): the dashed trail of a bee flying off free.
    static func beeTrail(_ ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint) {
        var p = Path()
        p.move(to: a)
        p.addQuadCurve(to: b, control: CGPoint(x: a.x - 30, y: (a.y + b.y) / 2 - 40))
        ctx.stroke(p, with: .color(Color.black.opacity(0.3)),
                   style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [14, 14]))
        ctx.stroke(p, with: .color(Color.white.opacity(0.9)),
                   style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [14, 14]))
    }

    /// Pure Gold (R4, REVIEW-3 #18): the scarab's elytra, two domed gold wing cases meeting down its back, over the
    /// bug drawn at `c`, `width` wide, turned `degrees` (as `bugs` draws it). The bug faces +x and its radius in the
    /// image is `BadgeArt.bugRadius` of `TrapArt.bugExtent`.
    static func wingCases(_ ctx: inout GraphicsContext, center c: CGPoint, width: CGFloat, degrees: Double) {
        let extent = TrapArt.bugExtent(radius: BadgeArt.bugRadius)
        let r = BadgeArt.bugRadius * width / max(2 * extent, 1)
        var g = ctx
        g.translateBy(x: c.x, y: c.y)
        g.rotate(by: .degrees(degrees))
        for side in [CGFloat(-1), 1] {
            var p = Path()
            // From the shoulder (behind the pronotum) back to the tail, the seam slightly parted at the tip.
            p.move(to: CGPoint(x: 0.24 * r, y: side * 0.03 * r))
            p.addCurve(to: CGPoint(x: -0.8 * r, y: side * 0.07 * r),
                       control1: CGPoint(x: 0.2 * r, y: side * 0.7 * r),
                       control2: CGPoint(x: -0.72 * r, y: side * 0.66 * r))
            p.closeSubpath()
            g.fill(p, with: .linearGradient(Gradient(colors: [Color(snapHex: 0xFFF0A8), Color(snapHex: 0xF2B92E),
                                                              Color(snapHex: 0xA8700E)]),
                                            startPoint: CGPoint(x: 0, y: side * 0.1 * r),
                                            endPoint: CGPoint(x: -0.3 * r, y: side * 0.62 * r)))
            g.stroke(p, with: .color(Color(snapHex: 0x1E0A10)), lineWidth: max(r * 0.05, 2))
            // A ridge along each case and a glossy streak.
            var ridge = Path()
            ridge.move(to: CGPoint(x: 0.12 * r, y: side * 0.28 * r))
            ridge.addQuadCurve(to: CGPoint(x: -0.66 * r, y: side * 0.24 * r),
                               control: CGPoint(x: -0.3 * r, y: side * 0.42 * r))
            g.stroke(ridge, with: .color(Color(snapHex: 0x8A5A0A).opacity(0.55)), lineWidth: max(r * 0.03, 1.5))
            let gloss = CGRect(x: -0.42 * r, y: side > 0 ? 0.12 * r : -0.3 * r, width: 0.36 * r, height: 0.16 * r)
            g.fill(Path(ellipseIn: gloss), with: .color(Color.white.opacity(0.45)))
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
