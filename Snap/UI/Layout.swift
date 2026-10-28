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

    /// Scene point (SpriteKit, y up) of a screen point (SwiftUI, y down). The inverse of `screenPoint`. Pure; tested.
    func scenePoint(_ screen: CGPoint) -> CGPoint {
        let s = max(scale, 0.0001)
        let ox = (size.width - layout.size.width * s) / 2
        let oy = (size.height - layout.size.height * s) / 2
        return CGPoint(x: (screen.x - ox) / s, y: layout.size.height - (screen.y - oy) / s)
    }

    /// The trap's normalised radius (0 centre … 1 the rim's edge) at a screen point.
    func trapRadius(_ p: CGPoint) -> CGFloat {
        let r = trapRect
        guard r.width > 0, r.height > 0 else { return .infinity }
        let dx = (p.x - r.midX) / (r.width / 2)
        let dy = (p.y - r.midY) / (r.height / 2)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// The smallest trap radius anywhere in `rect` (≥ 1: the rect is off the trap's face). Pure; tested.
    func minTrapRadius(_ rect: CGRect) -> CGFloat {
        let t = trapRect
        // The rect's point nearest the ellipse centre, then a sweep of its edges (the ellipse isn't a circle).
        let nearest = CGPoint(x: min(max(t.midX, rect.minX), rect.maxX), y: min(max(t.midY, rect.minY), rect.maxY))
        var best = trapRadius(nearest)
        let n = 16
        for i in 0...n {
            let f = CGFloat(i) / CGFloat(n)
            let x = rect.minX + rect.width * f
            let y = rect.minY + rect.height * f
            for p in [CGPoint(x: x, y: rect.minY), CGPoint(x: x, y: rect.maxY),
                      CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)] {
                best = min(best, trapRadius(p))
            }
        }
        return best
    }

    /// How far toward the outer edge the trap (grown by `grow`) reaches inside the band `y0…y1`: the screen x past
    /// which (outwards) nothing in that band covers it. Nil: the band misses the trap. Pure; tested.
    func trapReach(y0: CGFloat, y1: CGFloat, right: Bool, grow: CGFloat = 1) -> CGFloat? {
        let t = trapRect
        let a = t.width / 2 * grow
        let b = t.height / 2 * grow
        guard a > 0, b > 0 else { return nil }
        let lo = min(y0, y1)
        let hi = max(y0, y1)
        let dy: CGFloat = lo <= t.midY && t.midY <= hi ? 0 : min(abs(lo - t.midY), abs(hi - t.midY))
        guard dy < b else { return nil }
        let half = a * (1 - (dy / b) * (dy / b)).squareRoot()
        return right ? t.midX + half : t.midX - half
    }

    /// Where the hands rest (no hint plate goes there). On the Duo in book pose the thumbs cover ~0–80 pt in from
    /// each outer edge over the middle 40 % of the height (REVIEW-1-duo); on a phone in landscape they rest on the
    /// lower outer corners.
    var thumbZones: [CGRect] {
        let w = size.width
        let h = size.height
        if hasFold {
            return [CGRect(x: 0, y: h * 0.30, width: 80, height: h * 0.40),
                    CGRect(x: w - 80, y: h * 0.30, width: 80, height: h * 0.40)]
        }
        let reach = 96 + max(insets.leading, insets.trailing)
        return [CGRect(x: 0, y: h * 0.55, width: reach, height: h * 0.45),
                CGRect(x: w - reach, y: h * 0.55, width: reach, height: h * 0.45)]
    }

    func inThumbZone(_ rect: CGRect) -> Bool {
        thumbZones.contains { $0.intersects(rect) }
    }
}

// MARK: - The play HUD

/// Where the HUD goes (screen points), in the outer corners of the HUD page, OFF the trap's face (REVIEW-1 #14):
/// - the pause button in the top outer corner, the score beside it (pulled up, sized for six digits), the chain chip
///   under the pause button;
/// - the snaps row along the bottom outer edge (two rows of six on a short phone when one row would cover the rim);
/// - the hint plate where it has the most room off the trap, the crease and the thumbs (REVIEW-1 #16): under the
///   chain chip, or above the snaps row on the Duo (below the thumbs' band);
/// - "Your trap is tired." centred on the HUD page, never on the crease (REVIEW-1 #11).
/// Mirrored with "HUD on the left". Pure; tested (fold-clear, off the trap at 951 × 669, ≥ 56 pt pause).
struct HUDLayout: Equatable {
    var pause: CGRect
    var score: CGRect
    var chain: CGRect
    var snaps: CGRect
    var hint: CGRect
    /// The hint while the lesson card is up (below the card).
    var lessonHint: CGRect
    var lesson: CGRect
    var card: CGRect
    var tired: CGRect
    /// The snaps row wraps into two rows of six.
    var snapRows: Int
    /// The HUD hugs the right edge (false: the left edge, "HUD on the left").
    var trailing: Bool

    static let pauseSide: CGFloat = 56
    /// Snap glyph sizes: 22 pt up to ten slots, 18 pt for 11–12 (REVIEW-1 #3), 18 pt in two rows.
    static let snapIcon: CGFloat = 22
    static let snapIconSmall: CGFloat = 18
    static let snapGap: CGFloat = 4
    /// The numeral's box (fixed: "12" never clips).
    static let snapNumeralW: CGFloat = 30
    /// The trap's face ends at radius 1 (cilia and the leaf outside it may pass under the HUD).
    static let clearRadius: CGFloat = 1.0
    /// The hint plate is never narrower (two short lines).
    static let hintMin: CGFloat = 96

    static func glyphSize(slots: Int) -> CGFloat { slots > 10 ? snapIconSmall : snapIcon }

