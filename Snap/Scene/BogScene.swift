import CoreGraphics
import Foundation
import QuartzCore
import SpriteKit
import UIKit

/// The SpriteKit view of the bog (ARCHITECTURE "Scene API"). It draws only from `driver.advance` snapshots and events
/// and owns the cosmetic state: wing flaps, shadows, the nectar spray, the jaw slam, dew, light, the camera punch and
/// the score pops. It never changes game state; every touch goes to `driver.sceneTapped(at:time:)` in scene space.
///
/// Composition (scene space: origin bottom-left, y up; the trap is centred, the extra width on long phones is bog):
/// - world (camera punch: scaled about the scene centre)
///   - shaker (the bite's shake)
///     - backdrop (z 0: the cached bog with a 24 pt bleed, the trap's shadow) · light tint (z 5, multiply: bog only) ·
///       lift (z 6, add) and R5's dusk sky glow (z 6.5, add, a ramp from the top): bog only
///     - jaws (z 10: the trap's shadow at 2, two lobes with their thin backs, the day overlay and the rim light, the
///       midrib at 13, the teeth at 14, the closed trap at 16.5 (the bite's hold), the fold band at 1)
///     - surface (z 15: nectar drops, trigger hairs) · decals (z 16: nectar glistens)
///     - haze (z 21, add) · dew twinkles and night fireflies (z 21.5)
///     - bug shadows (z 22) · landing ripples (z 23) · bugs (z 30) · nectar night glow (z 41)
///     - FX (z 50: spray, sparkles, whiffs, startles) · score pops (z 60)
/// - the economy's glyph flights (z 62, never shaken: they land on the HUD's snaps row)
/// - vignette (z 70, never shaken)
///
/// **Clocks.** Moments (the slam, FX, pops, the punch) run on the session's clock (snapshot time), so a pause or a
/// CI freeze holds them at that instant; ambient life (flaps, bobs, twinkles, fireflies) runs on the wall clock, so a
/// still frame still breathes. **The bite's hit-stop** (50 ms of session time) freezes the bugs, FX and pops while the
/// jaws slam and the caught bugs flash white.
@MainActor
final class BogScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no shake or camera punch, gentler bobs, fewer particles.
    var reduceMotion: Bool = false {
        didSet {
            effects.reduceMotion = reduceMotion
            jaws.reduceMotion = reduceMotion
            economy.reduceMotion = reduceMotion
        }
    }

    var layout: ScreenLayout {
        didSet {
            if layout != oldValue { applyLayout() }
        }
    }

    // MARK: App inputs (R2)

    /// The closure to draw, in degrees (0 open … `Tuning.snapDepth` at the bite), when the App has a better one than
    /// `snapshot.closure`: set it from `HingeTrapSource.predictedAngle(at:)` each frame (before or inside
    /// `advance`) so the teeth glide instead of stepping at the hinge's 25–30 Hz. nil = draw `snapshot.closure`.
    var drawnClosure: Double?

    /// Where the HUD's snaps row is, in scene space (the glyph a Feast wins flies there; a sting cracks one there; a
    /// wilt droops one there). The App sets it from `HUDLayout` (QA-2 #6: the glyph that changes,
    /// `glyphCenter(snapsLeft − 1)`). nil = a fallback near the bottom of the HUD half.
    var hudSnapsAnchor: CGPoint?

    /// QA-2 #6: the whole snaps row (scene space), when the App knows it: a sting's crimson flash covers it, centred.
    /// nil = the R3 fallback (300 × 96 pt, 90 pt right of the anchor).
    var hudSnapsRowRect: CGRect?

    /// QA-2 #7: false on Home (no snaps row there): no Feast glyph flights, no sting crack or row flash, no wilt glyph
    /// or "Too slow!" pop. The bite, its pops and "Bzzt!" still show. Default true (play, the lesson).
    var showsEconomy = true

    // MARK: Read-outs (tests, the App, demo frames)

    /// Frames drawn since the scene was made.
    private(set) var drawnFrames = 0
    /// The snapshot drawn last.
    private(set) var snapshot = TrapSnapshot()
    /// The slam's level (0 open … 1 shut) and the drawn closure (0…1).
    var jawSlam: CGFloat { jaws.slamLevel }
    var drawnClosure01: CGFloat { jaws.drawnClosure }
    /// The lobes' x scale (1 open, 0.85 at the snap depth, `TrapArt.slamSqueeze` mid-bite).
    var lobeScale: CGFloat { jaws.lobeScale }
    /// R3 (#17): the lobes' y scale (the hunger droop, 0.95 at its deepest).
    var lobeYScale: CGFloat { jaws.lobeYScale }
    /// R3 (#1): the closed trap's opacity (1 in the bite's hold).
    var closedTrapAlpha: CGFloat { jaws.closedAlpha }
    /// R3 (#1): the frame of everything the trap draws now (scene space, unshaken): it never leaves the open trap's.
    var trapDrawnFrame: CGRect { jaws.drawnFrame }
    /// R3 (#10): the rim light's alpha on the lobes, and the day's overlay colour on them.
    var rimLightAlpha: CGFloat { jaws.rimLightAlpha }
    var lobeOverlayColor: RGBA { light.lobeTintRGBA }
    /// How hungry the trap looks (0 … 1).
    var hungerDroop: CGFloat { jaws.droop }
    /// The day's overlay on the lobes (≤ 0.25: the trap keeps its crimson).
    var lobeOverlayAlpha: CGFloat { jaws.overlayAlpha }
    /// The teeth's projected length factor (1 out, < 0 flipped in).
    var toothReach: CGFloat { jaws.toothReach }
    var teethCount: Int { jaws.teethCount }
    var liveBugNodes: Int { bugs.liveCount }
    /// The largest bug child sprite over its bug's radius (the streak guard: ≤ 6).
    var bugExtentRatio: CGFloat { bugs.maxExtentRatio }
    /// Bugs showing the white catch flash now.
    var flashingBugs: Int { bugs.flashing }
    func showsProtectedRing(ofBug id: Int) -> Bool { bugs.showsProtectedRing(id) }
    func showsSipRing(ofBug id: Int) -> Bool { bugs.showsSipRing(id) }
    var nectarDrops: Int { surface.dropCount }
    var litHairs: Int { surface.litHairs }
    var activePops: Int { pops.activeCount }
    var popTexts: [String] { pops.activeTexts }
    /// The active pops' text boxes (scene space, unshaken).
    var popRects: [CGRect] { pops.activeRects }
    /// R4 (#3) for the App: every live pop's footprint for the rest of its life, in scene space (origin bottom-left,
    /// y up, as drawn now: the camera punch and the shake included). Each is the pop's box at its pop-in overshoot,
    /// swept up its whole rise, plus its shadow and `BogPops.clearance` (6 pt). Pops still waiting on their delay are
    /// included. Keep the hint/toast plate off every one (`overlapsLivePop`); re-check on each HUD publish (pops live
    /// ≤ 1.6 s).
    var livePopRects: [CGRect] {
        let k = world.xScale
        let o = world.position, sh = shaker.position
        return pops.liveRects.map { r in
            CGRect(x: o.x + k * (sh.x + r.minX), y: o.y + k * (sh.y + r.minY), width: r.width * k,
                   height: r.height * k)
        }
    }
    /// R4 (#3): whether `rect` (scene space) touches any live pop.
    func overlapsLivePop(_ rect: CGRect) -> Bool {
        livePopRects.contains { $0.intersects(rect) }
    }
    /// R4 (#6): the closed trap's drawn width now (one width through every hold; 0 when hidden) and its global z.
    var closedTrapWidth: CGFloat { jaws.closedWidth }
    var closedTrapZ: CGFloat { jaws.closedZ }
    /// R4 (#6, tests): bug `id`'s global z and drawn scale.
    func drawnZ(ofBug id: Int) -> CGFloat? { bugs.drawnZ(id) }
    func drawnScale(ofBug id: Int) -> CGFloat? { bugs.drawnScale(id) }
    /// R4 (#7): the light's key clock now (`BogLight.lightClock`, eased), and the bog lift (noon white, dusk peach).
    var lightClock: Double { light.shownClock }
    var bogLiftAlpha: CGFloat { light.liftAlpha }
    var bogLiftColor: RGBA { light.liftRGBA }
    /// R5 (#9): the dusk's sky glow on the bog (under the trap) now.
    var bogSkyAlpha: CGFloat { light.skyAlpha }
    /// R5 (#3, tests): how dark the closure shades draw the face (0 = the open-state crimson), how much of that is
    /// the bite's own, and the open cilia's opacity.
    var faceShade: CGFloat { jaws.faceShade }
    var biteShade: CGFloat { jaws.closingLevel }
    var ciliaAlpha: CGFloat { jaws.teethAlpha }
    /// R5 (#15, tests): bug `id`'s airborne cue over the crease (0 … 1) and its shadow's offset.
    func creaseCue(ofBug id: Int) -> CGFloat? { bugs.creaseCue(id) }
    func shadowOffset(ofBug id: Int) -> CGPoint? { bugs.shadowOffset(id) }
    /// R5 (#12, tests): the glyph flights' sampled paths (scene space) for the flights still in the air.
    var glyphPaths: [[CGPoint]] { economy.activePaths }
    /// R5 (#12, tests): every free (uncaught) bug's footprint now (scene space, unshaken: its art, wings and ring), as
    /// the pops avoid them.
    var bugRects: [CGRect] { currentBugRects(snapshot) }
    /// QA-2 #2/#6 (tests): the sting cost the numeral is waiting on, and where the row flash is.
    var pendingCrackCost: Int { economy.pendingCrackCost }
    var rowFlashCenter: CGPoint { economy.rowFlashCenter }
    var activeEffects: Int { effects.activeCount }
    /// The economy: glyphs flying now, glyphs landed this session, a crack or a wilt showing.
    var glyphFlights: Int { economy.activeFlights }
    var glyphsLanded: Int { economy.landedCount }
    var glyphCracking: Bool { economy.cracking }
    var glyphWilting: Bool { economy.wilting }
    /// R3 (#14) for the App: add this to `snapshot.snapsLeft` for the numeral the HUD shows, so it changes when each
    /// glyph lands (−1 per Feast glyph still in the air) and only after a sting's crack has shown (+cost for 0.15 s).
    var snapsShownOffset: Int { economy.shownOffset }
    /// R3 (#14): the snaps row's crimson sting flash is showing.
    var snapsRowFlashing: Bool { economy.rowFlashing }
    /// True during the bite's 50 ms hit-stop.
    var inHitStop: Bool { hitStop > 0 }
    var nightLevel: CGFloat { light.night }
    var cameraScale: CGFloat { world.xScale }
    var shakeOffset: CGPoint { shaker.position }
    var foldBandShowing: Bool { !jaws.foldBand.isHidden }
    var visibleFireflies: Int { light.visibleFireflies }
    /// The light tint's z (tests: below the trap, so it multiplies the bog only).
    var tintZ: CGFloat { light.tint.zPosition }
    /// Where bug `id` is drawn (nil when it is not on screen).
    func drawnPoint(ofBug id: Int) -> CGPoint? { bugs.drawnPoint(id) }
    /// Every node under the scene.
    var nodeCount: Int { countNodes(self) }
    /// The snaps row anchor in use.
    var snapsAnchor: CGPoint {
        if let a = hudSnapsAnchor { return a }
        let r = layout.hudRect
        return CGPoint(x: r.minX + r.width * 0.6, y: 46)
    }

    /// Pops keep this far from the crease band (R2 #11).
    static let creaseClear: CGFloat = 24
    /// The bite's hit-stop (session seconds).
    static let hitStopTime: Double = 0.05

    private let world: SKNode
    private let shaker: SKNode
    private let backdrop: SKSpriteNode
    private let jaws: BogJaws
    private let surface: BogSurface
    private let bugs: BogBugLayer
    private let effects: BogEffects
    private let pops: BogPops
    private let economy: BogEconomy
    private let light: BogLight

    private var hasSnapshot = false
    private var lastUpdate: TimeInterval?
    private var wallTime: Double = 0
    private var backdropKey = ""
    private var punch: CGFloat = 0
    private var shakeAmp: CGFloat = 0
    private var shakeClock: Double = 0
    private var hitStop: Double = 0
    /// QA-2 #2: the snaps left on the frame drawn before this one (nil after a reset), so the glyphs and the crack
    /// show only the change that really happened.
    private var lastSnapsLeft: Int?
    /// QA-2 #19: reused per frame (no allocations in the frame loop).
    private var byId: [Int: BugState] = [:]
    private var riders: [SKNode] = []

    init(layout: ScreenLayout) {
        let worldN = SKNode()
        let shakerN = SKNode()
        let back = SKSpriteNode(texture: nil, color: .black, size: layout.size)
        let jawsV = BogJaws()
        let surfaceV = BogSurface()
        let bugsV = BogBugLayer()
        let fxV = BogEffects()
        let popsV = BogPops()
        let ecoV = BogEconomy()
        let lightV = BogLight()
        self.layout = layout
        world = worldN
        shaker = shakerN
        backdrop = back
        jaws = jawsV
        surface = surfaceV
        bugs = bugsV
        effects = fxV
        pops = popsV
        economy = ecoV
        light = lightV
        super.init(size: layout.size)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("BogScene is created in code with init(layout:)")
    }

    private func setUp() {
        scaleMode = .aspectFill
        anchorPoint = .zero
        backgroundColor = BogPaint.ui(TrapArt.palette.bogDeep)

        addChild(world)
        world.addChild(shaker)
        backdrop.anchorPoint = .zero
        backdrop.zPosition = 0
        shaker.addChild(backdrop)
        shaker.addChild(light.tint)
        shaker.addChild(light.lift)
        shaker.addChild(light.sky)
        shaker.addChild(jaws.root)
        shaker.addChild(surface.root)
        shaker.addChild(effects.decalRoot)
        shaker.addChild(light.haze)
        shaker.addChild(light.sparkleRoot)
        shaker.addChild(bugs.ground)
        shaker.addChild(effects.groundRoot)
        shaker.addChild(bugs.layer)
        shaker.addChild(surface.glowRoot)
        shaker.addChild(effects.fxRoot)
        shaker.addChild(pops.root)
        addChild(economy.root)
        addChild(light.vignette)
        riders = [surface.root, surface.glowRoot, effects.decalRoot]

        // Build every texture the frame loop can ask for now, not mid-run.
        let layer = bugs
        BogTextures.warm(size: layout.size) { s in layer.radius(s) }
        applyLayout()
    }

    private func applyLayout() {
        if size != layout.size { size = layout.size }
        let g = layout.geometry
        let key = BogTextures.backdropKey(size: layout.size)
        if key != backdropKey {
            if !backdropKey.isEmpty { BogTextures.forget(backdropKey) }
            backdropKey = key
            backdrop.texture = BogTextures.backdrop(size: layout.size)
        }
        let b = BogTextures.backdropBleed
        backdrop.position = CGPoint(x: -b, y: -b)
        bogResize(backdrop, CGSize(width: layout.size.width + 2 * b, height: layout.size.height + 2 * b))
        jaws.layout(g, sceneHeight: layout.size.height, hasFold: layout.hasFold)
        surface.layout(g)
        light.layout(size: layout.size, geometry: g)
        placeCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        placeCamera()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
    }

    /// A new session: clear every effect and moment.
    func reset() {
        effects.clear()
        pops.clear()
        economy.clear()
        bugs.clear()
        surface.clear()
        jaws.reset()
        light.reset()
        punch = 0
        shakeAmp = 0
        hitStop = 0
        shaker.position = .zero
        placeCamera()
        hasSnapshot = false
        lastSnapsLeft = nil
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        var dt: Double = 1.0 / 120.0
        if let last = lastUpdate { dt = min(max(currentTime - last, 0), 1.0 / 30.0) }
        lastUpdate = currentTime
        var events: [TrapEvent] = []
        var fxDt = dt
        if let d = driver {
            let out = d.advance(dt: dt, now: CACurrentMediaTime())
            var simDt: Double = 0
            if hasSnapshot {
                if out.0.time + 0.25 < snapshot.time {
                    // The clock went backwards: a new session the App didn't announce.
                    reset()
                } else {
                    simDt = min(max(out.0.time - snapshot.time, 0), 1.0 / 30.0)
                }
            }
            snapshot = out.0
            hasSnapshot = true
            events = out.1
            fxDt = simDt
        }
        draw(wallDt: dt, fxDt: fxDt, events: events)
    }

    /// Draws `s` with `events` and `dt` seconds on both clocks (tests and previews; the frame loop uses `update`).
    func show(_ s: TrapSnapshot, events: [TrapEvent], dt: Double) {
        snapshot = s
        hasSnapshot = true
        draw(wallDt: dt, fxDt: dt, events: events)
    }

    private func draw(wallDt: Double, fxDt: Double, events: [TrapEvent]) {
        drawnFrames += 1
        wallTime += wallDt
        let s = snapshot
        let g = layout.geometry
        light.update(clock: s.dayClock, time: wallTime, fxDt: fxDt)
        handle(events, s, g, before: lastSnapsLeft ?? s.snapsLeft)
        lastSnapsLeft = s.snapsLeft
        // The hit-stop: the bugs, FX and pops hold for 50 ms of session time; the jaws slam through it.
        let holding = hitStop > 0
        var momentDt = fxDt
        if holding {
            hitStop = max(hitStop - max(fxDt, 0), 0)
            momentDt = 0
        }
        var closure = s.closure
        if let c = drawnClosure, c.isFinite { closure = c }
        jaws.update(fxDt: fxDt, closure01: TrapArt.closure01(closure), tired: BogScene.tiredness(s.phase),
                    hunger: CGFloat(s.hunger), time: wallTime, night: light.night, dusk: light.dusk,
                    tint: light.lobeTint, tintAlpha: light.lobeTintAlpha, rim: light.rimTint,
                    rimAlpha: light.rimAlpha)
        // R3 (#1): the nectar, the hairs and the glistens ride the bite's squeeze (about the midrib) and sink under the
        // closed trap, so nothing is left lying on the bog outside it.
        let k = jaws.slamScale
        for n in riders {
            n.xScale = k
            n.position = CGPoint(x: g.center.x * (1 - k), y: 0)
        }
        surface.glowRoot.alpha = 1 - jaws.slamLevel
        surface.update(nectar: s.nectar, bugs: s.bugs, time: wallTime, dt: holding ? 0 : wallDt, night: light.night)
        bugs.update(s.bugs, time: wallTime, dt: wallDt, geometry: g, night: light.night, tint: light.bugTint,
                    tintAmount: light.bugTintAmount, reduceMotion: reduceMotion, squeeze: jaws.lobeScale,
                    hold: holding)
        effects.update(momentDt)
        pops.update(momentDt)
        economy.update(momentDt)
        updateCamera(fxDt)
    }

    /// How tired the trap looks (the teeth droop): 0 playing … 1 finished.
    static func tiredness(_ p: RunPhase) -> CGFloat {
        switch p {
        case .playing: return 0
        case .tired(let elapsed): return CGFloat(min(max(elapsed / 1.2, 0), 1))
        case .finished: return 1
        }
    }

    // MARK: Camera

    private func placeCamera() {
        let k = 1 + 0.03 * punch
        world.setScale(k)
        world.position = CGPoint(x: size.width / 2 * (1 - k), y: size.height / 2 * (1 - k))
    }

    private func updateCamera(_ dt: Double) {
        let fdt = CGFloat(max(dt, 0))
        if reduceMotion {
            punch = 0
            shakeAmp = 0
            shaker.position = .zero
            placeCamera()
            return
        }
        guard dt > 0 else { return }
        punch = BogMath.approach(punch, 0, rate: 4, dt: fdt)
        shakeAmp = BogMath.approach(shakeAmp, 0, rate: max(shakeAmp * 3.4, 6), dt: fdt)
        shakeClock += dt
        if shakeAmp > 0.05 {
            let t = CGFloat(shakeClock)
            // Never past the backdrop's bleed (QA-1 #20).
            let a = min(shakeAmp, BogTextures.backdropBleed - 4)
            shaker.position = CGPoint(x: a * sin(t * 71), y: a * 0.7 * sin(t * 53 + 1.3))
        } else {
            shaker.position = .zero
        }
        placeCamera()
    }

    // MARK: Events

    /// QA-2 #2/#3: how many of a bite's `snapsBack` glyphs stand for snaps Core really added (`before` → `after`):
    /// none at the cap or in a run that doesn't spend snaps (the lesson, Home).
    static func countedFlights(snapsBack: Int, before: Int, after: Int) -> Int {
        min(max(snapsBack, 0), max(after - before, 0))
    }

    /// QA-2 #2: the snaps a frame's stings really cost (their summed costs, clamped to the real drop).
    static func shownStingCost(costs: Int, before: Int, after: Int) -> Int {
        min(max(costs, 0), max(before - after, 0))
    }

    private func handle(_ events: [TrapEvent], _ s: TrapSnapshot, _ g: TrapGeometry, before: Int) {
        guard !events.isEmpty else { return }
        let pal = TrapArt.palette
        byId.removeAll(keepingCapacity: true)
        for b in s.bugs { byId[b.id] = b }
        var caughtPoints: [CGPoint] = []
        var caughtRadius: CGFloat = 0
        var bite: BiteReport?
        var feasted = false
        var lucky: [BugSpecies] = []
        var stings: [(CGPoint, BugSpecies, Int)] = []
        var dry = false
        var best = false
        var wilted = false
        var chained = false
        var broken = false
        let tint = light.envTint
        // R5 (#12): no pop is ever placed over a bug.
        let obstacles = currentBugRects(s)

        for e in events {
            switch e {
            case .waveStarted:
                break
            case .dayPhaseChanged:
                break
            case .bugArrived:
                break
            case .bugLanded(_, let species, let position, _):
                effects.ripple(at: position, radius: bugs.radius(species))
            case .bugSipping(let id, let species):
                if let b = byId[id], !species.isProtected {
                    effects.sparkBurst(at: b.position, count: 3, color: BogPaint.ui(TrapArt.sipRing), speed: 60,
                                       size: 12)
                }
            case .bugHopped(let id, let species):
                if let b = byId[id] {
                    let r = bugs.radius(species)
                    effects.puff(from: CGPoint(x: b.position.x - r, y: b.position.y - r * 0.4),
                                 to: CGPoint(x: b.position.x + r, y: b.position.y - r * 0.4), count: 2,
                                 color: UIColor(white: 1, alpha: 1), size: r * 1.2)
                }
            case .bugLeft:
                break
            case .bugSpooked(let id, let species):
                let p = bugs.drawnPoint(id) ?? byId[id]?.position
                if let p = p { effects.startle(at: p, radius: bugs.radius(species)) }
            case .snapStarted:
                break
            case .snapped(let report):
                bite = report
                jaws.slam()
                light.pulse()
                let n = report.caught.count
                punch = n > 0 ? 1 : 0.5
                var amp: CGFloat = n > 0 ? min(4 + 2 * CGFloat(n), 12) : 3
                if !report.stingers.isEmpty { amp = max(amp, 6) }
                shakeAmp = amp
                if n > 0 || !report.stingers.isEmpty {
                    hitStop = BogScene.hitStopTime
                }
                if n > 0 { effects.impact(at: g.center, height: g.b * 2) }
            case .bugCaught(let id, let species, let position):
                caughtPoints.append(position)
                caughtRadius = max(caughtRadius, bugs.radius(species))
                bugs.markCaught(id, at: position)
                effects.squish(at: position, radius: bugs.radius(species), tint: tint)
            case .bugEscaped(let id, let species):
                if let b = byId[id] {
                    let p = bugs.drawnPoint(id) ?? b.position
                    effects.whiff(at: p, heading: CGFloat(b.heading), radius: bugs.radius(species))
                }
            case .stung(let id, let species, let cost):
                let p = bugs.drawnPoint(id) ?? byId[id]?.position ?? g.center
                stings.append((p, species, cost))
            case .drySnap:
                dry = true
            case .feast:
                feasted = true
            case .luckySnap(let species):
                lucky.append(species)
            case .chainUp:
                // The chain step is the HUD chip's bump (App), never a line on the lobe (R2 #18).
                chained = true
            case .chainBroken:
                broken = true
            case .rearmed:
                jaws.rearm()
            case .beeSpared:
                break
            case .lastSnap:
                break
            case .hungry:
                jaws.rumble()
            case .wilted:
                wilted = true
            case .tired:
                break
            case .newBest:
                best = true
            case .finished:
                break
            }
        }

        var heroSaidStung = false
        // The bite's one hero callout, above the crowd that was caught, on the side with most catches, clear of the
        // crease; the snaps it won fly to the HUD's row.
        if let r = bite, !caughtPoints.isEmpty {
            var a = CGPoint.zero
            var left = 0, right = 0
            for p in caughtPoints {
                a.x += p.x
                a.y += p.y
                if p.x < CGFloat(layout.midX) { left += 1 } else { right += 1 }
            }
            a = CGPoint(x: a.x / CGFloat(caughtPoints.count), y: a.y / CGFloat(caughtPoints.count))
            let side = left == right ? sideOf(a.x) : (left > right ? -1 : 1)
            let n = r.caught.count
            let stung = !r.stingers.isEmpty
            let hero = feasted || n >= 3
            // R3 (#8): a bite with a stinger scores ×1 and says so ("Stung! · +172").
            let label = stung ? BogScene.stungLabel(points: r.points) : BogScene.heroLabel(count: n, points: r.points)
            // R3 (#15): every catch pop is big (≥ 28 pt even when it must shrink to fit) and pops with an overshoot.
            var size: CGFloat = hero ? 48 : (n >= 2 ? 40 : 36)
            let rise: CGFloat = hero ? 30 : 44
            // A clean bite that keeps the chain going without growing it says so ("×1.5 held").
            let held = !stung && !broken && !chained && r.chainMultiplier > 1.001
            // R5 (#12): room for each line under the callout, with its own rise (they never stack into one another).
            let extra = CGFloat(lucky.count + (held ? 1 : 0)) * BogScene.lineStep
            let pt = placePop(label, size: &size, near: CGPoint(x: a.x, y: a.y + 2 * caughtRadius + 20), side: side,
                              hero: hero, rise: rise, minY: extra, minSize: BogScene.minCatchPop, avoid: obstacles)
            pops.pop(label, at: pt, size: size, fill: BogPaint.ui(pal.gold), stroke: BogPaint.ui(pal.ink), rise: rise,
                     life: hero ? 1.5 : 1.2, hero: hero)
            heroSaidStung = stung
            var y = pt.y - size * 0.6 - 30
            if held {
                var hs: CGFloat = 28
                let text = BogScene.heldLabel(r.chainMultiplier)
                let hp = placePop(text, size: &hs, near: CGPoint(x: pt.x, y: y), side: side, hero: false, rise: 30,
                                  minSize: 24, avoid: obstacles, downFirst: true)
                pops.pop(text, at: hp, size: hs, fill: BogPaint.ui(TrapArt.sipRing), stroke: BogPaint.ui(pal.ink),
                         rise: 30, delay: 0.1, life: 1.2)
                y = hp.y - BogScene.lineStep
            }
            for sp in lucky {
                var ls: CGFloat = 28
                let text = BogScene.luckyLabel(sp)
                let lp = placePop(text, size: &ls, near: CGPoint(x: pt.x, y: y), side: side, hero: false, rise: 30,
                                  avoid: obstacles, downFirst: true)
                pops.pop(text, at: lp, size: ls, fill: BogPaint.ui(TrapArt.sipRing), stroke: BogPaint.ui(pal.ink),
                         rise: 30, delay: 0.12, life: 1.3)
                y = lp.y - BogScene.lineStep
            }
            if hero {
                effects.sparkBurst(at: a, count: 12, color: BogPaint.ui(TrapArt.sipRing), speed: 240, size: 22)
            }
            if r.snapsBack > 0 && showsEconomy {
                // QA-2 #2/#3: every glyph flies, but only the snaps Core really added hold the numeral back (at the
                // cap, or in the lesson, the number never dips).
                // R5 (#12): the glyphs take the arc that crosses the fewest live pops (never over "Golden!").
                economy.fly(count: r.snapsBack,
                            counted: BogScene.countedFlights(snapsBack: r.snapsBack, before: before, after: s.snapsLeft),
                            from: a, to: snapsAnchor, avoid: livePopRects)
            }
        }
        // "Bzzt!" above the bee's ring (R3 #14: never over the bee; under the ring when there's no room above), on
        // its own half; the snaps they cost crack on the HUD's row under a crimson flash (QA-2 #2: once, for the
        // summed cost, clamped to the real drop, so the numeral only ever goes down).
        var stingCosts = 0
        for (p, species, cost) in stings {
            stingCosts += max(cost, 0)
            var size: CGFloat = 40
            let text = species == .wasp && !heroSaidStung ? "Stung!" : "Bzzt!"
            let r = bugs.radius(species)
            let ring = r * TrapArt.protectedRingScale + 4
            let over = 1 + BogPops.overshoot(hero: false)
            var box = BogPops.measure(text, size: size)
            var c = placePop(text, size: &size, near: CGPoint(x: p.x, y: p.y + ring + 8 + box.height * over / 2),
                             side: sideOf(p.x), hero: false, rise: 36, avoid: obstacles)
            box = BogPops.measure(text, size: size)
            let overlaps = c.y - box.height * over / 2 < p.y + ring && abs(c.x - p.x) < box.width * over / 2 + ring
            let yellow = BogPaint.ui(RGBA(hex: 0xFFD23A))
            if overlaps {
                c = placePop(text, size: &size, near: CGPoint(x: p.x, y: p.y - ring - 14 - box.height * over / 2),
                             side: sideOf(p.x), hero: false, rise: 8, avoid: obstacles, downFirst: true)
                pops.pop(text, at: c, size: size, fill: yellow, stroke: BogPaint.ui(pal.ink), rise: 8)
            } else {
                pops.pop(text, at: c, size: size, fill: yellow, stroke: BogPaint.ui(pal.ink), rise: 36)
            }
        }
        let lost = BogScene.shownStingCost(costs: stingCosts, before: before, after: s.snapsLeft)
        if lost > 0 && showsEconomy {
            economy.crack(at: snapsAnchor, cost: lost, row: hudSnapsRowRect)
        }
        if dry && bite != nil {
            effects.puff(from: CGPoint(x: g.center.x, y: g.center.y - g.b * 0.6),
                         to: CGPoint(x: g.center.x, y: g.center.y + g.b * 0.6), count: 5,
                         color: UIColor(white: 0.85, alpha: 1), size: 34)
            // R5 (#10): a dry snap says so. A soft dusty puff at the seam (where the jaws met on nothing) and "Missed!"
            // beside it, on the half without the HUD, clear of the crease; pale and quiet (no squelch, no juice).
            let at = CGPoint(x: g.center.x, y: g.center.y + g.b * BogScene.missedHeight)
            effects.puff(from: CGPoint(x: at.x, y: at.y - 24), to: CGPoint(x: at.x, y: at.y + 24), count: 4,
                         color: BogPaint.ui(BogScene.missedColor), size: 46)
            var ms: CGFloat = 32
            let side = layout.hudOnLeft ? 1 : -1
            let mp = placePop(BogScene.missedLabel, size: &ms, near: at, side: side, hero: false, rise: 18,
                              minSize: 24, avoid: obstacles)
            pops.pop(BogScene.missedLabel, at: mp, size: ms, fill: BogPaint.ui(BogScene.missedColor),
                     stroke: BogPaint.ui(pal.ink), rise: 18, life: 0.9)
        }
        if wilted && showsEconomy {
            // R3 (#15): "Too slow! −1 snap", a crimson tag just over the snaps row, and the glyph droops off it.
            let anchor = snapsAnchor
            var size: CGFloat = 28
            let text = BogScene.wiltedLabel
            let p = placePop(text, size: &size, near: CGPoint(x: anchor.x + 60, y: anchor.y + 46),
                             side: sideOf(anchor.x), hero: false, rise: 18, inTrap: false, minSize: 20,
                             avoid: obstacles)
            pops.pop(text, at: p, size: size, fill: BogPaint.ui(BogScene.wiltColor), stroke: BogPaint.ui(pal.ink),
                     rise: 18, life: 1.6)
            economy.wilt(at: anchor)
        }
        if best {
            var size: CGFloat = 30
            let side = layout.hudOnLeft ? 1 : -1
            let p = placePop("New best!", size: &size, near: CGPoint(x: g.center.x, y: g.center.y + g.b * 0.62),
                             side: side, hero: false, rise: 24, avoid: obstacles)
            pops.pop("New best!", at: p, size: size, fill: BogPaint.ui(pal.gold), stroke: BogPaint.ui(pal.ink),
                     rise: 24, delay: 0.3, life: 1.6)
        }
    }

    /// −1 left of the crease, +1 right of it (a point on it goes to the half without the HUD).
    private func sideOf(_ x: CGFloat) -> Int {
        let mid = CGFloat(layout.midX)
        if x < mid - 0.5 { return -1 }
        if x > mid + 0.5 { return 1 }
        return layout.hudOnLeft ? 1 : -1
    }

    /// Where a pop of `text` goes near `p` (R2 #11): on `side`'s half, its box (with the pop-in overshoot) at least
    /// `creaseClear` from the crease band and inside the trap (or the canvas when `inTrap` is false), with room above
    /// for its rise and below for `minY` of lines under it (QA-1 #23). `size` shrinks if the text can't fit.
    ///
    /// R5 (#12): it also keeps its whole footprint (the box at its overshoot, swept up its rise, `popGap` round it) off
    /// every rect in `avoid` (the bugs on screen) and off every live pop, trying nearby spots in order of distance
    /// (downward first for the lines under a callout, so a stack spreads out instead of overlapping). If nowhere is
    /// clear it takes the spot that overlaps least.
    private func placePop(_ text: String, size: inout CGFloat, near p: CGPoint, side: Int, hero: Bool, rise: CGFloat,
                          minY: CGFloat = 0, inTrap: Bool = true, minSize: CGFloat = 12, avoid: [CGRect] = [],
                          downFirst: Bool = false) -> CGPoint {
        let g = layout.geometry
        let over = 1 + BogPops.overshoot(hero: hero)
        let w = layout.size.width, h = layout.size.height
        let leftEdge = inTrap ? max(g.center.x - g.a - TrapArt.exteriorWidth, 12) : 12
        let rightEdge = inTrap ? min(g.center.x + g.a + TrapArt.exteriorWidth, w - 12) : w - 12
        let lo: CGFloat, hi: CGFloat
        if side < 0 {
            lo = leftEdge
            hi = layout.creaseMinX - BogScene.creaseClear
        } else {
            lo = layout.creaseMaxX + BogScene.creaseClear
            hi = rightEdge
        }
        let avail = max(hi - lo, 40)
        var box = BogPops.measure(text, size: size)
        if box.width * over > avail {
            // Shrink to fit, but never under `minSize` unless even that would cross the crease (the crease wins).
            let fit = max((size * avail / (box.width * over)).rounded(.down), 12)
            var next = max(fit, min(minSize, size))
            if BogPops.measure(text, size: next).width * over > avail { next = fit }
            size = next
            box = BogPops.measure(text, size: size)
        }
        let half = box.width * over / 2
        let floorY = (inTrap ? g.center.y - g.b + 40 : 40) + minY + box.height / 2
        let ceilY = (inTrap ? min(g.center.y + g.b - 30, h - 24) : h - 24) - rise - box.height / 2
        func clampX(_ v: CGFloat) -> CGFloat {
            lo + half <= hi - half ? min(max(v, lo + half), hi - half) : (lo + hi) / 2
        }
        func clampY(_ v: CGFloat) -> CGFloat { floorY <= ceilY ? min(max(v, floorY), ceilY) : ceilY }
        let start = CGPoint(x: clampX(p.x), y: clampY(p.y))
        let blocks = avoid + pops.liveRects
        guard !blocks.isEmpty else { return start }
        let hh = box.height * over / 2
        func cost(_ c: CGPoint) -> CGFloat {
            let foot = BogScene.popFootprint(center: c, halfWidth: half, halfHeight: hh, rise: rise)
            var a: CGFloat = 0
            for b in blocks {
                let i = foot.intersection(b)
                if !i.isNull { a += i.width * i.height + 1 }
            }
            return a
        }
        var best = start
        var bestCost = cost(start)
        if bestCost <= 0 { return best }
        for o in BogScene.popOffsets(downFirst: downFirst) {
            let c = CGPoint(x: clampX(start.x + o.x), y: clampY(start.y + o.y))
            let k = cost(c)
            if k < bestCost {
                best = c
                bestCost = k
                if k <= 0 { break }
            }
        }
        return best
    }

    /// R5 (#12): how far a pop keeps from bugs and other pops (points, every side).
    static let popGap: CGFloat = 4

    /// R5 (#12): a pop's footprint for its whole life: its box at the pop-in overshoot (half extents `halfWidth`,
    /// `halfHeight`) about `center`, swept up its `rise`, with its drop shadow and `popGap` round it.
    static func popFootprint(center c: CGPoint, halfWidth: CGFloat, halfHeight: CGFloat, rise: CGFloat) -> CGRect {
        CGRect(x: c.x - halfWidth, y: c.y - halfHeight - 3, width: 2 * halfWidth + 2,
               height: 2 * halfHeight + 3 + max(rise, 0)).insetBy(dx: -popGap, dy: -popGap)
    }

    /// R5 (#12): the spots a pop tries, nearest first (sideways costs a little more than up or down; with
    /// `downFirst`, going up costs more than going down).
    static func popOffsets(downFirst: Bool) -> [CGPoint] {
        var out: [(CGPoint, CGFloat)] = []
        for dx in [CGFloat(0), 44, -44, 88, -88, 132, -132] {
            for dy in stride(from: CGFloat(-176), through: 176, by: 22) where dx != 0 || dy != 0 {
                let up = dy > 0 ? dy * (downFirst ? 1.8 : 1) : -dy
                out.append((CGPoint(x: dx, y: dy), abs(dx) * 1.25 + up))
            }
        }
        out.sort { $0.1 < $1.1 }
        return out.map { $0.0 }
    }

    /// R5 (#12): every free bug's footprint now (shaker space, as the pops are placed): its art and wings (1.25 r), or
    /// its protected ring. Caught bugs don't count: they leave for the seam within 60 ms (`sinkTime`), before a pop
    /// has even settled, and the seam is off limits to pops anyway.
    private func currentBugRects(_ s: TrapSnapshot) -> [CGRect] {
        var out: [CGRect] = []
        for b in s.bugs {
            if case .caught = b.activity { continue }
            let p = bugs.drawnPoint(b.id) ?? b.position
            let r = bugs.radius(b.species)
            let half = b.species.isProtected ? r * TrapArt.protectedRingScale + 4 : r * 1.25
            out.append(CGRect(x: p.x - half, y: p.y - half, width: 2 * half, height: 2 * half))
        }
        return out
    }

    // MARK: Words (scene labels; the HUD's words are the UI's)

    /// "DOUBLE ×2", "TRIPLE ×3", "QUAD ×4", "FEAST ×5"… (nil for a single bug).
    static func countLabel(_ n: Int) -> String? {
        switch n {
        case ..<2: return nil
        case 2: return "DOUBLE ×2"
        case 3: return "TRIPLE ×3"
        case 4: return "QUAD ×4"
        default: return "FEAST ×\(n)"
        }
    }

    /// The bite's one callout: "FEAST ×5 · +255", "DOUBLE ×2 · +40", or "+12" for one bug.
    static func heroLabel(count n: Int, points: Int) -> String {
        if let c = countLabel(n) { return "\(c) · +\(number(points))" }
        return "+\(number(points))"
    }

    static func feastLabel(_ snapsBack: Int) -> String {
        snapsBack > 0 ? "Feast! +\(snapsBack) snap\(snapsBack == 1 ? "" : "s")" : "Feast!"
    }

    /// The lucky bug's line under the hero callout (the snaps it won fly to the HUD as glyphs).
    static func luckyLabel(_ s: BugSpecies) -> String {
        s == .goldenScarab ? "Golden!" : "Lucky!"
    }

    /// The hunger wilt's pop (R3 #15: says what happened and what it cost).
    static let wiltedLabel = "Too slow! −1 snap"
    /// Its crimson.
    static let wiltColor = RGBA(hex: 0xFF4D5E)
    /// R3 (#15): the smallest a catch pop is ever drawn (points, before its overshoot).
    static let minCatchPop: CGFloat = 28
    /// R5 (#12): the room each line under a callout takes ("×2 held", "Golden!").
    static let lineStep: CGFloat = 56
    /// R5 (#10): the dry snap's word, its pale dusty colour, and where on the seam it puffs (× the trap's half
    /// height above the centre: the upper third, clear of a crowd sipping low).
    static let missedLabel = "Missed!"
    static let missedColor = RGBA(hex: 0xE9E2D0)
    static let missedHeight: CGFloat = 0.3

    /// R3 (#8): a bite with a stinger in it: "Stung! · +172" (it scored ×1).
    static func stungLabel(points: Int) -> String { "Stung! · +\(number(points))" }

    /// R3 (#15): a clean bite that kept the chain without growing it: "×1.5 held".
    static func heldLabel(_ m: Double) -> String { "\(multiplier(m)) held" }

    /// "×1.5", "×2".
    static func multiplier(_ m: Double) -> String {
        let r = (m * 10).rounded() / 10
        if abs(r - r.rounded()) < 0.001 { return "×\(Int(r.rounded()))" }
        return String(format: "×%.1f", r)
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    static func number(_ v: Int) -> String { formatter.string(from: NSNumber(value: v)) ?? "\(v)" }

    private func countNodes(_ n: SKNode) -> Int {
        var c = 1
        for k in n.children { c += countNodes(k) }
        return c
    }

    // MARK: Touches (scene space)

    /// A tap at scene point `p` (the UITouch path and tests).
    func tap(at p: CGPoint, time: TimeInterval) {
        driver?.sceneTapped(at: p, time: time)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { tap(at: t.location(in: self), time: t.timestamp) }
    }
}
