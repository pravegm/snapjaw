import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Snap

// App engineer tests: progress/settings round-trip, tolerant decoding, migration and the corrupt-save backup; the
// Daily one-scored-try rule; recording a run (Bug Book, rank, achievements) and an abandoned one; demo parsing and the
// seeded profiles; the pose, fold and orientation rules; the First Bite's step gating; the HUD's words and log
// formats; Game Center queue rules; the canvas and HUD layout maths; the run tally; the opaque PNG writer. R8: the
// portrait Duo (no pose card, the scene turned a quarter, the portrait HUD and menus: PortraitTests).

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

private func report(caught: [BugSpecies], stingers: [BugSpecies] = [], duration: Double = 0.1,
                    escaped: Int = 0) -> BiteReport {
    BiteReport(caught: caught, escaped: escaped, stingers: stingers, points: 10 * caught.count,
               countMultiplier: caught.count,
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
                               + "freezeAfter=3.5;closure=14;wave=23;level=12;chomp=sting;hudLeft=1;fold=1;sound=0")
        #expect(d.screen == .play)
        #expect(d.mode == .daily)
        #expect(d.seed == 42)
        #expect(d.pilot == .expert)
        #expect(d.progress == .mid)
        #expect(d.freezeOn == .lastSnap)
        #expect(d.holdAfter == 3.5)
        #expect(d.closure == 14)
        #expect(d.wave == 23)
        #expect(d.level == 12)
        #expect(d.chomp == .sting)
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
        #expect(DemoMode.parse("level=99").level == 30)
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
        // REVIEW-2 #19: the Bug Book's counts vary (not "Caught 27" on every page) and add up to the lifetime.
        #expect(Set(late.caught.values).count > 6)
        #expect(late.caught.values.reduce(0, +) == late.lifetimeBugs)
        #expect(Set(mid.caught.values).count > 3)
    }

    @Test @MainActor func badgesScreen() {
        #expect(DemoMode.parse("screen=badges").screen == .badges)
        // One image per Game Center achievement, named by its id.
        #expect(GameCenterManager.achievementIDs.count == 12)
        #expect(Set(GameCenterManager.achievementIDs).count == 12)
        #expect(GameCenterManager.achievementIDs == Achievements.all.map(\.id))
        #expect(BadgeExport.side == 1024)
    }
}
#endif

// MARK: - Poses, fold and orientation

struct PoseRuleTests {
    @Test func poses() {
        #expect(AppRules.pose(canvas: CGSize(width: 951, height: 669), hingeSeen: true, isShut: false) == .play)
        // R8 (founder rule: no pose demands, ever): portrait plays (the scene turned a quarter).
        #expect(AppRules.pose(canvas: CGSize(width: 669, height: 951), hingeSeen: true, isShut: false) == .play)
        #expect(AppRules.pose(canvas: CGSize(width: 466, height: 678), hingeSeen: true, isShut: false) == .cover)
        #expect(AppRules.pose(canvas: CGSize(width: 951, height: 669), hingeSeen: true, isShut: true) == .play)
        #expect(AppRules.pose(canvas: CGSize(width: 844, height: 390), hingeSeen: false, isShut: false) == .play)
        #expect(AppRules.pose(canvas: CGSize(width: 390, height: 844), hingeSeen: false, isShut: false) == .play)
    }

    @Test func fold() {
        #expect(AppRules.hasFold(canvas: CGSize(width: 951, height: 669), hingeSeen: false, demoFold: false,
                                 divisionSeen: false))
        #expect(!AppRules.hasFold(canvas: CGSize(width: 844, height: 390), hingeSeen: false, demoFold: false,
                                  divisionSeen: false))
        #expect(AppRules.hasFold(canvas: CGSize(width: 844, height: 390), hingeSeen: false, demoFold: true,
                                 divisionSeen: false))
        // R8 portrait: the laptop fold runs across the turned scene's midrib.
        #expect(AppRules.hasFold(canvas: CGSize(width: 669, height: 951), hingeSeen: true, demoFold: false,
                                 divisionSeen: false))
        #expect(AppRules.hasFold(canvas: CGSize(width: 669, height: 951), hingeSeen: false, demoFold: false,
                                 divisionSeen: false))
        #expect(!AppRules.hasFold(canvas: CGSize(width: 390, height: 844), hingeSeen: false, demoFold: false,
                                  divisionSeen: false))
    }

    @Test func orientationMasks() {
        #expect(OrientationLock.mask(hasHinge: false, screen: CGSize(width: 390, height: 844)) == .landscape)
        #expect(OrientationLock.mask(hasHinge: false, screen: CGSize(width: 669, height: 951)) == .allButUpsideDown)
        #expect(OrientationLock.mask(hasHinge: true, screen: CGSize(width: 390, height: 844)) == .allButUpsideDown)
        #expect(!OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 390, height: 844)))
        #expect(OrientationLock.trustsStoredHinge(true, screen: CGSize(width: 669, height: 951)))
    }

    /// R8 (ROUND-8 §1): closed is not a pause; while the Duo is shut (no scene frames) the hinge's reports step a live
    /// hinge run, never one under the pause menu.
    @Test func aShutDuoStepsFromTheHinge() {
        #expect(AppRules.stepsFromHinge(sinceSceneFrame: 0.5, liveHingeRun: true, menuOpen: false))
        #expect(!AppRules.stepsFromHinge(sinceSceneFrame: 0.01, liveHingeRun: true, menuOpen: false))
        #expect(!AppRules.stepsFromHinge(sinceSceneFrame: 0.5, liveHingeRun: false, menuOpen: false))
        #expect(!AppRules.stepsFromHinge(sinceSceneFrame: 0.5, liveHingeRun: true, menuOpen: true))
        #expect(AppRules.stepsFromHinge(sinceSceneFrame: .infinity, liveHingeRun: true, menuOpen: false))
        #expect(!AppRules.stepsFromHinge(sinceSceneFrame: .nan, liveHingeRun: true, menuOpen: false))
    }

    @Test func stepClamp() {
        #expect(AppRules.clampStep(1.0) == AppRules.maxStep)
        #expect(AppRules.clampStep(-1) == 0)
        #expect(AppRules.clampStep(.nan) == 0)
        #expect(abs(AppRules.clampStep(1.0 / 120.0) - 1.0 / 120.0) < 1e-12)
    }
}

// MARK: - Words and logs

@MainActor
struct WordsTests {
    @Test func hintsAreShort() {
        let all: [TrapHint] = [.bendALittle, .quick, .openUp, .beeInside, .crowd, .lastSnap, .hungry]
        for hint in all {
            for touch in [false, true] {
                guard let text = AppRules.hintText(hint, touch: touch) else { continue }
                let words = text.split(separator: " ").filter { $0 != "—" }.count
                #expect(words <= 6)
            }
        }
        #expect(AppRules.hintText(.quick, touch: true) == nil)
        #expect(AppRules.hintText(.beeInside, touch: true) != nil)
        // Core's hints and the fold line are ≤ 6 words; the App's two-sentence toasts (set a size smaller) ≤ 8.
        for line in AppRules.allHintLines {
            let words = line.text.split(separator: " ").count
            #expect(words <= (line.long ? 8 : 6))
        }
    }

