import CoreGraphics
import SpriteKit
import UIKit

/// One cosmetic particle (juice, dust, sparkles). Simulated by the scene, never by Core.
struct BogParticle {
    var position: CGPoint = .zero
    var velocity = CGVector(dx: 0, dy: 0)
    var life: CGFloat = 0
    var maxLife: CGFloat = 1
    var gravity: CGFloat = 0
    var drag: CGFloat = 0
    var spin: CGFloat = 0
    var shrink = true
    var growth: CGFloat = 0
    var alphaScale: CGFloat = 1
    var active = false
}

/// A fixed pool of sprites (one blend mode). Nothing is allocated per frame.
@MainActor
final class BogParticlePool {
    let root: SKNode
    private var sprites: [SKSpriteNode] = []
    private var parts: [BogParticle] = []
    private var cursor = 0
    var density: CGFloat = 1

    init(capacity: Int, texture: SKTexture, blend: SKBlendMode) {
        root = SKNode()
        for _ in 0..<max(capacity, 1) {
            let s = SKSpriteNode(texture: texture, size: CGSize(width: 6, height: 6))
            s.colorBlendFactor = 1
            s.blendMode = blend
            s.isHidden = true
            root.addChild(s)
            sprites.append(s)
            parts.append(BogParticle())
        }
    }

    var activeCount: Int {
        var n = 0
        for p in parts where p.active { n += 1 }
        return n
    }

    func clear() {
        for i in 0..<parts.count {
            parts[i].active = false
            sprites[i].isHidden = true
        }
    }

    func update(_ dt: CGFloat) {
        guard dt > 0 else { return }
        for i in 0..<parts.count where parts[i].active {
            var p = parts[i]
            p.life -= dt
            p.velocity.dy -= p.gravity * dt
            if p.drag > 0 {
                let k = max(0, 1 - p.drag * dt)
                p.velocity.dx *= k
                p.velocity.dy *= k
            }
            p.position.x += p.velocity.dx * dt
            p.position.y += p.velocity.dy * dt
            let s = sprites[i]
            if p.life <= 0 {
                p.active = false
                s.isHidden = true
                parts[i] = p
                continue
            }
            let k = max(0, min(1, p.life / max(p.maxLife, 0.001)))
            s.position = p.position
            s.alpha = min(1, k * 3) * p.alphaScale
            var scale: CGFloat = p.shrink ? (0.35 + 0.65 * k) : 1
            if p.growth > 0 { scale *= 1 + p.growth * (1 - k) }
            s.zRotation += p.spin * dt
            s.setScale(scale)
            parts[i] = p
        }
    }

    func spawn(_ p: BogParticle, size: CGFloat, color: UIColor) {
        let n = parts.count
        guard n > 0 else { return }
        var slot = -1
        for k in 0..<n {
            let idx = (cursor + k) % n
            if !parts[idx].active {
                slot = idx
                break
            }
        }
        if slot < 0 { slot = cursor }
        cursor = (slot + 1) % n
        var q = p
        q.active = true
        q.maxLife = max(q.life, 0.01)
        parts[slot] = q
        let s = sprites[slot]
        // (The scale is reset before the size: SpriteKit's `size` is the scaled size, so a recycled, shrunken
        // sprite would otherwise come back too big.)
        bogResize(s, CGSize(width: size, height: size))
        s.color = color
        s.position = q.position
        s.zRotation = 0
        s.alpha = q.alphaScale
        s.isHidden = false
    }
}

/// A short-lived sprite (splats, whiffs, startles, ripples) run by hand on the FX clock.
private struct BogFlash {
    var age: Double = 0
    var life: Double = 0
    var active = false
    var origin: CGPoint = .zero
    var angle: CGFloat = 0
    var size: CGFloat = 0
}

/// A pool of `BogFlash` sprites of one kind.
@MainActor
private final class BogFlashPool {
    let root: SKNode
    var sprites: [SKSpriteNode] = []
    var flashes: [BogFlash] = []
    private var cursor = 0

    init(capacity: Int, texture: SKTexture?, blend: SKBlendMode) {
        root = SKNode()
        for _ in 0..<max(capacity, 1) {
            let s = SKSpriteNode(texture: texture, size: CGSize(width: 10, height: 10))
            s.blendMode = blend
            s.isHidden = true
            root.addChild(s)
            sprites.append(s)
            flashes.append(BogFlash())
        }
    }

