import SwiftUI

/// Home: the live bog behind the menu (an attract session drawn by the real scene, REVIEW-1 #12: snap the Duo a
/// little shut and it chomps whatever has landed, with `FeedbackDirector.homeTrap`; a tap on other iPhones), the title
/// on the other page, and the four buttons on the HUD page (the right, sharp half by default): Feed, Daily Bog, Bug
/// Book, Settings. Shows the plant rank (and what grows it), the best and the Daily's status.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    /// The caption under Home's clap diagram.
    /// R7 (ci-R7.md #9, D06): the captions' and the pose card's words.
    static let foldCaption = "Snap it a little shut"
    static let foldDetail = "The two halves are the trap. Bite, then open."
    /// R4 (REVIEW-3 #8): the clap diagram's height on Home (it was ~65 pt, on the cilia).
    static let foldDiagramHeight: CGFloat = 120

    var body: some View {
        let c = info.isCompact
        let page = info.hudPage
        let other = info.otherPage
        let buttonsW = min(page.width, c ? 300 : 340)
        // The shade under the buttons runs from the fold to the screen's own edge (no seam at the safe area).
        let shadeX0 = info.hudOnLeft ? 0 : info.foldMaxX
        let shadeX1 = info.hudOnLeft ? info.foldMinX : info.size.width
        let otherX0 = info.hudOnLeft ? info.foldMaxX : 0
        let otherX1 = info.hudOnLeft ? info.size.width : info.foldMinX
        ZStack {
            if controller.scene == nil { SnapBackdrop() }
            HomeTrapLayer(trap: controller.homeTrap, info: info, reduceMotion: controller.reduceMotion,
                          onTap: { controller.homeTrapTapped() })
            LinearGradient(colors: [SnapTheme.night.opacity(0.05), SnapTheme.night.opacity(0.66)],
                           startPoint: info.hudOnLeft ? .trailing : .leading,
                           endPoint: info.hudOnLeft ? .leading : .trailing)
                .frame(width: max(shadeX1 - shadeX0, 0), height: info.size.height)
                .position(x: (shadeX0 + shadeX1) / 2, y: info.size.height / 2)
                .allowsHitTesting(false)
            // A soft shade behind the title so it reads over the lobe (never a slab over the trap).
            RadialGradient(colors: [SnapTheme.night.opacity(0.62), SnapTheme.night.opacity(0)], center: .center,
                           startRadius: 10, endRadius: max(otherX1 - otherX0, 1) * 0.62)
                .frame(width: max(otherX1 - otherX0, 0), height: info.size.height)
                .position(x: (otherX0 + otherX1) / 2, y: info.size.height * 0.42)
                .allowsHitTesting(false)
            titleBlock(c)
                .frame(width: min(other.width, 400))
                .position(x: other.midX, y: info.size.height * (c ? 0.44 : 0.42))
                .allowsHitTesting(false)
            buttons(c)
                .frame(width: buttonsW)
                .position(x: page.midX, y: info.size.height / 2 + (c ? 4 : 10))
        }
        .frame(width: info.size.width, height: info.size.height)
        // R7 (Scene/Core #4, frames 01, 52, D06: bugs peeked out from behind the buttons): the buttons' real frames,
        // in scene space, are the Home bog's clear zone.
        .coordinateSpace(.named(Self.space))
        .onPreferenceChange(HomeButtonFramesKey.self) { frames in
            controller.setHomeButtonFrames(Self.sceneRects(frames, info: info))
        }
    }

    /// R7 (#4): the coordinate space the button frames are measured in (the canvas, top-left origin).
    static let space = "snap.home"

    /// R7 (#4): screen rects (the canvas) to scene rects (y up), rounded out to 2 pt so a sub-point wobble never
    /// re-sends them. Pure; tested.
    static func sceneRects(_ rects: [CGRect], info: AppCanvas) -> [CGRect] {
        rects.compactMap { r -> CGRect? in
            guard r.minX.isFinite, r.minY.isFinite, r.width.isFinite, r.height.isFinite, r.width > 0,
                  r.height > 0 else { return nil }
            let a = info.scenePoint(CGPoint(x: r.minX, y: r.minY))
            let b = info.scenePoint(CGPoint(x: r.maxX, y: r.maxY))
            let x0 = (min(a.x, b.x) / 2).rounded(.down) * 2
            let y0 = (min(a.y, b.y) / 2).rounded(.down) * 2
            let x1 = (max(a.x, b.x) / 2).rounded(.up) * 2
            let y1 = (max(a.y, b.y) / 2).rounded(.up) * 2
            return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        }
    }

    // MARK: Title

    /// R5 (REVIEW-4 #12, 03: "Snap it shut a little" was on the subtitle and the clap card): on a Duo the subtitle
    /// gives the rule and the clap card the move.
    static let foldSubtitle = "Wait for a crowd, then bite."
    static let touchSubtitle = "Tap the trap. It bites!"

    static func subtitle(foldInput: Bool) -> String { foldInput ? foldSubtitle : touchSubtitle }

    private func titleBlock(_ c: Bool) -> some View {
        let rank = store.rank
        let progress = ProgressRules.rankProgress(lifetime: store.data.growth, rank: rank)
        return VStack(spacing: c ? 4 : 8) {
            Text(AppBrand.name)
                .font(SnapType.wordmark(c))
                .foregroundStyle(LinearGradient(colors: [SnapTheme.cream, SnapTheme.limeLight], startPoint: .top,
                                                endPoint: .bottom))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: SnapTheme.crimsonDeep, radius: 0, x: 0, y: 4)
                .snapLegible()
            // R5 (REVIEW-4 #12, 01–02: the attract fly sat on "bees."): the tagline and the subtitle sit on the rank's
            // card, so a bug of the live bog passes under them, never across the words.
            VStack(alignment: .leading, spacing: 6) {
                VStack(spacing: 2) {
                    Text(AppBrand.tagline)
                        .font(SnapType.headline(c))
                        .foregroundStyle(SnapTheme.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(Self.subtitle(foldInput: controller.showsFoldInput(info)))
                        .font(SnapType.caption(c))
                        .foregroundStyle(SnapTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                Rectangle().fill(SnapTheme.stroke).frame(height: 1)
                    .padding(.vertical, c ? 1 : 3)
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(SnapTheme.lime)
                    Text(PlantRanks.title(rank))
                        .font(SnapType.body(c))
                        .foregroundStyle(SnapTheme.cream)
                    Spacer(minLength: 6)
                    if store.data.bestFeed > 0 {
                        Text("Best " + AppRules.formatted(store.data.bestFeed))
                            .font(SnapType.body(c).monospacedDigit())
                            .foregroundStyle(SnapTheme.gold)
                    }
                }
                SnapProgressBar(value: progress, height: 8)
                Text(AppRules.rankHint(lifetimeBugs: store.data.growth))
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: 320)
            .snapCard(padding: c ? 10 : 14, radius: 18)
            .padding(.top, c ? 2 : 6)
            .accessibilityElement(children: .combine)
            // R6: the three goals (the best of any run so far), under the rank they grow.
            // R7 (#15): each goal wears its tier (a dot and its word).
            GoalsCard(lines: ProgressRules.goalLines(store.goalBook), compact: c, tierLabels: true)
                .frame(maxWidth: 320)
        }
    }

    /// R6 Daily: the streak beside the Daily's status ("🔥 3"), from a streak of two days.
    static func streakBadge(_ n: Int) -> String? { n >= 2 ? "🔥 \(n)" : nil }

    /// R6 Garden: "3/8" grown.
    static func gardenCount(_ data: ProgressData) -> String {
        "\(data.unlockedVarieties.count)/\(TrapVariety.allCases.count)"
    }

    /// R6 Garden: a grown variety not seen there yet.
    static func gardenHasNew(_ data: ProgressData) -> Bool {
        data.unlockedVarieties.contains { !data.varietiesSeen.contains($0.rawValue) }
    }

    // MARK: Buttons

    private func buttons(_ c: Bool) -> some View {
        let today = controller.today
        let found = store.data.speciesFound
        return VStack(spacing: c ? 8 : 14) {
            // ROUND-3 founder call, R4 (REVIEW-3 #8): on a Duo the fold is the input, so Home shows it big (≥ 120 pt),
            // looping, on its own card above Feed (off the trap's cilia).
            if controller.showsFoldInput(info) {
                HStack(spacing: c ? 8 : 12) {
                    DuoClapDiagram(reduceMotion: controller.reduceMotion, showsAngle: true)
                        .frame(width: Self.foldDiagramHeight * 1.3, height: Self.foldDiagramHeight)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.foldCaption)
                            .font(SnapType.headline(c))
                            .foregroundStyle(SnapTheme.cream)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Self.foldDetail)
                            .font(SnapType.caption(c))
                            .foregroundStyle(SnapTheme.mist)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .snapCard(padding: c ? 6 : 10, radius: 18)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.foldCaption + ". " + Self.foldDetail)
                .homeButtonFrame()
            }
            SnapButton(kind: .primary, height: c ? 58 : 70, compact: c, action: { controller.play() }) {
                Label("Feed", systemImage: "fork.knife")
            }
            .accessibilityHint("Start a run")
            .homeButtonFrame()
            SnapButton(kind: .secondary, height: c ? 52 : 60, compact: c, action: { controller.show(.daily) }) {
                HStack(spacing: 10) {
                    Image(systemName: "sun.max.fill").foregroundStyle(SnapTheme.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Daily Bog")
                        Text(dailyStatus(today))
                            .font(SnapType.caption(true))
                            .foregroundStyle(SnapTheme.mist)
                    }
                    Spacer(minLength: 0)
                    // R6: the Daily streak, next to "Today's bog is ready".
                    if let badge = Self.streakBadge(store.streak(today: today)) {
                        Text(badge)
                            .font(SnapType.caption(c).weight(.heavy).monospacedDigit())
                            .foregroundStyle(SnapTheme.cream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(SnapTheme.crimson.opacity(0.85)))
                            .fixedSize()
                            .accessibilityLabel("\(store.streak(today: today))-day streak")
                    }
                }
            }
            .homeButtonFrame()
            // R6: the Zen Bog and the Garden.
            HStack(spacing: c ? 8 : 12) {
                SnapButton(kind: .secondary, height: c ? 52 : 60, compact: c, action: { controller.playZen() }) {
                    VStack(spacing: 0) {
                        Text("Zen Bog")
                        Text(Self.zenDetail)
                            .font(SnapType.caption(true))
                            .foregroundStyle(SnapTheme.mist)
                    }
                }
                .accessibilityHint("A calm bog that never ends")
                SnapButton(kind: .secondary, height: c ? 52 : 60, compact: c, action: { controller.show(.garden) }) {
                    VStack(spacing: 0) {
                        Text("Garden")
                        HStack(spacing: 4) {
                            Text(Self.gardenCount(store.data))
                                .font(SnapType.caption(true).monospacedDigit())
                                .foregroundStyle(SnapTheme.mist)
                            if Self.gardenHasNew(store.data) {
                                Text("New")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(SnapTheme.ink)
                                    .padding(.horizontal, 5)
                                    .background(Capsule().fill(SnapTheme.gold))
                            }
                        }
                    }
                }
                .accessibilityHint("Choose your trap")
            }
            .homeButtonFrame()
            HStack(spacing: c ? 8 : 12) {
                SnapButton(kind: .secondary, height: c ? 52 : 60, compact: c, action: { controller.show(.book) }) {
                    VStack(spacing: 0) {
                        Text("Bug Book")
                        Text("\(found)/\(BugSpecies.allCases.count)")
                            .font(SnapType.caption(true).monospacedDigit())
                            .foregroundStyle(SnapTheme.mist)
                    }
                }
                SnapButton(kind: .secondary, height: c ? 52 : 60, compact: c, action: { controller.show(.settings) }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: c ? 20 : 24, weight: .bold))
                }
                .frame(width: c ? 64 : 76)
                .accessibilityLabel("Settings")
            }
            .homeButtonFrame()
        }
    }

    /// R6: under "Zen Bog".
    static let zenDetail = "No rush, no end"

    private func dailyStatus(_ today: Int) -> String {
        if store.canPlayScoredDaily(today: today) { return "Today's bog is ready" }
        if let r = store.data.dailyRecord(day: today) { return "Today " + AppRules.formatted(r.score) + " · practise" }
        return "Practise today's bog"
    }
}

