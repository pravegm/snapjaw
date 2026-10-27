import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Snap

// App engineer tests: progress/settings round-trip, tolerant decoding, migration and the corrupt-save backup; the
// Daily one-scored-try rule; recording a run (Bug Book, rank, achievements) and an abandoned one; demo parsing and the
// seeded profiles; the pose, fold and orientation rules; the First Bite's step gating; the HUD's words and log
// formats; Game Center queue rules; the canvas and HUD layout maths; the run tally; the opaque PNG writer.

// MARK: - Helpers

private func makeRun(mode: RunMode = .feed, score: Int = 1_200, bugs: Int = 9,
                     caught: [String: Int] = ["housefly": 6, "gnat": 3], spared: [String: Int] = [:],
                     biggest: Int = 3, chain: Int = 2, beesSpared: Int = 0) -> RunResult {
    RunResult(mode: mode, seed: 7, score: score, seconds: 140, snaps: 28, bugsCaught: bugs, caughtBySpecies: caught,
              sparedBySpecies: spared, bestBitePoints: score / 3, biggestBite: biggest, longestChain: chain,
              beesSpared: beesSpared, stings: 1, feasts: 1, waves: 20, drySnaps: 4, fastestSnap: 0.12)
}

/// One rank per 100 bugs.
private func fakeRank(_ bugs: Int) -> Int { min(bugs / 100, 11) }

private func noAchievements(_ r: RunResult, _ bugs: Int, _ spared: Int, _ species: Int,
                            _ earned: Set<String>) -> [AchievementDef] { [] }

private func firstFeast(_ r: RunResult, _ bugs: Int, _ spared: Int, _ species: Int,
                        _ earned: Set<String>) -> [AchievementDef] {
    r.biggestBite >= 3 ? [AchievementDef(id: "snap.ach.test", title: "Test", detail: "A test")] : []
}

private func record(_ r: RunResult, _ data: inout ProgressData, today: Int = 299,
                    earn: (RunResult, Int, Int, Int, Set<String>) -> [AchievementDef] = noAchievements)
    -> RecordOutcome {
    ProgressRules.record(r, into: &data, today: today, rankFor: fakeRank, earn: earn)
}

private func abandon(_ r: RunResult, _ data: inout ProgressData, today: Int = 299) -> RecordOutcome {
    ProgressRules.recordAbandoned(r, into: &data, today: today, rankFor: fakeRank, earn: noAchievements)
}

private let tolerance: CGFloat = 0.75

private func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= tolerance }

private func report(caught: [BugSpecies], stingers: [BugSpecies] = [], duration: Double = 0.1) -> BiteReport {
    BiteReport(caught: caught, escaped: 0, stingers: stingers, points: 10 * caught.count, countMultiplier: caught.count,
               chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: duration, time: 3)
}

// MARK: - Persistence

@MainActor
struct PersistenceTests {
    @Test func progressRoundTrips() throws {
        var d = ProgressData()
        d.bestFeed = 2_400
        d.bestDaily = 1_900
        d.lifetimeBugs = 310
        d.lifetimeSpared = 12
        d.runs = 12
        d.caught = ["housefly": 200, "gnat": 110]
        d.spared = ["bee": 12]
        d.foundOrder = ["housefly", "gnat", "bee"]
        d.achievements = ["snap.ach.a"]
        d.daily[299] = DailyRecord(score: 800, finished: true, practiceBest: 300)
        d.dailyAttempted = [299]
        d.lastDailyDay = 299
        d.lessonDone = true
        d.fastestSnap = 0.104
        d.pendingRun = makeRun()
        let raw = try #require(ProgressStore.encode(d))
        let back = try #require(ProgressStore.decode(raw))
        #expect(back == d)
    }