    func next() -> Int {
        let n = flashes.count
        for k in 0..<n {
            let i = (cursor + k) % n
            if !flashes[i].active {
                cursor = (i + 1) % n
                return i
            }
        }
        let i = cursor
        cursor = (cursor + 1) % n
        return i
    }

    var activeCount: Int { flashes.filter { $0.active }.count }

    func clear() {
        for i in 0..<flashes.count {
            flashes[i].active = false
            sprites[i].isHidden = true
        }
    }
}

/// The scene's FX: juice and sparkles (particles), juice splats on the lobe, whiff lines on escapes, startle marks
/// on spooked bugs, landing ripples.
@MainActor
final class BogEffects {
    /// Scene z 16 (on the lobe, under the tint): splats.
    let decalRoot: SKNode
    /// Scene z 23 (over the tint): landing ripples.
    let groundRoot: SKNode
    /// Scene z 50: particles, whiffs, startles.
    let fxRoot: SKNode
    private let juice: BogParticlePool
    private let sparks: BogParticlePool
    private let dust: BogParticlePool
    private let splats: BogFlashPool
    private let whiffs: BogFlashPool
    private let startles: BogFlashPool
    private let ripples: BogFlashPool
    private var rng = BogRNG(seed: 0x51A7)
    var reduceMotion = false {
        didSet {
            let d: CGFloat = reduceMotion ? 0.5 : 1
            juice.density = d
            sparks.density = d
            dust.density = d
        }
    }

    /// The "slurp" spray: pale green-gold nectar (never red: the game is 4+).
    static let juiceColor = RGBA(hex: 0xE2F59A)

    init() {
        decalRoot = SKNode()
        groundRoot = SKNode()
        fxRoot = SKNode()
        juice = BogParticlePool(capacity: 48, texture: BogTextures.dot, blend: .alpha)
        sparks = BogParticlePool(capacity: 36, texture: BogTextures.sparkle, blend: .add)
        dust = BogParticlePool(capacity: 16, texture: BogTextures.soft, blend: .alpha)
        splats = BogFlashPool(capacity: 10, texture: BogTextures.splat(0), blend: .alpha)
        whiffs = BogFlashPool(capacity: 8, texture: BogTextures.whiff, blend: .add)
        startles = BogFlashPool(capacity: 6, texture: BogTextures.startle, blend: .alpha)
        ripples = BogFlashPool(capacity: 10, texture: BogTextures.ripple, blend: .add)
        decalRoot.zPosition = 16
        groundRoot.zPosition = 23
        fxRoot.zPosition = 50
        decalRoot.addChild(splats.root)
        groundRoot.addChild(ripples.root)
        dust.root.zPosition = 0
        juice.root.zPosition = 1
        whiffs.root.zPosition = 2
        sparks.root.zPosition = 3
        startles.root.zPosition = 4
        fxRoot.addChild(dust.root)
        fxRoot.addChild(juice.root)
        fxRoot.addChild(whiffs.root)
        fxRoot.addChild(sparks.root)
        fxRoot.addChild(startles.root)
        for s in ripples.sprites {
            s.colorBlendFactor = 1
            s.color = .white
        }
    }

    /// Active particles and flashes (tests).
    var activeCount: Int {
        juice.activeCount + sparks.activeCount + dust.activeCount + splats.activeCount + whiffs.activeCount
            + startles.activeCount + ripples.activeCount
    }

    var activeSplats: Int { splats.activeCount }
    var activeWhiffs: Int { whiffs.activeCount }

    func clear() {
        juice.clear()
        sparks.clear()
        dust.clear()
        splats.clear()
        whiffs.clear()
        startles.clear()
        ripples.clear()
    }

    private func count(_ n: Int, _ pool: BogParticlePool) -> Int { max(1, Int((CGFloat(n) * pool.density).rounded())) }

    // MARK: Spawns

