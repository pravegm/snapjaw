# Scene R2 hand-off (Scene engineer)

Only `Snap/Scene/` (new file: `BogEconomy.swift`) and `SnapTests/SceneTests.swift` changed. Nothing is compiled
yet: I re-read every touched file twice for compile errors (CGFloat/Double, isolation, labels, exhaustive switches).

## New API the App must call
| API | What the App does |
|---|---|
| `scene.drawnClosure: Double?` | Each frame (before or inside `advance`), set it to the closure in degrees from `HingeTrapSource.predictedAngle(at:)` (rest − predicted angle). nil = draw `snapshot.closure`. Set nil on touch-only phones. |
| `scene.hudSnapsAnchor: CGPoint?` | Set it to the HUD snaps row's leftmost live glyph, in **scene space** (convert from `HUDLayout`, y up). Feast glyphs fly there, a sting cracks one there, and a wilt droops one there. nil = the bottom of the HUD half. |
| `TrapArt.trapImage(width:scale:)` | A `CGImage` of the play trap (green backs, lips, crimson faces, midrib, cilia), drawn by the scene's own code. For #12: Home, the cover, Results and the icon. |
| `TrapArt.bugImage(...)` | Unchanged. Pass `TrapArt.defaultRadius(s)` (now R1 × 1.8) or `BugCatalog.info(s).radius`. |

## Needs from the other modules
- **App/UI:**
  - The chain step now only bumps the HUD chip ("×2!"). The scene no longer pops "chain ×n".
  - The scene no longer pops "Feast! +n snaps" or "−n snaps": the glyph flights show them.
  - Flash the snaps row crimson on `stung`. Drain or grey the next glyph from `snapshot.hunger`.
  - `ScreenLayout`/`HUDLayout` are unchanged.
- **Feel:** glyph *k* (0-based) of a Feast lands at `0.05 + k × 0.12 + 0.45` s after `snapped`. That is the 50 ms hit-stop, then `BogEconomy.flightGap` and `flightTime`. Tick each one from `feast` / `luckySnap` (total = `BiteReport.snapsBack`).
- **Core:** the art radius is `max(BugInfo.radius, TrapArt.defaultRadius)`. If Core scales by 1.8, the two agree; if it doesn't, the art is still 1.8× (never 1.8² ×). Nectar is drawn at 0.7 × `NectarDrop.radius`. Every size in `Tuning.nectarRadiusMin…Max` is pre-warmed.

## What changed (review numbers)
- **#1 Streaks: found.**
  - The cause: SpriteKit's `size` is the *scaled* size. A caught bug folds its wings to `yScale` 0.001. The node goes back to the pool, and `dress()` then set `wings.size` while it was still folded, which stored a 1000× taller sprite.
  - The next bug's wings drew as a pale, tapered, 600–1100 pt streak. It ran along the bug's y axis, with the gap between the two wings at the bug, in the wing colour (green for the grasshopper in 12).
  - Fix: `bogResize()` resets the scale before every pooled resize (bugs, particles, drops, backdrop). Wings are clamped to ≥ 0.03 and hidden below that. Shadows are clamped to ≥ 0.01.
  - Test: `bugChildrenNeverStreak` checks that every bug child's frame is ≤ 6 × its radius through a catch, pool reuse and flying.
- **#4 Bugs ×1.8:** `TrapArt.defaultRadius` = `baseRadius` (R1) × `artScale`, so a housefly is 50 pt across and a gnat 25 pt. Rings, glows, splats and lift are radius-based.
- **#5 Trap:**
  - No lime rind. There is a 26 pt green back (`TrapArt.exteriorPath`) and a 5 pt dark lip.
  - The face runs #7A0C26 → #D23048, cupped (darker under the lip and at the curled ends).
  - The veins and pale pores are fainter, and the trigger hairs are thin and crimson.
  - 24 cilia per lobe, 1.5× longer and 40 % thinner, clamped to the canvas.
- **#6 Bite:**
  - A 50 ms hit-stop freezes the bugs, FX and pops, while the jaws slam through it.
  - Caught bugs flash white for 2 frames (silhouette sprite).
  - The lobes squeeze to x 0.6. The far lobe's green back, its lip and its cilia (`jawNode`, not squeezed) cover the outer 40 % of each lobe. Our teeth interlock at the new edge; the ones under the jaw tuck away.
  - Shake 4 + 2/bug (≤ 12, inside a 24 pt backdrop bleed; QA #20), plus a white impact puff on the midrib.
  - The lobes spring back with a ~1.05–1.08 overshoot on re-arm.
- **#7 Rings:**
  - Bees, bumblebees and wasps never get the sip ring. They get a crisp 3 pt ring at 1.6 r (white; red-orange for wasps). The R1 soft halo is gone.
  - Catchable sippers get a lime-white ring (`TrapArt.sipRing`). Gold is only for score and nectar.
- **#11/#18 Pops:**
  - One hero line ("FEAST ×5 · +255", 48 pt with a big overshoot), placed at y + 2r + 20 above the caught bugs, on the half with most catches.
  - Every pop box, overshoot included, is ≥ 24 pt from the crease and is shrunk to fit. Lines below are reserved (QA #23).
  - "Bzzt!"/"Stung!" sits above the bee on its own half.
  - The pool holds 20 and recycles the oldest (QA #22).
  - Test: `popsStayClearOfTheCrease` (both `hudOnLeft` values).
- **#17 Economy:** `BogEconomy`. Glyph flights (0.45 s, ease-in arc, 0.12 s apart, a bump on landing), a sting crack (two halves fall 20 pt under a crimson flash), and a wilt droop.
- **#19 Nectar:** 30 % smaller, translucent amber (`palette.nectar` = #F5A623). It shrinks 3 %/s while sipped (to 75 %), and sippers dip their heads.
- **#20 Closure:** foreshortening 3 % → 15 % (`lobeSquash`), with stronger edge shades (to about 30 % of the width). `drawnClosure` comes from the App.
- **#21 Night/dusk:** the multiply tint moved under the trap (z 5, bog only). The lobes get a ≤ 25 % normal-alpha overlay (gold/peach/blue), the midrib a matching blend, and the teeth a dark-blue blend at night.
- **Hunger:**
  - As `snapshot.hunger` goes from 0.7 to 1, the lobes droop (y 0.985, x −2 %), dull (a brown-grey overlay ≤ 20 %), lose gloss, and the teeth lean 14° (about 10 % shorter).
  - `hungry` plays a 0.7 s stomach-rumble wobble.
  - `wilted` pops "wilted −1" above the snaps anchor and drooping a glyph there.
- **QA-1:** #19 (fixed `phase`, separate `flapPhase`), #20, #21 (the catch height eases to 0), #22, #23, #24 (nectar warmed).
- **Escapes:** a bigger whiff plus a startle "!".

## Risks
- The streak diagnosis relies on SpriteKit's scaled-`size` semantics. The fix is harmless either way, and the 6× test guards it.
- The far-lobe jaw is a new look. Check frame 13 on CI (`freezeOn=snap`, 0.12 s, which lands in the hold).
- Textures: about 8 MB more (bigger bugs, silhouettes, and 26 pt of extra lobe margin).
