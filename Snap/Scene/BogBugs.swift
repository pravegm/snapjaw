import CoreGraphics
import SpriteKit
import UIKit

/// One bug on screen: its sprites (body, wings, wing blur, sip ring, protected halo, glow) under a root that carries
/// position, heading and lift; its shadow and "cross" mark live in the layer (they never rotate).
@MainActor
final class BogBugNode {
    let root: SKNode
    let body: SKSpriteNode
    let wings: SKSpriteNode
    let blur: SKSpriteNode
    let halo: SKSpriteNode
    let ring: SKSpriteNode
    let glow: SKSpriteNode
    let shadow: SKSpriteNode
    let mark: SKSpriteNode

    private(set) var species: BugSpecies = .housefly
    private(set) var radius: CGFloat = 14
    private(set) var style: TrapBugStyle = TrapArt.bugStyle(.housefly)
    var id: Int = -1
    var phase: CGFloat = 0
    var catchPoint: CGPoint?
    var sipLevel: CGFloat = 0
    var markLevel: CGFloat = 0
    var seen: Int = 0
    /// The point drawn this frame (scene space).
    var drawnPoint: CGPoint = .zero

    init() {
        let r = SKNode()
        let b = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        let w = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        let bl = SKSpriteNode(texture: BogTextures.soft, size: CGSize(width: 10, height: 10))
        let h = SKSpriteNode(texture: BogTextures.halo, size: CGSize(width: 10, height: 10))
        let rg = SKSpriteNode(texture: BogTextures.ring, size: CGSize(width: 10, height: 10))
        let gl = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 10, height: 10))
        let sh = SKSpriteNode(texture: BogTextures.shadow, size: CGSize(width: 10, height: 10))
        let mk = SKSpriteNode(texture: BogTextures.anger, size: CGSize(width: 16, height: 16))
        root = r
        body = b
        wings = w
        blur = bl
        halo = h
        ring = rg
        glow = gl
        shadow = sh
        mark = mk
        h.zPosition = -0.8
        rg.zPosition = -0.7
        b.zPosition = 0
        w.zPosition = 0.3
        bl.zPosition = 0.35
        gl.zPosition = 0.5
        for n in [h, rg, b, w, bl, gl] { r.addChild(n) }
        bl.blendMode = .alpha
        bl.color = .white
        bl.colorBlendFactor = 1
        rg.color = BogPaint.ui(TrapArt.palette.gold)
        rg.colorBlendFactor = 1
        gl.blendMode = .add
        gl.colorBlendFactor = 1
        h.colorBlendFactor = 1
        sh.color = UIColor(red: 0.05, green: 0.0, blue: 0.02, alpha: 1)
        sh.colorBlendFactor = 1
        b.color = .white
        w.color = .white
    }

    func dress(_ s: BugSpecies, radius r: CGFloat, id: Int) {
        self.id = id
        species = s
        radius = r
        style = TrapArt.bugStyle(s)
        let side = BogTextures.bugSide(radius: r)
        body.texture = BogTextures.bug(s, radius: r)
        body.size = CGSize(width: side, height: side)
        wings.texture = BogTextures.wings(s, radius: r)
        wings.size = CGSize(width: side, height: side)
        blur.size = CGSize(width: r * 1.3, height: r * 2.5)
        blur.position = CGPoint(x: -r * 0.2, y: 0)
        halo.size = CGSize(width: r * 3.0, height: r * 3.0)
        halo.color = s == .wasp ? BogPaint.ui(TrapArt.palette.danger) : UIColor(white: 1, alpha: 1)
        halo.isHidden = !s.isProtected
        ring.size = CGSize(width: r * 2.8, height: r * 2.8)
        shadow.size = CGSize(width: r * 2.1, height: r * 1.6)
        mark.size = CGSize(width: max(r * 0.95, 15), height: max(r * 0.95, 15))
        switch s {
        case .firefly:
            glow.isHidden = false
            glow.color = BogPaint.ui(RGBA(hex: 0xD8FF5A))
            glow.size = CGSize(width: r * 5, height: r * 5)
            glow.position = CGPoint(x: -0.66 * r, y: 0)
        case .goldenScarab:
            glow.isHidden = false
            glow.color = BogPaint.ui(TrapArt.palette.gold)
            glow.size = CGSize(width: r * 3.6, height: r * 3.6)
            glow.position = .zero
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .cricket, .bee, .bumblebee, .wasp:
            glow.isHidden = true
            glow.position = .zero
        }
        phase = BogRNG.hash(id, 0xB06) * 2 * .pi
        catchPoint = nil
        sipLevel = 0
        markLevel = 0
        root.isHidden = false
        shadow.isHidden = false
        mark.isHidden = true
        root.alpha = 1
        root.setScale(1)
    }

    func hide() {
        root.isHidden = true
        shadow.isHidden = true
        mark.isHidden = true
        id = -1
    }
}

