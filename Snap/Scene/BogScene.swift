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
/// - R8: the closing dim (z 55, never shaken: hinge input only, the edges darken as the phone closes; under the pops)
/// - the economy's glyph flights (z 62, never shaken: they land on the HUD's snaps row)
/// - vignette (z 70, never shaken)
///
/// **R8: the phone IS the trap.** With hinge input (`usesHinge`, set by the App) the lobes are always drawn open: the
/// closure (0 … about 150° at the shut) drives only the closing cues (the cilia lean in, the rim shadow deepens, the
/// edges dim, the bugs in the trap panic). The bite comes as the phone shuts, when nobody can see the inner screen, so
/// its moment (the pops, the FEAST, the juice) is held back and played as the digest when the trap reopens
/// (`snapshot.shut` goes false): the caught bugs gone, a gold juice stain and remains where they were, the "+N" pop.
/// Touch input keeps the R3 slam (a tap is an instant bite).
///
/// **Clocks.** Moments (the slam, FX, pops, the punch) run on the session's clock (snapshot time), so a pause or a
/// CI freeze holds them at that instant; ambient life (flaps, bobs, twinkles, fireflies) runs on the wall clock, so a
/// still frame still breathes. **The bite's hit-stop** (50 ms of session time) freezes the bugs, FX and pops while the
/// jaws slam and the caught bugs flash white.
/// R7 (#4): Core judges where bugs may rest (`TrapSession.keepOut`); the Scene knows the HUD's plates and Home's
/// buttons. A driver that conforms is sent `BogScene.coreKeepOut` (scene space, the sessions' own space) whenever it
/// changes, when it is set as the driver and on every `reset()`; it sets it on its play and Home sessions. (A session
/// made later can take it at once with `BogScene.applyKeepOut(to:)`.)
@MainActor
protocol SceneKeepOutReceiver: AnyObject {
    func sceneKeepOutChanged(_ rects: [CGRect])
}

@MainActor
final class BogScene: SKScene {
    /// R7 (#4): a driver that is also a `SceneKeepOutReceiver` is sent `coreKeepOut` when it is set.
    weak var driver: SceneDriver? {
        didSet { publishKeepOut() }
    }

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

    /// The closure to draw, in degrees from the open reference, when the App has a better one than
    /// `snapshot.closure`: set it from `HingeTrapSource.predictedAngle(at:)` each frame (before or inside
    /// `advance`) so the cues glide instead of stepping at the hinge's 25–30 Hz. nil = draw `snapshot.closure`.
    /// R8: with the hinge it runs 0 … about 150 at the shut and drives only the closing cues (`TrapArt.closingCue`);
    /// with touch it is the tap's sweep (0 … `Tuning.snapDepth`) and drives the lobes as before.
    var drawnClosure: Double?

    /// R8: the input is the hinge (the App sets it with its input kind, `AppInputKind.hinge`; default false = touch).
    /// Hinge: the lobes never animate shut on the inner screen, the closure drives the closing cues, the caught bugs
    /// are never drawn and the bite's moment plays as the digest on the reopen. Touch: today's slam.
    var usesHinge = false

    /// R8 portrait (the App sets it: design/notes/portrait-R8.md): on a Duo held like a laptop the App shows this scene
    /// turned a quarter clockwise (its midrib along the fold). Every word pop is then drawn turned a quarter back, so it
    /// reads upright, rises toward the screen's top (scene −x), and is placed by its turned box. Scene space and all
    /// the rest are unchanged. Default false (book pose, phones).
    var textTurned = false {
        didSet {
            if textTurned != oldValue { pops.quarterTurn = textTurned }
        }
    }

    /// Where the HUD's snaps row is, in scene space (the glyph a Feast wins flies there; a sting cracks one there; a
    /// wilt droops one there). The App sets it from `HUDLayout` (QA-2 #6: the glyph that changes,
    /// `glyphCenter(snapsLeft − 1)`). nil = a fallback near the bottom of the HUD half.
    var hudSnapsAnchor: CGPoint?

    /// QA-2 #6: the whole snaps row (scene space), when the App knows it: a sting's crimson flash covers it, centred.
    /// nil = the R3 fallback (300 × 96 pt, 90 pt right of the anchor).
    var hudSnapsRowRect: CGRect?

    /// QA-2 #7: false on Home (no snaps row there): no Feast glyph flights, no sting crack or row flash, no wilt glyph
    /// or "Too slow!" pop. The bite, its pops and "Bzzt!" still show. Default true (play, the lesson).
    /// R7 (#4): with no `hudKeepOut` from the App, false also means Home (`isHome`), so the bugs keep clear of Home's
    /// buttons (`homeButtonFrames`, else the `BogScene.homeKeepOut` estimate).
    var showsEconomy = true {
        didSet {
            if showsEconomy != oldValue { keepOutChanged() }
        }
    }

