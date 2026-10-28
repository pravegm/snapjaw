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

// MARK: - The trap's outline (R3, REVIEW-2 #4: the HUD clears the cilia, not just the face)

extension AppCanvas {
    /// The green back's reach beyond the trap zone's edge (scene points). Scene R2's `TrapArt.exteriorWidth`, kept as
    /// the App's own conservative constant: a thinner R3 back only adds room.
    static let leafBack: CGFloat = 26
    /// The HUD's glyphs and text stay at least this far from the cilia and the green back (REVIEW-2-duo P0 4).
    static let ciliaClear: CGFloat = 8
    /// The layout keeps this much (over `ciliaClear`): the outline is sampled every ≤ 3.5 pt and the cilia have width.
    static let ciliaPad: CGFloat = 11

    /// Screen points along the open trap's outer outline: the green back's edge and every cilium from root to tip,
    /// curl included. The cilia come from the Scene's own `TrapArt.teeth`, so longer cilia move the HUD with them.
    /// Pure; tested.
    func trapOutline() -> [CGPoint] {
        let g = layout.geometry
        var pts: [CGPoint] = []
        pts.reserveCapacity(14_000)
        // R6: B52's lobes are drawn wider about the midrib (`TrapLook.spread`).
        let spread = max(TrapVariety.allCases.map { TrapArt.look($0).spread }.max() ?? 1, 1)
        let rx = g.a * spread + Self.leafBack
        let ry = g.b + Self.leafBack
        let n = 720
        for i in 0..<n {
            let t = CGFloat(i) / CGFloat(n) * 2 * CGFloat.pi
            pts.append(screenPoint(CGPoint(x: g.center.x + rx * cos(t), y: g.center.y + ry * sin(t))))
        }
        let steps = 20
        // R6: every variety's cilia (B52's are longer and its lobes wider), so the HUD sits in the same place
        // whichever trap the Garden picked.
        for side in [-1, 1] {
            for tooth in TrapVariety.allCases.flatMap({ TrapArt.teeth(side: side, geometry: g, variety: $0) }) {
                let dx = cos(tooth.angle)
                let dy = sin(tooth.angle)
                // The tooth's own x axis once placed (`TrapArt.toothTransform` rotates by angle − π/2).
                let sx = sin(tooth.angle)
                let sy = -cos(tooth.angle)
                let length = tooth.length
                for k in 0...steps {
                    let f = CGFloat(k) / CGFloat(steps)
                    let bend = tooth.curl * length * 0.12 * f * f
                    let p = CGPoint(x: tooth.root.x + dx * length * f + sx * bend,
                                    y: tooth.root.y + dy * length * f + sy * bend)
                    pts.append(screenPoint(p))
                }
            }
        }
        return pts
    }

    /// The outermost outline x among `points` whose y is in y0…y1 (right: the largest x; left: the smallest). Nil: no
    /// point in the band. Pure; tested.
    static func outlineReach(_ points: [CGPoint], y0: CGFloat, y1: CGFloat, right: Bool) -> CGFloat? {
        let lo = min(y0, y1)
        let hi = max(y0, y1)
        var best: CGFloat?
        for p in points where p.y >= lo && p.y <= hi {
            if let b = best {
                best = right ? max(b, p.x) : min(b, p.x)
            } else {
                best = p.x
            }
        }
        return best
    }

    /// The distance from `rect` to the nearest of `points` (0 when one is inside it). Pure; tested.
    static func clearance(_ rect: CGRect, from points: [CGPoint]) -> CGFloat {
        var best = CGFloat.infinity
        for p in points {
            let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
            let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
            best = min(best, (dx * dx + dy * dy).squareRoot())
        }
        return best
    }
}

// MARK: - The play HUD

