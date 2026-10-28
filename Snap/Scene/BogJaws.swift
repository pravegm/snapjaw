import CoreGraphics
import SpriteKit
import UIKit

/// One lobe's nodes: the cached face, the closure shades, the day's overlay, the hunger wilt, the gloss, the rim light
/// and the teeth under `node` (its origin is the trap centre, the midrib; its xScale foreshortens and squeezes the lobe
/// towards the midrib).
@MainActor
final class BogLobeSide {
    let side: Int
    let node: SKNode
    let lobe: SKSpriteNode
    let shadeNarrow: SKSpriteNode
    let shadeWide: SKSpriteNode
    let overlay: SKSpriteNode
    let wilt: SKSpriteNode
    let gloss: SKSpriteNode
    /// R3 (#10): the rim light (additive: gold morning, peach dusk, moonlight at night).
    let glow: SKSpriteNode
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
        let ov = SKSpriteNode(texture: BogTextures.lobeSilhouette(side: side), size: lobeSize)
        let wl = SKSpriteNode(texture: BogTextures.lobeSilhouette(side: side), size: lobeSize)
        let gl = SKSpriteNode(texture: BogTextures.gloss(side: side), size: lobeSize)
        let gw = SKSpriteNode(texture: BogTextures.lobeGlow(side: side), size: lobeSize)
        node = n
        lobe = l
        shadeNarrow = sn
        shadeWide = sw
        overlay = ov
        wilt = wl
        gloss = gl
        glow = gw
        let layers: [(SKSpriteNode, CGFloat)] = [(l, 0), (sn, 1), (sw, 1.1), (ov, 1.5), (wl, 1.6), (gl, 2),
                                                 (gw, 2.2)]
        for (s, z) in layers {
            s.anchorPoint = anchor
            s.position = .zero
            s.zPosition = z
            n.addChild(s)
        }
        sn.alpha = 0
        sw.alpha = 0
        for s in [ov, wl] {
            s.colorBlendFactor = 1
            s.color = .white
            s.alpha = 0
            s.isHidden = true
        }
        // R3 (#17): the hunger wilt is a plain grey veil.
        wl.color = UIColor(white: 0.5, alpha: 1)
        gw.blendMode = .add
        gw.colorBlendFactor = 1
        gw.alpha = 0
        gw.isHidden = true
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

/// The trap: two lobes on the fold, the midrib, the fold band, the trap's shadow. It follows the hinge (`closure01`),
/// snaps shut on a bite, springs open on re-arm, droops when hungry and when the trap is tired. Static art is cached;
/// per frame only transforms, colours and alphas change.
///
/// **R3 (#1) the bite**: both lobes squeeze to `TrapArt.slamSqueeze` about the midrib in 60 ms while the closed trap
/// (`BogTextures.closedTrap`: margins meeting over a dark interior, the cilia interlocked) fades in over them; the open
/// cilia fold in and hide. It holds 120 ms and lets go. Nothing is drawn outside the open trap's outline (SceneTests).
@MainActor
final class BogJaws {
    /// At the trap centre (scene z 10).
    let root: SKNode
    let midrib: SKSpriteNode
    /// The crease across the whole scene height (only with a real fold).
    let foldBand: SKSpriteNode
    /// R3: the closed trap (the bite's hold).
    let closed: SKSpriteNode
    /// R3: the trap's soft shadow on the bog (it squeezes with the lobes, so the bite never leaves a dark ghost).
    let shadow: SKSpriteNode
    private let sides: [BogLobeSide]

