import Combine
import QuartzCore
import SwiftUI

/// Where the app is.
enum AppRoute: String, Equatable {
    case home, playing, lesson, results, book, settings, daily
    /// R6: the Garden (trap varieties).
    case garden

    /// The bog is live (a session steps).
    var isPlay: Bool { self == .playing || self == .lesson }
}

/// What the display should show, from the canvas shape, the hinge and the shut latch (AppRules.pose).
enum AppPose: String, Equatable {
    /// Landscape (the Duo held like a book, or any phone turned sideways): the game and its screens.
    case play
    /// Portrait on a Duo (tabletop) or a phone held upright: "Hold it open like a book".
    case pose
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
    /// Lesson runs hide the score and snaps.
    var lesson = false
    /// R2 hunger: 0 just fed … 1 a snap wilts (the next snap glyph drains with it). Rounded to 1/40.
    var hunger = 0.0
    /// Snaps wilted this run (the scene pops "wilted −1" and droops a glyph at the snaps anchor).
    var wilts = 0
    /// Stings this run (the snaps row flashes crimson when it rises).
    var stings = 0
    /// The lesson's pointer rings (scene space).
    var lessonTargets: [LessonTarget] = []
    /// R3: 3 s before a snap wilts (Core's `hungry` until the next bite or wilt): the draining glyph pulses crimson and
    /// the numeral ticks red.
    var hungry = false
    /// R3 (REVIEW-2 #12): the lesson shows the snaps row from step 3, and rings it on its last card.
    var lessonSnaps = false
    var ringSnaps = false
    /// R3 (REVIEW-2 #12): the first Feast's flying glyph is labelled once ("+1 snap"); R5 (REVIEW-4 #7): a costly
    /// sting's cost ("−2 snaps"). R6 (#6): one tag at a time, from the message queue, and never with a plate up.
    var tag: HUDTag?
    /// R6 (#6): the bugs in the trap (screen-space boxes, coarse), while a plate is up: the plate keeps off them.
    var subjectRects: [CGRect] = []
    /// R6 Zen: the snaps never run out, so the row shows its full count quietly.
    var zen = false
    /// R3 (Scene #14): the scene's crimson sting flash is crossing the row (`BogScene.snapsRowFlashing`).
    var rowFlashing = false
    /// R4 (REVIEW-3 #3): the free sting: the row flashes green with "free!".
    var freeFlash = false
    /// R4 (REVIEW-3 #10): a clean one-bug bite kept the chain: the chip says "×1.5 held" for a beat.
    var chainHeld = false
    /// R4 (REVIEW-3 #3): the Scene's live score/word pops (scene space, rounded), while a hint is up: the plate keeps
    /// off them.
    var popRects: [CGRect] = []
    /// R4 (REVIEW-3 #19): the other bugs in play while the lesson points at a bee (its arrow steers round them).
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
    /// "Your trap is tired", "Daily Bog · 27 Oct", "Daily practice · 27 Oct".
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
}

/// Demo `closure=`: the drawn closure held at a number of degrees (no hinge, no pilot): static frames of the jaws.
@MainActor
final class FixedTrapSource: TrapSource {
    var closure: Double = 0

    func input(at time: TimeInterval) -> TrapInput {
        let c = closure.isFinite ? max(closure, 0) : 0
        return TrapInput(closure: c, armed: c < Tuning.snapStartDepth, creeping: false, snap: nil, tooFlat: false,
                         angle: nil)
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