    @Test func progressDecodesTolerantly() throws {
        let raw = Data(#"{"version":1,"bestFeed":500,"unknownField":3}"#.utf8)
        let d = try #require(ProgressStore.decode(raw))
        #expect(d.bestFeed == 500)
        #expect(d.lifetimeBugs == 0)
        #expect(d.daily.isEmpty)
        #expect(d.version == ProgressData.currentVersion)
    }

    @Test func migrationFromV0MarksTheLessonDone() throws {
        let raw = Data(#"{"runs":3,"caught":{"housefly":4}}"#.utf8)
        let d = try #require(ProgressStore.decode(raw))
        #expect(d.lessonDone)
        #expect(d.foundOrder == ["housefly"])
    }

    @Test func migrationNormalisesTheFoundOrder() {
        var d = ProgressData()
        d.caught = ["gnat": 2, "housefly": 1]
        d.foundOrder = ["gnat", "gnat", "wasp"]
        ProgressRules.migrate(&d, fromVersion: 1)
        #expect(d.foundOrder == ["gnat", "housefly"])
    }

    @Test func corruptSaveIsBackedUp() {
        let suite = "snap.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.set(Data("not json".utf8), forKey: ProgressStore.key)
        let store = ProgressStore(defaults: defaults)
        #expect(store.data == ProgressData())
        #expect(defaults.data(forKey: ProgressStore.backupKey) == Data("not json".utf8))
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func settingsRoundTripAndDefaults() throws {
        var s = SettingsData()
        #expect(s.soundOn && s.hapticsOn && !s.respectSilentSwitch && !s.hudOnLeft && !s.reduceMotion)
        s.hudOnLeft = true
        s.respectSilentSwitch = true
        let raw = try #require(SettingsStore.encode(s))
        let back = try #require(SettingsStore.decode(raw))
        #expect(back == s)
        let partial = try #require(SettingsStore.decode(Data(#"{"soundOn":false}"#.utf8)))
        #expect(!partial.soundOn)
        #expect(partial.hapticsOn)
    }

    @Test func inMemoryStoreWritesNothing() {
        let store = ProgressStore(inMemory: ProgressData())
        store.markLessonDone()
        #expect(store.data.lessonDone)
    }
}

// MARK: - The Daily and recording runs

struct DailyRuleTests {
    @Test func oneScoredTryADay() {
        var d = ProgressData()
        #expect(ProgressRules.canPlayScoredDaily(d, today: 299))
        ProgressRules.noteDailyStart(&d, day: 299)
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 299))
        #expect(ProgressRules.canPlayScoredDaily(d, today: 300))
        // A clock set back never gives another scored try.
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 298))
    }

    @Test func scoredDailyThenPractice() {
        var d = ProgressData()
        let o1 = record(makeRun(mode: .daily(day: 299, scored: true), score: 900), &d)
        #expect(o1.dailyCounted)
        #expect(d.daily[299]?.score == 900)
        #expect(d.bestDaily == 900)
        let o2 = record(makeRun(mode: .daily(day: 299, scored: false), score: 1_500), &d)
        #expect(o2.practice)
        #expect(d.daily[299]?.score == 900)
        #expect(d.daily[299]?.practiceBest == 1_500)
        #expect(d.bestDaily == 900)
    }

    @Test func abandonedScoredDailyKeepsItsScoreUnfinished() {
        var d = ProgressData()
        ProgressRules.noteDailyStart(&d, day: 299)
        _ = abandon(makeRun(mode: .daily(day: 299, scored: true), score: 400), &d)
        #expect(d.daily[299]?.score == 400)
        #expect(d.daily[299]?.finished == false)
        #expect(!ProgressRules.canPlayScoredDaily(d, today: 299))
    }

    @Test func recordingFillsTheBugBookAndRanks() {
        var d = ProgressData()
        let run = makeRun(score: 1_200, bugs: 150, caught: ["housefly": 100, "gnat": 50], spared: ["bee": 2],
                          beesSpared: 2)
        let o = record(run, &d, earn: firstFeast)
        #expect(o.isNewBest)
        #expect(!o.showsNewBest)
        #expect(o.isFirstScore)
        #expect(o.newSpecies == [.housefly, .gnat, .bee])
        #expect(o.rankBefore == 0)
        #expect(o.rankAfter == 1)
        #expect(o.rankedUp)
        #expect(o.newAchievements.map(\.id) == ["snap.ach.test"])
        #expect(d.speciesFound == 3)
        #expect(d.isFound(.bee))
        #expect(d.lifetimeBugs == 150)
        #expect(d.lessonDone)
        // A second run adds counts but no new pages.
        let o2 = record(makeRun(score: 2_000, bugs: 10, caught: ["housefly": 10]), &d, earn: firstFeast)
        #expect(o2.newSpecies.isEmpty)
        #expect(o2.showsNewBest)
        #expect(o2.newAchievements.isEmpty)
        #expect(d.caughtCount(.housefly) == 110)
    }

    @Test func attractAndLessonAreIgnored() {
        var d = ProgressData()
        let o = record(makeRun(mode: .attract), &d)
        #expect(o.ignored)
        #expect(d.runs == 0)
        #expect(!ProgressRules.worthRecording(makeRun(mode: .lesson)))
    }

    @Test func bestPerMode() {
        var d = ProgressData()
        d.bestFeed = 700
        d.daily[5] = DailyRecord(score: 300, finished: true, practiceBest: 450)
        #expect(ProgressRules.best(for: .feed, in: d) == 700)
        #expect(ProgressRules.best(for: .daily(day: 5, scored: false), in: d) == 450)
        #expect(ProgressRules.best(for: .attract, in: d) == 0)
    }

    @Test func rankProgressIsAFraction() {
        let p = ProgressRules.rankProgress(lifetime: 150, rank: 1, threshold: { $0 * 100 }, count: 12)
        #expect(abs(p - 0.5) < 1e-9)
        #expect(ProgressRules.rankProgress(lifetime: 5_000, rank: 11, threshold: { $0 * 100 }, count: 12) == 1)
    }
}

