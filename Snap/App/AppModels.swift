import Combine
import QuartzCore
import SwiftUI

/// Where the app is.
enum AppRoute: String, Equatable {
    case home, playing, results, book, settings, daily
    /// R6: the Garden (trap varieties).
    case garden
    /// R8: the level map (3 worlds × 10 levels). The First Bite lesson's route is gone: Levels 1–5 teach.
    case levels

    /// The bog is live (a session steps).
    var isPlay: Bool { self == .playing }
    /// R8 ("the living bog as the backdrop"): every menu sits on Home's live attract bog, not a still.
    var showsLiveBog: Bool { self != .playing }
}

/// What the display should show, from the canvas shape, the hinge and the shut latch (AppRules.pose).
/// R8 (founder rule: no pose demands, ever): the pose card is gone; a portrait canvas plays, the scene turned a
/// quarter (`AppRules.turnsScene`).
enum AppPose: String, Equatable {
    /// The game and its screens: the Duo held like a book or like a laptop, flat, any angle; any phone.
    case play
    /// The Duo shut, or the small cover display: "Open to carry on".
    case cover
}

/// Who drives the trap.
enum AppInputKind: String, Equatable {
    case hinge, touch, pilot, fixed
}

/// What the hint plate says: one of Core's hints, or one of the App's own (R3).
enum HUDHint: Equatable {
    case trap(TrapHint)
    /// The first wave of a run: "Snap the halves together" on a Duo, "Tap to snap" on phones (ROUND-3 founder call).
    case foldInput
    /// Sprout's free first sting: "Bees and wasps cost snaps. This one's free!" (REVIEW-3 #3, the founder's copy).
    case beesCost
    /// R4 (REVIEW-3 #10): a player's first chain step ever, once. R6 (#14): the chain explainer, "Chain ×1.5! Big
    /// bites in a row multiply."
    case chainTag(Double)
    /// R6: a goal just completed: "Goal done! A 5-bug bite".
    case goalDone(String)
    /// R6 (Core #19): the late night's telegraph, once each ("The night gets fast…", "Last light…").
    case nightCue(NightCue)
    /// R8 (ROUND-8 §3 clarity): what the last bite did, in plain words ("3 bugs! Fast close", "Too slow, they flew",
    /// "Bee! −1 snap"). `good`: the cream plate; otherwise the crimson one.
    case verdict(String, good: Bool)
    /// R8: a teaching level's one line at the right moment ("Now shut it, fast!").
    case coach(String)
}

/// R8: the level's goal as the HUD shows it (one line, big, on the other page's top outer corner).
struct LevelHUD: Equatable {
    var id: Int
    var goal: String
    /// The goal is met (it ticks; the level ends a beat later).
    var done = false
    /// Seconds left on a timed level (nil: no clock).
    var secondsLeft: Int?
}

/// The HUD values (one value, published only when it changes).
struct HUDValues: Equatable {
    var score = 0
    var best = 0
    var snapsLeft = 0
    var snapsMax = 14
    var chain = 0
    var chainMultiplier = 1.0
    var hint: HUDHint?
    /// The run-start line ("Wait for a crowd. Spare bees."), shown for a beat when no hint is up.
    var banner: String?
    /// "Your trap is tired."
    var tired = false
    /// The score passed the personal best this run.
    var passedBest = false
    var dayPhase: DayPhase = .morning
    /// R8: a level's goal line (nil outside a level).
    var level: LevelHUD?
    /// R8 (founder rule 3): the round waits for the phone to close ("Close the phone to start").
    var waitingForClose = false
    /// R2 hunger: 0 just fed … 1 a snap wilts (the next snap glyph drains with it). Rounded to 1/40.
    var hunger = 0.0
    /// Snaps wilted this run (the scene pops "wilted −1" and droops a glyph at the snaps anchor).
    var wilts = 0
    /// Stings this run (the snaps row flashes crimson when it rises).
    var stings = 0
    /// The teaching levels' pointer rings (scene space; R8: Levels 1–5, where the lesson used them).
    var lessonTargets: [LessonTarget] = []
    /// R3: 3 s before a snap wilts (Core's `hungry` until the next bite or wilt): the draining glyph pulses crimson and
    /// the numeral ticks red.
    var hungry = false
    /// R3 (REVIEW-2 #12): the first Feast's flying glyph is labelled once ("+1 snap"); R5 (REVIEW-4 #7): a costly
    /// sting's cost ("−2 snaps"). R6 (#6): one tag at a time, from the message queue, and never with a plate up.
    var tag: HUDTag?
    /// R6 (#6): the bugs in the trap (screen-space boxes, coarse), while a plate is up: the plate keeps off them.
    var subjectRects: [CGRect] = []
    /// R6 Zen: the snaps never run out, so the row shows its full count quietly. R7 (#10): and the score wears a
    /// "Zen Bog" badge.
    var zen = false
    /// R7 (#5): the toast on the plate has waited `MessageQueue.maxHold` for a spot clear of the bugs: it may now show
    /// in the slot that covers fewest.
    var plateMayCover = false
    /// R3 (Scene #14): the scene's crimson sting flash is crossing the row (`BogScene.snapsRowFlashing`).
    var rowFlashing = false
    /// R4 (REVIEW-3 #3): the free sting: the row flashes green with "free!".
    var freeFlash = false
    /// R4 (REVIEW-3 #10): a clean one-bug bite kept the chain: the chip says "×1.5 held" for a beat.
    var chainHeld = false
    /// R4 (REVIEW-3 #3): the Scene's live score/word pops (scene space, rounded), while a hint is up: the plate keeps
    /// off them.
    var popRects: [CGRect] = []
    /// R4 (REVIEW-3 #19): the other bugs in play while the pointer is on a bee (its arrow steers round them).
    var lessonAvoid: [CGPoint] = []
}

