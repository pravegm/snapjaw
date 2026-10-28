import SwiftUI

// MARK: - R8: Levels (ROUND-8 §4): the map, the intro card, the goal line, "Close the phone to start", the results

/// Where a level's goal line sits: the other page's top outer corner, the score's mirror (so it clears the cilia as
/// the score does). Pure; tested.
enum LevelGoalLayout {
    static func rect(_ info: AppCanvas, score: CGRect) -> CGRect {
        let extra: CGFloat = info.isCompact ? 8 : 12
        return CGRect(x: info.size.width - score.maxX, y: score.minY, width: score.width, height: score.height + extra)
    }
}

/// The level's goal in play (R8: one line, big): a flag (a tick once met), the goal, and the level and its clock.
struct LevelGoalBadge: View {
    let level: LevelHUD
    /// It hugs the right edge (the HUD on the left puts it on the right page).
    let trailing: Bool
    let compact: Bool

    /// "LEVEL 3 · 0:42". Pure; tested.
    static func caption(_ level: LevelHUD) -> String {
        var s = LevelWords.levelName(level.id).uppercased()
        if let left = level.secondsLeft { s += " · \(left / 60):" + String(format: "%02d", left % 60) }
        return s
    }

    var body: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            HStack(spacing: 6) {
                if !trailing { icon }
                Text(level.goal)
                    .font(.system(size: compact ? 19 : 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(level.done ? SnapTheme.limeLight : SnapTheme.cream)
                    .multilineTextAlignment(trailing ? .trailing : .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .snapLegible()
                if trailing { icon }
            }
            Text(Self.caption(level))
                .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .rounded).monospacedDigit())
                .kerning(0.8)
                .foregroundStyle((level.secondsLeft ?? 99) <= 10 ? SnapTheme.danger : SnapTheme.mist)
                .lineLimit(1)
                .snapLegible()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LevelWords.levelName(level.id) + ": " + level.goal + (level.done ? ", done" : ""))
    }

    private var icon: some View {
        Image(systemName: level.done ? "checkmark.circle.fill" : "flag.fill")
            .font(.system(size: compact ? 15 : 18, weight: .heavy))
            .foregroundStyle(level.done ? SnapTheme.lime : SnapTheme.gold)
            .snapLegible()
    }
}

/// R8 (founder rule 3: every round starts closed): the big, calm "Close the phone to start", on the HUD page, with a
/// phone closing beside it. A phone (touch) says "Tap to start".
struct CloseToStartCard: View {
    let info: AppCanvas
    var touch = false
    var reduceMotion = false

    static func line(touch: Bool) -> String { LevelWords.startLine(touch: touch) }
    static let detail = "The trap opens when you do."

