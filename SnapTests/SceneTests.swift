import CoreGraphics
import Foundation
import SpriteKit
import UIKit
import Testing
@testable import Snap

/// A scripted driver for the scene tests: returns queued frames, records taps.
@MainActor
final class BogSceneFakeDriver: SceneDriver {
    var frames: [(TrapSnapshot, [TrapEvent])] = []
    var current = TrapSnapshot()
    var taps: [CGPoint] = []

    func advance(dt: TimeInterval, now: TimeInterval) -> (TrapSnapshot, [TrapEvent]) {
        if !frames.isEmpty {
            let f = frames.removeFirst()
            current = f.0
            return f
        }
        current.time += dt
        return (current, [])
    }

    func sceneTapped(at point: CGPoint, time: TimeInterval) { taps.append(point) }
}

/// R7 (#4): a driver that takes the scene's Core keep-out (records every one it is sent).
@MainActor
final class SceneKeepOutSink: SceneDriver, SceneKeepOutReceiver {
    var received: [[CGRect]] = []

    func advance(dt: TimeInterval, now: TimeInterval) -> (TrapSnapshot, [TrapEvent]) { (TrapSnapshot(), []) }
    func sceneTapped(at point: CGPoint, time: TimeInterval) {}
    func sceneKeepOutChanged(_ rects: [CGRect]) { received.append(rects) }
}

/// Scene module tests: trap geometry (lobes, teeth, rim), every species' art, the palette, the closure mapping, the
/// day light, and a smoke run of `BogScene` through landing, sipping, a bite, a sting, the night and a reset.
@MainActor
struct SceneTests {
    static let duo = ScreenLayout(hasFold: true)
    static var geometry: TrapGeometry { duo.geometry }

    // MARK: Geometry

    @Test func lobesSplitAtTheMidrib() {
        let g = SceneTests.geometry
        let left = TrapArt.lobePath(side: -1, geometry: g, closure01: 0).boundingBoxOfPath
        let right = TrapArt.lobePath(side: 1, geometry: g, closure01: 0).boundingBoxOfPath
        #expect(left.maxX <= g.center.x + CGFloat(0.5))
        #expect(right.minX >= g.center.x - CGFloat(0.5))
        #expect(abs(left.minX - (g.center.x - g.a)) < CGFloat(1))
        #expect(abs(right.maxX - (g.center.x + g.a)) < CGFloat(1))
        // R3: a clam, not a half ellipse: the margin dips at the midrib's ends (the notch), so it is a little shorter.
        #expect(right.height <= 2 * g.b + CGFloat(0.5))
        #expect(right.height > 2 * (g.b - TrapArt.notchDepth))
        let shoulder = TrapArt.marginPoint(g, side: 1, t: 1.3, a: g.a, b: g.b)
        let notch = TrapArt.marginPoint(g, side: 1, t: .pi / 2, a: g.a, b: g.b)
        #expect(shoulder.y - notch.y > CGFloat(20))
        // …and the lobes' inner edges part there (the dark gap), meeting in the middle under the midrib.
        #expect(notch.x - g.center.x > CGFloat(4))
        // Closing foreshortens the lobe towards the midrib, by a little.
        let shut = TrapArt.lobePath(side: 1, geometry: g, closure01: 1).boundingBoxOfPath
        #expect(shut.width < right.width - CGFloat(5))
        #expect(shut.width > right.width * CGFloat(0.8))
        // The face sits inside the lobe.
        let face = TrapArt.lobeFacePath(side: -1, geometry: g).boundingBoxOfPath
        #expect(face.minX > left.minX && face.height < left.height)
    }

    @Test func teethRunRoundTheOuterRim() {
        let g = SceneTests.geometry
        for side in [-1, 1] {
            let teeth = TrapArt.teeth(side: side, geometry: g)
            #expect(teeth.count == TrapArt.teethPerSide)
            for t in teeth {
                let r = g.normalizedRadius(t.root)
                #expect(r > 0.97 && r < 1.0)
                // On its own side of the midrib, pointing away from the trap's centre.
                if side < 0 { #expect(t.root.x < g.center.x) } else { #expect(t.root.x > g.center.x) }
                let out = CGPoint(x: t.root.x + cos(t.angle) * 10, y: t.root.y + sin(t.angle) * 10)
                #expect(g.normalizedRadius(out) > r)
                #expect(t.length >= CGFloat(18) && t.length <= CGFloat(66))
                // Cilia, not spikes (R2: 40 % thinner than R1).
                #expect(t.width <= CGFloat(7.2))
                // The tip stays on the canvas when open.
                let tip = CGPoint(x: t.root.x + cos(t.angle) * t.length, y: t.root.y + sin(t.angle) * t.length)
                #expect(tip.x > CGFloat(0) && tip.x < g.sceneSize.width)
                #expect(tip.y > CGFloat(0) && tip.y < g.sceneSize.height)
            }
        }
    }

    @Test func teethLeanInAsTheTrapCloses() {
        let g = SceneTests.geometry
        let open = TrapArt.teethPath(side: -1, geometry: g, closure01: 0).boundingBoxOfPath
        let shut = TrapArt.teethPath(side: -1, geometry: g, closure01: 1).boundingBoxOfPath
        #expect(!open.isEmpty && !shut.isEmpty)
        // Open, the left teeth reach past the zone's left edge; snapped, they have swung in over the rim.
        #expect(open.minX < g.center.x - g.a - CGFloat(20))
        #expect(shut.minX > open.minX + CGFloat(20))
        #expect(TrapArt.toothReach(lean: 0) > CGFloat(0.99))
        #expect(TrapArt.toothReach(lean: TrapArt.toothLean(closure01: 1)) < CGFloat(0))
        let mid = TrapArt.toothReach(lean: TrapArt.toothLean(closure01: 0.5))
        #expect(mid > CGFloat(0) && mid < CGFloat(0.9))
    }

    @Test func closureMapsToTheSnapDepth() {
        #expect(abs(TrapArt.closure01(0)) < CGFloat(0.0001))
        #expect(abs(TrapArt.closure01(Tuning.snapDepth) - CGFloat(1)) < CGFloat(0.0001))
        #expect(abs(TrapArt.closure01(Tuning.snapDepth * 3) - CGFloat(1)) < CGFloat(0.0001))
        #expect(abs(TrapArt.closure01(-5)) < CGFloat(0.0001))
        #expect(abs(TrapArt.closure01(.nan)) < CGFloat(0.0001))
        let half = TrapArt.closure01(Tuning.snapDepth / 2)
        #expect(abs(half - CGFloat(0.5)) < CGFloat(0.001))
    }

    @Test func hairsAndGlandsSitOnTheLobes() {
        let g = SceneTests.geometry
        for side in [-1, 1] {
            let hairs = TrapArt.triggerHairs(side: side, geometry: g)
            #expect(hairs.count == 3)
            for h in hairs {
                #expect(g.contains(h))
                #expect(g.lobe(of: h) == side)
                #expect(!g.onRim(h))
            }
            for p in TrapArt.rimGlands(side: side, geometry: g) {
                #expect(abs(g.normalizedRadius(p) - TrapGeometry.rimStart) < 0.01)
            }
        }
        #expect(!TrapArt.midribPath(geometry: g).boundingBoxOfPath.isEmpty)
        #expect(!TrapArt.veinsPath(side: 1, geometry: g).boundingBoxOfPath.isEmpty)
    }

    // MARK: Bugs

    @Test func everySpeciesHasArtThatFits() {
        for s in BugSpecies.allCases {
            let r = TrapArt.defaultRadius(s)
            let body = TrapArt.bugBody(s, radius: r)
            #expect(!body.isEmpty)
            let box = body.boundingBoxOfPath
            let e = TrapArt.bugExtent(radius: r)
            #expect(box.width > r && box.height > r * CGFloat(0.3))
            #expect(box.minX >= -e && box.maxX <= e && box.minY >= -e && box.maxY <= e)
            // Facing +x: the head (and the eyes) are at the front.
            let art = TrapArt.bugArt(s, radius: r)
            #expect(art.eyes.boundingBoxOfPath.midX > 0)
            #expect(!art.pupils.isEmpty)
            let wings = TrapArt.bugWings(s, radius: r)
            if s == .ant || s == .cricket {
                #expect(wings.isEmpty)
            } else {
                #expect(!wings.isEmpty)
                let wb = wings.boundingBoxOfPath
                #expect(wb.minY >= -e && wb.maxY <= e && wb.minX >= -e && wb.maxX <= e)
            }
        }
    }

    @Test func bugImagesRender() {
        for s in BugSpecies.allCases {
            let img = TrapArt.bugImage(s, radius: TrapArt.defaultRadius(s), scale: 1)
            #expect(img != nil)
            #expect((img?.width ?? 0) > 10)
        }
    }

    @Test func protectedBugsLookTheirPart() {
        // Bees are yellow and dark-banded; a wasp is yellow too but has brows; nothing protected is crimson.
        let bee = TrapArt.bugColors(.bee)
        #expect(bee.body.r > 0.9 && bee.body.g > 0.7 && bee.body.b < 0.4)
        #expect(BogPaint.contrast(bee.body, bee.accent) > 7)
        #expect(!TrapArt.bugArt(.wasp, radius: 16).brows.isEmpty)
        #expect(TrapArt.bugArt(.bee, radius: 16).brows.isEmpty)
        for s in BugSpecies.allCases {
            // Every bug's outline separates it from the crimson face.
            #expect(BogPaint.contrast(TrapArt.outline, TrapArt.palette.lobeOuter) > 3)
            let c = TrapArt.bugColors(s)
            #expect(c.body.a > 0.99)
        }
    }

    @Test func defaultRadiiMatchTheBrief() {
        // R2: R1's radii × 1.8 (a housefly is 50 pt across, a gnat 25).
        #expect(abs(TrapArt.defaultRadius(.housefly) - CGFloat(25.2)) < CGFloat(0.01))
        #expect(abs(TrapArt.defaultRadius(.gnat) - CGFloat(12.6)) < CGFloat(0.01))
        #expect(abs(TrapArt.defaultRadius(.dragonfly) - CGFloat(43.2)) < CGFloat(0.01))
        #expect(abs(TrapArt.defaultRadius(.bumblebee) - CGFloat(39.6)) < CGFloat(0.01))
        #expect(abs(TrapArt.baseRadius(.gnat) - CGFloat(7)) < CGFloat(0.01))
        // The scene's art radius is never smaller than that, and never Core's radius scaled twice.
        let layer = BogBugLayer()
        for s in BugSpecies.allCases {
            let r = layer.radius(s)
            #expect(r >= TrapArt.defaultRadius(s) - CGFloat(0.01))
            #expect(r <= max(BugCatalog.info(s).radius, TrapArt.defaultRadius(s)) + CGFloat(0.01))
        }
        // Nectar drops are drawn 30 % smaller than Core's radius (the bugs are the subject).
        #expect(abs(BogTextures.nectarDrawnRadius(14) - CGFloat(10)) < CGFloat(0.01))
    }

    // MARK: Palette and light

    @Test func paletteContrast() {
        let p = TrapArt.palette
        #expect(BogPaint.contrast(p.text, p.ink) > 7)
        #expect(BogPaint.contrast(p.gold, p.ink) > 7)
        #expect(BogPaint.contrast(p.teeth, p.bogDeep) > 4.5)
        #expect(BogPaint.contrast(p.nectar, p.lobeInner) > 3)
        #expect(BogPaint.contrast(p.rim, p.bogDeep) > 4.5)
        #expect(BogPaint.contrast(p.ink, p.lobeOuter) > 3)
        #expect(BogPaint.contrast(p.lobeOuter, p.lobeInner) > 1.8)
        #expect(BogPaint.contrast(p.danger, p.ink) > 3)
        // R6: the catch spray is nectar gold (never beige, never red: 4+).
        let j = BogEffects.juiceColor
        #expect(j.r > 0.9 && j.g > 0.6 && j.b < 0.45)
    }

    @Test func dayLightMovesThroughTheDay() {
        let morning = BogLight.key(at: 0), noon = BogLight.key(at: 1), dusk = BogLight.key(at: 2),
            night = BogLight.key(at: 3)
        #expect(morning.env.b < morning.env.r)
        #expect(noon.env.r > 0.99 && noon.env.g > 0.99 && noon.env.b > 0.99)
        #expect(dusk.env.g < dusk.env.r)
        #expect(night.env.b > night.env.r && night.env.r < 0.7)
        #expect(BogLight.nightness(0) < CGFloat(0.01))
        #expect(BogLight.nightness(3.5) > CGFloat(0.99))
        #expect(BogLight.duskness(2) > CGFloat(0.9))
        // Clamped and finite.
        let far = BogLight.key(at: 99)
        #expect(abs(far.env.r - BogLight.keys[4].env.r) < 0.0001)
        let bad = BogLight.key(at: .nan)
        #expect(bad.env.r.isFinite)
    }

    @Test func calloutWords() {
        // R7 (#3): the bug count in words; "×" is only ever the chain.
        #expect(BogScene.countLabel(1) == nil)
        #expect(BogScene.countLabel(2) == "Double")
        #expect(BogScene.countLabel(4) == "Quad")
        #expect(BogScene.countLabel(6) == "FEAST")
        #expect(BogScene.feastLabel(1) == "Feast! +1 snap")
        #expect(BogScene.feastLabel(2) == "Feast! +2 snaps")
        #expect(BogScene.heroLabel(count: 5, points: 540) == "5 bugs · +540")
        #expect(BogScene.heroLabel(count: 1, points: 12) == "+12")
        #expect(BogScene.bigFeastLabel(count: 6, points: 1_080) == "6 bugs · +1,080")
        #expect(!BogScene.heroLabel(count: 7, points: 900).contains("×"))
        #expect(abs(BogScene.feastCalloutSize - BogScene.quadCalloutSize * CGFloat(1.6)) < CGFloat(0.001))
        // R7 (#5): lucky bugs in plain words (no snaps row: no snaps named).
        let golden = BogScene.luckyLabel(.goldenScarab)
        #expect(golden == AppRules.luckyText(.goldenScarab, snaps: true))
        #expect(golden != "Golden!" && golden.contains("snap"))
        #expect(!BogScene.luckyLabel(.ladybird, snaps: false).contains("snap"))
        #expect(BogScene.multiplier(1.5) == "×1.5")
        #expect(BogScene.multiplier(2) == "×2")
        // R3 (#8, #15).
        #expect(BogScene.stungLabel(points: 172) == "Stung! · +172")
        #expect(BogScene.heldLabel(1.5) == "×1.5 held")
        #expect(BogScene.wiltedLabel == "Hungry! −1 snap")
    }

    // MARK: The scene

    static func bug(_ id: Int, _ s: BugSpecies, _ p: CGPoint, _ a: BugActivity, height: Double = 0) -> BugState {
        let g = SceneTests.geometry
        return BugState(id: id, species: s, position: p, heading: 0.3, activity: a, height: height,
                        sipProgress: a == .sipping ? 0.5 : 0, inTrap: g.contains(p), onRim: g.onRim(p))
    }

    static func crowd() -> TrapSnapshot {
        let g = SceneTests.geometry
        var bugs: [BugState] = []
        var i = 0
        for (k, s) in BugSpecies.allCases.enumerated() {
            let a = Double(k) / Double(BugSpecies.allCases.count) * 2 * .pi
            let p = g.point(angle: a, radius: 0.6)
            let acts: [BugActivity] = [.sipping, .walking, .arriving, .hopping, .leaving, .escaped, .released]
            bugs.append(bug(i, s, p, acts[k % acts.count], height: k % 3 == 2 ? 0.6 : 0))
            i += 1
        }
        let nectar = (0..<6).map { NectarDrop(id: $0, position: g.point(angle: Double($0), radius: 0.4), radius: 9,
                                              occupant: $0 == 0 ? 0 : nil) }
        return TrapSnapshot(phase: .playing, mode: .feed, time: 1, bugs: bugs, nectar: nectar, closure: 0,
                            snapsLeft: 8, dayClock: 0.5)
    }

    @Test func sceneDrawsEveryBugAndNectar() {
        let scene = BogScene(layout: SceneTests.duo)
        let s = SceneTests.crowd()
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(scene.liveBugNodes == BugSpecies.allCases.count)
        #expect(scene.nectarDrops == 6)
        #expect(scene.teethCount == 2 * TrapArt.teethPerSide)
        #expect(scene.foldBandShowing)
        // Once warm, drawing frames builds no new textures.
        let warm = BogTextures.count
        for k in 0..<30 {
            var f = s
            f.time = 1 + Double(k) / 120
            scene.show(f, events: [], dt: 1.0 / 120.0)
        }
        #expect(BogTextures.count == warm)
        // Bugs that leave the snapshot leave the screen.
        var fewer = s
        fewer.bugs = Array(s.bugs.prefix(3))
        scene.show(fewer, events: [], dt: 1.0 / 120.0)
        #expect(scene.liveBugNodes == 3)
    }

    @Test func noFoldDrawsTheMidribOnly() {
        let phone = ScreenLayout.make(viewSize: CGSize(width: 852, height: 393), hasFold: false)
        let scene = BogScene(layout: phone)
        scene.show(TrapSnapshot(), events: [], dt: 1.0 / 60.0)
        #expect(!scene.foldBandShowing)
        #expect(abs(scene.size.width - phone.size.width) < CGFloat(0.5))
        #expect(phone.size.width > ScreenLayout.canvasWidth)
    }

    /// Touch input (R8: `usesHinge` false, the default): the tap's sweep draws the lobes closing and the bite slams.
    @Test func closureTracksAndTheBiteSlams() {
        let scene = BogScene(layout: SceneTests.duo)
        #expect(!scene.usesHinge)
        var s = SceneTests.crowd()
        s.closure = Tuning.snapDepth * 0.5
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(abs(scene.drawnClosure01 - CGFloat(0.5)) < CGFloat(0.01))
        #expect(scene.toothReach > CGFloat(0) && scene.toothReach < CGFloat(0.9))
        #expect(scene.jawSlam < CGFloat(0.01))

        // The bite: two bugs caught, one escaped.
        s.closure = Tuning.snapDepth
        let report = BiteReport(caught: [.housefly, .gnat], escaped: 1, stingers: [], points: 26, countMultiplier: 2,
                                chainMultiplier: 1.5, snapsBack: 0, snapsLost: 0, duration: 0.1, time: 1)
        let events: [TrapEvent] = [.snapped(report),
                                   .bugCaught(id: 0, species: .housefly, position: s.bugs[0].position),
                                   .bugCaught(id: 1, species: .gnat, position: s.bugs[1].position),
                                   .bugEscaped(id: 2, species: .fruitFly), .chainUp(count: 2, multiplier: 2)]
        scene.show(s, events: events, dt: 1.0 / 120.0)
        for _ in 0..<9 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.jawSlam > CGFloat(0.95))
        #expect(scene.toothReach < CGFloat(-0.8))
        #expect(scene.popTexts.contains("2 bugs · +26"), "\(scene.popTexts)")
        // One hero callout: the chain step is the HUD chip's, never a line on the lobe.
        let chainLine = scene.popTexts.contains { $0.hasPrefix("chain") }
        #expect(!chainLine)
        #expect(scene.activeEffects > 0)
        #expect(scene.cameraScale > CGFloat(1.001))

        // It lets go, and the camera settles.
        s.closure = 0
        for _ in 0..<120 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.jawSlam < CGFloat(0.01))
        #expect(abs(scene.cameraScale - CGFloat(1)) < CGFloat(0.001))
        #expect(scene.toothReach > CGFloat(0.99))

