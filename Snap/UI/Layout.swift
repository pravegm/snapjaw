import CoreGraphics
import SwiftUI

// MARK: - The canvas as SwiftUI sees it

/// The play canvas in SwiftUI points (origin top-left), with the scene (952 × 670 design canvas, wider on long
/// phones) mapped onto it aspect-filled, like the SpriteView. Every screen lays its controls out on the two pages either
/// side of the fold; the HUD and the main buttons live on the HUD page (the right, sharp half by default).
///
/// R8 portrait (founder rule: no pose demands; design/notes/portrait-R8.md): a portrait canvas (the Duo held like a
/// laptop, its fold running across) shows the same landscape scene turned a quarter clockwise (`rotated`), so the
/// midrib lies along the fold and the lobes are the top and bottom halves. The pages are then the top page (the
/// scene's left lobe, the other page) and the bottom page (its right lobe, the HUD page); every rect stays upright.
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
    /// iPhone-sized type: the Duo's 669 pt short side gets the larger scale (R8: the short side, so a portrait phone
    /// stays compact).
    var isCompact: Bool { min(size.width, size.height) < 520 }

    /// R8 portrait: the scene is shown turned a quarter clockwise (`AppRules.turnsScene`, `RootView.gameLayer`).
    var rotated: Bool { AppRules.turnsScene(size) }
    /// The scene view's own size before the turn: the canvas, or the canvas turned (portrait).
    var sceneViewSize: CGSize { rotated ? CGSize(width: size.height, height: size.width) : size }

    /// The scene → screen scale (aspect fill).
    var scale: CGFloat {
        guard layout.size.width > 0, layout.size.height > 0 else { return 1 }
        let v = sceneViewSize
        return max(v.width / layout.size.width, v.height / layout.size.height)
    }

    /// Screen x of a scene x (R8 portrait: the screen y, since the scene's x runs down the turned screen).
    func screenX(_ sceneX: CGFloat) -> CGFloat {
        (sceneViewSize.width - layout.size.width * scale) / 2 + sceneX * scale
    }

    /// Screen point (SwiftUI, y down) of a scene point (SpriteKit, y up). Pure; tested. R8 portrait: the scene view
    /// (landscape, `sceneViewSize`) is turned a quarter clockwise about its centre, so its point (x, y) lands on the
    /// canvas at (view height − y, x).
    func screenPoint(_ scene: CGPoint) -> CGPoint {
        let s = scale
        let oy = (sceneViewSize.height - layout.size.height * s) / 2
        let p = CGPoint(x: screenX(scene.x), y: oy + (layout.size.height - scene.y) * s)
        return rotated ? CGPoint(x: sceneViewSize.height - p.y, y: p.x) : p
    }

    /// Screen rect of a scene rect (a quarter turn keeps rects axis-aligned: opposite corners stay opposite).
    func screenRect(_ scene: CGRect) -> CGRect {
        let a = screenPoint(CGPoint(x: scene.minX, y: scene.maxY))
        let b = screenPoint(CGPoint(x: scene.maxX, y: scene.minY))
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    /// R8: the fold band on screen: a column down the middle (landscape) or a row across it (portrait).
    var foldBand: CGRect {
        let a = screenX(layout.creaseMinX)
        let b = screenX(layout.creaseMaxX)
        return rotated ? CGRect(x: 0, y: a, width: size.width, height: max(b - a, 0))
                       : CGRect(x: a, y: 0, width: max(b - a, 0), height: size.height)
    }

    var foldMinX: CGFloat { foldBand.minX }
    var foldMaxX: CGFloat { foldBand.maxX }
    /// R8 portrait: the fold band's top and bottom (landscape: the canvas's).
    var foldMinY: CGFloat { foldBand.minY }
    var foldMaxY: CGFloat { foldBand.maxY }

    /// Landscape: the left page. R8 portrait: the top page (the scene's left lobe), the full width less the margins,
    /// from the top of the screen to the fold.
    var leftPage: CGRect {
        if rotated {
            let x0 = max(insets.leading, 0) + edgeMargin
            let x1 = size.width - max(insets.trailing, 0) - edgeMargin
            return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: max(foldMinY - foldClear, 0))
        }
        let x0 = max(insets.leading, 0) + edgeMargin
        let x1 = foldMinX - foldClear
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    /// Landscape: the right page. R8 portrait: the bottom page (the scene's right lobe), from the fold down.
    var rightPage: CGRect {
        if rotated {
            let x0 = max(insets.leading, 0) + edgeMargin
            let x1 = size.width - max(insets.trailing, 0) - edgeMargin
            let y0 = foldMaxY + foldClear
            return CGRect(x: x0, y: y0, width: max(x1 - x0, 0), height: max(size.height - y0, 0))
        }
        let x0 = foldMaxX + foldClear
        let x1 = size.width - max(insets.trailing, 0) - edgeMargin
        return CGRect(x: x0, y: 0, width: max(x1 - x0, 0), height: size.height)
    }

    /// The HUD's page (right by default; "HUD on the left" mirrors it). R8 portrait: the bottom page (the scene's
    /// right lobe; GameController lays a turned scene out with the HUD on its right).
    var hudPage: CGRect { hudOnLeft && !rotated ? leftPage : rightPage }
    /// The other page (the title, the big number). R8 portrait: the top page.
    var otherPage: CGRect { hudOnLeft && !rotated ? rightPage : leftPage }

    /// R8: the HUD's half of the screen, from the fold to the screen's own edge (no margins: the menus' shade).
    var hudHalf: CGRect {
        if rotated { return CGRect(x: 0, y: foldMaxY, width: size.width, height: max(size.height - foldMaxY, 0)) }
        return hudOnLeft ? CGRect(x: 0, y: 0, width: max(foldMinX, 0), height: size.height)
                         : CGRect(x: foldMaxX, y: 0, width: max(size.width - foldMaxX, 0), height: size.height)
    }

    /// R8: the other half of the screen, edge to fold.
    var otherHalf: CGRect {
        if rotated { return CGRect(x: 0, y: 0, width: size.width, height: max(foldMinY, 0)) }
        return hudOnLeft ? CGRect(x: foldMaxX, y: 0, width: max(size.width - foldMaxX, 0), height: size.height)
                         : CGRect(x: 0, y: 0, width: max(foldMinX, 0), height: size.height)
    }

    /// R8: a gradient's ends from the fold out to the HUD half's own edge (the menus' shade under the actions).
    var towardHUD: (start: UnitPoint, end: UnitPoint) {
        if rotated { return (.top, .bottom) }
        return hudOnLeft ? (.trailing, .leading) : (.leading, .trailing)
    }

    var top: CGFloat { max(insets.top, 0) + (hasFold ? 18 : 10) }
    var bottom: CGFloat { size.height - max(insets.bottom, 0) - (hasFold ? 18 : 10) }

    /// R8: the top padding a column in `page` takes inside its own frame: under the back button when that sits at the
    /// page's top, else `top` (landscape: the HUD page's column starts under the back button, the other at `top`).
    func columnTop(_ page: CGRect, back: CGRect) -> CGFloat {
        let inPage = back.midX >= page.minX - 1 && back.midX <= page.maxX + 1 && back.midY >= page.minY
            && back.midY <= page.maxY
        return inPage ? back.maxY + 10 - page.minY : top
    }

    /// R8: how far a page's header row keeps in from each side for the back button, when it sits in that header
    /// (landscape: the HUD page's top outer corner; portrait: the top page's top-left corner). Pure; tested.
    func headerPads(_ page: CGRect, back: CGRect) -> (leading: CGFloat, trailing: CGFloat) {
        guard back.midX >= page.minX - 1 && back.midX <= page.maxX + 1 && back.midY >= page.minY
                && back.minY < page.minY + 100 else {
            return (0, 0)
        }
        if back.midX > page.midX { return (0, max(page.maxX - back.minX, 0) + 8) }
        return (max(back.maxX - page.minX, 0) + 8, 0)
    }

    /// Nothing tappable may overlap the fold band. Pure; tested.
    func isFoldClear(_ rect: CGRect) -> Bool {
        if rotated { return rect.maxY <= foldMinY + 0.5 || rect.minY >= foldMaxY - 0.5 }
        return rect.maxX <= foldMinX + 0.5 || rect.minX >= foldMaxX - 0.5
    }

    /// The trap zone's ellipse on screen.
    var trapRect: CGRect {
        let g = layout.geometry
        return screenRect(CGRect(x: g.center.x - g.a, y: g.center.y - g.b, width: g.a * 2, height: g.b * 2))
    }

    /// Scene point (SpriteKit, y up) of a screen point (SwiftUI, y down). The inverse of `screenPoint`. Pure; tested.
    func scenePoint(_ screen: CGPoint) -> CGPoint {
        let s = max(scale, 0.0001)
        let v = sceneViewSize
        // R8 portrait: undo the quarter turn first (the canvas point (x, y) is the view's (y, view height − x)).
        let p = rotated ? CGPoint(x: screen.y, y: v.height - screen.x) : screen
        let ox = (v.width - layout.size.width * s) / 2
        let oy = (v.height - layout.size.height * s) / 2
        return CGPoint(x: (p.x - ox) / s, y: layout.size.height - (p.y - oy) / s)
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
    /// lower outer corners. R8 portrait (held like a laptop): the hands hold the bottom half by its sides.
    var thumbZones: [CGRect] {
        let w = size.width
        let h = size.height
        if rotated {
            let low = max(h - foldMaxY, 0)
            return [CGRect(x: 0, y: foldMaxY + low * 0.35, width: 80, height: low * 0.45),
                    CGRect(x: w - 80, y: foldMaxY + low * 0.35, width: 80, height: low * 0.45)]
        }
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
    /// the chain chip moved up for it). Nil with the labelled block (its caption is under the digits). R9: or, where
    /// neither clears the cilia, the numeral over the rows' outer end with "SNAPS" beside or over it (`rowNumeral`).
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
    /// The HUD hugs the right edge (false: the left edge, "HUD on the left"). R8 portrait: the score's side.
    var trailing: Bool
    /// R8 portrait: the side the snaps (rows, numeral, tag) hug; the score's other side (landscape: `trailing`).
    var snapsTrailing: Bool
    /// R8 portrait: the side the chain chip hugs (landscape: `trailing`).
    var chainTrailing: Bool
    /// R8: glyphs per row (landscape: `snapColumns`; portrait: 7 or 5, whichever draws them bigger off the cilia).
    var columns: Int

    static let pauseSide: CGFloat = 56
    /// The snaps: rows of seven mini closed traps (REVIEW-2 #11, #23).
    static let snapColumns = 7
    static let snapGap: CGFloat = 3
    static let snapRowGap: CGFloat = 5
    /// R9: the row gaps tried, in order, when the rows still touch the cilia at `glyphMin`.
    static let snapRowGapTight: [CGFloat] = [3, 2]
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
    /// R9: the height the numeral's digits draw at `size` pt (heavy rounded figures stand ~0.71 em), plus a point.
    /// R5's numeral box is never shorter, so "SNAPS" and the rows are placed off what is drawn (Duo frame
    /// duo-h2-reopened-150: with the glyphs stepped down to 12 pt, a 24 pt "12" in an 11.8 pt box ran into "SNAPS").
    static func numeralInkHeight(size s: CGFloat) -> CGFloat { s * 0.72 + 1 }
    /// R9: the room kept between R5's numeral and "SNAPS" over it, and between "SNAPS" and the chain chip.
    static let rowLabelGap: CGFloat = 2
    static let rowLabelChainGap: CGFloat = 6
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

    /// The width of a row of `columns` glyphs (`snapColumns` by default).
    static func rowsWidth(glyph g: CGFloat, columns n: Int = HUDLayout.snapColumns) -> CGFloat {
        let k = max(n, 1)
        return CGFloat(k) * g + CGFloat(k - 1) * snapGap
    }

    /// R8 portrait: the score's narrowest box (the portrait corners are narrow strips; the number scales to fit).
    static let portraitScoreMin: CGFloat = 64
    /// R8 portrait: the row lengths tried for the snaps (the one drawing the biggest glyphs off the cilia wins).
    static let portraitColumns = [7, 5]

    /// R7: the layout with the biggest glyphs whose every cilia rect (score, chain, numeral, rows, R9: "SNAPS") clears
    /// the cilia by `AppCanvas.ciliaClear`; the glyphs step down to `glyphMin` until it does.
    static func make(_ c: AppCanvas) -> HUDLayout {
        let outline = c.trapOutline()
        var cap: CGFloat = c.isCompact ? glyphPhone : glyphDuo
        while true {
            let l = make(c, outline: outline, glyphCap: cap)
            if cap <= glyphMin
                || l.ciliaRects.allSatisfy({ AppCanvas.clearance($0, from: outline) >= AppCanvas.ciliaClear }) {
                return l
            }
            cap -= 1
        }
    }

    private static func make(_ c: AppCanvas, outline: [CGPoint], glyphCap: CGFloat) -> HUDLayout {
        if c.rotated { return portrait(c, outline: outline, glyphCap: glyphCap) }
        let page = c.hudPage
        let right = !c.hudOnLeft
        let compact = c.isCompact
        let fold = c.hasFold
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
        // R9: under a top inset the box starts at the inset itself (the number's line keeps ~9 pt clear over its
        // digits, so they stay inside the safe area) and narrows (the number scales to fit) until it clears the cilia,
        // to `portraitScoreMin` at most: the Duo's tight top corner.
        let topY = c.insets.top > 0 ? c.insets.top : (fold ? 6 : 4)
        let scoreH: CGFloat = compact ? 51 : 62
        let scoreMax: CGFloat = compact ? 160 : 190
        var scoreW = max(min(room(textOuter, topY, scoreH), scoreMax), 90)
        while scoreW > portraitScoreMin
                && AppCanvas.clearance(box(textOuter, topY, scoreW, scoreH), from: outline) < AppCanvas.ciliaClear {
            scoreW -= 1
        }
        let score = box(textOuter, topY, scoreW, scoreH)
        let pause = CGRect(x: right ? outer - pauseSide : outer, y: score.maxY + 4, width: pauseSide,
                           height: pauseSide)

        // The snaps: rows of seven in the bottom outer corner, the numeral on the lower row's inner side. The glyphs
        // shrink (rarely) until every row clears the cilia.
        let rows = max((slotCount + snapColumns - 1) / snapColumns, 1)
        let bottomY = c.size.height - max(c.insets.bottom, 0) - (fold ? 10 : 4)
        /// `numeralOnRow`: R5's lower row also holds the numeral, on its inner side. `rowGap`: between the rows.
        func rowRects(_ g: CGFloat, numeralOnRow: Bool, rowGap: CGFloat = HUDLayout.snapRowGap) -> [CGRect] {
            let gh = g * glyphAspect
            var out: [CGRect] = []
            for r in 0..<rows {
                let fromBottom = CGFloat(rows - 1 - r)
                let y = bottomY - gh - fromBottom * (gh + rowGap)
                let w = rowsWidth(glyph: g) + (numeralOnRow && r == rows - 1 ? snapNumeralWRow + 4 : 0)
                out.append(box(textOuter, y, w, gh))
            }
            return out
        }
        /// The glyph size (shrunk only if a row would touch the cilia) and its rows. R9: still touching at `glyphMin`
        /// (the Duo with a home-bar inset), the rows close up (`snapRowGapTight`), the upper one dropping off the cilia.
        func fitRows(numeralOnRow: Bool) -> (glyph: CGFloat, rects: [CGRect]) {
            func misfit(_ rs: [CGRect]) -> Bool {
                rs.contains(where: { room(textOuter, $0.minY, $0.height) < $0.width })
            }
            var g: CGFloat = glyphCap
            var rs = rowRects(g, numeralOnRow: numeralOnRow)
            while g > glyphMin && misfit(rs) {
                g -= 1
                rs = rowRects(g, numeralOnRow: numeralOnRow)
            }
            for gap in snapRowGapTight where misfit(rs) {
                rs = rowRects(g, numeralOnRow: numeralOnRow, rowGap: gap)
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
            numeralSize = compact ? numeralRowPhone : numeralRowDuo
            let pick = rowNumeral(six: six, five: fitRows(numeralOnRow: true), numeralSize: numeralSize,
                                  outline: outline, right: right, textOuter: textOuter, bottomY: bottomY,
                                  chainH: chainH, fullW: fullW, shortW: shortW, box: box, room: room)
            glyph = pick.glyph
            rects = pick.rects
            numeral = pick.numeral
            rowLabel = pick.label
            chain = pick.chain
            chainCompact = pick.chainCompact
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
                         lesson: lesson, card: card, tired: tired, snapRows: rows, trailing: right,
                         snapsTrailing: right, chainTrailing: right, columns: snapColumns)
    }

    /// R9: one way to set R5's numeral (no room for the labelled block) with its "SNAPS" caption, and the chain chip.
    private struct RowNumeral {
        var glyph: CGFloat
        var rects: [CGRect]
        var numeral: CGRect
        var label: CGRect
        var chain: CGRect
        var chainCompact: Bool
    }

    /// R9 (Duo frame duo-h2-reopened-150: "SNAPS" sat on the numeral, the numeral ran into the rows): the numeral's box
    /// is as tall as its digits draw (`numeralInkHeight`), and "SNAPS" and the numeral go in the first of these that
    /// keeps both ≥ `AppCanvas.ciliaClear` off the cilia (the chip's clearing too, if any does):
    /// - A (R5/R7): the numeral on the lower row's inner side, "SNAPS" over it or over the rows' outer end (R7's
    ///   order: the 6.3" iPhone keeps its look);
    /// - B: the numeral over the rows' outer end, "SNAPS" on its inner side (the Duo with a home-bar inset);
    /// - C: the numeral over the rows' outer end, "SNAPS" over it;
    /// else the one keeping both furthest off. The chip goes over them, lifted clear of "SNAPS". Pure; tested.
    private static func rowNumeral(six: (glyph: CGFloat, rects: [CGRect]), five: (glyph: CGFloat, rects: [CGRect]),
                                   numeralSize: CGFloat, outline: [CGPoint], right: Bool, textOuter: CGFloat,
                                   bottomY: CGFloat, chainH: CGFloat, fullW: CGFloat, shortW: CGFloat,
                                   box: (CGFloat, CGFloat, CGFloat, CGFloat) -> CGRect,
                                   room: (CGFloat, CGFloat, CGFloat) -> CGFloat) -> RowNumeral {
        let ink = numeralInkHeight(size: numeralSize)
        let lh = rowLabelHeight
        let lw = rowLabelWidth
        func clearOf(_ r: CGRect) -> CGFloat { AppCanvas.clearance(r, from: outline) }
        func clears(_ r: CGRect) -> Bool { clearOf(r) >= AppCanvas.ciliaClear }
        /// The chip at `y` ("Chain ×2" where it has room, else "×2"), lifted over `label` if it would crowd it.
        func chip(_ y: CGFloat, over label: CGRect) -> (rect: CGRect, compact: Bool) {
            func at(_ top: CGFloat) -> (rect: CGRect, compact: Bool) {
                let short = room(textOuter, top, chainH) < fullW
                return (box(textOuter, top, short ? shortW : fullW, chainH), short)
            }
            let first = at(y)
            let r = first.rect
            if r.maxX > label.minX && r.minX < label.maxX && r.maxY + rowLabelChainGap > label.minY {
                return at(label.minY - rowLabelChainGap - chainH)
            }
            return first
        }
        func option(_ g: CGFloat, _ rs: [CGRect], _ numeral: CGRect, _ label: CGRect,
                    _ chipY: CGFloat) -> RowNumeral {
            let c = chip(chipY, over: label)
            return RowNumeral(glyph: g, rects: rs, numeral: numeral, label: label, chain: c.rect,
                              chainCompact: c.compact)
        }
        var options: [RowNumeral] = []

        // A: on the lower row's inner side, centred where R5's row-high box was (never lower than the rows' foot).
        let row = five.rects.last ?? box(textOuter, bottomY - 14, 200, 14)
        let topRow = five.rects.first ?? row
        let rowBoxH = numeralHeight(glyph: five.glyph)
        let onRowH = max(rowBoxH, ink)
        let onRowMid = min(row.midY, bottomY - rowBoxH / 2)
        let onRow = CGRect(x: right ? row.minX : row.maxX - snapNumeralWRow, y: onRowMid - onRowH / 2,
                           width: snapNumeralWRow, height: onRowH)
        let chainY = topRow.minY - 8 - chainH
        // R7 (#13): "SNAPS" over the numeral at the upper row's height (R9: never lower than the numeral's top), where
        // that has room; else over the rows at the outer edge, with the chain chip moved up for it.
        let overNumeral = CGRect(x: right ? onRow.maxX - lw : onRow.minX,
                                 y: min(topRow.maxY, onRow.minY - rowLabelGap) - lh, width: lw, height: lh)
        let reachNeeded = right ? textOuter - overNumeral.minX : overNumeral.maxX - textOuter
        let overRows = box(textOuter, topRow.minY - 3 - lh, lw, lh)
        let movedChainY = overRows.minY - rowLabelChainGap - chainH
        let roomOverNumeral = room(textOuter, overNumeral.minY, lh) >= reachNeeded
        let movedRoom = room(textOuter, movedChainY, chainH)
        let roomOverRows = movedRoom >= min(room(textOuter, chainY, chainH), fullW) && movedRoom >= shortW
        let a1 = option(five.glyph, five.rects, onRow, overNumeral, chainY)
        let a2 = option(five.glyph, five.rects, onRow, overRows, movedChainY)
        let rowsFirst = !roomOverNumeral && (roomOverRows || clears(overRows))
        options += rowsFirst ? [a2, a1] : [a1, a2]

        // B and C: over the rows' outer end, "SNAPS" beside it (inner side, feet level) or over it.
        let overEndH = max(numeralHeight(glyph: six.glyph), ink)
        let rowsTop = six.rects.first?.minY ?? bottomY
        let overEnd = box(textOuter, rowsTop - 3 - overEndH, snapNumeralWRow, overEndH)
        let besideLabel = CGRect(x: right ? overEnd.minX - 4 - lw : overEnd.maxX + 4, y: overEnd.maxY - lh,
                                 width: lw, height: lh)
        let aboveLabel = box(textOuter, overEnd.minY - rowLabelGap - lh, lw, lh)
        options.append(option(six.glyph, six.rects, overEnd, besideLabel, overEnd.minY - 8 - chainH))
        options.append(option(six.glyph, six.rects, overEnd, aboveLabel, aboveLabel.minY - 8 - chainH))

        func fits(_ o: RowNumeral) -> Bool { clears(o.numeral) && clears(o.label) }
        func worst(_ o: RowNumeral) -> CGFloat { min(clearOf(o.numeral), clearOf(o.label)) }
        if let o = options.first(where: { fits($0) && clears($0.chain) }) { return o }
        if let o = options.first(where: { fits($0) }) { return o }
        var best = options[0]
        for o in options.dropFirst() where worst(o) > worst(best) { best = o }
        return best
    }

    /// R8 portrait (the Duo held like a laptop; the scene turned a quarter, so its four corners are the screen's, each
    /// a narrow strip up a side edge). The HUD lives on the bottom page:
    /// - the score in its bottom corner on the right (the left with "HUD on the left"), the pause button over it;
    /// - the snaps in the other bottom corner, in rows of 7 or 5 (whichever draws the bigger glyphs off the cilia,
    ///   a labelled numeral first), the numeral with "SNAPS" over them;
    /// - the chain chip in the top corner over the score (the only other spot off the cilia it fits);
    /// - the hint just under the fold on the score's side, its alternate slot on the snaps' side;
    /// - the tired banner and the pause card on the bottom page; the menus' back button top left.
    /// Every rect is upright and off the fold band. Pure; tested.
    private static func portrait(_ c: AppCanvas, outline: [CGPoint], glyphCap: CGFloat) -> HUDLayout {
        let w = c.size.width
        let h = c.size.height
        let page = c.hudPage
        let compact = c.isCompact
        let fold = c.hasFold
        let pad = AppCanvas.ciliaPad
        let scoreRight = !c.hudOnLeft
        let snapsRight = !scoreRight
        let mid = w / 2
        let inset: CGFloat = fold ? 14 : 8
        /// Glyphs and text may sit nearer the screen's edge than a button (there's nothing to tap).
        func textEdge(_ right: Bool) -> CGFloat {
            right ? w - max(c.insets.trailing, 0) - inset : max(c.insets.leading, 0) + inset
        }
        func box(_ right: Bool, _ edge: CGFloat, _ y: CGFloat, _ bw: CGFloat, _ bh: CGFloat) -> CGRect {
            CGRect(x: right ? edge - bw : edge, y: y, width: bw, height: bh)
        }
        /// The width from `edge` inward before the outline (plus the pad) over the band y…y+bh; never past the middle.
        func room(_ right: Bool, _ edge: CGFloat, _ y: CGFloat, _ bh: CGFloat) -> CGFloat {
            let cap = right ? edge - (mid + 4) : (mid - 4) - edge
            guard let reach = AppCanvas.outlineReach(outline, y0: y - pad, y1: y + bh + pad, right: right) else {
                return max(cap, 0)
            }
            let rw = right ? edge - (reach + pad) : (reach - pad) - edge
            return min(max(rw, 0), max(cap, 0))
        }
        let topY = max(c.insets.top, 0) + (fold ? 6 : 4)
        let bottomY = h - max(c.insets.bottom, 0) - (fold ? 10 : 4)

        // The score: its bottom corner; the pause button over it.
        let scoreEdge = textEdge(scoreRight)
        let scoreH: CGFloat = compact ? 51 : 62
        let scoreMax: CGFloat = compact ? 160 : 190
        let scoreY = bottomY - scoreH
        let scoreW = max(min(room(scoreRight, scoreEdge, scoreY, scoreH), scoreMax), portraitScoreMin)
        let score = box(scoreRight, scoreEdge, scoreY, scoreW, scoreH)
        let pause = CGRect(x: scoreRight ? page.maxX - pauseSide : page.minX, y: score.minY - 4 - pauseSide,
                           width: pauseSide, height: pauseSide)
        let back = CGRect(x: max(c.insets.leading, 0) + c.edgeMargin, y: c.top - 6, width: pauseSide,
                          height: pauseSide)

        // The snaps: the other bottom corner.
        let snapsEdge = textEdge(snapsRight)
        let count = slotCount
        let blockW = compact ? snapNumeralWPhone : snapNumeralW
        func rowRects(_ g: CGFloat, _ n: Int) -> [CGRect] {
            let gh = g * glyphAspect
            let rows = max((count + n - 1) / max(n, 1), 1)
            var out: [CGRect] = []
            for r in 0..<rows {
                let fromBottom = CGFloat(rows - 1 - r)
                out.append(box(snapsRight, snapsEdge, bottomY - gh - fromBottom * (gh + snapRowGap),
                               rowsWidth(glyph: g, columns: n), gh))
            }
            return out
        }
        /// At `n` a row: the biggest glyph (≤ the cap) whose rows clear the cilia, its rows, and the labelled
        /// numeral's block over them (and whether that clears too).
        func fit(_ n: Int) -> (columns: Int, glyph: CGFloat, rects: [CGRect], block: CGRect, blockFits: Bool) {
            var g = glyphCap
            var rs = rowRects(g, n)
            while g > glyphMin && rs.contains(where: { room(snapsRight, snapsEdge, $0.minY, $0.height) < $0.width }) {
                g -= 1
                rs = rowRects(g, n)
            }
            let bh = max(numeralBlockHeight(compact: compact), numeralHeight(glyph: g))
            let rowsTop = rs.first?.minY ?? bottomY
            let block = box(snapsRight, snapsEdge, rowsTop - 3 - bh, blockW, bh)
            return (n, g, rs, block, room(snapsRight, snapsEdge, block.minY, block.height) >= blockW)
        }
        var best = fit(snapColumns)
        for n in portraitColumns where n != snapColumns {
            let f = fit(n)
            if (f.blockFits && !best.blockFits) || (f.blockFits == best.blockFits && f.glyph > best.glyph) { best = f }
        }
        let labeled = best.blockFits
        let numeralSize: CGFloat = labeled ? (compact ? numeralPhone : numeralDuo)
                                           : (compact ? numeralRowPhone : numeralRowDuo)
        let numeral: CGRect
        if labeled {
            numeral = best.block
        } else {
            // No room for the labelled block: R5's numeral alone over the rows' outer end. R9: as tall as its digits
            // draw, so they never spill down onto the upper row.
            let nh = max(numeralHeight(glyph: best.glyph), numeralInkHeight(size: numeralSize))
            let rowsTop = best.rects.first?.minY ?? bottomY
            numeral = box(snapsRight, snapsEdge, rowsTop - 3 - nh, snapNumeralWRow, nh)
        }
        let snaps = best.rects.reduce(numeral) { $0.union($1) }

        // The chain chip: the top corner over the score ("Chain ×2" where it has room, else "×2").
        let chainH: CGFloat = compact ? 28 : 32
        let fullW = compact ? chainFullPhone : chainFullDuo
        let shortW = compact ? chainShortPhone : chainShortDuo
        let chainCompact = room(scoreRight, scoreEdge, topY, chainH) < fullW
        let chain = box(scoreRight, scoreEdge, topY, chainCompact ? shortW : fullW, chainH)

        // The hint: just under the fold, on the score's side; the alternate slot on the snaps' side.
        let hintH = compact ? hintHeightPhone : hintHeightDuo
        let hintW = max(min(compact ? hintPhone : hintDuo, (page.width - 8) / 2), hintMin)
        let hint = CGRect(x: scoreRight ? page.maxX - hintW : page.minX, y: page.minY, width: hintW, height: hintH)
        let lessonHint = CGRect(x: scoreRight ? page.minX : page.maxX - hintW, y: page.minY, width: hintW,
                                height: hintH)
        let lesson = CGRect(x: page.minX, y: page.minY, width: max(page.width - pauseSide - 10, 160),
                            height: compact ? 128 : 150)
        let cardW = min(page.width, 380)
        let card = CGRect(x: page.midX - cardW / 2, y: page.minY, width: cardW, height: max(c.bottom - page.minY, 0))
        let tiredW = min(page.width, compact ? 300 : 360)
        let tiredH: CGFloat = compact ? 76 : 90
        let tired = CGRect(x: page.midX - tiredW / 2, y: page.midY - tiredH / 2, width: tiredW, height: tiredH)
        return HUDLayout(pause: pause, back: back, score: score, chain: chain, chainCompact: chainCompact, snaps: snaps,
                         snapRowRects: best.rects, numeral: numeral, numeralSize: numeralSize, numeralLabeled: labeled,
                         snapsLabel: nil, glyph: best.glyph, hint: hint, lessonHint: lessonHint, lesson: lesson,
                         card: card, tired: tired, snapRows: best.rects.count, trailing: scoreRight,
                         snapsTrailing: snapsRight, chainTrailing: scoreRight, columns: best.columns)
    }

    /// The centre (screen) of glyph `i` (reading order: the top row first, left to right). Pure; tested.
    func glyphCenter(_ i: Int) -> CGPoint {
        guard !snapRowRects.isEmpty else { return CGPoint(x: snaps.midX, y: snaps.midY) }
        let n = max(columns, 1)
        let k = max(i, 0)
        let r = min(k / n, snapRowRects.count - 1)
        let col = min(k - r * n, n - 1)
        let rect = snapRowRects[r]
        let x0 = snapsTrailing ? rect.maxX - Self.rowsWidth(glyph: glyph, columns: n) : rect.minX
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
    /// What must clear the cilia by `AppCanvas.ciliaClear` (REVIEW-2-duo P0 4). R9: the row layout's "SNAPS" too.
    var ciliaRects: [CGRect] { [score, chain, numeral] + snapRowRects + (snapsLabel.map { [$0] } ?? []) }

    /// R9: the glyphs' own boxes, one rect per row, top first (a row's rect in `snapRowRects` also holds R5's
    /// numeral). Pure; tested (the numeral, "SNAPS" and the glyphs never overlap).
    var glyphRects: [CGRect] {
        let n = max(columns, 1)
        let gh = glyph * Self.glyphAspect
        var out: [CGRect] = []
        var first = 0
        while first < Self.slotCount {
            let last = min(first + n, Self.slotCount) - 1
            let a = glyphCenter(first)
            let b = glyphCenter(last)
            out.append(CGRect(x: min(a.x, b.x) - glyph / 2, y: a.y - gh / 2, width: abs(b.x - a.x) + glyph,
                              height: gh))
            first += n
        }
        return out
    }
}