// MARK: - Demo mode

#if DEBUG
struct DemoTests {
    @Test func parsesEveryKey() {
        let d = DemoMode.parse("screen=play;mode=daily;seed=42;pilot=expert;progress=mid;freezeOn=lastSnap;"
                               + "freezeAfter=3.5;closure=14;wave=23;lessonStep=4;hudLeft=1;fold=1;sound=0")
        #expect(d.screen == .play)
        #expect(d.mode == .daily)
        #expect(d.seed == 42)
        #expect(d.pilot == .expert)
        #expect(d.progress == .mid)
        #expect(d.freezeOn == .lastSnap)
        #expect(d.holdAfter == 3.5)
        #expect(d.closure == 14)
        #expect(d.wave == 23)
        #expect(d.lessonStep == 4)
        #expect(d.hudLeft == true)
        #expect(d.fold)
        #expect(!d.sound)
        #expect(d.runMode(today: 299) == .daily(day: 299, scored: true))
    }

    @Test func modeAloneImpliesPlay() {
        #expect(DemoMode.parse("mode=attract").effectiveScreen == .play)
        #expect(DemoMode.parse("").effectiveScreen == .home)
        #expect(DemoMode.parse("screen=bogus;mode=feed").screen == nil)
    }

    @Test func freezeTagsAndDelays() {
        #expect(DemoMode.Freeze.snap.isEvent)
        #expect(!DemoMode.Freeze.crowd.isEvent)
        #expect(abs(DemoMode.Freeze.snap.holdDelay - 0.12) < 1e-9)
        #expect(DemoMode.parse("freezeOn=CROWD").freezeOn == .crowd)
        #expect(DemoMode.parse("lessonStep=99").lessonStep == LessonScript.Step.done.rawValue)
    }

    @Test func presetsAgree() {
        let mid = DemoPresets.progress(.mid, today: 299)
        #expect(PlantRanks.rank(forLifetimeBugs: mid.lifetimeBugs) == 4)
        #expect(mid.speciesFound == 9)
        #expect(mid.bestFeed == 3_200)
        #expect(mid.caught.values.reduce(0, +) <= mid.lifetimeBugs)
        let late = DemoPresets.progress(.late, today: 299)
        #expect(PlantRanks.rank(forLifetimeBugs: late.lifetimeBugs) == 10)
        #expect(late.speciesFound == 16)
        #expect(late.bestFeed == 14_800)
        #expect(!ProgressRules.canPlayScoredDaily(late, today: 298))
        #expect(ProgressRules.canPlayScoredDaily(late, today: 299))
        #expect(DemoPresets.progress(.fresh, today: 299) == ProgressData())
    }
}
#endif