/// Where the HUD goes (screen points). R3 (REVIEW-2 #4): every glyph and line of text sits ≥ 8 pt off the cilia tips
/// (the trap's real outline, `AppCanvas.trapOutline`), so on a Duo the HUD lives in the two outer corners of the HUD
/// page, the only room the open trap leaves:
/// - the top corner: the score (the widest spot), the pause button under it;
/// - the bottom corner: the snaps in two rows of seven (`Tuning.maxSnaps` 14), the numeral on the inner side of the
///   lower row, and the chain chip above them ("×2" alone when "Chain ×2" doesn't fit);
/// - the hint on the HUD page's inner top, ≥ 24 pt off the crease and off the thumbs (REVIEW-2-duo P1 6); while the
///   lesson card holds the top, at the inner bottom;
/// - "Your trap is tired." centred on the HUD page, never on the crease.
/// Mirrored with "HUD on the left". Pure; tested (fold-clear, cilia-clear at 951 × 669 on both sides, ≥ 56 pt pause).
struct HUDLayout: Equatable {
    var pause: CGRect
    /// The menus' back button: the top outer corner (Bug Book, Settings, the Daily).
    var back: CGRect
    var score: CGRect
    var chain: CGRect
    /// The chain chip shows the multiplier alone: too little room off the cilia for "Chain ×2".
    var chainCompact: Bool
    /// Everything the snaps take (the glyph rows and the numeral).
    var snaps: CGRect
    /// The glyph rows, top first. The lower one also holds the numeral, on its inner side.
    var snapRowRects: [CGRect]
    var numeral: CGRect
    /// R5 (REVIEW-4 #13): the numeral's type size (it was 15/17 pt beside a 32/40 pt score).
    var numeralSize: CGFloat
    /// R6 (#14): the numeral stands above the rows with "SNAPS" under it. False: there was no room off the cilia, so
    /// it sits on the lower row's inner side as in R5 (no caption).
    var numeralLabeled = false
    /// R7 (#13, SCORE-R6: no SNAPS label on the 6.3" or the Duo): where R5's numeral sits on the row, "SNAPS" goes here
    /// (over the numeral at the upper row's height when that clears the cilia, else over the rows at the outer edge,
    /// the chain chip moved up for it). Nil with the labelled block (its caption is under the digits).
    var snapsLabel: CGRect?
    /// The glyph's width (its height is `glyphAspect` of that).
    var glyph: CGFloat
    var hint: CGRect
    /// The hint while the lesson card holds the top (the inner bottom).
    var lessonHint: CGRect
    var lesson: CGRect
    var card: CGRect
    var tired: CGRect
    var snapRows: Int
    /// The HUD hugs the right edge (false: the left edge, "HUD on the left").
    var trailing: Bool

