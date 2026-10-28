import CoreGraphics
import SpriteKit
import UIKit

/// Sets a sprite's size with its own scale reset to 1 first. **R2 (the streak artefact):** SpriteKit's `size` is the
/// *scaled* size, so setting it while `yScale` is 0.001 (folded wings) stored a 1000 × taller sprite, and a pooled bug
/// reused later drew its wings as a 600–1100 pt pale streak. Every pooled sprite is resized through this.
@MainActor
func bogResize(_ s: SKSpriteNode, _ size: CGSize) {
    s.xScale = 1
    s.yScale = 1
    s.size = size
}

/// One bug on screen: its sprites (body, wings, wing blur, sip ring, protected ring, glow, white flash) under a root
/// that carries position, heading and lift; its shadow and "cross" mark live in the layer (they never rotate).
@MainActor
final class BogBugNode {
    let root: SKNode
    let body: SKSpriteNode
    let wings: SKSpriteNode
    let blur: SKSpriteNode
    let halo: SKSpriteNode
    let ring: SKSpriteNode
    let glow: SKSpriteNode
    let flash: SKSpriteNode
    let shadow: SKSpriteNode
    let mark: SKSpriteNode

    private(set) var species: BugSpecies = .housefly
    private(set) var radius: CGFloat = 14
    private(set) var style: TrapBugStyle = TrapArt.bugStyle(.housefly)
    var id: Int = -1
    /// A fixed per-bug offset for bobs, pulses and blinks (QA-1 #19: never the flap accumulator).
    var phase: CGFloat = 0
    /// The wing-flap accumulator (advances only while flying).
    var flapPhase: CGFloat = 0
    var catchPoint: CGPoint?
    /// The height it was drawn at when it was caught (QA-1 #21: eased to 0 over the gulp, never dropped at once).
    var catchHeight: CGFloat = 0
    var lastHeight: CGFloat = 0
    var sipLevel: CGFloat = 0
    var markLevel: CGFloat = 0
    /// Frames of white flash left (2 when caught).
    var flashFrames = 0
    var seen: Int = 0
    /// The point drawn this frame (scene space).
    var drawnPoint: CGPoint = .zero
    /// R5 (#15): how much of the airborne cue it shows now (0 … 1 right over the crease), and its shadow's offset from
    /// the bug's ground point.
    var creaseCue: CGFloat = 0
    var shadowOffset: CGPoint = .zero
    /// R6 (#7): the clearance nudge drawn now (eased towards `BogBugLayer.clearOffset`), and whether it has been set
    /// once (a new bug takes its first nudge at once).
    var nudge: CGPoint = .zero
    var nudged = false
    /// R7 (#4): sitting (walking, sipping) on the last frame, and its footprint half-size (halo included).
    var sitting = false
    var footHalf: CGFloat = 0
    /// R6 (FEAST): this caught bug waits `gulpDelay` s (held in the closing jaws, over the closed trap) and is then
    /// gulped into the midrib; `gulped` once it is in.
    var feastGulp = false
    var gulpDelay: Double = 0
    var gulped = false
    /// R8: how hard it panics now (0 … 1: a sitter in the closing trap), and the visual-only jitter it is drawn with.
    var panic: CGFloat = 0
    var jitter: CGPoint = .zero

    /// Every sprite under `root` (the streak test checks each one's frame).
    var parts: [SKSpriteNode] { [halo, ring, body, wings, blur, glow, flash] }