    /// ROUND-3 founder call: the fold is the input on a Duo; phones keep the tap. R8: "phone", "close".
    @Test func foldInputWords() {
        #expect(AppRules.hudHintText(.foldInput, touch: false) == "Close the phone to bite")
        #expect(AppRules.hudHintText(.foldInput, touch: true) == "Tap to snap")
        // REVIEW-3 #3: the founder's copy, good news on the cream plate.
        #expect(AppRules.hudHintText(.beesCost, touch: true) == "Bees and wasps cost snaps. This one's free!")
        #expect(!AppRules.hudHintIsWarning(.beesCost))
        #expect(AppRules.hudHintIsLong(.beesCost))
        // R6 (#14): the one-time chain explainer.
        #expect(AppRules.hudHintText(.chainTag(1.5), touch: false) == "Chain ×1.5! Big bites in a row multiply.")
        #expect(AppRules.allHintCopy.contains(AppRules.freeStingCopy))
        #expect(!AppRules.hudHintIsWarning(.foldInput))
        #expect(AppRules.hudHintText(.trap(.crowd), touch: false) == "Now! Close it!")
        #expect(AppRules.hudHintText(.trap(.crowd), touch: true) == "Now! Tap!")
        #expect(AppRules.allHintCopy.contains("Close the phone to bite"))
        #expect(AppRules.allHintCopy.contains("Tap to snap"))
        #expect(AppRules.hintText(.lastSnap, touch: false) == "Last snap!")
        #expect(HomeView.foldCaption == "Close the phone to bite")
        // Founder rule 4: "phone", never "lid".
        for line in AppRules.allHintCopy { #expect(!line.lowercased().contains("lid")) }
    }

    @Test func foldHintShowsOnTheFirstWaveOnly() {
        #expect(AppRules.showsFoldHint(mode: .feed, wave: 1, snapsMade: 0, time: 3, after: 2.6, coreHint: nil))
        #expect(AppRules.showsFoldHint(mode: .daily(day: 3, scored: true), wave: 0, snapsMade: 0, time: 3, after: 2.6,
                                       coreHint: nil))
        // REVIEW-3 #9 (frame 10 was wave 2 with no plate): the first two waves, within the window.
        #expect(AppRules.showsFoldHint(mode: .feed, wave: 2, snapsMade: 0, time: 9, after: 2.6, coreHint: nil))
        #expect(!AppRules.showsFoldHint(mode: .feed, wave: 2, snapsMade: 0, time: 2.6 + AppRules.foldHintWindow + 1,
                                        after: 2.6, coreHint: nil))
        // Not over the run-start line, not after the first snap, not past wave 2, never over Core's hints.
        #expect(!AppRules.showsFoldHint(mode: .feed, wave: 1, snapsMade: 0, time: 1, after: 2.6, coreHint: nil))
        #expect(!AppRules.showsFoldHint(mode: .feed, wave: 1, snapsMade: 1, time: 3, after: 2.6, coreHint: nil))
        #expect(!AppRules.showsFoldHint(mode: .feed, wave: 3, snapsMade: 0, time: 3, after: 2.6, coreHint: nil))
        #expect(!AppRules.showsFoldHint(mode: .feed, wave: 1, snapsMade: 0, time: 3, after: 2.6, coreHint: .crowd))
        #expect(!AppRules.showsFoldHint(mode: .lesson, wave: 1, snapsMade: 0, time: 3, after: 2.6, coreHint: nil))
        #expect(!AppRules.showsFoldHint(mode: .attract, wave: 1, snapsMade: 0, time: 3, after: 2.6, coreHint: nil))
        #expect(!AppRules.showsFoldHint(mode: .level(1), wave: 1, snapsMade: 0, time: 3, after: 2.6, coreHint: nil))
    }

    /// REVIEW-2 #9: Sprout's first Feed run never wilts and its first bee is free, with the toast.
    @Test func sproutFirstRun() {
        #expect(AppRules.isSproutFirstRun(mode: .feed, feedRuns: 0))
        #expect(!AppRules.isSproutFirstRun(mode: .feed, feedRuns: 1))
        #expect(!AppRules.isSproutFirstRun(mode: .daily(day: 3, scored: true), feedRuns: 0))
        #expect(!AppRules.isSproutFirstRun(mode: .lesson, feedRuns: 0))
        var options = SessionOptions()
        GameController.applyFirstRun(true, to: &options)
        #expect(!options.hunger)
        #expect(options.freeFirstSting)
        #expect(options.firstRun)
        // R4 (founder call): run 1 starts full, at 14.
        #expect(options.startSnaps == AppRules.firstRunSnaps)
        #expect(AppRules.firstRunSnaps == 14)
        var normal = SessionOptions()
        GameController.applyFirstRun(false, to: &normal)
        #expect(normal == SessionOptions())
        #expect(AppRules.isFreeSting(.stung(id: 1, species: .bee, cost: 0), mode: .feed))
        #expect(!AppRules.isFreeSting(.stung(id: 1, species: .bee, cost: 1), mode: .feed))
        #expect(!AppRules.isFreeSting(.stung(id: 1, species: .bee, cost: 0), mode: .lesson))
        #expect(!AppRules.isFreeSting(.drySnap, mode: .feed))
        #expect(AppRules.snapGainText(1) == "+1 snap")
        #expect(AppRules.snapGainText(2) == "+2 snaps")
    }

    /// The snaps numeral's tick (R8 portrait: the clap diagram it once shared this test with is gone with the pose card).
    @Test func clapAngles() {
        #expect(SnapsRow.tick(at: 10.0) > 1.2)
        #expect(abs(SnapsRow.tick(at: 10.5) - 1) < 1e-9)
    }

    @Test func numbers() {
        #expect(AppRules.formatted(12_450) == "12,450")
        #expect(AppRules.multiplierText(1.5) == "×1.5")
        #expect(AppRules.multiplierText(2) == "×2")
        #expect(AppRules.biteName(1) == nil)
        // R7 (#3): "×" is only ever the chain.
        #expect(AppRules.biteName(3) == "Triple")
        #expect(AppRules.biteName(6) == "FEAST")
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
        #expect(AppTrace.describe(.hungry(secondsLeft: 3)) == "hungry secondsLeft=3.0")
        #expect(AppTrace.describe(.wilted(snapsLeft: 7)) == "wilted snapsLeft=7")
    }

    @Test func hungerWords() {
        #expect(AppRules.hintText(.hungry, touch: false) == "Hungry! Bite soon")
        #expect(AppRules.hintText(.hungry, touch: true) == "Hungry! Bite soon")
        #expect(AppRules.hintIsWarning(.hungry))
        #expect(AppRules.hudHunger(0.51, live: true) == 0.5)
        #expect(AppRules.hudHunger(2, live: true) == 1)
        #expect(AppRules.hudHunger(0.7, live: false) == 0)
        #expect(AppRules.hudHunger(.nan, live: true) == 0)
    }

    @Test func resultsWords() {
        #expect(AppRules.bestBiteText(bugs: 4, points: 48) == "4 bugs · 48")
        #expect(AppRules.bestBiteText(bugs: 1, points: 10) == "1 bug · 10")
        #expect(AppRules.bestBiteText(bugs: 0, points: 0) == "–")
        #expect(AppRules.chainText(longest: 0) == "–")
        #expect(AppRules.chainText(longest: 1) == AppRules.multiplierText(TrapRules.chainMultiplier(1)) + " · 1 big bite")
        #expect(AppRules.chainText(longest: 2).hasPrefix(AppRules.multiplierText(TrapRules.chainMultiplier(2))))
        #expect(AppRules.chainText(longest: 2).hasSuffix("· 2 big bites"))
        // REVIEW-2 #24: "An 8-bug FEAST", "New best! was 3,200".
        #expect(AppRules.article(8) == "An")
        #expect(AppRules.article(11) == "An")
        #expect(AppRules.article(5) == "A")
        #expect(AppRules.story(makeRun(biggest: 8)).hasPrefix("An 8-bug FEAST"))
        #expect(AppRules.story(makeRun(biggest: 6)).hasPrefix("A 6-bug FEAST"))
        #expect(AppRules.previousBestText(3_200) == "was 3,200")
        #expect(AppRules.previousBestText(0) == nil)
        #expect(AppRules.shortName(.goldenScarab) == "Scarab")
        #expect(AppRules.shortName(.housefly) == "Housefly")
        #expect(AppRules.rankHint(lifetimeBugs: 0) == "Catch \(PlantRanks.threshold(1)) bugs to grow")
        #expect(AppRules.rankHint(lifetimeBugs: PlantRanks.threshold(1) - 1).hasPrefix("1 more bug to"))
        #expect(ResultsView.tilesShown(count: 3, width: 360, tile: 62, gap: 8) == 3)
        #expect(ResultsView.tilesShown(count: 9, width: 360, tile: 62, gap: 8) == 4)
        #expect(ResultsView.tilesShown(count: 0, width: 360, tile: 62, gap: 8) == 0)
    }

    @Test func sproutStartsWithTwelve() {
        #expect(AppRules.startSnaps(mode: .feed, lifetimeBugs: 0) == 12)
        #expect(AppRules.startSnaps(mode: .feed, lifetimeBugs: PlantRanks.threshold(1) - 1) == 12)
        #expect(AppRules.startSnaps(mode: .feed, lifetimeBugs: PlantRanks.threshold(1)) == nil)
        #expect(AppRules.startSnaps(mode: .daily(day: 3, scored: true), lifetimeBugs: 0) == nil)
        #expect(AppRules.startSnaps(mode: .lesson, lifetimeBugs: 0) == nil)
    }

    @Test func cardCopy() {
        // R8 (founder rule 2): no pose demands (the pose card is gone: PortraitTests).
        #expect(CoverCard.title(midRun: true) == "Open to keep feeding")
        #expect(CoverCard.title(midRun: false) == "Open to play")
        #expect(CoverCard.openToStart == "Open to start")
        // R6 (#12): the number big, "score so far" under it.
        #expect(CoverCard.scoreLine(1_174) == "1,174")
        #expect(CoverCard.scoreCaption == "score so far")
        #expect(CoverCard.bestLine(3_200) == "Best score 3,200")
        // REVIEW-2 #20: no debug line in Settings, a hinge readout only on TestFlight with a hinge.
        #expect(!SettingsView.showsDiagnostics(channel: .debug, hasHinge: true))
        #expect(!SettingsView.showsDiagnostics(channel: .appStore, hasHinge: true))
        #expect(!SettingsView.showsDiagnostics(channel: .testFlight, hasHinge: false))
        #expect(SettingsView.showsDiagnostics(channel: .testFlight, hasHinge: true))
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
        // R3: the score in the top outer corner, the pause button under it; the hint on the inner top.
        #expect(l.pause.minY >= l.score.maxY)
        #expect(l.hint.maxY <= l.snaps.minY)
        #expect(l.hint.maxX <= l.score.minX)
        #expect(l.back.minY < l.pause.minY)
    }

    @Test func hudOnTheLeftMirrors() {
        let c = duo(hudLeft: true)
        let l = HUDLayout.make(c)
        #expect(!l.trailing)
        #expect(l.pause.maxX <= c.foldMinX)
        #expect(c.isFoldClear(l.pause))
        #expect(l.score.maxX <= c.foldMinX)
        #expect(l.pause.minY >= l.score.maxY)
        #expect(l.hint.minX >= l.score.maxX)
        let right = HUDLayout.make(duo())
        // Mirrored: the score hugs the left edge as it hugs the right one.
        #expect(abs(l.score.minX - (c.size.width - right.score.maxX)) < 2)
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

    /// REVIEW-2 #11, #23: every snap the trap can hold, in rows of seven; "14" never clips (REVIEW-1 #3).
    @Test func snapsRowSlots() {
        #expect(HUDLayout.slotCount == min(Tuning.maxSnaps, 14))
        #expect(HUDLayout.snapNumeralW >= 28)
        for c in [duo(), duo(hudLeft: true)] {
            let l = HUDLayout.make(c)
            #expect(l.snapRows == (HUDLayout.slotCount + 6) / 7)
            #expect(l.snapRowRects.count == l.snapRows)
            #expect(l.glyph >= HUDLayout.glyphMin)
            for i in 0..<HUDLayout.slotCount {
                let p = l.glyphCenter(i)
                let row = l.snapRowRects[min(i / 7, l.snapRowRects.count - 1)]
                #expect(row.insetBy(dx: -0.5, dy: -0.5).contains(p))
                #expect(!l.numeral.insetBy(dx: 1, dy: 1).contains(p))
            }
            #expect(l.snaps.contains(l.numeral))
            // QA-2 #6: the Scene's anchor is the glyph that changes (the last full one).
            #expect(l.anchor(snapsLeft: 10) == l.glyphCenter(9))
            #expect(l.anchor(snapsLeft: 1) == l.glyphCenter(0))
            #expect(l.snapRowRects[0].contains(l.anchor(snapsLeft: 0)))
        }
    }

    /// REVIEW-1 #14: at 951 × 669 (both HUD sides) the score, chain chip and snaps stay off the trap's face.
    @Test func hudStaysOffTheTrapOnTheDuo() {
        for left in [false, true] {
            let c = duo(hudLeft: left)
            let l = HUDLayout.make(c)
            for rect in l.ciliaRects {
                #expect(c.minTrapRadius(rect) >= HUDLayout.clearRadius - 0.005)
            }
            #expect(l.hint.width >= HUDLayout.hintMin)
            // The hint sits off the thumbs' band and the crease.
            #expect(!c.inThumbZone(l.hint))
            #expect(!c.inThumbZone(l.lessonHint))
        }
    }

    /// REVIEW-2 #4 (REVIEW-2-duo P0 4): at 951 × 669 on both HUD sides, the snaps rows, the numeral, the chain chip and
    /// the score are ≥ 8 pt clear of the cilia tips and the green back (the Scene's own `TrapArt.teeth`).
    @Test func hudClearsTheCiliaOnTheDuo() {
        for left in [false, true] {
            let c = duo(hudLeft: left)
            let outline = c.trapOutline()
            #expect(outline.count > 700)
            let l = HUDLayout.make(c)
            for rect in l.ciliaRects {
                #expect(AppCanvas.clearance(rect, from: outline) >= AppCanvas.ciliaClear)
            }
        }
    }

    @Test func outlineHelpers() {
        let pts = [CGPoint(x: 10, y: 10), CGPoint(x: 40, y: 12), CGPoint(x: 90, y: 50)]
        #expect(AppCanvas.outlineReach(pts, y0: 0, y1: 20, right: true) == 40)
        #expect(AppCanvas.outlineReach(pts, y0: 0, y1: 20, right: false) == 10)
        #expect(AppCanvas.outlineReach(pts, y0: 60, y1: 80, right: true) == nil)
        let r = CGRect(x: 50, y: 0, width: 10, height: 10)
        #expect(near(AppCanvas.clearance(r, from: [CGPoint(x: 70, y: 5)]), 10))
        #expect(AppCanvas.clearance(r, from: [CGPoint(x: 55, y: 5)]) == 0)
        #expect(near(AppCanvas.clearance(r, from: [CGPoint(x: 63, y: 14)]), 5))
    }

    /// REVIEW-2 #3: every hint line fits its plate (≤ 3 lines, no word cut) at both plate widths, on the Duo and on a
    /// phone, either HUD side, in play and in the lesson.
    @Test func everyHintFitsBothPlates() {
        let phone = CGSize(width: 874, height: 402)
        let canvases = [duo(), duo(hudLeft: true),
                        AppCanvas(size: phone, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62),
                                  layout: ScreenLayout.make(viewSize: phone, hasFold: false)),
                        AppCanvas(size: phone, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62),
                                  layout: ScreenLayout.make(viewSize: phone, hasFold: false, hudOnLeft: true))]
        for c in canvases {
            let l = HUDLayout.make(c)
            // R4: in play every line can show on the inner-top plate, and on the inner-bottom one while a pop is under
            // the top (the lesson's own lines show there too).
            for plate in [l.hint, l.lessonHint] {
                #expect(plate.width >= HUDLayout.hintMin)
                for line in AppRules.allHintLines {
                    let f = HintFit.font(compact: c.isCompact, long: line.long)
                    let fits = HintFit.fits(line.text, plateWidth: plate.width, compact: c.isCompact, long: line.long)
                    #expect(fits)
                    // The plate's box holds the lines it wraps to.
                    let lines = CGFloat(HintFit.lines(line.text, plateWidth: plate.width, compact: c.isCompact,
                                                      long: line.long))
                    #expect(lines * f.lineHeight + 14 <= plate.height + 0.5)
                }
            }
        }
        // The old cut line is gone.
        #expect(!AppRules.allHintCopy.contains("Last snap — make it count"))
        #expect(HintFit.lines("Snap the halves together", plateWidth: 1_000, compact: false) == 1)
        #expect(!HintFit.fits("Supercalifragilisticexpialidocious", plateWidth: 150, compact: true))
    }

    /// REVIEW-1 #11: nothing the HUD draws in play crosses the crease, on either side.
    @Test func hudTextIsFoldClear() {
        for left in [false, true] {
            let c = duo(hudLeft: left)
            let l = HUDLayout.make(c)
            for rect in l.textRects + [l.lessonHint, l.lesson, l.pause] {
                #expect(c.isFoldClear(rect))
            }
            // "Your trap is tired." is centred on the HUD page, not on the crease.
            #expect(abs(l.tired.midX - c.hudPage.midX) < 1)
        }
    }

    @Test func phoneHudWrapsTheSnapsOffTheRim() {
        let size = CGSize(width: 874, height: 402)
        let c = AppCanvas(size: size, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62),
                          layout: ScreenLayout.make(viewSize: size, hasFold: false))
        let l = HUDLayout.make(c)
        #expect(l.snapRows == 2)
        for rect in l.ciliaRects {
            #expect(c.minTrapRadius(rect) >= HUDLayout.clearRadius)
        }
        #expect(l.hint.width >= HUDLayout.hintMin)
        #expect(!c.inThumbZone(l.hint))
    }

    @Test func scenePointInvertsScreenPoint() {
        let c = duo()
        let p = CGPoint(x: 700, y: 120)
        let back = c.scenePoint(c.screenPoint(p))
        #expect(near(back.x, p.x))
        #expect(near(back.y, p.y))
        let l = HUDLayout.make(c)
        let g = l.glyphCenter(0)
        #expect(l.snaps.contains(g))
    }

    @Test func trapReachMatchesTheEllipse() {
        let c = duo()
        let t = c.trapRect
        let mid = c.trapReach(y0: t.midY - 1, y1: t.midY + 1, right: true)
        #expect(mid.map { near($0, t.maxX) } ?? false)
        #expect(c.trapReach(y0: -40, y1: -10, right: true) == nil)
        #expect(c.minTrapRadius(CGRect(x: t.midX - 5, y: t.midY - 5, width: 10, height: 10)) < 0.1)
    }

    @Test func bugBookHeaderClearsTheBackButton() {
        let c = duo()
        let pause = HUDLayout.make(c).back
        let h = BugBookView.headerHeight(compact: false, pauseMaxY: pause.maxY, top: c.top)
        #expect(c.top - 8 + h >= pause.maxY)
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
        #expect(GameController.matches(.hungry, s, events: [.hungry(secondsLeft: 3)]))
        #expect(!GameController.matches(.hungry, s, events: []))
        #expect(GameController.matches(.wilted, s, events: [.wilted(snapsLeft: 4)]))
        #expect(DemoMode.Freeze.hungry.isEvent)
        #expect(DemoMode.Freeze.wilted.isEvent)
        #expect(DemoMode.parse("freezeOn=hungry").freezeOn == .hungry)
        #expect(DemoMode.parse("freezeOn=wilted").freezeOn == .wilted)
    }

    @Test func shownSnapsFollowTheFlyingGlyphs() {
        #expect(AppRules.shownSnaps(10, offset: -1, max: 14) == 9)
        #expect(AppRules.shownSnaps(9, offset: 1, max: 14) == 10)
        #expect(AppRules.shownSnaps(0, offset: -2, max: 14) == 0)
        #expect(AppRules.shownSnaps(14, offset: 2, max: 14) == 14)
    }

    @Test func badgeTiersAndSubjects() {
        var gold = 0
        for a in Achievements.all where BadgePainter.tier(for: a.id) == .gold { gold += 1 }
        #expect(gold >= 3 && gold <= 6)
        #expect(BadgePainter.species(for: Achievements.scarab.id) == [.goldenScarab])
        let spareBugs = BadgePainter.species(for: Achievements.spare50.id)
        let allProtected = spareBugs.allSatisfy { $0.isProtected }
        #expect(allProtected)
    }

    @Test func tallyIgnoresHunger() {
        var t = RunTally()
        t.note(.hungry(secondsLeft: 3))
        t.note(.wilted(snapsLeft: 5))
        #expect(t == RunTally())
    }

    @Test func pointerTargets() {
        let bugs = [
            BugState(id: 1, species: .housefly, position: CGPoint(x: 301, y: 341), heading: 0, activity: .sipping,
                     height: 0, inTrap: true, onRim: false),
            BugState(id: 2, species: .bee, position: CGPoint(x: 600, y: 300), heading: 0, activity: .walking,
                     height: 0, inTrap: true, onRim: false),
            BugState(id: 3, species: .housefly, position: CGPoint(x: 0, y: 0), heading: 0, activity: .leaving,
                     height: 0.5, inTrap: false, onRim: false),
        ]
        let s = TrapSnapshot(bugs: bugs)
        // R8: the coach's counts (a fly sipping, a bee walking in the trap).
        let counts = AppRules.trapCounts(s)
        #expect(counts.sipping == 1)
        #expect(counts.beeInTrap)
        // R3: with a bee in play only the bee is pointed at.
        let targets = AppRules.lessonTargets(s)
        #expect(targets.count == 1)
        #expect(targets.first?.bee == true)
        let flies = AppRules.lessonTargets(TrapSnapshot(bugs: [bugs[0], bugs[2]]))
        #expect(flies.count == 1)
        #expect(flies.first?.sipping == true)
    }

    @Test func drawnClosureIsClamped() {
        #expect(AppRules.drawnClosure(reference: 160, predicted: 140) == 20)
        #expect(AppRules.drawnClosure(reference: 150, predicted: 160) == 0)
        #expect(AppRules.drawnClosure(reference: 170, predicted: 0) == 90)
        #expect(AppRules.drawnClosure(reference: .nan, predicted: 120) == nil)
    }

    @Test func firstRunIsCelebrated() {
        var d = ProgressData()
        let first = record(makeRun(), &d)
        #expect(first.firstRun)
        let second = record(makeRun(), &d)
        #expect(!second.firstRun)
    }
}

// MARK: - Round 4

@MainActor
struct RoundFourTests {
    /// QA-2 #2, #3, #4: the numeral only ever moves from what it showed toward Core's count.
    @Test func snapsNeverMoveTheWrongWay() {
        // A costly sting with 1 left: Core goes to 0, the crack's offset says +2. The row stays at 1, then drops.
        #expect(AppRules.truthfulSnaps(previous: 1, target: 0, candidate: 2, max: 14, hold: false) == 1)
        #expect(AppRules.truthfulSnaps(previous: 1, target: 0, candidate: 0, max: 14, hold: false) == 0)
        // A Feast at the cap: Core stays at 14 while two glyphs fly (offset −2): no dip.
        #expect(AppRules.truthfulSnaps(previous: 14, target: 14, candidate: 12, max: 14, hold: false) == 14)
        // The lesson's triple (snaps never run out): 10 stays 10.
        #expect(AppRules.truthfulSnaps(previous: 10, target: 10, candidate: 9, max: 14, hold: false) == 10)
        // A Feast from 3 (Core 4, two glyphs in the air): it only climbs, as the glyphs land.
        #expect(AppRules.truthfulSnaps(previous: 3, target: 4, candidate: 2, max: 14, hold: false) == 3)
        #expect(AppRules.truthfulSnaps(previous: 3, target: 4, candidate: 4, max: 14, hold: false) == 4)
        // The frame whose events the Scene hasn't drawn yet holds; the first frame of a run shows Core's count.
        #expect(AppRules.truthfulSnaps(previous: 6, target: 5, candidate: 5, max: 14, hold: true) == 6)
        #expect(AppRules.truthfulSnaps(previous: nil, target: 14, candidate: 12, max: 14, hold: false) == 14)
        #expect(AppRules.movesSnaps([.drySnap, .wilted(snapsLeft: 3)]))
        #expect(!AppRules.movesSnaps([.rearmed, .drySnap]))
    }

