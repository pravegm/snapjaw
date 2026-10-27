import CoreGraphics
import SpriteKit
import UIKit

/// One lobe's nodes: the cached face, the closure shades, the gloss, the night glow, the slam jaw and the teeth.
/// The node's origin is the trap centre (the midrib); its xScale foreshortens the lobe towards the midrib.
@MainActor
final class BogLobeSide {
    let side: Int
    let node: SKNode
    let lobe: SKSpriteNode
    let shadeNarrow: SKSpriteNode
    let shadeWide: SKSpriteNode
    let gloss: SKSpriteNode
    let glow: SKSpriteNode
    let jaw: SKSpriteNode
    private(set) var teeth: [SKSpriteNode] = []
    private(set) var specs: [TrapTooth] = []

    init(side: Int) {
        self.side = side < 0 ? -1 : 1
        let n = SKNode()
        let lobeSize = BogTextures.lobeSize(reach: 1, pad: BogTextures.lobePad)
        let anchor = BogTextures.lobeAnchor(side: side)
        let l = SKSpriteNode(texture: BogTextures.lobe(side: side), size: lobeSize)
        let sn = SKSpriteNode(texture: BogTextures.lobeShadeNarrow(side: side), size: lobeSize)
        let sw = SKSpriteNode(texture: BogTextures.lobeShadeWide(side: side), size: lobeSize)
        let gl = SKSpriteNode(texture: BogTextures.gloss(side: side), size: lobeSize)
        let gw = SKSpriteNode(texture: BogTextures.lobeGlow(side: side), size: lobeSize)
        let jw = SKSpriteNode(texture: BogTextures.jaw(side: side),
                              size: BogTextures.lobeSize(reach: BogArt.jawOuter, pad: BogTextures.jawPad))
        node = n
        lobe = l
        shadeNarrow = sn
        shadeWide = sw
        gloss = gl
        glow = gw
        jaw = jw
        let layers: [(SKSpriteNode, CGFloat)] = [(l, 0), (sn, 1), (sw, 1.1), (gl, 2), (gw, 2.2), (jw, 3.5)]
        for (s, z) in layers {
            s.anchorPoint = anchor
            s.position = .zero
            s.zPosition = z
            n.addChild(s)
        }
        sn.alpha = 0
        sw.alpha = 0
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
        }
    }
}

/// The trap: two lobes on the fold, the midrib, the fold band. It follows the hinge (`closure01`), slams on a bite,
/// springs open on re-arm and droops when the trap is tired. Static art is cached; per frame only transforms and
/// alphas change.
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
    var reduceMotion = false

    private var slamClock: Double = -1
    private var springClock: Double = -1
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
        f.zPosition = -9
        f.color = .black
        f.colorBlendFactor = 1
        f.alpha = 0.22
        r.addChild(f)
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

    /// The bite: the teeth slam over and the far lobe's jaw sweeps in from the outer edges (60 ms), holds (120 ms)
    /// and lets go.
    func slam() {
        slamClock = 0
        sweep = 0
    }

    /// Re-armed: the teeth spring back out with a little overshoot.
    func rearm() {
        springClock = 0
    }

    func reset() {
        slamClock = -1
        springClock = -1
        slamLevel = 0
        sweep = 1
        tiredLevel = 0
        for s in sides {
            s.jaw.alpha = 0
            s.jaw.isHidden = true
        }
    }

    /// One frame. `fxDt` runs the moments (it is 0 while the session is frozen); `time` is the wall clock for
    /// shimmer.
    func update(fxDt: Double, closure01 c: CGFloat, tired target: CGFloat, time: Double, night: CGFloat,
                dusk: CGFloat) {
        let cc = BogMath.clamp01(c)
        drawnClosure = cc
        // The slam envelope.
        if slamClock >= 0 {
            slamClock += max(fxDt, 0)
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
        if springClock >= 0 {
            springClock += max(fxDt, 0)
            let t = CGFloat(springClock)
            if t < 0.6 {
                let td = Double(t)
                spring = 1 + CGFloat(0.16 * exp(-7 * td) * sin(26 * td))
            } else {
                springClock = -1
            }
        }
        tiredLevel = BogMath.approach(tiredLevel, BogMath.clamp01(target), rate: 1.2, dt: CGFloat(max(fxDt, 0)))

        let leanDeg = max(Double(cc) * TrapArt.toothMaxLean, TrapArt.slamLean * Double(slamLevel))
            + 40 * Double(tiredLevel)
        lean = CGFloat(leanDeg * .pi / 180)
        let reach = TrapArt.toothReach(lean: lean) * spring
        let shut = max(cc, slamLevel)
        let shadeK = max(cc, 0.65 * slamLevel, 0.55 * tiredLevel)
        let narrow = 0.85 * BogMath.smoothstep(0.02, 0.55, shadeK)
        let wide = 0.72 * BogMath.smoothstep(0.35, 1, shadeK)
        let darkTeeth = 0.32 * cc * (1 - slamLevel) + 0.25 * tiredLevel
        let shimmer = CGFloat(0.05 * sin(time * 1.3))
        for s in sides {
            let sx = CGFloat(s.side)
            s.node.xScale = 1 - TrapArt.lobeSquash * shut
            s.shadeNarrow.alpha = narrow
            s.shadeNarrow.isHidden = narrow < 0.005
            s.shadeWide.alpha = wide
            s.shadeWide.isHidden = wide < 0.005
            s.gloss.position = CGPoint(x: -sx * 18 * shut, y: -6 * shut)
            s.gloss.alpha = max(0.75 - 0.4 * shut - 0.3 * tiredLevel + shimmer, 0.1)
            let glowA = 0.16 * night + 0.07 * dusk
            s.glow.alpha = glowA
            s.glow.isHidden = glowA < 0.005
            if slamLevel > 0.001 {
                s.jaw.isHidden = false
                s.jaw.alpha = slamLevel
                s.jaw.setScale(1 + 0.16 * (1 - sweep))
            } else if !s.jaw.isHidden {
                s.jaw.isHidden = true
                s.jaw.alpha = 0
            }
            for t in s.teeth {
                t.yScale = reach
                t.colorBlendFactor = darkTeeth
            }
        }
    }
}