    /// The snaps row's width for `slots` glyphs in `rows` rows. Pure; tested.
    static func snapsWidth(slots: Int, rows: Int) -> CGFloat {
        let perRow = rows > 1 ? (slots + 1) / 2 : slots
        let icon = rows > 1 ? snapIconSmall : glyphSize(slots: slots)
        let n = CGFloat(max(perRow, 1))
        return snapNumeralW + 4 + n * icon + (n - 1) * snapGap
    }

    static func snapsHeight(rows: Int) -> CGFloat {
        rows > 1 ? snapIconSmall * 0.82 * 2 + 6 : 30
    }

    static func make(_ c: AppCanvas) -> HUDLayout {
        let page = c.hudPage
        let right = !c.hudOnLeft
        let compact = c.isCompact
        let outer = right ? page.maxX : page.minX
        func span(_ w: CGFloat) -> CGFloat { right ? outer - w : outer }   // x of a box hugging the outer edge
        /// The width from the outer edge to where the trap's face (grown a touch) stops, over a band.
        func room(_ y0: CGFloat, _ y1: CGFloat) -> CGFloat {
            guard let reach = c.trapReach(y0: y0, y1: y1, right: right, grow: 1.02) else { return page.width }
            let w = right ? outer - max(reach, page.minX) : min(reach, page.maxX) - outer
            return min(max(w, 0), page.width)
        }

        let pause = CGRect(x: span(pauseSide), y: c.top - 6, width: pauseSide, height: pauseSide)
        // The score: beside the pause button, pulled up off the rim.
        let scoreH: CGFloat = compact ? 50 : 58
        let scoreY = c.top - 8
        let scoreRoom = room(scoreY, scoreY + scoreH) - pauseSide - 6
        let scoreW = max(min(compact ? 150 : 172, scoreRoom), 110)
        let scoreX = right ? pause.minX - 6 - scoreW : pause.maxX + 6
        let score = CGRect(x: scoreX, y: scoreY, width: scoreW, height: scoreH)
        // The chain chip: under the pause button, hugging the outer edge (sized for "Chain ×4.5").
        let chainW: CGFloat = compact ? 122 : 140
        let chain = CGRect(x: span(chainW), y: pause.maxY + 6, width: chainW, height: compact ? 30 : 34)
        // The snaps row: one row if it clears the trap's face, else two rows of six.
        func snapsRect(rows: Int) -> CGRect {
            let w = min(snapsWidth(slots: 12, rows: rows), page.width)
            let h = snapsHeight(rows: rows)
            return CGRect(x: span(w), y: c.bottom - h, width: w, height: h)
        }
        var rows = 1
        var snaps = snapsRect(rows: 1)
        if c.minTrapRadius(snaps) < clearRadius {
            let two = snapsRect(rows: 2)
            if c.minTrapRadius(two) > c.minTrapRadius(snaps) {
                rows = 2
                snaps = two
            }
        }
        // The hint (up to two short lines): the candidate with the most room off the trap, the crease and the
        // thumbs. Never narrower than `hintMin`.
        let hintH: CGFloat = compact ? 58 : 66
        let hintMax: CGFloat = compact ? 280 : 340
        let underChain = chain.maxY + 8
        let aboveSnaps = snaps.minY - 8 - hintH
        func plate(_ y: CGFloat) -> CGRect {
            let w = max(min(room(y, y + hintH), hintMax), hintMin)
            return CGRect(x: span(w), y: y, width: w, height: hintH)
        }
        let high = plate(underChain)
        let low = plate(aboveSnaps)
        let lowOK = aboveSnaps > underChain + hintH && !c.inThumbZone(low)
        let hint = lowOK && low.width > high.width ? low : high
        let lessonW = max(page.width - pauseSide - 10, 160)
        let lesson = CGRect(x: right ? page.minX : pause.maxX + 10, y: c.top - 4, width: lessonW,
                            height: compact ? 128 : 150)
        // In the lesson the card holds the top: the hint goes low if it can, else under the card.
        let lessonHint = lowOK ? low : plate(max(lesson.maxY, chain.maxY) + 8)
        let cardW = min(page.width, 380)
        let card = CGRect(x: page.midX - cardW / 2, y: c.top, width: cardW, height: max(c.bottom - c.top, 0))
        let tiredW = min(page.width, compact ? 300 : 360)
        let tiredH: CGFloat = compact ? 76 : 90
        let tired = CGRect(x: page.midX - tiredW / 2, y: c.size.height / 2 - tiredH / 2, width: tiredW, height: tiredH)
        return HUDLayout(pause: pause, score: score, chain: chain, snaps: snaps, hint: hint, lessonHint: lessonHint,
                         lesson: lesson, card: card, tired: tired, snapRows: rows, trailing: right)
    }

    /// The centre (screen) of the snaps row's first glyph for `slots` glyphs: the Scene's economy anchor (the row's
    /// leftmost live glyph). Pure; tested.
    func firstGlyphCenter(slots: Int) -> CGPoint {
        let icon = snapRows > 1 ? Self.snapIconSmall : Self.glyphSize(slots: slots)
        let content = min(Self.snapsWidth(slots: slots, rows: snapRows), snaps.width)
        let x0 = trailing ? snaps.maxX - content : snaps.minX
        let y = snapRows > 1 ? snaps.minY + icon * 0.41 : snaps.midY
        return CGPoint(x: x0 + Self.snapNumeralW + 4 + icon / 2, y: y)
    }

    /// Every rect the play HUD draws text or glyphs in (the fold-clear and trap-clear tests).
    var textRects: [CGRect] { [score, chain, snaps, hint, tired] }
}
