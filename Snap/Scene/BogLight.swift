import CoreGraphics
import SpriteKit
import UIKit

/// The day's light (GAME-DESIGN §10): warm gold morning, white noon, peach dusk, blue night, from `dayClock` 0…4.
/// A multiply tint over the bog (never the trap: it gets a ≤ 25 % normal-alpha overlay so it stays crimson), a haze
/// from the sky, a vignette; at night the bog's own fireflies come out and the dew stops twinkling. Bugs get a
/// lighter tint of their own (they must stay readable).
///
/// R3 (#10): dusk reads (a peach bog, a strong peach haze and a warm rim light on the lobes); at night the bog goes
/// blue but the trap's overlay is a dark neutral (it darkens, never turns violet), a cool moonlit rim, and the
/// fireflies bloom.
@MainActor
final class BogLight {
    /// One key of the day (at dayClock 0, 1, 2, 3, 4).
    struct Key {
        var env: RGBA
        var haze: RGBA
        var hazeAlpha: Double
        var bug: RGBA
        var bugAmount: Double
        /// R3: the trap's normal-alpha overlay colour (gold, white, peach, then a dark neutral at night: it darkens the
        /// crimson, never shifts its hue).
        var lobe: RGBA
        /// R3: the rim light on the lobes (additive) and its strength.
        var rim: RGBA
        var rimAlpha: Double
    }

    static let keys: [Key] = [
        Key(env: RGBA(1.0, 0.94, 0.82), haze: RGBA(1.0, 0.8, 0.42), hazeAlpha: 0.13, bug: RGBA(1, 0.82, 0.55),
            bugAmount: 0.08, lobe: RGBA(1.0, 0.8, 0.42), rim: RGBA(1.0, 0.86, 0.55), rimAlpha: 0.22),
        Key(env: RGBA(1, 1, 1), haze: RGBA(1, 1, 0.92), hazeAlpha: 0.05, bug: RGBA(1, 1, 1), bugAmount: 0,
            lobe: RGBA(1, 1, 0.92), rim: RGBA(1, 1, 0.95), rimAlpha: 0),
        Key(env: RGBA(1.0, 0.72, 0.56), haze: RGBA(1, 0.56, 0.34), hazeAlpha: 0.26, bug: RGBA(1, 0.66, 0.5),
            bugAmount: 0.16, lobe: RGBA(1, 0.6, 0.38), rim: RGBA(1, 0.62, 0.36), rimAlpha: 0.62),
        Key(env: RGBA(0.42, 0.55, 0.98), haze: RGBA(0.3, 0.42, 0.95), hazeAlpha: 0.08, bug: RGBA(0.3, 0.38, 0.75),
            bugAmount: 0.3, lobe: RGBA(0.05, 0.04, 0.1), rim: RGBA(0.66, 0.76, 1), rimAlpha: 0.3),
        Key(env: RGBA(0.36, 0.46, 0.9), haze: RGBA(0.25, 0.32, 0.85), hazeAlpha: 0.07, bug: RGBA(0.26, 0.32, 0.7),
            bugAmount: 0.36, lobe: RGBA(0.04, 0.03, 0.08), rim: RGBA(0.62, 0.72, 1), rimAlpha: 0.28),
    ]

    /// The light at `clock` (0…4, clamped), interpolated between the keys.
    static func key(at clock: Double) -> Key {
        let c = min(max(clock.isFinite ? clock : 0, 0), 4)
        let i = min(Int(c), 3)
        let f = c - Double(i)
        let a = keys[i], b = keys[i + 1]
        return Key(env: a.env.mixed(with: b.env, f), haze: a.haze.mixed(with: b.haze, f),
                   hazeAlpha: a.hazeAlpha + (b.hazeAlpha - a.hazeAlpha) * f, bug: a.bug.mixed(with: b.bug, f),
                   bugAmount: a.bugAmount + (b.bugAmount - a.bugAmount) * f, lobe: a.lobe.mixed(with: b.lobe, f),
                   rim: a.rim.mixed(with: b.rim, f), rimAlpha: a.rimAlpha + (b.rimAlpha - a.rimAlpha) * f)
    }