    init() {
        let r = SKNode()
        let b = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        let w = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        let bl = SKSpriteNode(texture: BogTextures.soft, size: CGSize(width: 10, height: 10))
        let h = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        let rg = SKSpriteNode(texture: BogTextures.ring, size: CGSize(width: 10, height: 10))
        let gl = SKSpriteNode(texture: BogTextures.glow, size: CGSize(width: 10, height: 10))
        let fl = SKSpriteNode(texture: nil, size: CGSize(width: 10, height: 10))
        let sh = SKSpriteNode(texture: BogTextures.shadow, size: CGSize(width: 10, height: 10))
        let mk = SKSpriteNode(texture: BogTextures.anger, size: CGSize(width: 16, height: 16))
        root = r
        body = b
        wings = w
        blur = bl
        halo = h
        ring = rg
        glow = gl
        flash = fl
        shadow = sh
        mark = mk
        h.zPosition = -0.8
        rg.zPosition = -0.7
        b.zPosition = 0
        w.zPosition = 0.3
        bl.zPosition = 0.35
        gl.zPosition = 0.5
        fl.zPosition = 0.6
        for n in [h, rg, b, w, bl, gl, fl] { r.addChild(n) }
        bl.blendMode = .alpha
        bl.color = .white
        bl.colorBlendFactor = 1
        rg.color = BogPaint.ui(TrapArt.sipRing)
        rg.colorBlendFactor = 1
        gl.blendMode = .add
        gl.colorBlendFactor = 1
        fl.isHidden = true
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
        root.setScale(1)
        root.zRotation = 0
        let side = BogTextures.bugSide(radius: r)
        body.texture = BogTextures.bug(s, radius: r)
        bogResize(body, CGSize(width: side, height: side))
        wings.texture = BogTextures.wings(s, radius: r)
        bogResize(wings, CGSize(width: side, height: side))
        flash.texture = BogTextures.bugSilhouette(s, radius: r)
        bogResize(flash, CGSize(width: side, height: side))
        flash.isHidden = true
        bogResize(blur, CGSize(width: r * 1.3, height: r * 2.5))
        blur.position = CGPoint(x: -r * 0.2, y: 0)
        // Protected bugs: a crisp ring (bees white, wasps red) and never the sip ring (R2 #7).
        if s.isProtected {
            halo.texture = BogTextures.protectedRing(s, radius: r)
            let ps = BogTextures.protectedRingSide(radius: r)
            bogResize(halo, CGSize(width: ps, height: ps))
            halo.isHidden = false
        } else {
            halo.texture = nil
            bogResize(halo, CGSize(width: 1, height: 1))
            halo.isHidden = true
        }
        bogResize(ring, CGSize(width: r * 2.5, height: r * 2.5))
        ring.isHidden = true
        bogResize(shadow, CGSize(width: r * 2.1, height: r * 1.6))
        let m = max(r * 0.7, 15)
        bogResize(mark, CGSize(width: m, height: m))
        switch s {
        case .firefly:
            glow.isHidden = false
            glow.color = BogPaint.ui(RGBA(hex: 0xD8FF5A))
            bogResize(glow, CGSize(width: r * 4, height: r * 4))
            glow.position = CGPoint(x: -0.66 * r, y: 0)
        case .goldenScarab:
            glow.isHidden = false
            glow.color = BogPaint.ui(TrapArt.palette.gold)
            bogResize(glow, CGSize(width: r * 3, height: r * 3))
            glow.position = .zero
        case .cricket:
            // R6 (#5): a moonlit sheen at night, so the night's crickets read on the dark trap.
            glow.isHidden = false
            glow.color = BogPaint.ui(BogBugLayer.moonGlint)
            bogResize(glow, CGSize(width: r * 3.2, height: r * 3.2))
            glow.position = .zero
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .bee, .bumblebee, .wasp:
            glow.isHidden = true
            bogResize(glow, CGSize(width: r, height: r))
            glow.position = .zero
        }
        phase = BogRNG.hash(id, 0xB06) * 2 * .pi
        flapPhase = phase
        catchPoint = nil
        catchHeight = 0
        lastHeight = 0
        sipLevel = 0
        markLevel = 0
        flashFrames = 0
        creaseCue = 0
        shadowOffset = .zero
        nudge = .zero
        nudged = false
        sitting = false
        footHalf = BogBugLayer.footprintHalf(s, radius: r)
        feastGulp = false
        gulpDelay = 0
        gulped = false
        panic = 0
        jitter = .zero
        root.isHidden = false
        shadow.isHidden = false
        mark.isHidden = true
        root.alpha = 1
    }

    func hide() {
        root.isHidden = true
        shadow.isHidden = true
        mark.isHidden = true
        flash.isHidden = true
        id = -1
    }

    /// The largest child sprite's frame (in the root's space), over the art radius (tests: ≤ 6).
    var extentRatio: CGFloat {
        var m: CGFloat = 0
        for p in parts where !p.isHidden {
            let f = p.frame
            m = max(m, max(f.width, f.height))
        }
        let sf = shadow.isHidden ? 0 : max(shadow.frame.width, shadow.frame.height)
        let mf = mark.isHidden ? 0 : max(mark.frame.width, mark.frame.height)
        return max(m, sf, mf) / max(radius, 1)
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
    /// R6 (#7): what bugs keep clear of (scene space): the HUD's corners (`BogScene.hudKeepOut`) and the canvas.
    var keepOut: [CGRect] = []
    var canvas = CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight)
    /// R6 (FEAST): the seam points where caught bugs were gulped this frame (the scene sparkles them).
    private(set) var gulps: [CGPoint] = []

    init() {
        let g = SKNode()
        let l = SKNode()
        ground = g
        layer = l
        g.zPosition = 22
        l.zPosition = 30
    }

    var liveCount: Int { live.count }

    /// The largest child frame over its bug's radius, across every live bug (the streak test).
    var maxExtentRatio: CGFloat {
        var m: CGFloat = 0
        for n in live.values { m = max(m, n.extentRatio) }
        return m
    }

    /// R7 (#4): Home's bog is decoration: every uncatchable bug there may be eased clear of Home's buttons (in play only
    /// flying, uncatchable bugs are). Set by `BogScene`.
    var decorative = false