// MARK: - Poses, fold and orientation

struct PoseRuleTests {
    @Test func poses() {
        #expect(AppRules.pose(canvas: CGSize(width: 951, height: 669), hingeSeen: true, isShut: false) == .play)
        #expect(AppRules.pose(canvas: CGSize(width: 669, height: 951), hingeSeen: true, isShut: false) == .pose)
        #expect(AppRules.pose(canvas: CGSize(width: 466, height: 678), hingeSeen: true, isShut: false) == .cover)
        #expect(AppRules.pose(canvas: CGSize(width: 951, height: 669), hingeSeen: true, isShut: true) == .play)
        #expect(AppRules.pose(canvas: CGSize(width: 844, height: 390), hingeSeen: false, isShut: false) == .play)
        #expect(AppRules.pose(canvas: CGSize(width: 390, height: 844), hingeSeen: false, isShut: false) == .pose)
    }

    @Test func fold() {
        #expect(AppRules.hasFold(canvas: CGSize(width: 951, height: 669), hingeSeen: false, demoFold: false,
                                 divisionSeen: false))
        #expect(!AppRules.hasFold(canvas: CGSize(width: 844, height: 390), hingeSeen: false, demoFold: false,
                                  divisionSeen: false))
        #expect(AppRules.hasFold(canvas: CGSize(width: 844, height: 390), hingeSeen: false, demoFold: true,
                                 divisionSeen: false))
        #expect(!AppRules.hasFold(canvas: CGSize(width: 669, height: 951), hingeSeen: true, demoFold: true,
                                  divisionSeen: false))
    }

    @Test func orientationMasks() {
        #expect(OrientationLock.mask(hasHinge: false, screen: CGSize(width: 390, height: 844)) == .landscape)
        #expect(OrientationLock.mask(hasHinge: false, screen: CGSize(width: 669, height: 951)) == .allButUpsideDown)
        #expect(OrientationLock.mask(hasHinge: true, screen: CGSize(width: 390, height: 844)) == .allButUpsideDown)
        #expect(!OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 390, height: 844)))
        #expect(OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 669, height: 951)))
    }

    @Test func closingPauseResumesWellAboveNinety() {
        #expect(AppRules.resumeAngle > 100)
        #expect(!AppRules.mayResume(angle: 95, isClosing: false, isShut: false))
        #expect(AppRules.mayResume(angle: 150, isClosing: false, isShut: false))
        #expect(!AppRules.mayResume(angle: 150, isClosing: true, isShut: false))
        #expect(!AppRules.mayResume(angle: nil, isClosing: false, isShut: false))
    }

    @Test func stepClamp() {
        #expect(AppRules.clampStep(1.0) == AppRules.maxStep)
        #expect(AppRules.clampStep(-1) == 0)
        #expect(AppRules.clampStep(.nan) == 0)
        #expect(abs(AppRules.clampStep(1.0 / 120.0) - 1.0 / 120.0) < 1e-12)
    }
}

// MARK: - The First Bite

struct LessonTests {
    @Test func poseStepNeedsTheBookHold() {
        var s = LessonScript(start: .pose)
        _ = s.update(LessonScript.Input(time: 0, angle: 178, hasHinge: true))
        _ = s.update(LessonScript.Input(time: 1, angle: 178, hasHinge: true))
        #expect(s.step == .pose)
        #expect(s.praise == nil)
        _ = s.update(LessonScript.Input(time: 1.1, angle: 150, hasHinge: true))
        _ = s.update(LessonScript.Input(time: 1.5, angle: 152, hasHinge: true))
        #expect(s.praise == nil)
        _ = s.update(LessonScript.Input(time: 1.8, angle: 151, hasHinge: true))
        #expect(s.praise != nil)
        let spawned = s.update(LessonScript.Input(time: 3.2, angle: 151, hasHinge: true))
        #expect(s.step == .firstSnap)
        #expect(spawned == [.spawn(.housefly, slot: 0, linger: .infinity)])
    }