    /// The slam's level (0 none … 1 shut) and the lean the teeth are drawn at (radians).
    private(set) var slamLevel: CGFloat = 0
    private(set) var drawnClosure: CGFloat = 0
    private(set) var lean: CGFloat = 0
    private(set) var tiredLevel: CGFloat = 0
    /// How hungry the trap looks (0 fed … 1 about to wilt a snap): the lobes droop and grey a little.
    private(set) var droop: CGFloat = 0
    /// The lobes' x scale now (1 open, 0.85 at the snap depth, `slamSqueeze` mid-bite); caught bugs ride with it.
    private(set) var lobeScale: CGFloat = 1
    /// The bite's own squeeze (1 … `slamSqueeze`), without the hinge's foreshortening: the nectar and the hairs ride
    /// with it (they stay under the bugs that sip them while the hinge closes).
    private(set) var slamScale: CGFloat = 1
    /// The lobes' y scale now (the hunger droop: 0.95 at its deepest).
    private(set) var lobeYScale: CGFloat = 1
    /// The day's overlay alpha on the lobes (tests: the trap stays crimson).
    private(set) var overlayAlpha: CGFloat = 0
    /// The day's overlay colour on the lobes.
    private(set) var overlayColor: UIColor = .white
    /// The rim light's alpha (R3 #10: dusk shows).
    private(set) var rimLightAlpha: CGFloat = 0
    var reduceMotion = false

    /// R4 (#6): the closed trap's one x scale (1 = the squeezed lobes' width, `TrapArt.slamSqueeze` of the open trap).
    static let holdWidthScale: CGFloat = 1
    /// When the slam's hold ends and the release begins (session seconds after the bite).
    static let holdEnd: Double = 0.18
    /// QA-2 #8: how fast the hunger droop lets go after a wilt (per second: ~0.6 s from full).
    static let droopRelease: CGFloat = 1 / 0.6

    private var slamClock: Double = -1
    private var springClock: Double = -1
    private var rumbleClock: Double = -1
    private var toothTintNight: CGFloat = -1
    private var toothTintColor = UIColor(red: 0.07, green: 0.2, blue: 0.1, alpha: 1)

