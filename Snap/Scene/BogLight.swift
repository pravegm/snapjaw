import CoreGraphics
import SpriteKit
import UIKit

/// The day's light (GAME-DESIGN §10): warm gold morning, white noon, peach dusk, blue night, from `dayClock` 0…4.
/// A multiply tint over the bog and the trap, a haze from the sky, a vignette; at night the bog's own fireflies come
/// out and the dew stops twinkling. Bugs get a lighter tint of their own (they must stay readable).
@MainActor
final class BogLight {
    /// One key of the day (at dayClock 0, 1, 2, 3, 4).
    struct Key {
        var env: RGBA
        var haze: RGBA
        var hazeAlpha: Double
        var bug: RGBA
        var bugAmount: Double
    }

    static let keys: [Key] = [
        Key(env: RGBA(1.0, 0.94, 0.82), haze: RGBA(1.0, 0.8, 0.42), hazeAlpha: 0.13, bug: RGBA(1, 0.82, 0.55),
            bugAmount: 0.08),
        Key(env: RGBA(1, 1, 1), haze: RGBA(1, 1, 0.92), hazeAlpha: 0.05, bug: RGBA(1, 1, 1), bugAmount: 0),
        Key(env: RGBA(1.0, 0.8, 0.7), haze: RGBA(1, 0.52, 0.32), hazeAlpha: 0.15, bug: RGBA(1, 0.66, 0.5),
            bugAmount: 0.16),
        Key(env: RGBA(0.5, 0.58, 0.88), haze: RGBA(0.3, 0.42, 0.95), hazeAlpha: 0.07, bug: RGBA(0.3, 0.38, 0.75),
            bugAmount: 0.3),
        Key(env: RGBA(0.42, 0.48, 0.8), haze: RGBA(0.25, 0.32, 0.85), hazeAlpha: 0.06, bug: RGBA(0.26, 0.32, 0.7),
            bugAmount: 0.36),
    ]

    /// The light at `clock` (0…4, clamped), interpolated between the keys.
    static func key(at clock: Double) -> Key {
        let c = min(max(clock.isFinite ? clock : 0, 0), 4)
        let i = min(Int(c), 3)
        let f = c - Double(i)
        let a = keys[i], b = keys[i + 1]
        return Key(env: a.env.mixed(with: b.env, f), haze: a.haze.mixed(with: b.haze, f),
                   hazeAlpha: a.hazeAlpha + (b.hazeAlpha - a.hazeAlpha) * f, bug: a.bug.mixed(with: b.bug, f),
                   bugAmount: a.bugAmount + (b.bugAmount - a.bugAmount) * f)
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

    /// Scene z 20 (multiply).
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
        t.zPosition = 20
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
        while flies.count < 10 && tries < 3000 {
            tries += 1
            let p = CGPoint(x: rng.range(10, size.width - 10), y: rng.range(70, size.height - 10))
            guard g.normalizedRadius(p) > 1.14 else { continue }
            let gl = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 30, height: 30))
            gl.blendMode = .add
            gl.color = BogPaint.ui(RGBA(hex: 0xCFFF5E))
            gl.colorBlendFactor = 1
            gl.alpha = 0
            let core = SKSpriteNode(texture: BogTextures.dot, size: CGSize(width: 5, height: 5))
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
            let blink = 0.25 + 0.75 * b * b
            f.core.position = p
            f.glow.position = p
            f.core.alpha = on * blink
            f.glow.alpha = on * blink * 0.85
        }
    }

    /// Fireflies drawn this frame (tests).
    var visibleFireflies: Int { flies.filter { !$0.glow.isHidden && $0.glow.alpha > 0.01 }.count }
}
