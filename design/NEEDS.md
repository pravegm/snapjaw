# Needs between modules

Engineers: add a dated line when you need something another module does not expose.

- 2026-10-27 Feel → App: `TrapTelemetry` carries no scene width, so event positions can't be panned on wide phones.
  Worked around with `FeedbackDirector.sceneWidth` (additive); please set it from `ScreenLayout.size.width`, and set
  `FeedbackDirector.deviceHasFold = true` once a hinge is seen. Details in `design/notes/feel-R1.md`.
- 2026-10-27 Feel → Scene (optional, R2): `TrapInput.closure` steps at the hinge report rate (it is the detector's, so
  Core's creep rule stays truthful). For smoother teeth, `HingeTrapSource.predictedAngle(at:)` exists (drawing only).
- 2026-10-27 App → Core (R2, optional): `TrapSession` has no `partialResult()` for a run left early (Home, Restart, a
  kill in the background). The App tallies the run's events itself (`RunTally` in `Snap/App/AppRules.swift`) so the
  Bug Book and rank never lose those bugs; a Core-side partial result would be the single source of truth.
- 2026-10-27 App → Founder (contract): the App uses three additive APIs beyond ARCHITECTURE: Core's
  `SessionOptions.firstWave` (demo `wave=`), Feel's `FeedbackDirector.sceneWidth` / `deviceHasFold` and
  `HingeTrapSource.reset(at:)` / `reference` (as asked in feel-R1). Worth adding to ARCHITECTURE so nobody renames them.
- 2026-10-27 App → Feel: `homeTrap(closure:snapped:)` gets the closure in DEGREES (the TrapInput unit), like
  `TrapTelemetry.closure`.
- 2026-10-27 Core → App: `TrapSession.partialResult()` now exists (the counters so far; equals `result` once
  finished), so `RunTally` can defer to it in R2. `SessionOptions.firstWave` is in Core as the App uses it.
- 2026-10-27 Core → Founder (R2 decision): patient play never ends. Clean 3+ bites are snap-neutral, so expert/perfect
  pilots hit the 10-minute cap once the night fills with bees. A "wilt" rule (−1 snap after 15 s without a bite)
  ends perfect runs at ~5.8 min in the sim but needs a TrapEvent + hint. Data in `design/notes/core-R1.md`.
- 2026-10-28 Feel → Core (QA-1 #5, R2): please re-seed `SnapDetector`'s slow creep reference (`slow`) to θ — i.e.
  `slow.reset(time:angle:)` — on **every sample** while a "quiet" spell lasts, and start/extend a quiet spell of 0.6 s
  (a) at the first sample, (b) at every re-arm, (c) on any sample where θ is above the previous sample and ≥ 1° above
  the lowest θ of the last 0.25 s (rising), (d) on any sample with θ ≥ `Tuning.tooFlatAngle`. No `creepSince` while
  quiet. Mirror it in `tools/balance-sim.js` (detector=1). Until then Feel's `FeelCreepGuard` (Snap/Input/FeelFilters)
  vetoes the detector's creep in `HingeTrapSource` (creep reported only when both agree), so either order works.
  Optional, same file: clamp a trigger's `duration` to ≥ 1/30 s (Feel already does it in `HingeTrapSource.sane`).
- 2026-10-28 Feel → CI: CREEP-FAST in Duo sim run 40603497021 got **no hinge reports at all** (no `SNAP-H` line from
  t = 805.4 s to 925.7 s; all three `hinge sweep` calls "exited non-zero" after ~25–55 s), so "max closure 0.0°" is
  the CLI, not the trap (it stayed armed at 155.6°). Please mark a creep/snap check INCONCLUSIVE when its window has
  no `SNAP-H` line, and retry a failed sweep once. The 160→128 jump arrived after the window closed (the 925.7 s snap).
- 2026-10-28 Core → Scene + App/UI: `BugInfo.radius` is now the R1 art radius × 1.8 (`Tuning.bugRadiusScale`;
  housefly 25.2, gnat 12.6, dragonfly 43.2). `BogBugs.radius(_:)` and `TrapDrawing` already read it, so the art grows
  ×1.8 with no change: **do not multiply by 1.8 again**. `TrapArt.defaultRadius` (the fallback) still holds R1 sizes.
- 2026-10-28 Core → Feel: QA-1 #5 (creep after reopening) and #6 (stale attempt after a drift) are fixed inside
  `SnapDetector` (Core owns the file): the creep reference follows θ while it rises and for 0.6 s after the peak
  after a re-arm, the first sample or a too-flat θ; an attempt's start moves up while the closure rises < 4° per
  0.25 s. `HingeTrapSource` needs no workaround. Details in `design/notes/core-R2.md`.
- 2026-10-28 Core → App: `SessionOptions.startSnaps: Int?` (nil = 10; pass 12 while Sprout) and `hunger: Bool`
  (default true; only runs with `snapsRunOut` ever wilt, so the lesson and attract never do). `chainUp` now fires only
  for clean bites of ≥ 2; a clean 1-bug bite holds the chain silently. Nectar is 6–8 drops in clusters of 2–3.
