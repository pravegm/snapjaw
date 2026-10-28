# Scene R8: the phone IS the trap

Brief: `design/ROUND-8.md` §1 and the Scene owner line. Files: `Snap/Scene/*` and `SnapTests/SceneTests.swift` only.
**Not compiled locally.** CI is the compiler, and it compiles this together with Core's R8 contract
(`TrapSnapshot.shut`).

## New and changed APIs (read these first)

**For App (action needed):**
- **`BogScene.usesHinge: Bool`** (new; default `false` = touch). There was no input-kind flag in the Scene (the input
  kind lives in App: `AppInputKind`, `GameController.input`). **App must set it** on the play, lesson and Home scenes
  from its input kind (`input == .hinge`), and again whenever the kind changes. Until App sets it, the Duo keeps the R7
  look (the lobes draw shut with the hinge).
- `BogScene.drawnClosure` (changed meaning only): still degrees from the open reference. With the hinge it now runs
  0 … about 150 and drives only the cues. App can keep feeding it from `HingeTrapSource.predictedAngle(at:)`.

**Read-outs (tests, App, demo frames):**
- `BogScene.closingCue`, `rimShadow`, `edgeDim`, `bugPanic` (all `CGFloat` 0 … 1; all 0 with touch).
- `BogScene.panic(ofBug:) -> CGFloat?`, `panicJitter(ofBug:) -> CGPoint?`, `isDrawn(bug:) -> Bool`.
- `BogScene.digestPending: Bool`, `digestsShown: Int`, `juiceStains: Int`, `remainsShowing: Int`.
- `BogScene.digestFallback = 0.35` (wall s), `BogScene.isSnap(_:)`, `BogScene.isBitePart(_:)` (exhaustive over
  `TrapEvent`: **a new `TrapEvent` case from Core must be added there and in `handle`**).
- `TrapArt.closingCue(_ closure: Double) -> CGFloat`, `cueLeanAngle`, `rimShadow`, `edgeDim`, `panicLevel`, and the
  constants `cueStart` 3°, `cueFull` 120°, `cueLean` 100°, `rimShadowMax` 0.9, `edgeDimMax` 0.96, `panicGain` 1.4.
- `BogJaws.update(…, cue:)` (new defaulted parameter), `BogJaws.cueLevel`, `rimShadow`.
- `BogBugLayer.update(…, panic:, hideCaught:)` (new defaulted parameters), `panicOf`, `jitterOf`, `isDrawn`,
  `BogBugLayer.panicJitter` 0.14.
- `BogEffects.digest(at:radius:tint:)`, `activeStains`, `activeRemains`, `BogEffects.digestLife` 3 s,
  `remainsColor`, `remainsPerBug` 4.
- `BogTextures.closingDim` (new texture, warmed).

**From Core (read as written):** `snapshot.shut` (true from the bite until re-armed) and `snapshot.closure` (degrees,
0 … ~150). `BiteReport.catchRatio` is not used by the Scene. `Tuning.snapDepth` is still used for touch's drawn sweep
(`TrapArt.closure01`) and by the tests; if Core removes it, the Scene and SceneTests need a constant of their own.

No new log lines.

## 1. With the hinge, the jaws never animate shut

`BogScene.draw` passes `closure01` 0 to `BogJaws` when `usesHinge`, so there is no foreshortening, no hinge lean and no
hinge darkening. A hinge bite never calls `jaws.slam()`, `light.pulse()`, the hit-stop, the white flash, the impact
puff or the FEAST gulps. Caught bugs are never drawn (`hideCaught`): they were eaten as the phone shut, out of sight.
`.rearmed` still springs the lobes (a small overshoot > 1, the reopen's bounce, never a closing).

## 2. The closing cues follow the closure

`cue = TrapArt.closingCue(closure)` is linear from 3° (under the hinge's ~5° noise) to full at 120°:

| closure | cue | edge dim | rim shadow | cilia reach | panic |
|---|---|---|---|---|---|
| 10° | 0.06 | 0.06 | 0.05 | 0.99 | 0.08 |
| 40° | 0.32 | 0.30 | 0.28 | 0.85 | 0.44 |
| 80° | 0.66 | 0.63 | 0.59 | 0.41 | 0.92 |
| 120° | 1 | 0.96 | 0.9 | −0.17 (leaning in) | 1 |

- **Cilia lean in:** the lean is `max(hinge, bite, cue × 100°)`. They also darken a little (+0.3 × cue).
- **Rim shadow:** the narrow closure shade (it lies round the rim) is at least `0.9 × cue`. The rim light, the gloss and
  Golden Glow's twinkles dim with the cue as they do with the shut.
- **Edges dim:** a new never-shaken sprite (`closingDim`, z 55: over the bugs and FX, under the pops and glyphs) with a
  radial texture that is opaque at the edges and a faint veil (12 %) in the middle, at alpha `0.96 × cue`.
- **Bugs panic:** sitters (walking, sipping) in the trap get `panic = min(1.4 × cue, 1)`. They jitter on the spot
  (± 0.14 r, visual only: Core keeps the position and decides who flees), twitch, and buzz their wings half open
  (blurred on the fast fliers). Reduce Motion halves the jitter.

## 3. The digest on the reopen

In a hinge frame with `.snapped`, the bite's events (`isBitePart`: snapped, caught, escaped, stung, dry, feast, lucky,
chain up/broken, new best) are held, with the snaps left before them and where each stinger was drawn. The rest of the
frame is handled now. The held bite plays (`handle(…, digest: true)`) on the first frame after `shut` was seen true and
is false again: the re-arm, as the phone opens. If the snapshot never shows the phone shut (a pilot, a Core without
`shut`), it plays after `digestFallback` (0.35 wall s). A second bite before the reopen plays the first at once. Touch
never holds.

The digest draws:
- a gold juice stain (a splat tinted with `juiceColor`, 2.6 r) and four remains per caught bug: three dark flecks and
  one pale wing scrap, held for 3 s of session time, then fading;
- the usual pops ("+12", "3 bugs · +360", "Stung!", "Bzzt!", "Missed!", lucky and held lines, "New best!"), the
  FEAST banner, burst and sparkles, the glyph flights and the row flourish, and a camera punch (the FEAST also gets
  half its shake). There are no escape whiffs (the escapers fled on screen during the close).

## 4. Touch

`usesHinge` false: everything is as in R7 (the sweep, the slam, the hit-stop, the gulps, the pops at the bite). No cues,
no dim, no panic.

## Tests (`SceneTests`)

- **Deleted** (they asserted the hinge-driven shut): `closureTracksTheHandsAndTheApp`, and the scene half of
  `theReleaseIsCrimsonWithinEightyMs` (the hands holding the shut through the release and the re-close darkening).
  Its static slam-envelope checks stay.
- `closureTracksAndTheBiteSlams` now says it is touch (`usesHinge` false by default).
- **New:**
  - `withTheHingeTheLobesStayOpen`: drawn closure 0, lobe scale 1, no slam and no closed trap at 0–175° and through
    a bite at the shut; no pop and no caught bug while shut.
  - `theClosingCuesFollowTheClosure`: the thresholds above, everything monotonic in the closure, and nothing with touch.
  - `theDigestPlaysOnTheReopen`: a six-bug FEAST shows nothing while shut; on `shut` → false: six stains, 24 remains,
    the banner and the callout, no slam, hit-stop, flash or gulp; the stains fade after 3 s.
  - `aBiteNeverWaitsForeverAndTouchNeverWaits`: the fallback, and touch's instant pop and slam.