    @Test func feastAtTheCapSaysFull() {
        #expect(AppRules.refundHitTheCap(before: 14, after: 14, back: 1, max: 14))
        #expect(AppRules.refundHitTheCap(before: 14, after: 14, back: 2, max: 14))
        #expect(!AppRules.refundHitTheCap(before: 10, after: 11, back: 2, max: 14))
        #expect(!AppRules.refundHitTheCap(before: 14, after: 13, back: 0, max: 14))
        // R7 (#5): in plain words.
        #expect(AppRules.snapGainText(1, full: true) == "+1 snap (row full)")
        #expect(AppRules.snapGainText(2) == "+2 snaps")
    }

    /// REVIEW-3 #10: "×1.5 held" after a clean one-bug bite; a step or a break isn't a hold.
    @Test func chainHeld() {
        let one = TrapEvent.snapped(report(caught: [.housefly]))
        #expect(AppRules.chainHeld([one], chain: 1))
        #expect(!AppRules.chainHeld([one], chain: 0))
        #expect(!AppRules.chainHeld([one, .chainBroken(count: 2)], chain: 1))
        #expect(!AppRules.chainHeld([.snapped(report(caught: [.housefly, .gnat])), .chainUp(count: 2, multiplier: 2)],
                                    chain: 2))
        #expect(!AppRules.chainHeld([.snapped(report(caught: [.housefly], stingers: [.bee]))], chain: 1))
        #expect(AppRules.chainChipText(1.5, short: true, held: true) == "×1.5 held")
        #expect(AppRules.chainChipText(2, short: false, held: false) == "Chain ×2")
        #expect(AppRules.chainChipText(2, short: true, held: false) == "×2")
        #expect(AppRules.chainLesson == "Big bites in a row build a chain.")
    }

    /// REVIEW-3 #2: play demos are standard unless `firstRun=1` or `progress=fresh`; the new freeze tags.
    @Test func demoDefaultsAndFreezeTags() {
        #expect(!AppRules.demoFirstRun(firstRun: nil, progress: nil))
        #expect(!AppRules.demoFirstRun(firstRun: nil, progress: .mid))
        #expect(AppRules.demoFirstRun(firstRun: nil, progress: .fresh))
        #expect(AppRules.demoFirstRun(firstRun: true, progress: .mid))
        #expect(!AppRules.demoFirstRun(firstRun: false, progress: .fresh))
        #expect(DemoMode.parse("firstRun=1").firstRun == true)
        #expect(DemoMode.parse("firstRun=0").firstRun == false)
        #expect(DemoMode.parse("screen=play").firstRun == nil)
        #expect(!DemoMode.parse("screen=play").playsFirstRun)
        for tag in ["firstHint", "chain5", "costlySting", "drySnap", "held"] {
            #expect(DemoMode.parse("freezeOn=" + tag).freezeOn?.rawValue == tag)
        }
        #expect(abs(DemoMode.Freeze.hungry.holdDelay - 0.5) < 1e-9)
        #expect(abs(DemoMode.Freeze.wilted.holdDelay - 0.3) < 1e-9)
        #expect(abs(DemoMode.Freeze.costlySting.holdDelay - 0.2) < 1e-9)
        #expect(!DemoMode.Freeze.firstHint.isEvent)
        let s = TrapSnapshot(chain: 1)
        #expect(GameController.matches(.firstHint, s, events: [], hint: .foldInput))
        #expect(!GameController.matches(.firstHint, s, events: [], hint: .beesCost))
        #expect(GameController.matches(.chain5, s, events: [.chainUp(count: 5, multiplier: 3)]))
        #expect(!GameController.matches(.chain5, s, events: [.chainUp(count: 4, multiplier: 2.5)]))
        #expect(GameController.matches(.costlySting, s, events: [.stung(id: 1, species: .wasp, cost: 2)]))
        #expect(!GameController.matches(.costlySting, s, events: [.stung(id: 1, species: .bee, cost: 0)]))
        #expect(GameController.matches(.drySnap, s, events: [.drySnap]))
        #expect(GameController.matches(.held, s, events: [.snapped(report(caught: [.gnat]))]))
    }

    /// QA-2 #11: a Daily first doesn't use up the first Feed run's perks; an old save counts every run as Feed.
    @Test func feedRunsCountFeedOnly() throws {
        var d = ProgressData()
        _ = record(makeRun(mode: .daily(day: 299, scored: true)), &d)
        #expect(d.runs == 1)
        #expect(d.feedRuns == 0)
        #expect(AppRules.isSproutFirstRun(mode: .feed, feedRuns: d.feedRuns))
        _ = record(makeRun(), &d)
        #expect(d.feedRuns == 1)
        #expect(!AppRules.isSproutFirstRun(mode: .feed, feedRuns: d.feedRuns))
        let old = try #require(ProgressStore.decode(Data(#"{"runs":3}"#.utf8)))
        #expect(old.feedRuns == 3)
        let raw = try #require(ProgressStore.encode(d))
        let back = try #require(ProgressStore.decode(raw))
        #expect(back.feedRuns == 1)
        // An empty Feed run left early doesn't count.
        var e = ProgressData()
        _ = abandon(makeRun(score: 0, bugs: 0, caught: [:]), &e)
        #expect(e.feedRuns == 0)
    }

    /// REVIEW-3 #3: the plate never covers a live pop.
    @Test func hintPlateKeepsOffPops() {
        let top = CGRect(x: 500, y: 20, width: 220, height: 100)
        let bottom = CGRect(x: 500, y: 540, width: 200, height: 100)
        let clear = HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [CGRect(x: 100, y: 300, width: 80,
                                                                                      height: 40)])
        #expect(clear?.rect == top && clear?.low == false)
        let popTop = [CGRect(x: 600, y: 60, width: 120, height: 50)]
        let moved = HUDLayout.hintSlot(primary: top, alternate: bottom, pops: popTop)
        #expect(moved?.rect == bottom && moved?.low == true)
        #expect(HUDLayout.hintSlot(primary: top, alternate: bottom, pops: popTop + [bottom]) == nil)
        for pops in [popTop, [CGRect(x: 0, y: 0, width: 10, height: 10)]] {
            if let slot = HUDLayout.hintSlot(primary: top, alternate: bottom, pops: pops) {
                var covered = false
                for p in pops where p.intersects(slot.rect) { covered = true }
                #expect(!covered)
            }
        }
        let r = AppRules.roundedRects([CGRect(x: 3, y: 5, width: 10, height: 10), CGRect(x: CGFloat.nan, y: 0, width: 1,
                                                                                         height: 1)])
        #expect(r == [CGRect(x: 0, y: 0, width: 16, height: 16)])
    }

    /// REVIEW-3 #4: the cover card fits a phone in landscape (402 pt), the Duo's cover display and both turned.
    @Test func coverFits() {
        let cases: [(CGSize, EdgeInsets)] = [
            (CGSize(width: 874, height: 402), EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
            (CGSize(width: 402, height: 874), EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)),
            (CGSize(width: 466, height: 678), EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)),
            (CGSize(width: 678, height: 466), EdgeInsets(top: 0, leading: 24, bottom: 20, trailing: 24)),
        ]
        for (size, insets) in cases {
            for midRun in [true, false] {
                let l = CoverLayout.make(size: size, insets: insets, midRun: midRun, hasBest: !midRun)
                #expect(l.contentHeight <= l.area.height + 0.5)
                #expect(l.trap.height >= CoverLayout.trapMinH)
                #expect(l.area.maxY <= size.height - insets.bottom)
                #expect(l.textWidth <= l.area.width)
            }
        }
        #expect(CoverLayout.make(size: CGSize(width: 874, height: 402), insets: EdgeInsets(), midRun: true,
                                 hasBest: false).sideBySide)
        #expect(!CoverLayout.make(size: CGSize(width: 466, height: 678), insets: EdgeInsets(), midRun: true,
                                  hasBest: false).sideBySide)
    }

    /// REVIEW-3 #8: the fold diagrams (R8 portrait: the pose diagram is gone with the pose card).
    @Test func foldDiagrams() {
        // The angle reads under the hinge: the label fits the glyph's height.
        for h in [CGFloat(30), 48] {
            #expect(FoldAngleGlyph.labelSize(height: h) + 6 <= h)
        }
    }

    /// REVIEW-3 #19: the bee pointer's last stretch misses the fly beside the bee.
    @Test func beeArrowMissesTheFly() {
        let bee = CGPoint(x: 600, y: 400)
        let origin = CGPoint(x: 600, y: 100)
        // A fly right on the straight line in, just above the bee's ring.
        let fly = CGPoint(x: 600, y: 330)
        let path = LessonPointer.approach(to: bee, ring: 40, from: origin, avoid: [fly])
        #expect(LessonPointer.distance(fly, toSegment: path.tip, path.control) >= LessonPointer.avoidClear)
        let straight = LessonPointer.approach(to: bee, ring: 40, from: origin, avoid: [])
        #expect(abs(straight.tip.x - 600) < 0.01 && straight.tip.y < bee.y)
        let bugs = [
            BugState(id: 1, species: .bee, position: CGPoint(x: 600, y: 300), heading: 0, activity: .sipping,
                     height: 0, inTrap: true, onRim: false),
            BugState(id: 2, species: .housefly, position: CGPoint(x: 601, y: 341), heading: 0, activity: .sipping,
                     height: 0, inTrap: true, onRim: false),
        ]
        #expect(AppRules.lessonAvoidPoints(TrapSnapshot(bugs: bugs)) == [CGPoint(x: 600, y: 340)])
        #expect(AppRules.lessonAvoidPoints(TrapSnapshot(bugs: [bugs[1]])).isEmpty)
    }

    /// REVIEW-3 #13: the Daily's name is the score's caption (it ran under Pause).
    @Test func dailyNameIsTheScoreCaption() {
        #expect(ScoreBlock.caption(passedBest: false, best: 3_200, daily: "Daily Bog · 28 Oct") == "DAILY BOG · 28 OCT")
        #expect(ScoreBlock.caption(passedBest: true, best: 3_200, daily: "Daily Bog · 28 Oct") == "NEW BEST")
        #expect(ScoreBlock.caption(passedBest: false, best: 0, daily: nil) == "SCORE")
        #expect(ScoreBlock.caption(passedBest: false, best: 3_200, daily: nil) == "BEST 3,200")
    }

    /// REVIEW-3 #16, #18: the badges' bugs sit on the 3/4 trap's back face, inside its drawing.
    @Test func badgeBugsSitOnTheTrap() {
        let c = CGPoint(x: 256, y: 270)
        let w: CGFloat = 360
        let h = w * TrapArt.threeQuarterAspect
        for (u, v) in [(CGFloat(-0.34), CGFloat(0.5)), (0.34, 0.56), (0, 0.76), (0.3, 0.6)] {
            let p = SceneHooks.threeQuarterPoint(u: u, v: v, width: w, center: c)
            #expect(p.x > c.x - w / 2 && p.x < c.x + w / 2)
            #expect(p.y > c.y - h / 2 && p.y < c.y + h / 2)
        }
        // The back face is above the hinge (v up the lobe is up on screen).
        let low = SceneHooks.threeQuarterPoint(u: 0, v: 0.1, width: w, center: c)
        let high = SceneHooks.threeQuarterPoint(u: 0, v: 0.9, width: w, center: c)
        #expect(high.y < low.y)
        #expect(BadgePainter.species(for: Achievements.nobees.id).contains(.bee))
        #expect(BadgePainter.species(for: Achievements.bite5.id) != BadgePainter.species(for: Achievements.feast.id))
    }
}

// MARK: - Round 5

@MainActor
struct RoundFiveTests {
    // R8 portrait: REVIEW-4 #2's `poseCardFits` is gone with the pose card (every angle plays: PortraitTests).