    var body: some View {
        let page = info.hudPage
        let c = info.isCompact
        ZStack {
            LinearGradient(colors: [SnapTheme.night.opacity(0.0), SnapTheme.night.opacity(0.55)],
                           startPoint: info.hudOnLeft ? .trailing : .leading,
                           endPoint: info.hudOnLeft ? .leading : .trailing)
            VStack(spacing: c ? 10 : 16) {
                if !touch {
                    ClosingPhoneGlyph(reduceMotion: reduceMotion)
                        .frame(width: c ? 70 : 96, height: c ? 70 : 96)
                }
                Text(Self.line(touch: touch))
                    .font(.system(size: c ? 30 : 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(SnapTheme.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .snapLegible()
                if !touch {
                    Text(Self.detail)
                        .font(SnapType.body(c))
                        .foregroundStyle(SnapTheme.mist)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .snapLegible()
                }
            }
            .frame(width: min(page.width, 380))
            .position(x: page.midX, y: info.size.height / 2)
        }
        .frame(width: info.size.width, height: info.size.height)
        .accessibilityElement(children: .combine)
    }
}

/// A phone seen side on, its two halves closing on the hinge (R8: the "close it" cue). Still under Reduce Motion and
/// in demo captures (half shut).
struct ClosingPhoneGlyph: View {
    var reduceMotion = false

    static let loop: Double = 1.8

    /// The half-angle (degrees from upright) at `t`: open wide, closing, shut, opening. Pure; tested.
    static func spread(at t: Double) -> Double {
        let f = (t.isFinite ? t : 0).truncatingRemainder(dividingBy: loop) / loop
        if f < 0.45 { return 70 - 70 * f / 0.45 }
        if f < 0.65 { return 0 }
        return 70 * (f - 0.65) / 0.35
    }

    var body: some View {
        let still = reduceMotion || AppTrace.enabled
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let a = still ? 24 : Self.spread(at: context.date.timeIntervalSinceReferenceDate)
            Canvas { ctx, size in
                let hinge = CGPoint(x: size.width / 2, y: size.height * 0.88)
                let len = size.height * 0.74
                for side in [-1.0, 1.0] {
                    let r = (a * side) * Double.pi / 180
                    let tip = CGPoint(x: hinge.x + CGFloat(sin(r)) * len, y: hinge.y - CGFloat(cos(r)) * len)
                    var p = Path()
                    p.move(to: hinge)
                    p.addLine(to: tip)
                    ctx.stroke(p, with: .color(SnapTheme.night), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    ctx.stroke(p, with: .color(side < 0 ? SnapTheme.limeLight : SnapTheme.pink),
                               style: StrokeStyle(lineWidth: 9, lineCap: .round))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: hinge.x - 7, y: hinge.y - 7, width: 14, height: 14)),
                         with: .color(SnapTheme.cream))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The picture on a level's intro and its map pad: the bugs it is about (Levels 1–5 their lesson), on a lily pad.
enum LevelArt {
    /// Pure; tested (1…3 species for every level).
    static func species(_ id: Int) -> [BugSpecies] {
        switch id {
        case 1, 2: return [.housefly]
        case 3: return [.housefly, .housefly]
        case 4: return [.bee, .housefly]
        case 5: return [.gnat, .housefly, .fruitFly]
        default:
            let pools: [[BugSpecies]] = [[.gnat, .fruitFly, .ant, .ladybird, .bluebottle, .housefly],
                                         [.moth, .grasshopper, .wasp, .dragonfly, .bluebottle, .bumblebee],
                                         [.firefly, .cricket, .mosquito, .goldenScarab, .moth, .wasp]]
            let pool = pools[LevelRules.world(of: id) - 1]
            let n = 1 + id % 3
            return (0..<n).map { pool[(id * 7 + $0 * 3) % pool.count] }
        }
    }
}

/// A level's picture: its bugs on a pad (a bee wears its white "spare me" ring).
struct LevelPicture: View {
    let id: Int
    var size: CGFloat = 150

    var body: some View {
        let bugs = LevelArt.species(id)
        ZStack {
            LilyPadShape().fill(SnapTheme.night.opacity(0.8)).offset(y: 6)
            LilyPadShape().fill(RadialGradient(colors: [SnapTheme.mossLight, SnapTheme.moss, SnapTheme.bog],
                                               center: UnitPoint(x: 0.4, y: 0.35), startRadius: 2,
                                               endRadius: size * 0.6))
            LilyPadShape().stroke(SnapTheme.night, lineWidth: 3)
            PadVeins().stroke(SnapTheme.limeLight.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            ForEach(Array(bugs.enumerated()), id: \.offset) { item in
                let n = CGFloat(bugs.count)
                let i = CGFloat(item.offset)
                let x = (i - (n - 1) / 2) * size * 0.26
                let y = (item.offset % 2 == 0 ? -1 : 1) * size * 0.06
                ZStack {
                    if item.element.isProtected {
                        Circle()
                            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                            .frame(width: size * 0.42, height: size * 0.42)
                    }
                    BugPortrait(species: item.element)
                        .frame(width: size * 0.34, height: size * 0.34)
                }
                .offset(x: x, y: y)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// R8: a level's intro card: the level's number big on the other page, its goal in one line and its picture on the
/// HUD page, and how to start ("Close the phone to start"; a phone: Go, or a tap anywhere).
struct LevelIntroCard: View {
    let intro: LevelIntro
    let info: AppCanvas
    var reduceMotion = false
    let onGo: () -> Void

    var body: some View {
        let c = info.isCompact
        let other = info.otherPage
        let page = info.hudPage
        ZStack {
            SnapTheme.night.opacity(0.55)
                .allowsHitTesting(false)
            VStack(spacing: c ? 4 : 8) {
                SnapOverline(text: LevelWords.worldName(intro.world), compact: c, color: SnapTheme.gold)
                DisplayText(text: LevelWords.levelName(intro.id), size: c ? 56 : 80)
                if !intro.title.isEmpty {
                    Text(intro.title)
                        .font(SnapType.headline(c))
                        .foregroundStyle(SnapTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .snapLegible()
                }
            }
            .frame(width: min(other.width, 420))
            .position(x: other.midX, y: info.size.height * 0.46)
            .entrance(0, reduceMotion: reduceMotion)
            .allowsHitTesting(false)
            VStack(spacing: c ? 10 : 16) {
                LevelPicture(id: intro.id, size: c ? 104 : 150)
                Text(intro.goal)
                    .font(.system(size: c ? 26 : 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(SnapTheme.cream)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                if intro.touch {
                    SnapButton(kind: .primary, height: c ? 58 : 66, compact: c, action: onGo) {
                        Text("Go!")
                    }
                    .frame(width: c ? 180 : 220)
                } else {
                    OpenCue(text: LevelWords.startLine(touch: false), size: c ? 16 : 19)
                }
            }
            .padding(c ? 14 : 22)
            .frame(width: min(page.width, c ? 320 : 380))
            .background(LeafPanel(big: 34, small: 12, accent: SnapTheme.goldLight))
            .position(x: page.midX, y: info.size.height / 2)
            .entrance(1, reduceMotion: reduceMotion)
        }
        .frame(width: info.size.width, height: info.size.height)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - The level map

/// R8: the level map. The other page: the three worlds (the open one picked, a shut one with how many stars open it).
/// The HUD page: the world's ten levels as lily pads on a winding path, each with its stars, the shut ones locked,
/// the next one glowing. A pad plays its level.
struct LevelMapView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas
    @State private var world: Int?

    var body: some View {
        let c = info.isCompact
        let data = store.data
        let next = LevelRules.next(data)
        let shown = world ?? LevelRules.world(of: next ?? 1)
        let back = HUDLayout.make(info).back
        ZStack {
            BogBackdrop(controller: controller, glow: SnapTheme.goldLight)
            worlds(data, shown: shown, c)
                .frame(width: min(info.otherPage.width, 400))
                .position(x: info.otherPage.midX, y: info.size.height / 2)
            pads(data, world: shown, next: next, c)
                .frame(width: info.hudPage.width, height: info.size.height - (back.maxY + 8) - 16)
                .position(x: info.hudPage.midX, y: (back.maxY + 8 + info.size.height - 16) / 2)
            SnapRoundButton(systemImage: "chevron.backward", label: "Back") { controller.show(.home) }
                .position(x: back.midX, y: back.midY)
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    private func worlds(_ d: ProgressData, shown: Int, _ c: Bool) -> some View {
        VStack(alignment: .leading, spacing: c ? 8 : 12) {
            ScreenTitle(title: "Levels", line: "★ \(LevelRules.totalStars(d)) of \(LevelRules.lastID * 3)", compact: c)
                .entrance(0, reduceMotion: controller.reduceMotion)
            ForEach(1...LevelRules.worlds, id: \.self) { w in
                let open = LevelRules.isWorldOpen(d, world: w)
                Button(action: {
                    controller.feedbackTap()
                    world = w
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: open ? Self.worldIcon(w) : "lock.fill")
                            .font(.system(size: c ? 20 : 26, weight: .heavy))
                            .foregroundStyle(open ? Self.worldColor(w) : SnapTheme.haze)
                            .frame(width: c ? 30 : 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LevelWords.worldName(w))
                                .font(.system(size: c ? 18 : 22, weight: .black, design: .rounded))
                                .foregroundStyle(open ? SnapTheme.cream : SnapTheme.haze)
                            Text(open ? LevelWords.worldLine(w) : LevelWords.unlockLine(d, world: w))
                                .font(SnapType.caption(c))
                                .foregroundStyle(SnapTheme.mist)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 4)
                        Text("★ \(LevelRules.worldStars(d, world: w))")
                            .font(.system(size: c ? 14 : 16, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(open ? SnapTheme.gold : SnapTheme.haze)
                    }
                    .padding(.horizontal, c ? 12 : 16)
                    .frame(minHeight: max(SnapTheme.minTap, c ? 58 : 72))
                    .background(LeafPanel(big: 26, small: 9,
                                          accent: w == shown ? SnapTheme.gold : SnapTheme.limeLight))
                    .overlay(LeafShape(big: 26, small: 9)
                        .stroke(SnapTheme.gold.opacity(w == shown ? 0.9 : 0), lineWidth: 2.5))
                }
                .buttonStyle(PressStyle())
                .entrance(w, reduceMotion: controller.reduceMotion)
                .accessibilityLabel(LevelWords.worldName(w) + (open ? "" : ", locked"))
            }
        }
    }

    static func worldIcon(_ w: Int) -> String {
        switch w {
        case 1: return "sun.max.fill"
        case 2: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    static func worldColor(_ w: Int) -> Color {
        switch w {
        case 1: return SnapTheme.gold
        case 2: return Color(snapHex: 0xFFA27A)
        default: return Color(snapHex: 0x9DB8FF)
        }
    }

    /// Where pad `i` (0…9) sits in a box `size`: two rows of five, the path winding back. Pure; tested.
    static func padCenter(_ i: Int, in size: CGSize) -> CGPoint {
        let row = i / 5
        let col = row == 0 ? i % 5 : 4 - i % 5
        let x = size.width * (0.12 + 0.19 * CGFloat(col))
        let y = size.height * (row == 0 ? 0.30 : 0.72) + (col % 2 == 0 ? -1 : 1) * size.height * 0.06
        return CGPoint(x: x, y: y)
    }

    private func pads(_ d: ProgressData, world w: Int, next: Int?, _ c: Bool) -> some View {
        let ids = Array(LevelRules.ids(world: w))
        let pad: CGFloat = c ? 50 : 70
        return GeometryReader { geo in
            ZStack {
                // The path between the pads.
                Path { p in
                    for i in 0..<ids.count {
                        let pt = Self.padCenter(i, in: geo.size)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(SnapTheme.cream.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round,
                                                                       lineJoin: .round, dash: [2, 12]))
                ForEach(Array(ids.enumerated()), id: \.offset) { item in
                    let id = item.element
                    LevelPad(id: id, stars: LevelRules.stars(d, id), open: LevelRules.isOpen(d, id), next: id == next,
                             size: pad, reduceMotion: controller.reduceMotion,
                             action: { controller.playLevel(id) })
                        .position(Self.padCenter(item.offset, in: geo.size))
                        .entrance(item.offset + 1, reduceMotion: controller.reduceMotion)
                }
            }
        }
    }
}

/// One level on the map: a lily pad with its number, its stars under it; locked: dark, a padlock; next: glowing.
struct LevelPad: View {
    let id: Int
    let stars: Int
    let open: Bool
    var next = false
    var size: CGFloat = 70
    var reduceMotion = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if next {
                        Circle()
                            .fill(RadialGradient(colors: [SnapTheme.gold.opacity(0.55), SnapTheme.gold.opacity(0)],
                                                 center: .center, startRadius: size * 0.2, endRadius: size * 0.85))
                            .frame(width: size * 1.7, height: size * 1.7)
                    }
                    LilyPadShape().fill(SnapTheme.night.opacity(0.85)).offset(y: 4)
                    LilyPadShape().fill(open ? AnyShapeStyle(RadialGradient(
                        colors: [next ? SnapTheme.limeLight : SnapTheme.mossLight, SnapTheme.moss, SnapTheme.bog],
                        center: UnitPoint(x: 0.4, y: 0.35), startRadius: 2, endRadius: size * 0.6))
                        : AnyShapeStyle(Color(snapHex: 0x1A2A1F)))
                    LilyPadShape().stroke(next ? SnapTheme.gold : SnapTheme.night, lineWidth: next ? 3.5 : 3)
                    if open {
                        DisplayText(text: "\(id)", size: size * 0.44, fill: [SnapTheme.cream, SnapTheme.goldLight])
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: size * 0.32, weight: .heavy))
                            .foregroundStyle(SnapTheme.haze)
                    }
                }
                .frame(width: size, height: size)
                StarRow(earned: stars, size: size * 0.24, spacing: 1)
                    .opacity(open ? 1 : 0.35)
            }
            .frame(minWidth: max(size, SnapTheme.minTap), minHeight: max(size, SnapTheme.minTap))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(!open)
        .accessibilityLabel(LevelWords.levelName(id) + (open ? ", \(stars) stars" : ", locked"))
    }
}

// MARK: - The level results

/// R8: a level's Results. The other page: the level, its stars landing one by one, Core's line. The HUD page: what
/// next: Next (passed) or Retry (not yet), and the map.
struct LevelResultsView: View {
    @ObservedObject var controller: GameController
    let summary: ResultSummary
    let level: LevelResult
    let info: AppCanvas
    @State private var landed = 0
    @State private var task: Task<Void, Never>?

    /// The beat between stars (s).
    static let starBeat: Double = 0.38

    static func headline(_ l: LevelResult) -> String {
        guard l.passed else { return "Not yet!" }
        switch l.stars {
        case 3: return "Perfect!"
        case 2: return "Great!"
        default: return "Done!"
        }
    }

    var body: some View {
        let c = info.isCompact
        let other = info.otherPage
        let page = info.hudPage
        let instant = controller.reduceMotion || AppTrace.enabled
        ZStack {
            BogBackdrop(controller: controller, glow: level.passed ? SnapTheme.gold : SnapTheme.goldLight)
            VStack(spacing: c ? 6 : 12) {
                SnapOverline(text: LevelWords.worldName(level.world) + " · " + LevelWords.levelName(level.id),
                             compact: c, color: SnapTheme.gold)
                DisplayText(text: Self.headline(level), size: c ? 52 : 76,
                            fill: level.passed ? [SnapTheme.goldLight, SnapTheme.gold] : [SnapTheme.cream, SnapTheme.mist],
                            tilt: -3)
                HStack(spacing: c ? 10 : 18) {
                    ForEach(0..<3, id: \.self) { i in
                        let lit = i < level.stars && (instant || i < landed)
                        StarGlyph(lit: lit, size: (c ? 54 : 78) * (i == 1 ? 1.2 : 1))
                            .scaleEffect(lit || instant ? 1 : 0.85)
                            .rotationEffect(.degrees(Double(i - 1) * 12))
                            .offset(y: i == 1 ? -10 : 0)
                    }
                }
                .padding(.vertical, c ? 4 : 8)
                if !level.line.isEmpty {
                    Text(level.line)
                        .font(SnapType.headline(c))
                        .foregroundStyle(SnapTheme.cream)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .snapLegible()
                }
                Text(level.goal)
                    .font(SnapType.body(c))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .snapLegible()
            }
            .frame(width: min(other.width, 440))
            .position(x: other.midX, y: info.size.height / 2)
            VStack(spacing: c ? 10 : 14) {
                if let w = level.worldOpened {
                    HStack(spacing: 8) {
                        Image(systemName: LevelMapView.worldIcon(w))
                            .foregroundStyle(LevelMapView.worldColor(w))
                        Text(LevelWords.worldName(w) + " is open!")
                            .font(SnapType.headline(c))
                            .foregroundStyle(SnapTheme.cream)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(LeafPanel(big: 22, small: 8, accent: SnapTheme.gold))
                    .entrance(0, reduceMotion: controller.reduceMotion)
                }
                HStack(spacing: c ? 16 : 24) {
                    stat(AppRules.formatted(max(summary.result.score, 0)), AppRules.scoreWord, c)
                    stat("\(summary.result.bugsCaught)", "bugs", c)
                    stat("\(summary.result.beesSpared)", "spared", c)
                }
                .entrance(1, reduceMotion: controller.reduceMotion)
                if level.passed && level.next != nil {
                    SnapButton(kind: .primary, height: c ? 62 : 76, compact: c, action: { controller.playNextLevel() }) {
                        Label("Next level", systemImage: "arrow.right")
                    }
                    .entrance(2, reduceMotion: controller.reduceMotion)
                    SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                               action: { controller.again() }) {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                    }
                    .entrance(3, reduceMotion: controller.reduceMotion)
                } else {
                    SnapButton(kind: .primary, height: c ? 62 : 76, compact: c, action: { controller.again() }) {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                    }
                    .entrance(2, reduceMotion: controller.reduceMotion)
                }
                HStack(spacing: c ? 8 : 12) {
                    SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                               action: { controller.show(.levels) }) {
                        Label("Levels", systemImage: "map.fill")
                    }
                    SnapButton(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c,
                               action: { controller.goHome() }) {
                        Label("Home", systemImage: "house.fill")
                    }
                }
                .entrance(4, reduceMotion: controller.reduceMotion)
            }
            .frame(width: min(page.width, 360))
            .position(x: page.midX, y: info.size.height / 2)
        }
        .frame(width: info.size.width, height: info.size.height)
        .onAppear { landStars(instant: instant) }
        .onDisappear { task?.cancel() }
    }

    private func stat(_ value: String, _ title: String, _ c: Bool) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: c ? 22 : 28, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(SnapTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .snapLegible()
            Text(title)
                .font(.system(size: c ? 11 : 12, weight: .heavy, design: .rounded))
                .foregroundStyle(SnapTheme.mist)
                .snapLegible()
        }
        .accessibilityElement(children: .combine)
    }

    /// The stars land one by one, each with its chime.
    private func landStars(instant: Bool) {
        task?.cancel()
        guard !instant else {
            landed = level.stars
            return
        }
        landed = 0
        let n = level.stars
        task = Task { @MainActor in
            for i in 0..<n {
                try? await Task.sleep(nanoseconds: UInt64((i == 0 ? 0.45 : Self.starBeat) * 1_000_000_000))
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) { landed = i + 1 }
                controller.starLanded(i)
            }
        }
    }
}