    /// R7 (#4): a bug the next bite could take: in the trap and a bite candidate (`TrapRules.isCandidate`, Core's own
    /// rule). It is always drawn at its Core position.
    static func isCatchable(_ b: BugState) -> Bool {
        b.inTrap && TrapRules.isCandidate(b.activity, height: b.height)
    }

    /// R7 (#4, tests): bug `id`'s visual-only offset from its Core position now (zero for a catchable bug).
    func nudge(_ id: Int) -> CGPoint? { live[id]?.nudge }

    /// R7 (#4, tests, the CI probe): every sitting (walking, sipping) bug drawn now, as its footprint (halo included)
    /// about where it is drawn (scene space, unshaken).
    var sittingRects: [CGRect] {
        var out: [CGRect] = []
        for n in live.values where n.sitting && !n.root.isHidden && n.root.alpha > 0.01 {
            let h = n.footHalf
            out.append(CGRect(x: n.drawnPoint.x - h, y: n.drawnPoint.y - h, width: 2 * h, height: 2 * h))
        }
        return out
    }

    /// Bugs drawn with the white catch flash this frame (tests).
    var flashing: Int { live.values.filter { !$0.flash.isHidden }.count }

    /// Whether bug `id` shows the protected ring / the sip ring now (tests).
    func showsProtectedRing(_ id: Int) -> Bool { live[id].map { !$0.halo.isHidden } ?? false }
    func showsSipRing(_ id: Int) -> Bool { live[id].map { !$0.ring.isHidden } ?? false }

    /// The art radius: R1's radius × 1.8, or Core's `BugInfo.radius` when that is bigger (Core scales its radius by
    /// the same 1.8 in R2, so the two agree and nothing is scaled twice).
    func radius(_ s: BugSpecies) -> CGFloat {
        if let r = radii[s] { return r }
        let info = BugCatalog.info(s).radius
        let r = max(info, TrapArt.defaultRadius(s))
        radii[s] = r
        return r
    }

    /// Where a bug is drawn (nil when it is not on screen).
    func drawnPoint(_ id: Int) -> CGPoint? { live[id]?.drawnPoint }

    /// R4 (#6, tests): bug `id`'s global z and drawn scale now (nil when it is not on screen).
    func drawnZ(_ id: Int) -> CGFloat? { live[id].map { layer.zPosition + $0.root.zPosition } }
    func drawnScale(_ id: Int) -> CGFloat? { live[id].map { $0.root.yScale } }
    /// R5 (#15, tests): bug `id`'s airborne cue (0 … 1) and its shadow's offset from its ground point.
    func creaseCue(_ id: Int) -> CGFloat? { live[id].map { $0.creaseCue } }
    func shadowOffset(_ id: Int) -> CGPoint? { live[id].map { $0.shadowOffset } }
    /// R8 (tests): bug `id`'s panic now (0 … 1) and its visual-only jitter.
    func panicOf(_ id: Int) -> CGFloat? { live[id].map { $0.panic } }
    func jitterOf(_ id: Int) -> CGPoint? { live[id].map { $0.jitter } }
    /// R8 (tests): whether bug `id` is drawn at all now (root shown and not faded out).
    func isDrawn(_ id: Int) -> Bool { live[id].map { !$0.root.isHidden && $0.root.alpha > 0.01 } ?? false }

    /// R8: a panicking sitter's jitter at full panic, × its radius (visual only: Core keeps its position).
    static let panicJitter: CGFloat = 0.14

    /// R5 (#15): the airborne cue. Nothing ever rests on the hinge: a bug over the crease (its centre within
    /// `creaseHalfWidth` + 0.6 r of the midrib) is drawn lifted, `creaseScale` × bigger with its shadow pushed out by
    /// `creaseShadow`, easing off over one more radius.
    static let creaseScale: CGFloat = 1.1
    static let creaseShadow = CGPoint(x: 10, y: -8)
    static func creaseLift(dx: CGFloat, radius r: CGFloat) -> CGFloat {
        guard dx.isFinite else { return 0 }
        let band = ScreenLayout.creaseHalfWidth + 0.6 * max(r, 1)
        return 1 - BogMath.smoothstep(band, band + max(r, 1), abs(dx))
    }

    /// R4 (#6): a caught bug is in the seam this long after the bite (session seconds: the lobes' 60 ms squeeze).
    static let sinkTime: Double = 0.06
    /// The global z a caught bug is drawn at: just under the closed trap (z 16.5), over the lobes, the nectar (15)
    /// and its glistens (16).
    static let caughtZ: CGFloat = 16.2

    /// How far a caught bug has sunk into the seam `elapsed` s after the bite (0 … 1 at `sinkTime`, eased out).
    static func sinkLevel(_ elapsed: Double) -> CGFloat {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        let u = CGFloat(min(elapsed / sinkTime, 1))
        return 1 - (1 - u) * (1 - u)
    }