    static let pauseSide: CGFloat = 56
    /// The snaps: rows of seven mini closed traps (REVIEW-2 #11, #23).
    static let snapColumns = 7
    static let snapGap: CGFloat = 3
    static let snapRowGap: CGFloat = 5
    /// Height over width: the Scene's snap glyph is drawn 30 × 22 (`TrapArt.snapGlyph`).
    static let glyphAspect: CGFloat = 22.0 / 30.0
    /// R4 (Scene R4 #15): 24 pt on the Duo draws the full mini closed trap (smaller ones are the simple pod). R7 (#13,
    /// SCORE-R6 D9: "its snaps row is tiny (D01–D10)"): 28 pt (it still shrinks where a row would touch the cilia).
    static let glyphDuo: CGFloat = 28
    static let glyphPhone: CGFloat = 16
    /// Glyphs shrink towards this when a row would touch the cilia.
    static let glyphMin: CGFloat = 12
    /// The numeral's box (fixed: "14" never clips). R5 (REVIEW-4 #13): wider and taller for the bigger numeral. R6
    /// (#14, SCORE-R5 D2 #2: "label the snaps like the score"): a bigger numeral with "SNAPS" under it, in the outer
    /// corner just above the rows (the score's mirror), so the rows keep their full glyphs.
    static let snapNumeralW: CGFloat = 52
    static let snapNumeralWPhone: CGFloat = 44
    static let numeralDuo: CGFloat = 30
    static let numeralPhone: CGFloat = 24
    /// R5's numeral (the fallback on the lower row): its box and type size.
    static let snapNumeralWRow: CGFloat = 36
    static let numeralRowDuo: CGFloat = 24
    static let numeralRowPhone: CGFloat = 20
    /// The "SNAPS" caption under it (the score's caption size).
    static let numeralLabelDuo: CGFloat = 12
    static let numeralLabelPhone: CGFloat = 11
    static let numeralLabel = "SNAPS"
    /// R7 (#13): the row layout's "SNAPS" caption (its box is `rowLabelHeight` tall, `rowLabelWidth` wide).
    static let rowLabelSize: CGFloat = 10
    static let rowLabelHeight: CGFloat = 12
    static let rowLabelWidth: CGFloat = 40
    /// R5's numeral box height (a row's glyph plus a little): the block is never shorter.
    static func numeralHeight(glyph g: CGFloat) -> CGFloat { g * glyphAspect + 3 }
    /// R6: the numeral block's height (the digits, then the caption).
    static func numeralBlockHeight(compact: Bool) -> CGFloat {
        compact ? numeralPhone * 1.05 + numeralLabelPhone + 1 : numeralDuo * 1.05 + numeralLabelDuo + 1
    }
    /// The trap's face ends at radius 1.
    static let clearRadius: CGFloat = 1.0
    /// The hint plate: three short lines at most. Never narrower than `hintMin`.
    static let hintMin: CGFloat = 150
    static let hintDuo: CGFloat = 250
    static let hintPhone: CGFloat = 200
    static let hintHeightDuo: CGFloat = 100
    static let hintHeightPhone: CGFloat = 84
    /// "Chain ×4.5" and "×4.5" chips.
    static let chainFullDuo: CGFloat = 136
    static let chainFullPhone: CGFloat = 118
    static let chainShortDuo: CGFloat = 84
    static let chainShortPhone: CGFloat = 72

    /// The glyphs the row shows: every snap the trap can hold (`Tuning.maxSnaps`), at most two rows.
    static var slotCount: Int { min(max(Tuning.maxSnaps, 1), snapColumns * 2) }

    /// The width of a row of `snapColumns` glyphs.
    static func rowsWidth(glyph g: CGFloat) -> CGFloat {
        CGFloat(snapColumns) * g + CGFloat(snapColumns - 1) * snapGap
    }

    static func make(_ c: AppCanvas) -> HUDLayout {
        let page = c.hudPage
        let right = !c.hudOnLeft
        let compact = c.isCompact
        let fold = c.hasFold
        let outline = c.trapOutline()
        let pad = AppCanvas.ciliaPad
        let outer = right ? page.maxX : page.minX
        // Glyphs and text may sit nearer the screen's edge than a button (there's nothing to tap).
        let textOuter = right ? c.size.width - max(c.insets.trailing, 0) - (fold ? 14 : 8)
                              : max(c.insets.leading, 0) + (fold ? 14 : 8)
        func box(_ edge: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: right ? edge - w : edge, y: y, width: w, height: h)
        }
        /// The width from `edge` inward before the outline (plus the pad) over the band y…y+h; never into the crease.
        func room(_ edge: CGFloat, _ y: CGFloat, _ h: CGFloat) -> CGFloat {
            let cap = right ? edge - page.minX : page.maxX - edge
            guard let reach = AppCanvas.outlineReach(outline, y0: y - pad, y1: y + h + pad, right: right) else {
                return max(cap, 0)
            }
            let w = right ? edge - (reach + pad) : (reach - pad) - edge
            return min(max(w, 0), max(cap, 0))
        }