    /// REVIEW-4 #4: the tired banner never shows while the numeral shows a snap, and waits ≥ 0.45 s after the bite.
    @Test func tiredBannerWaitsForZero() {
        #expect(AppRules.tiredBannerDelay >= 0.45)
        #expect(AppRules.tiredNumeralLimit > AppRules.tiredBannerDelay)
        #expect(AppRules.tiredFreezeAt > AppRules.tiredNumeralLimit)
        #expect(AppRules.tiredFreezeAt < Tuning.tiredSeconds)
        // Never while the shown snaps are above 0, whatever the moment.
        for i in 0..<45 {
            let phase = RunPhase.tired(elapsed: Double(i) * 0.05)
            for shown in 1...3 {
                let banner = AppRules.showsTiredBanner(phase: phase, shownSnaps: shown)
                #expect(!banner)
            }
        }
        #expect(!AppRules.showsTiredBanner(phase: .tired(elapsed: 0.2), shownSnaps: 0))
        #expect(!AppRules.showsTiredBanner(phase: .tired(elapsed: 0.44), shownSnaps: 0))
        #expect(AppRules.showsTiredBanner(phase: .tired(elapsed: 0.45), shownSnaps: 0))
        #expect(!AppRules.showsTiredBanner(phase: .playing, shownSnaps: 0))
        #expect(!AppRules.showsTiredBanner(phase: .finished, shownSnaps: 0))
        // The numeral reaches 0 in time for the banner, even if the Scene's crack held it up.
        #expect(AppRules.tiredNumeral(2, phase: .tired(elapsed: 0.3)) == 2)
        #expect(AppRules.tiredNumeral(2, phase: .tired(elapsed: AppRules.tiredNumeralLimit)) == 0)
        #expect(AppRules.tiredNumeral(5, phase: .playing) == 5)
        // A frame-by-frame ending (the 19/40 case): the crack lands at 0.3 s.
        var bannerAt: Double?
        for i in 0..<40 {
            let t = Double(i) / 30
            let phase = RunPhase.tired(elapsed: t)
            let shown = AppRules.tiredNumeral(t < 0.3 ? 1 : 0, phase: phase)
            let banner = AppRules.showsTiredBanner(phase: phase, shownSnaps: shown)
            if banner {
                #expect(shown == 0)
                if bannerAt == nil { bannerAt = t }
            }
        }
        #expect((bannerAt ?? 0) >= AppRules.tiredBannerDelay)
        // CI's `freezeOn=tired` holds once the banner is up.
        #expect(!GameController.matches(.tired, TrapSnapshot(phase: .tired(elapsed: 0.1)), events: [.tired]))
        #expect(GameController.matches(.tired, TrapSnapshot(phase: .tired(elapsed: 1.7)), events: []))
        // R7 (#5): the banner waits for the bite's pops, but never past `tiredBannerLatest`.
        #expect(!AppRules.showsTiredBanner(phase: .tired(elapsed: 0.8), shownSnaps: 0, popsLive: true))
        #expect(AppRules.showsTiredBanner(phase: .tired(elapsed: AppRules.tiredBannerLatest), shownSnaps: 0,
                                          popsLive: true))
        #expect(AppRules.tiredFreezeAt > AppRules.tiredBannerLatest)
    }

    /// REVIEW-4 #5 (belt and braces): never "Hungry… bite!" while a halo is inside the zone; "Bee! Wait…" instead.
    @Test func noHungerBesideABee() {
        let g = ScreenLayout(hasFold: true).geometry
        let inside = BugState(id: 1, species: .bee, position: CGPoint(x: g.center.x - 200, y: g.center.y),
                              heading: 0, activity: .arriving, height: 0.3, inTrap: false, onRim: false)
        let away = BugState(id: 2, species: .wasp, position: CGPoint(x: 5, y: 660), heading: 0, activity: .leaving,
                            height: 0.8, inTrap: false, onRim: false)
        let eaten = BugState(id: 3, species: .bee, position: g.center, heading: 0, activity: .caught(elapsed: 0.1),
                             height: 0, inTrap: true, onRim: false)
        let fly = BugState(id: 4, species: .housefly, position: g.center, heading: 0, activity: .sipping, height: 0,
                           inTrap: true, onRim: false)
        #expect(AppRules.protectedHaloInTrap(TrapSnapshot(bugs: [inside, fly]), geometry: g))
        #expect(!AppRules.protectedHaloInTrap(TrapSnapshot(bugs: [away, fly]), geometry: g))
        #expect(!AppRules.protectedHaloInTrap(TrapSnapshot(bugs: [eaten, fly]), geometry: g))
        #expect(AppRules.guardedHint(.hungry, haloInTrap: true) == .beeInside)
        #expect(AppRules.guardedHint(.hungry, haloInTrap: false) == .hungry)
        #expect(AppRules.guardedHint(.crowd, haloInTrap: true) == .crowd)
        #expect(AppRules.guardedHint(nil, haloInTrap: true) == nil)
    }

    /// REVIEW-4 #7: a costly sting says its cost at the row, the mirror of "+1 snap".
    @Test func stingCostTag() {
        #expect(AppRules.snapLossText(1) == "\u{2212}1 snap")
        #expect(AppRules.snapLossText(2) == "\u{2212}2 snaps")
        #expect(AppRules.snapLossText(0) == "\u{2212}1 snap")
        #expect(AppRules.snapGainText(1) == "+1 snap")
    }

    /// REVIEW-4 #13 (founder call): "score" for the score word, "Score on the left", a three-sentence card 09 and a
    /// bigger snaps numeral.
    @Test func plainWords() {
        #expect(AppRules.scoreWord == "score")
        #expect(ScoreBlock.caption(passedBest: false, best: 0, daily: nil) == "SCORE")
        #expect(SettingsView.hudSideTitle == "Score on the left")
        var record = DailyRecord(score: 800, finished: true, practiceBest: 0)
        let lines = [AppRules.story(makeRun(biggest: 6)), AppRules.story(makeRun(biggest: 3)),
                     DailyView.status(canPlay: false, record: record)]
        record.finished = false
        let early = DailyView.status(canPlay: false, record: record)
        for line in lines + [early] {
            #expect(!line.lowercased().contains("protein"))
        }
        #expect(HUDLayout.numeralDuo >= 24)
        #expect(HUDLayout.numeralPhone >= 20)
        let size = CGSize(width: 951, height: 669)
        let c = AppCanvas(size: size, insets: EdgeInsets(), layout: ScreenLayout.make(viewSize: size, hasFold: true))
        let l = HUDLayout.make(c)
        // R6 (#14): the labelled numeral where there's room, else R5's on the row (never smaller than R5's).
        #expect(l.numeralSize == (l.numeralLabeled ? HUDLayout.numeralDuo : HUDLayout.numeralRowDuo))
        #expect(l.numeralSize >= 24)
        #expect(l.numeral.height >= HUDLayout.numeralHeight(glyph: l.glyph) - 0.01)
        // The bigger numeral still sits inside the snaps, clear of the glyphs (hudClearsTheCiliaOnTheDuo checks it
        // against the cilia).
        #expect(l.snaps.contains(l.numeral))
    }

    /// REVIEW-4 #12: Home's subtitle no longer repeats the clap card's "Snap it shut a little".
    @Test func homeSubtitleSaysTheRule() {
        #expect(!HomeView.subtitle(foldInput: true).contains(HomeView.foldCaption))
        #expect(HomeView.subtitle(foldInput: false) == "Tap to snap. Spare bees.")
    }

    /// ROUND-5: the Daily's one-line share (scored Dailies only).
    @Test func dailyShare() {
        #expect(AppRules.dailyShareText(day: 300, score: 4_210, biggestBite: 6, brand: "Snapjaw")
                == "Snapjaw Daily Bog #301 · 4,210 · biggest bite 6 🪤")
        let scored = ResultsView.shareText(makeRun(mode: .daily(day: 300, scored: true), score: 4_210, biggest: 6))
        #expect(scored?.contains("#301 · 4,210 · biggest bite 6") == true)
        #expect(ResultsView.shareText(makeRun(mode: .daily(day: 300, scored: false))) == nil)
        #expect(ResultsView.shareText(makeRun(mode: .feed)) == nil)
    }

    /// REVIEW-4 #8 (founder call): the Sprout taper's options for Feed runs 1–3, standard from run 4.
    @Test func sproutTaper() {
        #expect(AppRules.sproutFeedRun(mode: .feed, feedRuns: 0) == 1)
        #expect(AppRules.sproutFeedRun(mode: .feed, feedRuns: 1) == 2)
        #expect(AppRules.sproutFeedRun(mode: .feed, feedRuns: 2) == 3)
        #expect(AppRules.sproutFeedRun(mode: .feed, feedRuns: 3) == nil)
        #expect(AppRules.sproutFeedRun(mode: .daily(day: 3, scored: true), feedRuns: 0) == nil)
        #expect(AppRules.sproutFeedRun(mode: .lesson, feedRuns: 0) == nil)
        var one = SessionOptions()
        GameController.applySprout(feedRun: 1, to: &one)
        #expect(one.sproutRun == 1)
        #expect(one.firstRun)
        #expect(!one.hunger)
        #expect(one.freeFirstSting)
        var two = SessionOptions()
        GameController.applySprout(feedRun: 2, to: &two)
        #expect(two.sproutRun == 2)
        #expect(!two.firstRun)
        #expect(two.hunger)
        #expect(!two.freeFirstSting)
        var three = SessionOptions()
        GameController.applySprout(feedRun: 3, to: &three)
        #expect(three.sproutRun == 3)
        var four = SessionOptions()
        GameController.applySprout(feedRun: 4, to: &four)
        #expect(four == SessionOptions())
        var none = SessionOptions()
        GameController.applySprout(feedRun: nil, to: &none)
        #expect(none == SessionOptions())
    }

    /// REVIEW-4 #14: three badges draw the hero trap, each fitted inside the disc; none lays a bug on it.
    @Test func badgesKeepInsideTheDisc() {
        let heroCount = Achievements.all.filter { BadgePainter.usesHero(id: $0.id) }.count
        #expect(heroCount == 3)
        #expect(BadgePainter.usesHero(id: "snap.ach.unknown"))
        let aspect = TrapArt.threeQuarterAspect
        let spots: [(CGFloat, CGPoint)] = [(300, CGPoint(x: 256, y: 292)), (300, CGPoint(x: 256, y: 300)),
                                           (270, CGPoint(x: 226, y: 296)), (340, BadgePainter.center)]
        for (width, c) in spots {
            let w = BadgePainter.heroFit(width: width, center: c, aspect: aspect)
            #expect(w <= width)
            #expect(w >= 150)
            let h = w * aspect
            for corner in [CGPoint(x: c.x - w / 2, y: c.y - h / 2), CGPoint(x: c.x + w / 2, y: c.y + h / 2),
                           CGPoint(x: c.x - w / 2, y: c.y + h / 2), CGPoint(x: c.x + w / 2, y: c.y - h / 2)] {
                let d = hypot(corner.x - BadgePainter.center.x, corner.y - BadgePainter.center.y)
                #expect(d <= BadgePainter.discRadius)
            }
        }
        // The hero badges' bugs fly round the trap; its sipper is the Scene's own.
        for id in BadgePainter.heroBadges {
            #expect(BadgePainter.species(for: id).count <= 2)
        }
        #expect(BadgePainter.species(for: Achievements.monarch.id).isEmpty)
    }
}

// MARK: - Round 6: goals, the Garden, the Zen Bog, the streak, one message at a time

/// A book whose three active goals are `ids` (Core's pool).
private func book(_ ids: [String]) -> GoalBookState {
    var b = GoalBookState(seed: 42)
    b.active = ids.map { GoalBookSlot(id: $0) }
    return b
}

@MainActor
struct RoundSixTests {
    /// #6: one message at a time; a moment's tag takes the screen and the toast waits; a warning holds a toast's clock.
    @Test func oneMessageAtATime() {
        var q = MessageQueue()
        q.post(.plate(.goalDone("A 3-bug bite")), seconds: 2, now: 0)
        q.post(.plate(.chainTag(1.5)), seconds: 2, now: 0)
        let first = q.shown(now: 0.1, hint: .trap(.crowd))
        #expect(first == .plate(.goalDone("A 3-bug bite")))
        // The same toast is never queued twice.
        q.post(.plate(.chainTag(1.5)), seconds: 2, now: 0.2)
        #expect(q.pending.count == 1)
        // A tag interrupts; the toast goes back to the front.
        q.post(.tag(.loss("−2 snaps")), seconds: 1, now: 0.5, interrupt: true)
        let tag = q.shown(now: 0.6, hint: nil)
        #expect(tag == .tag(.loss("−2 snaps")))
        // R7 (#5): the tag ended at 1.5; nothing (not even a state hint) for the 0.4 s gap.
        let quiet = q.shown(now: 1.6, hint: .trap(.crowd))
        #expect(quiet == nil)
        let back = q.shown(now: 2.0, hint: nil)
        #expect(back == .plate(.goalDone("A 3-bug bite")))
        // A warning shows over a waiting toast, and the toast keeps its time (it runs 2.0 → 4.0, plus 0.5 s).
        let warned = q.shown(now: 2.5, hint: .trap(.beeInside), warning: true)
        #expect(warned == .plate(.trap(.beeInside)))
        let still = q.shown(now: 3.0, hint: nil)
        #expect(still == .plate(.goalDone("A 3-bug bite")))
        let gap = q.shown(now: 4.6, hint: nil)
        #expect(gap == nil)
        let next = q.shown(now: 5.0, hint: nil)
        #expect(next == .plate(.chainTag(1.5)))
        let hint = q.shown(now: 7.5, hint: .trap(.crowd))
        #expect(hint == .plate(.trap(.crowd)))
        #expect(q.isIdle)
        q.clear()
        #expect(q.current == nil)
        // Paused or frozen: nothing; tired: only a tag.
        #expect(AppRules.hidesMessage(.plate(.foldInput), paused: true, frozen: false, live: true))
        #expect(AppRules.hidesMessage(.plate(.foldInput), paused: false, frozen: false, live: false))
        #expect(!AppRules.hidesMessage(.tag(.loss("x")), paused: false, frozen: false, live: false))
        #expect(!AppRules.hidesMessage(.plate(.foldInput), paused: false, frozen: false, live: true))
    }

