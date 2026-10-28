import CoreGraphics
import SpriteKit
import UIKit

/// R2 #17, "show the economy": the snaps you win and lose travel to and from the HUD's snaps row, so a Feast's
/// "+2 snaps" is shown, not told.
/// - On a Feast (or a lucky bug) +N snap glyphs fly from the bite to `anchor` (0.45 s, ease-in along an arc, one
///   after another), each landing with a bump and a sparkle.
/// - On a sting the lost glyph cracks at the anchor: two halves fall 20 pt and fade, under a crimson flash on the
///   glyph and (R3 #14) a 0.45 s crimson flash across the whole row.
/// - R3 (#14): `shownOffset` keeps the HUD's numeral truthful: it changes when each glyph lands, and only after a
///   sting's crack has shown.
/// - On a wilt (hunger) a glyph droops off the row, greyed, and fades.
/// The row itself is the App's HUD; the App passes its scene-space position as `BogScene.hudSnapsAnchor`.
@MainActor
final class BogEconomy {
    /// Scene z 62 (over the pops: the glyphs travel to the HUD).
    let root: SKNode

    private struct Flight {
        var start: CGPoint = .zero
        var control: CGPoint = .zero
        var end: CGPoint = .zero
        var delay: Double = 0
        var age: Double = 0
        var active = false
        var landed = false
        /// QA-2 #2/#3: false for a glyph whose snap Core didn't add (the row was full, or the run doesn't spend snaps):
        /// it still flies and bumps, but never holds the numeral back.
        var counts = true
    }

    static let flightTime: Double = 0.45
    static let flightGap: Double = 0.12
    static let bumpTime: Double = 0.2
    /// R3 (#14): how long the numeral waits for a sting's crack before it drops (s).
    static let crackLead: Double = 0.15
    /// R3 (#14): the row flash's size and how long it shows (s).
    static let rowFlashSize = CGSize(width: 300, height: 96)
    static let rowFlashTime: Double = 0.45

    private var glyphs: [SKSpriteNode] = []
    private var flights: [Flight] = []
    private let halfL: SKSpriteNode
    private let halfR: SKSpriteNode
    /// R6 (FEAST): the snaps row's refill flourish: a gold glow across the row and a sweep of sparkles along it.
    private let rowGlow: SKSpriteNode
    private var sweep: [SKSpriteNode] = []
    private var flourishAge: Double = -1
    private var flourishRow: CGRect = .zero
    private(set) var variety: TrapVariety = .classic
    /// R6: how long the flourish runs (s).
    static let flourishTime: Double = 0.75
    private let wiltGlyph: SKSpriteNode
    private let flash: SKSpriteNode
    private let rowFlash: SKSpriteNode
    private var crackAge: Double = -1
    private var crackCost = 0
    private var crackAt: CGPoint = .zero
    private var wiltAge: Double = -1
    private var wiltAt: CGPoint = .zero
    private var cursor = 0
    /// Glyphs that have landed since the last `clear` (tests; Feel can tick on `landedTick`).
    private(set) var landedCount = 0
    var reduceMotion = false