/// The bugs (ARCHITECTURE: drawn from `snapshot.bugs` only). Nodes are pooled and keyed by bug id.
@MainActor
final class BogBugLayer {
    /// Shadows (scene z 22, under every bug).
    let ground: SKNode
    /// The bugs (scene z 30).
    let layer: SKNode
    private var live: [Int: BogBugNode] = [:]
    private var free: [BogBugNode] = []
    private var frame = 0
    private var radii: [BugSpecies: CGFloat] = [:]

    init() {
        let g = SKNode()
        let l = SKNode()
        ground = g
        layer = l
        g.zPosition = 22
        l.zPosition = 30
    }

    var liveCount: Int { live.count }

    /// The art radius: Core's `BugInfo.radius` (the art's fallback when it is missing).
    func radius(_ s: BugSpecies) -> CGFloat {
        if let r = radii[s] { return r }
        let info = BugCatalog.info(s).radius
        let r = info > 2 ? info : TrapArt.defaultRadius(s)
        radii[s] = r
        return r
    }

    /// Where a bug is drawn (nil when it is not on screen).
    func drawnPoint(_ id: Int) -> CGPoint? { live[id]?.drawnPoint }

    /// A bug in the bite: it squishes into the midrib from here.
    func markCaught(_ id: Int, at p: CGPoint) {
        if let n = live[id], n.catchPoint == nil { n.catchPoint = p }
    }

    func clear() {
        for (_, n) in live {
            n.hide()
            free.append(n)
        }
        live.removeAll()
    }

    private func node(for b: BugState) -> BogBugNode {
        if let n = live[b.id], n.species == b.species { return n }
        if let old = live[b.id] {
            old.hide()
            free.append(old)
        }
        let n: BogBugNode
        if let f = free.popLast() {
            n = f
        } else {
            n = BogBugNode()
            layer.addChild(n.root)
            layer.addChild(n.mark)
            ground.addChild(n.shadow)
        }
        n.dress(b.species, radius: radius(b.species), id: b.id)
        live[b.id] = n
        return n
    }

    /// One frame. `time`/`dt` are wall clock (flaps, bobs); `light` dims bugs at night.
    func update(_ bugs: [BugState], time: Double, dt: Double, geometry g: TrapGeometry, night: CGFloat,
                tint: UIColor, tintAmount: CGFloat, reduceMotion: Bool) {
        frame &+= 1
        let t = CGFloat(time)
        let fdt = CGFloat(max(dt, 0))
        for b in bugs {
            let n = node(for: b)
            n.seen = frame
            draw(n, b, t: t, dt: fdt, geometry: g, night: night, tint: tint, tintAmount: tintAmount,
                 reduceMotion: reduceMotion)
        }
        // Bugs gone from the snapshot leave the screen.
        if live.count > bugs.count || live.values.contains(where: { $0.seen != frame }) {
            var gone: [Int] = []
            for (id, n) in live where n.seen != frame { gone.append(id) }
            for id in gone {
                if let n = live.removeValue(forKey: id) {
                    n.hide()
                    free.append(n)
                }
            }
        }
    }