    /// Where a bug caught at `p` sinks to: on the seam (the midrib line), a little towards the middle, kept inside the
    /// closed trap's length.
    static func seamPoint(from p: CGPoint, geometry g: TrapGeometry) -> CGPoint {
        let reach = max(g.b - TrapArt.notchDepth - 16, 10)
        let y = p.y + (g.center.y - p.y) * 0.2
        return CGPoint(x: g.center.x, y: min(max(y, g.center.y - reach), g.center.y + reach))
    }

    /// A bug in the bite: it flashes white for 2 frames and squishes into the midrib from here (R6: from where it
    /// was drawn, its clearance nudge included, so it never jumps).
    func markCaught(_ id: Int, at p: CGPoint) {
        guard let n = live[id] else { return }
        if n.catchPoint == nil {
            n.catchPoint = CGPoint(x: p.x + n.nudge.x, y: p.y + n.nudge.y)
            n.catchHeight = n.lastHeight
        }
        n.flashFrames = 2
    }

    /// R6 (FEAST): caught bug `id` is gulped into the midrib `delay` s into its caught moment (one after another).
    func queueGulp(_ id: Int, delay: Double) {
        guard let n = live[id] else { return }
        n.feastGulp = true
        n.gulpDelay = max(delay, 0)
        n.gulped = false
    }

    /// R6 (tests): whether caught bug `id` is queued for a FEAST gulp, and whether it has been gulped.
    func gulpQueued(_ id: Int) -> Bool { live[id]?.feastGulp ?? false }
    func gulpDone(_ id: Int) -> Bool { live[id]?.gulped ?? false }

    /// R6 (FEAST): how long one gulp takes (s), and the global z a FEAST's caught bugs are drawn at (over the closed
    /// trap, z 16.5, so the gulps are seen).
    static let gulpTime: Double = 0.09
    static let feastZ: CGFloat = 17.2
    /// R6 (#5): the cricket's moonlit sheen.
    static let moonGlint = RGBA(hex: 0xC8D8FF)

    // MARK: R6 (#7) clearance

    /// How far a bug's footprint keeps inside the canvas edge, and off the HUD's corners (points).
    static let edgeGap: CGFloat = 6
    static let hudGap: CGFloat = 8
    /// How fast the drawn nudge follows its target (points per second).
    static let nudgeRate: CGFloat = 260

    /// A bug's footprint half-size: its protected ring (bees, wasps) or its art and wings.
    static func footprintHalf(_ s: BugSpecies, radius r: CGFloat) -> CGFloat {
        s.isProtected ? r * TrapArt.protectedRingScale + 4 : r * 1.25
    }

    /// R6 (#7): how far to push a bug in from one edge when its centre is `inside` points in from it and its footprint
    /// needs `margin`: all of the shortfall when `resting` (centre on screen), or eased in for a flyer
    /// (`(margin − inside) × smoothstep(0, margin, inside)`: 0 at the edge, monotonic, so it never stalls or pops).
    static func edgePush(_ inside: CGFloat, margin m: CGFloat, resting: Bool) -> CGFloat {
        guard inside < m, inside > 0, m > 0 else { return 0 }
        let need = m - inside
        return resting ? need : need * BogMath.smoothstep(0, m, inside)
    }

    /// R6 (#7): the cosmetic offset that keeps a bug at `p` (footprint half-size `half`, art radius `r`) clear:
    /// - of the canvas edge: its footprint (ring included) sits `edgeGap` inside. A `resting` bug (walking, sipping)
    ///   whose centre is on screen is pushed all the way in. A flying one is eased in (`edgePush`: nothing while its
    ///   centre is off screen, all of it once its centre is a footprint in), so a bug flying in never pops;
    /// - of the midrib, when `resting`: its centre `midribClearance` off it (Core's own rule, `creaseHalfWidth` + r +
    ///   16, or more for a wide halo: R7 #4, so a halo never sits on the crease band, in the trap or beyond it);
    /// - of every rect in `keepOut` (the HUD's plates; Home's buttons): pushed out to the nearest side that stays on
    ///   screen (resting: and off the midrib), by `gap` (default `hudGap`) more outside the trap. R7 (#4): a bug in the
    ///   trap is cleared of the plate itself too, and a centre still off the canvas is never pushed.
    /// `prefer` (the last frame's nudge) keeps a bug going out the way it went. Pure (tests). Caught bugs never move.
    static func clearOffset(at p: CGPoint, half: CGFloat, radius r: CGFloat, resting: Bool, keepOut: [CGRect],
                            canvas: CGSize, geometry g: TrapGeometry, hudGap gap: CGFloat? = nil,
                            prefer: CGPoint = .zero) -> CGPoint {
        clearance(at: p, half: half, radius: r, resting: resting, keepOut: keepOut, canvas: canvas, geometry: g,
                  hudGap: gap, prefer: prefer).offset
    }

