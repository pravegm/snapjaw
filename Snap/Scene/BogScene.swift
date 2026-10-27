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
///     - backdrop (z 0: the cached bog, the trap's shadow)
///     - jaws (z 10: two lobes, the midrib, the fold band at z 1, the teeth at z 14)
///     - surface (z 15: nectar drops, trigger hairs) · decals (z 16: nectar glistens)
///     - light tint (z 20, multiply) · haze (z 21, add) · dew twinkles and night fireflies (z 21.5)
///     - bug shadows (z 22) · landing ripples (z 23) · bugs (z 30) · nectar night glow (z 41)
///     - FX (z 50: spray, sparkles, whiffs, startles) · score pops (z 60)
/// - vignette (z 70, never shaken)
///
/// **Clocks.** Moments (the slam, FX, pops, the punch) run on the session's clock (snapshot time), so a pause or a
/// CI freeze holds them at that instant; ambient life (flaps, bobs, twinkles, fireflies) runs on the wall clock, so a
/// still frame still breathes.
@MainActor
final class BogScene: SKScene {
    weak var driver: SceneDriver?

    /// Reduce Motion: no shake or camera punch, gentler bobs, fewer particles.
    var reduceMotion: Bool = false {
        didSet {
            effects.reduceMotion = reduceMotion
            jaws.reduceMotion = reduceMotion
        }
    }

    var layout: ScreenLayout {
        didSet {
            if layout != oldValue { applyLayout() }
        }
    }

    // MARK: Read-outs (tests, the App, demo frames)

    /// Frames drawn since the scene was made.
    private(set) var drawnFrames = 0
    /// The snapshot drawn last.
    private(set) var snapshot = TrapSnapshot()
    /// The slam's level (0 open … 1 shut) and the drawn closure (0…1).
    var jawSlam: CGFloat { jaws.slamLevel }
    var drawnClosure01: CGFloat { jaws.drawnClosure }
    /// The teeth's projected length factor (1 out, < 0 flipped in).
    var toothReach: CGFloat { jaws.toothReach }
    var teethCount: Int { jaws.teethCount }
    var liveBugNodes: Int { bugs.liveCount }
    var nectarDrops: Int { surface.dropCount }
    var litHairs: Int { surface.litHairs }
    var activePops: Int { pops.activeCount }
    var popTexts: [String] { pops.activeTexts }
    var activeEffects: Int { effects.activeCount }
    var nightLevel: CGFloat { light.night }
    var cameraScale: CGFloat { world.xScale }
    var shakeOffset: CGPoint { shaker.position }
    var foldBandShowing: Bool { !jaws.foldBand.isHidden }
    var visibleFireflies: Int { light.visibleFireflies }
    /// Where bug `id` is drawn (nil when it is not on screen).
    func drawnPoint(ofBug id: Int) -> CGPoint? { bugs.drawnPoint(id) }
    /// Every node under the scene.
    var nodeCount: Int { countNodes(self) }

    private let world: SKNode
    private let shaker: SKNode
    private let backdrop: SKSpriteNode
    private let jaws: BogJaws
    private let surface: BogSurface
    private let bugs: BogBugLayer
    private let effects: BogEffects
    private let pops: BogPops
    private let light: BogLight

    private var hasSnapshot = false
    private var lastUpdate: TimeInterval?
    private var wallTime: Double = 0
    private var backdropKey = ""
    private var punch: CGFloat = 0
    private var shakeAmp: CGFloat = 0
    private var shakeClock: Double = 0
    private var rng = BogRNG(seed: 0x5CE7E)