    /// A caught bug is gulped (a cheeky "slurp", never gore): a pale nectar spray, a glisten on the lobe that fades
    /// fast, gold sparkles and a little white puff. The bug itself shrinks and spins into the midrib (BogBugLayer).
    func squish(at p: CGPoint, radius r: CGFloat, tint: RGBA) {
        let col = BogPaint.ui(BogPaint.multiply(BogEffects.juiceColor, tint))
        for _ in 0..<count(9, juice) {
            let a = rng.range(0, 2 * .pi)
            let v = rng.range(70, 230)
            var q = BogParticle()
            q.position = CGPoint(x: p.x + cos(a) * r * 0.3, y: p.y + sin(a) * r * 0.3)
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.3, 0.6)
            q.drag = 5
            q.alphaScale = 0.95
            juice.spawn(q, size: rng.range(4, 9), color: col)
        }
        let i = splats.next()
        splats.flashes[i] = BogFlash(age: 0, life: 1.1, active: true, origin: p, angle: rng.range(0, 2 * .pi),
                                     size: max(r * 2, 30))
        let s = splats.sprites[i]
        s.texture = BogTextures.splat(Int(rng.range(0, 3)))
        // (No colour blend: the glisten keeps its own pale colours.)
        s.colorBlendFactor = 0
        s.isHidden = false
        sparkBurst(at: p, count: 4, color: BogPaint.ui(TrapArt.sipRing), speed: 140, size: 18)
        puff(from: CGPoint(x: p.x - r * 0.5, y: p.y), to: CGPoint(x: p.x + r * 0.5, y: p.y), count: 3,
             color: UIColor(white: 1, alpha: 1), size: max(r * 1.4, 18))
    }

    /// The bite's impact on the trap: a soft white flash along the midrib (the jaws meeting).
    func impact(at p: CGPoint, height: CGFloat) {
        puff(from: CGPoint(x: p.x, y: p.y - height * 0.45), to: CGPoint(x: p.x, y: p.y + height * 0.45), count: 6,
             color: UIColor(white: 1, alpha: 1), size: 46)
    }

    /// Sparks bursting out of a point.
    func sparkBurst(at p: CGPoint, count n: Int, color: UIColor, speed: CGFloat = 180, size: CGFloat = 20) {
        for _ in 0..<count(n, sparks) {
            let a = rng.range(0, 2 * .pi)
            let v = rng.range(0.4, 1) * speed
            var q = BogParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.35, 0.7)
            q.drag = 3
            q.spin = rng.range(-6, 6)
            sparks.spawn(q, size: size * rng.range(0.6, 1.2), color: color)
        }
    }

    /// A soft puff (a dry snap along the midrib, a hop).
    func puff(from a: CGPoint, to b: CGPoint, count n: Int, color: UIColor, size: CGFloat = 30) {
        for _ in 0..<count(n, dust) {
            let t = rng.unit()
            var q = BogParticle()
            q.position = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            q.velocity = CGVector(dx: rng.range(-50, 50), dy: rng.range(-30, 50))
            q.life = rng.range(0.45, 0.8)
            q.drag = 2.4
            q.growth = 1.3
            q.shrink = false
            q.alphaScale = rng.range(0.3, 0.5)
            dust.spawn(q, size: size * rng.range(0.7, 1.2), color: color)
        }
    }

    /// Motion lines behind an escaping bug (`heading` radians: the way it flies), plus a startle "!" over it (R2:
    /// 1.5 × bigger, so a slow snap that missed reads as yours).
    func whiff(at p: CGPoint, heading: CGFloat, radius r: CGFloat) {
        let i = whiffs.next()
        whiffs.flashes[i] = BogFlash(age: 0, life: 0.45, active: true, origin: p, angle: heading,
                                     size: max(r * 3, 60))
        whiffs.sprites[i].isHidden = false
        startle(at: p, radius: r)
    }

    /// A startled bug: a little burst over it.
    func startle(at p: CGPoint, radius r: CGFloat) {
        let i = startles.next()
        startles.flashes[i] = BogFlash(age: 0, life: 0.55, active: true,
                                       origin: CGPoint(x: p.x, y: p.y + r * 0.9), angle: 0, size: max(r * 1.3, 33))
        startles.sprites[i].isHidden = false
    }

    /// A landing "tik": a thin ring opening out under the bug.
    func ripple(at p: CGPoint, radius r: CGFloat) {
        let i = ripples.next()
        ripples.flashes[i] = BogFlash(age: 0, life: 0.38, active: true, origin: p, angle: 0, size: r * 2.2)
        ripples.sprites[i].isHidden = false
    }

    // MARK: Frame

    func update(_ dt: Double) {
        let fdt = CGFloat(max(dt, 0))
        juice.update(fdt)
        sparks.update(fdt)
        dust.update(fdt)
        guard dt > 0 else { return }
        step(splats, dt) { s, f, u in
            let pop = u < 0.05 ? 0.6 + 0.4 * (u / 0.05) : 1
            s.position = f.origin
            s.zRotation = f.angle
            s.size = CGSize(width: f.size * pop, height: f.size * pop)
            s.alpha = 0.92 * (1 - BogMath.smoothstep(0.45, 1, u))
        }
        step(whiffs, dt) { s, f, u in
            let back = CGPoint(x: -cos(f.angle), y: -sin(f.angle))
            s.position = CGPoint(x: f.origin.x + back.x * f.size * 0.4, y: f.origin.y + back.y * f.size * 0.4)
            s.zRotation = f.angle
            s.size = CGSize(width: f.size * (0.7 + 0.6 * u), height: f.size * 0.34)
            s.alpha = 0.9 * (1 - u)
        }
        step(startles, dt) { s, f, u in
            s.position = CGPoint(x: f.origin.x, y: f.origin.y + 10 * u)
            let k = u < 0.2 ? 0.5 + 2.5 * u : 1
            s.size = CGSize(width: f.size * k, height: f.size * k)
            s.alpha = 1 - BogMath.smoothstep(0.5, 1, u)
        }
        step(ripples, dt) { s, f, u in
            s.position = f.origin
            let k = 0.4 + 0.9 * u
            s.size = CGSize(width: f.size * k, height: f.size * k * 0.8)
            s.alpha = 0.65 * (1 - u)
        }
    }

    private func step(_ pool: BogFlashPool, _ dt: Double, _ apply: (SKSpriteNode, BogFlash, CGFloat) -> Void) {
        for i in 0..<pool.flashes.count where pool.flashes[i].active {
            pool.flashes[i].age += dt
            let f = pool.flashes[i]
            if f.age >= f.life {
                pool.flashes[i].active = false
                pool.sprites[i].isHidden = true
                continue
            }
            apply(pool.sprites[i], f, CGFloat(f.age / max(f.life, 0.001)))
        }
    }
}

