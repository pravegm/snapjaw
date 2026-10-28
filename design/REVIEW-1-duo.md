# Review R1 — iPhone Duo specialist

**Score: 5 / 10 (provisional: no frame in r1 is actually a Duo).** The architecture is right:
- the HUD on the right (sharp) half, with a mirror setting;
- the fold-clear rule, which is tested;
- 56 pt targets, a relative rest angle, never asking for flat, and a closing pause kept away from 90°.

But all 33 frames are an iPhone 18 Pro at 874 × 402 pt (aspect 2.17), not the Duo's 952 × 670 (1.42). The "Duo
layout" frames (03, 22) are indistinguishable from 02 and 21, with no visible fold band. And several elements are
centred on the crease.

## What the frames do show
- **03-home-duo-layout vs 02-home-mid:** pixel-identical apart from a 10 px shift of the rank card, so `fold=1` has
  no visible effect on Home. On the Duo, the title and rank card on the left page are fine, because the blurred half
  only hides decoration. Feed, Daily, Book and Settings sit on the right page, correctly.
- **22-play-duo-fold1 vs 21-play-wide-fold0:** no crease shadow. Either `foldBand` is hidden because `hasFold` comes
  from the real hinge and not from `fold=1`, or it's too faint to see. The midrib (~26 pt dark seam) is centred, which
  is good.
- **Things that straddle the crease (x≈476 on the Duo):**
  - "Your trap is tired." (19, positioned at `trapRect.midX`);
  - the Feast pops "FEAST ×5 / Feast! +2 snaps" (14);
  - the "+N" pops, whenever the caught bugs' centroid is near the fold.
  - On a real Duo the crease distorts and dims a ~20 pt band, so text broken across it reads as broken.
- **Thumbs:** in book pose the hands grip the outer edges at mid-height, so the thumbs cover ~0–70 pt in from each
  outer edge over y≈200–470.
  - The HUD avoids that band (score top, snaps bottom), which is good.
  - But the hint plate sits bottom-outer, right at the thumb's resting arc (11, 12, 18).
  - Bugs also land on the outer rim at mid-height and enter from the side edges, under the thumbs.

## Fixes (prioritised)
**P0**
1. **Nothing centred on the crease:**
   - `TiredBanner` goes to `info.hudPage.midX`;
   - score pops get their text box clamped to one half (≥ 24 pt from `creaseMinX/MaxX`), so it shifts to the side
     with most of the caught bugs;
   - add a unit test that every text rect drawn in play satisfies `isFoldClear`.
2. **HUD over the trap on the Duo:** the App's own risk note says the HUD corners overlap the trap ellipse's top
   rim at 951 × 669. Add `HUDLayout` tests against `trapRect` at 951 × 669 (and with `hudLeft`). If they fail, pull
   the score in 12 pt and drop the chain chip under the pause button.
3. **Render a true Duo-aspect frame in CI.** Render 951 × 669 letterboxed on the phone sim, with `fold=1` forcing
   `jaws.foldBand` visible. 03 and 22 currently prove nothing. Run `duo.yml` before R2 sign-off.
4. **Touch on a hinged Duo:** confirm that scene taps never snap once a hinge is seen, so a thumb on the glass during
   a 22° clap isn't a second snap. The `PlayLayer` comment routes every tap to the scene.

**P1**
5. **Hints off the thumb arc:** move `HUDLayout.hint` to the HUD page's inner bottom (from `foldMaxX + foldClear`
   outwards) or under the chain chip.
6. **Thumb-safe landings:** exclude landing targets within 80 pt of either outer edge for y in the middle 50%.
   Bias wave entries to the top and bottom edges, and to the outer edges only above or below the hands.
7. **Grasshopper hops and fold-loving moths:** fine to cross the fold, but never *rest* within ±20 pt of x = 476
   (the crease distorts small sprites). Nectar drops ≥ 40 pt from the crease.
8. **Hunger fix (see Feel 4)** also caps a run at ~6 min and ~60 snaps. Unbounded expert runs (161 waves, 10 min) are a
   wrist and hinge cost on a £1.99 toy.

**P2**
9. The pose card (31) and cover card (32) are laid out for a wide canvas. On the Duo's cover display, check that
   "Open it like a book" fits at the large type size, and add the run's score so far, as the design says.

## Must be verified on real hardware
1. **The bite rule vs the hinge:**
   - Report rate and ~5° accuracy against the 4° start, the 6° creep and the 22° snap.
   - Is `d` stable to ±30 ms? The dragonfly's 0.12 s and the mosquito's 0.14 s windows are only ~4 report
     intervals.
   - Log `SNAP-T hinge snap d=` for 20 deliberate quick snaps and 20 lazy ones.
2. **Comfort:**
   - A 22° clap from the player's own rest (135–175°) without a wrist-roll.
   - The re-arm 16° rise.
   - A slow drift of rest doesn't creep.
   - A hard snap reaching 90–100° doesn't trigger the closing pause.
3. **Which half blurs** after a fold from flat and after cover → inner (left on the founder's Duo?), and that the HUD
   default is the other one.
4. **The crease position:** does `creaseMinX/MaxX` (from `reservedRegions(kind: .division)`, iOS 27.1) land on the
   physical crease at x≈476? Does the midrib sit on it at both orientations of book pose?
5. **Haptics:** the Strong profile on the Duo's weak actuator. Is the CHOMP felt through both halves? Is the landing
   tick distinguishable from the creep texture?
6. **Audio:** the stereo pan maps the bug's x to the correct speaker in book pose (not swapped). Does the 45–90 Hz
   thump survive the Duo speakers?
7. **Rendering:** sustained 120 fps with ~330 nodes and 35 MB of textures, and 64 voices in a 9-bug Feast; thermal
   over a 6-minute run. Also SpriteKit `.multiply` on the device GPU.
8. **Legibility at arm's length** (~35 cm), held like a book: bug size, the 11 pt "DAILY BOG" marker and the 15 pt
   snap numeral.
9. **Orientation:** a portrait or tabletop hold shows the pose card, and an upside-down book pose doesn't flip the HUD
   onto the blurred half.
