import SwiftUI

/// Results: the score as a big counting number, new best, the one sentence naming the best moment (on the other
/// page), then bugs caught, best bite, longest chain, bees spared, new Bug Book pages, the rank bar and Again / Home
/// (on the HUD page, the sharp half).
struct ResultsView: View {
    @ObservedObject var controller: GameController
    /// R6: the Garden's pick and the Bug Book's next page.
    @ObservedObject var store: ProgressStore
    let summary: ResultSummary
    let info: AppCanvas

    var body: some View {
        let c = info.isCompact
        let other = info.otherPage
        let page = info.hudPage
        ZStack {
            BogBackdrop(controller: controller,
                        glow: summary.outcome.showsNewBest ? SnapTheme.gold : SnapTheme.goldLight)
            hero(c)
                .frame(width: min(other.width, 440))
                .position(x: other.midX, y: info.size.height / 2)
            // R7 (#7, SCORE-R6: the rank card cut by the scroll in 20, 26, 27, 47, 50, P09; the Daily's goals cut
            // mid-row in 51): no scroll. The column takes the fullest layout that fits (`ViewThatFits`): every card,
            // then the stats in a grid and the "next" lines on one card, then the stats on one strip, then fewer
            // extras. Only a column too tall even at its tightest (huge Dynamic Type) scrolls. Home / Again and Share
            // stay put at its foot, always in reach.
            let colW = min(page.width, 400)
            let innerW = max(colW - 16, 1)
            VStack(spacing: c ? 8 : 12) {
                ViewThatFits(in: .vertical) {
                    column(c, fit: .full, width: innerW)
                    column(c, fit: .grid, width: innerW)
                    column(c, fit: .strip, width: innerW)
                    column(c, fit: .tight, width: innerW)
                    column(c, fit: .tightest, width: innerW)
                    ScrollView(showsIndicators: false) {
                        column(c, fit: .tightest, width: innerW)
                            .padding(.bottom, 14)
                    }
                    .scrollColumn(initially: false)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                actions(c)
                    .frame(width: colW)
            }
            .padding(.bottom, max(info.size.height - info.bottom, 12))
            .frame(width: page.width, height: info.size.height)
            .position(x: page.midX, y: info.size.height / 2)
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    /// Home / Again, and the Daily's Share.
    private func actions(_ c: Bool) -> some View {
        let r = summary.result
        let o = summary.outcome
        return VStack(spacing: c ? 8 : 10) {
            HStack(spacing: c ? 8 : 12) {
                SnapButton(kind: .secondary, height: c ? 56 : 60, compact: c, action: { controller.goHome() }) {
                    Text("Home")
                }
                .frame(width: c ? 110 : 130)
                SnapButton(kind: .primary, height: c ? 56 : 64, compact: c, action: { controller.again() }) {
                    Text(summary.againLabel)
                }
            }
            if let share = Self.shareText(r, streak: o.streak) {
                // R5 (ROUND-5, player 7): the Daily's one line for the group chat (no link until launch). R6: with
                // the streak in it.
                ShareLink(item: share) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SnapButtonStyle(kind: .secondary, height: SnapTheme.secondaryHeight, compact: c))
                .accessibilityHint("Share today's Daily Bog score")
            }
        }
    }

    /// How many new-species tiles fit in `width` (the last slot goes to "+n" when they don't all fit). Pure; tested.
    static func tilesShown(count: Int, width: CGFloat, tile: CGFloat, gap: CGFloat) -> Int {
        guard count > 0, tile > 0 else { return 0 }
        let fit = max(Int(((width + gap) / (tile + gap)).rounded(.down)), 1)
        return count <= fit ? count : max(fit - 1, 1)
    }

    // MARK: The other page

    private func hero(_ c: Bool) -> some View {
        let r = summary.result
        let o = summary.outcome
        return VStack(spacing: c ? 6 : 12) {
            // The trap that ate it all, as the scene paints it (REVIEW-1 #12). R4 (REVIEW-3 #16): open and 3/4 with a
            // fly sipping on it (never a centred slit), 1.4× on a patch of bog.
            ZStack {
                Ellipse()
                    .fill(RadialGradient(colors: [SnapTheme.mossLight.opacity(0.75), SnapTheme.moss.opacity(0.45),
                                                  SnapTheme.moss.opacity(0)],
                                         center: .center, startRadius: 4, endRadius: c ? 96 : 150))
                    .frame(width: c ? 200 : 310, height: c ? 120 : 180)
                TrapHeroImage(variety: controller.trapVariety)
                    .frame(width: c ? 162 : 252, height: c ? 118 : 182)
                    .shadow(color: Color.black.opacity(0.5), radius: 12, y: 4)
            }
            SnapOverline(text: summary.title, compact: c, color: SnapTheme.limeLight)
            // R7 (#10, SCORE-R6: Zen play showed a score and Zen Results none): the score, as the HUD showed it, in
            // every mode; the Zen Bog adds its bugs and its time, and keeps no best.
            CountingNumber(value: r.score, font: SnapType.hero(c),
                           instant: controller.reduceMotion || AppTrace.enabled)
                .foregroundStyle(LinearGradient(colors: [SnapTheme.goldLight, SnapTheme.gold], startPoint: .top,
                                                endPoint: .bottom))
                .shadow(color: SnapTheme.crimsonDeep, radius: 0, x: 0, y: 4)
                .snapLegible()
            // R5 (REVIEW-4 #13, founder call): "score", not "protein".
            Text(Self.heroWord(zen: o.zen))
                .font(SnapType.headline(c))
                .foregroundStyle(SnapTheme.mist)
            // R6: the Daily streak ("🔥 4 days").
            if let streak = ProgressRules.streakText(o.streak) {
                SnapPill(text: streak, color: SnapTheme.crimson, textColor: SnapTheme.cream)
                    .accessibilityLabel("\(o.streak)-day streak")
            }
            if o.zen {
                Text(Self.zenLine(bugs: r.bugsCaught, seconds: r.seconds))
                    .font(SnapType.body(c).monospacedDigit())
                    .foregroundStyle(SnapTheme.limeLight)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if o.showsNewBest {
                HStack(spacing: 8) {
                    SnapPill(text: "New best!")
                    if let was = AppRules.previousBestText(o.previousBest) {
                        Text(was)
                            .font(SnapType.body(c).monospacedDigit())
                            .foregroundStyle(SnapTheme.mist)
                    }
                }
            } else if o.firstRun {
                SnapPill(text: "First run!", color: SnapTheme.lime)
            } else if o.isFirstScore {
                SnapPill(text: "First score!", color: SnapTheme.lime)
            } else if let near = summary.nearMiss {
                Text(near)
                    .font(SnapType.body(c))
                    .foregroundStyle(SnapTheme.goldLight)
            } else if o.best > 0 {
                Text("Best " + AppRules.formatted(o.best))
                    .font(SnapType.body(c).monospacedDigit())
                    .foregroundStyle(SnapTheme.mist)
            }
            Text(summary.story)
                .font(SnapType.body(c))
                .foregroundStyle(SnapTheme.cream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, c ? 2 : 6)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: The HUD page

    /// R7 (#7): how much the HUD page's column holds, fullest first (`ViewThatFits` takes the first that fits).
    enum Fit: Int, CaseIterable {
        /// Every card, the stats as a list, the next goal and the next Bug Book page on cards of their own.
        case full
        /// The stats in a 2 × 2 grid; the next goal and the Book's next page share one card.
        case grid
        /// The stats on one strip; the new pages' tiles give way.
        case strip
        /// No bars under the goals, the rank without its hint; a new trap or the "next" card, not both.
        case tight
        /// The stats, the goals and the rank alone.
        case tightest

        var statsList: Bool { self == .full }
        var statsGrid: Bool { self == .grid }
        var separateNext: Bool { self == .full }
        var speciesTiles: Bool { self == .full || self == .grid }
        var goalBars: Bool { self == .full || self == .grid || self == .strip }
        var rankHint: Bool { self == .full || self == .grid || self == .strip }
        var showsNext: Bool { self != .tightest }
        var gardenAndNext: Bool { self == .full || self == .grid || self == .strip }
    }

    /// R7 (#7): the HUD page's column at a fit.
    private func column(_ c: Bool, fit: Fit, width: CGFloat) -> some View {
        let o = summary.outcome
        let next = Self.nextGoal(o)
        let book = AppRules.nextBookTarget(store.data)
        let garden = o.newVarieties.first
        let showsGarden = garden != nil && fit != .tightest
        let showsNext = fit.showsNext && (next != nil || book != nil) && (fit.gardenAndNext || garden == nil)
        return VStack(spacing: c ? 8 : 12) {
            stats(c, fit: fit)
            // R6: the run's goals, ticked, and the growth they gave.
            if !o.goalLines.isEmpty {
                GoalsCard(lines: o.goalLines, compact: c, title: GoalsCard.homeTitle,
                          footer: Self.goalsFooter(o), footerColor: o.goalBonus ? SnapTheme.gold : SnapTheme.limeLight,
                          bars: fit.goalBars)
            }
            // The rank bar next (the goals' growth fills it too).
            rankCard(c, hint: fit.rankHint)
            if showsGarden, let v = garden {
                gardenCard(v, more: o.newVarieties.count - 1, c)
            }
            if fit.speciesTiles && !o.newSpecies.isEmpty {
                speciesCard(c)
            }
            if showsNext {
                if fit.separateNext {
                    if let next { nextGoalCard(next, c) }
                    if let book { nextBookCard(book, c) }
                } else {
                    nextCard(goal: next, book: book, c)
                }
            }
        }
        .frame(width: width)
        .padding(.horizontal, 8)
        .padding(.top, info.top)
    }

    /// The run's numbers: a list (the fullest fit), a 2 × 2 grid, or one strip of four.
    @ViewBuilder
    private func stats(_ c: Bool, fit: Fit) -> some View {
        let r = summary.result
        let bite = AppRules.bestBiteText(bugs: r.biggestBite, points: r.bestBitePoints)
        let chain = AppRules.chainText(longest: r.longestChain)
        if fit.statsList {
            VStack(spacing: c ? 6 : 10) {
                statRow(icon: "ladybug.fill", title: "Bugs caught", value: "\(r.bugsCaught)", c)
                statRow(icon: "flame.fill", title: "Best bite", value: bite, c)
                statRow(icon: "link", title: "Best chain", value: chain, c)
                statRow(icon: "heart.fill", title: "Bees spared", value: "\(r.beesSpared)", c)
            }
            .snapCard(padding: c ? 10 : 14, radius: 20)
        } else if fit.statsGrid {
            VStack(spacing: c ? 6 : 8) {
                HStack(spacing: 8) {
                    statTile(value: "\(r.bugsCaught)", title: "Bugs caught", c)
                    statTile(value: bite, title: "Best bite", c)
                }
                HStack(spacing: 8) {
                    statTile(value: chain, title: "Best chain", c)
                    statTile(value: "\(r.beesSpared)", title: "Bees spared", c)
                }
            }
            .snapCard(padding: c ? 8 : 12, radius: 20)
        } else {
            HStack(spacing: 6) {
                statTile(value: "\(r.bugsCaught)", title: "Bugs", c)
                statTile(value: r.biggestBite > 0 ? AppRules.formatted(max(r.bestBitePoints, 0)) : "–",
                         title: Self.stripBiteTitle(r.biggestBite), c)
                statTile(value: r.longestChain > 0
                         ? AppRules.multiplierText(TrapRules.chainMultiplier(r.longestChain)) : "–",
                         title: "Chain", c)
                statTile(value: "\(r.beesSpared)", title: "Spared", c)
            }
            .snapCard(padding: c ? 8 : 10, radius: 20)
        }
    }

    /// R7 (#7): the strip's best-bite label ("Best bite", "5-bug bite"). Pure; tested.
    static func stripBiteTitle(_ bugs: Int) -> String { bugs >= 2 ? "\(bugs)-bug bite" : "Best bite" }

    /// One number over its label.
    private func statTile(value: String, title: String, _ c: Bool) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(SnapType.body(c).monospacedDigit().weight(.heavy))
                .foregroundStyle(SnapTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: c ? 10 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(SnapTheme.mist)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The new Bug Book pages as tiles.
    private func speciesCard(_ c: Bool) -> some View {
        let o = summary.outcome
        return Group {
                // As many tiles as fit, then "+n" (REVIEW-1 #23: the row never runs off the card).
                let tileW: CGFloat = c ? 52 : 62
                let cardW = min(info.hudPage.width, 400)
                let shown = ResultsView.tilesShown(count: o.newSpecies.count, width: cardW - (c ? 20 : 24),
                                                   tile: tileW, gap: 8)
                VStack(alignment: .leading, spacing: 6) {
                    SnapOverline(text: "New in the Bug Book", compact: c, color: SnapTheme.gold)
                    HStack(spacing: 8) {
                        ForEach(Array(o.newSpecies.prefix(shown).enumerated()), id: \.offset) { item in
                            VStack(spacing: 2) {
                                BugPortrait(species: item.element)
                                    .frame(width: c ? 36 : 46, height: c ? 36 : 46)
                                Text(AppRules.shortName(item.element))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(SnapTheme.mist)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(width: tileW)
                        }
                        if o.newSpecies.count > shown {
                            Text("+\(o.newSpecies.count - shown)")
                                .font(SnapType.headline(c))
                                .foregroundStyle(SnapTheme.gold)
                                .fixedSize()
                                .frame(width: tileW)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .snapCard(padding: c ? 10 : 12, radius: 20)
                .accessibilityElement(children: .combine)
        }
    }

    // MARK: R7 (#15): what's next

    /// The goal to play for next: the first goal drawn to replace a done one, else the first one still open. Pure;
    /// tested.
    static func nextGoal(_ o: RecordOutcome) -> GoalLine? {
        if let line = o.newGoals.lazy.compactMap({ GoalLine.fresh($0) }).first { return line }
        if let open = o.goalLines.first(where: { !$0.done && $0.inPlay }) { return open }
        return o.goalLines.first(where: { !$0.done })
    }

    static let nextGoalTitle = "Next goal"

    /// "Next goal: A 5-bug bite". Pure; tested.
    static func nextGoalText(_ g: GoalLine) -> String { nextGoalTitle + ": " + g.title }

    private func nextGoalCard(_ g: GoalLine, _ c: Bool) -> some View {
        HStack(spacing: c ? 8 : 10) {
            Image(systemName: "flag.fill")
                .font(.system(size: c ? 14 : 17, weight: .bold))
                .foregroundStyle(SnapTheme.gold)
                .frame(width: c ? 20 : 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    SnapOverline(text: Self.nextGoalTitle, compact: c, color: SnapTheme.gold)
                    if let t = g.tier { TierDot(tier: t, compact: c, label: true) }
                }
                Text(g.title)
                    .font(SnapType.caption(c).weight(.semibold))
                    .foregroundStyle(SnapTheme.cream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .snapCard(padding: c ? 10 : 12, radius: 20)
        .accessibilityElement(children: .combine)
    }

    /// The next goal and the Book's next page on one card (the tighter fits).
    private func nextCard(goal: GoalLine?, book: BugSpecies?, _ c: Bool) -> some View {
        VStack(alignment: .leading, spacing: c ? 4 : 6) {
            if let g = goal {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: c ? 11 : 13, weight: .bold))
                        .foregroundStyle(SnapTheme.gold)
                    Text(Self.nextGoalText(g))
                        .font(SnapType.caption(c).weight(.semibold))
                        .foregroundStyle(SnapTheme.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    if let t = g.tier { TierDot(tier: t, compact: c) }
                }
            }
            if let s = book {
                HStack(spacing: 6) {
                    Image(systemName: "book.fill")
                        .font(.system(size: c ? 11 : 13, weight: .bold))
                        .foregroundStyle(SnapTheme.gold)
                    Text(Self.nextBookShort + ": " + AppRules.nextBookLine(s))
                        .font(SnapType.caption(c).weight(.semibold))
                        .foregroundStyle(SnapTheme.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
            }
        }
        .snapCard(padding: c ? 10 : 12, radius: 20)
        .accessibilityElement(children: .combine)
    }

    static let nextBookShort = "Bug Book"

    /// R7 (#10): the Zen Bog's line under its score: "94 bugs in 2:30 · no best kept". Pure; tested.
    static func zenLine(bugs: Int, seconds: Double) -> String {
        let s = seconds.isFinite ? max(Int(seconds.rounded()), 0) : 0
        let n = max(bugs, 0)
        let time = "\(s / 60):" + String(format: "%02d", s % 60)
        return "\(n) \(n == 1 ? "bug" : "bugs") in " + time + " · no best kept"
    }

    /// The Daily share's line: the scored Daily only (a practice run isn't the day's score). R6: with the streak.
    /// Pure; tested.
    static func shareText(_ r: RunResult, streak: Int = 0) -> String? {
        guard case let .daily(day, scored) = r.mode, scored else { return nil }
        return AppRules.dailyShareText(day: day, score: r.score, biggestBite: r.biggestBite, streak: streak)
    }

    /// R6: the hero number's word. R7 (#10): "score" in the Zen Bog too (its HUD shows the score; `zenLine` adds the
    /// bugs and the time).
    static func heroWord(zen: Bool) -> String { AppRules.scoreWord }

    /// R6: under the goals: their growth (and the bonus), or nothing when none was done. Pure; tested.
    static func goalsFooter(_ o: RecordOutcome) -> String? {
        guard !o.goalsDone.isEmpty else { return nil }
        let growth = "+\(AppRules.formatted(o.goalGrowth)) growth"
        if o.goalBonus { return "All three! " + growth }
        let fresh = o.newGoals.count
        guard fresh > 0 else { return growth }
        return growth + " · \(fresh) new \(fresh == 1 ? "goal" : "goals") on Home"
    }

    /// R6 (#16): the next Bug Book page, in the Book's own words, with its silhouette.
    private func nextBookCard(_ s: BugSpecies, _ c: Bool) -> some View {
        HStack(spacing: c ? 8 : 12) {
            ZStack {
                Circle().fill(Color.black.opacity(0.25))
                BugPortrait(species: s, found: false)
                    .padding(c ? 2 : 3)
            }
            .frame(width: c ? 36 : 44, height: c ? 36 : 44)
            VStack(alignment: .leading, spacing: 2) {
                SnapOverline(text: Self.nextBookTitle, compact: c, color: SnapTheme.gold)
                Text(AppRules.nextBookLine(s))
                    .font(SnapType.caption(c).weight(.semibold))
                    .foregroundStyle(SnapTheme.cream)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .snapCard(padding: c ? 10 : 12, radius: 20)
        .accessibilityElement(children: .combine)
    }

    static let nextBookTitle = "Next for the Bug Book"
    static let gardenTitle = "New in the Garden"
    static let gardenUse = "Use it"

    /// R6: a variety this run grew, with "Use it".
    private func gardenCard(_ v: TrapVariety, more: Int, _ c: Bool) -> some View {
        let inUse = controller.trapVariety == v
        return HStack(spacing: c ? 8 : 12) {
            GardenTrapImage(variety: v, grown: true)
                .frame(width: c ? 64 : 84, height: c ? 46 : 60)
            VStack(alignment: .leading, spacing: 2) {
                SnapOverline(text: Self.gardenTitle, compact: c, color: SnapTheme.gold)
                Text(VarietyBridge.name(v) + (more > 0 ? " +\(more)" : ""))
                    .font(SnapType.headline(c))
                    .foregroundStyle(SnapTheme.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(VarietyBridge.blurb(v))
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if inUse {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: c ? 20 : 24, weight: .bold))
                    .foregroundStyle(SnapTheme.gold)
                    .accessibilityLabel("In use")
            } else {
                SnapButton(kind: .secondary, height: SnapTheme.minTap, compact: c,
                           action: { controller.chooseVariety(v) }) {
                    Text(Self.gardenUse)
                }
                .frame(width: c ? 84 : 96)
            }
        }
        .snapCard(padding: c ? 10 : 12, radius: 20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SnapTheme.gold.opacity(0.7), lineWidth: 2))
    }

    /// `hint`: the line under the bar (the tighter fits drop it).
    private func rankCard(_ c: Bool, hint: Bool = true) -> some View {
        let o = summary.outcome
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "leaf.fill").foregroundStyle(SnapTheme.lime)
                Text(summary.rankTitle)
                    .font(SnapType.body(c))
                    .foregroundStyle(SnapTheme.cream)
                if o.rankedUp {
                    SnapPill(text: "Rank up!", color: SnapTheme.lime)
                }
                Spacer(minLength: 4)
                if let next = summary.nextRankTitle {
                    Text("Next: " + next)
                        .font(SnapType.caption(c))
                        .foregroundStyle(SnapTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            RankBar(from: summary.rankProgressBefore, to: summary.rankProgressAfter,
                    instant: controller.reduceMotion || AppTrace.enabled)
            if hint {
                Text(AppRules.rankHint(lifetimeBugs: o.lifetimeAfter))
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .snapCard(padding: c ? 10 : 14, radius: 20)
        .accessibilityElement(children: .combine)
    }

    private func statRow(icon: String, title: String, value: String, _ c: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: c ? 13 : 15, weight: .bold))
                .foregroundStyle(SnapTheme.lime)
                .frame(width: 22)
            Text(title)
                .font(SnapType.body(c))
                .foregroundStyle(SnapTheme.cream)
            Spacer(minLength: 8)
            Text(value)
                .font(SnapType.body(c).monospacedDigit())
                .foregroundStyle(SnapTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A number that counts up to `value` over 1.2 s (at once under Reduce Motion and in demo captures).
struct CountingNumber: View {
    let value: Int
    let font: Font
    var instant = false
    @State private var shown = 0
    @State private var task: Task<Void, Never>?

    static let duration: Double = 1.2

    var body: some View {
        Text(AppRules.formatted(instant ? value : shown))
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel("\(value)")
            .onAppear { run() }
            .onChange(of: value) { _, _ in run() }
            .onDisappear { task?.cancel() }
    }

    private func run() {
        task?.cancel()
        guard !instant, value > 0 else {
            shown = value
            return
        }
        shown = 0
        let target = value
        task = Task { @MainActor in
            let steps = 36
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(Self.duration / Double(steps) * 1_000_000_000))
                if Task.isCancelled { return }
                let f = Double(i) / Double(steps)
                let eased = 1 - pow(1 - f, 3)
                shown = Int((Double(target) * eased).rounded())
            }
            shown = target
        }
    }
}

/// The rank bar, filling from before to after.
struct RankBar: View {
    let from: Double
    let to: Double
    var instant = false
    @State private var value: Double = 0

    var body: some View {
        SnapProgressBar(value: instant ? to : value, height: 10)
            .onAppear {
                value = from
                guard !instant else { return }
                withAnimation(.easeOut(duration: 1.0).delay(0.5)) { value = to }
            }
    }
}
