# Snap: architecture and module contracts

The types that modules share live in `Snap/Shared/Contracts.swift`, which the founder owns. This file sets out who
owns what, and the exact API each module must expose, so that the others can compile against it **without a compiler
on our side**. CI on GitHub's macOS runner is our only compiler.

**Rules**
- Swift 5 language mode, iOS 18 deployment target, built with Xcode 27.1 and the iOS 27.1 SDK.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Everything that touches views, nodes, audio or haptics is `@MainActor`.
- Core is plain value types plus final classes, with no actor isolation and no UIKit, SpriteKit or SwiftUI imports.
  Core may import Foundation and CoreGraphics only.
- No third-party packages.
- Every type and function listed here must exist with **exactly** this signature. You may add more, but not rename.
- The Xcode target is `Snap`, the test target `SnapTests`. The product name shown to players comes from the name check
  (`CFBundleDisplayName`), so never hard-code the product name in Swift: use `AppBrand.name` (App, `Snap/App/AppBrand.swift`).

## The frame loop

```
SpriteView(BogScene)                       ← SwiftUI hosts SpriteKit, preferredFramesPerSecond = 120
  BogScene.update(currentTime)
    → driver.advance(dt:now:)              ← GameController (App), the hub
         input  = source.input(at: now)        (HingeTrapSource on a Duo, TouchTrapSource elsewhere; TrapPilot in attract/CI)
         events = session.step(dt, input)      (Core: TrapSession, sub-steps at ≤ 1/120 s)
         feedback.handle(events, telemetry)    (Feedback: FeedbackDirector)
         publish HUD state at ≤ 15 Hz to SwiftUI (plus at once on snaps)
    ← (snapshot, events)
    BogScene draws the bog, the two lobes (closure from the snapshot), nectar, bugs, FX for the events
  BogScene.touchesBegan → driver.sceneTapped(at:time:) → GameController → TouchTrapSource.tap (no hinge only)
```
`dt` is clamped to ≤ 1/30 s by the driver. The game pauses (no stepping) while the phone is closing
(θ < 50° for 0.6 s), the app is inactive, or the pause menu is open.

## Module ownership

| Module | Folder | Owner |
|---|---|---|
| Contracts | `Snap/Shared/` | founder |
| Core rules, bugs, waves, pilot, snap detector | `Snap/Core/` | **Core engineer** |
| Scene (SpriteKit) and bug/trap art | `Snap/Scene/` | **Scene engineer** |
| Input (hinge, touch) and Feedback (audio synth, haptics) | `Snap/Input/`, `Snap/Feedback/` | **Feel engineer** |
| App shell, UI, persistence, Game Center, demo mode | `Snap/App/`, `Snap/UI/`, `Snap/Persistence/` | **App engineer** |
| Tests | `SnapTests/` | each engineer writes `SnapTests/<Module>Tests.swift` |
| CI | `.github/`, `ci/`, `project.yml` | CI engineer (founder reviews) |

An engineer only writes inside their own folders. If you need something from another module that isn't listed
below, don't invent it: write a note in `design/NEEDS.md` and use a local `private` stand-in.

## Core API (Core engineer)

