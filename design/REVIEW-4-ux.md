# Review R4: UX and onboarding

**Score: 8 / 10** (R1: 4, R2: 6, R3: 7). R4 is the first round where every teaching beat I asked for is on screen:
- the first-wave hint (38, 10: "Tap to snap");
- the chain line on the card (09) and the one-time chain tag (13, 14, 21: "Chain ×1.5! Keep the big bites
  coming");
- "×1.5 held" (42, as "×2 held");
- hungry (33: red numeral, draining glyph, "Hungry… bite!");
- the wilt (34: "Too slow! −1 snap");
- the free sting in the hint slot (43);
- "+2 (full)" at the cap (39).

The lesson's snaps row now matches the first run (14 in 05–09). The Daily label and the scroll chevrons are fixed.

What keeps it from 9:
- a broken pose card (31);
- two contradictions between the HUD and the hints (19/40 and 33/34);
- a costly sting with no cost shown;
- a dry snap with no feedback;
- the lesson captures still don't show the Duo flow.

Frames: `artifacts/r4/screenshots/` (874 × 402, tap build). Preview coordinates (2000 × 920).

## R3 items: fixed / not fixed
| R3 # | Issue | R4 status |
|---|---|---|
| 2 | Hunger/wilt never rendered | **Fixed** (33, 34). The pulse follows `hint == .hungry`. |
| 3 | Toast over pop | **Fixed** (43). |
| 4 | Cover clip | **Fixed** (32). |
| 8 | Fold as input | **Home fixed** (03: 120 pt clap card off the trap). **Pose card regressed** (31). **Lesson step 2 at `fold=1` not captured** (04 is the phone text). |
| 9 | First-wave hint missing | **Fixed** (38, 10). |
| 10 | Chain unexplained | **Fixed** (09 card line; 13 tag; 42 "held"). |
| 13 | Daily under Pause; chevrons on text | **Fixed** (25: "DAILY BOG · 28 OCT" under the score; 28–30 chevrons in a gutter). |
| 15 | Snap glyph reads as lips | **Fixed.** Under 24 pt it's a green pod with a crimson seam (05–43). It reads as "a little closed trap" once the card (09) points at it. |
| 19 | Lesson consistency | **Partly.** The row is 14 throughout (05–09). The bee pointer now curves into the bee (07: arrowhead at 890,430). **Still open:** 05 and 06 are identical again (both "Step 2 of 4: Two flies"). 04 has no snaps row, but 05 does. The phone lesson has 4 steps, while the R3 Duo lesson showed "Step 1 of 5" and "Step 2 of 6" in two frames (`duo3/duo-ui-lesson-2`, `-lesson-1-160`). |

## P0
1. **The pose card (31) is broken.** It shows a black quadrant, a rotated diagram with overlapping traps, a sideways
   "138°", stick hands, and a washed-out title. For a new Duo owner this is the "how do I hold it" screen. App/UI.
2. **"Out of snaps" over a non-zero numeral (19: 1; 40: 2).** A player reads this as a bug in the scoring. Hold the
   tired banner until the numeral drop (≥ 0.25 s after the bite), or drop the numeral at once on the final bite.

## P1
1. **Contradictory hints with a bee in the trap (33, 34).** A haloed bee sits inside the rim and the plate says
   "Hungry… bite!" (33); a snap wilts beside one (34). The halo tells the player "this bee is in the trap", so either:
   - Core counts a haloed (arriving, low) bee as "in the trap" for the hunger pause; or
   - App suppresses the `hungry` plate while any halo is drawn inside the zone, and uses "Bee! Wait…" instead.

   The first is truer to the rule the lesson teaches (07: "Never eat a bee. Wait…").
2. **A costly sting shows no cost (15, 40).** "Stung!" with a crimson flash, but no number. Show "−2 snaps" (wasp) or
   "−1 snap" (bee) as a tag at the row, mirroring "+1 snap" and "free!".
3. **A dry snap is silent (41).** Snaps went 9 → 8, nothing was caught, and the screen shows nothing. Add a small
   "Missed!" puff at the seam, and a "chain lost" tag on the chip when the chain was ≥ ×1.5.
4. **The lesson on a Duo has never been captured.** `screen=lesson;lessonStep=2;fold=1` and `lessonStep=3;fold=1` were
   in the App hand-off, but `ci/scenarios.txt` still captures the phone text. 05 = 06 for the third round. CI.

## P2
1. Home 03: "Snap it shut a little" appears in the subtitle and on the card. Keep the card and give the subtitle the
   rule ("Bite crowds. Spare bees.").
2. Home 01/02: the attract fly overlaps "bees." in the subtitle; keep the attract session out of the title rect.
3. Card 09 is five sentences in 30 pt. Cut "Bees and wasps cost more" (the lesson's bee step taught it) or split the
   card over two beats.
4. The word "protein" (HUD, Results, cover) is charming once and opaque after. Consider "PROTEIN" small under a bug
   icon, or just "score" in the HUD.
5. Bug Book 29: "Golden Scarab" wraps and hides its count. Shrink the name to fit one line, or allow a 3-line card.
6. 42: the scarab bite stacks "+300 / ×2 held / Golden!" and a flying glyph crosses "Golden!". Collapse it to
   "Golden! +300 · +2 snaps".
7. Results 20 is a standard (10-snap) novice run with "First run!". The real first impression is a 14-snap Sprout run
   1 (sim: 105 s). Capture that run's Results for the store and for review.
8. Settings 30: "HUD on the left — Score and snaps on the other half" is good, but "HUD" is jargon. Use "Score on the
   left".
