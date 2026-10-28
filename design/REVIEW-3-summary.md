# Review R3: merged top 20

Frames: `artifacts/r3/screenshots/` (iPhone 18 Pro, 874 × 402 pt, tap build, deterministic pilot). Every log says
`canvas 874x402`, including `fold=1`, so there are **no Duo-aspect frames** again. Reviews:
`REVIEW-3-juror.md`, `-ux.md`, `-feel.md`, `-duo.md`, and `fresh/tester4–6.md`.

## Scores
| Reviewer | R1 | R2 | R3 |
|---|---|---|---|
| ADA juror | 5 | 6 | **7** |
| UX / onboarding | 4 | 6 | **7** |
| Feel / economy | 4 | 6 | **7** |
| Duo specialist | 5 (prov.) | 5 (prov.) | **6** (prov.: still no Duo-aspect frame) |
| Fresh players, "feels finished" | — | 6 / 7 / 5 (testers 1–3) | **7 / 7 / 6** (4: parent, 45; 5: Two Dots fan; 6: Duo designer) |
| Icon, as a store asset | — | (fanged Pac-Man) | **7** |
| Badges, as a set | — | — | **7** |

## Fixed in R3
- **The bite** no longer draws a green iris: the hold stays inside the open trap (13, 14, 18).
- **The trap reads as a flytrap:** two clam lobes, a seam with notches, 76 thin cilia, glands, veins and a petiole
  (01, 10). The rind and seeds are gone.
- **The night** keeps the trap crimson, with fireflies (17, 35).
- **The hints** never clip (18).
- **The HUD** clears the cilia on the phone (22, 23).
- **The lesson** shows the snaps row and the card rings it (05–09). "+1 snap" labels the first refund (13).
- **The bee lesson** has the bee on a drop beside the flies (07).
- **Nectar** sits in visible clusters (12, 17, 35).
- **Pops** are 36–48 pt. The mosquito has six legs.
- **Results copy** reads right (20, 26). Bug Book names wrap and counts vary. The Debug string is gone.
- **The economy** (sim): perfect 5 wilts in 5.9 min, casual 1.5 wilts in 134 s, stinger bites refund nothing and
  score ×1, the chain caps at ×5 at step 8, `maxSnaps` is 14, and Sprout run 1 never wilts.
- **The pilot** is deterministic: 18 → 19 → 20 agree (371 → 419 → Results 419).
- **The icon** has no fangs, and there are 12 badges in one medallion family.