```swift
/// SplitMix64. Deterministic everywhere.
struct SeededRandom { init(seed: UInt64); mutating func next() -> UInt64; mutating func unit() -> Double /* [0,1) */
                      mutating func range(_ r: ClosedRange<Double>) -> Double; mutating func int(_ r: ClosedRange<Int>) -> Int }

enum Tuning { /* every number from GAME-DESIGN §3–§6 as static lets, documented; nothing hard-coded elsewhere */
    // at least these (used by other modules):
    static let snapDepth: Double          // 22   closure ° at which the bite fires
    static let snapStartDepth: Double     // 4    closure ° that starts the snap timer
    static let creepDepth: Double         // 6
    static let creepDwell: Double         // 0.45 s
    static let rearmRise: Double          // 16   ° above the snap's lowest point
    static let rearmAngle: Double         // 150
    static let refWindow: Double          // 0.6  s (rest reference = max θ over this window)
    static let refFallRate: Double        // 25   °/s max fall of the reference
    static let tooFlatAngle: Double       // 174
    static let closingAngle: Double       // 50   θ < this for closingDwell = pause
    static let closingDwell: Double       // 0.6
    static let touchSnapTime: Double      // 0.09 s
    static let touchRearmDelay: Double    // 0.45 s
    static let startSnaps: Int            // 10
    static let maxSnaps: Int              // 12
}

/// The pure snap rule (GAME-DESIGN §3), used by HingeTrapSource and the tests. Feed it filtered angle samples.
struct SnapDetector {
    init()
    /// Feed one (filtered) angle sample at `time`. Returns a trigger on the sample where closure passes snapDepth.
    mutating func ingest(angle: Double, at time: Double) -> SnapTrigger?
    /// The input for a frame at `time` (closure, armed, creeping, tooFlat; `snap` is whatever `ingest` last returned
    /// and has not been consumed — consumed by this call).
    mutating func input(at time: Double) -> TrapInput
    var reference: Double { get }         // the rest reference θ
    var armed: Bool { get }
}

enum BugCatalog { static let all: [BugInfo] /* exactly 16, in BugSpecies.allCases order */
                  static func info(_ s: BugSpecies) -> BugInfo }

/// The wave recipes (GAME-DESIGN §6). Deterministic: the same (seed, index) gives the same wave.
struct WaveSpec: Equatable { var index: Int; var phase: DayPhase; var delay: Double /* s after the previous wave */
                             var bugs: [SpawnSpec] }
struct SpawnSpec: Equatable { var species: BugSpecies; var entry: CGPoint /* scene space, on/just off an edge */
                              var target: CGPoint /* landing spot (a nectar drop or a spot), scene space */
                              var linger: Double; var landsInTrap: Bool; var groupOffset: Double /* s, swarms/lines */ }
enum WaveFactory {
    static func wave(seed: UInt64, index: Int, geometry: TrapGeometry, nectar: [NectarDrop]) -> WaveSpec
    static func phase(forWave index: Int) -> DayPhase
    static func nectar(seed: UInt64, geometry: TrapGeometry) -> [NectarDrop]   // 5–7 drops, re-seeded every 6 waves
}

struct SessionOptions: Equatable {
    var snapsRunOut: Bool = true      // false: attract, lesson
    var waves: Bool = true            // false: the lesson spawns by script only
    var stingCosts: Bool = true       // false: the lesson
    init(snapsRunOut: Bool = true, waves: Bool = true, stingCosts: Bool = true)
    static func `for`(_ mode: RunMode) -> SessionOptions
}

final class TrapSession {
    init(mode: RunMode, seed: UInt64, best: Int, geometry: TrapGeometry, options: SessionOptions)
    let mode: RunMode
    let seed: UInt64
    /// One frame. Returns this step's events in order.
    func step(dt: Double, input: TrapInput) -> [TrapEvent]
    /// The lesson: put one bug in now (it flies in from `entry` and lands on `target`). `linger` .infinity = stays.
    @discardableResult func spawnScripted(_ species: BugSpecies, entry: CGPoint, target: CGPoint, linger: Double) -> Int
    var snapshot: TrapSnapshot { get }
    var isFinished: Bool { get }
    var result: RunResult? { get }   // non-nil once finished
}

enum DailySeed {
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> Int   // days since 2026-01-01
    static func seed(day: Int) -> UInt64
}

enum PlantRanks {
    static let count: Int                                   // 12
    static func rank(forLifetimeBugs bugs: Int) -> Int      // 0…11
    static func title(_ rank: Int) -> String                // "Sprout" … "Bog Monarch"
    static func threshold(_ rank: Int) -> Int
}

enum Achievements {   // ids are Game Center ids too: "snap.ach.<key>"
    static let all: [AchievementDef]                        // exactly 12
    static func earned(after run: RunResult, lifetimeBugs: Int, lifetimeSpared: Int, speciesFound: Int,
                       alreadyEarned: Set<String>) -> [AchievementDef]
}
struct AchievementDef: Hashable { let id: String; let title: String; let detail: String }

enum PilotSkill: String, CaseIterable { case novice, casual, expert, perfect }
/// A simulated player: drives the closure (so the scene shows the jaws moving) and fires snaps.
struct PilotOutput: Equatable { var input: TrapInput }
struct TrapPilot {
    init(skill: PilotSkill, seed: UInt64)
    mutating func step(dt: Double, time: Double, snapshot: TrapSnapshot) -> PilotOutput
}
```

