# App engineer: Round 3 hand-off

Folders: `Snap/App/`, `Snap/UI/` (new `AchievementArt.swift`; `AppIconArt.swift` untouched), `SnapTests/AppTests.swift`.
**Not compiled.** Every touched file was re-read twice (exhaustive switches, ViewBuilder `let`s, isolation, labels).

## REVIEW-2 items
- **#3, hints never cut.** Plates take up to 3 lines (`HintFit.maxLines`); "Last snap! Make it count". `HintFit` measures
  each line with the plate's font (SF Rounded Heavy 19 / 23). `everyHintFitsBothPlates` renders every line
  (`AppRules.allHintCopy`, both inputs) at the play and lesson plate widths, Duo and phone, both HUD sides.
- **#4, HUD off the cilia.** `AppCanvas.trapOutline()` samples the green back (26 pt, conservative: Scene's is now 9)
  and every cilium root → tip from `TrapArt.teeth`. `HUDLayout` places everything by real room off that outline
  (+11 pt):
  - top outer corner: the score, with the pause button under it (`back` = the old corner, for the menus);
  - bottom outer corner: the snaps in 2 × 7 (numeral on the inner side of the lower row), the chain chip above them;
  - the chip shows "×1.5" alone where "Chain ×1.5" doesn't fit (the Duo, both sides, with Scene's R3 cilia);
  - the hint on the inner top (Duo P1 6), the lesson's hint on the inner bottom.
  - `hudClearsTheCiliaOnTheDuo` asserts ≥ 8 pt at 951 × 669, both sides.
- **#9.** Sprout run 1: `options.hunger = false`, `freeFirstSting = true` (`GameController.applyFirstRun`). On
  `stung(cost: 0)` the plate shows "Bees cost a snap!" (crimson, 2.4 s; `SNAP-T toast bees-cost`).
- **#11 snaps row.**
  - The glyph is the Scene's `TrapArt.snapGlyph` (cached in `SnapGlyphCache`); the App's own drawing is the fallback.
  - Empty slots are grey outlines, and all 14 slots always show.
  - From `hungry` until the next bite or wilt, the draining glyph pulses crimson and the numeral ticks red each second.
  - The numeral and glyphs show `snapsLeft + scene.snapsShownOffset`. The row also flashes on `scene.snapsRowFlashing`.
  - The anchor is the top row's first glyph (the Scene's flash runs 90 pt right of it).
- **#12.**
  - The lesson shows the snaps row from step 3.
  - The last card rings it, with "These are your snaps ↘" in the card (phone buttons side by side, so the row shows).
  - The first Feast ever gets a one-time "+1 snap" tag over the row.
- **#18:** the bee step casts the bee plus two flies beside it. Lesson bugs prefer inner drops (radius ≤ 0.74), and the
  pointer rings only the bee while one is in play.
- **#19:**
  - Bug Book names wrap to two lines, and a "more below" chevron sits on every scroll column (`scrollColumn()`).
  - The demo Bug Book counts vary.
- **#20:** "Debug · input touch" is gone. Only TestFlight with a hinge shows a hinge angle.
- **#24:**
  - Results: "Best chain ×2 · 2 big bites", "An 8-bug FEAST", "New best! was 3,200", and no shadow seam
    (`scrollClipDisabled`).
  - The cover always says "Open it up to carry on", with "1,174 so far" mid-run. Demo `screen=cover` plays 24 s
    headless first.
  - The pose card is TrapArt halves with a looping 160° → 138° clap and a top-view angle glyph.

## Fold as the input (founder call)
- `DuoClapDiagram` (loop 160° → 138°; still at 138° in demos):
  - Home: beside Feed with "Snap it shut a little";
  - lesson step 2 on a hinge;
  - the pose card.
- Shown on a hinge or a fold layout (`showsFoldInput`).
- First wave of each run, before the first snap: "Snap the halves together" (phones and pilot-on-phone: "Tap to snap").

## Also
- **Core R3:** the `.pilot` source now runs on `PilotRun` (fixed 1/60 s steps; `playTime` counts session time).
- **`screen=badges`:**
  - writes 12 × 1024² opaque PNGs to `Documents/badges/<Achievements id>.png`;
  - prints `SNAP-BADGE <id> <path>` for each, then `SNAP-T badges done 12`;
  - the art is a tiered medallion with TrapArt bugs and the trap.

## For CI / others
- The `ci/scenarios.txt` captions still quote "Last snap — make it count" (18) and "Open to carry on" (32).
- Phone glyph rows are 16 pt (the cilia allow no more at 874 × 402).
