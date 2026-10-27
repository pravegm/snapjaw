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