    /// R7 (#4): Home's button frames in scene space, when the App knows them (exact; nil = `homeKeepOut`'s estimate).
    var homeButtonFrames: [CGRect]? {
        didSet {
            if homeButtonFrames != oldValue { keepOutChanged() }
        }
    }

    /// R6 (the Garden): the trap variety to draw (the play lobes, cilia, closed trap and the economy's glyphs). Cosmetic
    /// only. Setting it builds that variety's textures once (do it before play, e.g. with the layout).
    var variety: TrapVariety = .classic {
        didSet {
            if variety != oldValue {
                jaws.setVariety(variety)
                economy.setVariety(variety)
            }
        }
    }

    /// R6 (#7): the HUD's plates in scene space (origin bottom-left, y up), when the App knows them: the score with
    /// the pause button, and the snaps row with the chain chip. Bugs outside the trap are drawn clear of them (and of
    /// the canvas edge). nil = `BogScene.defaultKeepOut(_:)`, the HUD's two outer corners.
    /// R7 (#4): on Home leave it nil and use `homeButtonFrames`.
    var hudKeepOut: [CGRect]? {
        didSet {
            if hudKeepOut != oldValue { keepOutChanged() }
        }
    }

    /// R7 (#4): Home (no economy, no HUD plates): its bog is decoration.
    var isHome: Bool { !showsEconomy && hudKeepOut == nil }

    /// R7 (#4): the plates the bugs keep clear of now: the App's HUD rects, else the HUD's default corners in play,
    /// else (Home) Home's buttons.
    var effectiveKeepOut: [CGRect] {
        if let rects = hudKeepOut { return rects }
        if showsEconomy { return BogScene.defaultKeepOut(layout) }
        return homeButtonFrames ?? BogScene.homeKeepOut(layout)
    }

    /// R7 (#4): the keep-out Core judges resting spots by (`TrapSession.keepOut`, scene space = the session's space):
    /// `effectiveKeepOut`, the midrib band and the edge margins (`BogScene.coreKeepOut(_:layout:)`).
    var coreKeepOut: [CGRect] { BogScene.coreKeepOut(effectiveKeepOut, layout: layout) }

    /// R7 (#4): gives `session` the scene's keep-out now (call it when a session is made, before its first wave).
    func applyKeepOut(to session: TrapSession) {
        session.keepOut = coreKeepOut
    }

    /// R7 (#4): the keep-out changed (plates, Home, layout or a new session): the bug layer's visual easing follows,
    /// and the driver's sessions are told.
    private func keepOutChanged() {
        bugs.keepOut = effectiveKeepOut
        bugs.decorative = isHome
        publishKeepOut()
    }

    private func publishKeepOut() {
        guard let receiver = driver as? SceneKeepOutReceiver else { return }
        receiver.sceneKeepOutChanged(coreKeepOut)
    }

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
    /// R6 (#5): the dusk's warm sun glow (top-left, on the bog only) now.
    var bogSunAlpha: CGFloat { light.sunAlpha }
    /// R6 (#17, tests): the tired trap's dim on its face, and the darkest any layer over the green margin is drawn.
    var tiredFaceDim: CGFloat { jaws.faceDimAlpha }
    var marginShade: CGFloat { jaws.marginShade }
    /// R6 (tests): the variety drawn by the jaws, the Golden Glow twinkles showing, and the open cilia's tips (scene
    /// space, unshaken).
    var drawnVariety: TrapVariety { jaws.variety }
    var rimSparkles: Int { jaws.sparklesShowing }
    var drawnToothTips: [CGPoint] { jaws.drawnToothTips }
    /// R6 (FEAST, tests): whether the last bite was a FEAST event, the hit-stop it started, the banners on screen,
    /// the snaps row's refill flourish, and each caught bug's gulp.
    private(set) var lastBiteWasFeastEvent = false
    private(set) var lastHitStop: Double = 0
    var banners: [String] { pops.activeBanners }
    var rowFlourishing: Bool { economy.flourishing }
    func gulpQueued(ofBug id: Int) -> Bool { bugs.gulpQueued(id) }
    func gulped(ofBug id: Int) -> Bool { bugs.gulpDone(id) }
    /// R6 (#7, tests): what the bugs keep clear of now.
    var bugKeepOut: [CGRect] { bugs.keepOut }
    /// R7 (#4, tests, the CI probe): every sitting bug's drawn footprint now (halo included, scene space, unshaken).
    var sittingBugRects: [CGRect] { bugs.sittingRects }
    /// R7 (#4, tests): bug `id`'s visual-only offset from its Core position (always zero for a catchable bug).
    func drawnNudge(ofBug id: Int) -> CGPoint? { bugs.nudge(id) }
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
    /// R7 (#14, tests): the bog's fireflies glowing at least `BogLight.fireflyFloor` now, and the vignette's colour.
    var glowingFireflies: Int { light.glowingFireflies }
    var vignetteColor: RGBA { light.vignetteRGBA }
    /// The light tint's z (tests: below the trap, so it multiplies the bog only).
    var tintZ: CGFloat { light.tint.zPosition }
    /// R8 (tests, the App): the closing cue drawn now (0 open … 1 at `TrapArt.cueFull`; 0 with touch), the rim shadow
    /// on the lobes, the edge dim's alpha (the edges' darkness: its texture is opaque there) and the bugs' panic.
    var closingCue: CGFloat { jaws.cueLevel }
    var rimShadow: CGFloat { jaws.rimShadow }
    var edgeDim: CGFloat { closingDim.isHidden ? 0 : closingDim.alpha }
    private(set) var bugPanic: CGFloat = 0
    /// R8 (tests): bug `id`'s panic and its visual-only jitter now, and whether it is drawn at all.
    func panic(ofBug id: Int) -> CGFloat? { bugs.panicOf(id) }
    func panicJitter(ofBug id: Int) -> CGPoint? { bugs.jitterOf(id) }
    func isDrawn(bug id: Int) -> Bool { bugs.isDrawn(id) }
    /// R8 (tests, the App): a hinge bite's moment is waiting for the reopen; the digests played so far; the digest's
    /// juice stains and remains showing now.
    var digestPending: Bool { !heldBite.isEmpty }
    private(set) var digestsShown = 0
    var juiceStains: Int { effects.activeStains }
    var remainsShowing: Int { effects.activeRemains }
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

