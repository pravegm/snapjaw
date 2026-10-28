import SwiftUI
import UIKit

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
                        // R4 (Duo frame duo-06: the drawing was a quarter of the page): it fills the page.
                        drawing
                            .frame(width: min(page * 0.86, 440), height: min(geo.size.height * 0.8, 440))
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
                            .frame(width: min(geo.size.width * 0.8, 400), height: min(half * 0.9, 400))
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
            // R4 (REVIEW-3 #16, Scene R4): the trap on its own is the Scene's 3/4 trap, a fly sipping on it.
            TrapHeroImage()
                .frame(width: Self.heroWidth, height: Self.heroWidth * CoverLayout.trapAspect)
                .padding(.top, 6)
        }
    }

    static let heroWidth: CGFloat = 150
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

    /// The drawing's own size (points); it scales to fit its frame.
    static let side: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            let k = max(min(geo.size.width, geo.size.height) / Self.side, 0.3)
            content
                .frame(width: Self.side, height: Self.side)
                .scaleEffect(k)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityHidden(true)
    }

    private var content: some View {
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
                        // R4 (REVIEW-3 #8): two hands hold it like a book, palms behind, thumbs on the front.
                        HoldingHands(theta: th, width: 200, height: 141, layer: .palms)
                            .opacity(turn)
                        DuoFoldView(theta: th, arrows: arrows)
                            .frame(width: 200, height: 141)
                        // A fly sipping on the right lobe: the clap is for it (R4, REVIEW-3 #16: it stays on through
                        // the still frame, so the trap on the card is never a bare slit).
                        BugPortrait(species: .housefly)
                            .frame(width: 30, height: 30)
                            .offset(x: 46, y: -6)
                            .opacity(turn)
                        HoldingHands(theta: th, width: 200, height: 141, layer: .thumbs)
                            .opacity(turn)
                    }
                    .frame(width: 250, height: 150)
                    .rotationEffect(.degrees(-90 * (1 - turn)))
                    FoldAngleGlyph(theta: th)
                        .frame(width: 160, height: 48)
                        .opacity(turn)
                }
            }
        }
    }

    static func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

/// R4 (REVIEW-3 #8, "like a book needs hands"): two hands holding the Duo by its outer edges, drawn in two layers
/// round `DuoFoldView` (`width` × `height`, centred): the palms behind the halves, the thumbs over their fronts. The
/// hands follow the halves' outer edges as the hinge angle `theta` changes.
struct HoldingHands: View {
    enum Layer { case palms, thumbs }

    let theta: Double
    let width: CGFloat
    let height: CGFloat
    let layer: Layer

    static let skin = Color(snapHex: 0xE8B48C)
    static let skinShade = Color(snapHex: 0xC98E66)
    static let line = Color(snapHex: 0x4A2E1E)

    /// The outer edge's distance from the hinge, seen from the front, at `theta` (each half turns (180 − θ) / 2).
    /// Pure; tested.
    static func edgeReach(theta: Double, halfWidth: CGFloat) -> CGFloat {
        let tilt = min(max((180 - (theta.isFinite ? theta : 160)) / 2, 0), 80) * Double.pi / 180
        return halfWidth * CGFloat(cos(tilt))
    }