    /// QA-2 #19: 12 slots, so a live flight is never overwritten (the numeral never jumps a glyph early).
    init(capacity: Int = 12) {
        root = SKNode()
        root.zPosition = 62
        let tex = BogTextures.snapGlyph
        let gs = BogTextures.glyphSize
        for _ in 0..<max(capacity, 1) {
            let s = SKSpriteNode(texture: tex, size: gs)
            s.isHidden = true
            root.addChild(s)
            glyphs.append(s)
            flights.append(Flight())
        }
        let left = SKTexture(rect: CGRect(x: 0, y: 0, width: 0.5, height: 1), in: tex)
        let right = SKTexture(rect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1), in: tex)
        let half = CGSize(width: gs.width / 2, height: gs.height)
        halfL = SKSpriteNode(texture: left, size: half)
        halfR = SKSpriteNode(texture: right, size: half)
        wiltGlyph = SKSpriteNode(texture: tex, size: gs)
        wiltGlyph.color = UIColor(red: 0.45, green: 0.4, blue: 0.3, alpha: 1)
        wiltGlyph.colorBlendFactor = 0.7
        flash = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 90, height: 90))
        flash.blendMode = .add
        flash.color = BogPaint.ui(TrapArt.palette.danger)
        flash.colorBlendFactor = 1
        rowFlash = SKSpriteNode(texture: BogTextures.soft, size: BogEconomy.rowFlashSize)
        rowFlash.color = BogPaint.ui(RGBA(hex: 0xE0203C))
        rowFlash.colorBlendFactor = 1
        rowGlow = SKSpriteNode(texture: BogTextures.soft, size: BogEconomy.rowFlashSize)
        rowGlow.color = BogPaint.ui(TrapArt.palette.gold)
        rowGlow.colorBlendFactor = 1
        rowGlow.blendMode = .add
        for s in [halfL, halfR, wiltGlyph, flash, rowFlash, rowGlow] {
            s.isHidden = true
            root.addChild(s)
        }
        flash.zPosition = -1
        rowFlash.zPosition = -2
        rowGlow.zPosition = -1.5
        for _ in 0..<6 {
            let s = SKSpriteNode(texture: BogTextures.sparkle, size: CGSize(width: 30, height: 30))
            s.blendMode = .add
            s.color = BogPaint.ui(TrapArt.palette.gold)
            s.colorBlendFactor = 0.5
            s.isHidden = true
            s.zPosition = 1
            root.addChild(s)
            sweep.append(s)
        }
    }

    /// R6: the glyphs in `v`'s colours (the snaps row is the App's: it draws `TrapArt.snapGlyph(variety:)`).
    func setVariety(_ v: TrapVariety) {
        guard v != variety else { return }
        variety = v
        let tex = BogTextures.snapGlyph(variety: v)
        for g in glyphs { g.texture = tex }
        wiltGlyph.texture = tex
        halfL.texture = SKTexture(rect: CGRect(x: 0, y: 0, width: 0.5, height: 1), in: tex)
        halfR.texture = SKTexture(rect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1), in: tex)
    }

    /// R6 (tests): the refill flourish is running.
    var flourishing: Bool { flourishAge >= 0 || flourishPending }

    /// R6 (FEAST): the snaps row refills with a flourish: a gold glow over `row` (scene space; nil = the fallback row
    /// right of `anchor`) and sparkles sweeping along it, after `delay` s (the glyph flights land first).
    func flourish(row: CGRect?, anchor: CGPoint, delay: Double = 0) {
        if let r = row, !r.isNull, r.width > 1, r.height > 1 {
            flourishRow = r
        } else {
            let s = BogEconomy.rowFlashSize
            flourishRow = CGRect(x: anchor.x - 20, y: anchor.y - 12 - s.height / 4, width: s.width - 60,
                                 height: s.height / 2)
        }
        flourishAge = -max(delay, 0)
        bogResize(rowGlow, CGSize(width: flourishRow.width + 60, height: flourishRow.height + 50))
        rowGlow.position = CGPoint(x: flourishRow.midX, y: flourishRow.midY)
        rowGlow.isHidden = true
        flourishPending = true
    }

    private var flourishPending = false

    /// Glyphs in the air or landing now (tests).
    var activeFlights: Int { flights.filter { $0.active }.count }
    var cracking: Bool { crackAge >= 0 }
    var wilting: Bool { wiltAge >= 0 }
    /// R3 (#14): the row's crimson flash is showing (tests).
    var rowFlashing: Bool { !rowFlash.isHidden && rowFlash.alpha > 0.01 }

    /// R3 (#14) for the App: add this to `snapshot.snapsLeft` for the numeral the HUD shows. Each Feast glyph still in
    /// the air holds one snap back (−1) until it lands; a sting's cost shows for `crackLead` s while its glyph
    /// cracks (+cost), then the numeral drops.
    var shownOffset: Int {
        var n = 0
        for f in flights where f.active && !f.landed && f.counts { n -= 1 }
        if crackAge >= 0 && crackAge < BogEconomy.crackLead { n += crackCost }
        return n
    }

    func clear() {
        for i in 0..<flights.count {
            flights[i].active = false
            glyphs[i].isHidden = true
        }
        crackAge = -1
        crackCost = 0
        wiltAge = -1
        for s in [halfL, halfR, wiltGlyph, flash, rowFlash, rowGlow] { s.isHidden = true }
        for s in sweep { s.isHidden = true }
        flourishAge = -1
        flourishPending = false
        landedCount = 0
    }

    /// R5 (#12): the arc a glyph takes from `from` to `to` (its start and Bézier control) that crosses the fewest of
    /// `avoid` (the live pops, scene space): the R4 high arc when it is clear, else a low arc under the pops, a dogleg
    /// down then across, or a higher arc; the start may move a little off a pop it would begin on.
    static func route(from: CGPoint, to: CGPoint, avoid: [CGRect]) -> (start: CGPoint, control: CGPoint) {
        let high = CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + 140)
        guard !avoid.isEmpty else { return (from, high) }
        var best = (start: from, control: high)
        var bestHits = Int.max
        // The bite's own spot first, then a little above or below it, then out towards the row (clear of the stack of
        // lines under the callout).
        let dir: CGFloat = to.x >= from.x ? 1 : -1
        let starts = [from, CGPoint(x: from.x, y: from.y + 36), CGPoint(x: from.x, y: from.y - 36),
                      CGPoint(x: from.x + dir * 90, y: from.y), CGPoint(x: from.x + dir * 150, y: from.y),
                      CGPoint(x: from.x + dir * 150, y: from.y - 40), CGPoint(x: from.x + dir * 210, y: from.y)]
        for s in starts {
            let controls = [CGPoint(x: (s.x + to.x) / 2, y: max(s.y, to.y) + 140),
                            CGPoint(x: (s.x + to.x) / 2, y: min(s.y, to.y) - 40),
                            CGPoint(x: s.x, y: to.y),
                            CGPoint(x: to.x, y: max(s.y, to.y) + 40),
                            CGPoint(x: (s.x + to.x) / 2, y: max(s.y, to.y) + 260)]
            for c in controls {
                let crossed = BogEconomy.hits(start: s, control: c, end: to, avoid: avoid)
                if crossed < bestHits {
                    bestHits = crossed
                    best = (start: s, control: c)
                }
                if bestHits == 0 { return best }
            }
        }
        return best
    }

    /// R5 (#12): how many of 25 points along a glyph's arc put its box (`glyphSize`) on any of `avoid`.
    static func hits(start: CGPoint, control: CGPoint, end: CGPoint, avoid: [CGRect]) -> Int {
        var n = 0
        let gs = BogTextures.glyphSize
        for p in BogEconomy.arc(start: start, control: control, end: end, samples: 24) {
            let box = CGRect(x: p.x - gs.width / 2, y: p.y - gs.height / 2, width: gs.width, height: gs.height)
            if avoid.contains(where: { $0.intersects(box) }) { n += 1 }
        }
        return n
    }

    /// Points along the quadratic arc start → control → end (`samples` + 1 of them).
    static func arc(start: CGPoint, control: CGPoint, end: CGPoint, samples: Int) -> [CGPoint] {
        let n = max(samples, 1)
        var out: [CGPoint] = []
        for i in 0...n {
            let e = CGFloat(i) / CGFloat(n)
            let a = 1 - e
            out.append(CGPoint(x: a * a * start.x + 2 * a * e * control.x + e * e * end.x,
                               y: a * a * start.y + 2 * a * e * control.y + e * e * end.y))
        }
        return out
    }

    /// R5 (#12, tests): the arcs of the glyphs still in the air.
    var activePaths: [[CGPoint]] {
        flights.filter { $0.active && !$0.landed }.map {
            BogEconomy.arc(start: $0.start, control: $0.control, end: $0.end, samples: 24)
        }
    }

    /// `count` snap glyphs fly from `from` to `to`, one after another; only the first `counted` of them hold the
    /// numeral back (QA-2 #2: the snaps Core really added; nil = all of them). R5 (#12): their arc keeps off `avoid`
    /// (the live pops, scene space) where it can.
    func fly(count: Int, counted: Int? = nil, from: CGPoint, to: CGPoint, avoid: [CGRect] = []) {
        guard count > 0 else { return }
        let real = min(max(counted ?? count, 0), count)
        let way = BogEconomy.route(from: from, to: to, avoid: avoid)
        for k in 0..<min(count, glyphs.count) {
            var slot = -1
            for j in 0..<flights.count where !flights[(cursor + j) % flights.count].active {
                slot = (cursor + j) % flights.count
                break
            }
            if slot < 0 { slot = cursor }
            cursor = (slot + 1) % flights.count
            let fan = CGFloat(k) - CGFloat(count - 1) / 2
            let start = CGPoint(x: way.start.x + fan * 14, y: way.start.y)
            // An arc that rises first, then swoops down into the row (R5: or the route round the pops).
            let control = CGPoint(x: way.control.x + fan * 7, y: way.control.y)
            flights[slot] = Flight(start: start, control: control, end: to, delay: Double(k) * BogEconomy.flightGap,
                                   age: 0, active: true, landed: false, counts: k < real)
            let g = glyphs[slot]
            g.position = start
            g.setScale(0.4)
            g.alpha = 0
            g.isHidden = true
        }
    }

    /// The glyph a sting cost cracks at `p` (`cost` snaps: the numeral waits `crackLead` s for it), and the row
    /// flashes crimson. QA-2 #2: a second sting while the numeral is still waiting adds its cost (never replaces it).
    /// QA-2 #6: `row` is the HUD's snaps row (scene space) when the App knows it: the flash covers it, centred.
    func crack(at p: CGPoint, cost: Int = 1, row: CGRect? = nil) {
        let c = max(cost, 0)
        if crackAge >= 0 && crackAge < BogEconomy.crackLead {
            crackCost += c
        } else {
            crackCost = c
        }
        crackAge = 0
        crackAt = p
        for s in [halfL, halfR, flash, rowFlash] {
            s.isHidden = false
            s.alpha = 1
            s.zRotation = 0
            s.setScale(1)
        }
        halfL.position = CGPoint(x: p.x - BogTextures.glyphSize.width / 4, y: p.y)
        halfR.position = CGPoint(x: p.x + BogTextures.glyphSize.width / 4, y: p.y)
        flash.position = p
        if let r = row, !r.isNull, r.width > 1, r.height > 1 {
            bogResize(rowFlash, CGSize(width: r.width + 40, height: r.height + 36))
            rowFlash.position = CGPoint(x: r.midX, y: r.midY)
        } else {
            // The fallback: the row runs right from its leftmost live glyph (the anchor), in two rows of seven.
            bogResize(rowFlash, BogEconomy.rowFlashSize)
            rowFlash.position = CGPoint(x: p.x + 90, y: p.y - 12)
        }
    }

    /// R4 (tests): the cost the numeral is waiting on now.
    var pendingCrackCost: Int { crackAge >= 0 && crackAge < BogEconomy.crackLead ? crackCost : 0 }
    /// R4 (tests): the row flash's centre.
    var rowFlashCenter: CGPoint { rowFlash.position }

    private func stepFlourish(_ dt: Double) {
        flourishAge += dt
        if flourishAge < 0 { return }
        flourishPending = false
        let u = CGFloat(flourishAge / BogEconomy.flourishTime)
        if u >= 1 {
            flourishAge = -1
            rowGlow.isHidden = true
            for s in sweep { s.isHidden = true }
            return
        }
        rowGlow.isHidden = false
        rowGlow.alpha = 0.85 * sin(.pi * u)
        rowGlow.setScale(1 + 0.12 * u)
        // The sparkles run along the row, one after another, towards its inner end.
        let n = CGFloat(sweep.count)
        for (i, s) in sweep.enumerated() {
            let v = BogMath.clamp01(u * 1.6 - CGFloat(i) / n * 0.6)
            let x = flourishRow.minX + flourishRow.width * v
            let y = flourishRow.midY + 0.35 * flourishRow.height * sin(CGFloat(i) * 2.1 + 6 * v)
            s.isHidden = v <= 0 || v >= 1
            s.position = CGPoint(x: x, y: y)
            s.alpha = sin(.pi * v)
            s.setScale(0.6 + 0.6 * sin(.pi * v))
            s.zRotation = 4 * v
        }
    }

    /// A snap wilted (hunger): one glyph droops off the row at `p`, greyed.
    func wilt(at p: CGPoint) {
        wiltAge = 0
        wiltAt = p
        wiltGlyph.isHidden = false
        wiltGlyph.alpha = 1
        wiltGlyph.zRotation = 0
        wiltGlyph.position = p
    }

    func update(_ dt: Double) {
        guard dt > 0 else { return }
        if flourishPending || flourishAge >= 0 { stepFlourish(dt) }
        for i in 0..<flights.count where flights[i].active {
            flights[i].age += dt
            let f = flights[i]
            let g = glyphs[i]
            let u = (f.age - f.delay) / BogEconomy.flightTime
            if u < 0 {
                g.isHidden = true
                continue
            }
            g.isHidden = false
            if u < 1 {
                // Ease in: slow off the bite, fast into the row.
                let e = CGFloat(u * u)
                let a = 1 - e
                let p = CGPoint(x: a * a * f.start.x + 2 * a * e * f.control.x + e * e * f.end.x,
                                y: a * a * f.start.y + 2 * a * e * f.control.y + e * e * f.end.y)
                g.position = p
                g.alpha = min(1, CGFloat(u) * 6)
                g.setScale(u < 0.15 ? 0.4 + 4 * CGFloat(u) : 1)
                g.zRotation = (reduceMotion ? 0 : 0.6) * (1 - CGFloat(u)) * (i % 2 == 0 ? 1 : -1)
                continue
            }
            if !f.landed {
                flights[i].landed = true
                landedCount += 1
            }
            let b = (f.age - f.delay - BogEconomy.flightTime) / BogEconomy.bumpTime
            if b >= 1 {
                flights[i].active = false
                g.isHidden = true
                continue
            }
            g.position = f.end
            g.zRotation = 0
            g.setScale(1 + 0.45 * sin(.pi * CGFloat(b)))
            g.alpha = 1 - CGFloat(b) * CGFloat(b)
        }
        if crackAge >= 0 {
            crackAge += dt
            let u = CGFloat(crackAge / 0.6)
            let r = CGFloat(crackAge / BogEconomy.rowFlashTime)
            if r < 1 {
                // Two quick crimson beats across the row, then gone.
                rowFlash.alpha = 0.72 * (1 - r) * (0.6 + 0.4 * abs(cos(.pi * 2 * r)))
                rowFlash.setScale(1 + 0.08 * r)
            } else {
                rowFlash.isHidden = true
            }
            if u >= 1 {
                crackAge = -1
                for s in [halfL, halfR, flash, rowFlash] { s.isHidden = true }
            } else {
                // (R3 #14: the halves are a size bigger, so the crack reads at arm's length.)
                halfL.setScale(1.3)
                halfR.setScale(1.3)
                let fall = 20 * u * u
                let w = BogTextures.glyphSize.width / 4
                halfL.position = CGPoint(x: crackAt.x - w - 6 * u, y: crackAt.y - fall)
                halfR.position = CGPoint(x: crackAt.x + w + 6 * u, y: crackAt.y - fall)
                halfL.zRotation = 0.5 * u
                halfR.zRotation = -0.5 * u
                let a = 1 - BogMath.smoothstep(0.4, 1, u)
                halfL.alpha = a
                halfR.alpha = a
                flash.alpha = max(0, 0.9 * (1 - u / 0.6))
                flash.setScale(0.8 + 0.6 * u)
            }
        }
        if wiltAge >= 0 {
            wiltAge += dt
            let u = CGFloat(wiltAge / 0.8)
            if u >= 1 {
                wiltAge = -1
                wiltGlyph.isHidden = true
            } else {
                wiltGlyph.position = CGPoint(x: wiltAt.x + 4 * u, y: wiltAt.y - 20 * u * u)
                wiltGlyph.zRotation = -0.7 * BogMath.smoothstep(0, 0.7, u)
                wiltGlyph.alpha = 1 - BogMath.smoothstep(0.35, 1, u)
            }
        }
    }
}
