import SwiftUI

/// Home: the live bog behind the menu (an attract session drawn by the real scene, REVIEW-1 #12: snap the Duo a
/// little shut and it chomps whatever has landed, with `FeedbackDirector.homeTrap`; a tap on other iPhones), the title
/// on the other page, and the four buttons on the HUD page (the right, sharp half by default): Feed, Daily Bog, Bug
/// Book, Settings. Shows the plant rank (and what grows it), the best and the Daily's status.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

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
    }

    // MARK: Title

    private func titleBlock(_ c: Bool) -> some View {
        let rank = store.rank
        let progress = ProgressRules.rankProgress(lifetime: store.data.lifetimeBugs, rank: rank)
        return VStack(spacing: c ? 4 : 8) {
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .snapLegible()
            Text(controller.hasHinge ? "Snap it a little shut. It bites!" : "Tap the trap. It bites!")
                .font(SnapType.caption(c))
                .foregroundStyle(SnapTheme.mist)
                .snapLegible()
            VStack(alignment: .leading, spacing: 6) {
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
                Text(AppRules.rankHint(lifetimeBugs: store.data.lifetimeBugs))
                    .font(SnapType.caption(c))
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
