import CoreGraphics
import SpriteKit
import UIKit

/// One lobe's nodes: the cached face, the closure shades, the day's overlay, the hunger wilt, the gloss, the night
/// glow and the teeth under `node` (its origin is the trap centre, the midrib; its xScale foreshortens and squeezes
/// the lobe towards the midrib), and the far lobe's slam jaw under `jawNode` (never squeezed).
@MainActor
final class BogLobeSide {
    let side: Int
    let node: SKNode
    let jawNode: SKNode
    let lobe: SKSpriteNode
    let shadeNarrow: SKSpriteNode
    let shadeWide: SKSpriteNode
    let overlay: SKSpriteNode
    let wilt: SKSpriteNode
    let gloss: SKSpriteNode
    let glow: SKSpriteNode
    let jaw: SKSpriteNode
    private(set) var teeth: [SKSpriteNode] = []
    private(set) var specs: [TrapTooth] = []
    /// Each tooth's root in normalised trap units (x / a, y / b from the centre): the slam hides the ones the far
    /// lobe's jaw covers.
    private(set) var rootNorm: [CGPoint] = []

    init(side: Int) {
        self.side = side < 0 ? -1 : 1
        let n = SKNode()
        let jn = SKNode()
        let lobeSize = BogTextures.lobeSize(reach: 1, pad: BogTextures.lobePad)
        let anchor = BogTextures.lobeAnchor(side: side)
        let l = SKSpriteNode(texture: BogTextures.lobe(side: side), size: lobeSize)
        let sn = SKSpriteNode(texture: BogTextures.lobeShadeNarrow(side: side), size: lobeSize)
        let sw = SKSpriteNode(texture: BogTextures.lobeShadeWide(side: side), size: lobeSize)
        let ov = SKSpriteNode(texture: BogTextures.lobeSilhouette(side: side), size: lobeSize)
        let wl = SKSpriteNode(texture: BogTextures.lobeSilhouette(side: side), size: lobeSize)
        let gl = SKSpriteNode(texture: BogTextures.gloss(side: side), size: lobeSize)
        let gw = SKSpriteNode(texture: BogTextures.lobeGlow(side: side), size: lobeSize)
        let jw = SKSpriteNode(texture: BogTextures.jaw(side: side),
                              size: BogTextures.lobeSize(reach: BogArt.jawOuter, pad: BogTextures.jawPad))
        node = n
        jawNode = jn
        lobe = l
        shadeNarrow = sn
        shadeWide = sw
        overlay = ov
        wilt = wl
        gloss = gl
        glow = gw
        jaw = jw
        let layers: [(SKSpriteNode, CGFloat)] = [(l, 0), (sn, 1), (sw, 1.1), (ov, 1.5), (wl, 1.6), (gl, 2),
                                                 (gw, 2.2)]
        for (s, z) in layers {
            s.anchorPoint = anchor
            s.position = .zero
            s.zPosition = z
            n.addChild(s)
        }
        jw.anchorPoint = anchor
        jw.position = .zero
        jn.addChild(jw)
        sn.alpha = 0
        sw.alpha = 0
        for s in [ov, wl] {
            s.colorBlendFactor = 1
            s.color = .white
            s.alpha = 0
            s.isHidden = true
        }
        wl.color = UIColor(red: 0.42, green: 0.36, blue: 0.24, alpha: 1)
        gw.blendMode = .add
        gw.alpha = 0
        jw.alpha = 0
        jw.isHidden = true
        gl.alpha = 0.75
        buildTeeth()
    }

    private func buildTeeth() {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        specs = TrapArt.teeth(side: side, geometry: g)
        let tex = BogArt.toothTexSize
        for t in specs {
            let s = SKSpriteNode(texture: BogTextures.tooth(curl: t.curl),
                                 size: CGSize(width: tex.width * t.width / BogArt.toothTexWidth,
                                              height: tex.height * t.length / BogArt.toothTexLength))
            s.anchorPoint = CGPoint(x: 0.5, y: BogArt.toothRootY / tex.height)
            s.position = CGPoint(x: t.root.x - g.center.x, y: t.root.y - g.center.y)
            s.zRotation = t.angle - .pi / 2
            s.zPosition = 4
            s.color = UIColor(red: 0.07, green: 0.2, blue: 0.1, alpha: 1)
            s.colorBlendFactor = 0
            node.addChild(s)
            teeth.append(s)
            rootNorm.append(CGPoint(x: (t.root.x - g.center.x) / g.a, y: (t.root.y - g.center.y) / g.b))
        }
    }
}

/// The trap: two lobes on the fold, the midrib, the fold band. It follows the hinge (`closure01`), slams on a bite,
/// springs open on re-arm, droops when hungry and when the trap is tired. Static art is cached; per frame only
/// transforms, colours and alphas change.
@MainActor
final class BogJaws {
    /// At the trap centre (scene z 10).
    let root: SKNode
    let midrib: SKSpriteNode
    /// The crease across the whole scene height (only with a real fold).
    let foldBand: SKSpriteNode
    private let sides: [BogLobeSide]