    // MARK: R6 FEAST (the big bite as an event)

    /// A bite of `bigFeastCount`+ bugs, or one scored at a chain of `bigFeastChain` or more, is a FEAST event. A 3–4
    /// bug Feast keeps the R5 treatment.
    static let bigFeastCount = FeastEvent.count
    static let bigFeastChain = FeastEvent.chain
    /// The FEAST's hit-stop (80 ms), camera punch (×1 is the R5 bite's 3 %) and shake.
    static let bigHitStopTime: Double = 0.08
    static let bigPunch: CGFloat = 2
    static let bigShake: CGFloat = 16
    /// The banner and its size.
    static let feastBanner = "FEAST!"
    static let feastBannerSize: CGFloat = 68
    /// R7 (#3): a QUAD's callout size (any 3+ hero bite), and the FEAST's callout at 1.6× it, centred over the trap.
    static let quadCalloutSize: CGFloat = 48
    static let feastCalloutScale: CGFloat = 1.6
    static var feastCalloutSize: CGFloat { quadCalloutSize * feastCalloutScale }

    /// Whether a bite is a FEAST event (`FeastEvent.isBig`).
    static func isBigFeast(_ r: BiteReport) -> Bool { FeastEvent.isBig(r) }

    /// The FEAST's callout under the banner. R7 (#3): "6 bugs · +1,080" (`AppRules.biteCallout`; "×" is the chain's).
    static func bigFeastLabel(count n: Int, points: Int) -> String { AppRules.biteCallout(count: n, points: points) }

    /// The delay before each of `count` caught bugs is gulped (`FeastEvent.gulpDelays`).
    static func gulpDelays(count n: Int) -> [Double] { FeastEvent.gulpDelays(count: n) }

    /// R6 (#7): the HUD's two outer corners in scene space (the score with the pause button at the top, the snaps
    /// row with the chain chip at the bottom), for when the App doesn't pass `hudKeepOut`.
    static func defaultKeepOut(_ l: ScreenLayout) -> [CGRect] {
        let w = l.size.width, h = l.size.height
        let topW: CGFloat = 214, topH: CGFloat = 134, lowW: CGFloat = 252, lowH: CGFloat = 98
        return [CGRect(x: l.hudOnLeft ? 0 : w - topW, y: h - topH, width: topW, height: topH),
                CGRect(x: l.hudOnLeft ? 0 : w - lowW, y: 0, width: lowW, height: lowH)]
    }

    /// R7 (#5): where a sting's word goes when there is no room above its bee's ring (the top of the screen): beside
    /// the ring (outward if it fits, else inward), on the bee's own half (off the crease band) and on the screen.
    static func besideRing(_ p: CGPoint, ring: CGFloat, halfWidth hw: CGFloat, layout l: ScreenLayout) -> CGPoint {
        let w = l.size.width
        let gap = ring + hw + 10
        let onLeft = p.x < l.midX
        let lo = onLeft ? 12 + hw : l.creaseMaxX + BogScene.creaseClear + hw
        let hi = onLeft ? l.creaseMinX - BogScene.creaseClear - hw : w - 12 - hw
        let outward = onLeft ? p.x - gap : p.x + gap
        let inward = onLeft ? p.x + gap : p.x - gap
        let x: CGFloat
        if outward >= lo && outward <= hi {
            x = outward
        } else if inward >= lo && inward <= hi {
            x = inward
        } else {
            x = min(max(outward, lo), hi)
        }
        return CGPoint(x: x, y: min(p.y, l.size.height - 44))
    }

