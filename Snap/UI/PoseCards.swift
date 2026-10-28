import SwiftUI
import UIKit

// MARK: - The pose card: "Hold it open like a book"

/// Full-screen card for a portrait canvas (the Duo in tabletop, or a phone held upright before iOS turns the UI): the
/// game holds until the phone is held like a book.
///
/// R5 (REVIEW-4 #2, frame 31: a black quadrant, a rotated diagram, stacked traps, a sideways "138°"): rebuilt simply.
/// One diagram drawn in a single `Canvas` (no 3D rotation, no scale effect, no images of the scene laid over each
/// other), a short title and one line. `PoseCardLayout` places both as plain rects (tested at 874 × 402, 951 × 669 and
/// both portraits): on a portrait canvas the diagram sits on the top half and the words on the bottom half, both clear
/// of the Duo's tabletop fold; on a landscape canvas (demo `screen=pose`) they sit side by side, clear of the middle.
struct PoseCard: View {
    var insets: EdgeInsets = EdgeInsets()
    let isDuo: Bool
    var reduceMotion = false

    /// Clear band kept round the middle of the canvas (the Duo's fold, 40 pt plus margins).
    static let foldBand: CGFloat = 80

    /// R8 (founder rule 2: no pose demands): it says how the game is laid out, never how to hold the phone.
    static func title(isDuo: Bool) -> String { isDuo ? "Snapjaw plays sideways" : "Snapjaw plays sideways" }
    /// One line (R5: the card was a title, two sentences and a second trap).
    /// R8: the phone is the trap: open is open, shut is a bite.
    static func detail(isDuo: Bool) -> String {
        isDuo ? "The two halves are its jaws." : "Tap to snap."
    }

