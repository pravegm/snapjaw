# Review R3: Apple Design Award juror

**Score: 7 / 10** (R1: 5, R2: 6). This is the first round where the trap reads as a plant. It has:
- two clam lobes on a dark seam, with notches at the top and bottom of the midrib;
- a petiole running into the bog;
- 76 thin cilia instead of a picket fence of fangs;
- stippled glands and fine veins.

The bite no longer turns into a green iris. The night keeps the trap crimson. The icon has lost its fangs.

What still keeps it off an award shortlist:
- the face still has a **peach rind band**, so the first read at arm's length is still "melon";
- the bite-hold silhouette is now *inside* the trap but reads as a red pod, not a shut leaf;
- dusk is still invisible;
- four small clipping and collision bugs show up in frames a store reviewer would see.

Frames: `artifacts/r3/screenshots/` (iPhone 18 Pro, 874 × 402 pt, tap build). Coordinates are in the 2000 × 920
preview of each frame. I sampled the colours from `10-play-landed.png`.

## R2 items: fixed / not fixed
| R2 # | Issue | R3 status |
|---|---|---|
| P0-1 / #1 | Bite draws a green iris wider than the trap | **Fixed.** The 13 hold is x 830–1190, and 14 and 18 are x 655–1350, all inside the open trap (x 355–1645 in 10). There is no green ellipse and no ghost teeth. **New problem:** see P1-4. |
| P0-2 / #2 | Watermelon | **Mostly fixed, not finished.** The rind band, pale seeds and double specular are gone (compare r2/10 with r3/10). But the outer lobe samples #D7525D (salmon, lighter than the brief's #C02A42 crimson) and the margin is a peach #E3A26C band about 12 pt wide. The founder asked for a yellow-green blush in the last ~10 %. On the cover (32) and Results (20) the isolated trap still reads as a blood-orange or watermelon cut. |
| P0-3 / #3 | "Last snap — make i…" | **Fixed** (18: "Last snap! Make it count" on two lines). |
| P1-4 / #10 | Dusk invisible; night goes violet | **Night fixed** (17, 35: a blue bog, the lobes stay crimson, fireflies show). **Dusk not fixed:** 12 (wave 16), 16 (wave 18) and 18 (wave 18) look like morning, then 19, 33 and 34 (waves 20–22, still dusk per the logs) are already night-blue. There is no peach anywhere. |
| P1-5 / #13 | Fanged Pac-Man icon | **Fixed in spirit.** See "Icon" below. |
| P1-6 / #24 | Pose card a flat book | **Better.** It now uses TrapArt with an angle glyph (31). See P2-9. |
| P1-7 / #15 | Small pops; "wilted −1" | **Pops fixed** ("QUAD ×4 · +128" ≈ 40 pt in 13; "TRIPLE ×3 · +99" in 25). **The "Too slow!" tag is unverified:** 34 caught no wilt. |
| P2-8 | Home menu hides the trap | **Not changed** (01–03). |
| P2-9 / #25 | Mosquito reads as a spider | **Fixed** (12 at 1290,550; 35 at 790,200: six legs and a proboscis). |
| P2-10 | Results seam and dead band | **Seam fixed** (20, 26). The 150 px dead band above the trap image remains. |
| P2-11 | Debug string | **Fixed** (30). |

