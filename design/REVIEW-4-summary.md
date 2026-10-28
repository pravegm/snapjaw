# Review R4: merged top 15

Frames: `artifacts/r4/screenshots/`. That is 43 frames on the iPhone 18 Pro (874 × 402 pt, tap build, deterministic
pilot, standard rules unless first run), plus `app-icon-1024.png` and 12 badges. Duo-aspect frames are the R3 build only
(`artifacts/duo3/duo-screens/duo-screens/`, 951 × 669); `artifacts/duo4/` did not exist when this was written.
Reviews: `REVIEW-4-juror.md`, `-ux.md`, `-feel.md`, `-duo.md`, and `fresh/tester7–9.md`.

## Scores
| Reviewer | R1 | R2 | R3 | R4 |
|---|---|---|---|---|
| ADA juror | 5 | 6 | 7 | **7** |
| UX / onboarding | 4 | 6 | 7 | **8** |
| Feel / economy | 4 | 6 | 7 | **8** |
| Duo specialist | 5 (prov.) | 5 (prov.) | 6 (prov.) | **6** (prov.: Duo frames are R3; hinge checks INCONCLUSIVE) |
| Fresh players, "feels finished" | — | 6 / 7 / 5 | 7 / 7 / 6 | **7 / 6 / 7** (7: Wordle + Royal Match, 25; 8: grandparent, 60; 9: Duo-games journalist) |
| Icon, as a store asset | — | (fanged Pac-Man) | 7 | **8** |
| Badges, as a set | — | — | 7 | **7** |

## Fixed in R4
- **Demos run standard rules.** Hunger (33), the wilt (34), the costly sting (40) and the free first sting (43) are
  all on screen at last.
- **The free-sting toast** is in the hint slot, with the founder's copy, clear of the pop, and the row flashes lime
  with "free!" (43).
- **The cover** fits (32). The Daily label sits under the score (25). The chevrons sit in a gutter (28–30).
- **The hold** reads as a shut leaf: green backs, a crimson seam, one width, and the bugs swallowed (13, 40).
- **The face** has no peach rind in play (10, 38).
- **Dusk** has its own light (12, 16, 37). The night keeps a crimson trap (35).
- **The first-wave hint** shows (38). The chain is taught: on card 09, by the one-time tag (13) and by "held" (42).
  "+2 (full)" shows at the cap (39).
- **The lesson row** matches the first run (14). The bee pointer lands on the bee (07).
- **The isolated trap** is 3/4, with a leaf back and a petiole (20, 26, 32, badges). The anatomical read is gone.
- **The icon** uses the game's housefly at about 35 % of the trap's width (8/10). The badge duplicates are resolved,
  and the scarab has elytra.
- **The economy** passes every sim check: casual 147 s with 0 wilts, expert 3 wilts (11.5 in R3), perfect 6.3 min,
  and novice Sprout run 1 at 105 s.

## What all three fresh players raised
- **31 looks broken.** All three said so.
- The dark red shape after a bite reads as "a plum" (14, 39).
- "Out of snaps" shows over a counter of 1 or 2 (19, 40).
- "Hungry… bite!" shows with a bee in the trap (33).
- "Protein" and the "×… held" chip are opaque.
- Two of the three: the Results/badge trap reads as a watermelon slice. The dusk looks muddy.
- The journalist: there's no Duo or hinge anywhere in the press kit.