## What all three fresh players raised
- the shut trap (13, 14, 18) reads as a red pepper, a pod or "a bum";
- the 15 toast covers "Stung!" and seems to say a snap was lost;
- the chain chip is never explained;
- text is clipped or covered (32, 25, 28–30);
- the Duo fold is barely visible as the input (03's stamp-sized diagram; "tap to snap" everywhere else).

## Top 20
| # | P | Owner | Fix |
|---|---|---|---|
| 1 | P0 | CI | **There is still no Duo-aspect evidence (third round).** `fold=1` renders at 874 × 402 (logs of 03, 22, 23), and duo2/duo3 are missing. Add a 951 × 669 letterboxed `fold=1` render with the hinge band forced, for Home, lesson step 2, 10, 13, 21, 18, 23, 24, Results and the cover, or run `duo.yml`. Gate sign-off on it. |
| 2 | P0 | CI + App/UI | **Every play demo is a Sprout run 1** (38 logs: `first run options`), so hunger is off and the first sting is free. Frames 33 and 34 are `no-freeze / expect-miss`: the hunger pulse, the red numeral, the droop, "Hungry… bite!", "Too slow! −1 snap" and the costly-sting crack and row flash have never been rendered. Honour `progress=` / add `firstRun=0`, and freeze on `hungry` +0.5, `wilted` +0.3 and costly `stung` +0.2. |
| 3 | P0 | App/UI + Scene | **The rule toast (15):** "Bees cost a snap!" covers the "Stung!" pop, fired for a **wasp**, on a sting that cost 0. Use the copy "Bees and wasps cost snaps. This one's free!", put it in the hint slot, keep the pop clear (test: no plate rect over a live pop), and flash the row green with "free!". |
| 4 | P0 | App/UI | **The cover clips its score (32):** "400 so far" is cut off at the bottom. Fit the card to 402 pt and to the Duo's cover display, with a layout test. |
| 5 | P0 | Scene | **Finish the founder's face.** It samples outer lobe #D7525D (salmon) and margin #E3A26C (a peach band about 12 pt wide), so it still reads as fruit, most of all isolated (32, 20, badges). Outer lobe ≤ #C02A42; a yellow-green blush (≈ #B8C25A, ≤ 40 % alpha) only in the last 8–10 %; the oxblood gradient (#892934 at the midrib) visible across the whole lobe. |
| 6 | P1 | Scene | **The hold doesn't read "shut" (13, 14, 18, 19).** The crimson faces bulge, zipped by cilia (a pod, a pepper, a bottom). Shade the outer half of each closed lobe toward the leaf green, with crimson only at the seam. Use one hold width (13 is 18 %; 14 and 18 are 35 %). Sink caught bugs under the lobes or into the seam within 60 ms: today they sit on top (13: 950,610 and 1050,600; 14: 860,540) and look uncaught. |
| 7 | P1 | Scene | **Dusk is still invisible, then jumps to night.** 12, 16 and 18 (dusk waves 16–18) look like morning; 19, 33 and 34 (dusk waves 20–22) look night-blue. Light by phase: peach haze plus a warm rim for waves 15–22, night from 23, and a whiter noon (11, 14). CI: a wave-18 dusk frame. |
| 8 | P1 | App/UI | **Make the fold the input you see.** Home's `DuoClapDiagram` (03) is about 65 pt and sits on the cilia: give it ≥ 120 pt, animated, off the trap. Capture lesson step 2 with `fold=1`. Pose (31): one trap across the hinge (not two images with two stems), the "138°" label unclipped, and hands. |
| 9 | P1 | App/UI | **The first-wave hint is missing (10:** wave 2, no snap yet, no plate). Fix the trigger and capture `freezeOn=firstHint`. |
| 10 | P1 | App/UI | **Explain the chain.** The chip is "×2" plus a link (11, 25, 35) with no word, and card 09 doesn't mention it. Add "Big bites in a row build a chain" to the card and a one-time tag on the first `chainUp`. Capture "×1.5 held". |
| 11 | P1 | Core | **The novice's first run is 75 s** (log 20: 21 bugs, 17 snaps), and that Results screen is the first impression. Run 1 only: the first 3 dry snaps are free ("Missed! This one's free"), or start at 14. Target the novice pilot ≥ 90 s. |
| 12 | P1 | Core | **Expert wilts 11.5 per run** (no target). Real Duo hands are in this band. Target ≤ 6: night wilt 14 s, the clock paused while a protected bug sits in the trap, or `extraBeeEvery` 60. Re-run the sim. |
| 13 | P1 | App/UI | **Collisions:** "DAILY BOG · 28 OCT" under Pause (25). The scroll chevrons sit on text (28 "for her", 29 "Absolutely not on the menu", 30 "eaten."): add a fade gutter and inset the content. |
| 14 | P1 | Core + App/UI | **Bugs at the midrib in frames:** 10 housefly (960,250), 11 gnat (990,355), Home attract 01 (1020,630) and 36 (1080,580). Anything within ±(20 + r) pt of the crease must look airborne (a shadow offset, 1.1× scale), or the attract and crossing paths must avoid it. Apply the crease rule to `AchievementArt` (`bite5` and `feast` put a fruit fly on the midrib). |
| 15 | P1 | Scene + App/UI | **The snap glyph** at 16 pt (05–35) reads as tiny lips with teeth. Simplify it for small sizes: a closed green pod silhouette with a crimson seam and 3 cilia ticks; larger on the Duo. |
| 16 | P1 | App/UI + Scene | **The isolated trap on Results, cover and the badges** (20, 26, 27, 32; `daily`, `monarch`, `score10k`, `nobees`): centred, with a vertical slit and a small stem, it can read as anatomical. That is a family-game risk. Put a sipping bug on it, or tilt it 3/4 like the icon, and show the leaf back and the petiole leaf. Make the Results image 1.4× on a bog backdrop. |
| 17 | P1 | App/UI (icon artist) | **The icon** is a different illustration from the game (a 3/4 cup and a navy fly against a top-down trap and a grey housefly), and at 29–60 px it can read as a beetle in a bowl or a face. Use the in-game housefly palette, shrink the fly to ≈ 35 % of the trap's width, and show both lobes' crimson edges. |
| 18 | P2 | App/UI | **Badges:** de-duplicate `bite5`/`feast` and `spare50`/`nobees` (different subjects or compositions). Give `scarab` beetle wing cases, not bee wings. Check the circular mask on the 512 px set. |
| 19 | P2 | App/UI | **Lesson consistency:** the lesson shows 10 snaps but Sprout's first run has 12 (05–09 vs 10). 05 and 06 are still identical (rename the scenario or capture the Duo re-arm). The bee pointer's arrowhead lands on the fly (07: 880,370), not the bee. |
| 20 | P2 | CI + Feel | **Store set and evidence:** build the store screenshots from one continuous run (`story=1`: 10/12/16/17 are all at score 0). Use 21 (open-after-bite) as the bite shot, not the hold. Add `freezeOn=chain5` and a dry-snap frame. Log the BalanceTests numbers in CI. Record 50 real-Duo `SNAP-H` snaps from TestFlight. Update GAME-DESIGN §6 (late decay 0.96 / 0.25, lingers 0.92 / 0.2, a bee every 40). |

Also noted, not in the top 20:
- Home's menu still hides half of the right lobe (01–03).
- Home's 60 fps attract thermals are unmeasured.
- The thumb-band entries (12: a bee entering mid-height at the right edge) are not addressed.
- The "+1 snap" tag and chain chip stack on the outer edge, which is the Duo's thumb band.
- "Protein" as the score word confused one player once.

## Launch readiness
Snapjaw is now a good-looking, fair *phone* game. The R3 open trap, the lesson, the Results and the economy are close
to store quality, and the panel moved up a point across the board.

A launch-quality 1.0 of a **Duo-first** game is still blocked on evidence, not on rules:
- **No one has seen the game at the Duo's 951 × 669 aspect since R1, nor on a real hinge.** The fold has never been
  shown working as the input (#1, #8, and the real-Duo `SNAP-H` log in #20).
- **CI renders every run as Sprout run 1** (#2), so the hunger, wilt and costly-sting feedback that make the economy
  legible has never been seen.
- **Four visible polish bugs** would be the first things a reviewer screenshots: the cover clip, the toast over the
  pop, the Daily label under Pause, and the chevrons over text (#3, #4, #13).
- **The hero art still needs one pass** (#5, #6): the peach margin and a closed trap that reads as a red pod with
  uneaten bugs on it.

Fix #1–#6 and capture the result at Duo aspect. Then the remaining work (the dusk, the chain teaching, run-1 length,
the icon and badge cohesion) is ordinary 1.0 polish rather than a launch risk.
