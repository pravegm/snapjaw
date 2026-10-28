import SwiftUI

/// Home (R8, rebuilt: "Menus feel cheap"): the live bog behind everything (an attract session drawn by the real scene:
/// close the phone and it chomps whatever has landed; a tap on other iPhones). One focal action, Play, which goes on to
/// the next level (Level 1 on a first launch: Levels 1–5 teach); Endless, the Daily and Zen as three lily pads under
/// it; the map, the Bug Book, the Garden and Settings as a quiet row. The title, the rank and the goals on the other
/// page, in few words. Everything off the fold, and it rises into place on entry.
/// R9: a first launch shows only the name, its one line and Play (which breathes); the rank and the goals come once
/// there is progress (`showsProgress`). Every quiet button has its word; Play's line speaks the player's control.
struct HomeView: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    let info: AppCanvas

    /// R8: the input in words (Settings). R8 portrait: the pose card is gone (every angle plays).
    static let foldCaption = "Close the phone to bite"
    static let foldDetail = "The two halves are the trap. Open them to feed."

    var body: some View {
        let c = info.isCompact
        let page = info.hudPage
        let other = info.otherPage
        let actionsW = min(page.width, c ? 320 : 360)
        // The shade under the actions runs from the fold to the screen's own edge (no seam at the safe area). R8
        // portrait: the halves are the top and the bottom of the screen.
        let shade = info.hudHalf
        let otherHalf = info.otherHalf
        let toward = info.towardHUD
        ZStack {
            if controller.scene == nil { SnapBackdrop() }
            HomeTrapLayer(trap: controller.homeTrap, info: info, reduceMotion: controller.reduceMotion,
                          onTap: { controller.homeTrapTapped() })
            LinearGradient(colors: [SnapTheme.night.opacity(0.08), SnapTheme.night.opacity(0.72)],
                           startPoint: toward.start, endPoint: toward.end)
                .frame(width: shade.width, height: shade.height)
                .position(x: shade.midX, y: shade.midY)
                .allowsHitTesting(false)
            // A soft shade behind the title so it reads over the lobe (never a slab over the trap).
            RadialGradient(colors: [SnapTheme.night.opacity(0.66), SnapTheme.night.opacity(0)], center: .center,
                           startRadius: 10, endRadius: max(min(otherHalf.width, info.size.width), 1) * 0.62)
                .frame(width: otherHalf.width, height: otherHalf.height)
                .position(x: otherHalf.midX, y: otherHalf.minY + otherHalf.height * 0.45)
                .allowsHitTesting(false)
            titleBlock(c)
                .frame(width: min(other.width, 420))
                .position(x: other.midX, y: other.minY + other.height * 0.47)
                .allowsHitTesting(false)
            actions(c)
                .frame(width: actionsW)
                .position(x: page.midX, y: page.midY + (c ? 2 : 8))
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

    /// R9 ("Unclear what to do", "Menus feel cheap"): a first-time player's Home is the name, one line and Play. The
    /// rank strip and the goals come once there is something to show: Level 3 passed, or a run of Endless, the Daily or
    /// Zen played (their goals are written when one starts). Pure; tested.
    static let progressAfterLevel = 3

    static func showsProgress(_ d: ProgressData) -> Bool {
        LevelRules.passed(d, progressAfterLevel) || d.goalBook != nil || d.feedRuns > 0
    }

    private func titleBlock(_ c: Bool) -> some View {
        let rank = store.rank
        let progress = ProgressRules.rankProgress(lifetime: store.data.growth, rank: rank)
        let rm = controller.reduceMotion
        let full = Self.showsProgress(store.data)
        return VStack(spacing: c ? 6 : 12) {
            DisplayText(text: AppBrand.name, size: full ? (c ? 60 : 88) : (c ? 70 : 104), tilt: -3)
                .entrance(0, reduceMotion: rm)
            Text(Self.subtitle(foldInput: controller.showsFoldInput(info)))
                .font(SnapType.headline(c))
                .foregroundStyle(SnapTheme.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .snapLegible()
                .entrance(1, reduceMotion: rm)
            if full { progressBlock(c, rank: rank, progress: progress) }
        }
    }

    /// The rank, the stars and the best on one strip, and the three goals (from `showsProgress`).
    private func progressBlock(_ c: Bool, rank: Int, progress: Double) -> some View {
        let rm = controller.reduceMotion
        return VStack(spacing: c ? 6 : 12) {
            // The rank and the stars: one strip. R9: the best lives under Endless only (frame 03: "Fly Catc…").
            HStack(spacing: c ? 10 : 14) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").foregroundStyle(SnapTheme.lime)
                    Text(PlantRanks.title(rank))
                        .font(SnapType.body(c))
                        .foregroundStyle(SnapTheme.cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }
                SnapProgressBar(value: progress, height: 7)
                    .frame(width: c ? 56 : 80)
                Text("★ \(LevelRules.totalStars(store.data))")
                    .font(SnapType.body(c).monospacedDigit().weight(.heavy))
                    .foregroundStyle(SnapTheme.gold)
                    .lineLimit(1)
                    .fixedSize()
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
    /// R9: in the player's control (a phone: "Level 1 · Tap when the fly lands"; the Duo: "… · Close the phone on the
    /// fly"). Pure; tested.
    static func playLine(_ data: ProgressData, touch: Bool) -> String {
        guard let next = LevelRules.next(data) else { return "Endless" }
        let goal = LevelBridge.spec(next).map { " · " + LevelWords.goal($0, touch: touch) } ?? ""
        return LevelWords.levelName(next) + goal
    }

    /// R9 (frame 01: "0/16" and "1/8" with no word): the quiet row's count badges, shown once there is something
    /// counted (a found bug; a variety grown past the first). Pure; tested.
    static func bookBadge(_ data: ProgressData) -> String? {
        data.speciesFound > 0 ? "\(data.speciesFound)/\(BugSpecies.allCases.count)" : nil
    }

    static func gardenBadge(_ data: ProgressData) -> String? {
        data.unlockedVarieties.count > 1 ? gardenCount(data) : nil
    }

    /// R9: the quiet row's words (every button says what it is).
    static let rowWords = ["Levels", "Bug Book", "Garden", "Settings"]

    // MARK: Actions

    private func actions(_ c: Bool) -> some View {
        let today = controller.today
        let rm = controller.reduceMotion
        let pad: CGFloat = c ? 58 : 80
        let touch = !controller.showsFoldInput(info)
        return VStack(spacing: c ? 10 : 18) {
            // The one focal action (R9: it glows, and breathes on a first launch).
            PlayButton(line: Self.playLine(store.data, touch: touch), compact: c,
                       beckons: LevelRules.next(store.data) == 1 && !rm, action: { controller.play() })
                .homeButtonFrame()
                .entrance(0, reduceMotion: rm)
            // R8 (founder rule 5): Endless, the Daily and Zen are always one tap away. R9: fewer words (only a best
            // and the Daily's state).
            HStack(alignment: .top, spacing: c ? 8 : 14) {
                PadButton(title: "Endless", detail: store.data.bestFeed > 0
                          ? "Best " + AppRules.formatted(store.data.bestFeed) : nil,
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
                PadButton(title: "Zen", detail: nil, size: pad, tint: Color(snapHex: 0x2F6E5C),
                          action: { controller.playZen() }) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: pad * 0.34, weight: .black))
                        .foregroundStyle(Color(snapHex: 0xBFF0D8))
                        .snapLegible()
                }
            }
            .homeButtonFrame()
            .entrance(1, reduceMotion: rm)
            // The quiet row. R9 (frame 01: "0/16", "1/8"): every button says what it is; a count rides on its icon.
            HStack(spacing: c ? 6 : 10) {
                QuietIcon(systemImage: "map.fill", label: Self.rowWords[0], compact: c) { controller.show(.levels) }
                QuietIcon(systemImage: "book.fill", label: Self.rowWords[1], compact: c,
                          badge: Self.bookBadge(store.data),
                          accessibility: "Bug Book, \(store.data.speciesFound) of \(BugSpecies.allCases.count) found") {
                    controller.show(.book)
                }
                QuietIcon(systemImage: "camera.macro", label: Self.rowWords[2], compact: c,
                          badge: Self.gardenBadge(store.data), dot: Self.gardenHasNew(store.data),
                          accessibility: "Garden, " + Self.gardenCount(store.data) + " grown") {
                    controller.show(.garden)
                }
                QuietIcon(systemImage: "gearshape.fill", label: Self.rowWords[3], compact: c) {
                    controller.show(.settings)
                }
            }
            .homeButtonFrame()
            .entrance(2, reduceMotion: rm)
        }
    }

    /// R6: under "Zen" (R9: Home says no more than "Zen"; the Zen Bog's banner says this).
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
    /// R9: a first launch's Play breathes (a slow swell and glow), so the one thing to do is obvious at a glance.
    var beckons = false
    let action: () -> Void
    @State private var swell = false

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
        // R9: the focal action carries a warm glow over the bog (the only gold light on Home).
        .shadow(color: SnapTheme.gold.opacity(beckons && swell ? 0.6 : 0.32), radius: beckons && swell ? 26 : 16)
        .scaleEffect(beckons && swell && !AppTrace.enabled ? 1.035 : 1)
        .onAppear {
            guard beckons, !AppTrace.enabled else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.8)) { swell = true }
        }
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

/// R8: a quiet round icon with a word under it (Home's map, Bug Book, Garden, Settings). R9: the word is always the
/// button's name; a count ("9/16") rides on the icon as a small gold tab.
struct QuietIcon: View {
    let systemImage: String
    let label: String
    var compact = false
    var badge: String?
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
                        // Something new (a grown variety): the top corner the count tab leaves free.
                        Circle().fill(SnapTheme.gold).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(SnapTheme.night, lineWidth: 2))
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: badge == nil ? .topTrailing : .topLeading)
                    }
                }
                .frame(width: compact ? 42 : 52, height: compact ? 42 : 52)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: compact ? 9 : 10, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(SnapTheme.ink)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(SnapTheme.goldLight))
                            .overlay(Capsule().stroke(SnapTheme.night, lineWidth: 1.5))
                            .fixedSize()
                            .offset(x: compact ? 12 : 14, y: -4)
                    }
                }
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
                    .position(x: other.midX, y: other.minY + other.height * 0.14)
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