    /// The slam's level (0 none … 1 shut) and the lean the teeth are drawn at (radians).
    private(set) var slamLevel: CGFloat = 0
    private(set) var drawnClosure: CGFloat = 0
    private(set) var lean: CGFloat = 0
    private(set) var tiredLevel: CGFloat = 0
    /// How hungry the trap looks (0 fed … 1 about to wilt a snap): the lobes droop and dull a little.
    private(set) var droop: CGFloat = 0
    /// The lobes' x scale now (1 open … `slamSqueeze` mid-bite); caught bugs ride with it.
    private(set) var lobeScale: CGFloat = 1
    /// The day's overlay alpha on the lobes (tests: the trap stays crimson).
    private(set) var overlayAlpha: CGFloat = 0
    var reduceMotion = false

    private var slamClock: Double = -1
    private var springClock: Double = -1
    private var rumbleClock: Double = -1
    private var sweep: CGFloat = 1

    init() {
        let r = SKNode()
        let m = SKSpriteNode(texture: BogTextures.midrib, size: BogTextures.midribSize)
        let f = SKSpriteNode(texture: BogTextures.foldBand,
                             size: CGSize(width: 2 * ScreenLayout.creaseHalfWidth, height: ScreenLayout.canvasHeight))
        root = r
        midrib = m
        foldBand = f
        sides = [BogLobeSide(side: -1), BogLobeSide(side: 1)]
        r.zPosition = 10
        for s in sides {
            s.node.zPosition = 0
            r.addChild(s.node)
        }
        m.zPosition = 3
        r.addChild(m)
        for s in sides {
            // The far lobe's jaw covers our lobe, the midrib's ends and our teeth' roots, under the bugs.
            s.jawNode.zPosition = 3.5
            r.addChild(s.jawNode)
        }
        f.zPosition = -9
        f.color = .black
        f.colorBlendFactor = 1
        f.alpha = 0.22
        r.addChild(f)
        m.colorBlendFactor = 0
    }

    var teethCount: Int { sides.reduce(0) { $0 + $1.teeth.count } }

    /// Every tooth's projected length factor as drawn (tests).
    var toothReach: CGFloat { TrapArt.toothReach(lean: lean) }

    func layout(_ g: TrapGeometry, sceneHeight: CGFloat, hasFold: Bool) {
        root.position = g.center
        foldBand.size = CGSize(width: 2 * ScreenLayout.creaseHalfWidth, height: sceneHeight + 160)
        foldBand.position = .zero
        foldBand.isHidden = !hasFold
    }

    /// The bite: the teeth slam over, both lobes squeeze to `slamSqueeze` towards the midrib and the far lobe's jaw
    /// sweeps in from beyond the outer edges (60 ms), holds (120 ms) and lets go.
    func slam() {
        slamClock = 0
        sweep = 0
    }

    /// Re-armed: the lobes and teeth spring back out with a little overshoot (1.08).
    func rearm() {
        springClock = 0
    }

    /// Hungry: a little stomach-rumble wobble of the lobes.
    func rumble() {
        rumbleClock = 0
    }

    func reset() {
        slamClock = -1
        springClock = -1
        rumbleClock = -1
        slamLevel = 0
        sweep = 1
        tiredLevel = 0
        droop = 0
        lobeScale = 1
        for s in sides {
            s.jaw.alpha = 0
            s.jaw.isHidden = true
        }
    }