// MARK: - Score pops

/// The in-world callouts ("FEAST ×5 · +255", "+40", "Bzzt!", "Too slow! −1 snap"): a pooled outlined label with a
/// soft drop shadow, popping in with an overshoot, rising, shrinking and only then fading on the FX clock. R2: 20 slots; when all are busy the
/// oldest is recycled (QA-1 #22), never a pop that has only just appeared.
@MainActor
final class BogPops {
    /// Scene z 60.
    let root: SKNode
    private var labels: [SKLabelNode] = []
    private var shadows: [SKLabelNode] = []
    private var ages: [Double] = []
    private var lives: [Double] = []
    private var delays: [Double] = []
    private var starts: [CGPoint] = []
    private var rises: [CGFloat] = []
    private var texts: [String] = []
    private var boxes: [CGSize] = []
    private var heroes: [Bool] = []
    private var cursor = 0
    private static var fonts: [Int: UIFont] = [:]

    init(capacity: Int = 20) {
        root = SKNode()
        root.zPosition = 60
        for _ in 0..<max(capacity, 1) {
            let sh = SKLabelNode()
            sh.horizontalAlignmentMode = .center
            sh.verticalAlignmentMode = .center
            sh.isHidden = true
            sh.zPosition = 0
            let l = SKLabelNode()
            l.horizontalAlignmentMode = .center
            l.verticalAlignmentMode = .center
            l.isHidden = true
            l.zPosition = 1
            root.addChild(sh)
            root.addChild(l)
            shadows.append(sh)
            labels.append(l)
            ages.append(-1)
            lives.append(1)
            delays.append(0)
            starts.append(.zero)
            rises.append(0)
            texts.append("")
            boxes.append(.zero)
            heroes.append(false)
        }
    }

    var capacity: Int { labels.count }

    /// The rounded black display face (cached per point size).
    static func font(_ size: CGFloat) -> UIFont {
        let key = Int(size.rounded())
        if let f = fonts[key] { return f }
        let base = UIFont.systemFont(ofSize: CGFloat(key), weight: .black)
        let f: UIFont
        if let d = base.fontDescriptor.withDesign(.rounded) {
            f = UIFont(descriptor: d, size: CGFloat(key))
        } else {
            f = base
        }
        fonts[key] = f
        return f
    }

    /// The size a pop's text takes at `size` points (its stroke included). Measured on events only, never per frame.
    static func measure(_ text: String, size: CGFloat) -> CGSize {
        let f = font(size)
        let s = (text as NSString).size(withAttributes: [.font: f])
        return CGSize(width: ceil(s.width) + 6, height: ceil(s.height))
    }

    /// How far a pop overshoots its size as it pops in (the crease clamp leaves room for it).
    nonisolated static func overshoot(hero: Bool) -> CGFloat { hero ? 0.22 : 0.18 }