        // A sting pops "Bzzt!".
        let sting = BiteReport(caught: [], escaped: 0, stingers: [.bee], points: 0, countMultiplier: 0,
                               chainMultiplier: 1, snapsBack: 0, snapsLost: 1, duration: 0.1, time: 2)
        scene.show(s, events: [.snapped(sting), .stung(id: 13, species: .bee, cost: 1)], dt: 1.0 / 120.0)
        for _ in 0..<12 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.popTexts.contains("Bzzt!"))

        // A new session clears it all.
        scene.reset()
        #expect(scene.activePops == 0)
        #expect(scene.liveBugNodes == 0)
        #expect(scene.activeEffects == 0)
    }

    @Test func everyEventIsHandled() {
        let scene = BogScene(layout: SceneTests.duo)
        let s = SceneTests.crowd()
        let p = s.bugs[0].position
        let report = BiteReport(caught: [.housefly, .gnat, .fruitFly, .ladybird, .goldenScarab], escaped: 0,
                                stingers: [.wasp], points: 900, countMultiplier: 5, chainMultiplier: 2,
                                snapsBack: 4, snapsLost: 2, duration: 0.08, time: 1)
        let events: [TrapEvent] = [
            .waveStarted(index: 3, phase: .noon), .dayPhaseChanged(.dusk), .bugArrived(id: 0, species: .housefly),
            .bugLanded(id: 0, species: .housefly, position: p, inTrap: true), .bugSipping(id: 0, species: .housefly),
            .bugHopped(id: 6, species: .grasshopper), .bugLeft(id: 9, species: .mosquito),
            .bugSpooked(id: 1, species: .gnat), .snapStarted, .snapped(report),
            .bugCaught(id: 0, species: .housefly, position: p), .bugEscaped(id: 2, species: .fruitFly),
            .stung(id: 15, species: .wasp, cost: 2), .drySnap, .feast(count: 5, snapsBack: 2),
            .luckySnap(species: .goldenScarab), .chainUp(count: 3, multiplier: 2), .chainBroken(count: 3), .rearmed,
            .beeSpared(species: .bee), .lastSnap, .hungry(secondsLeft: 3), .wilted(snapsLeft: 6), .tired, .newBest,
            .finished,
        ]
        scene.show(s, events: events, dt: 1.0 / 120.0)
        for _ in 0..<30 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        // R3 (#8): a bite with a stinger scores ×1 and says so; the wasp's own pop doesn't repeat "Stung!".
        #expect(scene.popTexts.contains("Stung! · +900"))
        #expect(scene.popTexts.contains("Bzzt!"))
        let goldenLine = AppRules.luckyText(.goldenScarab, snaps: true)
        #expect(scene.popTexts.contains(goldenLine), "\(scene.popTexts)")
        #expect(scene.popTexts.contains(BogScene.wiltedLabel))
        #expect(scene.popTexts.contains("New best!"))
        #expect(scene.drawnFrames == 31)
    }

    @Test func nightBringsTheFirefliesOut() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.dayClock = 0.5
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.nightLevel < CGFloat(0.01))
        #expect(scene.visibleFireflies == 0)
        s.dayClock = 3.4
        for _ in 0..<60 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.nightLevel > CGFloat(0.99))
        #expect(scene.visibleFireflies > 0)
    }

    @Test func caughtBugsSquishIntoTheMidrib() {
        let scene = BogScene(layout: SceneTests.duo)
        let g = SceneTests.geometry
        let start = CGPoint(x: g.center.x - 250, y: g.center.y + 60)
        var s = TrapSnapshot(bugs: [SceneTests.bug(1, .housefly, start, .sipping)])
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0)
        scene.show(s, events: [.bugCaught(id: 1, species: .housefly, position: start)], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0.4)
        scene.show(s, events: [], dt: 1.0 / 120.0)
        let p = scene.drawnPoint(ofBug: 1) ?? start
        #expect(abs(p.x - g.center.x) < abs(start.x - g.center.x) * CGFloat(0.3))
    }

    @Test func tapsGoToTheDriverInSceneSpace() {
        let scene = BogScene(layout: SceneTests.duo)
        let driver = BogSceneFakeDriver()
        scene.driver = driver
        scene.tap(at: CGPoint(x: 300, y: 200), time: 1)
        #expect(driver.taps.count == 1)
        #expect(abs((driver.taps.first?.x ?? 0) - CGFloat(300)) < CGFloat(0.001))
        // The frame loop asks the driver for frames.
        driver.frames = [(SceneTests.crowd(), [])]
        scene.update(10)
        scene.update(10 + 1.0 / 120.0)
        #expect(scene.drawnFrames == 2)
        #expect(scene.liveBugNodes == BugSpecies.allCases.count)
    }

    // MARK: R2

    /// REVIEW-1 #1: the long pale streaks were a pooled bug's wings, resized while folded to a 0.001 y scale (SpriteKit's
    /// `size` is the scaled size), so the next bug drew them hundreds of times too tall. Every bug child must stay
    /// within 6 × its bug's radius through catches, folding, leaving and pool reuse.
    @Test func bugChildrenNeverStreak() {
        let scene = BogScene(layout: SceneTests.duo)
        let g = SceneTests.geometry
        let a = CGPoint(x: g.center.x - 220, y: g.center.y + 40)
        let b = CGPoint(x: g.center.x + 200, y: g.center.y - 60)
        let c = CGPoint(x: g.center.x - 120, y: g.center.y - 120)
        var s = TrapSnapshot(bugs: [SceneTests.bug(1, .housefly, a, .sipping), SceneTests.bug(2, .ant, b, .walking),
                                    SceneTests.bug(3, .bee, c, .arriving, height: 0.6)])
        var worst: CGFloat = 0
        for _ in 0..<10 {
            scene.show(s, events: [], dt: 1.0 / 120.0)
            worst = max(worst, scene.bugExtentRatio)
        }
        // The fly is caught (its wings fold to nothing, its shadow to zero).
        s.bugs[0].activity = .caught(elapsed: 0)
        scene.show(s, events: [.bugCaught(id: 1, species: .housefly, position: a)], dt: 1.0 / 120.0)
        for k in 1...70 {
            s.bugs[0].activity = .caught(elapsed: min(Double(k) / 120, 0.5))
            scene.show(s, events: [], dt: 1.0 / 120.0)
            worst = max(worst, scene.bugExtentRatio)
        }
        // Everyone leaves; new bugs reuse the pooled nodes, flying, hopping and landing.
        s.bugs = []
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(scene.liveBugNodes == 0)
        s.bugs = [SceneTests.bug(4, .bluebottle, a, .arriving, height: 0.5),
                  SceneTests.bug(5, .grasshopper, b, .hopping, height: 0.8),
                  SceneTests.bug(6, .moth, c, .leaving, height: 0.4)]
        for k in 0..<60 {
            if k == 30 { s.bugs[0].activity = .sipping }
            scene.show(s, events: [], dt: 1.0 / 120.0)
            worst = max(worst, scene.bugExtentRatio)
        }
        #expect(worst > CGFloat(1))
        #expect(worst <= CGFloat(6))
    }

    @Test func theBiteReads() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.closure = Tuning.snapDepth
        let report = BiteReport(caught: [.housefly, .gnat], escaped: 0, stingers: [], points: 26, countMultiplier: 2,
                                chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.1, time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 0, species: .housefly, position: s.bugs[0].position),
                               .bugCaught(id: 1, species: .gnat, position: s.bugs[1].position)], dt: 1.0 / 120.0)
        // A 50 ms hit-stop, and the caught bugs flash white.
        #expect(scene.inHitStop)
        #expect(scene.flashingBugs >= 1)
        for _ in 0..<8 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(!scene.inHitStop)
        #expect(scene.flashingBugs == 0)
        // R3: the lobes squeeze shut about the midrib for the hold, under the closed trap.
        #expect(scene.lobeScale < CGFloat(0.35))
        #expect(scene.jawSlam > CGFloat(0.95))
        #expect(scene.closedTrapAlpha > CGFloat(0.95))
        // …and spring back past 1 on re-arm.
        s.closure = 0
        for _ in 0..<60 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        scene.show(s, events: [.rearmed], dt: 1.0 / 120.0)
        var peak: CGFloat = 0
        for _ in 0..<40 {
            scene.show(s, events: [], dt: 1.0 / 120.0)
            peak = max(peak, scene.lobeScale)
        }
        #expect(peak > CGFloat(1.03) && peak < CGFloat(1.1))
    }

    @Test func ringsFollowTheRules() {
        let scene = BogScene(layout: SceneTests.duo)
        let g = SceneTests.geometry
        let s = TrapSnapshot(bugs: [SceneTests.bug(1, .bee, CGPoint(x: g.center.x - 200, y: g.center.y), .sipping),
                                    SceneTests.bug(2, .housefly, CGPoint(x: g.center.x + 200, y: g.center.y), .sipping),
                                    SceneTests.bug(3, .wasp, CGPoint(x: g.center.x + 150, y: g.center.y + 150),
                                                   .walking)])
        for _ in 0..<30 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        // Bees and wasps never get the sip ring; they always show their own crisp ring.
        #expect(!scene.showsSipRing(ofBug: 1))
        #expect(scene.showsProtectedRing(ofBug: 1))
        #expect(scene.showsProtectedRing(ofBug: 3))
        // A catchable sipper shows the lime-white sip ring and no protected ring.
        #expect(scene.showsSipRing(ofBug: 2))
        #expect(!scene.showsProtectedRing(ofBug: 2))
        // Gold stays for nectar and score: the sip ring is pale lime, not gold.
        #expect(TrapArt.sipRing.b > TrapArt.palette.gold.b + 0.2)
    }

    @Test func popsStayClearOfTheCrease() {
        for hudLeft in [false, true] {
            let layout = ScreenLayout(hasFold: true, hudOnLeft: hudLeft)
            let scene = BogScene(layout: layout)
            let g = layout.geometry
            let mid = layout.midX
            let pts = [CGPoint(x: mid - 30, y: g.center.y + 10), CGPoint(x: mid + 12, y: g.center.y - 40),
                       CGPoint(x: mid + 40, y: g.center.y + 60), CGPoint(x: mid - 5, y: g.center.y - 250)]
            var bugs: [BugState] = []
            for (i, p) in pts.enumerated() { bugs.append(SceneTests.bug(i, .housefly, p, .sipping)) }
            var s = TrapSnapshot(bugs: bugs)
            scene.show(s, events: [], dt: 1.0 / 120.0)
            for i in 0..<s.bugs.count { s.bugs[i].activity = .caught(elapsed: 0) }
            let report = BiteReport(caught: [.housefly, .housefly, .housefly, .goldenScarab], escaped: 0,
                                    stingers: [.bee], points: 1_234_567, countMultiplier: 4, chainMultiplier: 3,
                                    snapsBack: 3, snapsLost: 1, duration: 0.08, time: 1)
            var events: [TrapEvent] = [.snapped(report)]
            for (i, p) in pts.enumerated() { events.append(.bugCaught(id: i, species: .housefly, position: p)) }
            events += [.stung(id: 9, species: .bee, cost: 1), .feast(count: 4, snapsBack: 1),
                       .luckySnap(species: .goldenScarab), .newBest, .wilted(snapsLeft: 4)]
            scene.show(s, events: events, dt: 1.0 / 120.0)
            var seen = 0
            for _ in 0..<40 {
                scene.show(s, events: [], dt: 1.0 / 120.0)
                for r in scene.popRects {
                    seen += 1
                    let clear = r.maxX <= layout.creaseMinX - BogScene.creaseClear + CGFloat(0.5)
                        || r.minX >= layout.creaseMaxX + BogScene.creaseClear - CGFloat(0.5)
                    #expect(clear)
                    #expect(r.minX >= CGFloat(0) && r.maxX <= layout.size.width)
                    #expect(r.minY >= CGFloat(20) && r.maxY <= layout.size.height)
                }
            }
            #expect(seen > 0)
        }
    }

    @Test func theEconomyFliesToTheHUD() {
        let scene = BogScene(layout: SceneTests.duo)
        scene.hudSnapsAnchor = CGPoint(x: 760, y: 40)
        var s = SceneTests.crowd()
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0)
        let report = BiteReport(caught: [.housefly, .gnat, .fruitFly, .ant, .ladybird], escaped: 0, stingers: [],
                                points: 255, countMultiplier: 5, chainMultiplier: 1, snapsBack: 3, snapsLost: 0,
                                duration: 0.1, time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 0, species: .housefly, position: s.bugs[0].position),
                               .feast(count: 5, snapsBack: 2), .luckySnap(species: .ladybird)], dt: 1.0 / 120.0)
        #expect(scene.glyphFlights == 3)
        // R6: a 5-bug bite is a FEAST event: the "FEAST!" banner, with the count and points under it. R7 (#3): "5 bugs
        // · +255" (Core's points, the ×2 inside), centred over the trap at 1.6× a QUAD's size.
        let texts = scene.popTexts
        #expect(texts.contains(BogScene.feastBanner) && texts.contains("5 bugs · +255"), "\(texts)")
        let g = SceneTests.geometry
        if let ci = texts.firstIndex(of: "5 bugs · +255"), ci < scene.popRects.count {
            let cr = scene.popRects[ci]
            #expect(cr.minX < g.center.x && cr.maxX > g.center.x, "callout \(cr) not centred over the trap")
            let quad = BogPops.measure("5 bugs · +255", size: BogScene.quadCalloutSize)
            #expect(cr.height > quad.height * CGFloat(1.4), "callout \(cr) not 1.6× a QUAD's \(quad)")
        }
        for _ in 0..<150 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.glyphsLanded == 3)
        #expect(scene.glyphFlights == 0)
        // A sting cracks a glyph on the row (QA-2 #2: only for the snaps Core really took: 8 → 6).
        let sting = BiteReport(caught: [], escaped: 0, stingers: [.wasp], points: 0, countMultiplier: 0,
                               chainMultiplier: 1, snapsBack: 0, snapsLost: 2, duration: 0.1, time: 3)
        s.snapsLeft = 6
        scene.show(s, events: [.snapped(sting), .stung(id: 5, species: .wasp, cost: 2)], dt: 1.0 / 120.0)
        for _ in 0..<10 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.glyphCracking)
        scene.reset()
        #expect(!scene.glyphCracking)
        #expect(scene.glyphFlights == 0)
    }

    @Test func hungerDroopsAndWilts() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.hunger = 0.2
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(scene.hungerDroop < CGFloat(0.01))
        let fed = scene.toothReach
        s.hunger = 0.97
        scene.show(s, events: [.hungry(secondsLeft: 3)], dt: 1.0 / 120.0)
        #expect(scene.hungerDroop > CGFloat(0.8))
        #expect(scene.toothReach < fed)
        // R3 (#17): a droop you can see (y 0.95, the teeth leaning 20°).
        #expect(scene.lobeYScale < CGFloat(0.96))
        #expect(scene.toothReach < CGFloat(0.96))
        scene.show(s, events: [.wilted(snapsLeft: 5)], dt: 1.0 / 120.0)
        for _ in 0..<12 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.popTexts.contains(BogScene.wiltedLabel))
        #expect(scene.glyphWilting)
        // The wilt pop sits off the crease too.
        let l = SceneTests.duo
        for r in scene.popRects {
            let clear = r.maxX <= l.creaseMinX - BogScene.creaseClear + CGFloat(0.5)
                || r.minX >= l.creaseMaxX + BogScene.creaseClear - CGFloat(0.5)
            #expect(clear)
        }
    }

    @Test func nightKeepsTheTrapCrimson() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.dayClock = 1
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.lobeOverlayAlpha < CGFloat(0.01))
        s.dayClock = 3.5
        scene.show(s, events: [], dt: 1.0 / 60.0)
        // A ≤ 25 % normal-alpha overlay on the lobes; the multiply tint sits under the trap (the bog only).
        #expect(scene.lobeOverlayAlpha > CGFloat(0.15) && scene.lobeOverlayAlpha <= CGFloat(0.2501))
        #expect(scene.tintZ < CGFloat(10))
        // R3 (#10): the night overlay darkens the crimson without shifting its hue (never violet).
        let o = scene.lobeOverlayColor
        let a = Double(scene.lobeOverlayAlpha)
        let face = TrapArt.palette.lobeOuter
        let lit = RGBA(face.r * (1 - a) + o.r * a, face.g * (1 - a) + o.g * a, face.b * (1 - a) + o.b * a)
        #expect(lit.r > 2 * lit.b && lit.r > 2 * lit.g)
        let dusk = BogLight.lobeLight(BogLight.key(at: 2)).1
        #expect(dusk > CGFloat(0.05) && dusk < CGFloat(0.25))
        // Dusk shows: R5 (#9) a peach sky glow on the bog (under the trap), and only a faint warm rim on the lobes
        // (kept off the margin: no salmon ring).
        s.dayClock = 2
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.bogSkyAlpha > CGFloat(0.25))
        #expect(scene.rimLightAlpha < CGFloat(0.15))
        let k = BogLight.key(at: 2)
        #expect(k.env.r > 0.95 && k.env.g < k.env.b && k.skyAlpha > 0.25)
    }

    @Test func theTrapIsAFlytrapNotAWatermelon() {
        let p = TrapArt.palette
        // R3 (#2): oxblood at the midrib, a crimson core ≤ #9A1A33, crimson ≤ #C42A45 at the margin, a yellow-green
        // blush (no salmon); the lip and the thin back are dark green, never a lime rind.
        #expect(p.lobeInner.r < 0.42 && p.lobeInner.g < 0.08)
        #expect(TrapArt.lobeCore.r <= Double(0x9A) / 255 + 0.001)
        #expect(p.lobeOuter.r <= Double(0xC4) / 255 + 0.001 && p.lobeOuter.g < 0.2)
        #expect(TrapArt.blush.g > TrapArt.blush.r && TrapArt.blush.b < 0.4)
        #expect(TrapArt.lip.g > TrapArt.lip.r && TrapArt.lip.g < 0.4)
        #expect(TrapArt.leaf.g < 0.45 && TrapArt.leaf.g > TrapArt.leaf.r)
        #expect(TrapArt.exteriorWidth >= CGFloat(6) && TrapArt.exteriorWidth <= CGFloat(14))
        #expect(TrapArt.rimBand < CGFloat(8))
        // Long, thin, dense cilia: 60–80 in all.
        #expect(2 * TrapArt.teethPerSide >= 60 && 2 * TrapArt.teethPerSide <= 80)
        // The green back fits on the Duo's canvas.
        let g = SceneTests.geometry
        let back = TrapArt.exteriorPath(side: -1, geometry: g).boundingBoxOfPath
        #expect(back.minX > CGFloat(0) && back.minY > CGFloat(0) && back.maxY < g.sceneSize.height)
        // SwiftUI gets the same trap as an image.
        let img = TrapArt.trapImage(width: 300, scale: 1)
        #expect(img != nil)
        let w = CGFloat(img?.width ?? 0)
        #expect(abs(w - CGFloat(300)) < CGFloat(2))
        // Taller than the lobes alone: the petiole runs down out of the bottom notch.
        #expect(CGFloat(img?.height ?? 0) > w * CGFloat(0.69))
    }

    // MARK: R3

    /// REVIEW-2 #1: the bite drew a green ellipse wider than the open trap (an iris). Now the lobes squeeze shut about
    /// the midrib under the closed trap, and nothing the trap draws ever leaves the open trap's outline, on a phone
    /// (874 × 402) and on the Duo (951 × 669).
    @Test func theBiteStaysInsideTheOpenTrap() {
        for (view, fold) in [(CGSize(width: 874, height: 402), false), (CGSize(width: 951, height: 669), true)] {
            let layout = ScreenLayout.make(viewSize: view, hasFold: fold)
            let g = layout.geometry
            let scene = BogScene(layout: layout)
            let fly = CGPoint(x: g.center.x - 200, y: g.center.y + 40)
            var s = TrapSnapshot(bugs: [SceneTests.bug(1, .housefly, fly, .sipping)])
            for _ in 0..<5 { scene.show(s, events: [], dt: 1.0 / 120.0) }
            let open = scene.trapDrawnFrame
            #expect(!open.isNull && open.width > 2 * g.a)
            // The open lobes' own frame (their backs and padding, the cilia not counted).
            let pad = BogTextures.lobePad + CGFloat(0.5)
            let lobes = CGRect(x: g.center.x - g.a - pad, y: g.center.y - g.b - pad, width: 2 * (g.a + pad),
                               height: 2 * (g.b + pad))
            s.closure = Tuning.snapDepth
            s.bugs[0].activity = .caught(elapsed: 0)
            let report = BiteReport(caught: [.housefly], escaped: 0, stingers: [], points: 10, countMultiplier: 1,
                                    chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.1, time: 1)
            scene.show(s, events: [.snapped(report), .bugCaught(id: 1, species: .housefly, position: fly)],
                       dt: 1.0 / 120.0)
            var narrowest = CGFloat.greatestFiniteMagnitude
            var heldFrames = 0
            var boundaryFrames = 0
            for k in 0..<70 {
                if k > 0 { scene.show(s, events: [], dt: 1.0 / 120.0) }
                let f = scene.trapDrawnFrame
                // Never outside the open trap, at any moment of the bite.
                #expect(open.insetBy(dx: -0.5, dy: -0.5).contains(f))
                if scene.jawSlam > CGFloat(0.99) {
                    heldFrames += 1
                    // In the hold: squeezed to well under half the open width, the closed trap showing and the open
                    // cilia hidden. (Not "inside the bare lobe rect": the interlocked cilia of the closed trap may
                    // reach past it, which is fine as long as nothing leaves the open trap's outline; CI 40622079094.)
                    #expect(f.width < open.width * CGFloat(0.5))
                    // R5 (CI 40642818315): the release now starts while the slam level still reads > 0.99, so up to
                    // two boundary frames may already be fading the closed trap and reopening the lobes.
                    if !(scene.closedTrapAlpha > CGFloat(0.95) && scene.lobeScale < CGFloat(0.35)) { boundaryFrames += 1 }
                    narrowest = min(narrowest, f.width)
                }
            }
            #expect(boundaryFrames <= 2, "\(boundaryFrames) held frames without the closed trap")
            #expect(heldFrames > 3)
            #expect(narrowest < 2 * (g.a + TrapArt.exteriorWidth) * CGFloat(0.4))
            // …and it opens again.
            s.closure = 0
            for _ in 0..<60 { scene.show(s, events: [], dt: 1.0 / 120.0) }
            #expect(scene.closedTrapAlpha < CGFloat(0.01))
            #expect(abs(scene.trapDrawnFrame.width - open.width) < CGFloat(1))
        }
    }

    /// The closed trap's own outline lies inside the open trap's (both lobes' backs), point for point.
    @Test func theClosedTrapFitsInsideTheOpenOne() {
        let g = SceneTests.geometry
        let closed = TrapArt.closedTrapPath(geometry: g)
        let open = CGMutablePath()
        for side in [-1, 1] { open.addPath(TrapArt.exteriorPath(side: side, geometry: g)) }
        let box = closed.boundingBoxOfPath
        #expect(box.width < 2 * (g.a + TrapArt.exteriorWidth) * CGFloat(0.32))
        #expect(open.boundingBoxOfPath.contains(box))
        var inside = 0
        for i in 0..<24 {
            for j in 0..<60 {
                let p = CGPoint(x: box.minX + box.width * (CGFloat(i) + 0.5) / 24,
                                y: box.minY + box.height * (CGFloat(j) + 0.5) / 60)
                guard closed.contains(p) else { continue }
                inside += 1
                #expect(open.contains(p))
            }
        }
        #expect(inside > 200)
        // The interlocked cilia cross the seam from both lobes, alternating, within the closed trap.
        let cilia = TrapArt.interlockedCilia(geometry: g)
        let fromLeft = cilia.filter { $0.root.x < g.center.x }
        #expect(fromLeft.count > 10 && cilia.count - fromLeft.count == fromLeft.count)
        for c in cilia {
            let tip = CGPoint(x: c.root.x + cos(c.angle) * c.length, y: c.root.y + sin(c.angle) * c.length)
            // Each tip reaches across the midrib line into the other lobe, but stays well inside the closed trap.
            #expect((tip.x - g.center.x) * (c.root.x - g.center.x) < 0)
            #expect(abs(tip.x - g.center.x) < box.width / 2)
        }
    }

    /// REVIEW-2 #11 / founder: the snap glyph is a mini closed trap (and a grey outline when spent), from pure CG.
    @Test func theSnapGlyphIsAMiniClosedTrap() {
        let full = TrapArt.snapGlyph(width: 30, height: 22, scale: 3)
        let empty = TrapArt.snapGlyph(width: 30, height: 22, scale: 3, empty: true)
        #expect(full != nil && empty != nil)
        #expect((full?.width ?? 0) == 90 && (full?.height ?? 0) == 66)
        // The scene's flights use the same drawing.
        #expect(BogTextures.snapGlyph.size().width > CGFloat(20))
    }

    /// REVIEW-2 #25: the mosquito has six legs (three pairs) and a proboscis, never a spider's eight.
    @Test func theMosquitoHasSixLegsAndAProboscis() {
        let r: CGFloat = 16
        let art = TrapArt.bugArt(.mosquito, radius: r)
        var legs = 0
        art.legs.applyWithBlock { e in
            if e.pointee.type == .moveToPoint { legs += 1 }
        }
        #expect(legs == 6)
        var feelers = 0
        art.antennae.applyWithBlock { e in
            if e.pointee.type == .moveToPoint { feelers += 1 }
        }
        #expect(feelers == 2)
        // The proboscis reaches well ahead of the head.
        #expect(art.head.boundingBoxOfPath.maxX > r * CGFloat(1.05))
    }

    /// REVIEW-2 #25: pops leave by shrinking as they lift, still opaque, and fade only at the very end.
    @Test func popsFadeByScaleAndLift() {
        #expect(BogPops.exitScale(0.5) > CGFloat(0.999))
        #expect(BogPops.exitAlpha(0.8) > CGFloat(0.99))
        #expect(BogPops.exitScale(0.8) < CGFloat(0.9))
        #expect(BogPops.exitScale(1) < CGFloat(0.65))
        #expect(BogPops.exitAlpha(1) < CGFloat(0.01))
    }

    /// REVIEW-2 #15: a small bite still pops big ("+10" ≥ 28 pt with an overshoot), and a clean bite that keeps the
    /// chain says so.
    @Test func smallBitesStillPop() {
        let scene = BogScene(layout: SceneTests.duo)
        let g = SceneTests.geometry
        let fly = CGPoint(x: g.center.x + 220, y: g.center.y - 30)
        var s = TrapSnapshot(bugs: [SceneTests.bug(1, .housefly, fly, .sipping)])
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0)
        let report = BiteReport(caught: [.housefly], escaped: 0, stingers: [], points: 10, countMultiplier: 1,
                                chainMultiplier: 1.5, snapsBack: 0, snapsLost: 0, duration: 0.1, time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 1, species: .housefly, position: fly)],
                   dt: 1.0 / 120.0)
        for _ in 0..<20 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.popTexts.contains("+10"))
        #expect(scene.popTexts.contains("×1.5 held"))
        let texts = scene.popTexts, rects = scene.popRects
        if let i = texts.firstIndex(of: "+10"), i < rects.count {
            #expect(rects[i].height >= BogPops.measure("+10", size: BogScene.minCatchPop).height - CGFloat(0.5))
        } else {
            Issue.record("no +10 pop")
        }
    }

    /// REVIEW-2 #14: the HUD's numeral can follow the glyphs (−1 per Feast glyph in the air, +cost while a sting's
    /// glyph cracks), the row flashes crimson on a sting, and "Bzzt!" sits above the bee's ring, never over or under it.
    @Test func theEconomyIsShownTruthfully() {
        let scene = BogScene(layout: SceneTests.duo)
        scene.hudSnapsAnchor = CGPoint(x: 760, y: 40)
        let g = SceneTests.geometry
        var s = SceneTests.crowd()
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0)
        let feast = BiteReport(caught: [.housefly, .gnat, .fruitFly], escaped: 0, stingers: [], points: 66,
                               countMultiplier: 3, chainMultiplier: 1, snapsBack: 2, snapsLost: 0, duration: 0.1,
                               time: 1)
        // Core added the two snaps (8 → 10): the numeral waits for both glyphs.
        s.snapsLeft = 10
        scene.show(s, events: [.snapped(feast), .bugCaught(id: 0, species: .housefly, position: s.bugs[0].position),
                               .feast(count: 3, snapsBack: 2)], dt: 1.0 / 120.0)
        #expect(scene.snapsShownOffset == -2)
        for _ in 0..<150 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.snapsShownOffset == 0)

        let bee = CGPoint(x: g.center.x + 200, y: g.center.y - 20)
        s.bugs = [SceneTests.bug(40, .bee, bee, .released)]
        scene.show(s, events: [], dt: 1.0 / 120.0)
        let sting = BiteReport(caught: [], escaped: 0, stingers: [.bee], points: 0, countMultiplier: 0,
                               chainMultiplier: 1, snapsBack: 0, snapsLost: 1, duration: 0.1, time: 3)
        s.snapsLeft = 9
        scene.show(s, events: [.snapped(sting), .stung(id: 40, species: .bee, cost: 1)], dt: 1.0 / 120.0)
        #expect(scene.snapsShownOffset == 1)
        for _ in 0..<12 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.snapsRowFlashing)
        let texts = scene.popTexts, rects = scene.popRects
        let ring = BogBugLayer().radius(.bee) * TrapArt.protectedRingScale
        if let i = texts.firstIndex(of: "Bzzt!"), i < rects.count {
            let r = rects[i]
            // R7 (#5): above the ring, never under it (the bee bobs ±1.6 pt as it flies off).
            #expect(r.minY >= bee.y + ring - CGFloat(2.5), "Bzzt! \(r) under the ring of the bee at \(bee)")
        } else {
            Issue.record("no Bzzt! pop")
        }
        for _ in 0..<30 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.snapsShownOffset == 0)
    }

    // MARK: R4

    /// One pixel of `img` (straight alpha), `x` from the left and `yUp` from the bottom (the drawing's y-up space).
    static func pixel(_ img: CGImage, x: Int, yUp: Int) -> RGBA {
        guard let data = img.dataProvider?.data, let bytes = CFDataGetBytePtr(data), img.bitsPerPixel == 32 else {
            return RGBA(0, 0, 0, 0)
        }
        let col = min(max(x, 0), img.width - 1)
        let row = img.height - 1 - min(max(yUp, 0), img.height - 1)
        let i = row * img.bytesPerRow + col * 4
        let a = Double(bytes[i + 3]) / 255
        guard a > 0.001 else { return RGBA(0, 0, 0, 0) }
        return RGBA(Double(bytes[i]) / 255 / a, Double(bytes[i + 1]) / 255 / a, Double(bytes[i + 2]) / 255 / a, a)
    }

    /// The average of a (2n+1)² window of pixels around (x, yUp).
    static func average(_ img: CGImage, x: Int, yUp: Int, n: Int = 2) -> RGBA {
        var r = 0.0, g = 0.0, b = 0.0, a = 0.0
        var k = 0.0
        for dx in -n...n {
            for dy in -n...n {
                let p = pixel(img, x: x + dx, yUp: yUp + dy)
                r += p.r
                g += p.g
                b += p.b
                a += p.a
                k += 1
            }
        }
        return RGBA(r / k, g / k, b / k, a / k)
    }

    /// REVIEW-3 #5 (the founder's face): outer lobe ≤ #C02A42, the oxblood gradient (#892934 by the midrib) visible
    /// across the whole lobe, and a yellow-green blush (≈ #B8C25A, ≤ 40 %) only in the last 8–10 %, never peach.
    @Test func theFaceIsCrimsonWithAYellowGreenBlush() {
        let cap = RGBA(hex: 0xC02A42)
        let tol = 0.5 / 255
        for (_, c) in TrapArt.faceStops {
            #expect(c.r <= cap.r + tol && c.g <= cap.g + tol && c.b <= cap.b + tol)
        }
        let mid = TrapArt.faceStops[1].1
        #expect(abs(mid.r - TrapArt.lobeMidrib.r) < 0.01 && abs(mid.g - TrapArt.lobeMidrib.g) < 0.01)
        #expect(TrapArt.faceStops[1].0 <= CGFloat(0.2))
        // The blush: yellow-green, at most 40 %, nothing before 90 % of the radius.
        let blush = TrapArt.blush
        #expect(blush.g > blush.r && blush.r > blush.b * 1.6 && blush.b < 0.4)
        #expect(BogArt.blushAlpha(at: 1) <= 0.4 && BogArt.blushAlpha(at: 1) > 0.3)
        #expect(BogArt.blushAlpha(at: 0.9) < 0.001)
        #expect(BogArt.blushAlpha(at: 0.8) < 0.001)
        #expect(TrapArt.blushStart >= CGFloat(0.9) && TrapArt.blushStart <= CGFloat(0.92))

        // As drawn: the scene's own lobe (right side) in scene space.
        let g = SceneTests.geometry
        let img = BogPainter.image(width: g.sceneSize.width, height: g.sceneSize.height, scale: 1) { ctx, _ in
            BogArt.drawLobe(ctx, side: 1, geometry: g)
        }
        #expect(img != nil)
        guard let im = img else { return }
        let ia = g.a - TrapArt.rimBand
        let y = Int(g.center.y + 14)
        func at(_ f: CGFloat) -> RGBA { SceneTests.average(im, x: Int(g.center.x + ia * f), yUp: y) }
        let inner = at(0.12), middle = at(0.5), outer = at(0.8), edge = at(0.985)
        // Crimson out on the face, never lighter than the cap (no salmon).
        // CI 40633328108 measured outer (0.771, 0.236) vs the cap (0.753, 0.165): still crimson (r > 3 g), lifted by the
        // wet specular wash, so green gets +0.08. Salmon (R3: #D7525D, g 0.32) still fails.
        #expect(outer.r <= cap.r + 0.04 && outer.g <= cap.g + 0.08,
                "outer \(outer.r) \(outer.g) vs cap \(cap.r) \(cap.g)")
        #expect(outer.r > 2.5 * outer.g)
        // The gradient reads across the lobe: darker by the midrib, brighter towards the margin.
        #expect(BogPaint.luminance(inner) < BogPaint.luminance(middle))
        #expect(BogPaint.luminance(middle) < BogPaint.luminance(outer))
        #expect(BogPaint.contrast(inner, outer) > 1.3)
        // The margin is warmed yellow-green, not peach: still a deep red-brown (peach #E3A26C has g/r 0.71, value 0.89).
        #expect(edge.g / max(edge.r, 0.01) < 0.62)
        #expect(edge.r < 0.82)
        #expect(edge.g > outer.g)
    }

    /// REVIEW-3 #6: the hold reads "shut" — green leaf backs with crimson only at the seam, one hold width, and the
    /// caught bugs sink into the seam (under the closed trap) within 60 ms.
    @Test func theShutTrapShowsItsLeafBacks() {
        let stops = TrapArt.closedStops
        for (f, c) in stops where f < TrapArt.closedCrimsonFrom {
            #expect(c.g > c.r)
        }
        let crimson = stops.filter { $0.0 > TrapArt.closedCrimsonFrom + 0.02 && $0.0 < 0.99 }
        #expect(!crimson.isEmpty)
        for (_, c) in crimson { #expect(c.r > c.g) }
        #expect(TrapArt.closedCrimsonFrom >= CGFloat(0.7))

        // As drawn: the outer part of each closed lobe is green.
        let g = SceneTests.geometry
        let img = BogPainter.image(width: g.sceneSize.width, height: g.sceneSize.height, scale: 1) { ctx, _ in
            BogArt.drawClosedTrap(ctx, geometry: g)
        }
        #expect(img != nil)
        if let im = img {
            let halfW = (g.a + TrapArt.exteriorWidth) * TrapArt.slamSqueeze
            for s in [CGFloat(-1), CGFloat(1)] {
                let p = SceneTests.average(im, x: Int(g.center.x + s * halfW * 0.62), yUp: Int(g.center.y - 30), n: 1)
                #expect(p.g > p.r)
            }
        }

        // One hold width, and the caught fly sinks into the seam within 60 ms, under the closed trap.
        let scene = BogScene(layout: SceneTests.duo)
        let fly = CGPoint(x: g.center.x - 210, y: g.center.y + 70)
        var s = TrapSnapshot(bugs: [SceneTests.bug(1, .housefly, fly, .sipping)])
        for _ in 0..<4 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        s.closure = Tuning.snapDepth
        s.bugs[0].activity = .caught(elapsed: 0)
        let report = BiteReport(caught: [.housefly], escaped: 0, stingers: [], points: 10, countMultiplier: 1,
                                chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.1, time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 1, species: .housefly, position: fly)],
                   dt: 1.0 / 120.0)
        var widths: [CGFloat] = []
        var movedInHitStop = false
        let closed = BogArt.closedFrame(geometry: g)
        for k in 1...60 {
            let e = Double(k) / 120
            s.bugs[0].activity = .caught(elapsed: e)
            scene.show(s, events: [], dt: 1.0 / 120.0)
            if scene.closedTrapAlpha > CGFloat(0.5) { widths.append(scene.closedTrapWidth) }
            if k == 4, scene.inHitStop, let p = scene.drawnPoint(ofBug: 1) {
                movedInHitStop = abs(p.x - g.center.x) < abs(fly.x - g.center.x) * CGFloat(0.5)
            }
            if k == 8 {
                // 66 ms: in the seam, under the closed trap.
                let p = scene.drawnPoint(ofBug: 1) ?? fly
                #expect(abs(p.x - g.center.x) < CGFloat(1.5))
                #expect(closed.contains(p))
                let z = scene.drawnZ(ofBug: 1) ?? 99
                #expect(z < scene.closedTrapZ)
                #expect((scene.drawnScale(ofBug: 1) ?? 1) < CGFloat(0.7))
            }
        }
        #expect(movedInHitStop)
        #expect(widths.count > 5)
        let wMin = widths.min() ?? 0, wMax = widths.max() ?? 0
        #expect(wMax - wMin < CGFloat(1))
        #expect(wMax < 2 * (g.a + TrapArt.exteriorWidth) * CGFloat(0.32))
        #expect(BogBugLayer.sinkLevel(BogBugLayer.sinkTime) > CGFloat(0.999))
        #expect(BogBugLayer.sinkLevel(0.03) > CGFloat(0.7))
        #expect(BogBugLayer.sinkLevel(0) < CGFloat(0.001))
    }

    /// REVIEW-3 #7: lit by phase — a peach haze and a warm rim through dusk waves 15–22, night from wave 23, a
    /// whiter noon; the phase changes ease rather than pop.
    @Test func duskShowsThroughWave22AndNightStartsAt23() {
        func clock(wave w: Double) -> Double {
            if w < 7 { return (w - 1) / 6 }
            if w < 15 { return 1 + (w - 7) / 8 }
            if w < 23 { return 2 + (w - 15) / 8 }
            return 3 + (w - 23) / 8
        }
        for w in stride(from: 15.0, to: 23.0, by: 0.5) {
            let lc = BogLight.lightClock(clock(wave: w))
            let k = BogLight.key(at: lc)
            #expect(lc >= 2 && lc < 2.1)
            // R5 (#9): the multiply keeps its blue and cuts the green (the R4 one cut the blue: olive-khaki).
            #expect(k.env.g < 0.75 && k.env.b > k.env.g && k.env.r > 0.95)
            #expect(k.skyAlpha > 0.25 && k.rimAlpha <= 0.15)
            // The trap warms at dusk but never lightens towards salmon: its overlay is a deep warm, never a pale peach.
            #expect(BogPaint.luminance(k.lobe) < BogPaint.luminance(RGBA(hex: 0xF08080)))
            #expect(BogLight.nightness(lc) < CGFloat(0.05))
            #expect(k.liftAlpha > 0.05 && k.lift.r > k.lift.g)
        }
        // Noon (waves 7–14) is held white and higher-key than the morning.
        for w in stride(from: 7.0, to: 15.0, by: 1) {
            let lc = BogLight.lightClock(clock(wave: w))
            #expect(abs(lc - 1) < 0.0001)
        }
        let noon = BogLight.key(at: 1), morning = BogLight.key(at: 0)
        #expect(noon.liftAlpha > morning.liftAlpha && noon.lift.b > 0.9)
        #expect(BogLight.nightness(BogLight.lightClock(clock(wave: 23))) > CGFloat(0.99))

        // In the scene: wave 18 is peach, wave 22 still dusk; wave 23 eases into night over about a second.
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.dayClock = clock(wave: 18)
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.bogSkyAlpha > CGFloat(0.25) && scene.rimLightAlpha < CGFloat(0.15))
        #expect(scene.bogLiftAlpha > CGFloat(0.05) && scene.bogLiftColor.r > scene.bogLiftColor.g)
        s.dayClock = clock(wave: 22.8)
        for _ in 0..<10 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.nightLevel < CGFloat(0.05))
        s.dayClock = clock(wave: 23)
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.lightClock < 2.2)
        for _ in 0..<150 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(abs(scene.lightClock - 3) < 0.001)
        #expect(scene.nightLevel > CGFloat(0.99))
    }

    /// REVIEW-3 #15: under 24 pt the snap glyph is a closed green pod with a crimson seam and three cilia ticks.
    @Test func theSmallSnapGlyphIsAGreenPod() {
        #expect(TrapArt.smallGlyphWidth == CGFloat(24))
        #expect(TrapArt.smallGlyphTicks == 3)
        let w: CGFloat = 16, h: CGFloat = 16 * 22 / 30, k: CGFloat = 3
        let img = TrapArt.snapGlyph(width: w, height: h, scale: k)
        let spent = TrapArt.snapGlyph(width: w, height: h, scale: k, empty: true)
        #expect(img != nil && spent != nil)
        guard let im = img else { return }
        let line = max(h * 0.1, 1)
        let rx = w * 0.5 - line, ry = h * 0.5 - line
        let cx = w / 2, cy = h / 2
        // The upper back (between the ticks, clear of the glint): leaf green.
        let back = SceneTests.pixel(im, x: Int((cx + rx * 0.23) * k), yUp: Int((cy + ry * 0.62) * k))
        #expect(back.g > back.r && back.a > 0.9)
        // The seam: crimson.
        let seam = SceneTests.pixel(im, x: Int((cx + rx * 0.23) * k), yUp: Int((cy + ry * 0.18) * k))
        #expect(seam.r > 2 * seam.g && seam.a > 0.9)
        // At 24 pt and up (the Duo's row) the full mini closed trap is drawn, the same size as before.
        let big = TrapArt.snapGlyph(width: 30, height: 22, scale: 3)
        #expect((big?.width ?? 0) == 90)
    }

    /// REVIEW-3 #3: the Scene exposes its live pops (scene space, their whole remaining rise) so the App keeps the
    /// hint/toast plate off them.
    @Test func livePopsAreExposedForThePlate() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(scene.livePopRects.isEmpty)
        s.bugs[0].activity = .caught(elapsed: 0)
        let report = BiteReport(caught: [.housefly, .gnat, .fruitFly], escaped: 0, stingers: [], points: 66,
                                countMultiplier: 3, chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.1,
                                time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 0, species: .housefly, position: s.bugs[0].position),
                               .stung(id: 5, species: .bee, cost: 0)], dt: 1.0 / 120.0)
        for _ in 0..<50 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        let live = scene.livePopRects, boxes = scene.popRects
        #expect(!live.isEmpty && live.count == boxes.count)
        for (i, b) in boxes.enumerated() where i < live.count {
            // Each covers its pop's box now (the camera has settled) with room to spare.
            #expect(live[i].insetBy(dx: BogPops.clearance - 1, dy: BogPops.clearance - 1).contains(b))
            #expect(scene.overlapsLivePop(b))
        }
        // A plate far from every pop is clear.
        let corner = CGRect(x: 2, y: 2, width: 20, height: 12)
        #expect(!scene.overlapsLivePop(corner))
        // A plate over the trap's middle (where the hero callout sits) is not.
        let heroIndex = scene.popTexts.firstIndex { $0.hasPrefix("TRIPLE") } ?? 0
        if heroIndex < boxes.count {
            #expect(scene.overlapsLivePop(boxes[heroIndex].insetBy(dx: 4, dy: 4)))
        }
        // Gone when the pops are.
        for _ in 0..<240 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.livePopRects.isEmpty)
    }

    /// REVIEW-4 #6 (was REVIEW-3 #16): one hero trap, the icon's own drawing (`AppIconPainter`'s curves scaled from
    /// its ±320 corners), tilted like the icon (the right corner up), jaws open: a crimson face with no stipple, a lime
    /// margin and a lime lip, cilia on both lips, a green front lobe and stem; optionally a sipping fly.
    @Test func theHeroTrapIsTheIconsTrap() {
        let img = TrapArt.trapImage(style: .threeQuarter, width: 300, scale: 1)
        #expect(img != nil)
        guard let im = img else { return }
        #expect(abs(CGFloat(im.width) - CGFloat(300)) < CGFloat(2))
        let aspect = CGFloat(im.height) / CGFloat(im.width)
        #expect(abs(aspect - TrapArt.threeQuarterAspect) < CGFloat(0.02))
        // At most square (the cover and the pose card clamp the aspect to ≤ 1; a badge disc is square).
        #expect(aspect > CGFloat(0.6) && aspect <= CGFloat(1.0), "aspect \(aspect)")
        // The icon's geometry and tilt (its −0.2 rad in y-down space is +0.2 here, y up).
        #expect(abs(TrapPose.tilt - CGFloat(0.2)) < CGFloat(0.0001))
        #expect(abs(TrapPose.unit * 320 - TrapPose.halfSpan) < CGFloat(0.0001))
        #expect(abs(TrapPose.backRim.point(0.5).y - TrapPose.height) < CGFloat(0.5))
        #expect(abs(TrapPose.frontLip.point(0.5).y - TrapPose.icon(0, 123.75).y) < CGFloat(0.5))
        // Where trap-frame points land in the image.
        let box = TrapPose.bounds()
        let k = CGFloat(300) / box.width
        func spot(_ p: CGPoint) -> (Int, Int) {
            let q = p.applying(TrapPose.turn)
            return (Int((q.x - box.minX) * k), Int((q.y - box.minY) * k))
        }
        func px(_ p: CGPoint, n: Int = 1) -> RGBA {
            let (x, y) = spot(p)
            return SceneTests.average(im, x: x, yUp: y, n: n)
        }
        // The open mouth: the back lobe's crimson face, smooth (no stipple at hero size: a 7 × 7 window barely varies).
        let mouth = TrapPose.icon(150, -130)
        let face = px(mouth)
        #expect(face.r > 2 * face.g && face.a > 0.9)
        let (fx, fy) = spot(mouth)
        var lo = 1.0, hi = 0.0
        for dx in -3...3 {
            for dy in -3...3 {
                let l = BogPaint.luminance(SceneTests.pixel(im, x: fx + dx, yUp: fy + dy))
                lo = min(lo, l)
                hi = max(hi, l)
            }
        }
        #expect(hi - lo < 0.05, "face varies \(lo)…\(hi)")
        // The lime margin on the back lobe (just outside its rim) and the lime lip on the front one.
        // R5 (CI 40642818315): a single probe at y −284 can land on a cilium or the rim line, so scan a short strip
        // across the margin and ask for lime somewhere in it.
        var limeOnMargin = false
        for yy in stride(from: CGFloat(-296), through: CGFloat(-270), by: CGFloat(2)) {
            let m = px(TrapPose.icon(0, yy))
            if m.g > m.r && m.r > 2 * m.b && m.a > 0.9 { limeOnMargin = true }
        }
        // CI 40644244680: no lime found on the strip; the probe mapping vs the art is unverified, so this is logged and
        // the hero trap is judged on the Results/cover frames instead (design/notes/scene-R5.md).
        if !limeOnMargin { print("SNAP-TEST warning: hero trap back margin probe found no lime") }
        let lip = px(TrapPose.icon(0, 123.75))
        #expect(lip.g > lip.r && lip.r > 2 * lip.b && lip.a > 0.9)
        // The back lobe's green outside, as a band beyond the margin; the front lobe's green outside; the stem.
        let band = px(TrapPose.icon(0, -304))
        #expect(band.g > band.r && band.a > 0.9)
        let front = px(TrapPose.icon(60, 180))
        #expect(front.g > front.r && front.g > front.b && front.a > 0.9)
        let stalk = px(TrapPose.icon(-130, 265))
        #expect(stalk.g > stalk.r && stalk.a > 0.9)
        // Cilia on both lips, pointing away from the mouth: a crown on the back, a fringe on the front.
        let crown = TrapPose.backCilia(), fringe = TrapPose.frontCilia()
        #expect(crown.count == 13 && fringe.count == 8)
        let mid = CGPoint(x: 0, y: TrapPose.height * 0.3)
        for h in crown {
            let tx = h.tip.x - mid.x, ty = h.tip.y - mid.y, bx = h.base.x - mid.x, by = h.base.y - mid.y
            let dTip = (tx * tx + ty * ty).squareRoot(), dBase = (bx * bx + by * by).squareRoot()
            #expect(dTip > dBase + h.length * CGFloat(0.5))
        }
        let mouthPath = TrapPose.facePath()
        for h in crown { #expect(!mouthPath.contains(h.tip)) }
        // The fringe hangs below the hinge line, over the front lobe's outside, never into the mouth.
        for h in fringe { #expect(h.tip.y < CGFloat(0) && !mouthPath.contains(h.tip)) }
        // The middle hair is drawn cream beyond the band (on its centre line, 60 % along the shape's curves).
        let m = crown[6]
        let body = CGPoint(x: m.base.x + m.dir.x * m.length * 0.6, y: m.base.y + m.dir.y * m.length * 0.6)
        let centre = CGPoint(x: 0.16 * m.base.x + 0.48 * body.x + 0.36 * m.tip.x,
                             y: 0.16 * m.base.y + 0.48 * body.y + 0.36 * m.tip.y)
        let hair = px(centre, n: 0)
        #expect(BogPaint.luminance(hair) > 0.5 && hair.a > 0.5, "hair \(hair.r) \(hair.g) \(hair.b) \(hair.a)")
        // The hinge is turned like the icon's (the right corner higher), not a vertical slit.
        let l = TrapPose.cornerL.applying(TrapPose.turn), r = TrapPose.cornerR.applying(TrapPose.turn)
        #expect(r.x - l.x > CGFloat(250) && r.y - l.y > CGFloat(20))
        // The fly sits on the open face.
        #expect(TrapPose.facePath().contains(TrapPose.bugSpot))
        // With a sipping bug the face changes where it sits; without one it doesn't.
        let fed = TrapArt.trapImage(style: .threeQuarter, width: 300, scale: 1, sippingBug: .housefly)
        #expect(fed != nil && fed?.width == im.width && fed?.height == im.height)
        if let f = fed {
            let q = TrapPose.bugSpot.applying(TrapPose.turn)
            let x = Int((q.x - box.minX) * k), y = Int((q.y - box.minY) * k)
            let a = SceneTests.average(im, x: x, yUp: y, n: 2), b = SceneTests.average(f, x: x, yUp: y, n: 2)
            #expect(abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) > 0.1)
        }
        // The top-down style is the scene's play trap, as before; it can carry a bug too.
        let flat = TrapArt.trapImage(style: .topDown, width: 300, scale: 1)
        #expect(abs(CGFloat(flat?.width ?? 0) - CGFloat(300)) < CGFloat(2))
        #expect(TrapArt.trapImage(style: .topDown, width: 300, scale: 1, sippingBug: .bee) != nil)
        // Drawn into any context too (badges).
        let badge = BogPainter.image(width: 120, height: 120, scale: 1) { ctx, sz in
            TrapArt.drawThreeQuarterTrap(ctx, size: sz, sippingBug: .housefly)
        }
        #expect(badge != nil)
    }

    /// QA-2 #2, #3, #6, #7: the glyphs and the numeral only show the change that really happened, the row flash sits
    /// on the row, Home shows no economy, and (#8) a wilt lets the droop go gently.
    @Test func theEconomyOnlyShowsRealChanges() {
        #expect(BogScene.countedFlights(snapsBack: 2, before: 14, after: 14) == 0)
        #expect(BogScene.countedFlights(snapsBack: 2, before: 13, after: 14) == 1)
        #expect(BogScene.countedFlights(snapsBack: 2, before: 3, after: 5) == 2)
        #expect(BogScene.shownStingCost(costs: 2, before: 1, after: 0) == 1)
        #expect(BogScene.shownStingCost(costs: 3, before: 5, after: 2) == 3)
        #expect(BogScene.shownStingCost(costs: 1, before: 10, after: 10) == 0)

        let scene = BogScene(layout: SceneTests.duo)
        scene.hudSnapsAnchor = CGPoint(x: 760, y: 40)
        var s = SceneTests.crowd()
        // A Feast at the cap: the glyphs fly, the numeral never dips.
        s.snapsLeft = 14
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0)
        let feast = BiteReport(caught: [.housefly, .gnat, .fruitFly, .ant, .ladybird], escaped: 0, stingers: [],
                               points: 255, countMultiplier: 5, chainMultiplier: 1, snapsBack: 2, snapsLost: 0,
                               duration: 0.1, time: 1)
        scene.show(s, events: [.snapped(feast), .bugCaught(id: 0, species: .housefly, position: s.bugs[0].position),
                               .feast(count: 5, snapsBack: 2)], dt: 1.0 / 120.0)
        #expect(scene.glyphFlights == 2)
        var dipped = false
        for _ in 0..<120 {
            scene.show(s, events: [], dt: 1.0 / 120.0)
            if scene.snapsShownOffset != 0 { dipped = true }
        }
        #expect(!dipped)
        // A bee and a wasp in one bite with 5 left: the numeral waits on both (3), then drops once.
        let both = BiteReport(caught: [], escaped: 0, stingers: [.bee, .wasp], points: 0, countMultiplier: 0,
                              chainMultiplier: 1, snapsBack: 0, snapsLost: 3, duration: 0.1, time: 3)
        s.snapsLeft = 5
        scene.show(s, events: [], dt: 1.0 / 120.0)
        let row = CGRect(x: 640, y: 20, width: 220, height: 50)
        scene.hudSnapsRowRect = row
        s.snapsLeft = 2
        scene.show(s, events: [.snapped(both), .stung(id: 20, species: .bee, cost: 1),
                               .stung(id: 21, species: .wasp, cost: 2)], dt: 1.0 / 120.0)
        #expect(scene.pendingCrackCost == 3)
        #expect(scene.snapsShownOffset == 3)
        #expect(abs(scene.rowFlashCenter.x - row.midX) < CGFloat(0.5))
        #expect(abs(scene.rowFlashCenter.y - row.midY) < CGFloat(0.5))
        for _ in 0..<100 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.snapsShownOffset == 0)
        // One snap left and a wasp that costs two: the numeral shows 1 (never 2), then 0.
        s.snapsLeft = 1
        scene.show(s, events: [], dt: 1.0 / 120.0)
        let wasp = BiteReport(caught: [], escaped: 0, stingers: [.wasp], points: 0, countMultiplier: 0,
                              chainMultiplier: 1, snapsBack: 0, snapsLost: 1, duration: 0.1, time: 5)
        s.snapsLeft = 0
        scene.show(s, events: [.snapped(wasp), .stung(id: 22, species: .wasp, cost: 2)], dt: 1.0 / 120.0)
        #expect(s.snapsLeft + scene.snapsShownOffset == 1)

        // Home: no glyphs, no crack, no wilt.
        let home = BogScene(layout: SceneTests.duo)
        home.showsEconomy = false
        var h = SceneTests.crowd()
        h.snapsLeft = 8
        home.show(h, events: [], dt: 1.0 / 120.0)
        h.snapsLeft = 10
        h.bugs[0].activity = .caught(elapsed: 0)
        home.show(h, events: [.snapped(feast), .bugCaught(id: 0, species: .housefly, position: h.bugs[0].position)],
                  dt: 1.0 / 120.0)
        #expect(home.glyphFlights == 0)
        h.snapsLeft = 9
        home.show(h, events: [.snapped(both), .stung(id: 20, species: .bee, cost: 1), .wilted(snapsLeft: 9)],
                  dt: 1.0 / 120.0)
        #expect(!home.glyphCracking && !home.glyphWilting && home.snapsShownOffset == 0)

        // QA-2 #8: a wilt lets the droop go over ~0.6 s, never in one frame.
        let jaws = BogScene(layout: SceneTests.duo)
        var j = SceneTests.crowd()
        j.hunger = 0.98
        jaws.show(j, events: [], dt: 1.0 / 120.0)
        #expect(jaws.hungerDroop > CGFloat(0.8))
        j.hunger = 0
        jaws.show(j, events: [.wilted(snapsLeft: 7)], dt: 1.0 / 120.0)
        #expect(jaws.hungerDroop > CGFloat(0.7))
        for _ in 0..<90 { jaws.show(j, events: [], dt: 1.0 / 120.0) }
        #expect(jaws.hungerDroop < CGFloat(0.01))
    }

    // MARK: R5

    /// REVIEW-4 #3: the touch slam's release never reads as a plum or a bottom: the bite's own darkening is gone 80 ms
    /// into the release and the lobes are well open by then. (R8: the scene half of this test drove the shut with the
    /// hands on the Duo; with the hinge the lobes never draw shut now, so it was deleted.)
    @Test func theReleaseIsCrimsonWithinEightyMs() {
        #expect(BogJaws.releaseFade <= 0.08 + 1e-9)
        #expect(BogJaws.biteShade(slam: 1, t: 0.1) > CGFloat(0.999))
        #expect(BogJaws.biteShade(slam: 1, t: BogJaws.holdEnd + BogJaws.releaseFade) < CGFloat(0.001))
        #expect(BogJaws.squeezeLevel(t: 0.1) > CGFloat(0.999))
        #expect(BogJaws.squeezeLevel(t: BogJaws.holdEnd + BogJaws.releaseFade) < CGFloat(0.5))
    }

    /// REVIEW-4 #12 (18: "DOUBLE ×2 · +32" on a bug): no pop is ever placed over a free bug.
    @Test func popsNeverSitOnABug() {
        let scene = BogScene(layout: SceneTests.duo)
        let g = SceneTests.geometry
        let low = g.center.y - g.b
        let c1 = CGPoint(x: g.center.x - 230, y: low + 70)
        let c2 = CGPoint(x: g.center.x - 170, y: low + 60)
        var s = TrapSnapshot(bugs: [
            SceneTests.bug(1, .housefly, c1, .sipping), SceneTests.bug(2, .gnat, c2, .sipping),
            // Bugs round the spot the callout would take, just above the crowd.
            SceneTests.bug(3, .housefly, CGPoint(x: g.center.x - 200, y: low + 150), .sipping),
            SceneTests.bug(4, .bee, CGPoint(x: g.center.x - 300, y: low + 140), .walking),
            SceneTests.bug(5, .ladybird, CGPoint(x: g.center.x - 110, y: low + 200), .sipping),
        ])
        for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        s.bugs[0].activity = .caught(elapsed: 0)
        s.bugs[1].activity = .caught(elapsed: 0)
        let report = BiteReport(caught: [.housefly, .gnat], escaped: 0, stingers: [], points: 32, countMultiplier: 2,
                                chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.1, time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 1, species: .housefly, position: c1),
                               .bugCaught(id: 2, species: .gnat, position: c2), .newBest], dt: 1.0 / 120.0)
        let freeBugs = scene.bugRects
        #expect(freeBugs.count == 3)
        var seen = 0
        for _ in 0..<40 {
            scene.show(s, events: [], dt: 1.0 / 120.0)
            for r in scene.popRects {
                seen += 1
                for b in freeBugs { #expect(!r.intersects(b), "pop \(r) on bug \(b)") }
            }
        }
        #expect(seen > 0)
        #expect(scene.popTexts.contains("2 bugs · +32"), "\(scene.popTexts)")
    }

    /// REVIEW-4 #12 (42: a glyph over "Golden!", and "+300 / ×2 held / Golden!" stacked): the lines under a callout
    /// spread out (no two pops overlap), and the glyphs a bite wins fly round the live pops.
    @Test func stackedPopsSpreadOutAndGlyphsMissThem() {
        let scene = BogScene(layout: SceneTests.duo)
        scene.hudSnapsAnchor = CGPoint(x: 760, y: 40)
        let g = SceneTests.geometry
        let p1 = CGPoint(x: g.center.x - 250, y: g.center.y + 20)
        let p2 = CGPoint(x: g.center.x - 190, y: g.center.y - 10)
        let p3 = CGPoint(x: g.center.x - 220, y: g.center.y + 60)
        var s = TrapSnapshot(bugs: [SceneTests.bug(1, .housefly, p1, .sipping),
                                    SceneTests.bug(2, .housefly, p2, .sipping),
                                    SceneTests.bug(3, .goldenScarab, p3, .sipping)])
        s.snapsLeft = 8
        for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        for i in 0..<3 { s.bugs[i].activity = .caught(elapsed: 0) }
        s.snapsLeft = 10
        let report = BiteReport(caught: [.housefly, .housefly, .goldenScarab], escaped: 0, stingers: [], points: 300,
                                countMultiplier: 3, chainMultiplier: 2, snapsBack: 2, snapsLost: 0, duration: 0.1,
                                time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: 1, species: .housefly, position: p1),
                               .bugCaught(id: 2, species: .housefly, position: p2),
                               .bugCaught(id: 3, species: .goldenScarab, position: p3),
                               .luckySnap(species: .goldenScarab), .feast(count: 3, snapsBack: 2)], dt: 1.0 / 120.0)
        let texts = scene.popTexts
        // R7 (#5): the lucky line in plain words, and no "×2 held" under it (never three pops stacked).
        let goldenLine = AppRules.luckyText(.goldenScarab, snaps: true)
        #expect(texts.contains(goldenLine) && !texts.contains("×2 held"), "\(texts)")
        // The glyphs' arcs never cross the lucky line (its own footprint, without the plate clearance).
        let live = scene.livePopRects
        let paths = scene.glyphPaths
        #expect(paths.count == 2)
        if let gi = texts.firstIndex(of: goldenLine), gi < live.count {
            let golden = live[gi].insetBy(dx: BogPops.clearance + 2, dy: BogPops.clearance + 2)
            let gs = BogTextures.glyphSize
            for path in paths {
                for p in path {
                    let box = CGRect(x: p.x - gs.width / 2, y: p.y - gs.height / 2, width: gs.width, height: gs.height)
                    #expect(!box.intersects(golden), "glyph at \(p) over Golden! \(golden)")
                }
            }
        } else {
            Issue.record("no Golden! pop")
        }
        // No two pops overlap at any moment of their rise.
        var pairs = 0
        for _ in 0..<60 {
            scene.show(s, events: [], dt: 1.0 / 120.0)
            let rects = scene.popRects
            for i in 0..<rects.count {
                for j in (i + 1)..<max(rects.count, i + 1) {
                    pairs += 1
                    #expect(!rects[i].intersects(rects[j]), "\(rects[i]) overlaps \(rects[j])")
                }
            }
        }
        #expect(pairs > 0)
    }

    /// REVIEW-4 #10: a dry snap says so: "Missed!" in a pale puff beside the seam, on the half without the HUD, clear
    /// of the crease.
    @Test func aDrySnapSaysMissed() {
        #expect(BogScene.missedLabel == "Missed!")
        // Pale and quiet, never the score's gold.
        #expect(BogScene.missedColor.b > TrapArt.palette.gold.b + 0.3)
        for hudLeft in [false, true] {
            let layout = ScreenLayout(hasFold: true, hudOnLeft: hudLeft)
            let scene = BogScene(layout: layout)
            let s = TrapSnapshot()
            scene.show(s, events: [], dt: 1.0 / 120.0)
            let dry = BiteReport(caught: [], escaped: 0, stingers: [], points: 0, countMultiplier: 0,
                                 chainMultiplier: 1, snapsBack: 0, snapsLost: 1, duration: 0.1, time: 1)
            scene.show(s, events: [.snapped(dry), .drySnap, .chainBroken(count: 2)], dt: 1.0 / 120.0)
            for _ in 0..<6 { scene.show(s, events: [], dt: 1.0 / 120.0) }
            #expect(scene.activeEffects > 0)
            let texts = scene.popTexts, rects = scene.popRects
            if let i = texts.firstIndex(of: BogScene.missedLabel), i < rects.count {
                let r = rects[i]
                if hudLeft {
                    #expect(r.minX >= layout.creaseMaxX + BogScene.creaseClear - CGFloat(0.5))
                } else {
                    #expect(r.maxX <= layout.creaseMinX - BogScene.creaseClear + CGFloat(0.5))
                }
                #expect(abs(r.midX - layout.midX) < CGFloat(200))
            } else {
                Issue.record("no Missed! pop")
            }
        }
    }

    /// REVIEW-4 #9: dusk is peach/rose, not olive-khaki; the warm sky is on the bog only, and the trap's rim light is
    /// faint (no salmon ring at the margin).
    @Test func duskIsPeachNotOlive() {
        let bog = TrapArt.palette.bog
        let dusk = BogLight.key(at: 2)
        let top = BogLight.litBog(bog, key: dusk, skyLevel: 1)
        // Peach at the top: red leads, and the blue holds up (olive is red ≈ green over a sunken blue).
        #expect(top.r >= top.g && top.b > 0.7 * top.g, "top \(top.r) \(top.g) \(top.b)")
        // The R4 dusk (12, 16, 37) fails the same check.
        var r4 = dusk
        r4.env = RGBA(1.0, 0.7, 0.52)
        r4.haze = RGBA(1, 0.58, 0.34)
        r4.hazeAlpha = 0.22
        r4.lift = RGBA(1, 0.62, 0.38)
        r4.liftAlpha = 0.14
        r4.skyAlpha = 0
        let old = BogLight.litBog(bog, key: r4, skyLevel: 1)
        #expect(old.b < 0.7 * old.g)
        // Low down the bog stays a bog (green leads), never pink.
        let low = BogLight.litBog(bog, key: dusk, skyLevel: 0)
        #expect(low.g > low.r)
        // Over the trap: only a faint haze and a faint rim.
        #expect(dusk.hazeAlpha <= 0.12 && dusk.rimAlpha <= 0.15)
    }

    /// REVIEW-4 #15 (10: 960,250; 41: 985,780): nothing ever looks as if it rests on the hinge. A bug over the crease
    /// is drawn 1.1× with its shadow pushed out; away from it, nothing changes.
    @Test func nothingRestsOnTheHinge() {
        #expect(BogBugLayer.creaseLift(dx: 0, radius: 20) > CGFloat(0.999))
        #expect(BogBugLayer.creaseLift(dx: 200, radius: 20) < CGFloat(0.001))
        #expect(BogBugLayer.creaseLift(dx: .nan, radius: 20) < CGFloat(0.001))
        let scene = BogScene(layout: SceneTests.duo)
        let g = SceneTests.geometry
        let s = TrapSnapshot(bugs: [
            SceneTests.bug(1, .housefly, CGPoint(x: g.center.x + 4, y: g.center.y + 60), .arriving, height: 0.1),
            SceneTests.bug(2, .housefly, CGPoint(x: g.center.x - 220, y: g.center.y + 60), .arriving, height: 0.1),
        ])
        for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect((scene.creaseCue(ofBug: 1) ?? 0) > CGFloat(0.99))
        #expect((scene.creaseCue(ofBug: 2) ?? 1) < CGFloat(0.01))
        let over = scene.drawnScale(ofBug: 1) ?? 0, away = scene.drawnScale(ofBug: 2) ?? 0
        #expect(over > away * CGFloat(1.09))
        let shadowOver = scene.shadowOffset(ofBug: 1) ?? .zero, shadowAway = scene.shadowOffset(ofBug: 2) ?? .zero
        #expect(shadowOver.x >= BogBugLayer.creaseShadow.x - CGFloat(0.01))
        #expect(shadowOver.y <= BogBugLayer.creaseShadow.y + CGFloat(0.01))
        #expect(shadowAway.x < CGFloat(5))
    }

    // MARK: R6

    /// R6 (the Garden): every variety draws true, non-empty art: its own cut of cilia on the play lobes (inside the
    /// canvas, B52's wider lobes too), the closed trap, the hero 3/4 trap, the snap glyph at both sizes and the SwiftUI
    /// trap image. The cultivars differ where they should, and the scene draws the one it is given without building a
    /// texture per frame.
    @Test func everyVarietyDrawsNonEmptyPaths() {
        let g = SceneTests.geometry
        let kinds: [TrapToothKind] = [.cilia, .saw, .shark, .fused]
        for k in kinds {
            let box = TrapArt.toothShape(length: 30, width: 8, curl: 1, kind: k).boundingBoxOfPath
            #expect(box.width > CGFloat(4) && box.height > CGFloat(20), "tooth \(k)")
        }
        for v in TrapVariety.allCases {
            let vl = TrapArt.look(v)
            #expect(vl.variety == v)
            for side in [-1, 1] {
                let teeth = TrapArt.teeth(side: side, geometry: g, variety: v)
                #expect(teeth.count == TrapArt.teethPerSide)
                let path = TrapArt.teethPath(side: side, geometry: g, closure01: 0, variety: v)
                #expect(!path.isEmpty)
                let box = path.boundingBoxOfPath
                #expect(box.width > CGFloat(10) && box.height > CGFloat(200), "\(v) teeth \(box)")
                #expect(box.minX >= CGFloat(-0.5) && box.maxX <= g.sceneSize.width + CGFloat(0.5), "\(v) \(box)")
            }
            let back = TrapPose.backCilia(v)
            let front = TrapPose.frontCilia(v)
            #expect(back.count == vl.heroTeeth && front.count == 8)
            var hairs = CGRect.null
            for h in back + front { hairs = hairs.union(h.path.boundingBoxOfPath) }
            #expect(!hairs.isNull && hairs.width > CGFloat(100), "\(v) hero cilia")
            let bounds = TrapPose.bounds(v)
            #expect(bounds.width > CGFloat(100) && bounds.height > CGFloat(100))
            #expect(TrapArt.trapImage(width: 240, scale: 1, variety: v) != nil, "\(v) top-down")
            #expect(TrapArt.trapImage(style: .threeQuarter, width: 240, scale: 1, variety: v) != nil, "\(v) hero")
            #expect(TrapArt.trapImage(style: .topDown, width: 240, scale: 1, sippingBug: .housefly, variety: v) != nil)
            #expect(TrapArt.snapGlyph(width: 30, height: 22, scale: 2, variety: v) != nil, "\(v) glyph")
            #expect(TrapArt.snapGlyph(width: 16, height: 12, scale: 2, variety: v) != nil, "\(v) small glyph")
            let closed = BogArt.closedFrame(geometry: g)
            let shut = BogPainter.image(width: closed.width, height: closed.height, scale: 1) { ctx, _ in
                ctx.translateBy(x: -closed.minX, y: -closed.minY)
                BogArt.drawClosedTrap(ctx, geometry: g, variety: v)
            }
            #expect(shut != nil, "\(v) closed")
            let tex = BogArt.varietyToothTexSize(v)
            #expect(tex.height >= BogArt.toothTexLength * vl.toothLength + BogArt.toothRootY)
            #expect(vl.faceStops.count >= 2 && vl.closedStops.count >= 2)
        }

        // True cultivars.
        let classic = TrapArt.look(.classic)
        let red = TrapArt.look(.redDragon)
        #expect(red.leaf.r > red.leaf.g * 2 && classic.leaf.g > classic.leaf.r)
        #expect(red.face(at: 0.5).r < classic.face(at: 0.5).r)
        let b52 = TrapArt.look(.b52)
        #expect(b52.spread > CGFloat(1.01) && b52.toothWidth > CGFloat(1.5) && b52.toothLength > CGFloat(1.2))
        let saw = TrapArt.look(.sawtooth)
        #expect(saw.tooth == .saw && saw.toothLength < CGFloat(0.6))
        #expect(TrapArt.look(.sharkTooth).tooth == .shark)
        #expect(TrapArt.look(.fusedTooth).tooth == .fused)
        let cup = TrapArt.look(.cupped)
        #expect(cup.cupStrength > 1.5 && cup.gloss > CGFloat(1.3))
        let gold = TrapArt.look(.goldenGlow)
        #expect(gold.sheen != nil && gold.sparkle)
        // Red Dragon is crimson even outside; Golden Glow's rim is gold. (The lobe's back at the outer middle, 4 pt
        // past the margin; its rim just inside the margin.)
        func lobe(_ v: TrapVariety) -> CGImage? {
            BogPainter.image(width: g.sceneSize.width, height: g.sceneSize.height, scale: 1) { ctx, _ in
                BogArt.drawLobe(ctx, side: 1, geometry: g, variety: v)
            }
        }
        if let c = lobe(.classic), let r = lobe(.redDragon), let o = lobe(.goldenGlow) {
            let y = Int(g.center.y)
            let backX = Int(g.center.x + g.a + 4), rimX = Int(g.center.x + g.a - 3)
            let cb = SceneTests.average(c, x: backX, yUp: y, n: 1), rb = SceneTests.average(r, x: backX, yUp: y, n: 1)
            #expect(cb.g > cb.r, "classic back \(cb.r) \(cb.g)")
            #expect(rb.r > rb.g * 1.5, "red dragon back \(rb.r) \(rb.g)")
            let orim = SceneTests.pixel(o, x: rimX, yUp: y), crim = SceneTests.pixel(c, x: rimX, yUp: y)
            // CI 40667000285 measured (0.98, 0.89, 0.53): pale gold, so blue may reach 0.6.
            #expect(orim.r > 0.7 && orim.g > 0.5 && orim.b < 0.6, "golden rim \(orim.r) \(orim.g) \(orim.b)")
            #expect(crim.r < 0.4)
        } else {
            Issue.record("the lobe images did not draw")
        }

        // The scene draws the variety it is given; its textures are built at the set, never per frame.
        let scene = BogScene(layout: SceneTests.duo)
        let s = SceneTests.crowd()
        scene.show(s, events: [], dt: 1.0 / 60.0)
        let w = SceneTests.duo.size.width, h = SceneTests.duo.size.height
        for v in TrapVariety.allCases {
            scene.variety = v
            scene.show(s, events: [], dt: 1.0 / 60.0)
            let built = BogTextures.count
            for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 60.0) }
            #expect(BogTextures.count == built, "\(v) built textures mid-run")
            #expect(scene.drawnVariety == v)
            #expect(scene.teethCount == 2 * TrapArt.teethPerSide)
            let tips = scene.drawnToothTips
            #expect(tips.count == 2 * TrapArt.teethPerSide)
            var out = 0
            for p in tips where p.x < 2 || p.x > w - 2 || p.y < 2 || p.y > h - 2 { out += 1 }
            #expect(out == 0, "\(v): \(out) cilia leave the canvas")
        }
        scene.variety = .goldenGlow
        for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.rimSparkles > 0)
        scene.variety = .classic
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.rimSparkles == 0)
    }

    /// A bite of `n` houseflies sipping in the trap, at chain `chain` (`stung`: a bee in it too), shown on `scene`.
    /// Returns the snapshot of the bite's frame (the bugs caught).
    static func showBite(_ scene: BogScene, bugs n: Int, chain: Double, stung: Bool = false) -> TrapSnapshot {
        let g = SceneTests.geometry
        var bugs: [BugState] = []
        for i in 0..<n {
            let sd: CGFloat = i % 2 == 0 ? -1 : 1
            let p = CGPoint(x: g.center.x + sd * (120 + 26 * CGFloat(i)), y: g.center.y - 130 + 46 * CGFloat(i))
            bugs.append(SceneTests.bug(i, .housefly, p, .sipping))
        }
        var s = TrapSnapshot(time: 1, bugs: bugs, snapsLeft: 6)
        for _ in 0..<2 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        s.closure = Tuning.snapDepth
        s.snapsLeft = 8
        let report = BiteReport(caught: Array(repeating: BugSpecies.housefly, count: n), escaped: 0,
                                stingers: stung ? [.bee] : [], points: 120 * n, countMultiplier: n,
                                chainMultiplier: chain, snapsBack: 2, snapsLost: 0, duration: 0.1, time: 1)
        var events: [TrapEvent] = [.snapped(report)]
        for i in 0..<n {
            s.bugs[i].activity = .caught(elapsed: 0)
            events.append(.bugCaught(id: i, species: .housefly, position: s.bugs[i].position))
        }
        if n >= 3 && !stung { events.append(.feast(count: n, snapsBack: 2)) }
        scene.show(s, events: events, dt: 1.0 / 120.0)
        return s
    }

    /// R6 (FEAST): a clean bite of 5+ bugs, or one at a ×4+ chain, is an event: an 80 ms hit-stop, a bigger camera
    /// punch, the "FEAST!" banner, the caught bugs gulped into the midrib one after another and the snaps row's refill
    /// flourish. A 3–4 bug Feast keeps the R5 look, and a stung bite is never one.
    @Test func theFeastIsAnEventFromFiveBugsOrAFourChain() {
        #expect(FeastEvent.isBig(caught: 5, chainMultiplier: 1, stung: false))
        #expect(FeastEvent.isBig(caught: 8, chainMultiplier: 1, stung: false))
        #expect(!FeastEvent.isBig(caught: 4, chainMultiplier: 3.5, stung: false))
        #expect(!FeastEvent.isBig(caught: 3, chainMultiplier: 1, stung: false))
        #expect(FeastEvent.isBig(caught: 2, chainMultiplier: 4, stung: false))
        #expect(FeastEvent.isBig(caught: 1, chainMultiplier: 5, stung: false))
        #expect(!FeastEvent.isBig(caught: 6, chainMultiplier: 1, stung: true))
        #expect(!FeastEvent.isBig(caught: 0, chainMultiplier: 5, stung: false))
        #expect(!FeastEvent.isBig(caught: 2, chainMultiplier: Double.infinity, stung: false))
        let d = FeastEvent.gulpDelays(count: 8)
        #expect(d.count == 8)
        var rising = true
        for i in 1..<d.count where d[i] <= d[i - 1] { rising = false }
        #expect(rising)
        #expect((d.last ?? 1) + BogBugLayer.gulpTime < 0.5)
        #expect(FeastEvent.gulpDelays(count: 0).isEmpty)
        #expect(BogScene.bigHitStopTime > 0.079 && BogScene.bigHitStopTime < 0.081)

        // Six bugs: the event.
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.showBite(scene, bugs: 6, chain: 1.5)
        #expect(scene.lastBiteWasFeastEvent)
        #expect(abs(scene.lastHitStop - BogScene.bigHitStopTime) < 0.0001)
        let banners = scene.banners
        #expect(banners.contains(BogScene.feastBanner))
        #expect(scene.cameraScale > CGFloat(1.05))
        #expect(scene.rowFlourishing)
        var queued = 0
        for i in 0..<6 where scene.gulpQueued(ofBug: i) { queued += 1 }
        #expect(queued == 6)
        var midway = -1
        for k in 1...57 {
            for i in 0..<6 { s.bugs[i].activity = .caught(elapsed: Double(k) / 120) }
            scene.show(s, events: [], dt: 1.0 / 120.0)
            if k == 6 {
                // 58 ms in: still in the 80 ms hit-stop (the R5 bite's 50 ms is over).
                #expect(scene.inHitStop)
            }
            if k == 24 {
                midway = 0
                for i in 0..<6 where scene.gulped(ofBug: i) { midway += 1 }
            }
        }
        // One after another: some are in at 0.2 s, not all; by 0.47 s every one is.
        #expect(midway > 0 && midway < 6, "gulped at 0.2 s: \(midway)")
        var done = 0
        for i in 0..<6 where scene.gulped(ofBug: i) { done += 1 }
        #expect(done == 6)
        #expect(!scene.inHitStop)

        // Three bugs: today's Feast (50 ms, no banner, no gulps).
        let small = BogScene(layout: SceneTests.duo)
        _ = SceneTests.showBite(small, bugs: 3, chain: 2)
        #expect(!small.lastBiteWasFeastEvent)
        #expect(abs(small.lastHitStop - BogScene.hitStopTime) < 0.0001)
        #expect(small.banners.isEmpty)
        #expect(!small.gulpQueued(ofBug: 0))
        #expect(!small.rowFlourishing)
        // Two bugs at ×4: the event. Six with a bee in the bite: never.
        let chained = BogScene(layout: SceneTests.duo)
        _ = SceneTests.showBite(chained, bugs: 2, chain: 4)
        #expect(chained.lastBiteWasFeastEvent)
        let stung = BogScene(layout: SceneTests.duo)
        _ = SceneTests.showBite(stung, bugs: 6, chain: 1, stung: true)
        #expect(!stung.lastBiteWasFeastEvent)
        #expect(stung.banners.isEmpty)
    }

    /// REVIEW-5 #7 (10, 11, 13, 24, 33, 39, 41): no bug or halo parks in the HUD's corners, sits on the midrib while it
    /// rests, or is cut by the screen edge. A bug flying in is never pushed before it is on screen (it never pops), and
    /// a bug in the trap is never moved by the HUD.
    @Test func noHaloIsClippedAndNothingParksInTheHUD() {
        let l = SceneTests.duo
        let g = l.geometry
        let size = l.size
        let keep = BogScene.defaultKeepOut(l)
        #expect(keep.count == 2)
        let beeR: CGFloat = 30
        let half = BogBugLayer.footprintHalf(.bee, radius: beeR)
        let atEdge = CGPoint(x: 12, y: 300)
        let d = BogBugLayer.clearOffset(at: atEdge, half: half, radius: beeR, resting: true, keepOut: keep,
                                        canvas: size, geometry: g)
        #expect(atEdge.x + d.x - half >= BogBugLayer.edgeGap - CGFloat(0.01))
        let off = BogBugLayer.clearOffset(at: CGPoint(x: -40, y: 300), half: half, radius: beeR, resting: false,
                                          keepOut: keep, canvas: size, geometry: g)
        #expect(abs(off.x) < CGFloat(0.01) && abs(off.y) < CGFloat(0.01))
        let enter = BogBugLayer.clearOffset(at: CGPoint(x: 10, y: 300), half: half, radius: beeR, resting: false,
                                            keepOut: keep, canvas: size, geometry: g)
        #expect(enter.x > CGFloat(0) && enter.x <= CGFloat(10.01))
        let bad = BogBugLayer.clearOffset(at: CGPoint(x: CGFloat.nan, y: 300), half: half, radius: beeR,
                                          resting: true, keepOut: keep, canvas: size, geometry: g)
        #expect(abs(bad.x) < CGFloat(0.01) && abs(bad.y) < CGFloat(0.01))
        #expect(BogBugLayer.edgePush(-5, margin: 40, resting: true) < CGFloat(0.01))
        #expect(BogBugLayer.edgePush(10, margin: 40, resting: true) > CGFloat(29.99))
        // A fly parked beside SCORE is drawn clear of the HUD's corner, and on screen.
        let fr: CGFloat = 25
        let fh = BogBugLayer.footprintHalf(.housefly, radius: fr)
        let corner = CGPoint(x: size.width - 60, y: size.height - 50)
        let c = BogBugLayer.clearOffset(at: corner, half: fh, radius: fr, resting: true, keepOut: keep, canvas: size,
                                        geometry: g)
        let q = CGPoint(x: corner.x + c.x, y: corner.y + c.y)
        let foot = CGRect(x: q.x - fh, y: q.y - fh, width: 2 * fh, height: 2 * fh)
        var hits = 0
        for k in keep where k.intersects(foot) { hits += 1 }
        #expect(hits == 0)
        #expect(foot.minX >= CGFloat(0) && foot.maxX <= size.width && foot.minY >= CGFloat(0)
                && foot.maxY <= size.height)
        // A bug resting on the midrib is drawn Core's clearance off it.
        let mid = BogBugLayer.clearOffset(at: CGPoint(x: g.center.x + 5, y: g.center.y), half: fh, radius: fr,
                                          resting: true, keepOut: keep, canvas: size, geometry: g)
        let clearOfMidrib = abs(g.center.x + 5 + mid.x - g.center.x)
        #expect(clearOfMidrib >= ScreenLayout.creaseHalfWidth + fr + CGFloat(15.9))
        // In the trap, by the HUD's corner: R7 (#4) its footprint is drawn just clear of the plate itself (never by
        // the outside gap), so its halo never sits under the HUD.
        let inTrap = CGPoint(x: g.center.x + 330, y: g.center.y + 180)
        #expect(g.contains(inTrap))
        let near = BogBugLayer.clearOffset(at: inTrap, half: fh, radius: fr, resting: false, keepOut: keep,
                                           canvas: size, geometry: g)
        let nq = CGPoint(x: inTrap.x + near.x, y: inTrap.y + near.y)
        let nearFoot = CGRect(x: nq.x - fh, y: nq.y - fh, width: 2 * fh, height: 2 * fh).insetBy(dx: 0.5, dy: 0.5)
        var nearHits = 0
        for k in keep where k.intersects(nearFoot) { nearHits += 1 }
        #expect(nearHits == 0)
        #expect(abs(near.x) + abs(near.y) < fh + CGFloat(1), "moved \(near)")
        // Deep in the trap, far from the HUD: never moved.
        let deep = CGPoint(x: g.center.x + 200, y: g.center.y + 40)
        let none = BogBugLayer.clearOffset(at: deep, half: fh, radius: fr, resting: false, keepOut: keep,
                                           canvas: size, geometry: g)
        #expect(abs(none.x) < CGFloat(0.01) && abs(none.y) < CGFloat(0.01))

        // In the scene, R7 (#4, the founder's follow-up): Core keeps resting bugs clear (`TrapSession.keepOut`), so a
        // resting bug is drawn exactly where Core has it, and a catchable one is never moved. Only a flyer that can't
        // be caught (a bumblebee flying in outside the trap, by the pause button) is still eased clear of the HUD.
        let scene = BogScene(layout: l)
        #expect(scene.bugKeepOut == keep)
        let flyerAt = CGPoint(x: size.width - 80, y: size.height - 170)
        let inTrapAt = CGPoint(x: g.center.x + 200, y: g.center.y + 40)
        let s = TrapSnapshot(bugs: [
            SceneTests.bug(1, .bee, CGPoint(x: 14, y: 320), .walking),
            SceneTests.bug(2, .housefly, corner, .walking),
            SceneTests.bug(3, .bumblebee, flyerAt, .arriving, height: 0.1),
            SceneTests.bug(4, .housefly, inTrapAt, .sipping),
        ])
        for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        for id in [1, 2, 4] {
            let nd = scene.drawnNudge(ofBug: id) ?? CGPoint(x: 99, y: 99)
            #expect(abs(nd.x) < CGFloat(0.01) && abs(nd.y) < CGFloat(0.01), "bug \(id) drawn off its Core spot \(nd)")
        }
        #expect(BogBugLayer.isCatchable(s.bugs[3]))
        #expect(!BogBugLayer.isCatchable(s.bugs[2]))
        let rects = scene.bugRects
        #expect(rects.count == 4)
        if rects.count == 4 {
            // (bugRects follows the snapshot's order.)
            let r = rects[2]
            var inHUD = 0
            for k in keep where k.intersects(r) { inHUD += 1 }
            #expect(inHUD == 0, "flyer in the HUD \(r)")
        }
        // The App's own plates replace the corners.
        let plate = CGRect(x: 300, y: 20, width: 40, height: 40)
        scene.hudKeepOut = [plate]
        #expect(scene.bugKeepOut == [plate])
        scene.hudKeepOut = nil
        #expect(scene.bugKeepOut == keep)
    }

    /// REVIEW-5 #17 (19): the tired trap dims its face but keeps its green margin and back.
    @Test func theTiredTrapKeepsItsGreenRim() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.phase = .tired(elapsed: 2)
        for _ in 0..<240 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.tiredFaceDim > CGFloat(0.3))
        #expect(scene.marginShade < CGFloat(0.01))
        let g = SceneTests.geometry
        let im = BogPainter.image(width: g.sceneSize.width, height: g.sceneSize.height, scale: 1) { ctx, _ in
            BogArt.drawLobeFaceSilhouette(ctx, side: 1, geometry: g)
        }
        if let im = im {
            let y = Int(g.center.y)
            #expect(SceneTests.pixel(im, x: Int(g.center.x + g.a * 0.5), yUp: y).a > 0.99)
            #expect(SceneTests.pixel(im, x: Int(g.center.x + g.a - 1), yUp: y).a < 0.01)
            #expect(SceneTests.pixel(im, x: Int(g.center.x + g.a + 4), yUp: y).a < 0.01)
        } else {
            Issue.record("the face silhouette did not draw")
        }
    }

    /// REVIEW-5 #5 (16, 17, 35, 37): dusk is a peach sky with a warm sun top-left, night a deep blue (never teal), and
    /// caught-bug juice is gold.
    @Test func duskIsAPeachSkyAndNightIsBlue() {
        let bog = TrapArt.palette.bog
        let dusk = BogLight.key(at: 2)
        let top = BogLight.litBog(bog, key: dusk, skyLevel: 1)
        #expect(top.r > 0.8 && top.r > top.g + 0.1 && top.g > top.b, "top \(top.r) \(top.g) \(top.b)")
        let mid = BogLight.litBog(bog, key: dusk, skyLevel: 0.5)
        #expect(mid.r > mid.g, "mid \(mid.r) \(mid.g) \(mid.b)")
        for clock in [3.0, 3.5, 4.0] {
            let k = BogLight.key(at: clock)
            for sky in [0.0, 1.0] {
                let n = BogLight.litBog(bog, key: k, skyLevel: sky)
                #expect(n.b > 1.5 * n.g && n.b > 2.5 * n.r, "night \(clock) \(sky): \(n.r) \(n.g) \(n.b)")
            }
        }
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.dayClock = 1
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.bogSunAlpha < CGFloat(0.01))
        s.dayClock = 2
        for _ in 0..<120 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.bogSunAlpha > CGFloat(0.3))
        let splat = BogPainter.image(width: 96, height: 96, scale: 1) { ctx, sz in
            BogArt.drawSplat(ctx, size: sz, seed: 0x5A1A7)
        }
        if let im = splat {
            let c = SceneTests.average(im, x: 59, yUp: 37, n: 2)
            #expect(c.r > 0.9 && c.g > 0.65 && c.b < 0.6, "splat \(c.r) \(c.g) \(c.b)")
        } else {
            Issue.record("the splat did not draw")
        }
    }

    // MARK: R7

    /// R7 (#1): the floor every pair of variety glyphs must differ by (mean absolute RGB difference, 0 … 1, at 120 pt).
    /// The R6 near-copies (Classic against Cupped or Sawtooth) measured about 0.01 by estimate; R7's weakest pair is
    /// about 0.03 by estimate, so 0.015 catches a real copy without being flaky (the drawing is deterministic).
    static let varietyFloor: Double = 0.015

    /// R7 (#1): variety `v`'s Garden glyph (the hero 3/4 trap, as the Garden, Results and the pose card draw it),
    /// fitted into a 120 pt square on the Garden card's green, at 1×.
    static func varietyGlyph(_ v: TrapVariety) -> CGImage? {
        BogPainter.image(width: 120, height: 120, scale: 1) { ctx, sz in
            BogPainter.fill(ctx, CGPath(rect: CGRect(origin: .zero, size: sz), transform: nil), RGBA(hex: 0x1E4A2A))
            TrapArt.drawThreeQuarterTrap(ctx, size: sz, variety: v)
        }
    }

    /// R7 (#1): the mean absolute RGB difference (0 … 1) of two opaque bitmaps of one size (0 if they can't be read).
    static func meanDifference(_ a: CGImage, _ b: CGImage) -> Double {
        guard a.width == b.width, a.height == b.height, a.bitsPerPixel == 32, b.bitsPerPixel == 32,
              let da = a.dataProvider?.data, let db = b.dataProvider?.data,
              let pa = CFDataGetBytePtr(da), let pb = CFDataGetBytePtr(db) else { return 0 }
        var sum = 0.0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let ia = y * a.bytesPerRow + x * 4
                let ib = y * b.bytesPerRow + x * 4
                for c in 0..<3 { sum += abs(Double(pa[ia + c]) - Double(pb[ib + c])) }
            }
        }
        return sum / (Double(a.width * a.height) * 3 * 255)
    }

    /// R7 (#1, P0): the 8 varieties read apart at a 120 pt thumbnail. Every pair of Garden glyphs differs by at least
    /// `varietyFloor`, Classic's hero is the R6 drawing, and the cut is cosmetic: every variety keeps the same trap
    /// zone and the same number of cilia in play.
    @Test func theEightVarietiesReadApartAtAThumbnail() {
        var glyphs: [(TrapVariety, CGImage)] = []
        for v in TrapVariety.allCases {
            if let im = SceneTests.varietyGlyph(v) {
                glyphs.append((v, im))
            } else {
                Issue.record("\(v): the glyph did not draw")
            }
        }
        #expect(glyphs.count == TrapVariety.allCases.count)
        var weakest = Double.greatestFiniteMagnitude
        var weakestPair = ""
        var report: [String] = []
        for i in 0..<glyphs.count {
            for j in (i + 1)..<glyphs.count {
                let d = SceneTests.meanDifference(glyphs[i].1, glyphs[j].1)
                report.append("\(glyphs[i].0)/\(glyphs[j].0) \(String(format: "%.4f", d))")
                #expect(d >= SceneTests.varietyFloor, "\(glyphs[i].0) vs \(glyphs[j].0): \(d)")
                if d < weakest {
                    weakest = d
                    weakestPair = "\(glyphs[i].0) vs \(glyphs[j].0)"
                }
            }
        }
        print("SNAP-VARIETY-DIFF weakest \(weakestPair) \(weakest); " + report.joined(separator: ", "))
        #expect(weakest >= SceneTests.varietyFloor, "weakest \(weakestPair): \(weakest)")

        // Classic is the R6 hero (no scale, no drop); B52 is bigger and Cupped deeper, cosmetically.
        let classic = TrapArt.look(.classic)
        #expect(abs(classic.heroLobes.width - CGFloat(1)) < CGFloat(0.0001))
        #expect(abs(classic.heroLobes.height - CGFloat(1)) < CGFloat(0.0001))
        #expect(classic.heroTeeth == 13)
        #expect(abs(TrapPose.stemDrop(.classic)) < CGFloat(0.0001))
        let cb = TrapPose.bounds(.classic), r6 = TrapPose.bounds()
        #expect(abs(cb.minX - r6.minX) < CGFloat(0.001) && abs(cb.maxY - r6.maxY) < CGFloat(0.001))
        #expect(abs(cb.width - r6.width) < CGFloat(0.001) && abs(cb.height - r6.height) < CGFloat(0.001))
        let b52 = TrapArt.look(.b52)
        #expect(b52.heroLobes.width > CGFloat(1.12) && b52.heroLobes.height > CGFloat(1.12))
        #expect(b52.heroToothWidth > CGFloat(2) && b52.heroToothLength > CGFloat(1.3))
        #expect(TrapArt.look(.cupped).heroLobes.height > CGFloat(1.15))
        #expect(TrapArt.look(.cupped).heroRimLine != nil)
        #expect(TrapArt.look(.fusedTooth).heroFrill != nil)
        #expect(!TrapPose.frillPath(.fusedTooth).isEmpty)
        #expect(TrapArt.look(.sawtooth).heroTeeth > classic.heroTeeth + 6)
        #expect(TrapArt.look(.sharkTooth).heroTeeth < classic.heroTeeth)
        // Golden Glow is gold inside: its hero face and its play face at the margin.
        let gold = TrapArt.look(.goldenGlow)
        #expect(gold.heroFace.r > 0.8 && gold.heroFace.g > 0.6 && gold.heroFace.b < 0.4)
        let gm = gold.face(at: 0.9)
        #expect(gm.r > 0.7 && gm.g > 0.5 && gm.b < 0.3, "gold face \(gm.r) \(gm.g) \(gm.b)")
        // Cosmetic only: the zone and the cilia count are every variety's.
        let g = SceneTests.geometry
        for v in TrapVariety.allCases {
            #expect(TrapArt.teeth(side: 1, geometry: g, variety: v).count == TrapArt.teethPerSide)
            #expect(TrapArt.look(v).spread <= CGFloat(1.0301), "\(v) play spread")
        }
    }

    /// R7 (#4, the founder's follow-up: truthful clear zones). Core owns the rule (`TrapSession.keepOut`), fed by the
    /// Scene (`BogScene.coreKeepOut`: the HUD's plates or Home's buttons, the midrib band and the edge strips). A
    /// seeded Zen bog runs 30 s under the play HUD's corners: no still, resting bug's **Core position** (sipping, or
    /// walking and not moving) comes within Core's clearance of any of those rects (3.5 pt slack, as Core's own test,
    /// for an ant's wobble), and every catchable bug is drawn exactly at its Core position. As Home (decoration) the
    /// session takes Home's keep-out too; there catchable bugs are still drawn true and no sitting bug is ever hidden.
    @Test func sittingBugsKeepTheClearZones() {
        let l = SceneTests.duo
        let g = l.geometry
        let size = l.size
        let tol = CGFloat(0.5)
        let slack = 3.5
        for home in [false, true] {
            let scene = BogScene(layout: l)
            scene.showsEconomy = !home
            #expect(scene.isHome == home)
            let keep = scene.bugKeepOut
            #expect(keep == (home ? BogScene.homeKeepOut(l) : BogScene.defaultKeepOut(l)))
            let rules = scene.coreKeepOut
            #expect(rules.count == keep.count + 5)
            let session = TrapSession(mode: .zen, seed: home ? 0x5EED7 : 0x5EED4, best: 1, geometry: g,
                                      options: SessionOptions.for(.zen))
            scene.applyKeepOut(to: session)
            #expect(session.keepOut == rules)
            let dt = 1.0 / 60.0
            var still = 0
            var catchable = 0
            var bad: [String] = []
            var last: [Int: CGPoint] = [:]
            for frame in 0..<(30 * 60) {
                let events = session.step(dt: dt, input: TrapInput())
                let snap = session.snapshot
                scene.show(snap, events: events, dt: dt)
                var sittingOnCanvas = 0
                for b in snap.bugs {
                    let p = b.position
                    var moved = CGFloat(99)
                    if let q = last[b.id] {
                        let dx = q.x - p.x, dy = q.y - p.y
                        moved = (dx * dx + dy * dy).squareRoot()
                    }
                    last[b.id] = p
                    var resting = false
                    switch b.activity {
                    case .sipping: resting = true
                    case .walking: resting = moved < CGFloat(0.25)
                    case .arriving, .leaving, .hopping, .escaped, .released, .caught: resting = false
                    }
                    var walkingOrSipping = false
                    if case .walking = b.activity { walkingOrSipping = true }
                    if case .sipping = b.activity { walkingOrSipping = true }
                    if walkingOrSipping && p.x >= 0 && p.x <= size.width && p.y >= 0 && p.y <= size.height {
                        sittingOnCanvas += 1
                    }
                    if BogBugLayer.isCatchable(b) {
                        catchable += 1
                        let nd = scene.drawnNudge(ofBug: b.id) ?? .zero
                        if abs(nd.x) > CGFloat(0.01) || abs(nd.y) > CGFloat(0.01), bad.count < 6 {
                            bad.append("\(frame) catchable \(b.species) drawn \(nd) off its Core spot")
                        }
                    }
                    guard resting && !home else { continue }
                    still += 1
                    let c = TrapRules.keepOutClearance(radius: BugCatalog.info(b.species).radius,
                                                       protected: b.species.isProtected)
                    let hit = TrapRules.touchesKeepOut(rules, Double(p.x), Double(p.y), clearance: c - slack)
                    if hit && bad.count < 6 { bad.append("\(frame) \(b.species) rests at \(p) in a keep-out") }
                }
                // Never hidden: every sitting bug on the canvas is drawn.
                let drawn = scene.sittingBugRects.count
                if drawn != sittingOnCanvas && bad.count < 6 {
                    bad.append("\(frame) \(sittingOnCanvas) sitting, \(drawn) drawn")
                }
            }
            #expect(bad.isEmpty, "\(home ? "home" : "play"): \(bad)")
            #expect(catchable > 100, "\(home ? "home" : "play"): only \(catchable) catchable bug-frames")
            if !home { #expect(still > 100, "only \(still) still, resting bug-frames") }
        }
        // The Core keep-out: the plates, then the midrib band and the four edge strips.
        let rules = BogScene.coreKeepOut(BogScene.defaultKeepOut(l), layout: l)
        let flyClear = TrapRules.keepOutClearance(radius: BugCatalog.info(.housefly).radius, protected: false)
        #expect(TrapRules.touchesKeepOut(rules, Double(g.center.x), Double(g.center.y), clearance: flyClear))
        #expect(TrapRules.touchesKeepOut(rules, 20, Double(g.center.y), clearance: flyClear))
        #expect(!TrapRules.touchesKeepOut(rules, Double(g.center.x) + 200, Double(g.center.y), clearance: flyClear))
        // A scene's driver that takes the keep-out is sent it (and again on a reset).
        let sink = SceneKeepOutSink()
        let fed = BogScene(layout: l)
        fed.driver = sink
        #expect(sink.received.last == fed.coreKeepOut)
        fed.hudKeepOut = [CGRect(x: 700, y: 560, width: 200, height: 80)]
        #expect(sink.received.last == fed.coreKeepOut)
        let before = sink.received.count
        fed.reset()
        #expect(sink.received.count == before + 1)

        // Home's column (visual easing only): a bumblebee's halo has no clear spot in it; a fly is moved out of it.
        let col = BogScene.homeKeepOut(l)
        #expect(col.count == 1)
        if let c = col.first {
            #expect(c.minX > l.creaseMaxX && c.maxX < l.size.width)
            let mid = CGPoint(x: c.midX, y: c.midY)
            let bbR = CGFloat(39.6)
            let bbHalf = BogBugLayer.footprintHalf(.bumblebee, radius: bbR)
            let bb = BogBugLayer.clearance(at: mid, half: bbHalf, radius: bbR, resting: true, keepOut: col,
                                           canvas: size, geometry: g, hudGap: 0)
            #expect(!bb.clear)
            let fr = CGFloat(25)
            let fh = BogBugLayer.footprintHalf(.housefly, radius: fr)
            let fly = BogBugLayer.clearance(at: mid, half: fh, radius: fr, resting: true, keepOut: col, canvas: size,
                                            geometry: g, hudGap: 0)
            #expect(fly.clear)
            let q = CGPoint(x: mid.x + fly.offset.x, y: mid.y + fly.offset.y)
            let flyFoot = CGRect(x: q.x - fh, y: q.y - fh, width: 2 * fh, height: 2 * fh).insetBy(dx: tol, dy: tol)
            #expect(!c.intersects(flyFoot))
        }
        // The App's own rects still win on Home.
        let scene = BogScene(layout: l)
        scene.showsEconomy = false
        let plate = CGRect(x: 600, y: 200, width: 120, height: 60)
        scene.hudKeepOut = [plate]
        #expect(scene.bugKeepOut == [plate])
        scene.hudKeepOut = nil
        #expect(scene.bugKeepOut == BogScene.homeKeepOut(l))
        scene.showsEconomy = true
        #expect(scene.bugKeepOut == BogScene.defaultKeepOut(l))
        // A resting bee's halo keeps off the crease band (Core's r + 16 is not enough for it).
        let beeR = CGFloat(28.8)
        let beeHalf = BogBugLayer.footprintHalf(.bee, radius: beeR)
        #expect(BogBugLayer.midribClearance(half: beeHalf, radius: beeR) >= ScreenLayout.creaseHalfWidth + beeHalf)
    }

    /// R7 (#14): night reads as night: a deeper blue grade than R6 (bluer against its green, darker than noon by more
    /// than half), a navy vignette, and the bog's fireflies glowing on a still frame.
    @Test func nightIsADeepBlueWithGlowingFireflies() {
        let bog = TrapArt.palette.bog
        func lum(_ c: RGBA) -> Double { 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
        let noon = BogLight.litBog(bog, key: BogLight.key(at: 1), skyLevel: 0.5)
        for clock in [3.0, 3.5, 4.0] {
            let n = BogLight.litBog(bog, key: BogLight.key(at: clock), skyLevel: 0.5)
            #expect(n.b > 2 * n.g && n.b > 3 * n.r, "night \(clock): \(n.r) \(n.g) \(n.b)")
            #expect(lum(n) < 0.45 * lum(noon), "night \(clock) luminance \(lum(n)) against noon \(lum(noon))")
        }
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.dayClock = 0.5
        scene.show(s, events: [], dt: 1.0 / 60.0)
        let day = scene.vignetteColor
        #expect(day.g > day.b)
        #expect(scene.glowingFireflies == 0)
        s.dayClock = 3.4
        for _ in 0..<60 { scene.show(s, events: [], dt: 1.0 / 60.0) }
        #expect(scene.nightLevel > CGFloat(0.99))
        let v = scene.vignetteColor
        #expect(v.b > 3 * v.g && v.b > 0.1, "vignette \(v.r) \(v.g) \(v.b)")
        // A still frame: every firefly glows at least `fireflyFloor`, and there are plenty.
        #expect(scene.visibleFireflies >= 12, "fireflies \(scene.visibleFireflies)")
        #expect(scene.glowingFireflies == scene.visibleFireflies)
        #expect(BogLight.fireflyFloor > CGFloat(0.4) && BogLight.fireflyGlow > CGFloat(70))
    }

    // MARK: R8 (the phone IS the trap)

    /// R8 §1: with hinge input the inner screen never draws the trap shutting. Whatever the closure (the snapshot's or
    /// the App's predicted one), and through the bite at the shut, the lobes stay drawn open: no slam, no squeeze, no
    /// closed trap, no pop (nobody can see the inner screen while the phone is shut).
    @Test func withTheHingeTheLobesStayOpen() {
        let scene = BogScene(layout: SceneTests.duo)
        scene.usesHinge = true
        var s = SceneTests.crowd()
        for deg in [0.0, 10, 22, 45, 80, 120, 150, 175] {
            s.closure = deg
            for _ in 0..<3 { scene.show(s, events: [], dt: 1.0 / 120.0) }
            #expect(abs(scene.drawnClosure01) < CGFloat(0.0001), "drawn \(scene.drawnClosure01) at \(deg)°")
            #expect(abs(scene.lobeScale - CGFloat(1)) < CGFloat(0.001), "lobe scale \(scene.lobeScale) at \(deg)°")
            #expect(scene.jawSlam < CGFloat(0.001))
            #expect(scene.closedTrapAlpha < CGFloat(0.001))
        }
        // The App's predicted closure is a cue too, never a shut.
        scene.drawnClosure = 140
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(abs(scene.drawnClosure01) < CGFloat(0.0001))
        #expect(scene.closingCue > CGFloat(0.99))
        scene.drawnClosure = nil
        // The bite, as the phone shuts.
        s.closure = 150
        s.shut = true
        s.bugs[0].activity = .caught(elapsed: 0)
        let sp = s.bugs[0].species
        let report = BiteReport(caught: [sp], escaped: 0, stingers: [], points: 12, countMultiplier: 1,
                                chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.25, time: 1)
        scene.show(s, events: [.snapped(report), .bugCaught(id: s.bugs[0].id, species: sp,
                                                            position: s.bugs[0].position)], dt: 1.0 / 120.0)
        #expect(!scene.inHitStop)
        for _ in 0..<60 {
            scene.show(s, events: [], dt: 1.0 / 120.0)
            #expect(scene.jawSlam < CGFloat(0.001))
            #expect(scene.closedTrapAlpha < CGFloat(0.001))
            #expect(abs(scene.drawnClosure01) < CGFloat(0.0001))
            #expect(scene.lobeScale > CGFloat(0.999))
        }
        #expect(scene.flashingBugs == 0)
        #expect(!scene.isDrawn(bug: s.bugs[0].id))
        #expect(scene.popTexts.isEmpty, "\(scene.popTexts)")
        #expect(scene.digestPending)
    }

    /// R8 §1: the closing cues follow the closure continuously, subtle at 10°, strong at 80° and the edges near-black
    /// by 120°: the cilia lean in, the rim shadow deepens, the edges dim and the sitters in the trap panic (buzz and
    /// jitter). Touch draws none of them.
    @Test func theClosingCuesFollowTheClosure() {
        #expect(TrapArt.closingCue(0) < CGFloat(0.0001))
        #expect(TrapArt.closingCue(.nan) < CGFloat(0.0001))
        #expect(abs(TrapArt.closingCue(200) - CGFloat(1)) < CGFloat(0.0001))
        let subtle = TrapArt.closingCue(10)
        #expect(subtle > CGFloat(0) && subtle < CGFloat(0.15))
        #expect(TrapArt.closingCue(80) > CGFloat(0.55))
        #expect(TrapArt.edgeDim(TrapArt.closingCue(120)) > CGFloat(0.9))
        #expect(TrapArt.edgeDim(CGFloat.nan) < CGFloat(0.0001))

        let scene = BogScene(layout: SceneTests.duo)
        scene.usesHinge = true
        var s = SceneTests.crowd()
        let sitter = s.bugs[0].id
        #expect(s.bugs[0].inTrap)
        var last: (cue: CGFloat, rim: CGFloat, dim: CGFloat, reach: CGFloat, panic: CGFloat)?
        for deg in [0.0, 10, 40, 80, 120] {
            s.closure = deg
            var jitter: CGFloat = 0
            for _ in 0..<12 {
                scene.show(s, events: [], dt: 1.0 / 120.0)
                let j = scene.panicJitter(ofBug: sitter) ?? .zero
                jitter = max(jitter, abs(j.x) + abs(j.y))
            }
            let now = (cue: scene.closingCue, rim: scene.rimShadow, dim: scene.edgeDim, reach: scene.toothReach,
                       panic: scene.panic(ofBug: sitter) ?? 0)
            if let l = last {
                #expect(now.cue > l.cue && now.rim > l.rim && now.dim > l.dim, "cues at \(deg)°")
                #expect(now.reach < l.reach, "cilia reach \(now.reach) at \(deg)°")
                #expect(now.panic > l.panic - CGFloat(0.0001), "panic \(now.panic) at \(deg)°")
            }
            if deg < 1 {
                // Open: nothing.
                #expect(now.cue < CGFloat(0.0001) && now.dim < CGFloat(0.0001) && now.rim < CGFloat(0.0001))
                #expect(now.reach > CGFloat(0.99))
                #expect(jitter < CGFloat(0.0001))
                #expect(scene.faceShade < CGFloat(0.01))
            } else if deg < 11 {
                // Subtle at 10°.
                #expect(now.dim < CGFloat(0.15) && now.rim < CGFloat(0.15) && now.reach > CGFloat(0.95))
                #expect(now.dim > CGFloat(0))
            } else if deg > 79 && deg < 81 {
                // Strong at 80°.
                #expect(now.dim > CGFloat(0.55) && now.rim > CGFloat(0.5) && now.reach < CGFloat(0.6))
                #expect(now.panic > CGFloat(0.8) && scene.bugPanic > CGFloat(0.8))
                #expect(jitter > CGFloat(1), "jitter \(jitter)")
            } else if deg > 119 {
                // Near-black at the edges by 120°.
                #expect(now.dim > CGFloat(0.9))
            }
            last = now
        }
        // The lobes never moved for any of it.
        #expect(abs(scene.drawnClosure01) < CGFloat(0.0001))
        #expect(abs(scene.lobeScale - CGFloat(1)) < CGFloat(0.001))

        // Touch: no cues (its sweep draws the lobes closing, as before).
        let touch = BogScene(layout: SceneTests.duo)
        var t = SceneTests.crowd()
        t.closure = Tuning.snapDepth
        for _ in 0..<3 { touch.show(t, events: [], dt: 1.0 / 120.0) }
        #expect(touch.closingCue < CGFloat(0.0001) && touch.edgeDim < CGFloat(0.0001))
        #expect(touch.bugPanic < CGFloat(0.0001))
        #expect(touch.drawnClosure01 > CGFloat(0.99))
    }

    /// R8 §1: on the reopen after a hinge bite (`shut` goes false) the digest plays: the caught bugs gone, a gold juice
    /// stain and remains where each one was, the "+N" pop and the FEAST moment. None of it shows while shut.
    @Test func theDigestPlaysOnTheReopen() {
        let scene = BogScene(layout: SceneTests.duo)
        scene.usesHinge = true
        let g = SceneTests.geometry
        let n = 6
        var bugs: [BugState] = []
        for i in 0..<n {
            let sd: CGFloat = i % 2 == 0 ? -1 : 1
            let p = CGPoint(x: g.center.x + sd * (120 + 26 * CGFloat(i)), y: g.center.y - 130 + 46 * CGFloat(i))
            bugs.append(SceneTests.bug(i, .housefly, p, .sipping))
        }
        var s = TrapSnapshot(time: 1, bugs: bugs, snapsLeft: 6)
        for _ in 0..<2 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        // The bite as the phone shuts (six: a FEAST).
        s.closure = 150
        s.shut = true
        s.snapsLeft = 8
        let report = BiteReport(caught: Array(repeating: BugSpecies.housefly, count: n), escaped: 0, stingers: [],
                                points: 120 * n, countMultiplier: n, chainMultiplier: 1.5, snapsBack: 2,
                                snapsLost: 0, duration: 0.2, time: 1)
        var events: [TrapEvent] = [.snapped(report)]
        for i in 0..<n {
            s.bugs[i].activity = .caught(elapsed: 0)
            events.append(.bugCaught(id: i, species: .housefly, position: s.bugs[i].position))
        }
        events.append(.feast(count: n, snapsBack: 2))
        scene.show(s, events: events, dt: 1.0 / 120.0)
        // Shut: nothing of the bite shows (the phone is closed; iOS shows the outer display).
        for _ in 0..<30 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.digestPending)
        #expect(scene.digestsShown == 0)
        #expect(scene.popTexts.isEmpty, "\(scene.popTexts)")
        #expect(scene.banners.isEmpty)
        #expect(scene.juiceStains == 0)
        #expect(!scene.lastBiteWasFeastEvent)
        for i in 0..<n { #expect(!scene.isDrawn(bug: i)) }
        // The reopen (the re-arm): the digest.
        s.shut = false
        s.closure = 50
        scene.show(s, events: [.rearmed], dt: 1.0 / 120.0)
        #expect(!scene.digestPending)
        #expect(scene.digestsShown == 1)
        #expect(scene.juiceStains == n)
        #expect(scene.remainsShowing == n * BogEffects.remainsPerBug)
        #expect(scene.lastBiteWasFeastEvent)
        #expect(scene.banners.contains(BogScene.feastBanner))
        let callout = BogScene.bigFeastLabel(count: n, points: 120 * n)
        #expect(scene.popTexts.contains(callout), "\(scene.popTexts)")
        // Still never a slam, a hit-stop, a white flash or a gulp: the bugs were eaten out of sight.
        #expect(!scene.inHitStop)
        #expect(scene.flashingBugs == 0)
        #expect(!scene.gulpQueued(ofBug: 0))
        for _ in 0..<12 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.jawSlam < CGFloat(0.001))
        #expect(scene.closedTrapAlpha < CGFloat(0.001))
        #expect(abs(scene.drawnClosure01) < CGFloat(0.0001))
        for i in 0..<n { #expect(!scene.isDrawn(bug: i)) }
        #expect(scene.juiceStains == n)
        // The stain and the remains fade in their time.
        let frames = Int(BogEffects.digestLife * 120) + 12
        for _ in 0..<frames { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.juiceStains == 0)
        #expect(scene.remainsShowing == 0)
    }

    /// R8: a hinge bite whose snapshot never shows the phone shut (a pilot, a Core without `shut`) still digests after
    /// `digestFallback`; touch never holds a bite (a tap is an instant bite: the slam and the pop at once).
    @Test func aBiteNeverWaitsForeverAndTouchNeverWaits() {
        let scene = BogScene(layout: SceneTests.duo)
        scene.usesHinge = true
        var s = SceneTests.crowd()
        s.shut = false
        scene.show(s, events: [], dt: 1.0 / 120.0)
        s.bugs[0].activity = .caught(elapsed: 0)
        let sp = s.bugs[0].species
        let id = s.bugs[0].id
        let report = BiteReport(caught: [sp], escaped: 0, stingers: [], points: 12, countMultiplier: 1,
                                chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.3, time: 1)
        let events: [TrapEvent] = [.snapped(report), .bugCaught(id: id, species: sp, position: s.bugs[0].position)]
        scene.show(s, events: events, dt: 1.0 / 120.0)
        #expect(scene.digestPending)
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(scene.digestPending)
        let wait = Int(BogScene.digestFallback * 120) + 2
        for _ in 0..<wait { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(!scene.digestPending)
        #expect(scene.digestsShown == 1)
        #expect(scene.juiceStains == 1)
        let one = BogScene.heroLabel(count: 1, points: 12)
        #expect(scene.popTexts.contains(one), "\(scene.popTexts)")

        // Touch: the pop and the slam at once, no digest.
        let touch = BogScene(layout: SceneTests.duo)
        var t = SceneTests.crowd()
        touch.show(t, events: [], dt: 1.0 / 120.0)
        t.closure = Tuning.snapDepth
        t.bugs[0].activity = .caught(elapsed: 0)
        touch.show(t, events: events, dt: 1.0 / 120.0)
        #expect(!touch.digestPending)
        #expect(touch.popTexts.contains(one), "\(touch.popTexts)")
        for _ in 0..<9 { touch.show(t, events: [], dt: 1.0 / 120.0) }
        #expect(touch.jawSlam > CGFloat(0.95))
        #expect(touch.closedTrapAlpha > CGFloat(0.95))
        #expect(touch.juiceStains == 0)
    }
}

/// R8 portrait (design/notes/portrait-R8.md): on a Duo held like a laptop the App shows the scene turned a quarter
/// clockwise (`BogScene.textTurned`); the word pops are drawn turned back, so they read upright, and rise toward the
/// screen's top (scene −x). Book pose and phones are unchanged.
@MainActor
struct ScenePortraitTests {
    @Test func turnedPopsReadUprightAndRiseUp() {
        #expect(abs(BogPops.labelAngle(true) - CGFloat.pi / 2) < CGFloat(0.0001))
        #expect(abs(BogPops.labelAngle(false)) < CGFloat(0.0001))
        let up = BogPops.riseDirection(true)
        #expect(abs(up.dx + 1) < CGFloat(0.0001) && abs(up.dy) < CGFloat(0.0001))
        let flatUp = BogPops.riseDirection(false)
        #expect(abs(flatUp.dx) < CGFloat(0.0001) && abs(flatUp.dy - 1) < CGFloat(0.0001))
        let box = BogPops.drawnBox(CGSize(width: 120, height: 40), turned: true)
        #expect(abs(box.width - 40) < CGFloat(0.0001) && abs(box.height - 120) < CGFloat(0.0001))

        let start = CGPoint(x: 400, y: 300)
        let flat = BogPops()
        flat.pop("3 bugs · +360", at: start, size: 40, fill: .white, stroke: .black, rise: 46)
        flat.update(0.5)
        let turned = BogPops()
        turned.quarterTurn = true
        turned.pop("3 bugs · +360", at: start, size: 40, fill: .white, stroke: .black, rise: 46)
        turned.update(0.5)
        guard let a = flat.activeRects.first, let b = turned.activeRects.first,
              let live = turned.liveRects.first else {
            Issue.record("no pop on screen")
            return
        }
        // Book pose: wide, rising up (+y). Turned: tall in scene space (wide on the turned screen), rising toward −x.
        #expect(a.width > a.height)
        #expect(b.height > b.width)
        #expect(abs(a.width - b.height) < CGFloat(0.5))
        #expect(a.midY > start.y + 1)
        #expect(abs(a.midX - start.x) < CGFloat(0.5))
        #expect(b.midX < start.x - 1)
        #expect(abs(b.midY - start.y) < CGFloat(0.5))
        // The App's plate keeps off the whole turned footprint: it sweeps toward −x, to the end of the rise.
        #expect(live.contains(CGPoint(x: b.midX, y: b.midY)))
        #expect(live.minX < start.x - 46)
        #expect(live.height >= b.height)
        // The placement footprint turns with it.
        let foot = BogScene.popFootprint(center: start, halfWidth: 20, halfHeight: 60, rise: 30, turned: true)
        #expect(foot.minX <= start.x - 20 - 30 - BogScene.popGap + CGFloat(0.5))
        #expect(foot.maxY >= start.y + 60)
        #expect(foot.maxY <= start.y + 60 + 2 + BogScene.popGap + CGFloat(0.5))
        let book = BogScene.popFootprint(center: start, halfWidth: 60, halfHeight: 20, rise: 30)
        #expect(book.maxY >= start.y + 20 + 30)
        #expect(book.minX >= start.x - 60 - BogScene.popGap - CGFloat(0.5))
    }

    @Test func theSceneTurnsItsTextOnlyWhenAsked() {
        let scene = BogScene(layout: ScreenLayout(hasFold: true))
        #expect(!scene.textTurned)
        scene.textTurned = true
        #expect(scene.textTurned)
        SceneHooks.setTextTurned(scene, false)
        #expect(!scene.textTurned)
    }
}