    @Test func noHingeSkipsThePose() {
        var s = LessonScript(start: .pose)
        let actions = s.update(LessonScript.Input(time: 0, hasHinge: false))
        #expect(s.step == .firstSnap)
        #expect(actions.count == 1)
        #expect(s.display(touch: true).line.contains("tap"))
    }

    @Test func firstSnapPassesOnACatch() {
        var s = LessonScript(start: .firstSnap)
        _ = s.update(LessonScript.Input(time: 0, hasHinge: true, liveFlies: 1))
        let caught: [TrapEvent] = [.snapped(report(caught: [.housefly])),
                                   .bugCaught(id: 1, species: .housefly, position: .zero)]
        _ = s.update(LessonScript.Input(time: 2, hasHinge: true, events: caught, liveFlies: 0))
        #expect(s.praise == "CHOMP!")
        _ = s.update(LessonScript.Input(time: 3.4, hasHinge: true, armed: false))
        #expect(s.step == .openAgain)
        #expect(s.allowsSkip)
    }

    @Test func aMissBringsAnotherFly() {
        var s = LessonScript(start: .firstSnap)
        _ = s.update(LessonScript.Input(time: 0, hasHinge: true, liveFlies: 1))
        let miss: [TrapEvent] = [.snapped(report(caught: [])), .bugEscaped(id: 1, species: .housefly)]
        _ = s.update(LessonScript.Input(time: 2, hasHinge: true, events: miss, liveFlies: 0))
        #expect(s.warning != nil)
        #expect(s.step == .firstSnap)
        let again = s.update(LessonScript.Input(time: 3.3, hasHinge: true, liveFlies: 0))
        #expect(again == [.spawn(.housefly, slot: 0, linger: .infinity)])
    }

    @Test func eatingTheBeeRepeatsTheStep() {
        var s = LessonScript(start: .bee)
        let first = s.update(LessonScript.Input(time: 0, hasHinge: true))
        #expect(first == [.spawn(.bee, slot: 0, linger: LessonScript.beeLinger)])
        let sting: [TrapEvent] = [.snapped(report(caught: [], stingers: [.bee])),
                                  .stung(id: 1, species: .bee, cost: 0)]
        _ = s.update(LessonScript.Input(time: 2, hasHinge: true, events: sting, liveBees: 0))
        #expect(s.warning != nil)
        // The bitten bee's leaving is not a spare.
        _ = s.update(LessonScript.Input(time: 2.5, hasHinge: true, events: [.beeSpared(species: .bee)], liveBees: 0))
        #expect(s.praise == nil)
        let again = s.update(LessonScript.Input(time: 4.5, hasHinge: true, liveBees: 0))
        #expect(again == [.spawn(.bee, slot: 0, linger: LessonScript.beeLinger)])
        _ = s.update(LessonScript.Input(time: 9, hasHinge: true, events: [.beeSpared(species: .bee)], liveBees: 0))
        #expect(s.praise != nil)
    }

    @Test func tripleNeedsThree() {
        var s = LessonScript(start: .triple)
        let cast = s.update(LessonScript.Input(time: 0, hasHinge: true))
        #expect(cast.count == 3)
        _ = s.update(LessonScript.Input(time: 3, hasHinge: true,
                                        events: [.snapped(report(caught: [.housefly, .housefly]))], liveFlies: 0))
        #expect(s.praise == nil)
        #expect(s.warning != nil)
        _ = s.update(LessonScript.Input(time: 8, hasHinge: true,
                                        events: [.snapped(report(caught: [.housefly, .housefly, .housefly]))],
                                        liveFlies: 0))
        #expect(s.praise == "TRIPLE ×3!")
        _ = s.update(LessonScript.Input(time: 9.5, hasHinge: true))
        #expect(s.step == .done)
        #expect(s.display(touch: false).isFinal)
    }