        let back = CGRect(x: right ? outer - pauseSide : outer, y: c.top - 6, width: pauseSide, height: pauseSide)
        // The score: the top outer corner, the widest spot off the cilia. The pause button goes under it.
        let topY = max(c.insets.top, 0) + (fold ? 6 : 4)
        let scoreH: CGFloat = compact ? 51 : 62
        let scoreMax: CGFloat = compact ? 160 : 190
        let scoreW = max(min(room(textOuter, topY, scoreH), scoreMax), 90)
        let score = box(textOuter, topY, scoreW, scoreH)
        let pause = CGRect(x: right ? outer - pauseSide : outer, y: score.maxY + 4, width: pauseSide,
                           height: pauseSide)

        // The snaps: rows of seven in the bottom outer corner, the numeral on the lower row's inner side. The glyphs
        // shrink (rarely) until every row clears the cilia.
        let rows = max((slotCount + snapColumns - 1) / snapColumns, 1)
        let bottomY = c.size.height - max(c.insets.bottom, 0) - (fold ? 10 : 4)
        /// `numeralOnRow`: R5's lower row also holds the numeral, on its inner side.
        func rowRects(_ g: CGFloat, numeralOnRow: Bool) -> [CGRect] {
            let gh = g * glyphAspect
            var out: [CGRect] = []
            for r in 0..<rows {
                let fromBottom = CGFloat(rows - 1 - r)
                let y = bottomY - gh - fromBottom * (gh + snapRowGap)
                let w = rowsWidth(glyph: g) + (numeralOnRow && r == rows - 1 ? snapNumeralWRow + 4 : 0)
                out.append(box(textOuter, y, w, gh))
            }
            return out
        }
        /// The glyph size (shrunk only if a row would touch the cilia) and its rows.
        func fitRows(numeralOnRow: Bool) -> (glyph: CGFloat, rects: [CGRect]) {
            var g: CGFloat = compact ? glyphPhone : glyphDuo
            var rs = rowRects(g, numeralOnRow: numeralOnRow)
            while g > glyphMin && rs.contains(where: { room(textOuter, $0.minY, $0.height) < $0.width }) {
                g -= 1
                rs = rowRects(g, numeralOnRow: numeralOnRow)
            }
            return (g, rs)
        }
        let chainH: CGFloat = compact ? 28 : 32
        let fullW = compact ? chainFullPhone : chainFullDuo
        let shortW = compact ? chainShortPhone : chainShortDuo
        /// The chain chip in the first of `spots` (edge, top) with room off the cilia: "Chain ×2" if any has room
        /// for it, else "×2"; nil when none has room even for that.
        func chainSpot(_ spots: [(CGFloat, CGFloat)]) -> (rect: CGRect, compact: Bool)? {
            for (edge, top) in spots where room(edge, top, chainH) >= fullW {
                return (box(edge, top, fullW, chainH), false)
            }
            for (edge, top) in spots where room(edge, top, chainH) >= shortW {
                return (box(edge, top, shortW, chainH), true)
            }
            return nil
        }

        // R6 (#14): the numeral with "SNAPS" under it in the outer corner just above the rows, the chain chip beside
        // it (or above it). Only where all of it clears the cilia; else R5's layout (the numeral on the lower row).
        let six = fitRows(numeralOnRow: false)
        let blockW = compact ? snapNumeralWPhone : snapNumeralW
        let blockH = max(numeralBlockHeight(compact: compact), numeralHeight(glyph: six.glyph))
        let sixTop = six.rects.first?.minY ?? bottomY
        let block = box(textOuter, sixTop - 3 - blockH, blockW, blockH)
        let blockFits = room(textOuter, block.minY, block.height) >= blockW
        let spots: [(CGFloat, CGFloat)] = [(right ? block.minX - 8 : block.maxX + 8, block.midY - chainH / 2),
                                           (textOuter, block.minY - 6 - chainH)]
        let sixChain = blockFits ? chainSpot(spots) : nil