**TrapSession behaviour** (GAME-DESIGN §4–§6):
- Waves start at t = 1.2 s, then every `delay`. Each spawn flies from `entry` towards `target` (ease-in, 160–320 pt/s
  by species, with wobble), lands, walks/sips for `linger`, then leaves towards the nearest edge. Grasshoppers and
  crickets hop between spots (they may cross the fold). Ants walk in from the bottom edge in a line and never fly.
- A bug is `inTrap` when `geometry.contains(position)` and it isn't leaving; `onRim` likewise.
- **Bite** (on the frame `input.snap` is non-nil, while `.playing`): every bug with `inTrap` and an activity in
  {arriving (height < 0.6), walking, sipping, hopping} is a candidate. Its reaction is computed with the GAME-DESIGN §4
  formula (flying = arriving or hopping). `duration ≤ reaction` → caught (protected → released + `stung`); else escaped.
  Then the snap cost, refunds, score, chain (GAME-DESIGN §5). Emit `snapped` first, then the per-bug events, then
  feast/lucky/chain/drySnap/lastSnap/tired/newBest.
- **Creep**: on each frame with `input.creeping`, every bug in the trap whose `nerve ≤ input.closure` leaves
  (`bugSpooked`).
- A protected bug that was in the trap (landed) and leaves uneaten emits `beeSpared` once.
- **Tired:** snaps 0 → `.tired(elapsed:)` for 2.2 s (no new waves, bugs leave) → `.finished`, `result` set.
- **Hint priority:** bendALittle > quick > openUp > beeInside > lastSnap > crowd.

## Input API (Feel engineer)

