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
    /// R6 (#17): the tired trap's dim, on the face only (the green margin and back keep their colour).
    let faceDim: SKSpriteNode
    let gloss: SKSpriteNode
    /// R3 (#10): the rim light (additive: gold morning, peach dusk, moonlight at night).
    let glow: SKSpriteNode
    private(set) var teeth: [SKSpriteNode] = []
    private(set) var specs: [TrapTooth] = []
    /// R6 (Golden Glow): twinkles on the rim (hidden for every other variety).
    private(set) var sparkles: [SKSpriteNode] = []
    private(set) var variety: TrapVariety = .classic

    init(side: Int) {
        self.side = side < 0 ? -1 : 1
        let n = SKNode()
        let lobeSize = BogTextures.lobeSize(reach: 1, pad: BogTextures.lobePad)
        let anchor = BogTextures.lobeAnchor(side: side)
        let l = SKSpriteNode(texture: BogTextures.lobe(side: side), size: lobeSize)
        let sn = SKSpriteNode(texture: BogTextures.lobeShadeNarrow(side: side), size: lobeSize)
        let sw = SKSpriteNode(texture: BogTextures.lobeShadeWide(side: side), size: lobeSize)
        let ov = SKSpriteNode(texture: BogTextures.lobeSilhouette(side: side), size: lobeSize)
        let wl = SKSpriteNode(texture: BogTextures.lobeFace(side: side), size: lobeSize)
        let fd = SKSpriteNode(texture: BogTextures.lobeFace(side: side), size: lobeSize)
        let gl = SKSpriteNode(texture: BogTextures.gloss(side: side), size: lobeSize)
        let gw = SKSpriteNode(texture: BogTextures.lobeGlow(side: side), size: lobeSize)
        node = n
        lobe = l
        shadeNarrow = sn
        shadeWide = sw
        overlay = ov
        wilt = wl
        faceDim = fd
        gloss = gl
        glow = gw
        let layers: [(SKSpriteNode, CGFloat)] = [(l, 0), (sn, 1), (sw, 1.1), (ov, 1.5), (wl, 1.6), (fd, 1.65),
                                                 (gl, 2), (gw, 2.2)]
        for (s, z) in layers {
            s.anchorPoint = anchor
            s.position = .zero
            s.zPosition = z
            n.addChild(s)
        }
        sn.alpha = 0
        sw.alpha = 0
        for s in [ov, wl, fd] {
            s.colorBlendFactor = 1
            s.color = .white
            s.alpha = 0
            s.isHidden = true
        }
        // R3 (#17): the hunger wilt is a plain grey veil. R6 (#17): it and the tired dim lie on the face only.
        wl.color = UIColor(white: 0.5, alpha: 1)
        fd.color = UIColor(red: 0.12, green: 0.01, blue: 0.04, alpha: 1)
        gw.blendMode = .add
        gw.colorBlendFactor = 1
        gw.alpha = 0
        gw.isHidden = true
        gl.alpha = 0.75
        buildTeeth()
        buildSparkles()
    }

    private func buildSparkles() {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        for p in TrapArt.sparkleSpots(side: side, geometry: g) {
            let s = SKSpriteNode(texture: BogTextures.sparkle, size: CGSize(width: 22, height: 22))
            s.blendMode = .add
            s.color = BogPaint.ui(TrapArt.palette.gold)
            s.colorBlendFactor = 0.35
            s.position = CGPoint(x: p.x - g.center.x, y: p.y - g.center.y)
            s.zPosition = 5
            s.alpha = 0
            s.isHidden = true
            node.addChild(s)
            sparkles.append(s)
        }
    }

    /// R6: re-dress the lobe and its cilia as `v` (textures are cached per variety; the sprites are reused).
    func apply(_ v: TrapVariety) {
        guard v != variety else { return }
        variety = v
        lobe.texture = BogTextures.lobe(side: side, variety: v)
        placeTeeth()
    }

    private func buildTeeth() {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        for _ in TrapArt.teeth(side: side, geometry: g) {
            let s = SKSpriteNode(texture: nil, size: CGSize(width: 4, height: 40))
            s.zPosition = 4
            s.color = UIColor(red: 0.07, green: 0.2, blue: 0.1, alpha: 1)
            s.colorBlendFactor = 0
            node.addChild(s)
            teeth.append(s)
        }
        placeTeeth()
    }

    /// Sizes and places every cilium for the current variety (its reference tooth, `BogArt.varietyToothTexSize`,
    /// mapped onto each `TrapTooth`).
    private func placeTeeth() {
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        let vl = TrapArt.look(variety)
        specs = TrapArt.teeth(side: side, geometry: g, variety: variety)
        let tex = BogArt.varietyToothTexSize(variety)
        let refW = BogArt.toothTexWidth * vl.toothWidth, refL = BogArt.toothTexLength * vl.toothLength
        for (i, t) in specs.enumerated() where i < teeth.count {
            let s = teeth[i]
            s.texture = BogTextures.tooth(curl: t.curl, variety: variety)
            bogResize(s, CGSize(width: tex.width * t.width / max(refW, 0.1),
                                height: tex.height * t.length / max(refL, 0.1)))
            s.anchorPoint = CGPoint(x: 0.5, y: BogArt.toothRootY / tex.height)
            s.position = CGPoint(x: t.root.x - g.center.x, y: t.root.y - g.center.y)
            s.zRotation = t.angle - .pi / 2
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
///
/// **R8 (the phone IS the trap):** with hinge input the scene never calls `slam()` and passes `closure01` 0, so the
/// lobes stay drawn open; the closure shows only through `cue` (the cilia lean, the rim shadow). Touch keeps the slam.
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
    /// R5 (#3): how dark the closure shades draw the face now (0 the open-state crimson … ~0.95), and how much of the
    /// darkness is the bite's own (it darkens only while closing and is gone `releaseFade` into the release).
    private(set) var faceShade: CGFloat = 0
    private(set) var closingLevel: CGFloat = 0
    /// R5 (#3): the open cilia's opacity now (1 out … 0 hidden under the closed trap).
    private(set) var teethAlpha: CGFloat = 1
    /// R5 (#3): how far the hinge's own darkening is held off after a bite (1 while the hands reopen; it lets go once
    /// they close again).
    private(set) var reopenHold: CGFloat = 0
    /// R6 (#17): the tired trap's dim on the face (the margin and back are never darkened by it), and the darkest any
    /// layer that covers the green margin is drawn now (the closure shades: 0 while the trap is open, tired or not).
    private(set) var faceDimAlpha: CGFloat = 0
    private(set) var marginShade: CGFloat = 0
    /// R6: the variety drawn (`BogScene.variety`), and its lobes' x scale about the midrib (B52 1.03).
    private(set) var variety: TrapVariety = .classic
    private(set) var spread: CGFloat = 1
    /// R6 (Golden Glow): the rim twinkles showing now.
    private(set) var sparklesShowing = 0
    /// R8 (hinge input): the closing cue drawn now (0 open … 1, `TrapArt.closingCue`) and the rim shadow it lays on
    /// the lobes. The cue never moves the lobes: it leans the cilia in, deepens the rim shadow and dims the rim light.
    private(set) var cueLevel: CGFloat = 0
    private(set) var rimShadow: CGFloat = 0
    private var glossBoost: CGFloat = 1
    private var sparkleOn = false
    var reduceMotion = false

    /// R4 (#6): the closed trap's one x scale (1 = the squeezed lobes' width, `TrapArt.slamSqueeze` of the open trap).
    static let holdWidthScale: CGFloat = 1
    /// When the slam's hold ends and the release begins (session seconds after the bite).
    static let holdEnd: Double = 0.18
    /// QA-2 #8: how fast the hunger droop lets go after a wilt (per second: ~0.6 s from full).
    static let droopRelease: CGFloat = 1 / 0.6
    /// R5 (#3): the face is back to its open-state crimson this long into the release (session seconds), the cilia
    /// out and the green rim showing; the closed trap is gone by `closedFade`.
    static let releaseFade: Double = 0.08
    static let closedFade: Double = 0.06
    /// R5 (#3): how far the hands must close again after a bite (closure01) before the hinge darkens the face again.
    static let reclose: CGFloat = 0.08

    private var slamClock: Double = -1
    /// R5 (#3): a bite happened and the hands haven't closed again since (the face never darkens on the reopen).
    private var afterBite = false
    private var reopenMin: CGFloat = 1
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

    /// R6: draw `v` (its textures are built here, once, never per frame).
    func setVariety(_ v: TrapVariety) {
        guard v != variety else { return }
        variety = v
        BogTextures.warm(variety: v)
        let vl = TrapArt.look(v)
        spread = vl.spread
        glossBoost = vl.gloss
        sparkleOn = vl.sparkle
        for s in sides { s.apply(v) }
        closed.texture = BogTextures.closedTrap(variety: v)
    }

    /// R6 (tests): every open cilium's projected tip in scene space (unshaken), from the drawn sprites.
    var drawnToothTips: [CGPoint] {
        var out: [CGPoint] = []
        let g = TrapGeometry(sceneSize: CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight))
        for s in sides {
            for (i, t) in s.specs.enumerated() where i < s.teeth.count && !s.teeth[i].isHidden {
                let reach = s.teeth[i].yScale
                let local = CGPoint(x: t.root.x - g.center.x + cos(t.angle) * t.length * reach,
                                    y: t.root.y - g.center.y + sin(t.angle) * t.length * reach)
                out.append(CGPoint(x: root.position.x + local.x * s.node.xScale,
                                   y: root.position.y + local.y * s.node.yScale))
            }
        }
        return out
    }

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
            for n in [s.lobe, s.shadeNarrow, s.shadeWide, s.overlay, s.wilt, s.faceDim, s.gloss, s.glow] { add(n) }
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
        afterBite = true
        reopenMin = 1
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
        afterBite = false
        reopenMin = 1
        reopenHold = 0
        closingLevel = 0
        faceShade = 0
        teethAlpha = 1
        cueLevel = 0
        rimShadow = 0
    }

    /// R5 (#3): the bite's own darkening `t` session seconds after it: it follows the slam while the jaws close and
    /// hold, and fades to nothing `releaseFade` into the release (the reopen is never dark).
    static func biteShade(slam: CGFloat, t: Double) -> CGFloat {
        guard t >= holdEnd else { return slam }
        let k = BogMath.smoothstep(0, CGFloat(releaseFade), CGFloat(t - holdEnd))
        return slam * (1 - k)
    }

    /// R5 (#3): the lobes' squeeze level (1 shut … 0 open) `t` s into the bite: an ease-out shut in 60 ms, the hold,
    /// then an ease-out release (≈ 60 % open 80 ms in), so the reopening trap is never a narrow dark shape.
    static func squeezeLevel(t: Double) -> CGFloat {
        if t < 0 { return 0 }
        if t < 0.06 {
            let u = CGFloat(t / 0.06)
            return 1 - (1 - u) * (1 - u)
        }
        if t < holdEnd { return 1 }
        let u = BogMath.clamp01(CGFloat((t - holdEnd) / (0.5 - holdEnd)))
        let o = 1 - (1 - u) * (1 - u) * (1 - u)
        return 1 - o
    }

    /// One frame. `fxDt` runs the moments (it is 0 while the session is frozen); `time` is the wall clock for
    /// shimmer. `hunger` is the snapshot's 0…1; `tint`/`tintAlpha` the day's overlay on the lobes, `rim`/`rimAlpha`
    /// the day's rim light. R8: `cue` is the hinge's closing cue (0 … 1; the scene passes `closure01` 0 with it, so
    /// the lobes stay drawn open and only the cues follow the hands).
    func update(fxDt: Double, closure01 c: CGFloat, tired target: CGFloat, hunger: CGFloat, time: Double,
                night: CGFloat, dusk: CGFloat, tint: UIColor, tintAlpha: CGFloat, rim: UIColor = .white,
                rimAlpha: CGFloat = 0, cue cueIn: CGFloat = 0) {
        let cc = BogMath.clamp01(c.isFinite ? c : 0)
        let cue = BogMath.clamp01(cueIn.isFinite ? cueIn : 0)
        let dt = max(fxDt, 0)
        drawnClosure = cc
        cueLevel = cue
        rimShadow = TrapArt.rimShadow(cue)
        // The slam envelope: shut in 60 ms (ease out), hold 120 ms, open by 0.5 s.
        var squeezeK: CGFloat = 0
        var releaseT: Double = -1
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
            if slamClock >= 0 {
                squeezeK = BogJaws.squeezeLevel(t: slamClock)
                closingLevel = BogJaws.biteShade(slam: slamLevel, t: slamClock)
                if slamClock >= BogJaws.holdEnd { releaseT = slamClock - BogJaws.holdEnd }
            } else {
                closingLevel = 0
            }
        } else {
            closingLevel = 0
        }
        // R5 (#3): after a bite the hinge's own darkening is held off while the hands reopen (or stay still); it comes
        // back only once they close again by `reclose`. Darkness tracks closing, never the reopen.
        if afterBite && (slamClock < 0 || slamClock >= BogJaws.holdEnd) {
            reopenMin = min(reopenMin, cc)
            if cc > reopenMin + BogJaws.reclose || cc < 0.02 { afterBite = false }
        }
        reopenHold = afterBite
            ? BogMath.approach(reopenHold, 1, rate: CGFloat(1 / BogJaws.releaseFade), dt: CGFloat(dt))
            : BogMath.approach(reopenHold, 0, rate: 1 / 0.15, dt: CGFloat(dt))
        let hingeK = cc * (1 - reopenHold)
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

        // R3 (#17): hungry teeth lean 20° (and tired ones 40°). R5 (#3): the bite leans them in only while it closes
        // and holds; they are back out `releaseFade` into the release, and the hinge's lean waits for a re-close.
        // R8: with the hinge the cilia lean in with the closing cue (the lobes themselves never move).
        let hingeLean: Double = Double(hingeK) * TrapArt.toothMaxLean
        let biteLean: Double = TrapArt.slamLean * Double(closingLevel)
        let cueTilt: Double = Double(cue) * TrapArt.cueLean
        let leanDeg = max(hingeLean, biteLean, cueTilt)
            + 40 * Double(tiredLevel) + 20 * Double(droop) * (1 - Double(closingLevel))
        lean = CGFloat(leanDeg * .pi / 180)
        let reach = TrapArt.toothReach(lean: lean) * spring
        let shut = max(hingeK, closingLevel)
        // Foreshortened by the hinge (up to 15 %), squeezed shut by the bite, springing back past 1 on re-arm.
        let foreshorten = 1 - TrapArt.lobeSquash * cc
        let squeeze = 1 - (1 - TrapArt.slamSqueeze) * squeezeK
        slamScale = squeeze
        lobeScale = min(foreshorten, squeeze) * lobeSpring * (1 + wobble) * (1 - 0.02 * droop)
        // R3 (#17): the hungry lobes droop to y 0.95, pinned at the midrib (the node's origin).
        lobeYScale = 1 - 0.05 * droop
        // R5 (#3): the closure shades darken the face only while closing (the hands or the bite), never on the reopen.
        // R6 (#17): tiredness no longer drives them (they cover the margin and back too: the R5 tired trap lost its
        // green rim); the tired trap dims its face only (`faceDim`).
        let shadeK = shut
        // R8: the hinge's rim shadow deepens with the closing cue (the narrow shade lies round the rim).
        let narrow = max(0.95 * BogMath.smoothstep(0.02, 0.6, shadeK), rimShadow)
        let wide = 0.6 * BogMath.smoothstep(0.45, 1, shadeK)
        marginShade = max(narrow, wide)
        faceDimAlpha = 0.42 * tiredLevel
        faceShade = max(narrow, wide, faceDimAlpha)
        let darkBase: CGFloat = 0.32 * hingeK * (1 - closingLevel) + 0.1 * tiredLevel + 0.25 * droop + 0.3 * night
        // R8: the cilia darken a little as they lean into the closing cue's shadow.
        let darkTeeth = min(darkBase + 0.3 * cue, 0.7)
        let shimmer = CGFloat(0.05 * sin(time * 1.3))
        overlayAlpha = min(max(tintAlpha, 0), 0.25)
        overlayColor = tint
        // R8: the cue dims the rim light, the gloss and the twinkles as the shut does.
        let dimK = max(shut, cue)
        rimLightAlpha = min(max(rimAlpha, 0), 0.8) * (1 - 0.7 * dimK)
        // At night the teeth go a deep blue-grey (never violet: the cream tips stay readable). QA-2 #19: one UIColor
        // per change of the night level, not per frame.
        if abs(night - toothTintNight) > 0.002 {
            toothTintNight = night
            toothTintColor = UIColor(red: 0.07 * (1 - night) + 0.1 * night, green: 0.2 * (1 - night) + 0.12 * night,
                                     blue: 0.1 * (1 - night) + 0.2 * night, alpha: 1)
        }
        let toothTint = toothTintColor
        // The open cilia fold in and hide under the closed trap as it shuts; R5 (#3): they are back out early in the
        // release (the outer fringe frames the reopening trap, so it never reads as a bare round shape).
        teethAlpha = 1 - BogMath.smoothstep(0.25, 0.75, closingLevel)
        let wiltA = 0.15 * droop + 0.12 * tiredLevel
        // R6 (Golden Glow): the rim twinkles, on the wall clock, gone while the jaws close.
        let twinkle = sparkleOn ? (1 - dimK) * (1 - 0.6 * tiredLevel) : 0
        sparklesShowing = 0
        for s in sides {
            let sx = CGFloat(s.side)
            s.node.xScale = lobeScale * spread
            s.faceDim.alpha = faceDimAlpha
            s.faceDim.isHidden = faceDimAlpha < 0.005
            for (i, k) in s.sparkles.enumerated() {
                let ph = CGFloat(i) * 1.7 + (s.side < 0 ? 0 : 0.9)
                let b = max(0, sin(CGFloat(time) * 1.9 + ph))
                let a = twinkle * (0.25 + 0.75 * b * b * b)
                k.alpha = a
                k.isHidden = a < 0.01
                if !k.isHidden {
                    sparklesShowing += 1
                    k.zRotation = CGFloat(time) * 0.6 + ph
                    k.setScale(0.7 + 0.5 * b)
                }
            }
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
            let glossA = max(0.75 - 0.45 * dimK - 0.3 * tiredLevel - 0.35 * droop + shimmer, 0.08)
            s.gloss.alpha = min(glossA * glossBoost, 1)
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
        // squeezed lobes', `TrapArt.slamSqueeze`), never stretched. R5 (#3): on the way out it is gone `closedFade`
        // (60 ms) into the release while the lobes spring open from under it, green rim and cilia showing.
        let show = releaseT >= 0
            ? 1 - BogMath.smoothstep(0, CGFloat(BogJaws.closedFade), CGFloat(releaseT))
            : (slamClock >= 0 ? BogMath.smoothstep(0.3, 0.85, slamLevel) : 0)
        if show > 0.005 {
            closed.isHidden = false
            closed.alpha = show
            closed.xScale = BogJaws.holdWidthScale * (1 - 0.02 * droop) * spread
            closed.yScale = lobeYScale
        } else if !closed.isHidden {
            closed.isHidden = true
            closed.alpha = 0
        }
        midrib.yScale = lobeYScale
        midrib.color = tint
        midrib.colorBlendFactor = overlayAlpha * 0.8
        shadow.xScale = max(lobeScale, 0.3) * spread
        shadow.yScale = lobeYScale
    }
}