    /// R7 (#4): how far in from each canvas edge the Core keep-out's edge strips reach (pt). Core keeps a resting
    /// centre its radius + 8 beyond a strip, so the drawn footprint (≤ 1.25 r, r ≤ 44) stays `BogBugLayer.edgeGap`
    /// inside the screen.
    static let edgeStrip: CGFloat = 10

    /// R7 (#4): the keep-out for Core (`TrapSession.keepOut`): the `plates` (the HUD's, or Home's buttons), the midrib
    /// band (the crease's half width each side of the trap's centre line, the full height) and four strips along the
    /// canvas edges, all in scene space. Core keeps each resting bug's centre its clearance (radius + 8, or its halo
    /// + 8) from every rect, so the bug and its halo sit clear of the plates, off the midrib and inside the edge.
    static func coreKeepOut(_ plates: [CGRect], layout l: ScreenLayout) -> [CGRect] {
        let w = l.size.width, h = l.size.height
        let far: CGFloat = 400
        let e = edgeStrip
        let cx = l.geometry.center.x
        let crease = ScreenLayout.creaseHalfWidth
        var out = plates.filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        out.append(CGRect(x: cx - crease, y: -far, width: 2 * crease, height: h + 2 * far))
        out.append(CGRect(x: -far, y: -far, width: far + e, height: h + 2 * far))
        out.append(CGRect(x: w - e, y: -far, width: far + e, height: h + 2 * far))
        out.append(CGRect(x: -far, y: -far, width: w + 2 * far, height: far + e))
        out.append(CGRect(x: -far, y: h - e, width: w + 2 * far, height: far + e))
        return out
    }

    /// R7 (#4): Home's button column in scene space (on the HUD page, centred, the clap card and four rows on a fold
    /// screen, three rows elsewhere), for when the App doesn't pass the buttons' frames as `hudKeepOut`. An estimate
    /// of `HomeView`'s stack: the App's real frames are exact.
    static func homeKeepOut(_ l: ScreenLayout) -> [CGRect] {
        let page = l.hudRect
        let w = min(max(page.width - 48, 0), 344)
        let h = l.size.height * (l.hasFold ? 0.7 : 0.48)
        let cy = l.size.height / 2 - 10
        return [CGRect(x: page.midX - w / 2, y: cy - h / 2, width: w, height: h)]
    }

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
    /// R8: the closing dim (hinge input only).
    private let closingDim: SKSpriteNode

    /// R8: the hinge bite held for the reopen (its events), the snaps left before it, where its stingers were drawn,
    /// whether the snapshot has shown the phone shut since, and the wall seconds waited unshut (`digestFallback`).
    private var heldBite: [TrapEvent] = []
    private var heldBefore = 0
    private var heldPoints: [Int: CGPoint] = [:]
    private var heldSawShut = false
    private var heldWait: Double = 0