    /// One frame. `fxDt` runs the moments (it is 0 while the session is frozen); `time` is the wall clock for
    /// shimmer. `hunger` is the snapshot's 0…1; `tint`/`tintAlpha` the day's overlay on the lobes.
    func update(fxDt: Double, closure01 c: CGFloat, tired target: CGFloat, hunger: CGFloat, time: Double,
                night: CGFloat, dusk: CGFloat, tint: UIColor, tintAlpha: CGFloat) {
        let cc = BogMath.clamp01(c.isFinite ? c : 0)
        let dt = max(fxDt, 0)
        drawnClosure = cc
        // The slam envelope.
        if slamClock >= 0 {
            slamClock += dt
            let t = CGFloat(slamClock)
            if t < 0.06 {
                let u = t / 0.06
                sweep = 1 - (1 - u) * (1 - u)
                slamLevel = sweep
            } else if t < 0.18 {
                sweep = 1
                slamLevel = 1
            } else if t < 0.5 {
                sweep = 1
                slamLevel = 1 - BogMath.smoothstep(0.18, 0.5, t)
            } else {
                slamLevel = 0
                slamClock = -1
            }
        }
        var spring: CGFloat = 1
        var lobeSpring: CGFloat = 1
        if springClock >= 0 {
            springClock += dt
            let t = springClock
            if t < 0.6 {
                spring = 1 + CGFloat(0.16 * exp(-7 * t) * sin(26 * t))
                lobeSpring = 1 + CGFloat(0.085 * exp(-6 * t) * sin(15 * t))
            } else {
                springClock = -1
            }
        }
        var wobble: CGFloat = 0
        if rumbleClock >= 0 {
            rumbleClock += dt
            let t = rumbleClock
            if t < 0.7 {
                wobble = CGFloat(0.012 * sin(t * 38) * (1 - t / 0.7))
            } else {
                rumbleClock = -1
            }
        }
        if reduceMotion {
            wobble = 0
            lobeSpring = 1 + (lobeSpring - 1) * 0.3
        }
        tiredLevel = BogMath.approach(tiredLevel, BogMath.clamp01(target), rate: 1.2, dt: CGFloat(dt))
        let h = CGFloat(hunger.isFinite ? hunger : 0)
        droop = BogMath.smoothstep(0.7, 1, BogMath.clamp01(h))

        let leanDeg = max(Double(cc) * TrapArt.toothMaxLean, TrapArt.slamLean * Double(slamLevel))
            + 40 * Double(tiredLevel) + 14 * Double(droop) * (1 - Double(slamLevel))
        lean = CGFloat(leanDeg * .pi / 180)
        let reach = TrapArt.toothReach(lean: lean) * spring
        let shut = max(cc, slamLevel)
        // Foreshortened by the hinge (up to 15 %), squeezed to 0.6 by the bite, springing back past 1 on re-arm.
        let foreshorten = 1 - TrapArt.lobeSquash * cc
        let squeeze = 1 - (1 - TrapArt.slamSqueeze) * slamLevel
        lobeScale = min(foreshorten, squeeze) * lobeSpring * (1 + wobble) * (1 - 0.02 * droop)
        let shadeK = max(cc, 0.65 * slamLevel, 0.55 * tiredLevel)
        let narrow = 0.95 * BogMath.smoothstep(0.02, 0.6, shadeK)
        let wide = 0.6 * BogMath.smoothstep(0.45, 1, shadeK)
        let darkTeeth = min(0.32 * cc * (1 - slamLevel) + 0.25 * tiredLevel + 0.2 * droop + 0.35 * night, 0.7)
        let shimmer = CGFloat(0.05 * sin(time * 1.3))
        overlayAlpha = min(max(tintAlpha, 0), 0.25)
        let toothTint = UIColor(red: 0.07 * (1 - night) + 0.08 * night, green: 0.2 * (1 - night) + 0.1 * night,
                                blue: 0.1 * (1 - night) + 0.3 * night, alpha: 1)
        for s in sides {
            let sx = CGFloat(s.side)
            s.node.xScale = lobeScale
            s.node.yScale = 1 - 0.015 * droop
            s.shadeNarrow.alpha = narrow
            s.shadeNarrow.isHidden = narrow < 0.005
            s.shadeWide.alpha = wide
            s.shadeWide.isHidden = wide < 0.005
            s.overlay.color = tint
            s.overlay.alpha = overlayAlpha
            s.overlay.isHidden = overlayAlpha < 0.005
            let wiltA = 0.2 * droop + 0.12 * tiredLevel
            s.wilt.alpha = wiltA
            s.wilt.isHidden = wiltA < 0.005
            s.gloss.position = CGPoint(x: -sx * 18 * shut, y: -6 * shut)
            s.gloss.alpha = max(0.75 - 0.4 * shut - 0.3 * tiredLevel - 0.3 * droop + shimmer, 0.1)
            let glowA = 0.16 * night + 0.07 * dusk
            s.glow.alpha = glowA
            s.glow.isHidden = glowA < 0.005
            if slamLevel > 0.001 {
                s.jaw.isHidden = false
                s.jaw.alpha = slamLevel
                s.jaw.setScale(1 + 0.5 * (1 - sweep))
            } else if !s.jaw.isHidden {
                s.jaw.isHidden = true
                s.jaw.alpha = 0
            }
            let ji = BogArt.jawInner
            for (i, t) in s.teeth.enumerated() {
                t.yScale = reach
                t.color = toothTint
                t.colorBlendFactor = darkTeeth
                // Mid-bite, the teeth whose roots the far lobe covers (top and bottom: the lobe squeezes in x only)
                // tuck under it; the rest interlock at the squeezed edge.
                if slamLevel > 0.001, i < s.rootNorm.count {
                    let q = s.rootNorm[i]
                    let nx = q.x * lobeScale
                    let r = (nx * nx + q.y * q.y).squareRoot()
                    t.alpha = 1 - slamLevel * BogMath.smoothstep(ji + 0.04, ji + 0.16, r)
                } else {
                    t.alpha = 1
                }
            }
        }
        midrib.color = tint
        midrib.colorBlendFactor = overlayAlpha * 0.8
    }
}
