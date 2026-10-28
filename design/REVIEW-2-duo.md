# Review R2: iPhone Duo specialist

**Score: 5 / 10 (provisional again).** R2 has **no Duo-aspect frame**:
- all 34 frames are an iPhone 18 Pro at 874 × 402 pt;
- `artifacts/duo2/` did not exist when this review was written;
- the only Duo evidence is R1's `artifacts/duo1` (951 × 669, real hinge CLI).

The R2 changes that matter most on a Duo can't be judged from these frames: the bigger bite jaw, the longer cilia,
the HUD ellipse maths and the hint placement. Several phone frames already show them colliding with the trap.

## R1 issues: fixed / not fixed
| R1 # | Issue | R2 status |
|---|---|---|
| 1 | Nothing centred on the crease | **Text: fixed** (19 banner at `hudPage.midX`; 13, 14, 25 pops on one half). **Bugs: not fixed.** They rest on the midrib: the housefly at x ≈ 1000 in 10, 21, 22 and 23; the gnat swarm on the midrib in 33 and 34; the caught housefly on the midrib in 13. On a Duo that is the hinge gap, about 20 pt that hides and distorts small sprites. |
| 2 | HUD over the trap at 951 × 669 | **Unverified, and suspicious.** 23 (`hudLeft=1`): the glyph rows (x 280–580) overlap the teeth at x 530–580, and the chain chip touches the teeth at (470,205). 22: the first glyph sits on the cilia at (1500,770). The cilia are now 1.5× longer, so does `trapReach` include them? In duo1 `store-10-hud-left`, the R1 snaps row already sat on the rim. |
| 3 | A true Duo-aspect CI frame | **Not done.** 03 and 22 are phone-aspect and still show no fold band (03 is near-identical to 02). |
| 4 | Touch while hinged | No evidence either way. |
| 5 | Hints off the thumb arc | On the phone the plate is right-edge, mid-height (12: "Bee! Wait…" at y ≈ 240–370 of 920). Mapped to the Duo, that is exactly the right thumb's rest (≈ 0–70 pt in from the edge, y 200–470). App-R2 says the Duo uses a different slot ("above the snaps, below the thumbs' band"): **needs a Duo frame**. |
| 6 | Thumb-safe landings | Not done. Bugs still enter and land at the outer rim at mid-height (11: the grasshopper at 1820,560; 18: the housefly at 1475,515). |
| 7 | No resting within ±20 pt of the crease | Drops: ≥ 50 pt (Core: done). **Bugs: not done** (see #1). |
| 8 | Hunger caps the run | Done: perfect 4.9 min, 25 snaps. Good for the hinge. |
| 9 | Cover card | Copy changed, but no score (32). |

## P0
1. **Run `duo.yml` for R2 and gate sign-off on it.** Add a `fold=1` render letterboxed at 951 × 669 on the phone sim
   with the fold band forced, so every PR shows Duo-aspect frames. The minimum set: 10 (landed), 13 (bite hold), 14
   (Feast), 18 (last snap and hint), 23 (HUD left), 24 (half shut), Home, Results.
2. **The bite jaw on the Duo canvas.**
   - On the phone, the jaw's green ellipse is 70–90% of the screen width (13, 17).
   - On the Duo, the open trap already spans about 95% of the width (duo1 `duo-01-open-165`: x 95–1905 of 2000).
   - If the jaw scales the same way, it goes off-canvas, or gets clipped flat at the edges, on both halves.
   - Clamp the jaw to the open-trap outline (this is also the juror's P0-1), and assert it in SceneTests at
     951 × 669.
3. **No bug rests within r + 16 pt of the crease** (Core `findSpot`, swarm anchors, hops, moth "near the fold"
   targets). Moths can be drawn *towards* the fold and stop at ≥ 24 pt. The caught-bug squish can still slide into
   the midrib, because it's a 0.1 s animation.
4. **HUD vs cilia at 951 × 669.** Include `ciliaLength` (now 1.5×) in `AppCanvas.trapReach`. Add a test that the
   snaps rows, chain chip and score are ≥ 8 pt outside the cilia tips at both `hudLeft` values. On a Duo, a glyph row
   over the teeth also sits in the zone where the player's eye watches for landings.

## P1
5. **Thumb-safe landings** (R1 #6, still open): no landing target within 80 pt of either outer edge in the middle 50%
   of the height. Bias entries to the top and bottom.
6. **The hint slot on the Duo.** Render the Duo layout to show the hint plate's actual slot. If it is at the outer
   edge at mid-height, move it to the HUD page's inner top, under the chain chip and ≥ 24 pt from the crease.
7. **Live Home scene (01–03) at 60 fps on the Duo** (App-R2 risk): measure the thermal and battery cost over 10 min
   on Home. Drop to 30 fps when there is no input for 5 s, and pause it under the Bug Book and Settings blur.
8. **CI hinge evidence is not hinge evidence.**
   - `d = 0.010` is a CLI jump (Feel-R2), now clamped to 1/30 s, so every CI snap is "perfect".
   - CREEP-FAST is an INFO with no samples.
   - Mark windows with no `SNAP-H` lines as INCONCLUSIVE (Feel asked in NEEDS), and keep the real-device checklist
     from REVIEW-1-duo §"Must be verified" open. The 0.12 s dragonfly and 0.14 s mosquito windows are 2–4 reports wide.

## P2
9. The pose card (31) should show the 160° → 138° clap. On the cover display (32), check that "Open it like a book"
   fits at the largest Dynamic Type, and add the score.
10. The mid-run hunger droop (33) is a whole-trap transform. On a Duo it should not move the midrib off the crease:
    pin the scale anchor at the midrib.
11. The blurred half: Home's title and rank card are on the left page (01). That's fine, because they're decorative.
    The lesson card (04–09) sits top-right, on the sharp half by default. Confirm that `hudLeft=1` mirrors the lesson
    card and the pointer origin too.
