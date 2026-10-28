import CoreGraphics
import SpriteKit
import UIKit

/// R2 #17, "show the economy": the snaps you win and lose travel to and from the HUD's snaps row, so a Feast's
/// "+2 snaps" is shown, not told.
/// - On a Feast (or a lucky bug) +N snap glyphs fly from the bite to `anchor` (0.45 s, ease-in along an arc, one
///   after another), each landing with a bump and a sparkle.
/// - On a sting the lost glyph cracks at the anchor: two halves fall 20 pt and fade, under a crimson flash.
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
    }

    static let flightTime: Double = 0.45
    static let flightGap: Double = 0.12
    static let bumpTime: Double = 0.2

    private var glyphs: [SKSpriteNode] = []
    private var flights: [Flight] = []
    private let halfL: SKSpriteNode
    private let halfR: SKSpriteNode
    private let wiltGlyph: SKSpriteNode
    private let flash: SKSpriteNode
    private var crackAge: Double = -1
    private var crackAt: CGPoint = .zero
    private var wiltAge: Double = -1
    private var wiltAt: CGPoint = .zero
    private var cursor = 0
    /// Glyphs that have landed since the last `clear` (tests; Feel can tick on `landedTick`).
    private(set) var landedCount = 0
    var reduceMotion = false

    init(capacity: Int = 8) {
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
        for s in [halfL, halfR, wiltGlyph, flash] {
            s.isHidden = true
            root.addChild(s)
        }
        flash.zPosition = -1
    }

    /// Glyphs in the air or landing now (tests).
    var activeFlights: Int { flights.filter { $0.active }.count }
    var cracking: Bool { crackAge >= 0 }
    var wilting: Bool { wiltAge >= 0 }

    func clear() {
        for i in 0..<flights.count {
            flights[i].active = false
            glyphs[i].isHidden = true
        }
        crackAge = -1
        wiltAge = -1
        for s in [halfL, halfR, wiltGlyph, flash] { s.isHidden = true }
        landedCount = 0
    }

    /// `count` snap glyphs fly from `from` to `to`, one after another.
    func fly(count: Int, from: CGPoint, to: CGPoint) {
        guard count > 0 else { return }
        for k in 0..<min(count, glyphs.count) {
            var slot = -1
            for j in 0..<flights.count where !flights[(cursor + j) % flights.count].active {
                slot = (cursor + j) % flights.count
                break
            }
            if slot < 0 { slot = cursor }
            cursor = (slot + 1) % flights.count
            let fan = CGFloat(k) - CGFloat(count - 1) / 2
            let start = CGPoint(x: from.x + fan * 14, y: from.y)
            // An arc that rises first, then swoops down into the row.
            let control = CGPoint(x: (start.x + to.x) / 2, y: max(start.y, to.y) + 140)
            flights[slot] = Flight(start: start, control: control, end: to, delay: Double(k) * BogEconomy.flightGap,
                                   age: 0, active: true, landed: false)
            let g = glyphs[slot]
            g.position = start
            g.setScale(0.4)
            g.alpha = 0
            g.isHidden = true
        }
    }

    /// The glyph a sting cost cracks at `p`.
    func crack(at p: CGPoint) {
        crackAge = 0
        crackAt = p
        for s in [halfL, halfR, flash] {
            s.isHidden = false
            s.alpha = 1
            s.zRotation = 0
            s.setScale(1)
        }
        halfL.position = CGPoint(x: p.x - BogTextures.glyphSize.width / 4, y: p.y)
        halfR.position = CGPoint(x: p.x + BogTextures.glyphSize.width / 4, y: p.y)
        flash.position = p
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
            if u >= 1 {
                crackAge = -1
                for s in [halfL, halfR, flash] { s.isHidden = true }
            } else {
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