    /// #6 (frame 43): the plate keeps off the trap's flies when the other slot is clear, and never covers a pop.
    @Test func plateKeepsOffItsSubjects() {
        let top = CGRect(x: 500, y: 20, width: 220, height: 100)
        let bottom = CGRect(x: 500, y: 540, width: 200, height: 100)
        let fly = CGRect(x: 520, y: 40, width: 30, height: 30)
        let moved = HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [], subjects: [fly])
        #expect(moved?.low == true)
        let both = HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [],
                                      subjects: [fly, CGRect(x: 520, y: 560, width: 30, height: 30)])
        #expect(both?.low == false)
        #expect(HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [bottom], subjects: [fly])?.low == false)
        let s = TrapSnapshot(bugs: [BugState(id: 1, species: .housefly, position: CGPoint(x: 300, y: 300), heading: 0,
                                             activity: .sipping, height: 0, inTrap: true, onRim: false),
                                    BugState(id: 2, species: .gnat, position: CGPoint(x: 10, y: 10), heading: 0,
                                             activity: .walking, height: 0, inTrap: false, onRim: false)])
        let rects = AppRules.subjectRects(s)
        #expect(rects.count == 1)
        #expect(rects.first?.contains(CGPoint(x: 300, y: 300)) == true)
    }

    /// #6 (frame 42): the chip doesn't repeat the bite's "×2 held"; the free sting's plate stands alone.
    @Test func noDoubledWords() {
        #expect(AppRules.chainChipText(2, short: true, held: false) == "×2")
        #expect(AppRules.hudHintText(.goalDone("A 3-bug bite"), touch: true) == "Goal done! A 3-bug bite")
        #expect(AppRules.hudHintIsLong(.goalDone("x")))
        #expect(!AppRules.hudHintIsWarning(.goalDone("x")))
        #expect(AppRules.nightCueText(.nightGetsFast) == "The night gets fast…")
        #expect(AppRules.nightCueText(.lastLight) == "Last light…")
        #expect(!AppRules.isFreeSting(.stung(id: 1, species: .bee, cost: 0), mode: .zen))
    }

    /// Goals: Core's tracker ticks live through `GoalRun`; the lesson and the attract bog track nothing.
    @Test func goalsTickLive() {
        var run = GoalRun(book: book(["bite3", "catch20", "spare3"]), mode: .feed)
        #expect(!run.isEmpty)
        let met = run.note([.snapped(report(caught: [.gnat, .gnat, .housefly]))])
        let metIDs = met.map { $0.id }
        #expect(metIDs == ["bite3"])
        let again = run.note([.snapped(report(caught: [.gnat, .gnat, .housefly]))])
        #expect(again.isEmpty)
        #expect(run.completed == ["bite3"])
        let lines = run.lines
        #expect(lines.count == 3)
        #expect(lines.first?.done == true)
        #expect(run.report.completed == ["bite3"])
        #expect(run.report.progress["bite3"] == 3)
        let lesson = GoalRun(book: book(["bite3"]), mode: .lesson)
        #expect(lesson.isEmpty)
        #expect(GoalRun().lines.isEmpty)
    }

    /// Goals at Results: the report is filed with Core (`GoalBook.complete`): done goals give growth and are replaced.
    @Test func goalsAreFiledWithGrowth() {
        var d = ProgressData()
        d.goalBook = book(["bite3", "catch20", "spare3"])
        let report = GoalReport(completed: ["bite3"], progress: ["bite3": 3, "catch20": 7, "spare3": 1])
        let o = record(makeRun(score: 400, bugs: 7, caught: ["housefly": 7], biggest: 3), &d)
        #expect(o.goalsDone.isEmpty)
        var e = ProgressData()
        e.goalBook = book(["bite3", "catch20", "spare3"])
        let out = ProgressRules.record(makeRun(score: 400, bugs: 7, caught: ["housefly": 7], biggest: 3), into: &e,
                                       today: 299, goals: report, rankFor: fakeRank, earn: noAchievements)
        #expect(out.goalsDone == ["bite3"])
        #expect(out.goalGrowth >= GoalBook.reward(rank: 0))
        #expect(!out.goalBonus)
        #expect(out.newGoals.count == 1)
        #expect(out.goalLines.count == 3)
        let ids = e.goalBook?.active.map(\.id) ?? []
        #expect(!ids.contains("bite3"))
        #expect(ids.count == GoalBridge.slots)
        #expect(e.goalsDone == 1)
        // The growth is on the rank bar.
        #expect(e.growth == e.rankBugs + out.goalGrowth)
        #expect(out.lifetimeAfter == e.growth)
        // The banked progress of an unfinished goal.
        let catchSlot = e.goalBook?.active.first { $0.id == "catch20" }
        #expect(catchSlot?.progress == 7)
        // A report is worth filing on its own.
        #expect(ProgressRules.worthRecording(makeRun(mode: .zen, score: 0, bugs: 0, caught: [:]), goals: report))
    }

    /// Persistence: v2 keeps the book, the Garden and the streak; a v1 save's rank keeps every bug it had.
    @Test func roundSixPersistence() throws {
        var d = ProgressData()
        d.goalBook = book(["bite3", "catch20", "spare3"])
        d.rankBugs = 0
        d.variety = TrapVariety.redDragon.rawValue
        d.varietiesSeen = [TrapVariety.classic.rawValue, TrapVariety.redDragon.rawValue]
        d.bestStreak = 4
        d.chainTipSeen = true
        d.pendingGoals = GoalReport(completed: ["bite3"], progress: ["bite3": 3])
        let raw = try #require(ProgressStore.encode(d))
        let back = try #require(ProgressStore.decode(raw))
        #expect(back == d)
        #expect(back.version == ProgressData.currentVersion)
        let v1 = try #require(ProgressStore.decode(Data(#"{"version":1,"lifetimeBugs":250,"longestChain":2}"#.utf8)))
        #expect(v1.rankBugs == 250)
        #expect(v1.chainTipSeen)
        #expect(v1.goalBook == nil)
        let odd = try #require(ProgressStore.decode(Data(#"{"variety":"plum","goalBook":7}"#.utf8)))
        #expect(odd.variety == TrapVariety.classic.rawValue)
        #expect(odd.goalBook == nil)
        // Home's goals before the first run are the ones the first run plays.
        var fresh = ProgressData()
        let shown = ProgressRules.goalLines(ProgressRules.goalBook(fresh)).map(\.id)
        let played = ProgressRules.prepareGoals(&fresh).active.map(\.id)
        #expect(shown == played)
        #expect(shown.count == GoalBridge.slots)
    }

    /// Zen (founder rule): no best and no leaderboard; the Bug Book counts every bug, the rank a quarter.
    @Test func zenIsFiledGently() {
        var d = ProgressData()
        d.bestFeed = 900
        let o = record(makeRun(mode: .zen, score: 5_000, bugs: 40, caught: ["housefly": 40]), &d)
        #expect(o.zen)
        #expect(!o.isNewBest)
        #expect(o.best == 0)
        #expect(d.bestFeed == 900)
        #expect(d.lifetimeBugs == 40)
        #expect(d.caughtCount(.housefly) == 40)
        #expect(d.rankBugs == 10)
        #expect(d.lifetimeScore == 0)
        #expect(d.runs == 1)
        #expect(d.feedRuns == 0)
        #expect(ProgressRules.best(for: .zen, in: d) == 0)
        #expect(AppRules.againMode(.zen) == .zen)
        #expect(AppRules.startBanner(.zen, touch: true) == AppRules.zenBanner)
        // R7 (#10): Zen play shows a score, so Zen Results does too (with its bugs and time under it).
        #expect(ResultsView.heroWord(zen: true) == "score")
        #expect(ResultsView.heroWord(zen: false) == "score")
        #expect(PauseMenu.zenEnd == "End")
        // Feed and the Daily still count every bug for the rank.
        _ = record(makeRun(score: 100, bugs: 8, caught: ["gnat": 8]), &d)
        #expect(d.rankBugs == 18)
    }

    /// The Daily streak: days in a row with the scored try played; it survives until today's is played; a gap ends it.
    @Test func dailyStreak() {
        var d = ProgressData()
        d.dailyAttempted = [296, 297, 298]
        #expect(ProgressRules.dailyStreak(d, today: 299) == 3)
        #expect(ProgressRules.dailyStreak(d, today: 300) == 0)
        ProgressRules.noteDailyStart(&d, day: 299)
        #expect(ProgressRules.dailyStreak(d, today: 299) == 4)
        #expect(d.bestStreak == 4)
        let o = record(makeRun(mode: .daily(day: 299, scored: true), score: 4_210, biggest: 6), &d)
        #expect(o.streak == 4)
        #expect(ProgressRules.streakText(4) == "🔥 4 days")
        #expect(ProgressRules.streakText(1) == "🔥 1 day")
        #expect(ProgressRules.streakText(0) == nil)
        #expect(HomeView.streakBadge(3) == "🔥 3")
        #expect(HomeView.streakBadge(1) == nil)
        #expect(DailyView.streakLine(streak: 3, best: 5) == "🔥 3 days · best 5")
        #expect(DailyView.streakLine(streak: 0, best: 5) == nil)
        // The share line carries the streak.
        let share = ResultsView.shareText(makeRun(mode: .daily(day: 300, scored: true), score: 4_210, biggest: 6),
                                          streak: 4)
        #expect(share == "\(AppBrand.name) Daily Bog #301 · 4,210 · biggest bite 6 · 🔥 4 days 🪤")
    }

    /// The Garden: Core's rules; a locked variety can't be picked; the pick is drawn everywhere.
    @Test func gardenPicks() {
        var d = ProgressData()
        #expect(d.unlockedVarieties == [.classic])
        #expect(d.chosenVariety == .classic)
        d.variety = TrapVariety.goldenGlow.rawValue
        #expect(d.chosenVariety == .classic)
        #expect(GardenView.countLine(d) == "1 of 8 grown")
        let store = ProgressStore(inMemory: d)
        let locked = store.chooseVariety(.redDragon)
        #expect(!locked)
        var grown = ProgressData()
        grown.rankBugs = PlantRanks.threshold(2)
        grown.lifetimeBugs = grown.rankBugs
        #expect(grown.unlockedVarieties.contains(.redDragon))
        #expect(HomeView.gardenHasNew(grown))
        let s2 = ProgressStore(inMemory: grown)
        let picked = s2.chooseVariety(.redDragon)
        #expect(picked)
        #expect(s2.data.chosenVariety == .redDragon)
        s2.markVarietiesSeen()
        #expect(!HomeView.gardenHasNew(s2.data))
        #expect(GardenCard.line(.redDragon, grown: true) == Varieties.info(.redDragon).blurb)
        #expect(GardenCard.line(.goldenGlow, grown: false) == VarietyBridge.rule(.goldenGlow))
        // A run that crosses a rank names the new variety for Results' celebration.
        var r = ProgressData()
        r.rankBugs = PlantRanks.threshold(2) - 5
        r.lifetimeBugs = r.rankBugs
        let o = record(makeRun(score: 300, bugs: 10, caught: ["housefly": 10]), &r)
        #expect(o.newVarieties.contains(.redDragon))
    }

    /// #16: Results names the next Bug Book page from the Book's own clue.
    @Test func nextBookPage() {
        var d = ProgressData()
        let first = AppRules.nextBookTarget(d)
        #expect(first != nil)
        let phase = first.map { BugCatalog.info($0).firstPhase }
        #expect(phase == .morning)
        for s in BugSpecies.allCases {
            if s.isProtected { d.spared[s.rawValue] = 1 } else { d.caught[s.rawValue] = 1 }
        }
        #expect(AppRules.nextBookTarget(d) == nil)
        #expect(AppRules.nextBookLine(.bee) == "Spare a striped one to fill its page.")
        #expect(AppRules.nextBookLine(.dragonfly).hasPrefix("Something new"))
        #expect(ResultsView.nextBookTitle == "Next for the Bug Book")
    }

    /// #12: the cover card is centred in the screen whatever a stale inset says, and fills it.
    @Test func coverIsCentredAndFilled() {
        let size = CGSize(width: 466, height: 678)
        let stale = EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 86)
        let l = CoverLayout.make(size: size, insets: stale, midRun: true, hasBest: false)
        #expect(abs(l.area.midX - size.width / 2) < 0.5)
        #expect(l.contentHeight <= l.area.height + 0.5)
        #expect(l.trap.width >= size.width * 0.6)
        #expect(l.titleSize >= 30)
        let wide = CoverLayout.make(size: CGSize(width: 874, height: 402),
                                    insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 20), midRun: true,
                                    hasBest: false)
        #expect(abs(wide.area.midX - 437) < 0.5)
    }

    /// #14: the snaps numeral is labelled "SNAPS" where it has room (and always clear of the cilia: LayoutTests).
    @Test func snapsNumeralIsLabelled() {
        let size = CGSize(width: 951, height: 669)
        for left in [false, true] {
            let c = AppCanvas(size: size, insets: EdgeInsets(),
                              layout: ScreenLayout.make(viewSize: size, hasFold: true, hudOnLeft: left))
            let l = HUDLayout.make(c)
            #expect(l.snaps.contains(l.numeral))
            #expect(!l.chain.intersects(l.numeral))
            for i in 0..<HUDLayout.slotCount {
                let p = l.glyphCenter(i)
                #expect(!l.numeral.insetBy(dx: 1, dy: 1).contains(p))
            }
            if l.numeralLabeled {
                #expect(l.numeral.maxY <= (l.snapRowRects.first?.minY ?? 0))
                #expect(l.numeralSize == HUDLayout.numeralDuo)
            }
        }
        #expect(HUDLayout.numeralLabel == "SNAPS")
        #expect(HUDLayout.numeralDuo >= 30)
    }

    /// The FEAST freeze is the Scene's FEAST: 5+ clean bugs, or ×4; a bite with a stinger never is.
    @Test func bigFeastFreeze() {
        let five = report(caught: [.gnat, .gnat, .gnat, .gnat, .housefly])
        #expect(AppRules.isBigFeast([.snapped(five)]))
        #expect(!AppRules.isBigFeast([.snapped(report(caught: [.gnat, .gnat, .gnat]))]))
        let stung = report(caught: [.gnat, .gnat, .gnat, .gnat, .gnat, .gnat], stingers: [.bee])
        #expect(!AppRules.isBigFeast([.snapped(stung)]))
        let s = TrapSnapshot()
        #expect(GameController.matches(.bigFeast, s, events: [.snapped(five)]))
        #expect(GameController.matches(.goalDone, s, events: [], hint: .goalDone("A 3-bug bite")))
        #expect(!GameController.matches(.goalDone, s, events: [], hint: .foldInput))
        #expect(DemoMode.Freeze.bigFeast.isEvent)
        #expect(!DemoMode.Freeze.goalDone.isEvent)
        #expect(abs(DemoMode.Freeze.bigFeast.holdDelay - 0.45) < 1e-9)
    }

    /// The goal toasts fit the plate's own slot (≤ 3 lines, no word cut), on the Duo and a phone, either side.
    @Test func goalToastsFit() {
        let phone = CGSize(width: 874, height: 402)
        let duo = CGSize(width: 951, height: 669)
        let canvases = [AppCanvas(size: duo, insets: EdgeInsets(), layout: ScreenLayout.make(viewSize: duo, hasFold: true)),
                        AppCanvas(size: phone, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62),
                                  layout: ScreenLayout.make(viewSize: phone, hasFold: false, hudOnLeft: true))]
        let titles = AppRules.goalToastTitles
        #expect(titles.count == GoalBook.pool.count)
        #expect(AppRules.goalDoneText("A 3-bug bite") == "Goal done! A 3-bug bite")
        for c in canvases {
            let plate = HUDLayout.make(c).hint
            #expect(HintFit.fits(AppRules.goalDoneHeading, plateWidth: plate.width, compact: c.isCompact))
            for text in titles {
                let fits = HintFit.fits(text, plateWidth: plate.width, compact: c.isCompact, long: true)
                #expect(fits)
            }
        }
    }

    /// Demo keys for the R6 frames.
    @Test func roundSixDemoKeys() {
        #if DEBUG
        #expect(DemoMode.parse("screen=garden").screen == .garden)
        #expect(DemoMode.parse("mode=zen").runMode(today: 3) == .zen)
        #expect(DemoMode.parse("freezeOn=bigFeast").freezeOn == .bigFeast)
        #expect(DemoMode.parse("freezeOn=goalDone").freezeOn == .goalDone)
        #expect(DemoMode.parse("variety=b52").variety == .b52)
        #expect(DemoMode.parse("variety=plum").variety == nil)
        #endif
        let mid = DemoPresets.progress(.mid, today: 299)
        #expect(mid.goalBook?.active.count == GoalBridge.slots)
        #expect(mid.rank == 4)
        #expect(ProgressRules.dailyStreak(mid, today: 299) == 2)
        let late = DemoPresets.progress(.late, today: 299)
        #expect(late.unlockedVarieties.contains(.sawtooth))
        #expect(!late.unlockedVarieties.contains(.goldenGlow))
        #expect(!HomeView.gardenHasNew(late))
    }
}

// MARK: - Round 7: one message at a time for real, Results that fit, the Duo's counter, Zen, tiers

@MainActor
struct RoundSevenTests {
    /// #5: two toasts posted together show one after the other, at least `MessageQueue.gap` apart.
    @Test func messagesAreSpacedApart() {
        var q = MessageQueue()
        q.post(.plate(.goalDone("A 3-bug bite")), seconds: 1, now: 0)
        q.post(.plate(.nightCue(.lastLight)), seconds: 1, now: 0)
        var lastEnd: Double?
        var secondStart: Double?
        var previous: HUDMessage?
        for i in 0..<60 {
            let t = Double(i) * 0.05
            let m = q.shown(now: t, hint: nil)
            if previous == .plate(.goalDone("A 3-bug bite")) && m != previous { lastEnd = t }
            if m == .plate(.nightCue(.lastLight)) && secondStart == nil { secondStart = t }
            previous = m
        }
        let end = lastEnd ?? -1
        let start = secondStart ?? -1
        #expect(end > 0)
        #expect(start - end >= MessageQueue.gap - 0.051)
        #expect(abs(MessageQueue.gap - 0.4) < 1e-9)
    }