    /// The trap's overlay for a light key: its `lobe` colour (gold morning, peach dusk, a dark neutral at night) at up
    /// to 25 % alpha, by how far the day's light is from white.
    static func lobeLight(_ k: Key) -> (RGBA, CGFloat) {
        let minC = min(k.env.r, k.env.g, k.env.b)
        let a = CGFloat(min(max((1 - minC) / 0.58, 0), 1)) * 0.25
        return (k.lobe, a)
    }

    /// 0 by day … 1 at night.
    static func nightness(_ clock: Double) -> CGFloat {
        BogMath.smoothstep(2.35, 3.0, CGFloat(clock.isFinite ? clock : 0))
    }

    /// 0 … 1 around dusk.
    static func duskness(_ clock: Double) -> CGFloat {
        let c = CGFloat(clock.isFinite ? clock : 0)
        return BogMath.smoothstep(1.35, 2.0, c) * (1 - BogMath.smoothstep(2.3, 3.0, c))
    }

    /// Scene z 5 (multiply, over the bog only: R2 #21, so the trap keeps its crimson at dusk and night).
    let tint: SKSpriteNode
    /// Scene z 21 (additive sky haze).
    let haze: SKSpriteNode
    /// Scene z 21.5: dew twinkles (day) and the bog's fireflies (night).
    let sparkleRoot: SKNode
    /// Over everything (z 70, not shaken).
    let vignette: SKSpriteNode

    private(set) var night: CGFloat = 0
    private(set) var dusk: CGFloat = 0
    private(set) var bugTint: UIColor = .white
    private(set) var bugTintAmount: CGFloat = 0
    private(set) var envTint = RGBA(1, 1, 1)
    /// The trap's own light (R2 #21): a normal-alpha overlay of the day's colour, at most 25 %, instead of the
    /// multiply that turned the crimson magenta.
    private(set) var lobeTint: UIColor = .white
    private(set) var lobeTintAlpha: CGFloat = 0
    /// R3 (#10): the rim light on the lobes (additive).
    private(set) var rimTint: UIColor = .white
    private(set) var rimAlpha: CGFloat = 0
    /// The overlay as RGBA (tests: the night keeps the crimson's hue).
    private(set) var lobeTintRGBA = RGBA(1, 1, 1)
    private var pulseLevel: CGFloat = 0
    private var twinkles: [(SKSpriteNode, CGFloat)] = []
    private var flies: [(core: SKSpriteNode, glow: SKSpriteNode, home: CGPoint, phase: CGFloat)] = []
    private var lastClock: Double = -1

    init() {
        let t = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
        let h = SKSpriteNode(texture: BogTextures.haze, size: CGSize(width: 10, height: 10))
        let s = SKNode()
        let v = SKSpriteNode(texture: BogTextures.vignette, size: CGSize(width: 10, height: 10))
        tint = t
        haze = h
        sparkleRoot = s
        vignette = v
        t.blendMode = .multiply
        t.zPosition = 5
        h.blendMode = .add
        h.colorBlendFactor = 1
        h.zPosition = 21
        s.zPosition = 21.5
        v.color = UIColor(red: 0.02, green: 0.04, blue: 0.03, alpha: 1)
        v.colorBlendFactor = 1
        v.zPosition = 70
    }

    var level: CGFloat { night }

    func layout(size: CGSize, geometry g: TrapGeometry) {
        let pad: CGFloat = 120
        tint.size = CGSize(width: size.width + 2 * pad, height: size.height + 2 * pad)
        tint.position = CGPoint(x: size.width / 2, y: size.height / 2)
        haze.size = CGSize(width: size.width + 2 * pad, height: size.height * 0.9)
        haze.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        vignette.size = size
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)