    @Test func linesAreShort() {
        for step in LessonScript.Step.allCases {
            for touch in [false, true] {
                let words = LessonScript.line(step, touch: touch).split(separator: " ").count
                #expect(words <= 8)
            }
        }
    }

    @Test func lessonSpotsAreInsideTheTrap() {
        let g = ScreenLayout(hasFold: true).geometry
        for slot in 0..<LessonScript.Step.allCases.count {
            let spot = AppRules.lessonSpot(slot: slot, geometry: g)
            #expect(g.contains(spot.target))
            #expect(spot.entry.y > g.sceneSize.height)
        }
    }
}

// MARK: - Words and logs

@MainActor
struct WordsTests {
    @Test func hintsAreShort() {
        let all: [TrapHint] = [.bendALittle, .quick, .openUp, .beeInside, .crowd, .lastSnap]
        for hint in all {
            for touch in [false, true] {
                guard let text = AppRules.hintText(hint, touch: touch) else { continue }
                let words = text.split(separator: " ").filter { $0 != "—" }.count
                #expect(words <= 6)
            }
        }
        #expect(AppRules.hintText(.quick, touch: true) == nil)
        #expect(AppRules.hintText(.beeInside, touch: true) != nil)
    }

    @Test func numbers() {
        #expect(AppRules.formatted(12_450) == "12,450")
        #expect(AppRules.multiplierText(1.5) == "×1.5")
        #expect(AppRules.multiplierText(2) == "×2")
        #expect(AppRules.biteName(1) == nil)
        #expect(AppRules.biteName(3) == "Triple ×3")
        #expect(AppRules.biteName(6) == "FEAST ×6")
    }

    @Test func dailyDates() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        #expect(AppRules.dailyDate(day: 299, calendar: cal) == "27 Oct")
        #expect(AppRules.dailyDate(day: 0, calendar: cal) == "1 Jan")
    }

    @Test func storyNamesTheBestMoment() {
        #expect(AppRules.story(makeRun(biggest: 5)).contains("FEAST"))
        #expect(AppRules.story(makeRun(caught: ["goldenScarab": 1], biggest: 2)).contains("Golden Scarab"))
        #expect(AppRules.story(makeRun(bugs: 0, caught: [:], biggest: 0, chain: 0)).contains("nibble"))
    }

    @Test func nearMiss() {
        #expect(AppRules.nearMiss(score: 900, best: 1_000, newBest: false) == "100 short of your best")
        #expect(AppRules.nearMiss(score: 100, best: 1_000, newBest: false) == nil)
        #expect(AppRules.nearMiss(score: 1_200, best: 1_200, newBest: true) == nil)
    }

    @Test func againPractisesTheDaily() {
        #expect(AppRules.againMode(.daily(day: 3, scored: true)) == .daily(day: 3, scored: false))
        #expect(AppRules.againMode(.feed) == .feed)
    }

    @Test func trapLogLine() {
        let input = TrapInput(closure: 12.34, armed: true, creeping: false, snap: nil, tooFlat: false, angle: 150)
        #expect(AppTrace.trapLine(input, reference: AppTrace.reference(input))
                == "SNAP-T trap closure 12.3 armed 1 creep 0 angle 150.0 ref 162.3")
        let touch = TrapInput(closure: 0, armed: false, creeping: true)
        #expect(AppTrace.trapLine(touch, reference: AppTrace.reference(touch))
                == "SNAP-T trap closure 0.0 armed 0 creep 1 angle - ref -")
    }

    @Test func eventLines() {
        let bite = BiteReport(caught: [.housefly, .gnat], escaped: 1, stingers: [], points: 26, countMultiplier: 2,
                              chainMultiplier: 1, snapsBack: 0, snapsLost: 0, duration: 0.1234, time: 3)
        #expect(AppTrace.describe(.snapped(bite)) == "snapped caught=2 escaped=1 stingers=0 points=26 d=0.123")
        #expect(AppTrace.describe(.rearmed) == "rearmed")
        #expect(AppTrace.describe(.waveStarted(index: 3, phase: .dusk)) == "waveStarted index=3 phase=dusk")
        #expect(AppTrace.describe(.beeSpared(species: .bumblebee)) == "beeSpared species=bumblebee")
    }

    @Test func cardCopy() {
        #expect(PoseCard.title(isDuo: true) == "Hold it open like a book")
        #expect(CoverCard.title(midRun: true) == "Open to carry on")
        #expect(ClosingCard.title == "Open it a little to carry on")
        #expect(DailyView.status(canPlay: true, record: nil).contains("One scored try"))
        var d = ProgressData()
        d.spared = ["bee": 4]
        #expect(BugBookCard.countLine(.bee, data: d) == "Spared 4")
        #expect(BugBookCard.countLine(.housefly, data: d) == "Caught 0")
    }
}