    /// R7 (#4): `clearOffset`, and whether it found a clear spot: false when a keep-out has no way out that stays on
    /// screen (and, resting, off the midrib), e.g. a bumblebee's halo in Home's button column. (Visual only: Core's
    /// `TrapSession.keepOut` is the rule; this is for the uncatchable bugs the scene may still ease.)
    static func clearance(at p: CGPoint, half: CGFloat, radius r: CGFloat, resting: Bool, keepOut: [CGRect],
                          canvas: CGSize, geometry g: TrapGeometry, hudGap gap: CGFloat? = nil,
                          prefer: CGPoint = .zero) -> (offset: CGPoint, clear: Bool) {
        guard p.x.isFinite, p.y.isFinite else { return (.zero, true) }
        let outsideGap = max(gap ?? hudGap, 0)
        var isClear = true
        var d = CGPoint.zero
        let w = canvas.width, h = canvas.height
        let m = half + edgeGap
        d.x += edgePush(p.x, margin: m, resting: resting) - edgePush(w - p.x, margin: m, resting: resting)
        d.y += edgePush(p.y, margin: m, resting: resting) - edgePush(h - p.y, margin: m, resting: resting)
        // R7 (#4): a resting bug keeps its footprint (halo included) off the midrib band, in the trap or beyond it.
        let band = midribClearance(half: half, radius: r)
        if resting {
            let dx = p.x + d.x - g.center.x
            if abs(dx) < band {
                let side: CGFloat = dx < 0 ? -1 : 1
                d.x = g.center.x + side * band - p.x
            }
        }
        // R7 (#4): every keep-out (the HUD's plates, Home's buttons) clears the footprint: by `gap` more outside the
        // trap, exactly in it (the trap's zone never moves; only the drawing does). A flyer whose centre is still off
        // the canvas is left alone (it never pops on).
        let inTrap = g.normalizedRadius(p) <= 1
        let onCanvas = p.x >= 0 && p.x <= w && p.y >= 0 && p.y <= h
        let pad = half + (inTrap ? 0 : outsideGap)
        for rect in keepOut where onCanvas && !rect.isNull && rect.width > 0 && rect.height > 0 {
            let q = CGPoint(x: p.x + d.x, y: p.y + d.y)
            let box = rect.insetBy(dx: -pad, dy: -pad)
            guard box.contains(q) else { continue }
            // The nearest way out that keeps the footprint on screen (and, resting, off the midrib), favouring the way
            // it went last frame (`prefer`), so a bug walking across a plate never flips sides.
            let ways = [CGPoint(x: box.minX - q.x, y: 0), CGPoint(x: box.maxX - q.x, y: 0),
                        CGPoint(x: 0, y: box.minY - q.y), CGPoint(x: 0, y: box.maxY - q.y)]
            var best: CGPoint?
            var bestLen = CGFloat.greatestFiniteMagnitude
            for o in ways {
                let t = CGPoint(x: q.x + o.x, y: q.y + o.y)
                guard t.x >= m - 0.5, t.x <= w - m + 0.5, t.y >= m - 0.5, t.y <= h - m + 0.5 else { continue }
                if resting && abs(t.x - g.center.x) < band - 0.5 { continue }
                var len = abs(o.x) + abs(o.y)
                if o.x * prefer.x + o.y * prefer.y > 0 { len -= wayStickiness }
                if len < bestLen {
                    bestLen = len
                    best = o
                }
            }
            if let o = best {
                d.x += o.x
                d.y += o.y
            } else {
                isClear = false
            }
        }
        return (d, isClear)
    }

    /// R7 (#4): how far a resting bug's centre keeps off the midrib line: Core's own rule (`creaseHalfWidth` + r + 16),
    /// or further when its footprint (a bee's halo) is wider, so the halo never touches the crease band.
    static func midribClearance(half: CGFloat, radius r: CGFloat) -> CGFloat {
        ScreenLayout.creaseHalfWidth + max(r + 16, half + 2)
    }

    /// R7 (#4): how much shorter (points) the way out a bug took last frame counts, so it never flips sides mid-plate.
    static let wayStickiness: CGFloat = 160

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