        for (n, _) in twinkles { n.removeFromParent() }
        for f in flies {
            f.core.removeFromParent()
            f.glow.removeFromParent()
        }
        twinkles.removeAll()
        flies.removeAll()
        let dews = BogArt.dewSpots(size: size, geometry: g)
        var i = 0
        while i < dews.count && twinkles.count < 9 {
            let n = SKSpriteNode(texture: BogTextures.sparkle, size: CGSize(width: 14, height: 14))
            n.blendMode = .add
            n.position = CGPoint(x: dews[i].x - 1, y: dews[i].y + 1)
            n.alpha = 0
            sparkleRoot.addChild(n)
            twinkles.append((n, BogRNG.hash(i, 0x7A1) * 2 * .pi))
            i += 3
        }
        var rng = BogRNG(seed: 0xF1EF)
        var tries = 0
        while flies.count < 14 && tries < 3000 {
            tries += 1
            let p = CGPoint(x: rng.range(10, size.width - 10), y: rng.range(70, size.height - 10))
            guard g.normalizedRadius(p) > 1.12 else { continue }
            // R3 (#10): blooms big enough to see at arm's length.
            let gl = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 58, height: 58))
            gl.blendMode = .add
            gl.color = BogPaint.ui(RGBA(hex: 0xCFFF5E))
            gl.colorBlendFactor = 1
            gl.alpha = 0
            let core = SKSpriteNode(texture: BogTextures.dot, size: CGSize(width: 8, height: 8))
            core.blendMode = .add
            core.color = BogPaint.ui(RGBA(hex: 0xF4FFC0))
            core.colorBlendFactor = 1
            core.alpha = 0
            sparkleRoot.addChild(gl)
            sparkleRoot.addChild(core)
            flies.append((core: core, glow: gl, home: p, phase: rng.range(0, 2 * .pi)))
        }
        lastClock = -1
    }

    /// The snap's dark vignette pulse.
    func pulse() { pulseLevel = 1 }

    func reset() { pulseLevel = 0 }

    /// One frame: `clock` is the snapshot's `dayClock`, `time` the wall clock.
    func update(clock: Double, time: Double, fxDt: Double) {
        let t = CGFloat(time)
        if abs(clock - lastClock) > 0.0005 {
            lastClock = clock
            let k = BogLight.key(at: clock)
            envTint = k.env
            night = BogLight.nightness(clock)
            dusk = BogLight.duskness(clock)
            let white = k.env.r > 0.995 && k.env.g > 0.995 && k.env.b > 0.995
            tint.isHidden = white
            tint.color = BogPaint.ui(RGBA(k.env.r, k.env.g, k.env.b, 1))
            haze.color = BogPaint.ui(RGBA(k.haze.r, k.haze.g, k.haze.b, 1))
            haze.alpha = CGFloat(k.hazeAlpha)
            bugTint = BogPaint.ui(RGBA(k.bug.r, k.bug.g, k.bug.b, 1))
            bugTintAmount = CGFloat(k.bugAmount)
            let (c, a) = BogLight.lobeLight(k)
            lobeTint = BogPaint.ui(RGBA(c.r, c.g, c.b, 1))
            lobeTintAlpha = a
            lobeTintRGBA = RGBA(c.r, c.g, c.b, 1)
            rimTint = BogPaint.ui(RGBA(k.rim.r, k.rim.g, k.rim.b, 1))
            rimAlpha = CGFloat(min(max(k.rimAlpha, 0), 1))
        }
        pulseLevel = BogMath.approach(pulseLevel, 0, rate: 2.6, dt: CGFloat(max(fxDt, 0)))
        vignette.alpha = 0.2 + 0.28 * night + 0.5 * pulseLevel

        let day = 1 - 0.8 * night
        for (n, ph) in twinkles {
            let s = max(0, sin(t * 0.9 + ph))
            let s2 = s * s
            let s4 = s2 * s2
            n.alpha = s4 * s4 * s4 * day
            n.zRotation = t * 0.5 + ph
        }
        let on = night
        for f in flies {
            if on < 0.01 {
                f.core.isHidden = true
                f.glow.isHidden = true
                continue
            }
            f.core.isHidden = false
            f.glow.isHidden = false
            let p = CGPoint(x: f.home.x + 26 * sin(t * 0.31 + f.phase) + 8 * sin(t * 1.3 + f.phase * 2),
                            y: f.home.y + 18 * cos(t * 0.23 + f.phase) + 6 * sin(t * 1.7 + f.phase))
            let b = max(0, sin(t * 1.6 + f.phase))
            let blink = 0.2 + 0.8 * b * b * b
            f.core.position = p
            f.glow.position = p
            f.core.alpha = on * blink
            f.glow.alpha = on * blink
            f.glow.setScale(0.75 + 0.35 * blink)
        }
    }

    /// Fireflies drawn this frame (tests).
    var visibleFireflies: Int { flies.filter { !$0.glow.isHidden && $0.glow.alpha > 0.01 }.count }
}
