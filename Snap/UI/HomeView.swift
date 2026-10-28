import SwiftUI

/// Home (R8, rebuilt: "Menus feel cheap"): the live bog behind everything (an attract session drawn by the real scene:
/// close the phone and it chomps whatever has landed; a tap on other iPhones). One focal action, Play, which goes on to
/// the next level (Level 1 on a first launch: Levels 1–5 teach); Endless, the Daily and Zen as three lily pads under
/// it; the map, the Bug Book, the Garden and Settings as a quiet row. The title, the rank and the goals on the other
/// page, in few words. Everything off the fold, and it rises into place on entry.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    /// R8: the input in words (the pose card, Settings).
    static let foldCaption = "Close the phone to bite"
    static let foldDetail = "The two halves are the trap. Open them to feed."
    /// R4 (REVIEW-3 #8): kept for the fold diagram's other uses (the pose card).
    static let foldDiagramHeight: CGFloat = 120

    var body: some View {
        let c = info.isCompact
        let page = info.hudPage
        let other = info.otherPage
        let actionsW = min(page.width, c ? 320 : 360)
        // The shade under the actions runs from the fold to the screen's own edge (no seam at the safe area).
        let shadeX0 = info.hudOnLeft ? 0 : info.foldMaxX
        let shadeX1 = info.hudOnLeft ? info.foldMinX : info.size.width
        let otherX0 = info.hudOnLeft ? info.foldMaxX : 0
        let otherX1 = info.hudOnLeft ? info.size.width : info.foldMinX
        ZStack {
            if controller.scene == nil { SnapBackdrop() }
            HomeTrapLayer(trap: controller.homeTrap, info: info, reduceMotion: controller.reduceMotion,
                          onTap: { controller.homeTrapTapped() })
            LinearGradient(colors: [SnapTheme.night.opacity(0.08), SnapTheme.night.opacity(0.72)],
                           startPoint: info.hudOnLeft ? .trailing : .leading,
                           endPoint: info.hudOnLeft ? .leading : .trailing)
                .frame(width: max(shadeX1 - shadeX0, 0), height: info.size.height)
                .position(x: (shadeX0 + shadeX1) / 2, y: info.size.height / 2)
                .allowsHitTesting(false)
            // A soft shade behind the title so it reads over the lobe (never a slab over the trap).
            RadialGradient(colors: [SnapTheme.night.opacity(0.66), SnapTheme.night.opacity(0)], center: .center,
                           startRadius: 10, endRadius: max(otherX1 - otherX0, 1) * 0.62)
                .frame(width: max(otherX1 - otherX0, 0), height: info.size.height)
                .position(x: (otherX0 + otherX1) / 2, y: info.size.height * 0.45)
                .allowsHitTesting(false)
            titleBlock(c)
                .frame(width: min(other.width, 420))
                .position(x: other.midX, y: info.size.height * 0.47)
                .allowsHitTesting(false)
            actions(c)
                .frame(width: actionsW)
                .position(x: page.midX, y: info.size.height / 2 + (c ? 2 : 8))
        }
        .frame(width: info.size.width, height: info.size.height)
        // R7 (Scene/Core #4): the buttons' real frames, in scene space, are the Home bog's clear zone.
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

    /// R8: one line under the name: the rule (phones: how to bite).
    static let foldSubtitle = "Feed the flytrap. Spare bees."
    static let touchSubtitle = "Tap to snap. Spare bees."

    static func subtitle(foldInput: Bool) -> String { foldInput ? foldSubtitle : touchSubtitle }

    private func titleBlock(_ c: Bool) -> some View {
        let rank = store.rank
        let progress = ProgressRules.rankProgress(lifetime: store.data.growth, rank: rank)
        let rm = controller.reduceMotion
        return VStack(spacing: c ? 6 : 12) {
            DisplayText(text: AppBrand.name, size: c ? 60 : 88, tilt: -3)
                .entrance(0, reduceMotion: rm)
            Text(Self.subtitle(foldInput: controller.showsFoldInput(info)))
                .font(SnapType.headline(c))
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .snapLegible()
                .entrance(1, reduceMotion: rm)
            // The rank and the stars: one strip.
            HStack(spacing: c ? 10 : 14) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").foregroundStyle(SnapTheme.lime)
                    Text(PlantRanks.title(rank))
                        .font(SnapType.body(c))
                        .foregroundStyle(SnapTheme.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                SnapProgressBar(value: progress, height: 7)
                    .frame(width: c ? 60 : 84)
                Text("★ \(LevelRules.totalStars(store.data))")
                    .font(SnapType.body(c).monospacedDigit().weight(.heavy))
                    .foregroundStyle(SnapTheme.gold)
                if store.data.bestFeed > 0 {
                    Text("Best " + AppRules.formatted(store.data.bestFeed))
                        .font(SnapType.body(c).monospacedDigit())
                        .foregroundStyle(SnapTheme.goldLight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, c ? 12 : 16)
            .padding(.vertical, c ? 7 : 10)
            .background(LeafPanel(big: 20, small: 7))
            .accessibilityElement(children: .combine)
            .entrance(2, reduceMotion: rm)
            // R6: the three goals (R8: a compact leaf, the goals Endless, the Daily and Zen play for).
            GoalsCard(lines: ProgressRules.goalLines(store.goalBook), compact: true, tierLabels: false, bars: !c)
                .frame(maxWidth: c ? 300 : 340)
                .entrance(3, reduceMotion: rm)
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

    /// R8: Play's line: the level it goes on to ("Level 3 · Catch 3 flies"), or Endless when every level is done.
    static func playLine(_ data: ProgressData) -> String {
        guard let next = LevelRules.next(data) else { return "Endless" }
        let goal = LevelBridge.spec(next).map { " · " + LevelBridge.goal($0) } ?? ""
        return LevelWords.levelName(next) + goal
    }

    // MARK: Actions

    private func actions(_ c: Bool) -> some View {
        let today = controller.today
        let rm = controller.reduceMotion
        let pad: CGFloat = c ? 62 : 84
        return VStack(spacing: c ? 10 : 18) {
            // The one focal action.
            PlayButton(line: Self.playLine(store.data), compact: c, action: { controller.play() })
                .homeButtonFrame()
                .entrance(0, reduceMotion: rm)
            // R8 (founder rule 5): Endless, the Daily and Zen are always one tap away.
            HStack(alignment: .top, spacing: c ? 8 : 14) {
                PadButton(title: "Endless", detail: store.data.bestFeed > 0
                          ? "Best " + AppRules.formatted(store.data.bestFeed) : "Until the night",
                          size: pad, tint: SnapTheme.mossLight, action: { controller.playEndless() }) {
                    Image(systemName: "infinity")
                        .font(.system(size: pad * 0.36, weight: .black))
                        .foregroundStyle(SnapTheme.limeLight)
                        .snapLegible()
                }
                PadButton(title: "Daily", detail: dailyStatus(today), size: pad, tint: Color(snapHex: 0x5C7A2E),
                          badge: Self.streakBadge(store.streak(today: today)), action: { controller.show(.daily) }) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: pad * 0.36, weight: .black))
                        .foregroundStyle(SnapTheme.gold)
                        .snapLegible()
                }
                PadButton(title: "Zen", detail: Self.zenDetail, size: pad, tint: Color(snapHex: 0x2F6E5C),
                          action: { controller.playZen() }) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: pad * 0.34, weight: .black))
                        .foregroundStyle(Color(snapHex: 0xBFF0D8))
                        .snapLegible()
                }
            }
            .homeButtonFrame()
            .entrance(1, reduceMotion: rm)
            // The quiet row.
            HStack(spacing: c ? 6 : 10) {
                QuietIcon(systemImage: "map.fill", label: "Levels", compact: c) { controller.show(.levels) }
                QuietIcon(systemImage: "book.fill", label: "\(store.data.speciesFound)/\(BugSpecies.allCases.count)",
                          compact: c, accessibility: "Bug Book") { controller.show(.book) }
                QuietIcon(systemImage: "camera.macro", label: Self.gardenCount(store.data), compact: c,
                          dot: Self.gardenHasNew(store.data), accessibility: "Garden") { controller.show(.garden) }
                QuietIcon(systemImage: "gearshape.fill", label: "Settings", compact: c) { controller.show(.settings) }
            }
            .homeButtonFrame()
            .entrance(2, reduceMotion: rm)
        }
    }

    /// R6: under "Zen".
    static let zenDetail = "No rush, no end"

    private func dailyStatus(_ today: Int) -> String {
        if store.canPlayScoredDaily(today: today) { return "Ready" }
        if let r = store.data.dailyRecord(day: today) { return AppRules.formatted(r.score) }
        return "Practise"
    }
}