## P0
1. **The cover clips its own score (32).** "400 so far" is cut in half by the bottom edge at y ≈ 900. This is the
   promised R2 fix (#24), and it now looks broken. Fit the card to 402 pt and the cover display: shrink the trap image
   to 0.6 × height, or put the score beside it. Add a layout test.
2. **The toast sits on the pop (15).**
   - "Bees cost a snap!" (1060–1335, 25–160) covers the "Stung!" pop, so only its lower half shows at (1180,170).
   - It fired for a **wasp** (log: `stung id=36 species=wasp cost=0`), so the copy is also wrong for the bug on screen.
   - It is the one moment the game teaches its key rule, and it is the messiest frame in the set.
3. **Finish the founder's face.** These numbers apply to `TrapArt` everywhere: in play, on Home, the cover, Results
   and the badges.
   - The outer lobe should be ≤ #C02A42.
   - The blush should be yellow-green (around #B8C25A at ≤ 40 % alpha), only in the last ~8–10 % before the lip. Today
     it is peach #E3A26C.
   - The gradient to the oxblood at the midrib (#892934 today, good) should be visible across the whole lobe, not only
     its inner third.

## P1
4. **The bite hold doesn't read as "shut" (13, 14, 18, 19).**
   - What you see is two puffy crimson halves zipped by interlaced cilia. At 35 % width (14, 18) it reads as a red
     apple, a bell pepper or a bottom; at 18 % (13) as a hot-dog bun.
   - A shut flytrap from above shows its **green leaf backs**, crimson only near the seam. Shade the outer half of each
     closed lobe toward `TrapArt.leaf` (#2F5F2B) and keep the crimson bulge along the seam.
   - Pick one hold width: today 13 and 14/18 differ by 2×.
   - Caught bugs stay drawn on top of the shut lobes (13: housefly 950,610 and fruit fly 1050,600; 14: fruit fly
     860,540), so they look uncaught. Sink them under the lobes (or into the seam) within the 60 ms squeeze.
5. **Dusk.** Light by phase, not by wave index past 20:
   - a peach haze plus a warm rim through waves 15–22;
   - the blue night only from wave 23.
   - CI needs a mid-dusk frame (wave 18) that is visibly peach. Noon (11, 14) should also be a whiter, higher-key
     light than morning (10).
6. **The Daily label collides with Pause (25).** "DAILY BOG · 28 OCT" runs under the pause circle at (1700–1810,
   140–255). Move the label under the score's left edge, or drop Pause 30 pt.
7. **Scroll chevrons sit on copy** (28: "for her", 29: "Absolutely not on the menu", 30: "eaten."). Give the
   chevron a bottom fade gutter and inset the content by the chevron's height.
8. **The trap on its own (cover 32, Results 20/26/27, badges `daily`, `monarch`, `score10k`, `nobees`).**
   - Isolated, centred, with a vertical slit and a small stem, the open trap can read as anatomical. Several people
     will see it that way.
   - For a family game this is a store-review and word-of-mouth risk.
   - Fix it on these surfaces:
     - put a bug sipping on it (as `bite5` and `feast` do);
     - or tilt it 3/4 as the icon does;
     - and show a sliver of the leaf back and the petiole leaf.

## P2
9. **Pose card (31).**
   - The "138°" label is clipped by the book's bottom edge (480–570, 585–610).
   - Each half carries its own petiole (two stems at 510 and 540, 520–565).
   - The right 55 % of the frame is empty.
   - Fix: one trap across the hinge, the label below the angle glyph, hands at the outer edges.
10. **Home (01–03).** The menu still covers most of the right lobe. In 03 the new fold diagram (1610–1770, 235–400)
    sits on the cilia at the lobe's edge and is about 65 pt tall: too small to be the hero instruction it was meant
    to be.
11. **Results (20, 26, 27).** The left column's trap image (430–690, 155–345) is too small for the screen's hero and
    floats over a dark blob. Make it 1.4× and set it on the bog.

## Icon (`app-icon-1024.png`): 7 / 10 as a store asset
- **Good:**
  - no fangs, no outlines;
  - a clear red/green/navy/white value structure;
  - the fly's huge eyes looking up give it character;
  - the crown of pale cilia reads as "flytrap";
  - the stem is a nice touch.
- **Problems:**
  - It is a different object from the game: a 3/4 cup with a navy fly, against the top-down two-lobed trap and the
    grey housefly in play. The store page will show both side by side.
  - At 29–60 px the navy body plus white wings can read as a ladybird or beetle in a red bowl, not as a fly. The fly
    is also so dominant that the app reads as "play the fly".
  - The front lobe is only a green bowl: the yellow lip under the fly's chin reads like a smile line. With the eyes
    above it, the whole icon can read as a face.
- **Fixes:**
  - use the in-game housefly palette (grey body, red-brown eyes);
  - shrink the fly to about 35 % of the trap's width;
  - show the second lobe's crimson inner edge, so there are two lobes, not a bowl.

## Badges (12, `badges/*.png`): 7 / 10 as a set
- **Good:**
  - one family (medallion, ring tier bronze/silver/gold, a gold number coin);
  - the bugs are crisp and charming (`dragonfly`, `night`, `scarab`);
  - they are legible at 64 px.
- **Problems:**
  - **Near-duplicates:** `bite5` vs `feast` (a trap plus bugs); `spare50` vs `nobees` (a bee in a dashed ring). In
    the Game Center grid they will look like copies.
  - **Contradicting the game:** the fruit fly sits on the midrib in `bite5` (510,510) and `feast` (520,630), which
    is the exact thing R3 fixed in play.
  - The trap-only badges inherit P1-8.
  - `scarab` reads as a golden bee (wings plus bobble antennae). Give it a beetle's wing-case split and no
    transparent wings.
  - Apple masks achievement images to a circle. The ring sits about 60 px inside the square, so check that the mask
    doesn't shave the ring on the 512 px set.
