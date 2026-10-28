import SwiftUI
import UIKit

// R8 portrait (founder rule: no pose demands, ever; design/notes/portrait-R8.md): the pose card ("Snapjaw plays
// sideways", PoseCard, PoseCardLayout, PoseDiagram, PoseDiagramArt) is gone. A portrait canvas plays: the scene is drawn
// turned a quarter (RootView, AppCanvas.rotated). This file keeps the cover display's cards.

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
