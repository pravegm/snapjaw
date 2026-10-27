import SwiftUI

/// Home: the title over a live trap that follows the hinge (snap the Duo a little shut and it chomps, with
/// `FeedbackDirector.homeTrap`; a tap on other iPhones), a bee bumbling across, and the four buttons on the HUD page
/// (the right, sharp half by default): Feed, Daily Bog, Bug Book, Settings. Shows the plant rank, the best and the
/// Daily's status.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    var body: some View {
        let c = info.isCompact
        let page = info.hudPage
        let other = info.otherPage
        let buttonsW = min(page.width, c ? 300 : 340)
        ZStack {
            SnapBackdrop()
            HomeTrapLayer(trap: controller.homeTrap, info: info, reduceMotion: controller.reduceMotion,
                          onTap: { controller.homeTrapTapped() })
            // A soft shade under the buttons so they read over the crimson lobe.
            LinearGradient(colors: [SnapTheme.night.opacity(0), SnapTheme.night.opacity(0.62)],
                           startPoint: info.hudOnLeft ? .trailing : .leading,
                           endPoint: info.hudOnLeft ? .leading : .trailing)
                .frame(width: page.width + info.edgeMargin + info.foldClear, height: info.size.height)
                .position(x: page.midX + (info.hudOnLeft ? -info.edgeMargin / 2 : info.edgeMargin / 2),
                          y: info.size.height / 2)
                .allowsHitTesting(false)
            titleBlock(c)
                .frame(width: min(other.width, 420))
                .position(x: other.midX, y: info.size.height * (c ? 0.30 : 0.28))
                .allowsHitTesting(false)
            buttons(c)
                .frame(width: buttonsW)
                .position(x: page.midX, y: info.size.height / 2 + (c ? 4 : 10))
        }
        .frame(width: info.size.width, height: info.size.height)
    }

    // MARK: Title

    private func titleBlock(_ c: Bool) -> some View {
        let rank = store.rank
        let progress = ProgressRules.rankProgress(lifetime: store.data.lifetimeBugs, rank: rank)
        return VStack(spacing: c ? 6 : 10) {
            Text(AppBrand.name)
                .font(SnapType.wordmark(c))
                .foregroundStyle(LinearGradient(colors: [SnapTheme.cream, SnapTheme.limeLight], startPoint: .top,
                                                endPoint: .bottom))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: SnapTheme.crimsonDeep, radius: 0, x: 0, y: 4)
                .snapLegible()
            Text(AppBrand.tagline)
                .font(SnapType.headline(c))
                .foregroundStyle(SnapTheme.cream)
                .snapLegible()
            Text(controller.hasHinge ? "Snap it a little shut. It bites!" : "Tap the trap. It bites!")
                .font(SnapType.caption(c))
                .foregroundStyle(SnapTheme.mist)
                .snapLegible()
            VStack(spacing: 6) {
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
            }
            .frame(maxWidth: 300)
            .snapCard(padding: c ? 10 : 14, radius: 18)
            .padding(.top, c ? 4 : 10)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Buttons

    private func buttons(_ c: Bool) -> some View {
        let today = controller.today
        let found = store.data.speciesFound
        return VStack(spacing: c ? 8 : 14) {
            SnapButton(kind: .primary, height: c ? 58 : 70, compact: c, action: { controller.play() }) {
                Label("Feed", systemImage: "fork.knife")
            }
            .accessibilityHint("Start a run")
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
                }
            }
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
        }
    }

    private func dailyStatus(_ today: Int) -> String {
        if store.canPlayScoredDaily(today: today) { return "Today's bog is ready" }
        if let r = store.data.dailyRecord(day: today) { return "Today " + AppRules.formatted(r.score) + " · practise" }
        return "Practise today's bog"
    }
}

/// Home's live title trap (its own observed object, so the 30 Hz closure never rebuilds Home's buttons), the bee and
/// the CHOMP! pop.
struct HomeTrapLayer: View {
    @ObservedObject var trap: HomeTrapState
    let info: AppCanvas
    let reduceMotion: Bool
    let onTap: () -> Void
    @State private var chompShown = false
    @State private var chompTask: Task<Void, Never>?

    var body: some View {
        let trapRect = info.trapRect
        ZStack {
            TrapPortrait(closure01: trap.closure01)
                .frame(width: info.size.width, height: info.size.height)
            BumblingBee(area: CGRect(x: 0, y: 0, width: info.size.width, height: info.size.height),
                        still: reduceMotion || AppTrace.enabled)
                .allowsHitTesting(false)
            if chompShown {
                Text("CHOMP!")
                    .font(.system(size: info.isCompact ? 54 : 76, weight: .black, design: .rounded))
                    .foregroundStyle(SnapTheme.gold)
                    .shadow(color: SnapTheme.crimsonDeep, radius: 0, x: 0, y: 5)
                    .snapLegible()
                    .rotationEffect(.degrees(-6))
                    .position(x: trapRect.midX, y: trapRect.midY)
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

/// A bee bumbling across Home in a lazy figure of eight (it never lands: bees are friends).
struct BumblingBee: View {
    let area: CGRect
    var still = false

    static let period: Double = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? 3.2 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1_000)
            let phase = t * 2 * Double.pi / Self.period
            let x = area.midX + area.width * 0.34 * CGFloat(sin(phase))
            let y = area.minY + area.height * 0.22 + area.height * 0.07 * CGFloat(sin(phase * 2 + 0.6))
            let heading = cos(phase)
            BugPortrait(species: .bee, flying: true)
                .frame(width: 58, height: 58)
                .scaleEffect(x: heading >= 0 ? 1 : -1, y: 1)
                .offset(y: CGFloat(sin(t * 9)) * 2)
                .position(x: x, y: y)
        }
    }
}
