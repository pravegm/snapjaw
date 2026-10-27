import CoreGraphics
import SwiftUI

// MARK: - The canvas as SwiftUI sees it

/// The play canvas in SwiftUI points (origin top-left), with the scene (952 × 670 design canvas, wider on long
/// phones) mapped onto it aspect-filled, like the SpriteView. Every screen lays its controls out on the two pages either
/// side of the fold; the HUD and the main buttons live on the HUD page (the right, sharp half by default).
struct AppCanvas: Equatable {
    var size: CGSize
    var insets: EdgeInsets
    var layout: ScreenLayout

    /// The smallest tap target anywhere (arm's length on a Duo held in two hands).
    static let minTap: CGFloat = 56

    init(size: CGSize, insets: EdgeInsets, layout: ScreenLayout) {
        self.size = size
        self.insets = insets
        self.layout = layout
    }

    /// Margins: 28 pt from the Duo's outer edges and 24 pt from the fold band; 18 pt (plus the safe area) and 14 pt on
    /// other iPhones.
    var edgeMargin: CGFloat { hasFold ? 28 : 18 }
    var foldClear: CGFloat { hasFold ? 24 : 14 }
    var hasFold: Bool { layout.hasFold }
    var hudOnLeft: Bool { layout.hudOnLeft }
    /// iPhone-sized type: the Duo's 669 pt height gets the larger scale.
    var isCompact: Bool { size.height < 520 }

    /// The scene → screen scale (aspect fill).
    var scale: CGFloat {
        guard layout.size.width > 0, layout.size.height > 0 else { return 1 }
        return max(size.width / layout.size.width, size.height / layout.size.height)
    }

    /// Screen x of a scene x.
    func screenX(_ sceneX: CGFloat) -> CGFloat {
        (size.width - layout.size.width * scale) / 2 + sceneX * scale
    }

    /// Screen point (SwiftUI, y down) of a scene point (SpriteKit, y up). Pure; tested.
    func screenPoint(_ scene: CGPoint) -> CGPoint {
        let s = scale
        let oy = (size.height - layout.size.height * s) / 2
        return CGPoint(x: screenX(scene.x), y: oy + (layout.size.height - scene.y) * s)
    }

    /// Screen rect of a scene rect.
    func screenRect(_ scene: CGRect) -> CGRect {
        let a = screenPoint(CGPoint(x: scene.minX, y: scene.maxY))
        let b = screenPoint(CGPoint(x: scene.maxX, y: scene.minY))
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    var foldMinX: CGFloat { screenX(layout.creaseMinX) }
    var foldMaxX: CGFloat { screenX(layout.creaseMaxX) }

    var leftPage: CGRect {
        let x0 = max(insets.leading, 0) + edgeMargin
        let x1 = foldMinX - foldClear
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    var rightPage: CGRect {
        let x0 = foldMaxX + foldClear
        let x1 = size.width - max(insets.trailing, 0) - edgeMargin
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    /// The HUD's page (right by default; "HUD on the left" mirrors it).
    var hudPage: CGRect { hudOnLeft ? leftPage : rightPage }
    /// The other page (the title, the big number).
    var otherPage: CGRect { hudOnLeft ? rightPage : leftPage }

    var top: CGFloat { max(insets.top, 0) + (hasFold ? 18 : 10) }
    var bottom: CGFloat { size.height - max(insets.bottom, 0) - (hasFold ? 18 : 10) }

    /// Nothing tappable may overlap the fold band. Pure; tested.
    func isFoldClear(_ rect: CGRect) -> Bool {
        rect.maxX <= foldMinX + 0.5 || rect.minX >= foldMaxX - 0.5
    }

    /// The trap zone's ellipse on screen.
    var trapRect: CGRect {
        let g = layout.geometry
        return screenRect(CGRect(x: g.center.x - g.a, y: g.center.y - g.b, width: g.a * 2, height: g.b * 2))
    }
}

// MARK: - The play HUD

/// Where the HUD goes (screen points), in the corners of the HUD page, outside the trap ellipse where it can be: the
/// score and the pause button at the top outer corner, the chain chip under the score, the snaps along the bottom
/// outer edge with the hint above them. Mirrored with "HUD on the left". Pure; tested (fold-clear, ≥ 56 pt pause).
struct HUDLayout: Equatable {
    var pause: CGRect
    var score: CGRect
    var chain: CGRect
    var snaps: CGRect
    var hint: CGRect
    var lesson: CGRect
    var card: CGRect
    /// The HUD hugs the right edge (false: the left edge, "HUD on the left").
    var trailing: Bool

    static let pauseSide: CGFloat = 56
    static let snapIcon: CGFloat = 22
    static let snapGap: CGFloat = 4

    static func make(_ c: AppCanvas) -> HUDLayout {
        let page = c.hudPage
        let right = !c.hudOnLeft
        let compact = c.isCompact
        let outer = right ? page.maxX : page.minX
        func span(_ w: CGFloat) -> CGFloat { right ? outer - w : outer }   // x of a box hugging the outer edge

        let pause = CGRect(x: span(pauseSide), y: c.top - 6, width: pauseSide, height: pauseSide)
        let scoreW = min(compact ? 200 : 250, max(page.width - pauseSide - 8, 120))
        let scoreH: CGFloat = compact ? 50 : 62
        let scoreX = right ? pause.minX - 6 - scoreW : pause.maxX + 6
        let score = CGRect(x: scoreX, y: c.top - 4, width: scoreW, height: scoreH)
        let chainW: CGFloat = compact ? 104 : 120
        let chain = CGRect(x: right ? score.maxX - chainW : score.minX, y: score.maxY + 2, width: chainW,
                           height: compact ? 30 : 34)
        let snapsW = min(CGFloat(12) * (snapIcon + snapGap) + 40, page.width)
        let snapsH: CGFloat = 30
        let snaps = CGRect(x: span(snapsW), y: c.bottom - snapsH, width: snapsW, height: snapsH)
        let hintW = min(page.width, compact ? 300 : 360)
        let hintH: CGFloat = compact ? 40 : 46
        let hint = CGRect(x: span(hintW), y: snaps.minY - 8 - hintH, width: hintW, height: hintH)
        let lessonW = max(page.width - pauseSide - 10, 160)
        let lesson = CGRect(x: right ? page.minX : pause.maxX + 10, y: c.top - 4, width: lessonW,
                            height: compact ? 128 : 150)
        let cardW = min(page.width, 380)
        let card = CGRect(x: page.midX - cardW / 2, y: c.top, width: cardW, height: max(c.bottom - c.top, 0))
        return HUDLayout(pause: pause, score: score, chain: chain, snaps: snaps, hint: hint, lesson: lesson,
                         card: card, trailing: right)
    }
}
