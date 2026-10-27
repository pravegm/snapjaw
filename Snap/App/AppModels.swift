import Combine
import QuartzCore
import SwiftUI

/// Where the app is.
enum AppRoute: String, Equatable {
    case home, playing, lesson, results, book, settings, daily

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

/// The HUD values (one value, published only when it changes).
struct HUDValues: Equatable {
    var score = 0
    var best = 0
    var snapsLeft = 0
    var snapsMax = 12
    var chain = 0
    var chainMultiplier = 1.0
    var hint: TrapHint?
    /// The run-start line ("Wait for a crowd. Spare bees."), shown for a beat when no hint is up.
    var banner: String?
    /// "Your trap is tired."
    var tired = false
    /// The score passed the personal best this run.
    var passedBest = false
    var dayPhase: DayPhase = .morning
    /// Lesson runs hide the score and snaps.
    var lesson = false
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
