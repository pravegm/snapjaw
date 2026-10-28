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
    /// R8: height ÷ width (the digest's wing scrap is long) and the alpha it holds at (the digest's stains, remains).
    var aspect: CGFloat = 1
    var peak: CGFloat = 1
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
    /// R8 (the digest): gold juice stains and the remains (flecks, a wing scrap) where caught bugs were.
    private let stains: BogFlashPool
    private let remains: BogFlashPool
    private var rng = BogRNG(seed: 0x51A7)
    var reduceMotion = false {
        didSet {
            let d: CGFloat = reduceMotion ? 0.5 : 1
            juice.density = d
            sparks.density = d
            dust.density = d
        }
    }

    /// The "slurp" spray. R6: nectar gold everywhere (never beige, never red: the game is 4+).
    static let juiceColor = RGBA(hex: 0xFFC83D)
    /// R6: the spray's bright core (the FEAST burst's sparkle).
    static let juiceGlint = RGBA(hex: 0xFFF2B0)
    /// R8 (the digest): how long the stain and the remains stay (session seconds), and the remains' dark fleck colour.
    static let digestLife: Double = 3
    static let remainsColor = RGBA(hex: 0x2A1A10)
    /// R8: the remains per caught bug (one pale wing scrap, the rest dark flecks).
    static let remainsPerBug = 4

    init() {
        decalRoot = SKNode()
        groundRoot = SKNode()
        fxRoot = SKNode()
        juice = BogParticlePool(capacity: 80, texture: BogTextures.dot, blend: .alpha)
        sparks = BogParticlePool(capacity: 72, texture: BogTextures.sparkle, blend: .add)
        dust = BogParticlePool(capacity: 16, texture: BogTextures.soft, blend: .alpha)
        splats = BogFlashPool(capacity: 10, texture: BogTextures.splat(0), blend: .alpha)
        whiffs = BogFlashPool(capacity: 8, texture: BogTextures.whiff, blend: .add)
        startles = BogFlashPool(capacity: 6, texture: BogTextures.startle, blend: .alpha)
        ripples = BogFlashPool(capacity: 10, texture: BogTextures.ripple, blend: .add)
        stains = BogFlashPool(capacity: 14, texture: BogTextures.splat(1), blend: .alpha)
        remains = BogFlashPool(capacity: 14 * BogEffects.remainsPerBug, texture: BogTextures.dot, blend: .alpha)
        decalRoot.zPosition = 16
        groundRoot.zPosition = 23
        fxRoot.zPosition = 50
        stains.root.zPosition = -0.4
        remains.root.zPosition = -0.2
        decalRoot.addChild(stains.root)
        decalRoot.addChild(remains.root)
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
            + startles.activeCount + ripples.activeCount + stains.activeCount + remains.activeCount
    }

    var activeSplats: Int { splats.activeCount }
    var activeWhiffs: Int { whiffs.activeCount }
    /// R8 (tests): the digest's stains and remains showing now.
    var activeStains: Int { stains.activeCount }
    var activeRemains: Int { remains.activeCount }

    func clear() {
        juice.clear()
        sparks.clear()
        dust.clear()
        splats.clear()
        whiffs.clear()
        startles.clear()
        ripples.clear()
        stains.clear()
        remains.clear()
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
        sparkBurst(at: p, count: 4, color: BogPaint.ui(TrapArt.palette.gold), speed: 140, size: 18)
        puff(from: CGPoint(x: p.x - r * 0.5, y: p.y), to: CGPoint(x: p.x + r * 0.5, y: p.y), count: 3,
             color: UIColor(white: 1, alpha: 1), size: max(r * 1.4, 18))
    }

    /// R6: the FEAST event's gold juice burst: a big ring of nectar gold thrown out from the bite and a shower of gold
    /// sparkles (the 3–4 bug Feast keeps the R5 treatment).
    func feastBurst(at p: CGPoint, tint: RGBA) {
        let col = BogPaint.ui(BogPaint.multiply(BogEffects.juiceColor, tint))
        let glint = BogPaint.ui(BogEffects.juiceGlint)
        for i in 0..<count(26, juice) {
            let a = CGFloat(i) / 26 * 2 * .pi + rng.range(-0.12, 0.12)
            let v = rng.range(260, 520)
            var q = BogParticle()
            q.position = p
            q.velocity = CGVector(dx: cos(a) * v, dy: sin(a) * v)
            q.life = rng.range(0.45, 0.8)
            q.drag = 4.2
            q.gravity = 120
            q.alphaScale = 1
            juice.spawn(q, size: rng.range(8, 16), color: i % 4 == 0 ? glint : col)
        }
        sparkBurst(at: p, count: 18, color: BogPaint.ui(TrapArt.palette.gold), speed: 420, size: 30)
        sparkBurst(at: p, count: 8, color: glint, speed: 200, size: 22)
    }

    /// R6: a little gold gulp where a caught bug vanishes into the midrib (the FEAST's one-after-another gulps).
    func gulp(at p: CGPoint) {
        sparkBurst(at: p, count: 3, color: BogPaint.ui(TrapArt.palette.gold), speed: 110, size: 16)
    }

    /// R8 (the digest, as the trap reopens after a hinge bite): where a caught bug was, a gold juice stain soaking into
    /// the lobe and its remains (dark flecks and one pale wing scrap), fading after `digestLife`. A cheeky leftover,
    /// never gore (4+). Placed at once (position, size, alpha), so it shows on the first frame even at dt 0.
    func digest(at p: CGPoint, radius r: CGFloat, tint: RGBA) {
        let i = stains.next()
        let size = max(r * 2.6, 36)
        let angle = rng.range(0, 2 * .pi)
        stains.flashes[i] = BogFlash(age: 0, life: BogEffects.digestLife, active: true, origin: p, angle: angle,
                                     size: size, aspect: 0.82, peak: 0.85)
        let s = stains.sprites[i]
        s.texture = BogTextures.splat(Int(rng.range(0, 3)))
        s.color = BogPaint.ui(BogPaint.multiply(BogEffects.juiceColor, tint))
        s.colorBlendFactor = 0.7
        s.position = p
        s.zRotation = angle
        s.size = CGSize(width: size * 0.6, height: size * 0.6 * 0.82)
        s.alpha = 0.85
        s.isHidden = false
        let fleck = BogPaint.ui(BogEffects.remainsColor)
        for k in 0..<BogEffects.remainsPerBug {
            let j = remains.next()
            let a = rng.range(0, 2 * .pi)
            let d = rng.range(0.1, 0.55) * r
            let q = CGPoint(x: p.x + cos(a) * d, y: p.y + sin(a) * d)
            let wing = k == 0
            let sz = wing ? max(r * 0.6, 9) : max(r * rng.range(0.16, 0.3), 4)
            let aspect: CGFloat = wing ? 0.45 : rng.range(0.7, 1)
            let peak: CGFloat = wing ? 0.55 : 0.85
            remains.flashes[j] = BogFlash(age: 0, life: BogEffects.digestLife, active: true, origin: q, angle: a,
                                          size: sz, aspect: aspect, peak: peak)
            let sp = remains.sprites[j]
            sp.color = wing ? UIColor(white: 0.93, alpha: 1) : fleck
            sp.colorBlendFactor = 1
            sp.position = q
            sp.zRotation = a
            sp.size = CGSize(width: sz, height: sz * aspect)
            sp.alpha = peak
            sp.isHidden = false
        }
    }

    /// R6: sparkles round the FEAST banner (`box`, scene space).
    func bannerSparkles(around box: CGRect) {
        let pts = [CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY),
                   CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                   CGPoint(x: box.midX, y: box.maxY + 6)]
        for c in pts {
            sparkBurst(at: c, count: 3, color: BogPaint.ui(TrapArt.palette.gold), speed: 120, size: 26)
        }
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
        step(stains, dt) { s, f, u in
            // R8: the stain soaks out to its size in the first moment, holds, and fades at the end.
            let soak: CGFloat = u < 0.08 ? 0.6 + 0.4 * (u / 0.08) : 1
            s.position = f.origin
            s.zRotation = f.angle
            s.size = CGSize(width: f.size * soak, height: f.size * soak * f.aspect)
            s.alpha = f.peak * (1 - BogMath.smoothstep(0.7, 1, u))
        }
        step(remains, dt) { s, f, u in
            s.position = f.origin
            s.zRotation = f.angle
            s.size = CGSize(width: f.size, height: f.size * f.aspect)
            s.alpha = f.peak * (1 - BogMath.smoothstep(0.75, 1, u))
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
    /// Each slot's pop-in overshoot (R6: the FEAST banner's is bigger) and whether it is a banner.
    private var overs: [CGFloat] = []
    private var banners: [Bool] = []
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
            overs.append(BogPops.overshoot(hero: false))
            banners.append(false)
        }
    }

    var capacity: Int { labels.count }

    /// R8 portrait (`BogScene.textTurned`; design/notes/portrait-R8.md): the App shows the scene turned a quarter
    /// clockwise, so every label is drawn a quarter turn counter-clockwise (upright on screen) and rises toward scene −x
    /// (the screen's top); `activeRects` and `liveRects` are the turned boxes. False: as before.
    var quarterTurn = false {
        didSet {
            guard quarterTurn != oldValue else { return }
            let angle = BogPops.labelAngle(quarterTurn)
            for l in labels { l.zRotation = angle }
            for s in shadows { s.zRotation = angle }
        }
    }

    /// R8: the labels' z rotation (radians, counter-clockwise). Pure; tested.
    nonisolated static func labelAngle(_ turned: Bool) -> CGFloat { turned ? .pi / 2 : 0 }
    /// R8: the way a pop rises, in scene space (a unit vector: the screen's up). Pure; tested.
    nonisolated static func riseDirection(_ turned: Bool) -> CGVector {
        turned ? CGVector(dx: -1, dy: 0) : CGVector(dx: 0, dy: 1)
    }
    /// R8: the drop shadow's offset in scene space (2 pt right and 3 pt down on screen). Pure; tested.
    nonisolated static func shadowOffset(_ turned: Bool) -> CGVector {
        turned ? CGVector(dx: 3, dy: 2) : CGVector(dx: 2, dy: -3)
    }
    /// R8: a text box as drawn in scene space (turned: the text runs along scene y). Pure; tested.
    nonisolated static func drawnBox(_ b: CGSize, turned: Bool) -> CGSize {
        turned ? CGSize(width: b.height, height: b.width) : b
    }

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
    /// R6: the FEAST banner's overshoot (a big, bouncy scale-in) and the scale it pops in from.
    static let bannerOvershoot: CGFloat = 0.42
    static let bannerFrom: CGFloat = 0.35

    /// R6 (tests): the banners on screen now.
    var activeBanners: [String] {
        var out: [String] = []
        for i in 0..<ages.count where ages[i] >= 0 && banners[i] { out.append(texts[i]) }
        return out
    }

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
        let d = BogPops.riseDirection(quarterTurn)
        for i in 0..<ages.count where ages[i] >= 0 {
            let u = max(ages[i] - delays[i], 0)
            let f = CGFloat(min(u / lives[i], 1))
            let ease = 1 - (1 - f) * (1 - f)
            let p = CGPoint(x: starts[i].x + d.dx * rises[i] * ease, y: starts[i].y + d.dy * rises[i] * ease)
            let b = BogPops.drawnBox(boxes[i], turned: quarterTurn)
            out.append(CGRect(x: p.x - b.width / 2, y: p.y - b.height / 2, width: b.width, height: b.height))
        }
        return out
    }

    /// R4 (#3): how far the App's plates keep from a live pop (points, on every side).
    static let clearance: CGFloat = 6

    /// R4 (#3): every live pop's footprint for the rest of its life, in the pops' own space: its box at the pop-in
    /// overshoot (and its drop shadow) swept from where it is now to where its rise ends, padded by `clearance`.
    /// Pops still waiting on their delay count from their start.
    var liveRects: [CGRect] {
        var out: [CGRect] = []
        for i in 0..<ages.count where ages[i] >= 0 {
            let u = max(ages[i] - delays[i], 0)
            let f = CGFloat(min(u / lives[i], 1))
            let ease = 1 - (1 - f) * (1 - f)
            let over = 1 + overs[i]
            let b = boxes[i]
            if quarterTurn {
                // R8 portrait: the box runs along y (its text) and sweeps toward −x; the shadow sits +x, +y.
                let x0 = starts[i].x - rises[i] * ease
                let x1 = starts[i].x - rises[i]
                let w = b.height * over, h = b.width * over
                let lo = min(x0, x1) - w / 2, hi = max(x0, x1) + w / 2 + 3
                let r = CGRect(x: lo, y: starts[i].y - h / 2, width: hi - lo, height: h + 2)
                out.append(r.insetBy(dx: -BogPops.clearance, dy: -BogPops.clearance))
                continue
            }
            let y0 = starts[i].y + rises[i] * ease
            let y1 = starts[i].y + rises[i]
            let w = b.width * over, h = b.height * over
            let lo = min(y0, y1) - h / 2 - 3, hi = max(y0, y1) + h / 2
            let r = CGRect(x: starts[i].x - w / 2, y: lo, width: w + 2, height: hi - lo)
            out.append(r.insetBy(dx: -BogPops.clearance, dy: -BogPops.clearance))
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
             delay: Double = 0, life: Double = 1.15, hero: Bool = false, banner: Bool = false) {
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
        heroes[slot] = hero || banner
        banners[slot] = banner
        overs[slot] = banner ? BogPops.bannerOvershoot : BogPops.overshoot(hero: hero)
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
            let over = overs[i]
            let from: CGFloat = banners[i] ? BogPops.bannerFrom : 0.72
            var k: CGFloat
            // R3 (#15): it pops in from 0.72 (readable even on the hit-stop's frozen first frame), overshoots, settles.
            // R6: the FEAST banner springs in from 0.35 to a 1.42 overshoot.
            if u < 0.09 {
                k = from + (1 - from + over) * CGFloat(u / 0.09)
            } else if u < 0.22 {
                k = 1 + over - over * BogMath.smoothstep(0.09, 0.22, CGFloat(u))
            } else {
                k = 1
            }
            let f = CGFloat(min(u / lives[i], 1))
            let ease = 1 - (1 - f) * (1 - f)
            let d = BogPops.riseDirection(quarterTurn)
            let p = CGPoint(x: starts[i].x + d.dx * rises[i] * ease, y: starts[i].y + d.dy * rises[i] * ease)
            k *= BogPops.exitScale(f)
            let a = BogPops.exitAlpha(f)
            l.position = p
            l.setScale(k)
            l.alpha = a
            let so = BogPops.shadowOffset(quarterTurn)
            sh.position = CGPoint(x: p.x + so.dx, y: p.y + so.dy)
            sh.setScale(k)
            sh.alpha = a
        }
    }
}
