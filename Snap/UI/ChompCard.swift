import SwiftUI

// MARK: - R8: the outer display's CHOMP card (ROUND-8 §1: "closed phone = closed trap")
//
// When the Duo shuts, iOS moves the app to the outer display (466 × 678). The trap is shut too, so the outer display
// shows it from outside: the closed trap, a bump in its lobe for every bug it caught, and the bite in plain words.
// - a catch: "CHOMP!", "4 bugs · +360", "Fast close", "Open to keep feeding";
// - a sting: "Bzzt!", the bee buzzing off cross, "Bee! −1 snap";
// - a dry bite: "Empty!", the trap flat, "Too slow, they flew" (or "Empty bite").
// The heavy haptic and the CHOMP itself fire at the shut, on Core's `snapped` (FeedbackDirector); this card only
// shows what happened.

/// The CHOMP card's words. Pure; tested.
enum ChompWords {
    static let carryOn = "Open to keep feeding"
    static let openToPlay = "Open to play"
    static let openForResults = "Open to see how you did"

    static func headline(_ k: ChompInfo.Kind) -> String {
        switch k {
        case .catchBite: return "CHOMP!"
        case .sting: return "Bzzt!"
        case .dry: return "Empty!"
        }
    }

    /// "4 bugs · +360", "1 bug · +12"; a sting names its cost; a dry bite says so.
    static func callout(_ c: ChompInfo) -> String {
        switch c.kind {
        case .catchBite:
            let n = c.caught.count
            return "\(n) \(n == 1 ? "bug" : "bugs") · +" + AppRules.formatted(max(c.points, 0))
        case .sting:
            let who = c.stingers.contains(.wasp) ? "A wasp" : "A bee"
            return c.snapsLost > 0 ? who + " · " + AppRules.snapLossText(c.snapsLost) : who + " in the bite"
        case .dry:
            return c.escaped > 0 ? "They all flew" : "Nothing in it"
        }
    }

    /// The bite's verdict without the count the callout already says ("Fast close", "2 got away"). R9 (frames 57, 58:
    /// "A bee · −1 snap" over "Bee! −1 snap", "They all flew" over "Too slow, they flew"): a sting or a dry bite says
    /// what to do next instead of saying the callout twice. The outer display is the Duo's, so it speaks of closing.
    static func note(_ c: ChompInfo) -> String {
        switch c.kind {
        case .catchBite:
            guard let r = c.verdict.range(of: "! ") else { return c.verdict }
            return String(c.verdict[r.upperBound...])
        case .sting:
            return c.stingers.contains(.wasp) ? stingTipWasp : stingTip
        case .dry:
            return c.escaped > 0 ? slowTip : emptyTip
        }
    }

    static let stingTip = "Wait for bees to leave"
    static let stingTipWasp = "Wait for wasps to leave"
    static let slowTip = "Close faster: flies flee"
    static let emptyTip = "Wait for bugs to land"
}

/// The closed trap seen from outside (R8), drawn in one `Canvas` in a 300 × 210 design box: the two lobes pressed
/// together, their cilia locked like fingers across the seam, a bump in the top lobe for each bug inside, the stalk.
/// A sting lifts the margin a crack (the bee got out); a dry bite lies flat and pale.
struct ChompArt: View {
    let caught: [BugSpecies]
    var kind: ChompInfo.Kind = .catchBite
    /// How many bumps have swelled so far (they pop in one by one).
    var bumpsShown: Int = .max
    /// 0…1 the lobes' squeeze on landing (1: at rest).
    var settle: Double = 1
    /// The trap shut at rest (the cover off a run): no glow, no impact strokes.
    var resting = false

    static let box = CGSize(width: 300, height: 210)
    static let maxBumps = 8
    /// Where the bumps swell on the top lobe (design space), biggest first.
    static let bumpSpots: [CGPoint] = [CGPoint(x: 150, y: 70), CGPoint(x: 110, y: 82), CGPoint(x: 192, y: 62),
                                       CGPoint(x: 132, y: 54), CGPoint(x: 214, y: 80), CGPoint(x: 90, y: 98),
                                       CGPoint(x: 172, y: 46), CGPoint(x: 236, y: 92)]