    var body: some View {
        ZStack {
            SnapBackdrop()
            GeometryReader { geo in
                let l = PoseCardLayout.make(size: geo.size, insets: insets, isDuo: isDuo)
                ZStack {
                    PoseDiagram(isDuo: isDuo, reduceMotion: reduceMotion)
                        .frame(width: l.diagram.width, height: l.diagram.height)
                        .position(x: l.diagram.midX, y: l.diagram.midY)
                    VStack(alignment: l.sideBySide ? .leading : .center, spacing: l.spacing) {
                        Text(Self.title(isDuo: isDuo))
                            .font(CoverLayout.swiftFont(l.titleSize, .heavy))
                            .foregroundStyle(SnapTheme.cream)
                            .multilineTextAlignment(l.sideBySide ? .leading : .center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Self.detail(isDuo: isDuo))
                            .font(CoverLayout.swiftFont(l.bodySize, .semibold))
                            .foregroundStyle(SnapTheme.mist)
                            .multilineTextAlignment(l.sideBySide ? .leading : .center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: l.text.width, alignment: l.sideBySide ? .leading : .center)
                    .position(x: l.text.midX, y: l.text.midY)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}

/// Where the pose card's diagram and words go (screen points, top-left origin). Pure; tested: the two never overlap,
/// stay inside the safe area, keep off the fold band, and the words fit their half.
struct PoseCardLayout: Equatable {
    /// The safe area less the margin.
    var area: CGRect
    var sideBySide: Bool
    var diagram: CGRect
    /// The words' box (its height is the words' measured height).
    var text: CGRect
    var titleSize: CGFloat
    var bodySize: CGFloat
    var spacing: CGFloat
    /// The room the words had (their half, or their page).
    var textRoom: CGRect

    static let margin: CGFloat = 20
    /// The diagram's width bounds (its height is `PoseDiagram.aspect` of that).
    static let diagramMin: CGFloat = 120
    static let diagramMax: CGFloat = 440

    static func make(size: CGSize, insets: EdgeInsets, isDuo: Bool) -> PoseCardLayout {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let x0 = max(insets.leading, 0) + margin
        let y0 = max(insets.top, 0) + margin
        let x1 = w - max(insets.trailing, 0) - margin
        let y1 = h - max(insets.bottom, 0) - margin
        let area = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
        let side = w >= h
        let band = PoseCard.foldBand / 2
        let aspect = PoseDiagramArt.box.height / PoseDiagramArt.box.width
        let title = PoseCard.title(isDuo: isDuo)
        let detail = PoseCard.detail(isDuo: isDuo)
        var last: PoseCardLayout?
        for compact in [false, true] {
            let titleSize: CGFloat = compact ? 24 : 32
            let bodySize: CGFloat = compact ? 16 : 19
            let spacing: CGFloat = compact ? 8 : 12
            let diagramRoom: CGRect
            let textRoom: CGRect
            if side {
                // The fold (if any) runs down the middle: the diagram on the left page, the words on the right.
                diagramRoom = CGRect(x: area.minX, y: area.minY, width: max(w / 2 - band - area.minX, 1),
                                     height: area.height)
                let tx = w / 2 + band
                textRoom = CGRect(x: tx, y: area.minY, width: max(area.maxX - tx, 1), height: area.height)
            } else {
                // The tabletop fold runs across the middle: the diagram on the top half, the words on the bottom.
                diagramRoom = CGRect(x: area.minX, y: area.minY, width: area.width,
                                     height: max(h / 2 - band - area.minY, 1))
                let ty = h / 2 + band
                textRoom = CGRect(x: area.minX, y: ty, width: area.width, height: max(area.maxY - ty, 1))
            }
            let textW = min(textRoom.width, side ? 400 : 440)
            let textH = CoverLayout.height(title, CoverLayout.font(titleSize, .heavy), width: textW) + spacing
                + CoverLayout.height(detail, CoverLayout.font(bodySize, .semibold), width: textW)
            let text: CGRect
            if side {
                text = CGRect(x: textRoom.minX, y: textRoom.midY - textH / 2, width: textW, height: textH)
            } else {
                text = CGRect(x: textRoom.midX - textW / 2, y: textRoom.minY, width: textW, height: textH)
            }
            let fitW = diagramRoom.width * (side ? 0.92 : 0.86)
            let dw = max(min(fitW, diagramMax, diagramRoom.height * 0.92 / aspect), 1)
            let dh = dw * aspect
            let diagram = CGRect(x: diagramRoom.midX - dw / 2, y: diagramRoom.midY - dh / 2, width: dw, height: dh)
            let l = PoseCardLayout(area: area, sideBySide: side, diagram: diagram, text: text, titleSize: titleSize,
                                   bodySize: bodySize, spacing: spacing, textRoom: textRoom)
            if textH <= textRoom.height + 0.5 && dw >= diagramMin { return l }
            last = l
        }
        return last ?? PoseCardLayout(area: area, sideBySide: side, diagram: .zero, text: .zero, titleSize: 24,
                                      bodySize: 16, spacing: 8, textRoom: area)
    }
}

/// The pose card's one diagram, drawn in a single `Canvas` (`PoseDiagramArt`):
/// - a Duo: seen from the front, held open like a book, its two screens showing the two lobes of one trap (the midrib
///   on the hinge, a fly sipping), snapping 160° → 138° and opening again with the "shut" chevrons at its outer edges;
/// - another iPhone: turning from upright to sideways.
/// On a loop; still (mid-clap, or turned) under Reduce Motion and in demo captures.
struct PoseDiagram: View {
    let isDuo: Bool
    var reduceMotion = false

    /// Height over width (the drawing's design box is `PoseDiagramArt.box`).
    static var aspect: CGFloat { PoseDiagramArt.box.height / PoseDiagramArt.box.width }
    static let phoneLoop: Double = 3.6

    private var still: Bool { reduceMotion || AppTrace.enabled }

    var body: some View {
        let fly = isDuo ? BugArtCache.image(.housefly, found: true, flying: false) : nil
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: still)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let duo = isDuo
            let clapT = still ? DuoClapDiagram.stillTime : now
            let theta = DuoClapDiagram.theta(at: clapT)
            let arrows = DuoClapDiagram.arrows(at: clapT)
            let phoneT = still ? 2.4 : now.truncatingRemainder(dividingBy: Self.phoneLoop)
            let turn = 1 - pow(1 - min(max((phoneT - 0.4) / 0.9, 0), 1), 3)
            Canvas { ctx, size in
                if duo {
                    PoseDiagramArt.drawDuo(&ctx, size: size, theta: theta, arrows: arrows, fly: fly)
                } else {
                    PoseDiagramArt.drawPhone(&ctx, size: size, turn: turn)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The pose diagram's drawing (plain 2D paths; the Duo's perspective is computed here, point by point). Pure.
enum PoseDiagramArt {
    /// The design box (points); the drawing is fitted and centred in the view.
    static let box = CGSize(width: 300, height: 210)
    static let hingeX: CGFloat = 150
    static let midY: CGFloat = 105
    /// One half's width, flat.
    static let halfWidth: CGFloat = 112
    /// The halves' height at the hinge; the outer edges are nearer the eye and drawn taller.
    static let height: CGFloat = 150
    /// The drawn tilt exaggerates the real one, so a 22° snap reads at a glance.
    static let tiltGain: Double = 1.8

    static let body = Color(snapHex: 0x14181C)
    static let leaf = Color(snapHex: 0x2F6A2C)
    static let lip = Color(snapHex: 0x173D17)
    static let faceDeep = Color(snapHex: 0x7A0C26)
    static let faceRim = Color(snapHex: 0xD23048)
    static let rib = Color(snapHex: 0x4E0716)

    /// Each half's drawn tilt (radians) at hinge angle `theta` (degrees between the halves, 180 = flat). Pure; tested.
    static func tilt(theta: Double) -> Double {
        let t = theta.isFinite ? min(max(theta, 90), 180) : 160
        return min((180 - t) / 2 * tiltGain, 70) * Double.pi / 180
    }

    /// A point on half `side` (−1 left, +1 right): `u` 0 at the hinge … 1 at the outer edge, `v` −1 top … 1 bottom, at
    /// `tilt` radians (design space). Pure; tested (the outer edge comes in and grows as the Duo snaps).
    static func point(side: CGFloat, u: CGFloat, v: CGFloat, tilt lean: Double) -> CGPoint {
        let reach = halfWidth * CGFloat(cos(lean))
        let grow = 1 + 0.22 * CGFloat(sin(lean)) * u
        return CGPoint(x: hingeX + side * u * reach, y: midY + v * height / 2 * grow)
    }

    /// Fits the design box into `size` (centred).
    private static func fit(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let k = max(min(size.width / box.width, size.height / box.height), 0.01)
        ctx.translateBy(x: (size.width - box.width * k) / 2, y: (size.height - box.height * k) / 2)
        ctx.scaleBy(x: k, y: k)
    }

    static func drawDuo(_ context: inout GraphicsContext, size: CGSize, theta: Double, arrows: Double, fly: CGImage?) {
        var ctx = context
        fit(&ctx, size)
        let lean = tilt(theta: theta)
        // A soft round shadow of the bog behind it.
        ctx.fill(Path(ellipseIn: CGRect(x: 28, y: 8, width: 244, height: 194)),
                 with: .color(SnapTheme.moss.opacity(0.55)))
        for side in [CGFloat(-1), 1] {
            func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { point(side: side, u: u, v: v, tilt: lean) }
            // The half's body, then its screen.
            var shell = Path()
            shell.move(to: p(0, -1))
            shell.addLine(to: p(1, -1))
            shell.addLine(to: p(1, 1))
            shell.addLine(to: p(0, 1))
            shell.closeSubpath()
            ctx.fill(shell, with: .color(body))
            ctx.stroke(shell, with: .color(body), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
            var screen = Path()
            screen.move(to: p(0.02, -0.95))
            screen.addLine(to: p(0.96, -0.95))
            screen.addLine(to: p(0.96, 0.95))
            screen.addLine(to: p(0.02, 0.95))
            screen.closeSubpath()
            ctx.fill(screen, with: .color(SnapTheme.bog))
            // Its lobe: half of one trap, the midrib on the hinge.
            let a: CGFloat = 0.86
            let b: CGFloat = 0.74
            var lobe = Path()
            let steps = 28
            for i in 0...steps {
                let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
                let q = p(a * CGFloat(cos(t)), b * CGFloat(sin(t)))
                if i == 0 { lobe.move(to: q) } else { lobe.addLine(to: q) }
            }
            lobe.closeSubpath()
            ctx.stroke(lobe, with: .color(leaf), style: StrokeStyle(lineWidth: 8, lineJoin: .round))
            ctx.fill(lobe, with: .linearGradient(Gradient(colors: [faceDeep, faceRim]), startPoint: p(0, 0),
                                                 endPoint: p(a, 0)))
            ctx.stroke(lobe, with: .color(lip), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            // The cilia round its margin.
            var cilia = Path()
            for i in 1..<14 {
                let t = -Double.pi / 2 + Double.pi * Double(i) / 14
                cilia.move(to: p(a * CGFloat(cos(t)), b * CGFloat(sin(t))))
                cilia.addLine(to: p(a * 1.13 * CGFloat(cos(t)), b * 1.16 * CGFloat(sin(t))))
            }
            ctx.stroke(cilia, with: .color(SnapTheme.limeLight), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            // A gloss streak.
            var gloss = Path()
            gloss.move(to: p(0.30, -0.46))
            gloss.addQuadCurve(to: p(0.62, -0.30), control: p(0.52, -0.52))
            ctx.stroke(gloss, with: .color(Color.white.opacity(0.3)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            // The "shut" chevron at the outer edge, pointing in.
            if arrows > 0.01 {
                let k = CGFloat(min(max(arrows, 0), 1))
                let edge = p(1, 0)
                let x = edge.x + side * 20
                var chevron = Path()
                chevron.move(to: CGPoint(x: x + side * 7, y: edge.y - 14))
                chevron.addLine(to: CGPoint(x: x - side * 7, y: edge.y))
                chevron.addLine(to: CGPoint(x: x + side * 7, y: edge.y + 14))
                ctx.stroke(chevron, with: .color(Color.black.opacity(0.4 * Double(k))),
                           style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                ctx.stroke(chevron, with: .color(SnapTheme.limeLight.opacity(Double(k))),
                           style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
        }
        // The midrib on the hinge.
        var midrib = Path()
        midrib.move(to: CGPoint(x: hingeX, y: midY - height / 2 * 0.72))
        midrib.addLine(to: CGPoint(x: hingeX, y: midY + height / 2 * 0.72))
        ctx.stroke(midrib, with: .color(rib), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        // A fly sipping on the right lobe: the snap is for it.
        if let fly, fly.width > 0, fly.height > 0 {
            let c = point(side: 1, u: 0.44, v: -0.08, tilt: lean)
            let w: CGFloat = 34
            let h = w * CGFloat(fly.height) / CGFloat(fly.width)
            ctx.draw(Image(decorative: fly, scale: 1), in: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
        }
    }

    static func drawPhone(_ context: inout GraphicsContext, size: CGSize, turn: Double) {
        var ctx = context
        fit(&ctx, size)
        ctx.fill(Path(ellipseIn: CGRect(x: 45, y: 0, width: 210, height: 210)), with: .color(SnapTheme.moss.opacity(0.55)))
        var g = ctx
        g.translateBy(x: hingeX, y: midY)
        g.rotate(by: .degrees(-90 * (1 - min(max(turn.isFinite ? turn : 1, 0), 1))))
        let shell = Path(roundedRect: CGRect(x: -95, y: -46, width: 190, height: 92), cornerRadius: 22,
                         style: .continuous)
        g.fill(shell, with: .color(SnapTheme.cream.opacity(0.9)))
        let screen = Path(roundedRect: CGRect(x: -90, y: -41, width: 180, height: 82), cornerRadius: 17,
                          style: .continuous)
        g.fill(screen, with: .linearGradient(Gradient(colors: [SnapTheme.pink, SnapTheme.crimson, SnapTheme.pink]),
                                             startPoint: CGPoint(x: -90, y: 0), endPoint: CGPoint(x: 90, y: 0)))
    }
}

// MARK: - The cover display

/// The cover display (466 × 678) and the shut Duo (R8: closed phone = closed trap). Mid-run, after the bite at the
/// shut: the CHOMP card (`ChompCard`). Off a run, or a run shut without a bite: the closed trap at rest and "Open to
/// play" (or, once a run has ended, "Open to see how you did").
struct CoverCard: View {
    @ObservedObject var controller: GameController
    @ObservedObject var store: ProgressStore
    var insets: EdgeInsets = EdgeInsets()

    /// One line for "open to carry on" everywhere.
    static let carryOn = ChompWords.carryOn

    static func title(midRun: Bool) -> String { midRun ? ChompWords.carryOn : ChompWords.openToPlay }
    static func detail(midRun: Bool) -> String {
        midRun ? "Your trap is shut tight." : "Bugs are gathering in the bog."
    }
    /// R8 (founder rule 3): a round starts closed; shut before its first bite, the cover says how it begins.
    static let openToStart = "Open to start"
    static let startDetail = "The bugs are coming."
    /// R6 (#12): the run's score, big ("1,174"), with "score so far" under it. Pure; tested.
    static func scoreLine(_ score: Int) -> String { AppRules.formatted(max(score, 0)) }
    static let scoreCaption = AppRules.scoreWord + " so far"
    /// Off a run: "Best score 3,200".
    static func bestLine(_ best: Int) -> String { "Best " + AppRules.scoreWord + " " + AppRules.formatted(max(best, 0)) }

    var body: some View {
        if controller.isLiveRun, let chomp = controller.coverChomp {
            ChompCard(chomp: chomp, levelGoal: controller.levelGoalLine, insets: insets,
                      reduceMotion: controller.reduceMotion, variety: controller.trapVariety)
                .id("chomp")
        } else {
            rest
        }
    }

    /// The closed trap at rest, and what opening it does.
    private var rest: some View {
        let midRun = controller.isLiveRun
        let ended = controller.route == .results ? controller.summary : nil
        return GeometryReader { geo in
            let l = CoverLayout.make(size: geo.size, insets: insets, midRun: false, hasBest: true)
            ZStack {
                CoverBackdrop(kind: nil, size: geo.size)
                if l.sideBySide {
                    HStack(spacing: CoverLayout.gap) {
                        ChompArt(caught: [], kind: .catchBite, resting: true)
                            .frame(width: l.trap.width, height: l.trap.height)
                        restWords(l, midRun: midRun, ended: ended)
                    }
                    .position(x: l.area.midX, y: l.area.midY)
                } else {
                    VStack(spacing: l.spacing) {
                        ChompArt(caught: [], kind: .catchBite, resting: true)
                            .frame(width: l.trap.width, height: l.trap.height)
                        restWords(l, midRun: midRun, ended: ended)
                    }
                    .position(x: l.area.midX, y: l.area.midY)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func restWords(_ l: CoverLayout, midRun: Bool, ended: ResultSummary?) -> some View {
        VStack(spacing: l.spacing * 0.6) {
            if let ended {
                if let lv = ended.level {
                    DisplayText(text: LevelWords.levelName(lv.id), size: l.titleSize)
                    StarRow(earned: lv.stars, size: l.titleSize * 0.8, spacing: 6)
                } else {
                    DisplayText(text: AppRules.formatted(max(ended.result.score, 0)), size: l.titleSize * 1.2,
                                fill: [SnapTheme.goldLight, SnapTheme.gold])
                    Text(ended.title)
                        .font(CoverLayout.swiftFont(l.bodySize, .bold))
                        .foregroundStyle(SnapTheme.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                OpenCue(text: ChompWords.openForResults, size: l.bodySize)
            } else {
                DisplayText(text: AppBrand.name, size: l.titleSize)
                Text(controller.awaitingFirstBite ? Self.startDetail : Self.detail(midRun: midRun))
                    .font(CoverLayout.swiftFont(l.bodySize, .semibold))
                    .foregroundStyle(SnapTheme.mist)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if midRun {
                    Text(Self.scoreLine(controller.hud.values.score) + " " + Self.scoreCaption)
                        .font(CoverLayout.swiftFont(l.bodySize + 2, .bold).monospacedDigit())
                        .foregroundStyle(SnapTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else if let next = controller.nextLevelLine {
                    Text(next)
                        .font(CoverLayout.swiftFont(l.bodySize + 2, .bold))
                        .foregroundStyle(SnapTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else if store.data.bestFeed > 0 {
                    Text(Self.bestLine(store.data.bestFeed))
                        .font(CoverLayout.swiftFont(l.bodySize + 2, .bold))
                        .foregroundStyle(SnapTheme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                OpenCue(text: controller.awaitingFirstBite ? Self.openToStart : Self.title(midRun: midRun),
                        size: l.bodySize)
            }
        }
        .frame(width: l.textWidth)
    }
}

/// The cover cards' sizes (R4, REVIEW-3 #4; R8: the CHOMP card's): everything fits the canvas, from a phone in
/// landscape (874 × 402) to the Duo's cover display (466 × 678), with the type measured as it is set. A wide canvas
/// puts the trap beside the words. `midRun`: the CHOMP card (its headline, the bite, the note, a goal line, the open
/// cue and the score); else the card at rest (the name, a line, the best, the open cue). Pure; tested.
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
    /// R8: the CHOMP headline over the title size.
    static let headlineScale: CGFloat = 1.5
    /// The closed trap's height over its width (`ChompArt.box`).
    static var trapAspect: CGFloat { ChompArt.box.height / ChompArt.box.width }
    static let trapMaxW: CGFloat = 420
    /// The smallest trap worth drawing before the type steps down a size.
    static let trapMinH: CGFloat = 90

    enum Weight { case black, heavy, bold, semibold }

    static func swiftFont(_ size: CGFloat, _ w: Weight) -> Font {
        switch w {
        case .black: return .system(size: size, weight: .black, design: .rounded)
        case .heavy: return .system(size: size, weight: .heavy, design: .rounded)
        case .bold: return .system(size: size, weight: .bold, design: .rounded)
        case .semibold: return .system(size: size, weight: .semibold, design: .rounded)
        }
    }

    static func font(_ size: CGFloat, _ w: Weight) -> UIFont {
        let weight: UIFont.Weight
        switch w {
        case .black: weight = .black
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

    /// One line's height at `size` (the cards set every line on one line, scaling down to fit).
    static func line(_ size: CGFloat, _ w: Weight) -> CGFloat { font(size, w).lineHeight.rounded(.up) }

    /// A display line's height (`DisplayText`: the letters, their ink and the lip under them).
    static func displayLine(_ size: CGFloat) -> CGFloat {
        line(size, .black) + DisplayText.inkWidth(size) * 2 + max((size * 0.075).rounded(), 3)
    }

    /// The open cue's height (`OpenCue`: its line and padding).
    static func cueHeight(_ size: CGFloat) -> CGFloat { line(size, .heavy) + 16 + 3 }

    /// R6 (#12, duo-04: the card sat off-centre with an empty half): the insets are applied evenly on both sides (a
    /// stale inset from the inner display moved the whole card), portrait ignores side insets (none of the cover's
    /// edges has one), and the content is centred in the screen itself.
    static func evenInsets(_ insets: EdgeInsets, size: CGSize) -> (h: CGFloat, top: CGFloat, bottom: CGFloat) {
        let portrait = size.height > size.width
        let h = portrait ? 0 : max(max(insets.leading, 0), max(insets.trailing, 0))
        let v = max(max(insets.top, 0), max(insets.bottom, 0))
        return (h, v, v)
    }

    /// The words' height at a size tier.
    static func wordsHeight(midRun: Bool, hasBest: Bool, titleSize: CGFloat, bodySize: CGFloat,
                            spacing: CGFloat, width: CGFloat) -> CGFloat {
        let gap = spacing * 0.6
        if midRun {
            // CHOMP!, "4 bugs · +360", "Fast close", the level's goal, the open cue, the score.
            return displayLine(titleSize * headlineScale) + gap + line(bodySize + 6, .heavy) + gap
                + line(bodySize, .bold) + gap + line(bodySize - 2, .semibold) + gap + spacing * 0.4
                + cueHeight(bodySize) + gap + line(bodySize - 3, .bold)
        }
        // The name (or the result), a line (two at most), the best (or the stars), the open cue.
        var h = displayLine(titleSize * 1.2) + gap
        h += min(height(CoverCard.detail(midRun: false), font(bodySize, .semibold), width: width),
                 line(bodySize, .semibold) * 2)
        if hasBest { h += gap + max(line(bodySize + 2, .bold), titleSize * 0.8) }
        return h + gap + cueHeight(bodySize)
    }

    static func make(size: CGSize, insets: EdgeInsets, midRun: Bool, hasBest: Bool) -> CoverLayout {
        let even = evenInsets(insets, size: size)
        let x0 = even.h + margin
        let y0 = even.top + margin
        let x1 = size.width - even.h - margin
        let y1 = size.height - even.bottom - margin
        let area = CGRect(x: x0, y: y0, width: max(x1 - x0, 1), height: max(y1 - y0, 1))
        let side = area.width > area.height * 1.15
        var last: CoverLayout?
        // R6 (#12): filled: the largest type that fits, then a size down, then the smallest.
        for tier in 0..<3 {
            let titleSize: CGFloat = [36, 30, 22][tier]
            let bodySize: CGFloat = [20, 17, 15][tier]
            let scoreSize: CGFloat = [48, 38, 28][tier]
            let spacing: CGFloat = [18, 14, 8][tier]
            let textW = side ? min((area.width - gap) / 2, 400) : min(area.width, 420)
            let text = wordsHeight(midRun: midRun, hasBest: hasBest, titleSize: titleSize, bodySize: bodySize,
                                   spacing: spacing, width: textW)
            var trapW: CGFloat
            if side {
                trapW = min((area.width - gap) / 2, trapMaxW, area.height / trapAspect)
            } else {
                trapW = min(area.width * 0.92, trapMaxW, max(area.height - text - spacing * 2, 0) / trapAspect)
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