// MARK: - Game Center

@MainActor
struct GameCenterTests {
    @Test func ids() {
        #expect(GameCenterManager.gameCenterID("feast") == "snap.ach.feast")
        #expect(GameCenterManager.gameCenterID("snap.ach.feast") == "snap.ach.feast")
    }

    @Test func queueKeepsOneDailyPerDay() {
        let a = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 100, day: 5, token: "a")
        let b = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 300, day: 5, token: "b")
        let c = GameCenterManager.encode(leaderboard: GameCenterManager.Leaderboard.daily, score: 200, day: 5, token: "c")
        var q = GameCenterManager.enqueue(a, into: [])
        q = GameCenterManager.enqueue(b, into: q)
        q = GameCenterManager.enqueue(c, into: q)
        #expect(q == [b])
        let parsed = GameCenterManager.parse(b)
        #expect(parsed?.score == 300)
        #expect(parsed?.day == 5)
        if let parsed {
            #expect(GameCenterManager.isStale(parsed, today: 6))
            #expect(!GameCenterManager.isStale(parsed, today: 5))
        }
    }
}

// MARK: - Layout

@MainActor
struct LayoutTests {
    private func duo(hudLeft: Bool = false) -> AppCanvas {
        let size = CGSize(width: 951, height: 669)
        return AppCanvas(size: size, insets: EdgeInsets(),
                         layout: ScreenLayout.make(viewSize: size, hasFold: true, hudOnLeft: hudLeft))
    }

    @Test func sceneMapsOntoTheScreen() {
        let c = duo()
        let mid = c.screenPoint(CGPoint(x: 476, y: 335))
        #expect(near(mid.x, 475.5))
        #expect(near(mid.y, 334.5))
        let top = c.screenPoint(CGPoint(x: 0, y: 670))
        #expect(near(top.y, 0))
        #expect(c.foldMinX < c.foldMaxX)
        #expect(c.leftPage.maxX <= c.foldMinX)
        #expect(c.rightPage.minX >= c.foldMaxX)
    }

    @Test func hudSitsOnTheSharpHalf() {
        let c = duo()
        let l = HUDLayout.make(c)
        #expect(l.trailing)
        #expect(l.pause.width >= AppCanvas.minTap)
        #expect(c.isFoldClear(l.pause))
        #expect(l.pause.minX >= c.foldMaxX)
        #expect(l.snaps.minX >= c.foldMaxX - tolerance)
        #expect(l.score.maxX <= l.pause.minX)
        #expect(l.hint.maxY <= l.snaps.minY)
    }

    @Test func hudOnTheLeftMirrors() {
        let c = duo(hudLeft: true)
        let l = HUDLayout.make(c)
        #expect(!l.trailing)
        #expect(l.pause.maxX <= c.foldMinX)
        #expect(c.isFoldClear(l.pause))
        #expect(l.score.minX >= l.pause.maxX)
    }