        let glyph: CGFloat
        let rects: [CGRect]
        let numeral: CGRect
        let chain: CGRect
        let chainCompact: Bool
        let numeralSize: CGFloat
        let labeled: Bool
        var rowLabel: CGRect?
        if let sixChain {
            glyph = six.glyph
            rects = six.rects
            numeral = block
            chain = sixChain.rect
            chainCompact = sixChain.compact
            numeralSize = compact ? numeralPhone : numeralDuo
            labeled = true
        } else {
            let five = fitRows(numeralOnRow: true)
            glyph = five.glyph
            rects = five.rects
            let row = five.rects.last ?? box(textOuter, bottomY - 14, 200, 14)
            let nh = numeralHeight(glyph: five.glyph)
            numeral = CGRect(x: right ? row.minX : row.maxX - snapNumeralWRow, y: min(row.midY - nh / 2, bottomY - nh),
                             width: snapNumeralWRow, height: nh)
            let topRow = five.rects.first ?? row
            var chainY = topRow.minY - 8 - chainH
            // R7 (#13): "SNAPS" over the numeral, at the upper row's height (the upper row is shorter: the numeral
            // has no glyphs above it), where that clears the cilia; else over the rows at the outer edge, with the
            // chain chip moved up for it, if the chip still has room there; else over the numeral all the same.
            let lh = rowLabelHeight
            let overNumeral = CGRect(x: right ? numeral.maxX - rowLabelWidth : numeral.minX,
                                     y: topRow.maxY - lh, width: rowLabelWidth, height: lh)
            let reachNeeded = right ? textOuter - overNumeral.minX : overNumeral.maxX - textOuter
            let overRows = box(textOuter, topRow.minY - 3 - lh, rowLabelWidth, lh)
            let movedChainY = overRows.minY - 6 - chainH
            if room(textOuter, overNumeral.minY, overNumeral.height) >= reachNeeded {
                rowLabel = overNumeral
            } else if room(textOuter, movedChainY, chainH) >= min(room(textOuter, chainY, chainH), fullW)
                        && room(textOuter, movedChainY, chainH) >= shortW {
                rowLabel = overRows
                chainY = movedChainY
            } else {
                rowLabel = overNumeral
            }
            chainCompact = room(textOuter, chainY, chainH) < fullW
            chain = box(textOuter, chainY, chainCompact ? shortW : fullW, chainH)
            numeralSize = compact ? numeralRowPhone : numeralRowDuo
            labeled = false
        }
        let lower = rects.last ?? box(textOuter, bottomY - 14, 200, 14)
        var snaps = rects.reduce(numeral) { $0.union($1) }
        if let r = rowLabel { snaps = snaps.union(r) }

        // The hint: the inner top of the HUD page (off the thumbs, the crease and the score).
        let hintH = compact ? hintHeightPhone : hintHeightDuo
        let beside = right ? score.minX - 8 - page.minX : page.maxX - (score.maxX + 8)
        let hintW = max(min(compact ? hintPhone : hintDuo, beside, page.width), hintMin)
        let hint = CGRect(x: right ? page.minX : page.maxX - hintW, y: c.top, width: hintW, height: hintH)
        // The lesson card holds the top: its hint goes to the inner bottom, clear of the snaps.
        let besideSnaps = right ? lower.minX - 8 - page.minX : page.maxX - (lower.maxX + 8)
        let lessonHintW = max(min(hintW, besideSnaps), hintMin)
        let lessonHint = CGRect(x: right ? page.minX : page.maxX - lessonHintW, y: bottomY - hintH,
                                width: lessonHintW, height: hintH)