    /// #5: a toast with no clear spot keeps its clock still, for at most `maxHold`; then it may show where it must.
    @Test func aHeldToastWaits() {
        var q = MessageQueue()
        q.post(.plate(.beesCost), seconds: 1, now: 0)
        _ = q.shown(now: 0, hint: nil)
        _ = q.shown(now: 0.5, hint: nil, hold: true)
        let a = q.until
        #expect(abs(a - 1.5) < 1e-9)
        #expect(!q.holdSpent)
        // To 2.25 s: the hold is spent at 2.0 (0.5 + 1.5), and the toast now ends at 3.0.
        for i in 1...35 { _ = q.shown(now: 0.5 + Double(i) * 0.05, hint: nil, hold: true) }
        #expect(q.holdSpent)
        #expect(abs(q.until - (1 + MessageQueue.maxHold)) < 1e-6)
        // A strict slot is refused while both slots cover a bug; a free one is taken.
        let top = CGRect(x: 500, y: 20, width: 220, height: 100)
        let bottom = CGRect(x: 500, y: 540, width: 200, height: 100)
        let flies = [CGRect(x: 520, y: 40, width: 30, height: 30), CGRect(x: 520, y: 560, width: 30, height: 30)]
        #expect(HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [], subjects: flies, strict: true) == nil)
        #expect(HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [], subjects: flies) != nil)
        #expect(HUDLayout.hintSlot(primary: top, alternate: bottom, pops: [], subjects: [flies[0]], strict: true)?.low
                == true)
        #expect(AppRules.hudHintIsToast(.beesCost))
        #expect(AppRules.hudHintIsToast(.goalDone("x")))
        #expect(!AppRules.hudHintIsToast(.trap(.crowd)))
        #expect(!AppRules.hudHintIsToast(.foldInput))
    }

    /// #3: the bite counts bugs in words; "×" is only the chain. The refund's one tag at the row, in plain words.
    @Test func plainBiteWords() {
        #expect(AppRules.biteCallout(count: 5, points: 540) == "5 bugs · +540")
        #expect(AppRules.biteCallout(count: 1, points: 12) == "+12")
        #expect(!AppRules.biteCallout(count: 7, points: 1_080).contains("×"))
        #expect(AppRules.biteGainText(back: 2, full: false, lucky: [], bigFeast: true, firstFeast: false)
                == "FEAST! +2 snaps")
        #expect(AppRules.biteGainText(back: 2, full: false, lucky: [.goldenScarab], bigFeast: false, firstFeast: false)
                == "Golden scarab! +2 snaps")
        #expect(AppRules.biteGainText(back: 1, full: true, lucky: [], bigFeast: false, firstFeast: false)
                == "+1 snap (row full)")
        #expect(AppRules.biteGainText(back: 1, full: false, lucky: [], bigFeast: false, firstFeast: true) == "+1 snap")
        #expect(AppRules.biteGainText(back: 1, full: false, lucky: [], bigFeast: false, firstFeast: false) == nil)
        #expect(AppRules.biteGainText(back: 0, full: false, lucky: [.ladybird], bigFeast: true, firstFeast: true) == nil)
        #expect(AppRules.luckyText(.ladybird).hasPrefix("Ladybird! +"))
        #expect(AppRules.luckyText(.goldenScarab, snaps: false) == "Golden scarab!")
        #expect(AppRules.leaderboardName == "Best Score")
    }

    /// R8 (founder rule 2: no pose demands, ever): no too-flat prompt, no "hold it like a book" anywhere a plate speaks.
    @Test func noPoseDemands() {
        #expect(AppRules.hintText(.bendALittle, touch: false) == nil)
        #expect(AppRules.hintText(.bendALittle, touch: true) == nil)
        for line in AppRules.allHintCopy + AppRules.coachSamples {
            let l = line.lowercased()
            #expect(!l.contains("fold it"))
            #expect(!l.contains("like a book"))
            #expect(!l.contains("stand it"))
        }
    }

    /// #17: a bee's halo over the trap's edge counts as beside the trap (no "Hungry… bite!").
    @Test func haloOnTheEdge() {
        let g = ScreenLayout(hasFold: true).geometry
        let edge = BugState(id: 1, species: .bee, position: CGPoint(x: g.center.x + g.a + 10, y: g.center.y),
                            heading: 0, activity: .walking, height: 0, inTrap: false, onRim: false)
        let far = BugState(id: 2, species: .bee, position: CGPoint(x: g.center.x + g.a + 200, y: g.center.y),
                           heading: 0, activity: .walking, height: 0, inTrap: false, onRim: false)
        #expect(AppRules.haloReaches(edge.position, species: .bee, geometry: g))
        #expect(!AppRules.haloReaches(far.position, species: .bee, geometry: g))
        #expect(AppRules.protectedHaloInTrap(TrapSnapshot(bugs: [edge]), geometry: g))
        #expect(!AppRules.protectedHaloInTrap(TrapSnapshot(bugs: [far]), geometry: g))
        #expect(!AppRules.haloReaches(CGPoint(x: CGFloat.nan, y: 0), species: .bee, geometry: g))
    }

    /// #7, #10, #15: Results' words.
    @Test func resultsWords() throws {
        #expect(GameController.feedTitle(newBest: true) == "What a feast!")
        #expect(GameController.feedTitle(newBest: false) == "Your trap is tired")
        #expect(ResultsView.zenLine(bugs: 94, seconds: 150) == "94 bugs in 2:30 · no best kept")
        #expect(ResultsView.zenLine(bugs: 1, seconds: 59.6) == "1 bug in 1:00 · no best kept")
        #expect(ResultsView.zenLine(bugs: 3, seconds: Double.nan) == "3 bugs in 0:00 · no best kept")
        #expect(ResultsView.stripBiteTitle(5) == "5-bug bite")
        #expect(ResultsView.stripBiteTitle(1) == "Best bite")
        #expect(ResultsView.Fit.allCases.first == .full)
        #expect(ResultsView.Fit.allCases.last == .tightest)
        // The next goal: a goal just drawn first, else the first one still open.
        let spec = try #require(GoalBook.pool.first)
        let line = GoalLine.make(spec, progress: 0, done: false)
        #expect(line.tier == spec.tier)
        #expect(line.tierLabel == spec.tier.label)
        var o = RecordOutcome()
        o.goalLines = [GoalLine.make(spec, progress: 0, done: true)]
        #expect(ResultsView.nextGoal(o) == nil)
        o.newGoals = [spec.id]
        #expect(ResultsView.nextGoal(o)?.id == spec.id)
        #expect(ResultsView.nextGoalText(line) == "Next goal: " + spec.title)
        for t in [GoalTier.easy, .medium, .hard] { _ = GoalRow.tierColor(t) }
    }

    /// #19: the Garden's rules in one style; every locked card the same silhouette.
    @Test func gardenRulesInOneStyle() {
        for v in TrapVariety.allCases {
            let rule = VarietyBridge.rule(v)
            switch Varieties.info(v).unlock {
            case .start: #expect(!rule.isEmpty)
            case .rank: #expect(rule.hasPrefix("Rank: "))
            case .goal: #expect(rule.hasPrefix("Goal: "))
            }
            #expect(GardenTrapImage.drawn(v, grown: false) == .classic)
            #expect(GardenTrapImage.drawn(v, grown: true) == v)
        }
    }

    /// #10, #13: the Zen badge; "SNAPS" at every size.
    @Test func hudLabels() {
        #expect(ScoreBlock.caption(passedBest: true, best: 9, daily: nil, zen: true) == "ZEN BOG")
        #expect(ScoreBlock.caption(passedBest: false, best: 0, daily: nil) == "SCORE")
        let phone = CGSize(width: 874, height: 402)
        let duo = CGSize(width: 951, height: 669)
        let canvases = [AppCanvas(size: duo, insets: EdgeInsets(), layout: ScreenLayout.make(viewSize: duo, hasFold: true)),
                        AppCanvas(size: duo, insets: EdgeInsets(),
                                  layout: ScreenLayout.make(viewSize: duo, hasFold: true, hudOnLeft: true)),
                        AppCanvas(size: phone, insets: EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62),
                                  layout: ScreenLayout.make(viewSize: phone, hasFold: false))]
        for c in canvases {
            let l = HUDLayout.make(c)
            // Either the labelled block or the row's own label.
            #expect(l.numeralLabeled || l.snapsLabel != nil)
            if let r = l.snapsLabel {
                #expect(l.snaps.contains(r))
                #expect(!r.intersects(l.numeral.insetBy(dx: 1, dy: 1)))
                #expect(!r.intersects(l.chain))
                for i in 0..<HUDLayout.slotCount {
                    #expect(!r.insetBy(dx: 1, dy: 1).contains(l.glyphCenter(i)))
                }
                if c.hasFold { #expect(c.isFoldClear(r)) }
            }
        }
        #expect(HUDLayout.glyphDuo >= 28)
    }

    /// #4 (with Scene and Core): Home's button frames go to the scene in scene space, rounded out, never NaN.
    @Test func homeButtonFramesInSceneSpace() {
        let duo = CGSize(width: 951, height: 669)
        let c = AppCanvas(size: duo, insets: EdgeInsets(), layout: ScreenLayout.make(viewSize: duo, hasFold: true))
        let button = CGRect(x: 600, y: 300, width: 300, height: 70)
        let out = HomeView.sceneRects([button, CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10), .zero], info: c)
        #expect(out.count == 1)
        if let r = out.first {
            let back = c.screenRect(r)
            #expect(back.insetBy(dx: -0.5, dy: -0.5).contains(button))
            #expect(back.width - button.width <= 4 * c.scale + 0.5)
        }
    }

    /// The R7 demo keys: `freezeOn=feastGulp`, `progress=story`, the Zen Results seed.
    @Test func roundSevenDemoKeys() {
        #if DEBUG
        #expect(DemoMode.parse("freezeOn=feastGulp").freezeOn == .feastGulp)
        #expect(DemoMode.parse("progress=story").progress == .story)
        #endif
        #expect(DemoMode.Freeze.feastGulp.isEvent)
        #expect(DemoMode.Freeze.feastGulp.holdsSceneAtOnce)
        #expect(!DemoMode.Freeze.bigFeast.holdsSceneAtOnce)
        #expect(abs(DemoMode.Freeze.feastGulp.holdDelay - 0.15) < 1e-9)
        let five = report(caught: [.gnat, .gnat, .gnat, .gnat, .housefly])
        let three = report(caught: [.gnat, .gnat, .housefly])
        #expect(GameController.matches(.feastGulp, TrapSnapshot(), events: [.snapped(five)]))
        #expect(!GameController.matches(.feastGulp, TrapSnapshot(), events: [.snapped(three)]))
        #expect(AppRules.isCrowdFeast([.snapped(five)]))
        #expect(DemoMode.seed(for: .zen, screen: .results) == DemoMode.zenResultsSeed)
        #expect(DemoMode.seed(for: .zen, screen: .play) == DemoMode.defaultSeed)
        #expect(DemoMode.seed(for: .feed, screen: .results) == DemoMode.defaultSeed)
        let story = DemoPresets.progress(.story, today: 299)
        #expect(story.rank == 7)
        #expect(story.unlockedVarieties.count == 5)
        #expect(story.speciesFound == 13)
        #expect(story.goalBook?.active.count == GoalBridge.slots)
    }
}

// MARK: - Round 8: the phone IS the trap; levels; the CHOMP card; plain words

private func bite(caught: [BugSpecies], escaped: Int = 0, stingers: [BugSpecies] = [], lost: Int = 0,
                  duration: Double = 0.2, ratio: Double = 1) -> BiteReport {
    BiteReport(caught: caught, escaped: escaped, stingers: stingers, points: 90 * caught.count,
               countMultiplier: caught.count, chainMultiplier: 1, snapsBack: 0, snapsLost: lost, duration: duration,
               time: 4, catchRatio: ratio)
}

@MainActor
struct RoundEightTests {
    /// ROUND-8 §3: every bite says plainly what was good or bad.
    @Test func biteVerdicts() {
        #expect(AppRules.biteVerdict(bite(caught: [.housefly, .gnat, .gnat])).text == "3 bugs! Fast close")
        #expect(AppRules.biteVerdict(bite(caught: [.housefly, .gnat, .gnat])).good)
        #expect(AppRules.biteVerdict(bite(caught: [], escaped: 2)).text == "Too slow, they flew")
        #expect(!AppRules.biteVerdict(bite(caught: [], escaped: 2)).good)
        #expect(AppRules.biteVerdict(bite(caught: [])).text == "Empty bite")
        #expect(AppRules.biteVerdict(bite(caught: [], stingers: [.bee], lost: 1)).text == "Bee! \u{2212}1 snap")
        #expect(AppRules.biteVerdict(bite(caught: [], stingers: [.wasp])).text == "Wasp! Let it leave")
        #expect(AppRules.biteVerdict(bite(caught: [.gnat], escaped: 3, duration: 1.2, ratio: 0.25)).text
                == "Too slow, 3 flew")
        #expect(AppRules.biteVerdict(bite(caught: [.gnat, .gnat], duration: 0.8)).text == "2 bugs! Clean bite")
        #expect(AppRules.biteVerdict(bite(caught: [.gnat, .gnat, .gnat], duration: 0.8)).text == "3 bugs! Feast!")
        // A tap has no speed: never "Fast close" on a phone.
        #expect(AppRules.biteVerdict(bite(caught: [.gnat], duration: 0.12), touch: true).text == "Got it! Clean bite")
        #expect(AppRules.biteVerdict(bite(caught: [.gnat], duration: Double.nan)).text == "Got it! Clean bite")
        // R9 (frame 46: "FEAST!" under "Too slow, 1 flew"): a crowd caught is good news, whatever flew.
        let feast = AppRules.biteVerdict(bite(caught: [.gnat, .gnat, .gnat], escaped: 3, duration: 1.2, ratio: 0.5))
        #expect(feast.good)
        #expect(feast.text == "3 bugs! 3 got away")
        // R9: a phone is never told it was slow (a tap has no speed).
        #expect(AppRules.biteVerdict(bite(caught: [], escaped: 2), touch: true).text == "Missed, they flew")
        #expect(!AppRules.biteVerdict(bite(caught: [], escaped: 2), touch: true).text.contains("slow"))
        for s in AppRules.verdictSamples { #expect(s.split(separator: " ").count <= 5) }
        #expect(AppRules.hudHintIsToast(.verdict("x", good: true)))
        #expect(AppRules.hudHintIsWarning(.verdict("x", good: false)))
        #expect(!AppRules.hudHintIsWarning(.verdict("x", good: true)))
        #expect(!AppRules.hudHintIsToast(.coach("x")))
    }

    /// Levels 1–5 teach one idea each: the coach says one short thing at the right moment.
    @Test func teachingCoach() {
        #expect(AppRules.teachNeed(level: 1) == 1)
        #expect(AppRules.teachNeed(level: 3) == 2)
        #expect(AppRules.teachNeed(level: 5) == 3)
        #expect(AppRules.teachNeed(level: 6) == nil)
        #expect(AppRules.coachLine(level: 1, sipping: 1, beeInTrap: false, armed: true, touch: false)
                == "Now close it, fast!")
        #expect(AppRules.coachLine(level: 3, sipping: 1, beeInTrap: false, armed: true, touch: false) == "Wait for 2…")
        #expect(AppRules.coachLine(level: 5, sipping: 3, beeInTrap: false, armed: true, touch: true) == "Now! Tap!")
        // A bee in the trap: Core's "Bee! Wait…" speaks, not the coach.
        #expect(AppRules.coachLine(level: 4, sipping: 1, beeInTrap: true, armed: true, touch: false) == nil)
        #expect(AppRules.coachLine(level: 9, sipping: 3, beeInTrap: false, armed: true, touch: false) == nil)
        // Never "open it" to a phone that's open (founder rule 3): only when the trap isn't armed.
        #expect(AppRules.coachLine(level: 2, sipping: 0, beeInTrap: false, armed: false, touch: false) == "Open it again")
        #expect(AppRules.coachLine(level: 2, sipping: 0, beeInTrap: false, armed: false, touch: true) == nil)
        for line in AppRules.coachSamples { #expect(line.split(separator: " ").count <= 4) }
    }

    /// The CHOMP card's words, per kind.
    @Test func chompCardWords() {
        let catchBite = ChompInfo(bite(caught: [.housefly, .gnat, .gnat, .ant]), score: 1_240)
        #expect(catchBite.kind == .catchBite)
        #expect(ChompWords.headline(.catchBite) == "CHOMP!")
        #expect(ChompWords.callout(catchBite) == "4 bugs · +360")
        #expect(ChompWords.note(catchBite) == "Fast close")
        let one = ChompInfo(bite(caught: [.gnat]), score: 90)
        #expect(ChompWords.callout(one) == "1 bug · +90")
        let sting = ChompInfo(bite(caught: [], stingers: [.bee], lost: 1), score: 0)
        #expect(sting.kind == .sting)
        #expect(ChompWords.headline(.sting) == "Bzzt!")
        #expect(ChompWords.callout(sting) == "A bee · \u{2212}1 snap")
        // R9 (frames 57, 58): the note says what to do next, never the callout again.
        #expect(ChompWords.note(sting) == ChompWords.stingTip)
        #expect(ChompWords.note(ChompInfo(bite(caught: [], stingers: [.wasp]), score: 0)) == ChompWords.stingTipWasp)
        let dry = ChompInfo(bite(caught: [], escaped: 2), score: 0)
        #expect(dry.kind == .dry)
        #expect(ChompWords.callout(dry) == "They all flew")
        #expect(ChompWords.note(dry) == ChompWords.slowTip)
        #expect(ChompWords.note(ChompInfo(bite(caught: []), score: 0)) == ChompWords.emptyTip)
        for c in [sting, dry, catchBite, one] {
            #expect(ChompWords.note(c) != ChompWords.callout(c))
        }
        #expect(ChompWords.carryOn == "Open to keep feeding")
        #expect(ChompArt.bumpSpots.count == ChompArt.maxBumps)
        for kind in [ChompInfo.Kind.catchBite, .sting, .dry] {
            let made = AppRules.demoChomp(kind, score: 100)
            #expect(made.kind == kind)
        }
        #expect(AppRules.demoChompMatches(bite(caught: [.gnat, .gnat, .gnat]), want: .catchBite))
        #expect(!AppRules.demoChompMatches(bite(caught: [.gnat]), want: .catchBite))
        #expect(AppRules.demoChompMatches(bite(caught: [], stingers: [.bee]), want: .sting))
        #expect(AppRules.demoChompMatches(bite(caught: []), want: .dry))
    }