/// Home's tap catcher over the live bog (phones: a tap chomps the trap) and the CHOMP! pop (its own observed object,
/// so the closure updates never rebuild Home's buttons). The pop sits on the other page, never across the crease.
struct HomeTrapLayer: View {
    @ObservedObject var trap: HomeTrapState
    let info: AppCanvas
    let reduceMotion: Bool
    let onTap: () -> Void
    @State private var chompShown = false
    @State private var chompTask: Task<Void, Never>?

    var body: some View {
        let other = info.otherPage
        ZStack {
            Color.clear
            if chompShown {
                Text("CHOMP!")
                    .font(.system(size: info.isCompact ? 54 : 76, weight: .black, design: .rounded))
                    .foregroundStyle(SnapTheme.gold)
                    .shadow(color: SnapTheme.crimsonDeep, radius: 0, x: 0, y: 5)
                    .snapLegible()
                    .rotationEffect(.degrees(-6))
                    .position(x: other.midX, y: info.size.height * 0.16)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: info.size.width, height: info.size.height)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onChange(of: trap.chomps) { _, _ in
            withAnimation(SnapTheme.pop(reduceMotion)) { chompShown = true }
            chompTask?.cancel()
            chompTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { chompShown = false }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("The title trap")
        .accessibilityAddTraits(.isButton)
    }
}

/// R7 (#4): every Home button row's frame in `HomeView.space` (the Home bog's clear zone).
struct HomeButtonFramesKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

extension View {
    /// R7 (#4): reports this view's frame as one of Home's buttons (`HomeButtonFramesKey`).
    func homeButtonFrame() -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: HomeButtonFramesKey.self, value: [g.frame(in: .named(HomeView.space))])
        })
    }
}