    static let leafTop = Color(snapHex: 0x8ACB55)
    static let leaf = Color(snapHex: 0x4C9A3C)
    static let leafDeep = Color(snapHex: 0x1F5526)
    static let blush = Color(snapHex: 0xC42A45)
    static let blushDeep = Color(snapHex: 0x8A1232)
    static let cilium = Color(snapHex: 0xF2F9CC)
    static let ink = Color(snapHex: 0x061009)

    var body: some View {
        let silhouettes = caught.prefix(Self.maxBumps).map { BugArtCache.image($0, found: false, flying: false) }
        let k = kind
        let shown = min(max(bumpsShown, 0), min(caught.count, Self.maxBumps))
        let squeeze = min(max(settle.isFinite ? settle : 1, 0), 1)
        let still = resting
        Canvas { ctx, size in
            Self.draw(&ctx, size: size, kind: k, bumps: shown, silhouettes: silhouettes, settle: squeeze,
                      resting: still)
        }
        .accessibilityHidden(true)
    }

    /// The seam's two ends and its sag (design space): the margins meet along it.
    static let seamL = CGPoint(x: 50, y: 116)
    static let seamR = CGPoint(x: 264, y: 100)

    static func upperLobe(lift: CGFloat) -> Path {
        var p = Path()
        p.move(to: seamL)
        p.addCurve(to: seamR, control1: CGPoint(x: 66, y: 36 - lift), control2: CGPoint(x: 236, y: 18 - lift))
        p.addQuadCurve(to: seamL, control: CGPoint(x: 157, y: 116 - lift))
        p.closeSubpath()
        return p
    }

    static func lowerLobe() -> Path {
        var p = Path()
        p.move(to: seamL)
        p.addQuadCurve(to: seamR, control: CGPoint(x: 157, y: 112))
        p.addCurve(to: seamL, control1: CGPoint(x: 238, y: 172), control2: CGPoint(x: 78, y: 184))
        p.closeSubpath()
        return p
    }