    /// The CHOMP card fits the Duo's cover display and a phone (CI's forced cover), every size measured.
    @Test func chompCardFits() {
        let cases: [(CGSize, EdgeInsets)] = [
            (CGSize(width: 466, height: 678), EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)),
            (CGSize(width: 874, height: 402), EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)),
            (CGSize(width: 402, height: 874), EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)),
        ]
        for (size, insets) in cases {
            let l = CoverLayout.make(size: size, insets: insets, midRun: true, hasBest: false)
            #expect(l.contentHeight <= l.area.height + 0.5)
            #expect(l.trap.height >= CoverLayout.trapMinH)
            let aspect = l.trap.height / max(l.trap.width, 1)
            #expect(abs(aspect - CoverLayout.trapAspect) < 0.01)
        }
        #expect(DisplayText.inkWidth(40) >= 2)
        #expect(DisplayText.inkWidth(10) == 2)
    }

    /// Level progress: in order, a world at 20 stars (Core's rules), the best stars kept, persisted (v3).
    @Test func levelProgress() throws {
        var d = ProgressData()
        #expect(LevelRules.next(d) == 1)
        #expect(LevelRules.isOpen(d, 1))
        #expect(!LevelRules.isOpen(d, 2))
        #expect(!LevelRules.isWorldOpen(d, world: 2))
        let first = LevelRules.record(&d, id: 1, stars: 2)
        #expect(first.before == 0 && first.after == 2 && first.opened == nil)
        #expect(LevelRules.isOpen(d, 2))
        #expect(LevelRules.next(d) == 2)
        // A worse try never lowers the best; a failed one (0) never counts.
        _ = LevelRules.record(&d, id: 1, stars: 1)
        #expect(LevelRules.stars(d, 1) == 2)
        _ = LevelRules.record(&d, id: 2, stars: 0)
        #expect(!LevelRules.passed(d, 2))
        // 20 stars open Dusk (its first level open, the next world's line counts down).
        var w = ProgressData()
        var opened: Int?
        for id in 1...7 { opened = LevelRules.record(&w, id: id, stars: 3).opened ?? opened }
        #expect(opened == 2)
        #expect(LevelRules.totalStars(w) == 21)
        #expect(LevelRules.isWorldOpen(w, world: 2))
        #expect(LevelRules.isOpen(w, 11))
        #expect(LevelWords.unlockLine(w, world: 3) == "19 more ★ to open Night")
        #expect(LevelRules.world(of: 1) == 1 && LevelRules.world(of: 20) == 2 && LevelRules.world(of: 30) == 3)
        #expect(LevelRules.ids(world: 2) == 11...20)
        #expect(LevelRules.nextAfter(7, in: w) == 8)
        // Persisted.
        let raw = try #require(ProgressStore.encode(w))
        let back = try #require(ProgressStore.decode(raw))
        #expect(back.levelStars == w.levelStars)
        #expect(ProgressData.currentVersion == 3)
        let odd = try #require(ProgressStore.decode(Data(#"{"levelStars":{"3":9,"0":2,"5":0}}"#.utf8)))
        #expect(odd.levelStars == [3: 3])
        // A level run fills the Bug Book but keeps no best.
        var r = ProgressData()
        r.bestFeed = 500
        let o = record(makeRun(mode: .level(3), score: 900, bugs: 5, caught: ["housefly": 5]), &r)
        #expect(o.level)
        #expect(!o.isNewBest)
        #expect(r.bestFeed == 500)
        #expect(r.caughtCount(.housefly) == 5)
        #expect(ProgressRules.best(for: .level(3), in: r) == 0)
        #expect(AppRules.againMode(.level(4)) == .level(4))
    }

    /// The levels' words and pictures.
    @Test func levelWords() {
        #expect(LevelWords.levelName(3) == "Level 3")
        #expect(LevelWords.worldName(1) == "Morning Bog")
        #expect(LevelWords.worldName(3) == "Night")
        #expect(LevelWords.startLine(touch: false) == "Close the phone to start")
        #expect(LevelWords.startLine(touch: true) == "Tap to start")
        #expect(LevelGoalBadge.caption(LevelHUD(id: 3, goal: "Catch 3 flies", secondsLeft: 75)) == "LEVEL 3 · 1:15")
        #expect(LevelGoalBadge.caption(LevelHUD(id: 12, goal: "x")) == "LEVEL 12")
        for id in 1...30 {
            let n = LevelArt.species(id).count
            #expect(n >= 1 && n <= 3)
        }
        #expect(LevelArt.species(4).contains(.bee))
        let box = CGSize(width: 400, height: 500)
        for i in 0..<10 {
            let p = LevelMapView.padCenter(i, in: box)
            #expect(p.x > 0 && p.x < box.width && p.y > 0 && p.y < box.height)
        }
        #expect(ClosingPhoneGlyph.spread(at: 0) > 60)
        #expect(ClosingPhoneGlyph.spread(at: ClosingPhoneGlyph.loop * 0.5) < 1)
        #expect(LevelResultsView.headline(LevelResult(id: 1, world: 1, title: "", goal: "", stars: 3, bestStars: 3,
                                                      passed: true, line: "", next: 2, worldOpened: nil)) == "Perfect!")
        #expect(LevelResultsView.headline(LevelResult(id: 1, world: 1, title: "", goal: "", stars: 0, bestStars: 0,
                                                      passed: false, line: "", next: nil, worldOpened: nil)) == "Not yet!")
    }

    /// The goal line mirrors the score, so it sits on the other page, off the fold.
    @Test func goalLineSitsOnTheOtherPage() {
        for left in [false, true] {
            let size = CGSize(width: 951, height: 669)
            let c = AppCanvas(size: size, insets: EdgeInsets(),
                              layout: ScreenLayout.make(viewSize: size, hasFold: true, hudOnLeft: left))
            let l = HUDLayout.make(c)
            let goal = LevelGoalLayout.rect(c, score: l.score)
            #expect(c.isFoldClear(goal))
            #expect(c.otherPage.insetBy(dx: -40, dy: 0).contains(CGPoint(x: goal.midX, y: goal.midY)))
            #expect(!goal.intersects(l.score))
        }
    }

    /// The R8 demo keys.
    @Test func roundEightDemoKeys() {
        #if DEBUG
        #expect(DemoMode.parse("screen=levels").screen == .levels)
        #expect(DemoMode.parse("screen=levelIntro").screen == .levelIntro)
        #expect(DemoMode.parse("screen=LEVELRESULTS").screen == .levelResults)
        #expect(DemoMode.parse("screen=chomp;chomp=dry").chomp == .dry)
        #expect(DemoMode.parse("screen=shut").screen == .shut)
        #expect(DemoMode.parse("screen=lesson").screen == nil)
        #expect(DemoMode.parse("mode=level;level=7").runMode(today: 3) == .level(7))
        #expect(DemoMode.parse("mode=level").runMode(today: 3) == .level(DemoMode.defaultLevel))
        #endif
        #expect(DemoMode.chompKind("catch") == .catchBite)
        #expect(DemoMode.chompKind("bogus") == nil)
        let mid = DemoPresets.progress(.mid, today: 299)
        #expect(LevelRules.next(mid) == 7)
        let late = DemoPresets.progress(.late, today: 299)
        #expect(LevelRules.isWorldOpen(late, world: 3))
        #expect(DemoPresets.progress(.fresh, today: 299).levelStars.isEmpty)
    }

    /// Menus sit on the live bog; only play is a play route.
    @Test func routes() {
        #expect(AppRoute.playing.isPlay)
        #expect(!AppRoute.levels.isPlay)
        #expect(AppRoute.levels.showsLiveBog && AppRoute.results.showsLiveBog && AppRoute.home.showsLiveBog)
        #expect(!AppRoute.playing.showsLiveBog)
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

// MARK: - R8 portrait: no pose card; the scene turned a quarter (design/notes/portrait-R8.md)

@MainActor
struct PortraitTests {
    /// The Duo's inner display held like a laptop (the fold across the middle).
    private static let duoPortrait = CGSize(width: 669, height: 951)
    private static let duoBook = CGSize(width: 951, height: 669)
    /// No insets, and a guess at a camera cut-out and a home bar in portrait.
    private static let insetCases = [EdgeInsets(), EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)]

    private func canvas(_ insets: EdgeInsets = EdgeInsets(), hudLeft: Bool = false) -> AppCanvas {
        AppCanvas(size: PortraitTests.duoPortrait, insets: insets,
                  layout: ScreenLayout.make(viewSize: PortraitTests.duoPortrait, hasFold: true, hudOnLeft: hudLeft))
    }

    /// Founder rule (no pose demands, ever): a portrait Duo plays, hinge or not, open or with a stale shut latch;
    /// only the small cover display is the cover.
    @Test func aPortraitDuoNeverShowsAPoseCard() {
        for hinge in [true, false] {
            for shut in [false, true] {
                #expect(AppRules.pose(canvas: PortraitTests.duoPortrait, hingeSeen: hinge, isShut: shut) == .play)
                #expect(AppRules.pose(canvas: PortraitTests.duoBook, hingeSeen: hinge, isShut: false) == .play)
            }
        }
        #expect(AppRules.pose(canvas: CGSize(width: 466, height: 678), hingeSeen: true, isShut: false) == .cover)
        // The portrait canvas turns the scene, keeps its fold, and keeps the HUD on the scene's right lobe.
        #expect(AppRules.turnsScene(PortraitTests.duoPortrait))
        #expect(!AppRules.turnsScene(PortraitTests.duoBook))
        #expect(AppRules.sceneViewSize(PortraitTests.duoPortrait) == PortraitTests.duoBook)
        #expect(AppRules.sceneViewSize(PortraitTests.duoBook) == PortraitTests.duoBook)
        #expect(AppRules.hasFold(canvas: PortraitTests.duoPortrait, hingeSeen: true, demoFold: false,
                                 divisionSeen: true))
        #expect(!AppRules.hudOnLeft(true, canvas: PortraitTests.duoPortrait))
        #expect(AppRules.hudOnLeft(true, canvas: PortraitTests.duoBook))
        // The same landscape scene either way (Core's geometry never changes with the pose).
        let turned = ScreenLayout.make(viewSize: PortraitTests.duoPortrait, hasFold: true)
        let book = ScreenLayout.make(viewSize: PortraitTests.duoBook, hasFold: true)
        #expect(turned == book)
    }

    #if DEBUG
    /// CI: `portrait=1` (and the old pose card's `screen=pose`) lay the app out portrait on a landscape simulator.
    @Test func portraitDemoKeys() {
        #expect(DemoMode.parse("portrait=1").showsPortrait)
        #expect(DemoMode.parse("screen=pose").showsPortrait)
        #expect(DemoMode.parse("screen=play;portrait=1;pilot=expert").showsPortrait)
        #expect(!DemoMode.parse("screen=home").showsPortrait)
        #expect(AppRules.demoTurnsCanvas(PortraitTests.duoBook, demoPortrait: true))
        #expect(!AppRules.demoTurnsCanvas(PortraitTests.duoPortrait, demoPortrait: true))
        #expect(!AppRules.demoTurnsCanvas(PortraitTests.duoBook, demoPortrait: false))
        let i = RootView.turnedInsets(EdgeInsets(top: 1, leading: 2, bottom: 3, trailing: 4))
        #expect(i == EdgeInsets(top: 2, leading: 3, bottom: 4, trailing: 1))
    }
    #endif

    /// The quarter turn: scene point → screen point and back, and where the fold, the trap and the pages land.
    @Test func theTurnMapsTheSceneOntoTheScreen() {
        let c = canvas()
        #expect(c.rotated)
        #expect(near(c.sceneViewSize.width, 951))
        #expect(near(c.sceneViewSize.height, 669))
        // The trap's centre is the screen's centre.
        let mid = c.screenPoint(CGPoint(x: 476, y: 335))
        #expect(near(mid.x, 334.5))
        #expect(near(mid.y, 475.5))
        // Turned clockwise: the scene's top-left corner is the screen's top-right, its bottom-right the bottom-left.
        let topLeft = c.screenPoint(CGPoint(x: 0, y: 670))
        #expect(near(topLeft.x, 669))
        #expect(near(topLeft.y, 0))
        let bottomRight = c.screenPoint(CGPoint(x: 952, y: 0))
        #expect(near(bottomRight.x, 0))
        #expect(near(bottomRight.y, 951))
        // Scene right is screen down (the right lobe is the bottom half); scene up is screen right.
        #expect(c.screenPoint(CGPoint(x: 800, y: 335)).y > mid.y + 300)
        #expect(c.screenPoint(CGPoint(x: 476, y: 600)).x > mid.x + 200)
        // The whole scene covers the canvas, as the turned SpriteView does.
        let all = c.screenRect(CGRect(x: 0, y: 0, width: 952, height: 670))
        #expect(near(all.minX, 0) && near(all.minY, 0))
        #expect(near(all.width, 669) && near(all.height, 951))
        // scenePoint inverts it.
        for p in [CGPoint(x: 700, y: 120), CGPoint(x: 30, y: 640), CGPoint(x: 476, y: 335), CGPoint(x: 900, y: 20)] {
            let back = c.scenePoint(c.screenPoint(p))
            #expect(near(back.x, p.x))
            #expect(near(back.y, p.y))
        }
        // The fold runs across the middle; the trap is tall.
        #expect(near(c.foldMinY, 455.5))
        #expect(near(c.foldMaxY, 495.5))
        #expect(near(c.foldBand.width, 669))
        let t = c.trapRect
        #expect(t.height > t.width)
        #expect(near(t.midX, 334.5))
        #expect(near(t.midY, 475.5))
        // The pages: the top (other) and the bottom (HUD) halves, off the fold.
        #expect(c.otherPage == c.leftPage)
        #expect(c.hudPage == c.rightPage)
        #expect(c.leftPage.maxY <= c.foldMinY)
        #expect(c.rightPage.minY >= c.foldMaxY)
        #expect(!c.isFoldClear(CGRect(x: 100, y: 470, width: 40, height: 10)))
        #expect(c.isFoldClear(CGRect(x: 100, y: 300, width: 400, height: 100)))
        // Book pose is untouched.
        let book = AppCanvas(size: PortraitTests.duoBook, insets: EdgeInsets(),
                             layout: ScreenLayout.make(viewSize: PortraitTests.duoBook, hasFold: true))
        #expect(!book.rotated)
        let bookMid = book.screenPoint(CGPoint(x: 476, y: 335))
        #expect(near(bookMid.x, 475.5))
        #expect(near(bookMid.y, 334.5))
        #expect(near(book.leftPage.height, 669))
    }

    /// The portrait HUD: upright rects in the bottom page's corners, off the fold band, ≥ 8 pt clear of the cilia
    /// (the Scene's own `TrapArt.teeth`, every variety), every hint line fitting its plate.
    @Test func thePortraitHUDIsUprightOffTheFoldAndClearOfTheCilia() {
        for insets in PortraitTests.insetCases {
            for left in [false, true] {
                let c = canvas(insets, hudLeft: left)
                let outline = c.trapOutline()
                #expect(outline.count > 700)
                let l = HUDLayout.make(c)
                for rect in l.ciliaRects {
                    #expect(AppCanvas.clearance(rect, from: outline) >= AppCanvas.ciliaClear)
                    #expect(rect.minX >= -0.5 && rect.maxX <= c.size.width + 0.5)
                    #expect(rect.minY >= -0.5 && rect.maxY <= c.size.height + 0.5)
                }
                for rect in l.textRects + [l.lessonHint, l.lesson, l.pause, l.back] {
                    #expect(c.isFoldClear(rect))
                }
                // The score and the snaps in the bottom page's two corners, the pause button over the score.
                #expect(l.score.minY >= c.foldMaxY)
                #expect(l.snaps.minY >= c.foldMaxY)
                #expect(l.pause.minY >= c.foldMaxY)
                #expect(l.pause.maxY <= l.score.minY + 0.5)
                #expect(l.pause.width >= AppCanvas.minTap)
                #expect(l.score.width >= HUDLayout.portraitScoreMin - 0.5)
                #expect(l.trailing == !left)
                #expect(l.snapsTrailing == left)
                #expect(l.chainTrailing == !left)
                if left {
                    #expect(l.score.maxX < c.size.width / 2)
                    #expect(l.snaps.minX > c.size.width / 2)
                } else {
                    #expect(l.score.minX > c.size.width / 2)
                    #expect(l.snaps.maxX < c.size.width / 2)
                }
                #expect(!l.score.intersects(l.snaps))
                // The glyphs: rows of 7 or 5, every glyph in its row, the numeral over them.
                #expect(HUDLayout.portraitColumns.contains(l.columns))
                #expect(l.snapRows == (HUDLayout.slotCount + l.columns - 1) / l.columns)
                #expect(l.snapRowRects.count == l.snapRows)
                #expect(l.glyph >= HUDLayout.glyphMin)
                #expect(l.snaps.contains(l.numeral))
                for i in 0..<HUDLayout.slotCount {
                    let p = l.glyphCenter(i)
                    let row = l.snapRowRects[min(i / l.columns, l.snapRowRects.count - 1)]
                    #expect(row.insetBy(dx: -0.5, dy: -0.5).contains(p))
                    #expect(!l.numeral.insetBy(dx: 1, dy: 1).contains(p))
                }
                // The hint's two slots hang under the fold, side by side, off the hands; every line fits.
                #expect(!l.hint.intersects(l.lessonHint))
                for plate in [l.hint, l.lessonHint] {
                    #expect(plate.minY >= c.foldMaxY)
                    #expect(plate.width >= HUDLayout.hintMin)
                    #expect(!c.inThumbZone(plate))
                    for line in AppRules.allHintLines {
                        #expect(HintFit.fits(line.text, plateWidth: plate.width, compact: c.isCompact, long: line.long))
                    }
                }
                // "Your trap is tired." and the pause card on the bottom page.
                #expect(abs(l.tired.midX - c.hudPage.midX) < 1)
                #expect(c.hudPage.insetBy(dx: -1, dy: -1).contains(CGPoint(x: l.tired.midX, y: l.tired.midY)))
                #expect(l.card.minY >= c.foldMaxY)
                // A level's goal line: the score's mirror through the centre, on the top page.
                let goal = LevelGoalLayout.rect(c, score: l.score)
                #expect(goal.maxY <= c.foldMinY)
                #expect(c.isFoldClear(goal))
                #expect(!goal.intersects(l.chain))
                // The score sits on the scene's right lobe (the Scene's HUD half), as in book pose.
                let s = c.scenePoint(CGPoint(x: l.score.midX, y: l.score.midY))
                #expect(s.x > c.layout.creaseMaxX)
            }
        }
    }

    /// The menus lay out on the top and bottom pages: the back button top left, headers and columns clear of it.
    @Test func menusLayOutOnTheTopAndBottomPages() {
        for insets in PortraitTests.insetCases {
            let c = canvas(insets)
            let back = HUDLayout.make(c).back
            #expect(c.leftPage.contains(CGPoint(x: back.midX, y: back.midY)))
            #expect(c.isFoldClear(back))
            #expect(c.headerPads(c.leftPage, back: back).leading >= back.width)
            #expect(near(c.headerPads(c.leftPage, back: back).trailing, 0))
            #expect(near(c.headerPads(c.rightPage, back: back).leading, 0))
            #expect(near(c.headerPads(c.rightPage, back: back).trailing, 0))
            #expect(c.columnTop(c.leftPage, back: back) >= back.maxY)
            #expect(near(c.columnTop(c.rightPage, back: back), c.top))
            for page in [c.leftPage, c.rightPage] {
                #expect(c.isFoldClear(page))
                #expect(page.width >= 600)
                #expect(page.height >= 380)
            }
            #expect(!c.isCompact)
            #expect(near(c.hudHalf.minY, c.foldMaxY))
            #expect(near(c.hudHalf.maxY, c.size.height))
            #expect(near(c.otherHalf.maxY, c.foldMinY))
            #expect(c.towardHUD.start == .top)
            #expect(c.towardHUD.end == .bottom)
        }
        // Book pose keeps R7's paddings: 64 pt on the HUD page's header, its column under the back button.
        let book = AppCanvas(size: PortraitTests.duoBook, insets: EdgeInsets(),
                             layout: ScreenLayout.make(viewSize: PortraitTests.duoBook, hasFold: true))
        let lb = HUDLayout.make(book).back
        #expect(near(book.headerPads(book.rightPage, back: lb).trailing, 64))
        #expect(near(book.headerPads(book.leftPage, back: lb).leading, 0))
        #expect(near(book.columnTop(book.hudPage, back: lb), lb.maxY + 10))
        #expect(near(book.columnTop(book.otherPage, back: lb), book.top))
        #expect(book.towardHUD.start == .leading)
        let left = AppCanvas(size: PortraitTests.duoBook, insets: EdgeInsets(),
                             layout: ScreenLayout.make(viewSize: PortraitTests.duoBook, hasFold: true, hudOnLeft: true))
        let ll = HUDLayout.make(left).back
        #expect(near(left.headerPads(left.leftPage, back: ll).leading, 64))
        #expect(near(left.headerPads(left.rightPage, back: ll).trailing, 0))
    }
}

