import SwiftUI

// MARK: - Portrait: "Hold it open like a book"

/// Full-screen card for a portrait canvas (the Duo in tabletop, or a phone held upright before iOS turns the UI): the
/// game holds until the phone is held like a book. On a Duo in tabletop the fold runs across the middle, so the
/// drawing sits on the top half and the words on the bottom half, both clear of the fold.
struct PoseCard: View {
    var insets: EdgeInsets = EdgeInsets()
    let isDuo: Bool
    var reduceMotion = false

    /// Clear band kept around the middle of a portrait canvas (the Duo's tabletop fold, 40 pt + margins).
    static let foldBand: CGFloat = 80

    static func title(isDuo: Bool) -> String { isDuo ? "Hold it open like a book" : "Turn your iPhone sideways" }
    static func detail(isDuo: Bool) -> String {
        isDuo ? "The two halves are the trap. Snap it a little shut to bite." : "Tap anywhere to snap the trap."
    }

    var body: some View {
        ZStack {
            SnapBackdrop()
            GeometryReader { geo in
                if geo.size.width > geo.size.height {
                    // A landscape canvas (demo `screen=pose`): drawing and words side by side, clear of the middle.
                    let page = max((geo.size.width - Self.foldBand) / 2, 0)
                    HStack(spacing: 0) {
                        drawing
                            .frame(width: min(page * 0.8, 280), height: min(geo.size.height * 0.7, 260))
                            .frame(width: page, height: geo.size.height)
                        Color.clear.frame(width: Self.foldBand)
                        copy
                            .frame(maxWidth: 420, alignment: .leading)
                            .padding(.horizontal, 24)
                            .frame(width: max(page - insets.trailing, 0), height: geo.size.height)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    let half = max((geo.size.height - Self.foldBand) / 2, 0)
                    VStack(spacing: 0) {
                        drawing
                            .frame(width: min(geo.size.width * 0.65, 280), height: min(half * 0.8, 260))
                            .frame(maxWidth: .infinity)
                            .frame(height: half)
                            .padding(.top, insets.top * 0.5)
                        Color.clear.frame(height: Self.foldBand)
                        copy
                            .frame(maxWidth: 440)
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity)
                            .frame(height: half, alignment: .top)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var drawing: some View {
        if isDuo {
            BookPoseDrawing(reduceMotion: reduceMotion)
        } else {
            PhoneTurnDrawing(reduceMotion: reduceMotion)
        }
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Self.title(isDuo: isDuo))
                .font(SnapType.title(false))
                .foregroundStyle(SnapTheme.cream)
                .fixedSize(horizontal: false, vertical: true)
            Text(Self.detail(isDuo: isDuo))
                .font(SnapType.body(false))
                .foregroundStyle(SnapTheme.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A Duo seen from the front, its halves showing the play trap's two lobes (`TrapArt`, REVIEW-2 #24): it turns from
/// upright to sideways, opens like a book to 160°, then claps to 138° and opens again, twice (ROUND-3 founder call),
/// with the hinge angle drawn from the top under it. On a loop; still at the clap under Reduce Motion and in demo
/// captures.
struct BookPoseDrawing: View {
    var reduceMotion = false

    static let loop: Double = 4.4
    /// The intro (turn and open) takes this long; the clap loop follows.
    static let introEnd: Double = 1.8
    /// Demo captures hold the clearest moment: turned, open, mid-clap at 138°.
    static let stillTime: Double = introEnd + DuoClapDiagram.stillTime

    private var still: Bool { reduceMotion || AppTrace.enabled }

    /// θ at `t` s into the loop: half open while it turns, opening to 160°, then the clap. Pure; tested.
    static func theta(at t: Double) -> Double {
        let x = t.isFinite ? t.truncatingRemainder(dividingBy: loop) : 0
        if x < introEnd {
            let openIn = ease(min(max((x - 1.2) / 0.6, 0), 1))
            return 100 + (DuoClapDiagram.openAngle - 100) * openIn
        }
        return DuoClapDiagram.theta(at: x - introEnd)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? Self.stillTime
                          : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop)
            let turn = Self.ease(min(max((t - 0.3) / 0.9, 0), 1))
            let th = Self.theta(at: t)
            let clapT = t - Self.introEnd
            let arrows = t >= Self.introEnd ? DuoClapDiagram.arrows(at: clapT) : 0
            ZStack {
                Circle()
                    .fill(SnapTheme.moss.opacity(0.65))
                    .frame(width: 250, height: 250)
                VStack(spacing: 8) {
                    ZStack {
                        DuoFoldView(theta: th, arrows: arrows)
                            .frame(width: 200, height: 141)
                        // A fly sipping on the right lobe: the clap is for it (gone once the trap shuts).
                        BugPortrait(species: .housefly)
                            .frame(width: 30, height: 30)
                            .offset(x: 46, y: -6)
                            .opacity(turn * (th > 150 ? 1 : 0))
                    }
                    .rotationEffect(.degrees(-90 * (1 - turn)))
                    FoldAngleGlyph(theta: th)
                        .frame(width: 160, height: 34)
                        .opacity(turn)
                }
            }
        }
        .accessibilityHidden(true)
    }

    static func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

/// A regular iPhone turning from upright to sideways. On a loop; still under Reduce Motion and in demo captures.
struct PhoneTurnDrawing: View {
    var reduceMotion = false

    static let loop: Double = 3.6
    private var still: Bool { reduceMotion || AppTrace.enabled }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? 2.4 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop)
            let turn = 1 - pow(1 - min(max((t - 0.4) / 0.9, 0), 1), 3)
            ZStack {
                Circle()
                    .fill(SnapTheme.moss.opacity(0.65))
                    .frame(width: 230, height: 230)
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SnapTheme.cream.opacity(0.9))
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(LinearGradient(colors: [SnapTheme.pink, SnapTheme.crimson, SnapTheme.pink],
                                             startPoint: .leading, endPoint: .trailing))
                        .padding(5)
                }
                .frame(width: 196, height: 96)
                .rotationEffect(.degrees(-90 * (1 - turn)))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - The cover display

/// The cover display (466 × 678) and the shut Duo: a closed trap, then what's waiting ("Open to carry on" mid-run).
struct CoverCard: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    var insets: EdgeInsets = EdgeInsets()

    /// One line for "open to carry on" everywhere (the closing card says it too: REVIEW-1-ux P2 #14).
    static let carryOn = "Open it up to carry on"

    /// R3 (REVIEW-2 #24): the promised "Open it up to carry on" on the cover, with the run's score mid-run.
    static func title(midRun: Bool) -> String { carryOn }
    static func detail(midRun: Bool) -> String {
        midRun ? "Your trap is waiting, jaws open." : "Bugs are gathering in the bog."
    }
    /// "1,174 so far" (mid-run). Pure; tested.
    static func scoreLine(_ score: Int) -> String { AppRules.formatted(max(score, 0)) + " so far" }

    var body: some View {
        let midRun = controller.isLiveRun
        GeometryReader { geo in
            let side = min(geo.size.width * 0.78, 320)
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(colors: [SnapTheme.moss.opacity(0.55), Color.black], center: .center, startRadius: 20,
                               endRadius: max(geo.size.width, geo.size.height) * 0.6)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // The play trap, drawn by the scene's own code (one art language, REVIEW-1 #12).
                        TrapArtImage()
                            .frame(width: side, height: side * 0.74)
                            .shadow(color: Color.black.opacity(0.6), radius: 18, y: 6)
                            .padding(.top, 8)
                        Text(Self.title(midRun: midRun))
                            .font(SnapType.title(false))
                            .foregroundStyle(SnapTheme.cream)
                            .multilineTextAlignment(.center)
                        Text(Self.detail(midRun: midRun))
                            .font(SnapType.body(false))
                            .foregroundStyle(SnapTheme.mist)
                            .multilineTextAlignment(.center)
                        if midRun {
                            Text(Self.scoreLine(controller.hud.values.score))
                                .font(SnapType.number(34))
                                .foregroundStyle(SnapTheme.gold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("protein")
                                .font(SnapType.body(false))
                                .foregroundStyle(SnapTheme.mist)
                        } else if store.data.bestFeed > 0 {
                            Text("Best feast " + AppRules.formatted(store.data.bestFeed))
                                .font(SnapType.headline(false))
                                .foregroundStyle(SnapTheme.gold)
                        }
                    }
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 24)
                    .padding(.top, max(insets.top, 20) + 16)
                    .padding(.bottom, max(insets.bottom, 16) + 16)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