/// R8: Home's focal action: a big inked gold button, "Play" in display type and the level it goes to under it.
struct PlayButton: View {
    let line: String
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: compact ? 0 : 2) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: compact ? 26 : 34, weight: .black))
                    Text("Play")
                        .font(.system(size: compact ? 36 : 48, weight: .black, design: .rounded))
                }
                Text(line)
                    .font(.system(size: compact ? 13 : 15, weight: .heavy, design: .rounded))
                    .opacity(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 16)
            }
            .foregroundStyle(SnapTheme.ink)
            .frame(maxWidth: .infinity, minHeight: compact ? 78 : 104)
        }
        .buttonStyle(PlayButtonStyle())
        .accessibilityLabel("Play, " + line)
    }
}

/// The Play button's paint: the primary button's, bigger, pressing down into its lip.
struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(SnapButtonBackground(kind: .primary, pressed: configuration.isPressed))
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// R8: a quiet round icon with a word under it (Home's map, Bug Book, Garden, Settings).
struct QuietIcon: View {
    let systemImage: String
    let label: String
    var compact = false
    var dot = false
    var accessibility: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Circle().fill(SnapTheme.night.opacity(0.8)).offset(y: 3)
                    Circle().fill(LinearGradient(colors: [Color(snapHex: 0x24573A), SnapTheme.surface],
                                                 startPoint: .top, endPoint: .bottom))
                    Circle().stroke(SnapTheme.night, lineWidth: 2.5)
                    Image(systemName: systemImage)
                        .font(.system(size: compact ? 17 : 21, weight: .heavy))
                        .foregroundStyle(SnapTheme.cream)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if dot {
                        Circle().fill(SnapTheme.gold).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(SnapTheme.night, lineWidth: 2))
                    }
                }
                .frame(width: compact ? 42 : 52, height: compact ? 42 : 52)
                Text(label)
                    .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(SnapTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .snapLegible()
            }
            .frame(minWidth: SnapTheme.minTap, minHeight: SnapTheme.minTap)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(accessibility ?? label)
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
                DisplayText(text: "CHOMP!", size: info.isCompact ? 54 : 76, fill: [SnapTheme.goldLight, SnapTheme.gold],
                            tilt: -6)
                    .position(x: other.midX, y: info.size.height * 0.14)
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