    /// R8: if a hinge bite's snapshot never shows the phone shut (a pilot, a Core without `shut`), its digest plays
    /// after this many wall seconds anyway.
    static let digestFallback: Double = 0.35

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
        let dimV = SKSpriteNode(texture: BogTextures.closingDim, size: layout.size)
        self.layout = layout
        closingDim = dimV
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
        shaker.addChild(light.sun)
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
        // R8: the closing dim, never shaken, over the bugs and FX (z 50), under the pops (60) and the glyphs (62).
        closingDim.zPosition = 55
        closingDim.color = .black
        closingDim.colorBlendFactor = 1
        closingDim.alpha = 0
        closingDim.isHidden = true
        addChild(closingDim)
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
        bogResize(closingDim, layout.size)
        closingDim.position = CGPoint(x: layout.size.width / 2, y: layout.size.height / 2)
        bugs.canvas = layout.size
        keepOutChanged()
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
        // R8: a held bite belongs to the old session.
        heldBite = []
        heldPoints = [:]
        heldSawShut = false
        heldWait = 0
        bugPanic = 0
        closingDim.alpha = 0
        closingDim.isHidden = true
        // R7 (#4): a new session takes the keep-out too.
        publishKeepOut()
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
        let before = lastSnapsLeft ?? s.snapsLeft
        // R8: with the hinge a bite's moment waits for the reopen (the digest).
        let now = holdBite(events, s, before: before, wallDt: wallDt)
        handle(now, s, g, before: before)
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
        // R8: the hinge never closes the drawn lobes (the phone is the trap); its closure drives the closing cues.
        let hinge = usesHinge
        let cue: CGFloat = hinge ? TrapArt.closingCue(closure) : 0
        let drawn01: CGFloat = hinge ? 0 : TrapArt.closure01(closure)
        jaws.update(fxDt: fxDt, closure01: drawn01, tired: BogScene.tiredness(s.phase),
                    hunger: CGFloat(s.hunger), time: wallTime, night: light.night, dusk: light.dusk,
                    tint: light.lobeTint, tintAlpha: light.lobeTintAlpha, rim: light.rimTint,
                    rimAlpha: light.rimAlpha, cue: cue)
        let dim = TrapArt.edgeDim(cue)
        closingDim.alpha = dim
        closingDim.isHidden = dim < 0.005
        bugPanic = TrapArt.panicLevel(cue)
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
                    hold: holding, panic: bugPanic, hideCaught: hinge)
        for p in bugs.gulps { effects.gulp(at: p) }
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

    // MARK: R8 the digest (hinge input)

    /// R8: whether `e` is the bite itself.
    nonisolated static func isSnap(_ e: TrapEvent) -> Bool {
        if case .snapped = e { return true }
        return false
    }

    /// R8: whether `e` belongs to a bite's moment (held with it for the reopen when it comes in the bite's frame).
    nonisolated static func isBitePart(_ e: TrapEvent) -> Bool {
        switch e {
        case .snapped, .bugCaught, .bugEscaped, .stung, .drySnap, .feast, .luckySnap, .chainUp, .chainBroken,
             .newBest:
            return true
        case .waveStarted, .dayPhaseChanged, .bugArrived, .bugLanded, .bugSipping, .bugHopped, .bugLeft,
             .bugSpooked, .snapStarted, .rearmed, .beeSpared, .lastSnap, .hungry, .wilted, .tired, .finished:
            return false
        }
    }

    /// R8: with hinge input, a frame with a bite hands its moment (`isBitePart`) to the held bite and returns the rest
    /// to handle now; on a later frame, the held bite plays as the digest once the trap reopens (`snapshot.shut` was
    /// true and is false again), or after `digestFallback` wall seconds if the snapshot never showed it shut. A second
    /// bite before the reopen plays the first at once. With touch, nothing is held (a held bite plays at once).
    private func holdBite(_ events: [TrapEvent], _ s: TrapSnapshot, before: Int, wallDt: Double) -> [TrapEvent] {
        if usesHinge && events.contains(where: { BogScene.isSnap($0) }) {
            if !heldBite.isEmpty { playDigest(s) }
            var now: [TrapEvent] = []
            var held: [TrapEvent] = []
            for e in events {
                if BogScene.isBitePart(e) { held.append(e) } else { now.append(e) }
            }
            heldBite = held
            heldBefore = before
            heldSawShut = s.shut
            heldWait = 0
            heldPoints = [:]
            for e in held {
                if case .stung(let id, _, _) = e {
                    heldPoints[id] = bugs.drawnPoint(id) ?? s.bugs.first(where: { $0.id == id })?.position
                }
            }
            return now
        }
        if !heldBite.isEmpty {
            if s.shut {
                heldSawShut = true
            } else {
                heldWait += max(wallDt, 0)
            }
            let reopened = !s.shut && (heldSawShut || heldWait >= BogScene.digestFallback)
            if !usesHinge || reopened { playDigest(s) }
        }
        return events
    }

    /// R8: plays the held bite as the digest now (`handle(…, digest: true)`) and lets it go.
    private func playDigest(_ s: TrapSnapshot) {
        let held = heldBite
        let before = heldBefore
        heldBite = []
        heldSawShut = false
        heldWait = 0
        guard !held.isEmpty else { return }
        digestsShown += 1
        handle(held, s, layout.geometry, before: before, digest: true)
        heldPoints = [:]
    }

    /// One frame's events. R8: `digest` replays a held hinge bite as the trap reopens: no slam (the phone did that), no
    /// hit-stop or white flash, no bug sinking or gulping (they were eaten out of sight); the juice stain and remains
    /// where each was caught; the pops, the FEAST banner and burst, the glyph flights and the camera punch as usual.
    private func handle(_ events: [TrapEvent], _ s: TrapSnapshot, _ g: TrapGeometry, before: Int,
                        digest: Bool = false) {
        guard !events.isEmpty else { return }
        let pal = TrapArt.palette
        byId.removeAll(keepingCapacity: true)
        for b in s.bugs { byId[b.id] = b }
        var caughtPoints: [CGPoint] = []
        var caughtIds: [(Int, CGPoint)] = []
        var caughtRadius: CGFloat = 0
        var big = false
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
                let n = report.caught.count
                // R6: a FEAST event (5+ bugs, or a ×4+ chain) hits harder: an 80 ms hit-stop, a bigger punch.
                big = BogScene.isBigFeast(report)
                lastBiteWasFeastEvent = big
                if digest {
                    // R8: the reopen. The FEAST still lands with its punch and a softer shake; a plain bite with a
                    // small punch.
                    punch = big ? BogScene.bigPunch : (n > 0 ? 0.6 : 0)
                    if big { shakeAmp = BogScene.bigShake * 0.5 }
                    continue
                }
                jaws.slam()
                light.pulse()
                punch = big ? BogScene.bigPunch : (n > 0 ? 1 : 0.5)
                var amp: CGFloat = n > 0 ? min(4 + 2 * CGFloat(n), 12) : 3
                if !report.stingers.isEmpty { amp = max(amp, 6) }
                if big { amp = BogScene.bigShake }
                shakeAmp = amp
                if n > 0 || !report.stingers.isEmpty {
                    hitStop = big ? BogScene.bigHitStopTime : BogScene.hitStopTime
                    lastHitStop = hitStop
                }
                if n > 0 { effects.impact(at: g.center, height: g.b * 2) }
            case .bugCaught(let id, let species, let position):
                caughtPoints.append(position)
                caughtIds.append((id, position))
                caughtRadius = max(caughtRadius, bugs.radius(species))
                if digest {
                    // R8: the bug is gone; a gold juice stain and its remains are where it was.
                    effects.digest(at: position, radius: bugs.radius(species), tint: tint)
                } else {
                    bugs.markCaught(id, at: position)
                    effects.squish(at: position, radius: bugs.radius(species), tint: tint)
                }
            case .bugEscaped(let id, let species):
                // R8: on the reopen the escapers are long gone (they fled during the close, on screen).
                if !digest, let b = byId[id] {
                    let p = bugs.drawnPoint(id) ?? b.position
                    effects.whiff(at: p, heading: CGFloat(b.heading), radius: bugs.radius(species))
                }
            case .stung(let id, let species, let cost):
                // R8: on the reopen, where the stinger was drawn at the shut.
                let heldAt: CGPoint? = digest ? heldPoints[id] : nil
                let p = heldAt ?? bugs.drawnPoint(id) ?? byId[id]?.position ?? g.center
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
            let hero = feasted || n >= 3 || big
            // R3 (#8): a bite with a stinger scores ×1 and says so ("Stung! · +172").
            var label = stung ? BogScene.stungLabel(points: r.points) : BogScene.heroLabel(count: n, points: r.points)
            if big { label = BogScene.bigFeastLabel(count: n, points: r.points) }
            // R3 (#15): every catch pop is big (≥ 28 pt even when it must shrink to fit) and pops with an overshoot.
            var size: CGFloat = hero ? BogScene.quadCalloutSize : (n >= 2 ? 40 : 36)
            // R7 (#3): the FEAST's callout is 1.6× a QUAD's, centred over the trap (side 0: across the whole trap).
            if big { size = BogScene.feastCalloutSize }
            let popSide = big ? 0 : side
            let rise: CGFloat = hero ? 30 : 44
            // A clean bite that keeps the chain going without growing it says so ("×1.5 held"). R7 (#5): not when a
            // lucky line shows (never three pops stacked).
            let held = !stung && !broken && !chained && r.chainMultiplier > 1.001 && lucky.isEmpty
            // R5 (#12): room for each line under the callout, with its own rise (they never stack into one another).
            let extra = CGFloat(lucky.count + (held ? 1 : 0)) * BogScene.lineStep
            var near = CGPoint(x: big ? g.center.x : a.x, y: a.y + 2 * caughtRadius + 20)
            if big {
                // R6: the FEAST banner, big, springing in with an overshoot and sparkles, above the callout. R7 (#3):
                // centred over the trap, not on the crowd's side.
                var bs = BogScene.feastBannerSize
                let top = g.center.y + g.b * 0.18
                let bp = placePop(BogScene.feastBanner, size: &bs, near: CGPoint(x: g.center.x, y: top), side: 0,
                                  hero: true, rise: 18, minY: extra + BogScene.lineStep + size * 1.2,
                                  minSize: 44, avoid: obstacles, banner: true)
                pops.pop(BogScene.feastBanner, at: bp, size: bs, fill: BogPaint.ui(pal.gold),
                         stroke: BogPaint.ui(pal.ink), rise: 18, life: 1.7, hero: true, banner: true)
                // R8 portrait: the banner's box as drawn (turned when `textTurned`).
                let bb = BogPops.drawnBox(BogPops.measure(BogScene.feastBanner, size: bs), turned: textTurned)
                effects.bannerSparkles(around: CGRect(x: bp.x - bb.width / 2, y: bp.y - bb.height / 2,
                                                      width: bb.width, height: bb.height))
                effects.feastBurst(at: a, tint: tint)
                near = CGPoint(x: bp.x, y: bp.y - bs * 0.62 - size * 0.62 - 12)
            }
            let pt = placePop(label, size: &size, near: near, side: popSide, hero: hero, rise: rise, minY: extra,
                              minSize: BogScene.minCatchPop, avoid: obstacles, downFirst: big)
            pops.pop(label, at: pt, size: size, fill: BogPaint.ui(pal.gold), stroke: BogPaint.ui(pal.ink), rise: rise,
                     life: hero ? 1.5 : 1.2, hero: hero)
            heroSaidStung = stung
            var y = pt.y - size * 0.6 - 30
            if held {
                var hs: CGFloat = 28
                let text = BogScene.heldLabel(r.chainMultiplier)
                let hp = placePop(text, size: &hs, near: CGPoint(x: pt.x, y: y), side: popSide, hero: false, rise: 30,
                                  minSize: 24, avoid: obstacles, downFirst: true)
                pops.pop(text, at: hp, size: hs, fill: BogPaint.ui(TrapArt.sipRing), stroke: BogPaint.ui(pal.ink),
                         rise: 30, delay: 0.1, life: 1.2)
                y = hp.y - BogScene.lineStep
            }
            for sp in lucky {
                var ls: CGFloat = 28
                let text = BogScene.luckyLabel(sp, snaps: showsEconomy)
                let lp = placePop(text, size: &ls, near: CGPoint(x: pt.x, y: y), side: popSide, hero: false, rise: 30,
                                  avoid: obstacles, downFirst: true)
                pops.pop(text, at: lp, size: ls, fill: BogPaint.ui(TrapArt.sipRing), stroke: BogPaint.ui(pal.ink),
                         rise: 30, delay: 0.12, life: 1.3)
                y = lp.y - BogScene.lineStep
            }
            if hero {
                // R6: the catch's sparkle is nectar gold, like its juice.
                effects.sparkBurst(at: a, count: 12, color: BogPaint.ui(pal.gold), speed: 240, size: 22)
            }
            if r.snapsBack > 0 && showsEconomy {
                // QA-2 #2/#3: every glyph flies, but only the snaps Core really added hold the numeral back (at the
                // cap, or in the lesson, the number never dips).
                // R5 (#12): the glyphs take the arc that crosses the fewest live pops (never over "Golden!").
                economy.fly(count: r.snapsBack,
                            counted: BogScene.countedFlights(snapsBack: r.snapsBack, before: before, after: s.snapsLeft),
                            from: a, to: snapsAnchor, avoid: livePopRects)
            }
            if big {
                // R6: the snaps row refills with a flourish once the won glyphs have landed.
                if showsEconomy {
                    let wait = r.snapsBack > 0
                        ? BogEconomy.flightTime + Double(r.snapsBack - 1) * BogEconomy.flightGap : 0.1
                    economy.flourish(row: hudSnapsRowRect, anchor: snapsAnchor, delay: wait)
                }
                // R6: the caught bugs are gulped into the midrib one after another, nearest it first. R8: not on the
                // reopen (they were eaten as the phone shut).
                if !digest {
                    let cx = g.center.x
                    let order = caughtIds.sorted { abs($0.1.x - cx) < abs($1.1.x - cx) }
                    let delays = BogScene.gulpDelays(count: order.count)
                    for (k, c) in order.enumerated() { bugs.queueGulp(c.0, delay: delays[k]) }
                }
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
            let hw = box.width * over / 2, hh = box.height * over / 2
            let yellow = BogPaint.ui(RGBA(hex: 0xFFD23A))
            // R7 (#5): "Stung!" / "Bzzt!" goes above the ring, never under it or over the stinger. If dodging the
            // other pops pulled it down onto the ring, it is lifted straight back above it (other pops give way to
            // the stinger); only a bee at the very top of the screen gets its word beside the ring instead.
            if c.y - hh < p.y + ring + 4 && abs(c.x - p.x) < hw + ring {
                let lifted = CGPoint(x: c.x, y: p.y + ring + 8 + hh)
                if lifted.y + hh + 36 <= layout.size.height - 4 {
                    c = lifted
                } else {
                    c = BogScene.besideRing(p, ring: ring, halfWidth: hw, layout: layout)
                }
            }
            pops.pop(text, at: c, size: size, fill: yellow, stroke: BogPaint.ui(pal.ink), rise: 36)
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
            // R3 (#15): "Hungry! −1 snap", a crimson tag over the snaps row, and the glyph droops off it.
            // R9: it starts above the row's "SNAPS" label (at + 46 it sat on the label, frame 34).
            let anchor = snapsAnchor
            var size: CGFloat = 28
            let text = BogScene.wiltedLabel
            let p = placePop(text, size: &size, near: CGPoint(x: anchor.x + 60, y: anchor.y + 84),
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
                          downFirst: Bool = false, banner: Bool = false) -> CGPoint {
        let g = layout.geometry
        let over = 1 + (banner ? BogPops.bannerOvershoot : BogPops.overshoot(hero: hero))
        let w = layout.size.width, h = layout.size.height
        // R8 portrait (`textTurned`): the pop is drawn turned, so its text runs along y, it rises toward −x, and the
        // lines "under" a callout come out along +x (the screen's down).
        let turned = pops.quarterTurn
        let leftEdge = inTrap ? max(g.center.x - g.a - TrapArt.exteriorWidth, 12) : 12
        let rightEdge = inTrap ? min(g.center.x + g.a + TrapArt.exteriorWidth, w - 12) : w - 12
        let lo: CGFloat, hi: CGFloat
        if side == 0 {
            // R7 (#3): the FEAST's banner and callout, centred over the whole trap.
            lo = leftEdge
            hi = rightEdge
        } else if side < 0 {
            lo = leftEdge
            hi = layout.creaseMinX - BogScene.creaseClear
        } else {
            lo = layout.creaseMaxX + BogScene.creaseClear
            hi = rightEdge
        }
        let yLo = inTrap ? g.center.y - g.b + 40 : 40
        let yHi = inTrap ? min(g.center.y + g.b - 30, h - 24) : h - 24
        // The length the text may take: across its half (landscape), or up the trap's height (turned).
        let avail = turned ? max(yHi - yLo, 40) : max(hi - lo, 40)
        var box = BogPops.measure(text, size: size)
        if box.width * over > avail {
            // Shrink to fit, but never under `minSize` unless even that would cross the crease (the crease wins).
            let fit = max((size * avail / (box.width * over)).rounded(.down), 12)
            var next = max(fit, min(minSize, size))
            if BogPops.measure(text, size: next).width * over > avail { next = fit }
            size = next
            box = BogPops.measure(text, size: size)
        }
        let drawn = BogPops.drawnBox(box, turned: turned)
        let half = drawn.width * over / 2
        let riseX: CGFloat = turned ? rise : 0
        let riseY: CGFloat = turned ? 0 : rise
        let floorY = yLo + (turned ? 0 : minY) + drawn.height / 2
        let ceilY = yHi - riseY - drawn.height / 2
        func clampX(_ v: CGFloat) -> CGFloat {
            lo + half + riseX <= hi - half ? min(max(v, lo + half + riseX), hi - half) : (lo + hi) / 2
        }
        func clampY(_ v: CGFloat) -> CGFloat { floorY <= ceilY ? min(max(v, floorY), ceilY) : ceilY }
        let start = CGPoint(x: clampX(p.x), y: clampY(p.y))
        let blocks = avoid + pops.liveRects
        guard !blocks.isEmpty else { return start }
        let hh = drawn.height * over / 2
        func cost(_ c: CGPoint) -> CGFloat {
            let foot = BogScene.popFootprint(center: c, halfWidth: half, halfHeight: hh, rise: rise, turned: turned)
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
        for offset in BogScene.popOffsets(downFirst: downFirst) {
            // Turned: the screen's down is scene +x and its right scene +y.
            let o = turned ? CGPoint(x: -offset.y, y: offset.x) : offset
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
    /// R8 portrait (`turned`): the half extents are the turned box's (scene space), it rises toward −x and its shadow
    /// sits +x, +y.
    static func popFootprint(center c: CGPoint, halfWidth: CGFloat, halfHeight: CGFloat, rise: CGFloat,
                             turned: Bool = false) -> CGRect {
        if turned {
            let r = max(rise, 0)
            return CGRect(x: c.x - halfWidth - r, y: c.y - halfHeight, width: 2 * halfWidth + 3 + r,
                          height: 2 * halfHeight + 2).insetBy(dx: -popGap, dy: -popGap)
        }
        return CGRect(x: c.x - halfWidth, y: c.y - halfHeight - 3, width: 2 * halfWidth + 2,
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

    /// "Double", "Triple", "Quad", "FEAST" (nil for a single bug). R7 (#3): never "×" for a bug count ("×" is only
    /// the chain): `AppRules.biteName`.
    static func countLabel(_ n: Int) -> String? { AppRules.biteName(n) }

    /// The bite's one callout. R7 (#3): the bug count in words, "5 bugs · +540", or "+12" for one bug
    /// (`AppRules.biteCallout`). The points are Core's (`BiteReport.points`, the FEAST's ×2 inside).
    static func heroLabel(count n: Int, points: Int) -> String { AppRules.biteCallout(count: n, points: points) }

    static func feastLabel(_ snapsBack: Int) -> String {
        snapsBack > 0 ? "Feast! +\(snapsBack) snap\(snapsBack == 1 ? "" : "s")" : "Feast!"
    }

    /// The lucky bug's line under the hero callout (the snaps it won fly to the HUD as glyphs). R7 (#5): in plain words,
    /// "Golden scarab! +2 snaps", "Ladybird! +1 snap"; with no snaps row (Home, the Zen Bog) just "Golden scarab!"
    /// (`AppRules.luckyText`).
    static func luckyLabel(_ s: BugSpecies, snaps: Bool = true) -> String { AppRules.luckyText(s, snaps: snaps) }

    /// The hunger wilt's pop (R3 #15: says what happened and what it cost).
    static let wiltedLabel = "Hungry! −1 snap"
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