// MARK: - R9: premium menus, first-run clarity, the phone path (design/notes/app-R9.md)

@MainActor
struct RoundNineTests {
    /// "lid" as a word (never "solid" or "valid").
    private func saysLid(_ s: String) -> Bool {
        s.lowercased().split { !$0.isLetter }.contains { $0 == "lid" || $0 == "lids" }
    }

    /// Every level's goal and the result lines Core gives it, in one control.
    private func levelLines(touch: Bool) -> [String] {
        var out: [String] = []
        for spec in LevelBridge.all {
            out.append(LevelWords.goal(spec, touch: touch))
            let runs = [makeRun(mode: .level(spec.id)),
                        makeRun(mode: .level(spec.id), score: 0, bugs: 0, caught: [:], biggest: 0, chain: 0)]
            for r in runs { out.append(LevelWords.outcomeLine(LevelBridge.evaluate(r, spec).line, touch: touch)) }
        }
        out.append(LevelWords.outcomeLine("Out of time. Shut it faster", touch: touch))
        return out
    }

    /// The words a player can read in one control (the HUD plate, the coach, the verdicts, Home, the levels).
    private func playerCopy(touch: Bool) -> [String] {
        var out = levelLines(touch: touch)
        out += AppRules.allHintCopy + AppRules.coachSamples + AppRules.verdictSamples
        out += [LevelWords.startLine(touch: touch), HomeView.subtitle(foldInput: !touch)]
        out += HomeView.rowWords + [HomeView.zenDetail, SettingsView.aboutLine, SettingsView.replayLesson,
                                    SettingsView.hudSideTitle, SettingsView.hudSideDetail, AppRules.freeStingCopy,
                                    AppRules.chainLesson, CloseToStartCard.detail]
        out += (1...3).map { LevelWords.worldLine($0) }
        if let banner = AppRules.startBanner(.feed, touch: touch) { out.append(banner) }
        for preset in [DemoMode.Preset.fresh, .mid, .late] {
            out.append(HomeView.playLine(DemoPresets.progress(preset, today: 299), touch: touch))
        }
        return out
    }

    /// Founder rule: say "phone", never "lid", anywhere a player reads.
    @Test func noPlayerLineSaysLid() {
        var all = playerCopy(touch: false) + playerCopy(touch: true)
        all += [ChompWords.carryOn, ChompWords.openToPlay, ChompWords.openForResults, ChompWords.stingTip,
                ChompWords.stingTipWasp, ChompWords.slowTip, ChompWords.emptyTip, CoverCard.openToStart,
                CoverCard.startDetail, CoverCard.detail(midRun: true), CoverCard.detail(midRun: false),
                HomeView.foldCaption, HomeView.foldDetail]
        for line in all { #expect(!saysLid(line), "says lid: \(line)") }
        #expect(saysLid("Close the lid"))
        #expect(!saysLid("A solid, valid bite"))
    }

    /// R9 (frame 01: "Level 1 · Shut the phone on the fly" on a phone): a phone is never told to close or shut
    /// anything, and the Duo's control lines say "close the phone" (not "shut").
    @Test func phoneCopyNeverSpeaksOfTheHinge() {
        for line in levelLines(touch: true) {
            #expect(!LevelWords.speaksOfTheHinge(line), "phone line: \(line)")
        }
        for preset in [DemoMode.Preset.fresh, .mid, .late] {
            let line = HomeView.playLine(DemoPresets.progress(preset, today: 299), touch: true)
            #expect(!LevelWords.speaksOfTheHinge(line), "phone Play: \(line)")
        }
        for hint in [TrapHint.bendALittle, .quick, .openUp, .beeInside, .crowd, .lastSnap, .hungry] {
            if let t = AppRules.hintText(hint, touch: true) { #expect(!LevelWords.speaksOfTheHinge(t)) }
        }
        let phoneLines: [String?] = [AppRules.hudHintText(.foldInput, touch: true),
                                     AppRules.startBanner(.feed, touch: true), LevelWords.startLine(touch: true),
                                     HomeView.subtitle(foldInput: false)]
        for t in phoneLines { #expect(!LevelWords.speaksOfTheHinge(t ?? "")) }
        for level in 1...5 {
            for sipping in 0...3 {
                for armed in [true, false] {
                    let t = AppRules.coachLine(level: level, sipping: sipping, beeInTrap: false, armed: armed,
                                               touch: true)
                    #expect(!LevelWords.speaksOfTheHinge(t ?? ""))
                }
            }
        }
        // The Duo's own words: "close", never "shut".
        for line in levelLines(touch: false) { #expect(!line.lowercased().contains("shut"), "Duo line: \(line)") }
        // Level 1, both ways.
        if let one = LevelBridge.spec(1) {
            let phone = LevelWords.goal(one, touch: true)
            let duo = LevelWords.goal(one, touch: false)
            #expect(phone == "Tap when the fly lands")
            #expect(duo == "Close the phone on the fly")
        } else {
            Issue.record("no Level 1")
        }
        #expect(LevelWords.inputAware("Catch 2 flies. Shut it fast", touch: true) == "Catch 2 flies")
        #expect(LevelWords.inputAware("Catch 2 flies. Shut it fast", touch: false) == "Catch 2 flies. Close it fast")
        #expect(LevelWords.outcomeLine("Out of time. Shut it faster", touch: true) == "Out of time. Snap sooner")
        #expect(LevelWords.inputAware("One bite, 2 bugs", touch: true) == "One bite, 2 bugs")
        #expect(HomeView.playLine(ProgressData(), touch: true) == "Level 1 · Tap when the fly lands")
    }

    /// R9: a first-time Home is the name, its line and Play; the rank and goals come with progress. Every quiet button
    /// has a word, and its count rides on the icon only once there is one.
    @Test func homeShowsLessToANewPlayer() {
        let fresh = DemoPresets.progress(.fresh, today: 299)
        #expect(!HomeView.showsProgress(fresh))
        #expect(HomeView.showsProgress(DemoPresets.progress(.mid, today: 299)))
        #expect(HomeView.showsProgress(DemoPresets.progress(.late, today: 299)))
        var d = ProgressData()
        _ = LevelRules.record(&d, id: 1, stars: 3)
        _ = LevelRules.record(&d, id: 2, stars: 3)
        #expect(!HomeView.showsProgress(d))
        _ = LevelRules.record(&d, id: 3, stars: 1)
        #expect(HomeView.showsProgress(d))
        var e = ProgressData()
        e.feedRuns = 1
        #expect(HomeView.showsProgress(e))
        #expect(HomeView.rowWords == ["Levels", "Bug Book", "Garden", "Settings"])
        for w in HomeView.rowWords { #expect(w.rangeOfCharacter(from: .decimalDigits) == nil) }
        #expect(HomeView.bookBadge(ProgressData()) == nil)
        #expect(HomeView.gardenBadge(ProgressData()) == nil)
        let mid = DemoPresets.progress(.mid, today: 299)
        #expect(HomeView.bookBadge(mid) == "\(mid.speciesFound)/\(BugSpecies.allCases.count)")
    }

    /// R9 (frame 04: 7 sat on 6 and its stars): no two pads (nor a pad and the next one's glow) meet, on the Duo's
    /// page, a 6.3" phone and an iPhone SE-size phone, and every pad lies in its box.
    @Test func theMapsPadsNeverOverlap() {
        let boxes: [(CGSize, Bool)] = [(CGSize(width: 420, height: 560), false), (CGSize(width: 380, height: 300), true),
                                       (CGSize(width: 290, height: 280), true), (CGSize(width: 620, height: 360), false)]
        for (box, compact) in boxes {
            let pad = LevelMapView.padSize(in: box, compact: compact)
            #expect(pad >= 30)
            // A pad's footprint: its tap frame (at least 44 pt) and its star row under it.
            let w = max(pad, SnapTheme.minTap)
            let h = max(pad * 1.24 + 4, SnapTheme.minTap)
            var rects: [CGRect] = []
            for i in 0..<10 {
                let p = LevelMapView.padCenter(i, in: box)
                let r = CGRect(x: p.x - w / 2, y: p.y - pad / 2, width: w, height: h)
                #expect(r.minX >= -0.5 && r.maxX <= box.width + 0.5, "pad \(i) leaves its box across")
                #expect(r.minY >= -0.5 && r.maxY <= box.height + 0.5, "pad \(i) leaves its box down")
                rects.append(r)
            }
            for i in 0..<10 {
                for j in (i + 1)..<10 {
                    #expect(!rects[i].insetBy(dx: 2, dy: 2).intersects(rects[j]), "pad \(i) meets pad \(j)")
                }
            }
            // The glow round the next pad stays off its neighbours' pads.
            for i in 0..<9 {
                let a = LevelMapView.padCenter(i, in: box)
                let b = LevelMapView.padCenter(i + 1, in: box)
                let gap = ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
                #expect(gap >= pad * 0.72 + pad / 2)
            }
        }
        // The path reads in order: the top row left to right, the bottom row right to left.
        let box = CGSize(width: 400, height: 300)
        for i in 0..<4 { #expect(LevelMapView.padCenter(i, in: box).x < LevelMapView.padCenter(i + 1, in: box).x) }
        for i in 5..<9 { #expect(LevelMapView.padCenter(i, in: box).x > LevelMapView.padCenter(i + 1, in: box).x) }
        #expect(near(LevelMapView.padCenter(4, in: box).x, LevelMapView.padCenter(5, in: box).x))
        #expect(LevelMapView.padCenter(5, in: box).y > LevelMapView.padCenter(4, in: box).y)
        var d = ProgressData()
        #expect(LevelMapView.pathReach(d, world: 1) == 0)
        for id in 1...6 { _ = LevelRules.record(&d, id: id, stars: 2) }
        #expect(LevelMapView.pathReach(d, world: 1) == 6)
        #expect(!LevelMapView.path(in: box).isEmpty)
    }

    /// R9 (frames 08, 62: a perfect pilot scored 0 on Level 1): a level's demo pilot reads the level's goal.
    @Test func aLevelsDemoPilotReadsItsGoal() throws {
        let spec = try #require(LevelBridge.spec(5))
        let p = DemoRunner.pilot(skill: .perfect, seed: 7, mode: .level(5))
        #expect(p.minBite == spec.goal.biteOf)
        #expect(p.targets == spec.goal.species)
        let feed = DemoRunner.pilot(skill: .perfect, seed: 7, mode: .feed)
        #expect(feed.minBite == 0)
        #expect(feed.targets.isEmpty)
        // Played the way the levelResults demo plays it (in half-second slices with one pilot), Level 1 passes.
        let size = CGSize(width: ScreenLayout.canvasWidth, height: ScreenLayout.canvasHeight)
        let session = try #require(LevelBook.session(id: 1, geometry: TrapGeometry(sceneSize: size)))
        var pilot = DemoRunner.pilot(skill: .perfect, seed: session.seed &+ 101, mode: session.mode)
        var played = 0.0
        while played < 120 && !session.isFinished {
            played += DemoRunner.play(session, pilot: &pilot, seconds: 0.5)
        }
        let one = try #require(LevelBridge.spec(1))
        let result = session.partialResult()
        #expect(result.bugsCaught >= 1)
        #expect(LevelBridge.evaluate(result, one).passed)
    }

    /// R9: Settings' About is true on every iPhone; Settings' lesson button is Level 1.
    @Test func settingsSpeakBothControls() {
        #expect(SettingsView.aboutLine.contains("close the phone to bite"))
        #expect(SettingsView.aboutLine.contains("tap to snap"))
        #expect(SettingsView.replayLesson == "Replay Level 1")
    }
}
