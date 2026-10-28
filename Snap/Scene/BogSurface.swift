import CoreGraphics
import SpriteKit
import UIKit

/// One nectar drop's sprites.
@MainActor
final class BogDropView {
    let sprite: SKSpriteNode
    let twinkle: SKSpriteNode
    let glow: SKSpriteNode
    /// Core's radius (the drawn one is `BogTextures.nectarDrawnRadius` of it).
    var radius: CGFloat = 0
    var drawn: CGFloat = 0
    var level: CGFloat = 0
    var alive = true
    /// Seconds a bug has sipped from it (it shrinks 3 % a second, to 75 %).
    var sipped: CGFloat = 0
    let phase: CGFloat

    init(id: Int) {
        sprite = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        twinkle = SKSpriteNode(texture: BogTextures.sparkle, size: CGSize(width: 10, height: 10))
        glow = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 10, height: 10))
        phase = BogRNG.hash(id, 0x7EC7) * 2 * .pi
        twinkle.blendMode = .add
        twinkle.zPosition = 0.5
        twinkle.alpha = 0
        glow.blendMode = .add
        glow.color = BogPaint.ui(TrapArt.palette.nectar)
        glow.colorBlendFactor = 1
        glow.alpha = 0
    }

    func setRadius(_ r: CGFloat) {
        guard abs(r - radius) > 0.25 else { return }
        radius = r
        let d = BogTextures.nectarDrawnRadius(r)
        drawn = d
        sprite.texture = BogTextures.nectar(radius: d)
        // (Sizes are set with the scale reset first: SpriteKit's `size` is the scaled size.)
        bogResize(sprite, CGSize(width: d * 3, height: d * 3))
        bogResize(twinkle, CGSize(width: d * 1.6, height: d * 1.6))
        bogResize(glow, CGSize(width: d * 4.5, height: d * 4.5))
    }
}

/// The lobes' surface details that live above the cached face: nectar drops (they come and go with the waves) and
/// the three trigger hairs per lobe (they glow when a bug walks over one).
@MainActor
final class BogSurface {
    /// Scene z 15 (under the day tint).
    let root: SKNode
    /// Scene z 41 (additive glows over the tint: nectar at night).
    let glowRoot: SKNode
    private var drops: [Int: BogDropView] = [:]
    private var hairs: [SKSpriteNode] = []
    private var hairGlows: [SKSpriteNode] = []
    private var hairLevels: [CGFloat] = []
    private var hairPoints: [CGPoint] = []

    init() {
        let r = SKNode()
        let gr = SKNode()
        root = r
        glowRoot = gr
        r.zPosition = 15
        gr.zPosition = 41
    }

    var dropCount: Int { drops.values.filter { $0.alive }.count }
    var litHairs: Int { hairLevels.filter { $0 > 0.2 }.count }

    func layout(_ g: TrapGeometry) {
        for h in hairs { h.removeFromParent() }
        for h in hairGlows { h.removeFromParent() }
        hairs.removeAll()
        hairGlows.removeAll()
        hairPoints = TrapArt.triggerHairs(side: -1, geometry: g) + TrapArt.triggerHairs(side: 1, geometry: g)
        hairLevels = hairPoints.map { _ in CGFloat(0) }
        for (i, p) in hairPoints.enumerated() {
            let gl = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 46, height: 46))
            gl.blendMode = .add
            gl.color = BogPaint.ui(RGBA(hex: 0xFFE38A))
            gl.colorBlendFactor = 1
            gl.alpha = 0
            gl.position = p
            gl.zPosition = 0.2
            root.addChild(gl)
            hairGlows.append(gl)
            let h = SKSpriteNode(texture: BogTextures.hair, size: CGSize(width: 14, height: 24))
            h.anchorPoint = CGPoint(x: 0.5, y: 5.0 / 24.0)
            h.position = p
            h.zRotation = (BogRNG.hash(i, 0x4A19) - 0.5) * 1.4
            h.zPosition = 0.3
            root.addChild(h)
            hairs.append(h)
        }
    }

    func clear() {
        for (_, d) in drops {
            d.sprite.removeFromParent()
            d.twinkle.removeFromParent()
            d.glow.removeFromParent()
        }
        drops.removeAll()
        for i in 0..<hairLevels.count { hairLevels[i] = 0 }
    }

    func update(nectar: [NectarDrop], bugs: [BugState], time: Double, dt: Double, night: CGFloat) {
        let t = CGFloat(time)
        let fdt = CGFloat(max(dt, 0))
        for d in drops.values { d.alive = false }
        for n in nectar {
            let v: BogDropView
            if let have = drops[n.id] {
                v = have
            } else {
                v = BogDropView(id: n.id)
                root.addChild(v.sprite)
                v.sprite.addChild(v.twinkle)
                glowRoot.addChild(v.glow)
                drops[n.id] = v
            }
            v.alive = true
            v.setRadius(max(n.radius, 3))
            v.sprite.position = n.position
            v.glow.position = n.position
            v.level = BogMath.approach(v.level, 1, rate: 4, dt: fdt)
            let sipped = n.occupant != nil
            if sipped { v.sipped += fdt }
            let drink = max(1 - 0.03 * v.sipped, 0.75)
            let wobble: CGFloat = sipped ? 0.035 * sin(t * 7 + v.phase) : 0.012 * sin(t * 1.7 + v.phase)
            let k = ((sipped ? 0.94 : 1) + wobble) * drink
            v.sprite.setScale(k * (0.6 + 0.4 * v.level))
            v.sprite.alpha = v.level
            let s = max(0, sin(t * 1.1 + v.phase))
            let s2 = s * s
            let s8 = s2 * s2 * s2 * s2
            v.twinkle.alpha = s8 * s2 * s2 * v.level
            v.twinkle.position = CGPoint(x: -v.drawn * 0.32, y: v.drawn * 0.44)
            v.twinkle.zRotation = t * 0.6
            v.glow.alpha = (0.5 * night + 0.06) * v.level
        }
        // Drops gone (a new nectar seeding) melt away.
        var gone: [Int] = []
        for (id, d) in drops where !d.alive {
            d.level = BogMath.approach(d.level, 0, rate: 3.5, dt: fdt)
            d.sprite.alpha = d.level
            d.sprite.setScale(0.6 + 0.4 * d.level)
            d.glow.alpha = d.level * 0.3 * night
            if d.level <= 0.001 { gone.append(id) }
        }
        for id in gone {
            if let d = drops.removeValue(forKey: id) {
                d.sprite.removeFromParent()
                d.glow.removeFromParent()
            }
        }

        // Trigger hairs glow when a bug on the surface is on one.
        for i in 0..<hairPoints.count {
            let p = hairPoints[i]
            var touched = false
            for b in bugs where b.height < 0.15 {
                var onSurface = false
                switch b.activity {
                case .walking, .sipping: onSurface = true
                case .arriving, .hopping, .leaving, .caught, .escaped, .released: onSurface = false
                }
                guard onSurface else { continue }
                let dx = b.position.x - p.x, dy = b.position.y - p.y
                let reach: CGFloat = 26
                if dx * dx + dy * dy < reach * reach {
                    touched = true
                    break
                }
            }
            if touched {
                hairLevels[i] = 1
            } else {
                hairLevels[i] = BogMath.approach(hairLevels[i], 0, rate: 1.6, dt: fdt)
            }
            hairGlows[i].alpha = 0.85 * hairLevels[i]
            hairGlows[i].setScale(1 + 0.15 * sin(t * 8 + CGFloat(i)))
            hairs[i].xScale = 1 + 0.25 * hairLevels[i]
        }
    }
}