## Top 15
| # | P | Owner | Fix |
|---|---|---|---|
| 1 | P0 | CI (founder) | **Duo evidence, for the fourth round.** `duo4` hasn't landed. The R3 Duo run has frames but SNAP / REARM / CREEP / CLOSE-PAUSE INCONCLUSIVE (2 simulator deaths, 6 hinge timeouts). Fix the rig (fresh simulator per launch, shorter `hinge -t`), then require a hinge-input `snapped` line, re-arm, creep, the < 50° pause and resume, no pause at 95°, the too-flat hint at 178°, and R4 frames of Home, pose, lesson 2–3, 10, 13, 21, 23, 25, Results and the cover display. Add 50 real-Duo `SNAP-H` snaps from TestFlight. Gate sign-off on both. |
| 2 | P0 | App/UI | **The pose card renders broken (31):** a black quadrant, a rotated portrait diagram with overlapping traps (430–760, 220–830), a sideways "138°", stick hands, and the title under a translucent overlay. This regressed with "scale the drawing to fill the page". Fix it at 874 × 402, 951 × 669, portrait/tabletop and the cover display, with a snapshot test. |
| 3 | P0 | Scene | **The release reads as a plum or a bottom (14, 18, 19, 39, 41, 42, 43).** For about 0.3 s after each bite the lobes are dark oxblood, narrower, with no lime rim and only faint inner cilia, and that's the Feast frame (39). Keep the rim and the outer cilia through the release, return the face to open-state crimson within ~80 ms, and darken edges only while closing. Check it at Duo aspect, where it fills the height (R3 `store-07`). |
| 4 | P0 | App/UI + Feel | **"Out of snaps" over a non-zero numeral (19: 1; 40: 2).** The tired banner fires before the 0.20 s numeral drop. Sequence it: drop and blip at 0.20 s, then the banner and yawn at ≥ 0.45 s (Feel's `afterLoss`). Add a test: no `tired` plate while the shown snaps > 0. |
| 5 | P1 | Core + App/UI | **"Hungry… bite!" next to a haloed bee (33), and a wilt beside one (34).** Count a protected bug as in the trap once it is inside the zone and below `creaseAirHeight` (final approach, halo drawn). Re-sim perfect ≤ 5 wilts with no cap. If it fails, at minimum App shows "Bee! Wait…" instead of the hungry plate while any halo is inside the zone. |
| 6 | P1 | Scene + App/UI (icon artist to advise) | **One hero trap.** The 3/4 trap on Results, the cover and 5 badges reads as a watermelon wedge (a stippled red cap on a ribbed green bowl) and is a different drawing from the icon's open jaw. Redraw `.threeQuarter` from the icon's geometry: open jaws, a lime lip, cilia on both lips, no stipple at hero size, and a sipping fly. |
| 7 | P1 | App/UI + Feel | **Make the sting's cost legible (15, 40).** "Stung!" carries no number. Show "−1 snap" / "−2 snaps" at the row (the mirror of "+1 snap" and "free!"), with a heavier wobble for a wasp. CI: capture a mid-run costly sting (both of today's are also the run's end). |
| 8 | P1 | Core | **Sprout run 2 cliff.** It's unmodelled. Run 1 gets 14 snaps, no wilt, a free sting and a calm morning. Run 2 gets 12 snaps with everything on (standard novice: 45 s). Add `novice, Sprout run 2` to the sim with a ≥ 75 s target. If it fails, taper the perks over Feed runs 1–3. |
| 9 | P1 | Scene | **Dusk is olive-khaki, and the rim goes salmon (12, 16, 37).** Warm it toward peach/rose and keep the warm rim off the lobe margin (the rind creeps back at dusk). CI: freeze 17 at `night` +1.5 s, so it isn't caught mid-ease (today it still shows dusk at wave 23). |
| 10 | P1 | App/UI + Feel | **The dry snap is silent (41).** Add a hollow "clop" with no squelch, a "Missed!" puff at the seam, and a cracked chip when the chain was > ×1. |
| 11 | P1 | CI | **Capture the Duo lesson and the real first impression.** `lessonStep=2/3;fold=1` were in the App hand-off but aren't in `scenarios.txt`. 05 = 06 for the third round. The phone shows "Step n of 4", while the R3 Duo showed "Step 1 of 5" and "Step 2 of 6". Capture the Results of a full Sprout run 1 (20 is a standard 10-snap novice run tagged "First run!"). |
| 12 | P2 | App/UI | **Pop and text collisions:** <ul><li>a glyph over "Golden!" (42), with "+300 / ×2 held / Golden!" stacked;</li><li>"DOUBLE ×2 · +32" on a bug (18);</li><li>the attract fly on the subtitle "bees." (01, 02);</li><li>"Golden Scarab" hides its count (29);</li><li>03 repeats "Snap it shut a little".</li></ul> |
| 13 | P2 | App/UI | **Words and sizes:** <ul><li>"protein" as the score word, "×… held" and "HUD on the left" confused two of three players;</li><li>the play-screen snaps numeral and glyphs are small next to the score;</li><li>card 09 is five sentences.</li></ul> Plain words ("score", "Score on the left"), a bigger snaps numeral, and a shorter card. |
| 14 | P2 | App/UI (badges) | **Badges:** <ul><li>5 of 12 reuse one trap drawing;</li><li>the petiole leaf breaks the ring on `daily`, `feast`, `monarch` and `nobees`;</li><li>outlined bugs sit on an outline-free trap.</li></ul> After #6, vary the compositions and keep the art inside the disc. Icon: lighten the two "nostril" dots on the front lip (480,710 and 595,690). |
| 15 | P2 | CI + Core | **Evidence hygiene:** <ul><li>keep the Dynamic Island pill out of frames (03, 05, 15, 16, 17);</li><li>`chain5` should capture ×5, the cap (39 shows ×3.5);</li><li>add an airborne cue (shadow offset, 1.1×) for flyers over the crease (10: 960,250; 41: 985,780);</li><li>don't spawn bee entries in the Duo thumb band (11, 12, 18, 19);</li><li>regenerate the whole store set from the R4 Duo run, using an open-after-bite frame for the bite shot, not the hold or the release.</li></ul> |

Also noted, not in the top 15:
- The Home menu still hides most of the right lobe (01–03).
- The late night ends runs by outrunning hands (floor 0.2); consider telegraphing it.
- `pilotGiveUp` should be reported in `SNAP-BAL` with and without it.
- The too-flat plate didn't show at 178° in R3's Duo frame.
- Player 7 asked for a Daily share card (Wordle-style).
- Player 8 asked for a relaxed, no-run-out mode.

## Launch readiness
**Not yet a launch-quality 1.0.** As a *phone* game Snapjaw is close:
- the rules teach themselves;
- the economy passes every target;
- the hold, the cover, the toast, the dusk and the icon all landed;
- the panel went up a point on UX, feel and the icon.

A Duo-first premium game is still blocked on these.

**Blockers (must fix before submission):**
1. **No one has seen the hinge work** (#1). There's no R4 Duo frame, the R3 Duo hinge checks are all INCONCLUSIVE,
   and there's no real-Duo snap log. The store set must come from an R4 Duo run.
2. **A broken screen** (#2): the pose card in this build. Every fresh player flagged it, and on a Duo it's the screen
   shown to anyone holding it wrong.
3. **The bite's hero moment reads as a plum or a bottom** (#3): the release frame, which is what a Feast screenshot or
   a reviewer's capture will show. It's the same family-game risk the founder made P0 in R3.
4. **The HUD contradicts the banner at every run's end** (#4): "Out of snaps" over 1 or 2.

**Polish (ship-quality 1.0 work, not launch risks):** #5–#15. That's the hungry-vs-bee contradiction, one hero trap
instead of the watermelon wedge, the sting cost number, the Sprout run-2 taper, the dusk tone, dry-snap feedback, the
Duo lesson capture, collisions, wording, the badges and the evidence hygiene. #5 and #6 are the two I'd do in the same
round as the blockers. Both are cheap, and players noticed both.

Fix #1–#4, capture the R4 build at Duo aspect with a working hinge, and Snapjaw is a launchable 1.0.