    /// R3 (#25): a pop leaves by shrinking as it lifts, still opaque, and only fades at the very end (never a
    /// half-transparent smear mid-fade). `f` is its life fraction (0…1).
    nonisolated static func exitScale(_ f: CGFloat) -> CGFloat { 1 - 0.38 * BogMath.smoothstep(0.66, 1, f) }
    nonisolated static func exitAlpha(_ f: CGFloat) -> CGFloat { 1 - BogMath.smoothstep(0.86, 1, f) }

    var activeCount: Int { ages.filter { $0 >= 0 }.count }

    /// The texts on screen now (tests, demo frames).
    var activeTexts: [String] {
        var out: [String] = []
        for i in 0..<ages.count where ages[i] >= 0 { out.append(texts[i]) }
        return out
    }

    /// Each active pop's text box at its resting scale, where it is now (scene space; tests: off the crease).
    var activeRects: [CGRect] {
        var out: [CGRect] = []
        for i in 0..<ages.count where ages[i] >= 0 {
            let u = max(ages[i] - delays[i], 0)
            let f = CGFloat(min(u / lives[i], 1))
            let ease = 1 - (1 - f) * (1 - f)
            let p = CGPoint(x: starts[i].x, y: starts[i].y + rises[i] * ease)
            let b = boxes[i]
            out.append(CGRect(x: p.x - b.width / 2, y: p.y - b.height / 2, width: b.width, height: b.height))
        }
        return out
    }

    func clear() {
        for i in 0..<ages.count {
            ages[i] = -1
            labels[i].isHidden = true
            shadows[i].isHidden = true
        }
    }

    /// Shows `text` centred at `p`. `hero`: the bite's one big callout (a bigger overshoot, a longer hold).
    func pop(_ text: String, at p: CGPoint, size: CGFloat, fill: UIColor, stroke: UIColor, rise: CGFloat = 46,
             delay: Double = 0, life: Double = 1.15, hero: Bool = false) {
        let n = labels.count
        var slot = -1
        for k in 0..<n {
            let i = (cursor + k) % n
            if ages[i] < 0 {
                slot = i
                break
            }
        }
        if slot < 0 {
            // All busy: recycle the oldest.
            var oldest = 0
            for i in 1..<max(n, 1) where ages[i] > ages[oldest] { oldest = i }
            slot = oldest
        }
        cursor = (slot + 1) % n
        let font = BogPops.font(size)
        let main: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fill, .strokeColor: stroke,
                                                   .strokeWidth: -7.0]
        let back: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(white: 0, alpha: 0.38),
                                                   .strokeColor: UIColor(white: 0, alpha: 0.38), .strokeWidth: -9.0]
        labels[slot].attributedText = NSAttributedString(string: text, attributes: main)
        shadows[slot].attributedText = NSAttributedString(string: text, attributes: back)
        ages[slot] = 0
        lives[slot] = max(life, 0.3)
        delays[slot] = max(delay, 0)
        starts[slot] = p
        rises[slot] = rise
        texts[slot] = text
        boxes[slot] = BogPops.measure(text, size: size)
        heroes[slot] = hero
        labels[slot].isHidden = true
        shadows[slot].isHidden = true
    }

    func update(_ dt: Double) {
        for i in 0..<ages.count where ages[i] >= 0 {
            ages[i] += max(dt, 0)
            let u = ages[i] - delays[i]
            let l = labels[i], sh = shadows[i]
            if u < 0 {
                l.isHidden = true
                sh.isHidden = true
                continue
            }
            if u >= lives[i] {
                ages[i] = -1
                l.isHidden = true
                sh.isHidden = true
                continue
            }
            l.isHidden = false
            sh.isHidden = false
            let over = BogPops.overshoot(hero: heroes[i])
            var k: CGFloat
            // R3 (#15): it pops in from 0.72 (readable even on the hit-stop's frozen first frame), overshoots, settles.
            if u < 0.09 {
                k = 0.72 + (0.28 + over) * CGFloat(u / 0.09)
            } else if u < 0.22 {
                k = 1 + over - over * BogMath.smoothstep(0.09, 0.22, CGFloat(u))
            } else {
                k = 1
            }
            let f = CGFloat(min(u / lives[i], 1))
            let ease = 1 - (1 - f) * (1 - f)
            let p = CGPoint(x: starts[i].x, y: starts[i].y + rises[i] * ease)
            k *= BogPops.exitScale(f)
            let a = BogPops.exitAlpha(f)
            l.position = p
            l.setScale(k)
            l.alpha = a
            sh.position = CGPoint(x: p.x + 2, y: p.y - 3)
            sh.setScale(k)
            sh.alpha = a
        }
    }
}