    /// One frame. `time`/`dt` are wall clock (flaps, bobs). `squeeze` is the lobes' x scale (caught bugs ride with
    /// the bite). `hold` is the bite's hit-stop: nothing moves, only the white flash runs. R8: `panic` (0 … 1,
    /// `TrapArt.panicLevel`) makes the sitters in the trap buzz and jitter as the phone closes; `hideCaught` (hinge
    /// input) draws no caught bug at all (they were eaten as the phone shut, out of sight).
    func update(_ bugs: [BugState], time: Double, dt: Double, geometry g: TrapGeometry, night: CGFloat,
                tint: UIColor, tintAmount: CGFloat, reduceMotion: Bool, squeeze: CGFloat = 1, hold: Bool = false,
                panic: CGFloat = 0, hideCaught: Bool = false) {
        frame &+= 1
        gulps.removeAll(keepingCapacity: true)
        let fear = panic.isFinite ? min(max(panic, 0), 1) : 0
        if hold {
            // R4 (#6): the hit-stop freezes the crowd, but the caught bugs keep sinking into the seam (60 ms).
            for b in bugs {
                guard case .caught(_) = b.activity, let n = live[b.id] else { continue }
                draw(n, b, t: CGFloat(time), dt: 0, geometry: g, night: night, reduceMotion: reduceMotion,
                     squeeze: squeeze, panic: fear, hideCaught: hideCaught)
            }
            for n in live.values { applyFlash(n, tint: tint, tintAmount: tintAmount, night: night) }
            return
        }
        let t = CGFloat(time)
        let fdt = CGFloat(max(dt, 0))
        for b in bugs {
            let n = node(for: b)
            n.seen = frame
            draw(n, b, t: t, dt: fdt, geometry: g, night: night, reduceMotion: reduceMotion, squeeze: squeeze,
                 panic: fear, hideCaught: hideCaught)
            applyFlash(n, tint: tint, tintAmount: tintAmount, night: night)
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

    /// The catch flash (2 frames of white) or the light's tint (a colour blend, never a replacement).
    private func applyFlash(_ n: BogBugNode, tint: UIColor, tintAmount: CGFloat, night: CGFloat) {
        if n.flashFrames > 0 {
            n.flashFrames -= 1
            n.flash.isHidden = false
            n.flash.alpha = 1
        } else {
            n.flash.isHidden = true
        }
        // R6 (#5): the night's own bugs (fireflies, crickets) keep most of their colour, so they read in the trap.
        let nightBug = n.species == .firefly || n.species == .cricket
        let amount = max(tintAmount, 0) * (nightBug ? 1 - 0.7 * night : 1)
        n.body.color = tint
        n.body.colorBlendFactor = min(amount, 0.6)
        n.wings.color = tint
        n.wings.colorBlendFactor = amount
    }

    private func draw(_ n: BogBugNode, _ b: BugState, t: CGFloat, dt: CGFloat, geometry g: TrapGeometry,
                      night: CGFloat, reduceMotion: Bool, squeeze: CGFloat, panic: CGFloat, hideCaught: Bool) {
        let r = n.radius
        let st = n.style
        let ph = n.phase
        var pos = b.position
        var h = CGFloat(min(max(b.height, 0), 1))
        var rot = CGFloat(b.heading)
        var sx: CGFloat = 1, sy: CGFloat = 1
        var alpha: CGFloat = 1
        var flying = false
        var sipping = false
        var walking = false
        var released = false
        var caughtT: CGFloat = -1
        var caughtAge: Double = 0
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
            caughtAge = elapsed.isFinite ? min(max(elapsed, 0), 1) : 0
            caughtT = CGFloat(min(caughtAge / 0.5, 1))
        }
        let restless = CGFloat(min(max(b.restless, 0), 1))
        let motion: CGFloat = reduceMotion ? 0.5 : 1

        // Body life.
        if walking {
            sx *= 1 + 0.035 * sin(t * 16 + ph) * motion
            rot += 0.05 * sin(t * 16 + ph) * motion
        }
        if sipping {
            // Dipping its head into the drop (busy: "now's the time").
            rot += 0.06 * sin(t * 5 + ph) * motion
            sx *= 1 - 0.04 * max(0, sin(t * 6 + ph)) * motion
            sy *= 1 + 0.025 * sin(t * 10 + ph) * motion
        }
        if restless > 0.05 && !flying && caughtT < 0 {
            let burst: CGFloat = sin(t * 7.3 + ph) > 0.35 ? 1 : 0.2
            rot += 0.16 * restless * sin(t * 31 + ph) * burst * motion
        }
        if flying {
            pos.y += 1.6 * sin(t * 9 + ph) * motion
        }

        // R4 (#6): the gulp. A caught bug sinks into the seam within `sinkTime` (60 ms, the lobes' squeeze), under the
        // closed trap, so the shut trap never shows uneaten bugs on top of it. A cheeky gulp, never gore (4+): it
        // shrinks and spins in, whole, and is gone.
        var sunk: CGFloat = 0
        if caughtT >= 0 {
            n.sitting = false
            let start = n.catchPoint ?? CGPoint(x: b.position.x + n.nudge.x, y: b.position.y + n.nudge.y)
            if n.catchPoint == nil {
                n.catchPoint = start
                n.catchHeight = n.lastHeight
            }
            let seam = BogBugLayer.seamPoint(from: start, geometry: g)
            if n.feastGulp {
                // R6 (FEAST): held in the closing jaws (riding the squeeze, wriggling), over the closed trap, until
                // its turn; then gulped into the midrib in `gulpTime`, with a gold sparkle as it goes in.
                let local = caughtAge - n.gulpDelay
                let held = CGPoint(x: g.center.x + (start.x - g.center.x) * min(max(squeeze, 0.2), 1), y: start.y)
                if local < 0 {
                    pos = held
                    let wr = 1 + 0.07 * sin(t * 42 + ph) * motion
                    sx *= 0.9 * wr
                    sy *= 0.9 / wr
                    rot += 0.25 * sin(t * 31 + ph) * motion
                    h = 0
                } else {
                    let u = CGFloat(min(local / BogBugLayer.gulpTime, 1))
                    sunk = 1 - (1 - u) * (1 - u)
                    pos = BogMath.lerp(held, seam, sunk)
                    let shrink = 0.9 * (1 - 0.75 * sunk)
                    sx *= shrink
                    sy *= shrink
                    rot += 1.6 * .pi * sunk * sunk
                    alpha = 1 - BogMath.smoothstep(0.75, 1, u)
                    h = 0
                    if u >= 1 && !n.gulped {
                        n.gulped = true
                        gulps.append(seam)
                    }
                }
            } else {
                sunk = BogBugLayer.sinkLevel(caughtAge)
                pos = BogMath.lerp(start, seam, sunk)
                let shrink = (1 - 0.45 * sunk) * (1 - 0.4 * BogMath.smoothstep(0.06, 0.3, CGFloat(caughtAge)))
                let boing = 1 + 0.1 * sin(.pi * sunk)
                sx *= shrink * boing
                sy *= shrink * boing
                rot += 1.4 * .pi * sunk * sunk
                alpha = 1 - BogMath.smoothstep(0.1, 0.22, CGFloat(caughtAge))
                h = n.catchHeight * (1 - sunk)
            }
            // R8 (hinge): eaten as the phone shut; the reopen shows only the digest, never the bug.
            if hideCaught { alpha = 0 }
            n.panic = 0
            n.jitter = .zero
        } else {
            // R7 (#4, the founder's follow-up): Core decides where bugs rest (`TrapSession.keepOut`, which the Scene
            // feeds: `BogScene.coreKeepOut`), so the drawing is truthful. A catchable bug (in the trap and a bite
            // candidate) is drawn exactly where Core has it: never nudged, never hidden. The R6 visual-only easing
            // (clear of the HUD's plates and the canvas edge) is kept only for a flying bug that can't be caught, and
            // for Home's decoration (`decorative`); any other bug eases back to its Core position.
            let half = BogBugLayer.footprintHalf(b.species, radius: r)
            let resting = walking || sipping
            if BogBugLayer.isCatchable(b) {
                n.nudge = .zero
                n.nudged = true
            } else {
                let eased = flying || decorative
                let target = eased ? BogBugLayer.clearOffset(at: pos, half: half, radius: r, resting: resting,
                                                             keepOut: keepOut, canvas: canvas, geometry: g,
                                                             prefer: n.nudge) : CGPoint.zero
                if !n.nudged || reduceMotion {
                    n.nudge = target
                    n.nudged = true
                } else {
                    let k = BogBugLayer.nudgeRate
                    n.nudge = CGPoint(x: BogMath.approach(n.nudge.x, target.x, rate: k, dt: dt),
                                      y: BogMath.approach(n.nudge.y, target.y, rate: k, dt: dt))
                }
            }
            pos = CGPoint(x: pos.x + n.nudge.x, y: pos.y + n.nudge.y)
            // R8: a sitter in the closing trap panics: it jitters on the spot and twitches (visual only, a few
            // points; Core keeps its position and decides when it flees).
            let fear: CGFloat = b.inTrap && resting ? panic : 0
            n.panic = fear
            if fear > 0.001 {
                let amp = BogBugLayer.panicJitter * r * fear * motion
                let j = CGPoint(x: amp * sin(t * 47 + ph * 3.1), y: amp * sin(t * 59 + ph * 1.7 + 0.8))
                n.jitter = j
                pos = CGPoint(x: pos.x + j.x, y: pos.y + j.y)
                rot += 0.22 * fear * sin(t * 37 + ph) * motion
            } else {
                n.jitter = .zero
            }
            // (A walker still coming in from off the screen is not sitting yet.)
            let p0 = b.position
            n.sitting = resting && p0.x >= 0 && p0.x <= canvas.width && p0.y >= 0 && p0.y <= canvas.height
        }
        n.lastHeight = h

        // R5 (#15): over the crease it is always airborne (never resting on the hinge): 1.1× and its shadow pushed out.
        let cue = caughtT >= 0 ? 0 : BogBugLayer.creaseLift(dx: pos.x - g.center.x, radius: r)
        n.creaseCue = cue
        // Lift: drawn higher and larger the higher it flies.
        let lift = (1 + 0.32 * h) * (1 + (BogBugLayer.creaseScale - 1) * cue)
        let drawn = CGPoint(x: pos.x, y: pos.y + (10 + 0.35 * r) * h)
        n.drawnPoint = drawn
        n.root.position = drawn
        n.root.zRotation = rot
        n.root.xScale = max(sx * lift * stretch, 0.01)
        n.root.yScale = max(sy * lift, 0.01)
        n.root.alpha = alpha
        // Caught: under the closed trap (`caughtZ`), over the lobes and the nectar. Otherwise by height.
        let sinkZ = n.feastGulp ? BogBugLayer.feastZ : BogBugLayer.caughtZ
        n.root.zPosition = caughtT >= 0 ? sinkZ - layer.zPosition : 6 * max(h, 0.5 * cue)

        // Wings.
        var spread: CGFloat = st.restSpread
        var blurA: CGFloat = 0
        if flying && st.flapHz > 0 {
            n.flapPhase += dt * CGFloat(st.flapHz) * 2 * .pi * (reduceMotion ? 0.5 : 1)
            if n.flapPhase > 1000 { n.flapPhase -= 2 * .pi * 150 }
            spread = 0.35 + 0.65 * (0.5 + 0.5 * sin(n.flapPhase))
            if st.flapHz >= 20 { blurA = 0.26 }
        } else if caughtT < 0 && restless > 0.3 && st.restSpread > 0 {
            let flick = max(0, sin(t * 23 + ph))
            let f2 = flick * flick
            spread += 0.3 * restless * f2 * f2 * f2 * f2
        }
        if caughtT < 0 && !flying && n.panic > 0.01 && st.flapHz > 0 {
            // R8: panicking, the wings buzz half open (blurred on the fast fliers), ready to go.
            let buzz = 0.5 + 0.5 * sin(t * 88 + ph)
            spread = max(spread, st.restSpread + (0.25 + 0.45 * buzz) * n.panic)
            if st.flapHz >= 20 { blurA = max(blurA, 0.3 * n.panic) }
        }
        if caughtT >= 0 { spread = st.restSpread * (1 - caughtT) }
        spread = min(max(spread.isFinite ? spread : 0, 0), 1.2)
        n.wings.isHidden = spread < 0.03 || st.wing.a < 0.01
        n.wings.yScale = max(spread, 0.03)
        n.wings.xScale = 1
        n.blur.alpha = blurA
        n.blur.isHidden = blurA <= 0.001

        // The sip ring: lime-white under a catchable sipper (never on a bee or a wasp; gold is for nectar and score).
        let ringOn = sipping && !b.species.isProtected
        n.sipLevel = BogMath.approach(n.sipLevel, ringOn ? 1 : 0, rate: 5, dt: dt)
        n.ring.alpha = 0.9 * n.sipLevel
        n.ring.isHidden = n.sipLevel < 0.01
        if !n.ring.isHidden { n.ring.setScale(1 + 0.05 * sin(t * 4 + ph)) }

        // The protected ring: a steady crisp ring, a slow gentle pulse (QA-1 #19: the phase is fixed per bug).
        if b.species.isProtected && caughtT < 0 {
            n.halo.isHidden = false
            n.halo.alpha = 0.85 + 0.15 * sin(t * 3 + ph)
            n.halo.setScale(1 + 0.03 * sin(t * 3 + ph))
        } else {
            n.halo.isHidden = true
        }

        // Glow (fireflies at night; the scarab's shimmer).
        switch b.species {
        case .firefly:
            // R6 (#5): at night it blooms bigger and never blinks right out, so it reads in the trap.
            let blink = 0.55 + 0.45 * max(0, sin(t * 2.2 + ph))
            n.glow.alpha = min((0.35 + 0.65 * night) * (blink + 0.25 * night), 1) * alpha
            // R7 (#14): a bigger bloom at night (4 r × 1.45: inside the streak guard's 6 r).
            n.glow.setScale(1 + 0.45 * night)
        case .goldenScarab:
            n.glow.alpha = (0.28 + 0.14 * sin(t * 2.6 + ph)) * alpha
        case .cricket:
            n.glow.alpha = 0.42 * night * alpha
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .bee, .bumblebee, .wasp:
            break
        }

        // Shadow: on the ground below, offset down-right as it rises, softer and smaller.
        // R5 (#15): over the crease the shadow sits out by `creaseShadow` (at least), smaller and softer.
        let off = CGPoint(x: max(2 + 8 * h, BogBugLayer.creaseShadow.x * cue),
                          y: min(-2 - 5 * h, BogBugLayer.creaseShadow.y * cue))
        n.shadowOffset = off
        n.shadow.position = CGPoint(x: pos.x + off.x, y: pos.y + off.y)
        n.shadow.zRotation = CGFloat(b.heading)
        n.shadow.setScale(max((1 - 0.35 * h) * (1 - 0.15 * cue) * (caughtT >= 0 ? 1 - caughtT : 1), 0.01))
        n.shadow.alpha = 0.4 * (1 - 0.6 * h) * (1 - 0.25 * cue) * alpha * (1 - sunk)

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