    /// A point on the seam at `u` 0…1 (left to right).
    static func seamPoint(_ u: CGFloat) -> CGPoint {
        let c = CGPoint(x: 157, y: 114)
        let t = min(max(u, 0), 1)
        let a = (1 - t) * (1 - t)
        let b = 2 * (1 - t) * t
        let d = t * t
        return CGPoint(x: a * seamL.x + b * c.x + d * seamR.x, y: a * seamL.y + b * c.y + d * seamR.y)
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, kind: ChompInfo.Kind, bumps: Int,
                     silhouettes: [CGImage?], settle: Double, resting: Bool = false) {
        var ctx = context
        let k = max(min(size.width / box.width, size.height / box.height), 0.01)
        ctx.translateBy(x: (size.width - box.width * k) / 2, y: (size.height - box.height * k) / 2)
        ctx.scaleBy(x: k, y: k)
        // The landing squeeze: the lobes flatten a touch and spring back.
        let squash = CGFloat(0.12 * (1 - settle))
        ctx.translateBy(x: 0, y: 112 * squash)
        ctx.scaleBy(x: 1 + squash * 0.4, y: 1 - squash)
        let dry = kind == .dry
        let lift: CGFloat = kind == .sting ? 7 : 0
        // The bog under it: a soft shadow, a glow of nectar for a good bite.
        if kind == .catchBite && !resting {
            ctx.fill(Path(ellipseIn: CGRect(x: 40, y: 20, width: 240, height: 170)),
                     with: .radialGradient(Gradient(colors: [SnapTheme.gold.opacity(0.32), SnapTheme.gold.opacity(0)]),
                                           center: CGPoint(x: 160, y: 104), startRadius: 4, endRadius: 140))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: 44, y: 172, width: 232, height: 28)), with: .color(Color.black.opacity(0.45)))
        // The stalk: a winged petiole from the lower left.
        var stalk = Path()
        stalk.move(to: CGPoint(x: 18, y: 196))
        stalk.addQuadCurve(to: CGPoint(x: 70, y: 132), control: CGPoint(x: 30, y: 150))
        stalk.addQuadCurve(to: CGPoint(x: 92, y: 150), control: CGPoint(x: 88, y: 136))
        stalk.addQuadCurve(to: CGPoint(x: 34, y: 200), control: CGPoint(x: 52, y: 166))
        stalk.closeSubpath()
        ctx.fill(stalk, with: .linearGradient(Gradient(colors: [leaf, leafDeep]), startPoint: CGPoint(x: 70, y: 132),
                                              endPoint: CGPoint(x: 24, y: 198)))
        ctx.stroke(stalk, with: .color(ink), style: StrokeStyle(lineWidth: 3.5, lineJoin: .round))
        // The lower lobe (the far one), then the upper (the near one, the bumps in it).
        let lower = lowerLobe()
        let upper = upperLobe(lift: lift)
        let fade = dry ? 0.55 : 1.0
        ctx.fill(lower, with: .linearGradient(Gradient(stops: [
            .init(color: blushDeep.opacity(fade), location: 0),
            .init(color: leaf.opacity(fade), location: 0.25),
            .init(color: leafDeep, location: 1)]),
            startPoint: CGPoint(x: 157, y: 112), endPoint: CGPoint(x: 157, y: 182)))
        ctx.stroke(lower, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
        if lift > 0 {
            // A sting: the margin lifted a crack, the dark inside showing.
            var crack = Path()
            crack.move(to: seamL)
            crack.addQuadCurve(to: seamR, control: CGPoint(x: 157, y: 116 - lift))
            crack.addQuadCurve(to: seamL, control: CGPoint(x: 157, y: 112))
            ctx.fill(crack, with: .color(Color(snapHex: 0x1C0309)))
        }
        ctx.fill(upper, with: .linearGradient(Gradient(stops: [
            .init(color: (dry ? leaf : leafTop), location: 0),
            .init(color: leaf, location: 0.55),
            .init(color: blush.opacity(0.85 * fade), location: 0.88),
            .init(color: blushDeep, location: 1)]),
            startPoint: CGPoint(x: 157, y: 24 - lift), endPoint: CGPoint(x: 157, y: 116 - lift)))
        // The veins of the top lobe, from the midrib out.
        var veins = Path()
        for i in 0..<7 {
            let u = 0.16 + CGFloat(i) * 0.12
            let foot = seamPoint(u)
            veins.move(to: CGPoint(x: foot.x, y: foot.y - 6 - lift))
            veins.addQuadCurve(to: CGPoint(x: 60 + u * 190, y: 44 + abs(u - 0.5) * 70 - lift),
                               control: CGPoint(x: foot.x + (u - 0.5) * 30, y: foot.y - 40 - lift))
        }
        ctx.stroke(veins, with: .color(leafDeep.opacity(0.35)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        // The bumps: each caught bug pushes the lobe out (a lit swelling, a shadow under it, its shape through the
        // leaf).
        let n = min(bumps, maxBumps)
        let r: CGFloat = n > 4 ? 13 : 16
        for i in 0..<n {
            let c = bumpSpots[i]
            let bump = CGRect(x: c.x - r, y: c.y - r * 0.8 - lift, width: r * 2, height: r * 1.6)
            var under = Path()
            under.addArc(center: CGPoint(x: c.x, y: c.y - lift), radius: r, startAngle: .degrees(20),
                         endAngle: .degrees(160), clockwise: false)
            ctx.stroke(under, with: .color(leafDeep.opacity(0.75)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            ctx.fill(Path(ellipseIn: bump), with: .radialGradient(
                Gradient(colors: [Color(snapHex: 0xC8EE8A), Color(snapHex: 0x86C653).opacity(0.85),
                                  Color(snapHex: 0x86C653).opacity(0)]),
                center: CGPoint(x: c.x - r * 0.25, y: c.y - r * 0.35 - lift), startRadius: 1, endRadius: r * 1.05))
            if i < silhouettes.count, let img = silhouettes[i], img.width > 0, img.height > 0 {
                var ghost = ctx
                ghost.opacity = 0.22
                let w = r * 1.5
                let h = w * CGFloat(img.height) / CGFloat(img.width)
                ghost.draw(Image(decorative: img, scale: 1),
                           in: CGRect(x: c.x - w / 2, y: c.y - h / 2 - lift, width: w, height: h))
            }
        }
        ctx.stroke(upper, with: .color(ink), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
        // The wet gloss on the top lobe.
        var gloss = Path()
        gloss.move(to: CGPoint(x: 92, y: 60 - lift))
        gloss.addQuadCurve(to: CGPoint(x: 150, y: 34 - lift), control: CGPoint(x: 108, y: 38 - lift))
        ctx.stroke(gloss, with: .color(Color.white.opacity(dry ? 0.18 : 0.42)),
                   style: StrokeStyle(lineWidth: 5, lineCap: .round))
        // The seam, and the cilia locked across it like fingers (from the top lobe down, from the bottom one up).
        var seam = Path()
        seam.move(to: CGPoint(x: seamL.x, y: seamL.y - lift / 2))
        seam.addQuadCurve(to: CGPoint(x: seamR.x, y: seamR.y - lift / 2), control: CGPoint(x: 157, y: 114 - lift / 2))
        ctx.stroke(seam, with: .color(blushDeep), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        var cilia = Path()
        let teeth = 16
        for i in 0..<teeth {
            let u = 0.06 + CGFloat(i) / CGFloat(teeth - 1) * 0.88
            let p = seamPoint(u)
            let down = i % 2 == 0
            let len: CGFloat = 15 + 5 * sin(u * .pi)
            let lean = (u - 0.5) * 10
            if down {
                cilia.move(to: CGPoint(x: p.x - lean * 0.3, y: p.y - 6 - lift))
                cilia.addLine(to: CGPoint(x: p.x + lean, y: p.y - 6 - lift + len + (lift > 0 ? 2 : 0)))
            } else {
                cilia.move(to: CGPoint(x: p.x + lean * 0.3, y: p.y + 6))
                cilia.addLine(to: CGPoint(x: p.x - lean, y: p.y + 6 - len))
            }
        }
        ctx.stroke(cilia, with: .color(ink), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
        ctx.stroke(cilia, with: .color(dry ? cilium.opacity(0.7) : cilium), style: StrokeStyle(lineWidth: 2.2,
                                                                                            lineCap: .round))
        // A catch: the impact strokes at both ends of the seam.
        if kind == .catchBite && !resting {
            var hits = Path()
            for (end, dir) in [(seamL, CGFloat(-1)), (seamR, CGFloat(1))] {
                for j in 0..<3 {
                    let a = CGFloat(j - 1) * 0.5
                    let x0 = end.x + dir * 12
                    let y0 = end.y + a * 18
                    hits.move(to: CGPoint(x: x0, y: y0))
                    hits.addLine(to: CGPoint(x: x0 + dir * 16, y: y0 + a * 10))
                }
            }
            ctx.stroke(hits, with: .color(ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            ctx.stroke(hits, with: .color(SnapTheme.goldLight), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }
}

/// The CHOMP card (R8): the outer display while the Duo is shut mid-run. The closed trap (bumps swelling in one by
/// one), the headline, the bite, the verdict, and what to do: open.
struct ChompCard: View {
    let chomp: ChompInfo
    var levelGoal: String?
    var insets: EdgeInsets = EdgeInsets()
    var reduceMotion = false
    var variety: TrapVariety = .classic

    @State private var bumps = 0
    @State private var settle: Double = 0
    @State private var popped = false
    @State private var task: Task<Void, Never>?

    private var instant: Bool { reduceMotion || AppTrace.enabled }

    var body: some View {
        GeometryReader { geo in
            let l = CoverLayout.make(size: geo.size, insets: insets, midRun: true, hasBest: false)
            ZStack {
                CoverBackdrop(kind: chomp.kind, size: geo.size)
                if l.sideBySide {
                    HStack(spacing: CoverLayout.gap) {
                        art(l)
                        words(l)
                    }
                    .position(x: l.area.midX, y: l.area.midY)
                } else {
                    VStack(spacing: l.spacing) {
                        art(l)
                        words(l)
                    }
                    .position(x: l.area.midX, y: l.area.midY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ChompWords.headline(chomp.kind) + " " + ChompWords.callout(chomp) + ". "
                            + ChompWords.note(chomp) + ". " + ChompWords.carryOn)
        .onAppear { run() }
        .onChange(of: chomp) { _, _ in run() }
        .onDisappear { task?.cancel() }
    }

    private func art(_ l: CoverLayout) -> some View {
        ZStack(alignment: .topTrailing) {
            ChompArt(caught: chomp.caught, kind: chomp.kind, bumpsShown: bumps, settle: settle)
                .frame(width: l.trap.width, height: l.trap.height)
            if chomp.kind == .sting, let s = chomp.stingers.first {
                // The bee got out: off it goes, cross.
                BugPortrait(species: s, flying: true)
                    .frame(width: l.trap.width * 0.26, height: l.trap.width * 0.26)
                    .rotationEffect(.degrees(18))
                    .offset(x: popped ? l.trap.width * 0.02 : -l.trap.width * 0.3,
                            y: popped ? -l.trap.height * 0.08 : l.trap.height * 0.3)
                    .opacity(popped ? 1 : 0)
            }
        }
        .frame(width: l.trap.width, height: l.trap.height)
    }

    private func words(_ l: CoverLayout) -> some View {
        let fill: [Color]
        switch chomp.kind {
        case .catchBite: fill = [SnapTheme.goldLight, SnapTheme.gold]
        case .sting: fill = [Color(snapHex: 0xFFF1A8), SnapTheme.bee]
        case .dry: fill = [SnapTheme.mist, SnapTheme.haze]
        }
        return VStack(spacing: l.spacing * 0.6) {
            DisplayText(text: ChompWords.headline(chomp.kind), size: l.titleSize * CoverLayout.headlineScale,
                        fill: fill, lip: chomp.kind == .dry ? SnapTheme.bog : SnapTheme.crimsonDeep, tilt: -5)
                .scaleEffect(popped ? 1 : 0.6)
                .opacity(popped ? 1 : 0)
            Text(ChompWords.callout(chomp))
                .font(CoverLayout.swiftFont(l.bodySize + 6, .heavy).monospacedDigit())
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(ChompWords.note(chomp))
                .font(CoverLayout.swiftFont(l.bodySize, .bold))
                .foregroundStyle(chomp.kind == .catchBite ? SnapTheme.limeLight : SnapTheme.pink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let levelGoal {
                Text(levelGoal)
                    .font(CoverLayout.swiftFont(l.bodySize - 2, .semibold))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            OpenCue(text: ChompWords.carryOn, size: l.bodySize)
                .padding(.top, l.spacing * 0.4)
            Text(AppRules.scoreWord.capitalized + " " + AppRules.formatted(max(chomp.score, 0)))
                .font(CoverLayout.swiftFont(l.bodySize - 3, .bold).monospacedDigit())
                .foregroundStyle(SnapTheme.haze)
                .lineLimit(1)
        }
        .frame(width: l.textWidth)
    }

    private func run() {
        task?.cancel()
        let n = min(chomp.caught.count, ChompArt.maxBumps)
        guard !instant else {
            bumps = n
            settle = 1
            popped = true
            return
        }
        bumps = 0
        settle = 0
        popped = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
            settle = 1
            popped = true
        }
        task = Task { @MainActor in
            for i in 0..<n {
                try? await Task.sleep(nanoseconds: 110_000_000)
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bumps = i + 1 }
            }
        }
    }
}

/// "Open to keep feeding" with the opening arrows.
struct OpenCue: View {
    let text: String
    var size: CGFloat = 18
    /// R9: nil for a cue that isn't an opening (the intro's "Close the phone to start" has its closing phone beside it).
    var icon: String? = "arrow.left.and.right"

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: size * 0.9, weight: .heavy))
                    .foregroundStyle(SnapTheme.limeLight)
            }
            Text(text)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(SnapTheme.surface.opacity(0.9)))
        .overlay(Capsule().stroke(SnapTheme.lime.opacity(0.45), lineWidth: 1.5))
    }
}

/// The outer display's backdrop: the bog at night-black, lit from under the trap (gold for a catch, crimson for a
/// sting, cold for a dry bite).
struct CoverBackdrop: View {
    var kind: ChompInfo.Kind?
    let size: CGSize

    var body: some View {
        let glow: Color
        switch kind {
        case .catchBite?: glow = SnapTheme.mossLight
        case .sting?: glow = SnapTheme.crimsonDeep
        case .dry?: glow = SnapTheme.bog
        case nil: glow = SnapTheme.moss
        }
        return ZStack {
            Color.black
            RadialGradient(colors: [glow.opacity(0.75), SnapTheme.night, Color.black], center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 10, endRadius: max(size.width, size.height) * 0.62)
            DewField().opacity(0.6)
        }
        .ignoresSafeArea()
    }
}