```swift
@MainActor final class HingeTrapSource: TrapSource {   // fed by HingeReader samples
    init()
    func ingest(angleDegrees: Double, at time: TimeInterval)
    var hasHinge: Bool { get }                       // true once any real sample arrived (never goes back to false)
    var angle: Double? { get }                       // filtered hinge angle (180 = flat)
    var isClosing: Bool { get }                      // filtered angle < Tuning.closingAngle for Tuning.closingDwell
    func input(at time: TimeInterval) -> TrapInput
}
@MainActor final class TouchTrapSource: TrapSource { // the no-hinge fallback: tap to snap
    init()
    func tap(at time: TimeInterval)                  // snaps if armed (auto re-arms after Tuning.touchRearmDelay)
    func input(at time: TimeInterval) -> TrapInput   // closure animates 0 → 22 → 0 for the drawn jaws
}
struct HingeReader: ViewModifier                     // copy of Swoop's: (angle°, time) + onUnavailable
enum FeelDemoLog { static let isEnabled: Bool; static func line(_ s: String) }   // `SNAP-T …` lines, DEBUG + -snapDemo only
```
- The hinge path: raw samples → One-Euro filter (copy Swoop's `FeelFilters.swift`) → `SnapDetector.ingest` per
  sample (snap timing uses sample times, not frames). Between samples, `input(at:)` reports the latest state; a
  prediction step (Swoop's `HingePredictor`) may feed the drawn closure only, never the snap rule.
- **Latency matters.** The filter must not add more than ~15 ms of lag on a fast close: use a high beta. A snap of
  25° in 0.12 s at 30 Hz (4 samples) must fire on the sample that crosses 22°.

## Feedback API (Feel engineer)

```swift
@MainActor final class FeedbackDirector: FeedbackSink {
    static let shared: FeedbackDirector
    func start()                                      // audio session + engines (idempotent)
    var soundOn: Bool; var hapticsOn: Bool; var respectSilentSwitch: Bool
    var idle: Bool                                    // menus: the engine naps when quiet
    func handle(_ events: [TrapEvent], telemetry: TrapTelemetry)
    func uiTap(); func uiConfirm(); func celebrate()  // menus, rank up, new Bug Book page
    func silence()                                    // fade the continuous layers out (pause, menus)
    func homeTrap(closure: Double, snapped: Bool)     // Home's title trap follows the hinge and chomps too
}
```

## Scene API (Scene engineer)

```swift
@MainActor final class BogScene: SKScene {
    init(layout: ScreenLayout)                        // scene.size = layout.size; scaleMode .aspectFill
    weak var driver: SceneDriver?
    var reduceMotion: Bool
    var layout: ScreenLayout                          // settable (a hinge appears later / HUD side changes)
    func reset()                                      // new session: clear FX
}
/// The trap, bugs and nectar drawn with CoreGraphics paths, so SwiftUI (Home, Bug Book, icon) and SpriteKit share one
/// art source.
enum TrapArt {
    /// The bug body silhouette (centred at the origin, facing right = +x), `radius` = BugInfo.radius.
    static func bugBody(_ s: BugSpecies, radius: CGFloat) -> CGPath
    static func bugWings(_ s: BugSpecies, radius: CGFloat) -> CGPath
    static func bugColors(_ s: BugSpecies) -> (body: RGBA, accent: RGBA, wing: RGBA, eye: RGBA)
    /// One lobe (side −1 left, +1 right) of the trap for `geometry`, `closure01` 0 open … 1 snapped (teeth lean in).
    static func lobePath(side: Int, geometry: TrapGeometry, closure01: CGFloat) -> CGPath
    static func teethPath(side: Int, geometry: TrapGeometry, closure01: CGFloat) -> CGPath
    static let palette: SnapPalette
}
struct SnapPalette { let bog: RGBA; let bogDeep: RGBA; let moss: RGBA; let lobeOuter: RGBA; let lobeInner: RGBA
                     let lobeGloss: RGBA; let rim: RGBA; let teeth: RGBA; let nectar: RGBA; let gold: RGBA
                     let danger: RGBA; let text: RGBA; let ink: RGBA }
```
The scene draws only from snapshots and events. It owns cosmetic state: wing flaps, shadows, juice splats, the jaw
slam, dew, light, camera shake and score pops. It never changes game state. Every touch-began goes to
`driver.sceneTapped(at:time:)` in scene space.

## App API (App engineer)

- **`GameController`** (`@MainActor ObservableObject`, `SceneDriver`) owns the session, the trap source (hinge, touch
  or pilot) and the feedback, and exposes HUD state to SwiftUI.
- **`AppBrand`**: `enum AppBrand { static let name: String /* from CFBundleDisplayName */ }`.
- **Persistence.** `ProgressStore` and `SettingsStore` keep versioned JSON in UserDefaults.
- **Demo mode** (DEBUG and CI) is turned on by the launch argument `-snapDemo "key=value;key"`. The keys are
  documented at the top of `Snap/App/DemoMode.swift` and in `design/ROUND-1.md`.
- **Log lines CI greps** all start with `SNAP-`:
  - `SNAP-T` for timing, demo and events;
  - `SNAP-H <t> <angle>` for hinge samples, at most 10/s.
  - `SNAP-T frame 120` is printed once the scene has drawn 120 frames.
- **Orientation:** landscape only on phones; on the Duo, play is landscape (book pose). A portrait inner display
  (tabletop) shows the pose card "Hold it open like a book". Copy Swoop's `OrientationLock.swift` and its plist set.