/// A bug the lesson points at (a pulsing ring, and an arrow from the card).
struct LessonTarget: Equatable, Identifiable {
    var id: Int
    var point: CGPoint
    /// A bee: a white "wait" ring instead of the lime "bite" ring.
    var bee: Bool
    var sipping: Bool
}

/// The HUD's state over the scene, published at ≤ 15 Hz (and at once on snaps and hint changes).
@MainActor
final class HUDState: ObservableObject {
    @Published private(set) var values = HUDValues()

    func update(_ fresh: HUDValues) {
        if fresh != values { values = fresh }
    }
}

/// Home's title trap: the live closure (hinge on a Duo, a tap elsewhere) and a counter that ticks on each chomp.
@MainActor
final class HomeTrapState: ObservableObject {
    /// 0 open … 1 snapped.
    @Published private(set) var closure01: Double = 0
    @Published private(set) var chomps = 0

    func update(closure01 fresh: Double, chomped: Bool) {
        let rounded = (min(max(fresh.isFinite ? fresh : 0, 0), 1) * 50).rounded() / 50
        if rounded != closure01 { closure01 = rounded }
        if chomped { chomps &+= 1 }
    }
}

/// Everything the Results screen shows (built once when a run is recorded).
struct ResultSummary: Equatable {
    var result: RunResult
    var outcome: RecordOutcome
    /// "Your trap is tired" ("What a feast!" on a new best), "Daily Bog · 27 Oct", "Daily practice · 27 Oct".
    var title: String
    /// One sentence naming the best moment.
    var story: String
    var rankTitle: String
    var nextRankTitle: String?
    var rankProgressBefore: Double
    var rankProgressAfter: Double
    var againLabel: String
    /// "312 short of your best" (nil on a new best, a first score or an empty run).
    var nearMiss: String?
    /// R8: a level's own result (nil for Endless, the Daily and Zen): Results shows `LevelResultsView` instead.
    var level: LevelResult?
}

/// R8: how a level went, as its Results card shows it.
struct LevelResult: Equatable {
    var id: Int
    var world: Int
    var title: String
    var goal: String
    /// 0…3 this try, and the best ever after it.
    var stars: Int
    var bestStars: Int
    var passed: Bool
    /// Core's line ("Clean! No bee bitten.").
    var line: String
    /// The level to play next (nil: the last level, or the next world is still shut).
    var next: Int?
    /// This try opened a world (its number).
    var worldOpened: Int?
}

/// R8: the bite the outer display shows while the Duo is shut (the CHOMP card).
struct ChompInfo: Equatable {
    var caught: [BugSpecies]
    var stingers: [BugSpecies]
    var escaped: Int
    var points: Int
    /// The snaps the bite cost beyond its own one (a sting).
    var snapsLost: Int
    var snapsBack: Int
    /// The run's score after the bite.
    var score: Int
    /// The plain words ("3 bugs! Fast close").
    var verdict: String

    enum Kind: Equatable { case catchBite, sting, dry }

    var kind: Kind {
        if !stingers.isEmpty { return .sting }
        return caught.isEmpty ? .dry : .catchBite
    }

    init(caught: [BugSpecies], stingers: [BugSpecies] = [], escaped: Int = 0, points: Int, snapsLost: Int = 0,
         snapsBack: Int = 0, score: Int, verdict: String) {
        self.caught = caught
        self.stingers = stingers
        self.escaped = escaped
        self.points = points
        self.snapsLost = snapsLost
        self.snapsBack = snapsBack
        self.score = score
        self.verdict = verdict
    }

    init(_ r: BiteReport, score: Int) {
        self.init(caught: r.caught, stingers: r.stingers, escaped: r.escaped, points: r.points, snapsLost: r.snapsLost,
                  snapsBack: r.snapsBack, score: score, verdict: AppRules.biteVerdict(r).text)
    }
}

/// Demo `closure=`: the drawn closure held at a number of degrees (no hinge, no pilot): static frames of the jaws.
@MainActor
final class FixedTrapSource: TrapSource {
    var closure: Double = 0

    func input(at time: TimeInterval) -> TrapInput {
        let c = closure.isFinite ? max(closure, 0) : 0
        return TrapInput(closure: c, armed: c < AppRules.heldClosureArmedBelow, creeping: false, snap: nil,
                         tooFlat: false, angle: nil)
    }
}

/// A display-link tick (Home's live title trap: the scene is not on screen there).
@MainActor
final class AppFrameTicker: NSObject {
    private var link: CADisplayLink?
    private let tick: @MainActor (TimeInterval) -> Void

    init(_ tick: @escaping @MainActor (TimeInterval) -> Void) {
        self.tick = tick
    }

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        tick(link.timestamp)
    }
}
