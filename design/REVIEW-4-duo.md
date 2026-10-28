# Review R4: Duo specialist

**Score: 6 / 10, provisional** (R1: 5 prov., R2: 5 prov., R3: 6 prov.). For the first time I have Duo-aspect frames:
`artifacts/duo3/duo-screens/duo-screens/`, 31 frames at 951 × 669 (rendered 2853 × 2007), plus the 1398 × 2034
cover display, from the **R3 build**. They show the composition really works on the near-square canvas:
- the trap fills the book spread;
- the midrib sits on the fold;
- the lobes are the two pages.

But the R4 Duo run hasn't landed (`artifacts/duo4/` doesn't exist), and **every hinge check in the R3 run is
INCONCLUSIVE**. From `checks.tsv`:
- the simulator shut down during the `hinge` and `close-pause` launches;
- 6 hinge calls timed out;
- "min angle 156.1°, max closure 0.0°", with no `snapped` line from the hinge.

So, four rounds in, nobody has seen **a hinge snap catch a bug**, in the simulator or on a real Duo. The R4 phone
frames all log `canvas 874x402`, including `fold=1` (03, 22, 23).

## R3 items: fixed / not fixed
| R3 # | Issue | Status |
|---|---|---|
| 1 | Duo-aspect evidence | **Half.** There are frames at 951 × 669 (R3 build). There is no hinge evidence (INCONCLUSIVE ×4), no R4 Duo frames, and no real-Duo `SNAP-H` log. |
| 8 | Fold as input | **Home fixed on the phone** (03: a 120 pt clap card; R3 Duo `duo-ui-home-160` had a stamp-sized diagram beside Feed). **The pose card is broken in R4** (31). The R3 Duo pose card (`duo-06-pose-card`) was readable but small, and its "138°" was clipped under the diagram. |
| 13 | Daily label under Pause | **Fixed on the phone** (25). It was colliding on the Duo in R3 (`store-11-daily`: "DAILY BOG · 28 OCT" under the pause button). Needs an R4 Duo frame. |
| 14 | Crease | **Fixed by rule** (core-R4: 0 low frames over the band in 16 seeds). The R3 Duo frames show why it mattered: `duo-ui-home-160` has a housefly on the midrib (1125,830), `store-10` fruit flies at (920,960), and `duo-ui-too-flat-178` a bee halo straddling the crease (870,860). |
| 15 | Glyph size | **Unverified on the Duo.** R4 sets 24 pt `glyphDuo`. In the R3 Duo frames the glyph rows are ~12 pt in the extreme bottom-right corner, on the lily pads (1720–1970, 1265–1305). |
| 16 | Isolated trap on the cover display | **Fixed in R4 on the phone** (32). The R3 Duo cover (`duo-04-cover-shut`, portrait) is the centred top-down trap with a vertical slit, which was the risk the founder called P0. Needs the R4 render at 1398 × 2034. |

## P0
1. **Run the R4 Duo job to completion and gate sign-off on it.**
   - Fix the rig first: two simulator deaths and 6 hinge timeouts mean the job isn't trustworthy. Retry the
     `hinge`/`close-pause` launches with a fresh simulator, smaller sweeps, and `hinge -t` under 10 s.
   - Required evidence:
     - a `snapped` line from **hinge input** (not touch);
     - re-arm, creep (`creep-1` lines with closure > 6°), the close pause at < 50° and its resume;
     - no pause at 95°;
     - the too-flat hint at 178°;
     - frames of Home, the pose card, lesson steps 2–3, 10, 13, 21, 23, 25, Results and the cover display.
2. **A real-hinge log from TestFlight.** Record 50 snaps from the founder's Duo (`SNAP-H`: θ rest, d, depth at tc,
   catches). Four rounds of tuning (`snapDepth` 22°, `ref` 0.6 s, creep 6°/0.45 s) rest on a simulated hinge that
   never delivered a sweep.
3. **The pose card (31).** It's the Duo's first screen when held wrong (portrait or tabletop), and in R4 it renders
   broken: a black quadrant, a rotated, overlapping diagram, sideways "138°", stick hands. Fix it, then verify it at
   951 × 669, at the portrait inner size, and on the cover display.

## P1
1. **Too flat shows nothing (R3 `duo-ui-too-flat-178`).** At 178° no "Bend it a little, like a book" plate is drawn.
   App's QA-2 #15 fix (> 176° in the pose step) covers the lesson. Check that play shows it too, per GAME-DESIGN §3.
2. **Thumb band.** In book pose the right thumb rests near the right outer edge at mid height. That is where these
   sit:
   - the bees enter (11: 1640,200 behind Pause; 12/19: 1810–1930, 600; 18: 1810,600);
   - the "+1 snap" / chain chips stack (13, 21, 42: 1660–1850, 650–780);
   - the hint plate's inner-bottom slot sits just left of it (43).

   On a Duo the HUD half is the sharp half (good), but don't spawn bee entries in the thumb rect (outer 12 % ×
   middle 50 % of each half), and move the chips above the row's left end, not its right.
3. **Lesson on the Duo.** R3 frames show "Step 2 of 6" (`duo-ui-lesson-1-160`) and "Step 1 of 5" (`duo-ui-lesson-2`)
   for the same step, and the in-card fold diagram is tiny with "138" clipped. The R4 note says it plays "Step n of 5"
   with the clap on step 2. Capture it.
4. **The release on the Duo (juror P0-2).** At 951 × 669 the reopening trap fills the canvas height (R3 `store-07`:
   x 420–1580, y 90–1330). The plum/bottom silhouette is larger there than on the phone. Check the R4 release at Duo
   aspect.

## P2
1. Blurred half: the HUD is right by default, and the free-sting plate stays on the right half (43: x 1060–1385).
   Good. Make sure the plate's inner-bottom fallback never crosses x < 0.52 W on the Duo.
2. Home on the Duo: the menu covers most of the right lobe, and there the right lobe *is* the right screen. Consider
   shrinking the menu to the outer 40 % of the right half, so the trap reads as two pages.
3. The R3 Duo store set (`store-01…16`) is stale:
   - the peach rind;
   - the old toast "Bees cost a snap!" over "Stung!" (`store-07`);
   - the Daily label under Pause (`store-11`);
   - the red-pod hold (`store-04`).

   Regenerate it entirely from the R4 Duo run. Use an open-after-bite frame, not the hold or the release, for the bite
   shot.
4. The cover display card (portrait) needs its own R4 layout check. `CoverLayout` was tested at 466 × 678 and
   678 × 466, but the R3 cover frame is 1398 × 2034 px (≈ 466 × 678 pt @3x), so that is the right size. Capture it.