    init(layout: ScreenLayout) {
        let worldN = SKNode()
        let shakerN = SKNode()
        let back = SKSpriteNode(texture: nil, color: .black, size: layout.size)
        let jawsV = BogJaws()
        let surfaceV = BogSurface()
        let bugsV = BogBugLayer()
        let fxV = BogEffects()
        let popsV = BogPops()
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
        backdrop.position = .zero
        backdrop.zPosition = 0
        shaker.addChild(backdrop)
        shaker.addChild(jaws.root)
        shaker.addChild(surface.root)
        shaker.addChild(effects.decalRoot)
        shaker.addChild(light.tint)
        shaker.addChild(light.haze)
        shaker.addChild(light.sparkleRoot)
        shaker.addChild(bugs.ground)
        shaker.addChild(effects.groundRoot)
        shaker.addChild(bugs.layer)
        shaker.addChild(surface.glowRoot)
        shaker.addChild(effects.fxRoot)
        shaker.addChild(pops.root)
        addChild(light.vignette)

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
        backdrop.size = layout.size
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
        bugs.clear()
        surface.clear()
        jaws.reset()
        light.reset()
        punch = 0
        shakeAmp = 0
        shaker.position = .zero
        placeCamera()
        hasSnapshot = false
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
        handle(events, s, g)
        jaws.update(fxDt: fxDt, closure01: TrapArt.closure01(s.closure), tired: BogScene.tiredness(s.phase),
                    time: wallTime, night: light.night, dusk: light.dusk)
        surface.update(nectar: s.nectar, bugs: s.bugs, time: wallTime, dt: wallDt, night: light.night)
        bugs.update(s.bugs, time: wallTime, dt: wallDt, geometry: g, night: light.night, tint: light.bugTint,
                    tintAmount: light.bugTintAmount, reduceMotion: reduceMotion)
        effects.update(fxDt)
        pops.update(fxDt)
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
            shaker.position = CGPoint(x: shakeAmp * sin(t * 71), y: shakeAmp * 0.7 * sin(t * 53 + 1.3))
        } else {
            shaker.position = .zero
        }
        placeCamera()
    }

    // MARK: Events

    private func handle(_ events: [TrapEvent], _ s: TrapSnapshot, _ g: TrapGeometry) {
        guard !events.isEmpty else { return }
        let pal = TrapArt.palette
        var byId: [Int: BugState] = [:]
        for b in s.bugs { byId[b.id] = b }
        var caughtPoints: [CGPoint] = []
        var bite: BiteReport?
        var feastBack = 0
        var feasted = false
        var lucky: [BugSpecies] = []
        var stings: [(CGPoint, BugSpecies, Int)] = []
        var dry = false
        var best = false
        let tint = light.envTint

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
            case .bugSipping(let id, _):
                if let b = byId[id] {
                    effects.sparkBurst(at: b.position, count: 3, color: BogPaint.ui(pal.gold), speed: 60, size: 12)
                }
            case .bugHopped(let id, let species):
                if let b = byId[id] {
                    let r = bugs.radius(species)
                    effects.puff(from: CGPoint(x: b.position.x - r, y: b.position.y - r * 0.4),
                                 to: CGPoint(x: b.position.x + r, y: b.position.y - r * 0.4), count: 2,
                                 color: UIColor(white: 1, alpha: 1), size: r * 1.4)
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
                punch = 1
                shakeAmp = report.caught.isEmpty ? 3 : min(4 + 2.5 * CGFloat(report.caught.count), 14)
            case .bugCaught(let id, let species, let position):
                caughtPoints.append(position)
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
            case .feast(_, let snapsBack):
                feasted = true
                feastBack = snapsBack
            case .luckySnap(let species):
                lucky.append(species)
            case .chainUp:
                break
            case .chainBroken:
                break
            case .rearmed:
                jaws.rearm()
            case .beeSpared:
                break
            case .lastSnap:
                break
            case .tired:
                break
            case .newBest:
                best = true
            case .finished:
                break
            }
        }

        // The bite's callouts, stacked at the crowd that was caught.
        if let r = bite, !caughtPoints.isEmpty {
            var a = CGPoint.zero
            for p in caughtPoints {
                a.x += p.x
                a.y += p.y
            }
            a = CGPoint(x: a.x / CGFloat(caughtPoints.count), y: a.y / CGFloat(caughtPoints.count))
            a = clampPop(a)
            var y = a.y + 36
            pops.pop("+\(BogScene.number(r.points))", at: CGPoint(x: a.x, y: y), size: 50,
                     fill: BogPaint.ui(pal.gold), stroke: BogPaint.ui(pal.ink), rise: 50)
            y -= 46
            if let label = BogScene.countLabel(r.caught.count) {
                pops.pop(label, at: CGPoint(x: a.x, y: y), size: 34, fill: BogPaint.ui(pal.text),
                         stroke: BogPaint.ui(BogPaint.darker(pal.lobeInner, 0.3)), rise: 44, delay: 0.06)
                y -= 38
            }
            if r.chainMultiplier > 1.01 {
                pops.pop("chain \(BogScene.multiplier(r.chainMultiplier))", at: CGPoint(x: a.x, y: y), size: 22,
                         fill: BogPaint.ui(pal.rim), stroke: BogPaint.ui(pal.ink), rise: 40, delay: 0.1)
                y -= 30
            }
            if feasted {
                pops.pop(BogScene.feastLabel(feastBack), at: CGPoint(x: a.x, y: y), size: 28,
                         fill: BogPaint.ui(pal.rim), stroke: BogPaint.ui(pal.ink), rise: 40, delay: 0.16, life: 1.3)
                effects.sparkBurst(at: a, count: 12, color: BogPaint.ui(pal.gold), speed: 240, size: 22)
                y -= 34
            }
            for sp in lucky {
                pops.pop(BogScene.luckyLabel(sp), at: CGPoint(x: a.x, y: y), size: 26, fill: BogPaint.ui(pal.gold),
                         stroke: BogPaint.ui(pal.ink), rise: 40, delay: 0.22, life: 1.3)
                y -= 32
            }
        }
        for (p, species, cost) in stings {
            let c = clampPop(p)
            pops.pop(species == .wasp ? "Stung!" : "Bzzt!", at: CGPoint(x: c.x, y: c.y + 44), size: 40,
                     fill: BogPaint.ui(RGBA(hex: 0xFFD23A)), stroke: BogPaint.ui(pal.ink), rise: 36)
            if cost > 0 {
                pops.pop("−\(cost) snap\(cost == 1 ? "" : "s")", at: CGPoint(x: c.x, y: c.y + 8), size: 24,
                         fill: BogPaint.ui(pal.danger), stroke: BogPaint.ui(pal.text), rise: 30, delay: 0.1)
            }
        }
        if dry && bite != nil {
            effects.puff(from: CGPoint(x: g.center.x, y: g.center.y - g.b * 0.6),
                         to: CGPoint(x: g.center.x, y: g.center.y + g.b * 0.6), count: 5,
                         color: UIColor(white: 0.85, alpha: 1), size: 34)
        }
        if best {
            pops.pop("New best!", at: CGPoint(x: g.center.x, y: g.center.y + g.b * 0.62), size: 30,
                     fill: BogPaint.ui(pal.gold), stroke: BogPaint.ui(pal.ink), rise: 24, delay: 0.3, life: 1.6)
        }
    }

    /// Keeps a callout inside the trap, clear of the canvas edges.
    private func clampPop(_ p: CGPoint) -> CGPoint {
        let g = layout.geometry
        let x = min(max(p.x, g.center.x - g.a + 130), g.center.x + g.a - 130)
        let y = min(max(p.y, g.center.y - g.b + 110), g.center.y + g.b - 110)
        return CGPoint(x: x, y: y)
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

    static func feastLabel(_ snapsBack: Int) -> String {
        snapsBack > 0 ? "Feast! +\(snapsBack) snap\(snapsBack == 1 ? "" : "s")" : "Feast!"
    }

    static func luckyLabel(_ s: BugSpecies) -> String {
        s == .goldenScarab ? "Golden! +2 snaps" : "Lucky! +1 snap"
    }

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
