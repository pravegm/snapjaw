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
        // The catch spray is pale nectar, never red (4+).
        let j = BogEffects.juiceColor
        #expect(j.g > j.r * 0.9 && j.g > 0.8)
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
        #expect(BogScene.countLabel(1) == nil)
        #expect(BogScene.countLabel(2) == "DOUBLE ×2")
        #expect(BogScene.countLabel(3) == "TRIPLE ×3")
        #expect(BogScene.countLabel(4) == "QUAD ×4")
        #expect(BogScene.countLabel(6) == "FEAST ×6")
        #expect(BogScene.feastLabel(1) == "Feast! +1 snap")
        #expect(BogScene.feastLabel(2) == "Feast! +2 snaps")
        #expect(BogScene.heroLabel(count: 5, points: 255) == "FEAST ×5 · +255")
        #expect(BogScene.heroLabel(count: 1, points: 12) == "+12")
        #expect(BogScene.luckyLabel(.goldenScarab) == "Golden!")
        #expect(BogScene.multiplier(1.5) == "×1.5")
        #expect(BogScene.multiplier(2) == "×2")
        // R3 (#8, #15).
        #expect(BogScene.stungLabel(points: 172) == "Stung! · +172")
        #expect(BogScene.heldLabel(1.5) == "×1.5 held")
        #expect(BogScene.wiltedLabel == "Too slow! −1 snap")
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

    @Test func closureTracksAndTheBiteSlams() {
        let scene = BogScene(layout: SceneTests.duo)
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
        #expect(scene.popTexts.contains("DOUBLE ×2 · +26"))
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
        #expect(scene.popTexts.contains("Golden!"))
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

    @Test func closureTracksTheHandsAndTheApp() {
        let scene = BogScene(layout: SceneTests.duo)
        var s = SceneTests.crowd()
        s.closure = Tuning.snapDepth
        scene.show(s, events: [], dt: 1.0 / 120.0)
        // 15 % foreshortening at the snap depth.
        #expect(abs(scene.lobeScale - CGFloat(0.85)) < CGFloat(0.01))
        // The App's predicted closure wins over the snapshot's.
        scene.drawnClosure = Tuning.snapDepth * 0.5
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(abs(scene.drawnClosure01 - CGFloat(0.5)) < CGFloat(0.01))
        scene.drawnClosure = nil
        s.closure = 0
        scene.show(s, events: [], dt: 1.0 / 120.0)
        #expect(scene.drawnClosure01 < CGFloat(0.01))
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
        #expect(scene.popTexts.contains("FEAST ×5 · +255"))
        for _ in 0..<150 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.glyphsLanded == 3)
        #expect(scene.glyphFlights == 0)
        // A sting cracks a glyph on the row.
        let sting = BiteReport(caught: [], escaped: 0, stingers: [.wasp], points: 0, countMultiplier: 0,
                               chainMultiplier: 1, snapsBack: 0, snapsLost: 2, duration: 0.1, time: 3)
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
        // Dusk shows: a warm rim light on the lobes and a peach bog.
        s.dayClock = 2
        scene.show(s, events: [], dt: 1.0 / 60.0)
        #expect(scene.rimLightAlpha > CGFloat(0.4))
        let k = BogLight.key(at: 2)
        #expect(k.env.r > 0.95 && k.env.b < 0.65 && k.hazeAlpha > 0.2)
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
                    #expect(scene.closedTrapAlpha > CGFloat(0.95))
                    #expect(scene.lobeScale < CGFloat(0.35))
                    narrowest = min(narrowest, f.width)
                }
            }
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
    /// glyph cracks), the row flashes crimson on a sting, and "Bzzt!" sits above the bee's ring, not over the bee.
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
        scene.show(s, events: [.snapped(sting), .stung(id: 40, species: .bee, cost: 1)], dt: 1.0 / 120.0)
        #expect(scene.snapsShownOffset == 1)
        for _ in 0..<12 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.snapsRowFlashing)
        let texts = scene.popTexts, rects = scene.popRects
        let ring = BogBugLayer().radius(.bee) * TrapArt.protectedRingScale
        if let i = texts.firstIndex(of: "Bzzt!"), i < rects.count {
            let r = rects[i]
            let clear = r.minY >= bee.y + ring - CGFloat(0.5) || r.maxY <= bee.y - ring + CGFloat(0.5)
            #expect(clear)
        } else {
            Issue.record("no Bzzt! pop")
        }
        for _ in 0..<30 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.snapsShownOffset == 0)
    }

}