    var body: some View {
        Canvas { ctx, size in
            let mid = CGPoint(x: size.width / 2, y: size.height / 2)
            let reach = Self.edgeReach(theta: theta, halfWidth: width / 2)
            for side in [CGFloat(-1), 1] {
                let edge = mid.x + side * reach
                switch layer {
                case .palms:
                    // The palm and the heel of the hand, behind the half's outer edge, lower half.
                    let palm = CGRect(x: edge - (side > 0 ? 10 : 26), y: mid.y - height * 0.18, width: 36,
                                      height: height * 0.62)
                    let shape = Path(roundedRect: palm, cornerRadius: 16)
                    ctx.fill(shape, with: .linearGradient(Gradient(colors: [Self.skin, Self.skinShade]),
                                                          startPoint: CGPoint(x: palm.midX, y: palm.minY),
                                                          endPoint: CGPoint(x: palm.midX, y: palm.maxY)))
                    ctx.stroke(shape, with: .color(Self.line.opacity(0.55)), lineWidth: 1.5)
                case .thumbs:
                    // The thumb across the front of the half, near its outer edge, pointing in toward the hinge.
                    var thumb = Path()
                    let base = CGPoint(x: edge + side * 4, y: mid.y + height * 0.22)
                    let tip = CGPoint(x: edge - side * 30, y: mid.y + height * 0.12)
                    thumb.move(to: base)
                    thumb.addLine(to: tip)
                    ctx.stroke(thumb, with: .color(Self.line.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 17, lineCap: .round))
                    ctx.stroke(thumb, with: .color(Self.skin), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    // The nail.
                    let nail = CGRect(x: tip.x - 4 + side * 2, y: tip.y - 4, width: 8, height: 7)
                    ctx.fill(Path(ellipseIn: nail), with: .color(Color.white.opacity(0.55)))
                }
            }
        }
        .accessibilityHidden(true)
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
        let hasBest = !midRun && store.data.bestFeed > 0
        GeometryReader { geo in
            // R4 (REVIEW-3 #4): sized to fit, never a scroll that clips the score (32: "400 so far" was cut at 402 pt).
            let l = CoverLayout.make(size: geo.size, insets: insets, midRun: midRun, hasBest: hasBest)
            ZStack {
                Color.black.ignoresSafeArea()
                RadialGradient(colors: [SnapTheme.moss.opacity(0.55), Color.black], center: .center, startRadius: 20,
                               endRadius: max(geo.size.width, geo.size.height) * 0.6)
                    .ignoresSafeArea()
                if l.sideBySide {
                    HStack(spacing: CoverLayout.gap) {
                        trap(l)
                        words(l, midRun: midRun, hasBest: hasBest)
                    }
                    .position(x: l.area.midX, y: l.area.midY)
                } else {
                    VStack(spacing: l.spacing) {
                        trap(l)
                        words(l, midRun: midRun, hasBest: hasBest)
                    }
                    .position(x: l.area.midX, y: l.area.midY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .combine)
    }

    /// The trap open and 3/4, a fly sipping on it (REVIEW-3 #16): the scene's own art.
    private func trap(_ l: CoverLayout) -> some View {
        TrapHeroImage()
            .frame(width: l.trap.width, height: l.trap.height)
            .shadow(color: Color.black.opacity(0.6), radius: 18, y: 6)
    }

    private func words(_ l: CoverLayout, midRun: Bool, hasBest: Bool) -> some View {
        VStack(spacing: l.spacing) {
            Text(Self.title(midRun: midRun))
                .font(CoverLayout.swiftFont(l.titleSize, .heavy))
                .foregroundStyle(SnapTheme.cream)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(Self.detail(midRun: midRun))
                .font(CoverLayout.swiftFont(l.bodySize, .semibold))
                .foregroundStyle(SnapTheme.mist)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if midRun {
                VStack(spacing: CoverLayout.scoreGap) {
                    Text(Self.scoreLine(controller.hud.values.score))
                        .font(SnapType.number(l.scoreSize))
                        .foregroundStyle(SnapTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("protein")
                        .font(CoverLayout.swiftFont(l.bodySize, .semibold))
                        .foregroundStyle(SnapTheme.mist)
                }
            } else if hasBest {
                Text("Best feast " + AppRules.formatted(store.data.bestFeed))
                    .font(CoverLayout.swiftFont(l.bodySize + 4, .bold))
                    .foregroundStyle(SnapTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: l.textWidth)
    }
}

/// The cover card's sizes (R4, REVIEW-3 #4): everything fits the canvas, from a phone in landscape (874 × 402) to the
/// Duo's cover display (466 × 678), with the type measured as it is set. A wide canvas puts the trap beside the words.
/// Pure; tested.
struct CoverLayout: Equatable {
    var area: CGRect
    var sideBySide: Bool
    var trap: CGSize
    var textWidth: CGFloat
    var titleSize: CGFloat
    var bodySize: CGFloat
    var scoreSize: CGFloat
    var spacing: CGFloat
    /// The words' measured height.
    var textHeight: CGFloat
    /// Everything's height (the trap and the words).
    var contentHeight: CGFloat

    static let margin: CGFloat = 20
    static let gap: CGFloat = 24
    static let scoreGap: CGFloat = 2
    /// The hero trap's height over its width (the Scene's 3/4 drawing).
    static var trapAspect: CGFloat { min(max(TrapArt.threeQuarterAspect, 0.5), 1) }
    static let trapMaxW: CGFloat = 320
    /// The smallest trap worth drawing before the type steps down a size.
    static let trapMinH: CGFloat = 90

    enum Weight { case heavy, bold, semibold }

    static func swiftFont(_ size: CGFloat, _ w: Weight) -> Font {
        switch w {
        case .heavy: return .system(size: size, weight: .heavy, design: .rounded)
        case .bold: return .system(size: size, weight: .bold, design: .rounded)
        case .semibold: return .system(size: size, weight: .semibold, design: .rounded)
        }
    }

    static func font(_ size: CGFloat, _ w: Weight) -> UIFont {
        let weight: UIFont.Weight
        switch w {
        case .heavy: weight = .heavy
        case .bold: weight = .bold
        case .semibold: weight = .semibold
        }
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: rounded, size: size)
    }

    /// The height `text` takes at `width`, wrapped.
    static func height(_ text: String, _ f: UIFont, width: CGFloat) -> CGFloat {
        let r = (text as NSString).boundingRect(with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                attributes: [.font: f], context: nil)
        return max(r.height.rounded(.up), f.lineHeight.rounded(.up))
    }

    static func make(size: CGSize, insets: EdgeInsets, midRun: Bool, hasBest: Bool) -> CoverLayout {
        let x0 = max(insets.leading, 0) + margin
        let y0 = max(insets.top, 0) + margin
        let x1 = size.width - max(insets.trailing, 0) - margin
        let y1 = size.height - max(insets.bottom, 0) - margin
        let area = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
        let side = area.width > area.height * 1.15
        var last: CoverLayout?
        // The larger type when it fits, else a size down.
        for compact in [false, true] {
            let titleSize: CGFloat = compact ? 22 : 30
            let bodySize: CGFloat = compact ? 15 : 17
            let scoreSize: CGFloat = compact ? 28 : 34
            let spacing: CGFloat = compact ? 8 : 14
            let textW = side ? min((area.width - gap) / 2, 400) : min(area.width, 400)
            var text = height(CoverCard.carryOn, font(titleSize, .heavy), width: textW)
            text += spacing + height(CoverCard.detail(midRun: midRun), font(bodySize, .semibold), width: textW)
            if midRun {
                text += spacing + font(scoreSize, .heavy).lineHeight.rounded(.up) + scoreGap
                    + font(bodySize, .semibold).lineHeight.rounded(.up)
            } else if hasBest {
                text += spacing + font(bodySize + 4, .bold).lineHeight.rounded(.up)
            }
            var trapW: CGFloat
            if side {
                trapW = min((area.width - gap) / 2, trapMaxW, area.height / trapAspect)
            } else {
                trapW = min(area.width * 0.78, trapMaxW, max(area.height - text - spacing, 0) / trapAspect)
            }
            trapW = max(trapW, 0)
            let trapH = trapW * trapAspect
            let content = side ? max(text, trapH) : trapH + spacing + text
            let l = CoverLayout(area: area, sideBySide: side, trap: CGSize(width: trapW, height: trapH),
                                textWidth: textW, titleSize: titleSize, bodySize: bodySize, scoreSize: scoreSize,
                                spacing: spacing, textHeight: text, contentHeight: content)
            if content <= area.height + 0.5 && trapH >= trapMinH { return l }
            last = l
        }
        return last ?? CoverLayout(area: area, sideBySide: side, trap: .zero, textWidth: area.width, titleSize: 22,
                                   bodySize: 15, scoreSize: 28, spacing: 8, textHeight: 0, contentHeight: 0)
    }
}