    private func draw(_ n: BogBugNode, _ b: BugState, t: CGFloat, dt: CGFloat, geometry g: TrapGeometry,
                      night: CGFloat, tint: UIColor, tintAmount: CGFloat, reduceMotion: Bool) {
        let r = n.radius
        let st = n.style
        let ph = n.phase
        var pos = b.position
        let h = CGFloat(min(max(b.height, 0), 1))
        var rot = CGFloat(b.heading)
        var sx: CGFloat = 1, sy: CGFloat = 1
        var alpha: CGFloat = 1
        var flying = false
        var sipping = false
        var walking = false
        var released = false
        var caughtT: CGFloat = -1
        var stretch: CGFloat = 1
        switch b.activity {
        case .arriving, .leaving, .hopping:
            flying = true
        case .escaped:
            flying = true
            stretch = 1.12
        case .released:
            flying = true
            released = true
        case .walking:
            walking = true
        case .sipping:
            sipping = true
        case .caught(let elapsed):
            caughtT = CGFloat(min(max(elapsed / 0.5, 0), 1))
        }
        let restless = CGFloat(min(max(b.restless, 0), 1))
        let motion: CGFloat = reduceMotion ? 0.5 : 1

        // Body life.
        if walking {
            sx *= 1 + 0.035 * sin(t * 16 + ph) * motion
            rot += 0.05 * sin(t * 16 + ph) * motion
        }
        if sipping {
            rot += 0.06 * sin(t * 5 + ph) * motion
            sy *= 1 + 0.025 * sin(t * 10 + ph) * motion
        }
        if restless > 0.05 && !flying && caughtT < 0 {
            let burst: CGFloat = sin(t * 7.3 + ph) > 0.35 ? 1 : 0.2
            rot += 0.16 * restless * sin(t * 31 + ph) * burst * motion
        }
        if flying {
            pos.y += 1.6 * sin(t * 9 + ph) * motion
        }

        // The squish into the midrib.
        if caughtT >= 0 {
            let start = n.catchPoint ?? b.position
            if n.catchPoint == nil { n.catchPoint = start }
            let target = CGPoint(x: g.center.x, y: start.y + (g.center.y - start.y) * 0.3)
            // A cheeky gulp, never gore (4+): the bug shrinks and spins into the midrib, whole, and is gone.
            let pull = BogMath.smoothstep(0.08, 0.85, caughtT)
            pos = BogMath.lerp(start, target, pull)
            let shrink = 1 - 0.85 * BogMath.smoothstep(0.05, 0.95, caughtT)
            let boing = 1 + 0.12 * sin(.pi * min(caughtT * 3, 1))
            sx *= shrink * boing
            sy *= shrink * boing
            rot += 2.6 * .pi * pull * pull
            alpha = 1 - BogMath.smoothstep(0.6, 1, caughtT)
        }

        // Lift: drawn higher and larger the higher it flies.
        let lift = 1 + 0.32 * h
        let drawn = CGPoint(x: pos.x, y: pos.y + 18 * h)
        n.drawnPoint = drawn
        n.root.position = drawn
        n.root.zRotation = rot
        n.root.xScale = sx * lift * stretch
        n.root.yScale = sy * lift
        n.root.alpha = alpha
        n.root.zPosition = 6 * h

        // Night dimming (a light colour blend; never a full replacement).
        let amount = max(tintAmount, 0)
        n.body.color = tint
        n.body.colorBlendFactor = min(amount, 0.6)
        n.wings.color = tint
        n.wings.colorBlendFactor = amount

        // Wings.
        var spread: CGFloat = st.restSpread
        var blurA: CGFloat = 0
        if flying && st.flapHz > 0 {
            n.phase += dt * CGFloat(st.flapHz) * 2 * .pi * (reduceMotion ? 0.5 : 1)
            spread = 0.35 + 0.65 * (0.5 + 0.5 * sin(n.phase))
            if st.flapHz >= 20 { blurA = 0.26 }
        } else if caughtT < 0 && restless > 0.3 && st.restSpread > 0 {
            let flick = max(0, sin(t * 23 + ph))
            let f2 = flick * flick
            spread += 0.3 * restless * f2 * f2 * f2 * f2
        }
        if caughtT >= 0 { spread = st.restSpread * (1 - caughtT) }
        n.wings.yScale = max(spread, 0.001)
        n.wings.isHidden = spread < 0.02 || st.wing.a < 0.01
        n.blur.alpha = blurA
        n.blur.isHidden = blurA <= 0.001

        // The sip ring (gold, under the bug).
        n.sipLevel = BogMath.approach(n.sipLevel, sipping ? 1 : 0, rate: 5, dt: dt)
        n.ring.alpha = 0.85 * n.sipLevel
        n.ring.isHidden = n.sipLevel < 0.01
        if !n.ring.isHidden { n.ring.setScale(1 + 0.06 * sin(t * 4 + ph)) }

        // The protected halo (bees white, wasps red).
        if b.species.isProtected && caughtT < 0 {
            n.halo.isHidden = false
            n.halo.alpha = 0.5 + 0.2 * sin(t * 3 + ph)
            n.halo.setScale(1 + 0.04 * sin(t * 3 + ph))
        } else {
            n.halo.isHidden = true
        }

        // Glow (fireflies at night; the scarab's shimmer).
        switch b.species {
        case .firefly:
            let blink = 0.55 + 0.45 * max(0, sin(t * 2.2 + ph))
            n.glow.alpha = (0.35 + 0.65 * night) * blink * alpha
        case .goldenScarab:
            n.glow.alpha = (0.28 + 0.14 * sin(t * 2.6 + ph)) * alpha
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .cricket, .bee, .bumblebee, .wasp:
            break
        }

        // Shadow: on the ground below, offset down-right as it rises, softer and smaller.
        n.shadow.position = CGPoint(x: pos.x + 2 + 8 * h, y: pos.y - 2 - 5 * h)
        n.shadow.zRotation = CGFloat(b.heading)
        n.shadow.setScale((1 - 0.35 * h) * (caughtT >= 0 ? 1 - caughtT : 1))
        n.shadow.alpha = 0.4 * (1 - 0.6 * h) * alpha

        // The cross mark over a released bee.
        n.markLevel = BogMath.approach(n.markLevel, released ? 1 : 0, rate: 6, dt: dt)
        if n.markLevel > 0.01 {
            n.mark.isHidden = false
            n.mark.position = CGPoint(x: drawn.x + r * 0.7, y: drawn.y + r * 1.1 + 2 * sin(t * 10))
            n.mark.alpha = n.markLevel
            n.mark.setScale(0.8 + 0.2 * n.markLevel + 0.08 * sin(t * 14))
            n.mark.zPosition = 8
        } else {
            n.mark.isHidden = true
        }
    }
}