        let lessonW = max(page.width - pauseSide - 10, 160)
        let lesson = CGRect(x: right ? page.minX : page.maxX - lessonW, y: c.top - 4, width: lessonW,
                            height: compact ? 128 : 150)
        let cardW = min(page.width, 380)
        let card = CGRect(x: page.midX - cardW / 2, y: c.top, width: cardW, height: max(c.bottom - c.top, 0))
        let tiredW = min(page.width, compact ? 300 : 360)
        let tiredH: CGFloat = compact ? 76 : 90
        let tired = CGRect(x: page.midX - tiredW / 2, y: c.size.height / 2 - tiredH / 2, width: tiredW, height: tiredH)
        return HUDLayout(pause: pause, back: back, score: score, chain: chain, chainCompact: chainCompact, snaps: snaps,
                         snapRowRects: rects, numeral: numeral, numeralSize: numeralSize, numeralLabeled: labeled,
                         snapsLabel: rowLabel, glyph: glyph, hint: hint, lessonHint: lessonHint,
                         lesson: lesson, card: card, tired: tired, snapRows: rows, trailing: right)
    }

    /// The centre (screen) of glyph `i` (reading order: the top row first, left to right). Pure; tested.
    func glyphCenter(_ i: Int) -> CGPoint {
        guard !snapRowRects.isEmpty else { return CGPoint(x: snaps.midX, y: snaps.midY) }
        let k = max(i, 0)
        let r = min(k / Self.snapColumns, snapRowRects.count - 1)
        let col = min(k - r * Self.snapColumns, Self.snapColumns - 1)
        let rect = snapRowRects[r]
        let x0 = trailing ? rect.maxX - Self.rowsWidth(glyph: glyph) : rect.minX
        return CGPoint(x: x0 + CGFloat(col) * (glyph + Self.snapGap) + glyph / 2, y: rect.midY)
    }

    /// The Scene's economy anchor (`BogScene.hudSnapsAnchor`: Feast glyph flights, the sting crack, the wilt droop).
    /// R4 (QA-2 #6): the glyph that changes, the last full one (`snapsLeft − 1`; the first slot when none is left);
    /// the row flash now covers `hudSnapsRowRect`. Pure; tested.
    func anchor(snapsLeft: Int) -> CGPoint {
        glyphCenter(max(snapsLeft - 1, 0))
    }

    /// R4 (REVIEW-3 #3): where the hint plate goes this frame: its own slot (the inner top), else the other one (the
    /// inner bottom) when a live pop is under it, else nowhere until the pop has gone (a plate never covers a pop).
    /// `low`: the plate sits in the lower slot. Pure; tested.
    /// R6 (#6, frame 43: the plate sat on the trap's flies): `subjects` are the bugs on the trap; a slot that covers
    /// none is preferred (the plate's own slot first), else the one covering fewer. Pops are never covered.
    /// R7 (#5, frame 43: the hint sat on bugs): `strict` (a toast, which can wait): nil unless a slot covers no
    /// subject at all.
    static func hintSlot(primary: CGRect, alternate: CGRect, pops: [CGRect],
                         subjects: [CGRect] = [], strict: Bool = false) -> (rect: CGRect, low: Bool)? {
        let open = [(primary, false), (alternate, true)].filter { slot in
            !pops.contains(where: { $0.intersects(slot.0) })
        }
        guard !open.isEmpty else { return nil }
        func covered(_ r: CGRect) -> Int { subjects.filter { $0.intersects(r) }.count }
        var best = open[0]
        for slot in open.dropFirst() where covered(slot.0) < covered(best.0) { best = slot }
        if strict && covered(best.0) > 0 { return nil }
        return (best.0, best.1)
    }

    /// Every rect the play HUD draws text or glyphs in (the fold-clear test).
    var textRects: [CGRect] { [score, chain, hint, tired, numeral] + snapRowRects + (snapsLabel.map { [$0] } ?? []) }
    /// What must clear the cilia by `AppCanvas.ciliaClear` (REVIEW-2-duo P0 4).
    var ciliaRects: [CGRect] { [score, chain, numeral] + snapRowRects }
}