    init() {
        let r = SKNode()
        let m = SKSpriteNode(texture: BogTextures.midrib, size: BogTextures.midribSize)
        let f = SKSpriteNode(texture: BogTextures.foldBand,
                             size: CGSize(width: 2 * ScreenLayout.creaseHalfWidth, height: ScreenLayout.canvasHeight))
        let c = SKSpriteNode(texture: BogTextures.closedTrap, size: BogTextures.closedSize)
        let sh = SKSpriteNode(texture: BogTextures.trapShadow, size: BogTextures.trapShadowSize)
        root = r
        midrib = m
        foldBand = f
        closed = c
        shadow = sh
        sides = [BogLobeSide(side: -1), BogLobeSide(side: 1)]
        r.zPosition = 10
        // Under the lobes, over the bog (scene z 2: under the day's multiply tint at 5).
        sh.zPosition = -8
        sh.position = CGPoint(x: 4, y: -10)
        sh.color = UIColor(red: 0, green: 0.03, blue: 0.01, alpha: 1)
        sh.colorBlendFactor = 1
        sh.alpha = 0.62
        r.addChild(sh)
        for s in sides {
            s.node.zPosition = 0
            r.addChild(s.node)
        }
        m.zPosition = 3
        r.addChild(m)
        // The closed trap covers the squeezed lobes, the midrib, their folded cilia, the nectar and the glistens (scene
        // z 16.5), under the bugs.
        c.zPosition = 6.5
        c.alpha = 0
        c.isHidden = true
        r.addChild(c)
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

    /// The closed trap's opacity now (tests: it shows in the bite's hold).
    var closedAlpha: CGFloat { closed.isHidden ? 0 : closed.alpha }
    /// R4 (#6): the closed trap's drawn width now (scene points; 0 when hidden). One width through every hold.
    var closedWidth: CGFloat { closed.isHidden ? 0 : closed.frame.width }
    /// R4 (#6): the closed trap's global z (caught bugs sink just under it).
    var closedZ: CGFloat { root.zPosition + closed.zPosition }

    /// R3 (#1, tests): the frame (scene space, unshaken) of everything the trap draws now that is visible: the lobes and
    /// their layers, the teeth, the midrib and the closed trap (not the fold band, the shadow or the petiole).
    var drawnFrame: CGRect {
        var box = CGRect.null
        func add(_ n: SKNode) {
            guard !n.isHidden, n.alpha > 0.01, let parent = n.parent else { return }
            let f = n.frame
            for p in [CGPoint(x: f.minX, y: f.minY), CGPoint(x: f.maxX, y: f.minY), CGPoint(x: f.minX, y: f.maxY),
                      CGPoint(x: f.maxX, y: f.maxY)] {
                let q = parent.convert(p, to: root)
                let s = CGPoint(x: root.position.x + q.x, y: root.position.y + q.y)
                box = box.union(CGRect(origin: s, size: .zero))
            }
        }
        for s in sides {
            for n in [s.lobe, s.shadeNarrow, s.shadeWide, s.overlay, s.wilt, s.gloss, s.glow] { add(n) }
            for t in s.teeth { add(t) }
        }
        add(midrib)
        add(closed)
        return box
    }

    func layout(_ g: TrapGeometry, sceneHeight: CGFloat, hasFold: Bool) {
        root.position = g.center
        foldBand.size = CGSize(width: 2 * ScreenLayout.creaseHalfWidth, height: sceneHeight + 160)
        foldBand.position = .zero
        foldBand.isHidden = !hasFold
    }

    /// The bite: the lobes squeeze shut about the midrib (60 ms), hold (120 ms) and let go.
    func slam() {
        slamClock = 0
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
        tiredLevel = 0
        droop = 0
        lobeScale = 1
        slamScale = 1
        lobeYScale = 1
        closed.alpha = 0
        closed.isHidden = true
    }

    /// One frame. `fxDt` runs the moments (it is 0 while the session is frozen); `time` is the wall clock for
    /// shimmer. `hunger` is the snapshot's 0…1; `tint`/`tintAlpha` the day's overlay on the lobes, `rim`/`rimAlpha`
    /// the day's rim light.
    func update(fxDt: Double, closure01 c: CGFloat, tired target: CGFloat, hunger: CGFloat, time: Double,
                night: CGFloat, dusk: CGFloat, tint: UIColor, tintAlpha: CGFloat, rim: UIColor = .white,
                rimAlpha: CGFloat = 0) {
        let cc = BogMath.clamp01(c.isFinite ? c : 0)
        let dt = max(fxDt, 0)
        drawnClosure = cc
        // The slam envelope: shut in 60 ms (ease out), hold 120 ms, open by 0.5 s.
        if slamClock >= 0 {
            slamClock += dt
            let t = CGFloat(slamClock)
            if t < 0.06 {
                let u = t / 0.06
                slamLevel = 1 - (1 - u) * (1 - u)
            } else if t < 0.18 {
                slamLevel = 1
            } else if t < 0.5 {
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
        // QA-2 #8: the droop follows hunger up at once, but a wilt (hunger 1 → 0) lets it go over ~0.6 s, never in
        // one frame.
        let droopTarget = BogMath.smoothstep(0.7, 1, BogMath.clamp01(h))
        droop = droopTarget >= droop ? droopTarget
            : BogMath.approach(droop, droopTarget, rate: BogJaws.droopRelease, dt: CGFloat(dt))

        // R3 (#17): hungry teeth lean 20° (and tired ones 40°).
        let leanDeg = max(Double(cc) * TrapArt.toothMaxLean, TrapArt.slamLean * Double(slamLevel))
            + 40 * Double(tiredLevel) + 20 * Double(droop) * (1 - Double(slamLevel))
        lean = CGFloat(leanDeg * .pi / 180)
        let reach = TrapArt.toothReach(lean: lean) * spring
        let shut = max(cc, slamLevel)
        // Foreshortened by the hinge (up to 15 %), squeezed shut by the bite, springing back past 1 on re-arm.
        let foreshorten = 1 - TrapArt.lobeSquash * cc
        let squeeze = 1 - (1 - TrapArt.slamSqueeze) * slamLevel
        slamScale = squeeze
        lobeScale = min(foreshorten, squeeze) * lobeSpring * (1 + wobble) * (1 - 0.02 * droop)
        // R3 (#17): the hungry lobes droop to y 0.95, pinned at the midrib (the node's origin).
        lobeYScale = 1 - 0.05 * droop
        let shadeK = max(cc, slamLevel, 0.55 * tiredLevel)
        let narrow = 0.95 * BogMath.smoothstep(0.02, 0.6, shadeK)
        let wide = 0.6 * BogMath.smoothstep(0.45, 1, shadeK)
        let darkTeeth = min(0.32 * cc * (1 - slamLevel) + 0.25 * tiredLevel + 0.25 * droop + 0.3 * night, 0.7)
        let shimmer = CGFloat(0.05 * sin(time * 1.3))
        overlayAlpha = min(max(tintAlpha, 0), 0.25)
        overlayColor = tint
        rimLightAlpha = min(max(rimAlpha, 0), 0.8) * (1 - 0.7 * shut)
        // At night the teeth go a deep blue-grey (never violet: the cream tips stay readable). QA-2 #19: one UIColor
        // per change of the night level, not per frame.
        if abs(night - toothTintNight) > 0.002 {
            toothTintNight = night
            toothTintColor = UIColor(red: 0.07 * (1 - night) + 0.1 * night, green: 0.2 * (1 - night) + 0.12 * night,
                                     blue: 0.1 * (1 - night) + 0.2 * night, alpha: 1)
        }
        let toothTint = toothTintColor
        // The open cilia fold in and hide under the closed trap as it shuts.
        let teethAlpha = 1 - BogMath.smoothstep(0.25, 0.75, slamLevel)
        let wiltA = 0.15 * droop + 0.12 * tiredLevel
        for s in sides {
            let sx = CGFloat(s.side)
            s.node.xScale = lobeScale
            s.node.yScale = lobeYScale
            s.shadeNarrow.alpha = narrow
            s.shadeNarrow.isHidden = narrow < 0.005
            s.shadeWide.alpha = wide
            s.shadeWide.isHidden = wide < 0.005
            s.overlay.color = tint
            s.overlay.alpha = overlayAlpha
            s.overlay.isHidden = overlayAlpha < 0.005
            s.wilt.alpha = wiltA
            s.wilt.isHidden = wiltA < 0.005
            s.gloss.position = CGPoint(x: -sx * 18 * shut, y: -6 * shut)
            s.gloss.alpha = max(0.75 - 0.45 * shut - 0.3 * tiredLevel - 0.35 * droop + shimmer, 0.08)
            s.glow.color = rim
            s.glow.alpha = rimLightAlpha
            s.glow.isHidden = rimLightAlpha < 0.005
            for t in s.teeth {
                t.yScale = reach
                t.color = toothTint
                t.colorBlendFactor = darkTeeth
                t.alpha = teethAlpha
                t.isHidden = teethAlpha < 0.01
            }
        }
        // The closed trap: it fades in over the squeezing lobes and droops with them. R4 (#6): always one width (the
        // squeezed lobes', `TrapArt.slamSqueeze`), never stretched; on the way out it fades in the first ~70 ms of the
        // release while the lobes spring open from under it.
        let releasing = slamClock >= BogJaws.holdEnd
        let show = releasing ? BogMath.smoothstep(0.72, 0.95, slamLevel) : BogMath.smoothstep(0.3, 0.85, slamLevel)
        if show > 0.005 {
            closed.isHidden = false
            closed.alpha = show
            closed.xScale = BogJaws.holdWidthScale * (1 - 0.02 * droop)
            closed.yScale = lobeYScale
        } else if !closed.isHidden {
            closed.isHidden = true
            closed.alpha = 0
        }
        midrib.yScale = lobeYScale
        midrib.color = tint
        midrib.colorBlendFactor = overlayAlpha * 0.8
        shadow.xScale = max(lobeScale, 0.3)
        shadow.yScale = lobeYScale
    }
}
