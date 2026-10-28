# Scene R4 hand-off (Scene engineer)

Only `Snap/Scene/` (one new file, `TrapArtPose.swift`) and `SnapTests/SceneTests.swift` changed. Nothing is compiled
yet. I re-read every touched file twice for compile errors (CGFloat/Double, MainActor isolation, labels, exhaustive
switches, no rethrowing or key-path calls inside `#expect`). I checked the changes against the R3 phone frames and the
founder's Duo frames (`artifacts/duo3/duo-screens/duo-screens/`, mainly store-03, store-04 and store-08).

## New or changed API for the App
| API | What the App does |
|---|---|
| `TrapArt.trapImage(style: .threeQuarter, width:scale:sippingBug:) -> CGImage?` | **#16.** Use it on Results, the cover, the pose card and every badge. It draws the trap 3/4-tilted like the icon (−0.18 rad, opening up-right) and half open: the back lobe's crimson face under a crown of cilia, the front lobe's **green leaf back** with its yellow-green lip and crimson edge, and a **winged petiole leaf**. Pass `sippingBug: .housefly` for a fly sipping a nectar drop on the face. Height ≈ `TrapArt.threeQuarterAspect` × width (about 1). Never use the top-down image as a hero. |
| `TrapArt.drawThreeQuarterTrap(_:size:sippingBug:)` | The same drawing into any `CGContext` (y up), fitted and centred in `size`. Use it for badge medallions. |
| `TrapArt.trapImage(style: .topDown, …)` | The same output as `trapImage(width:scale:)`, and it can also carry a sipping bug. Keep it for Home and the Duo halves diagrams only. |
| `scene.livePopRects: [CGRect]` | **#3.** Each live pop's footprint for the rest of its life, in scene space (y up, with the punch and shake as drawn now). It covers the pop-in overshoot, the whole rise, the shadow and 6 pt of clearance. `scene.overlapsLivePop(rect)` checks a plate against them. Check again on each HUD publish. `SceneHooks.livePopRects` already reads this. |
| `scene.showsEconomy` (default true) | **QA-2 #7.** Set it to **false on Home**: no glyph flights, no crack, no row flash, no wilt glyph and no "Too slow!" pop. |
| `scene.hudSnapsRowRect: CGRect?` | **QA-2 #6.** The whole snaps row in scene space. The sting's crimson flash covers it, centred. Also set `hudSnapsAnchor` to `glyphCenter(snapsLeft − 1)`. |
| `TrapArt.snapGlyph(width:…)` | **#15.** Under 24 pt (`TrapArt.smallGlyphWidth`) it draws a simplified silhouette: a closed **green pod**, a crimson seam and 3 cream cilia ticks. From 24 pt up (use that size on the Duo) it is the full mini closed trap, now with green backs. The signature is unchanged. |
| `TrapArt.palette` | Unchanged (`lobeOuter` is still #C02A42, the cap). New constants: `TrapArt.lobeMidrib` #892934, `faceStops`, `closedStops`, `blush` #B8C25A, `blushAlpha` 0.38, `blushStart` 0.905. `TrapArt.lip` is a touch greener. |
| `scene.snapsShownOffset` | Same meaning. It now counts only snaps Core really added or took (QA-2 #2/#3, see below). |

## What changed
- **#5 face.** The face is now one linear oxblood gradient across the whole lobe: #6E1426 at the midrib, #892934 at
  16 %, then #A22239 and #B6273F, reaching #C02A42 at 92 % and darkening to #A42440 at the cupped margin. The stacked
  blush strokes are gone. They were the ~40 pt peach band on the Duo's store-03. The blush is now an elliptical ring:
  0 until 90.5 % of the radius, then rising (`pow(smoothstep, 2.5)`) to 38 % at the lip, so most of it is in the last
  ~4 %. Everything else that lightened the face to salmon is cut back: the gloss sheen is 0.14 → 0.06 (the streak a
  little fainter), the morning rim glow is 0.22 → 0.05, the morning haze is 0.13 → 0.08, and the rim glow is a thin
  rim (strokes ≤ 19 pt wide, about 10 pt in), not a 46 pt band.
- **#6 hold.** The closed trap's lobes are now leaf green over their outer ~75 %: dark at the edge, lit on the bulge,
  with fine veins and a green specular. Crimson shows only in the band at the seam, then the dark interior. The hold
  has **one width** (`BogJaws.holdWidthScale`; the old 1.8× stretch on release is gone). The closed trap fades out in
  the first ~70 ms of the release while the lobes spring open from under it.
- **#6 caught bugs.** They are pulled into the seam within 60 ms (`BogBugLayer.sinkTime`, eased out; 75 % there by
  30 ms) and drawn at z 16.2, under the closed trap (16.5). They keep sinking through the 50 ms hit-stop, shrink to
  0.55 and are gone by 0.22 s. Their shadows go at once.
- **#7 dusk by phase.** `BogLight.lightClock` maps Core's `dayClock` to the light keys:
  - morning (waves 1–6): easing to white;
  - noon (7–14): held white, with a +10 % white lift on the bog only (a new additive sprite at z 6, under the trap);
  - dusk (15–22): held at the peach key (a 14 % peach lift on the bog, a 22 % haze, a thin warm rim at 0.48, and a
    *deep* warm overlay #D9593A-ish so the trap warms without going salmon; store-08 had gone pink with a cream rind);
  - night (23+).

  The jumps at waves 15 and 23 ease over ~1.2 s of session time. A jump bigger than 1.2 (a new session or demo) is
  taken at once.
- **QA-2.**
  - #2/#3: glyphs and cracks are clamped to the real `snapsLeft` change since the last frame. At the cap, or in the
    lesson, the glyphs still fly but never hold the numeral back. Several stings in one frame crack once for their
    summed cost, capped at the real drop (1 left and a wasp: the numeral shows 1, then 0).
  - #6: the row flash is centred on the row rect.
  - #7: the `showsEconomy` flag.
  - #8: the droop now lets go over 0.6 s after a wilt.
  - #19: `byId` and the rider list are reused, the tooth tint is cached, and the flight pool has 12 slots.

## Needs from the other modules
- **App:**
  - Switch Results, the cover, the pose card and the badges to `.threeQuarter` (with `.housefly` on Results/cover).
  - Set `showsEconomy = false` on Home.
  - Set `hudSnapsRowRect`, and the anchor from QA-2 #6.
  - Keep the hint plate off `livePopRects`.
  - Size the Duo's snaps row glyphs ≥ 24 pt if you want the full glyph there.
  - QA-2 #4 (republish the HUD after the scene's `draw`) is still yours.
- **Feel:** QA-2 #9. The numeral still drops 0.15 s after `stung` (`BogEconomy.crackLead`); put the "lost" blip there
  (0.20 s from the bite), or tell me to move `crackLead` to 0.41.
- **CI:**
  - A wave-18 frame should now be visibly peach on the bog.
  - `freezeOn=snap` at 0.12 s shows the green-backed closed trap with no bugs on top.

## Tests added (SceneTests)
- `theFaceIsCrimsonWithAYellowGreenBlush`: stops ≤ #C02A42, #892934 by the midrib, blush ≤ 40 % only after 90 %. It
  also renders a lobe and checks the pixels: crimson out on the face, a gradient across it, and no peach at the margin.
- `theShutTrapShowsItsLeafBacks`: green outer stops and pixels, one hold width, the fly in the seam under the closed
  trap at 66 ms, and still moving during the hit-stop.
- `duskShowsThroughWave22AndNightStartsAt23`: peach keys for waves 15–22, a whiter noon, and the eased change into
  night.
- `theSmallSnapGlyphIsAGreenPod`: pixels for the green back and the crimson seam; 3 ticks.
- `livePopsAreExposedForThePlate`: the live rects cover the pops, and an empty corner is clear.
- `theIsolatedTrapIsThreeQuarterTilted`: pixels for the crimson face, the green front lobe and the green petiole; the
  tilted hinge; the bug changes the face where it sits.
- `theEconomyOnlyShowsRealChanges`: the cap, two stings, a wasp at 1 snap, Home, and the droop release.
- Updated `theEconomyFliesToTheHUD` and `theEconomyIsShownTruthfully`: their snapshots now change `snapsLeft` (they
  relied on the old unclamped behaviour).

## Risks
- The pixel tests sample fixed points. If a gland, vein or tick lands on one, nudge the point rather than the art.
- The 3/4 trap is new art that no one has looked at yet. Check the first CI render of Results and the cover. If it
  reads as a bowl, raise `TrapPose.frontLip`'s control y (a more shut trap) or pass a sipping bug.
