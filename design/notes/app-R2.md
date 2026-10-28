# App engineer: Round 2 hand-off

Folders: `Snap/App/` (new file `SceneHooks.swift`), `Snap/UI/`, `Snap/Persistence/`, `SnapTests/AppTests.swift`.
**Not compiled.** I re-read every touched file twice (exhaustive switches over the new `TrapEvent`/`TrapHint` cases,
CGFloat/Double, ViewBuilder `let`s, label overloads, isolation).

## QA-1
- **#1 P0, the closing pause:** `hingeSample` now calls `checkClosing` while `isClosingPaused`, so the pause lifts from
  the hinge reports (≥ 120°, not shut) with the scene paused. The scene still pauses under the card (battery).
- **#2:** `start()` calls `hinge.reset` after choosing the input. `goHome()` resets too, so a menu clap never fires on
  Home. Feel's 0.25 s stale-snap drop is the safety net.
- **#3 / REVIEW #8, #9, #22, the lesson:**
  - Scripted bugs land ON real drops (`AppRules.lessonSpot(slot:geometry:nectar:taken:)`: the nearest free drop off
    the crease; one per bug in play, tracked in `lessonClaims`).
  - Step 2 passes on any snap with a fly in the trap. A miss says "Snap! Quicker catches more." A dry snap with no fly
    says "Wait till it's sipping…".
  - Skip is offered on every step, from step 1.
  - The pose step moves on after 3 s with no hinge reading (#10).
  - The bee lingers 6 s, and the lesson shows the "Bee! Wait…" and "Now!" hints (`AppRules.lessonShowsHint`).
  - A pulsing ring and dashed arrow run from the card to every bug in play (`LessonPointer`): lime for flies,
    dashed white for bees.
  - On touch, the re-arm step is merged into step 2's praise. Step 4 says "Two flies. Get both in one bite." and
    needs both. Numbering counts only the visible steps (phone "Step n of 4", Duo "of 6").
- **#7:** `touch.reset()` when a pause begins.
- **#8:** `tally.hingeTiming` is set when a run moves onto the hinge.
- **#9:** leaving in the tired moment finishes the run headless and records it as finished, with no Results.
- **#11:** only Skip is hit-testable on the lesson card.
- **Scene P2, width change mid-run:** a width change is deferred to the next session.

## REVIEW-1
- **#2:** `ChainChip` is `.fixedSize()`, under the pause button, and bumps on each chain step.
- **#3:** the snaps numeral has a fixed 30 pt box, and 11–12 slots use 18 pt glyphs.
- **#14, #16, #11, the HUD (`HUDLayout`):**
  - Everything is placed by ellipse maths (`AppCanvas.trapReach`/`minTrapRadius`): the score beside the pause (pulled
    up, 172 pt), the chip under the pause, the snaps bottom-outer (two rows of six on short phones), and the hint
    plate (two lines) where it has the most room off the trap and out of the thumb zones (Duo: above the snaps,
    below the thumbs' band; phone: under the chip).
  - "Your trap is tired." sits at `hudPage.midX`.
  - Tests at 951 × 669 on both sides: the score, chip, snaps and hint all sit at radius ≥ 1, and every text rect is
    fold-clear.
- **#12, one art language:**
  - Home is the live `BogScene` running an attract session (`homeSession`, never recorded). The hinge or a tap
    chomps it, and `FeedbackDirector.homeTrap` is fed from `advanceHome`.
  - The menus sit on a blurred, dimmed still of the bog (`BogBackdrop`, from `SKView.texture(from:)`).
  - Every portrait is `TrapArt.bugImage` (`BugPortrait` re-implemented, cached).
  - The cover card and Results show `TrapArt.trapImage` (`TrapArtImage`).
  - `TrapPortrait` is only a restyled fallback.
- **#13, the Bug Book:** the joke runs full width (3 lines, 0.85 minimum scale), a fade hints at the rows below, and
  the header clears the back button.
- **#23, Results:**
  - "4 bugs · 48", "×1.5 (1 bite)", "Scarab".
  - The new-species row shows the tiles that fit, then "+n".
  - "First run!" via the new `RecordOutcome.firstRun`; "First feast!" is now "First score!".
- **#23, Home:**
  - The rank hint reads "Catch 30 bugs to grow".
  - The title sits over a soft shade on the lobe.
  - The button shade now runs to the screen edge (no seam), and the pink smudge is gone.
- **P2s:**
  - The copy is now "Open it up to carry on" on both the closing card and the cover.
  - Settings starts under the back button, its cards are one width, and its columns fade at the foot.
  - The pose card now has the trap colours and a fly that gets eaten.

## Hunger and the R2 contract
- `AppTrace` logs `event hungry secondsLeft=…` and `event wilted snapsLeft=…`. `RunTally` ignores both.
- `.hungry` has the copy "Hungry… bite!" (crimson plate).
- The next snap glyph (the last filled one) drains from the top and greys with `snapshot.hunger` (`HUDValues.hunger`,
  in 1/40 steps). The scene pops "wilted −1" and droops a glyph, so the HUD doesn't.
- The snaps row flashes crimson on `stung`, as scene-R2 asked.
- `SessionOptions.startSnaps = 12` while the rank is Sprout, for **Feed only**: the Daily stays the same bog for
  everyone, which is my call.
- New demo freeze tags: `hungry` (holds 1 s, so the drain shows) and `wilted` (0.3 s).

## Scene-R2 wiring (`SceneHooks`)
- `scene.drawnClosure` is set every frame to the detector's reference minus `predictedAngle(at:)`, clamped to 0…90.
  It is nil off the hinge.
- `scene.hudSnapsAnchor` is the first glyph's centre in scene space (`HUDLayout.firstGlyphCenter`,
  `AppCanvas.scenePoint`), re-sent on layout and slot changes.

## Icon
`AppIconArt` has been redrawn:
- the subject fills about 88 % of the canvas;
- a dark throat, green leaf jaws, and the deep crimson face with gloss;
- 12 thin cilia per rim (no fangs);
- the fly is drawn last, so no line crosses it.

**CI must re-render it** (`screen=icon`). `Assets.xcassets/AppIcon-1024.png` is still the old placeholder.

## Risks
- `SKView.texture(from:)` on a paused SpriteView should work. If it returns nil, the menus fall back to the painted
  gradient.
- Home now renders the scene at 60 fps on real devices: watch battery and heat on the Duo.
- On a phone the hint plate is about 99 pt wide, so its text wraps to two lines.
- `onPreferenceChange` with a non-Sendable closure may warn in the iOS 27 SDK.