    @Test func phoneCanvasIsWider() {
        let size = CGSize(width: 844, height: 390)
        let c = AppCanvas(size: size, insets: EdgeInsets(top: 0, leading: 47, bottom: 21, trailing: 47),
                          layout: ScreenLayout.make(viewSize: size, hasFold: false))
        #expect(c.layout.size.width > ScreenLayout.canvasWidth)
        #expect(c.isCompact)
        let l = HUDLayout.make(c)
        #expect(l.pause.maxX <= size.width - 47)
        #expect(l.snaps.maxY <= size.height - 21)
    }

    @Test func snapsRowSlots() {
        #expect(SnapsRow.slots(left: 3, max: 12) == Tuning.startSnaps)
        #expect(SnapsRow.slots(left: 12, max: 12) == 12)
    }
}

// MARK: - Run tally and telemetry

struct TallyTests {
    @Test func tallyBuildsAPartialResult() {
        var t = RunTally(hingeTiming: true)
        t.note(.snapped(report(caught: [.housefly, .gnat], duration: 0.11)))
        t.note(.bugCaught(id: 1, species: .housefly, position: .zero))
        t.note(.bugCaught(id: 2, species: .gnat, position: .zero))
        t.note(.beeSpared(species: .bee))
        t.note(.chainUp(count: 3, multiplier: 2))
        t.note(.stung(id: 3, species: .wasp, cost: 2))
        let snap = TrapSnapshot(mode: .feed, time: 40, score: 320, chain: 1, wave: 7, bugsCaught: 2, beesSpared: 1)
        let r = t.result(mode: .feed, seed: 9, snapshot: snap)
        #expect(r.snaps == 1)
        #expect(r.score == 320)
        #expect(r.caughtBySpecies == ["housefly": 1, "gnat": 1])
        #expect(r.sparedBySpecies == ["bee": 1])
        #expect(r.longestChain == 3)
        #expect(r.stings == 1)
        #expect(r.biggestBite == 2)
        #expect(abs(r.fastestSnap - 0.11) < 1e-9)
        #expect(ProgressRules.worthRecording(r))
    }

    @Test func buzzersPanAndSkipCaughtBugs() {
        let bugs = [
            BugState(id: 1, species: .housefly, position: CGPoint(x: 0, y: 300), heading: 0, activity: .arriving,
                     height: 0.8, inTrap: false, onRim: false),
            BugState(id: 2, species: .bee, position: CGPoint(x: 952, y: 300), heading: 0, activity: .sipping,
                     height: 0, inTrap: true, onRim: false),
            BugState(id: 3, species: .gnat, position: CGPoint(x: 476, y: 300), heading: 0,
                     activity: .caught(elapsed: 0.1), height: 0, inTrap: true, onRim: false),
        ]
        let s = TrapSnapshot(bugs: bugs)
        let b = AppRules.buzzers(s, sceneWidth: 952)
        #expect(b.count == 2)
        #expect(abs(b[0].pan + 1) < 1e-9)
        #expect(b[0].flying)
        #expect(abs(b[1].pan - 1) < 1e-9)
        #expect(!b[1].flying)
    }

    @Test func freezeMatching() {
        let sipping = BugState(id: 1, species: .bee, position: CGPoint(x: 400, y: 300), heading: 0, activity: .sipping,
                               height: 0, inTrap: true, onRim: false)
        let s = TrapSnapshot(bugs: [sipping], dayPhase: .night)
        #expect(GameController.matches(.bee, s, events: []))
        #expect(GameController.matches(.landed, s, events: []))
        #expect(!GameController.matches(.crowd, s, events: []))
        #expect(GameController.matches(.dusk, s, events: []))
        #expect(GameController.matches(.lastSnap, s, events: [.lastSnap]))
        #expect(!GameController.matches(.results, s, events: []))
    }
}

// MARK: - The icon's PNG

struct PNGTests {
    @Test func writesRGBWithoutAlpha() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let ctx = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                                         space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.3, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let image = try #require(ctx.makeImage())
        let png = try #require(SnapPNG.encode(image))
        #expect(SnapPNG.colorType(png) == 2)
        #expect(UIImage(data: png) != nil)
    }
}
