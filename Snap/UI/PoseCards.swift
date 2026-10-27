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

/// A Duo seen from the front: it turns from upright to sideways, then opens like a book, the two halves a crimson
/// flytrap's lobes with pale teeth, and snaps a little shut. On a loop; still under Reduce Motion and in demo captures.
struct BookPoseDrawing: View {
    var reduceMotion = false

    static let loop: Double = 4.4

    /// Demo captures hold the clearest moment (turned and open).
    private var still: Bool { reduceMotion || AppTrace.enabled }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let t = still ? 2.4 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop)
            let turn = Self.ease(min(max((t - 0.3) / 0.9, 0), 1))
            let openIn = Self.ease(min(max((t - 1.4) / 0.6, 0), 1))
            let snap = Self.ease(min(max((t - 3.0) / 0.12, 0), 1)) * (1 - Self.ease(min(max((t - 3.4) / 0.4, 0), 1)))
            let fold = 18 * openIn + 26 * snap
            ZStack {
                Circle()
                    .fill(SnapTheme.moss.opacity(0.65))
                    .frame(width: 240, height: 240)
                HStack(spacing: 3) {
                    half(left: true)
                        .rotation3DEffect(.degrees(fold), axis: (x: 0, y: 1, z: 0), anchor: .trailing,
                                          perspective: 0.5)
                    half(left: false)
                        .rotation3DEffect(.degrees(-fold), axis: (x: 0, y: 1, z: 0), anchor: .leading,
                                          perspective: 0.5)
                }
                .frame(width: 196, height: 136)
                .rotationEffect(.degrees(-90 * (1 - turn)))
            }
        }
        .accessibilityHidden(true)
    }

    private static func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

    private func half(left: Bool) -> some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: left ? 20 : 4, bottomLeadingRadius: left ? 20 : 4,
                                   bottomTrailingRadius: left ? 4 : 20, topTrailingRadius: left ? 4 : 20,
                                   style: .continuous)
                .fill(SnapTheme.lime)
            UnevenRoundedRectangle(topLeadingRadius: left ? 15 : 3, bottomLeadingRadius: left ? 15 : 3,
                                   bottomTrailingRadius: left ? 3 : 15, topTrailingRadius: left ? 3 : 15,
                                   style: .continuous)
                .fill(LinearGradient(colors: left ? [SnapTheme.pink, SnapTheme.crimson]
                                                  : [SnapTheme.crimson, SnapTheme.pink],
                                     startPoint: .leading, endPoint: .trailing))
                .padding(6)
            // Teeth along the outer edge.
            VStack(spacing: 7) {
                ForEach(0..<6, id: \.self) { _ in
                    Capsule()
                        .fill(SnapTheme.limeLight)
                        .frame(width: 16, height: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: left ? .leading : .trailing)
            .offset(x: left ? -10 : 10)
        }
        .frame(width: 96, height: 136)
    }
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

    static func title(midRun: Bool) -> String { midRun ? "Open to carry on" : "Open it like a book" }
    static func detail(midRun: Bool) -> String {
        midRun ? "Your trap is waiting, jaws open." : "Bugs are gathering in the bog."
    }

    var body: some View {
        let midRun = controller.isLiveRun
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(colors: [SnapTheme.moss.opacity(0.55), Color.black], center: .center, startRadius: 20,
                               endRadius: max(geo.size.width, geo.size.height) * 0.6)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        TrapPortrait(closure01: 1)
                            .frame(width: min(geo.size.width * 0.7, 300), height: min(geo.size.width * 0.7, 300) * 0.7)
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
                            Text("Protein " + AppRules.formatted(controller.hud.values.score))
                                .font(SnapType.number(34))
                                .foregroundStyle(SnapTheme.gold)
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
