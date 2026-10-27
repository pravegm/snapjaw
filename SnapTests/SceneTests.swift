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
        #expect(abs(right.height - 2 * g.b) < CGFloat(1))
        // Closing foreshortens the lobe towards the midrib, by a little.
        let shut = TrapArt.lobePath(side: 1, geometry: g, closure01: 1).boundingBoxOfPath
        #expect(shut.width < right.width - CGFloat(5))
        #expect(shut.width > right.width * CGFloat(0.9))
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
                #expect(t.length >= CGFloat(18) && t.length <= CGFloat(44))
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
        #expect(abs(TrapArt.defaultRadius(.gnat) - CGFloat(7)) < CGFloat(0.01))
        #expect(abs(TrapArt.defaultRadius(.dragonfly) - CGFloat(24)) < CGFloat(0.01))
        #expect(abs(TrapArt.defaultRadius(.bumblebee) - CGFloat(22)) < CGFloat(0.01))
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
        #expect(BogScene.multiplier(1.5) == "×1.5")
        #expect(BogScene.multiplier(2) == "×2")
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
        #expect(scene.popTexts.contains("+26"))
        #expect(scene.popTexts.contains("DOUBLE ×2"))
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
            .beeSpared(species: .bee), .lastSnap, .tired, .newBest, .finished,
        ]
        scene.show(s, events: events, dt: 1.0 / 120.0)
        for _ in 0..<30 { scene.show(s, events: [], dt: 1.0 / 120.0) }
        #expect(scene.popTexts.contains("FEAST ×5"))
        #expect(scene.popTexts.contains("Stung!"))
        #expect(scene.popTexts.contains("Golden! +2 snaps"))
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
}
