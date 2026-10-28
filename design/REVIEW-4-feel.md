# Review R4: feel and economy

**Score: 8 / 10** (R1: 4, R2: 6, R3: 7). R4's rule changes are the right ones, and the sim says they work:
- hunger ticks only while food waits and no protected bug has landed;
- night wilt is 14 s;
- Sprout run 1 has 14 snaps;
- the first morning is calm.

For the first time the economy feedback is visible in frames:
- hungry (33);
- the wilt (34);
- the costly sting's crimson row (40);
- the free sting (43);
- "+2 (full)" at the cap (39);
- "held" (42).

The bite itself looks juicier: in 13 the shut trap swallows the bugs (none sit on top), and 21/22 show juice splats on
the reopened face. What stops it at 8:
- the release frame looks like a dark plum (14, 18, 39), which undercuts the CHOMP;
- the run's end garbles the economy read (19, 40);
- a weak player's **second** run is unmodelled and probably falls off a cliff;
- nothing here is heard or felt on a real hinge yet.

Sources: `design/notes/core-R4.md` (16 seeds, 60 Hz, 600 s cap), `feel-R4.md`, frames `artifacts/r4/screenshots/`,
logs `…/logs/*.at-capture.txt`.

## Balance (core-R4) against the R4 targets
| Skill | Seconds | Snaps | Wilts | Target | Verdict |
|---|---|---|---|---|---|
| novice (standard) | 45 | 10 | 0 | — | Harsh, but a standard novice is rare (a Sprout gets 12 snaps; see P1-1) |
| casual | 147 | 24.5 | 0 | 100–240 s, ≤ 2 wilts | ✔ |
| expert | 326 | 43 | 3 | ≤ 6 wilts (R3: 11.5) | ✔ |
| perfect | 377 | 43 | 3 | 240–480 s, ≤ 5 | ✔ |
| novice, Sprout run 1 | 105 (p10 82) | 18.5 | 0 | ≥ 90 s | ✔ (16-seed margin 15 s; 8-seed 101 s) |
| casual, Sprout run 1 | 165 | 29 | 0 | never wilts | ✔ |

The CI frames agree with the sim. The novice pilot's standard run ends at **47 s, 9 bugs, 111** (log 20: `run
score=111 bugs=9 snaps=11 seconds=47`), and 18 → 19 → 20 agree (99 → 111 → Results 111).

## R3 items: fixed / not fixed
| R3 # | Issue | R4 status |
|---|---|---|
| 2 | Hunger / wilt / costly sting never seen | **Fixed** (33, 34, 40). |
| 6 | Caught bugs sit on the hold | **Fixed** (13: nothing on the closed trap; the sink is ≤ 60 ms). |
| 11 | Novice run 1 is 75 s | **Fixed in sim** (105 s, with 14 snaps and a calm first morning). Not captured: there's no end-to-end Sprout run-1 frame (20 is a standard run). |
| 12 | Expert 11.5 wilts | **Fixed** (3). |
| 20 | Chain5, dry-snap frames, BAL in CI | **Partly.** 41 is the dry snap and 42 is held, but 39 `chain5` shows **×3.5** (the 5th chain step), not ×5. The `SNAP-BAL` block is printed, per core-R4. Still missing: 50 real-Duo `SNAP-H` snaps. |
| QA-2 #16 | Voice steal clicks | **Fixed in code and test** (6 ms fade, a 30 ms protect window, `twoBigBitesCloseTogetherNeverClick`). Not heard on a device. |
| QA-2 #9 | The loss blip lands before the numeral | **Fixed** (`numeralDropAt` 0.20 s, guarded by a test). See P0-1 for the banner. |

## P0
1. **The end of a run garbles the economy (15, 19, 40).** At the last bite, three things happen out of order:
   - the tired banner appears at once;
   - the numeral drops at 0.20 s;
   - the loss blip plays at 0.20 s.

   So frames show "Out of snaps" over **1** (19) and **2** (40). Order it: numeral drop and blip (0.20 s), then the
   tired banner and the yawn (≥ 0.45 s). Feel already has `afterLoss` 0.52 s for the knocks and yawn; use the same
   beat for the banner. App + Feel.
2. **The release undercuts the CHOMP (14, 18, 39, 41, 42).** Right after the bite, the trap goes dark oxblood with no
   lime rim, so the satisfying moment reads as a bruise-coloured plum. The splats and pops are fine. The leaf isn't.
   Scene (see juror P0-2).

## P1
1. **Sprout run 2 is unmodelled.** Run 1 gets 14 snaps, no wilt, a free sting and the calm morning. Run 2 drops to 12
   snaps, wilts on, the normal wave mix and full sting costs, all at once. The standard novice is 45 s, so a weak
   player's second run is plausibly about 55–60 s, half of run 1, and that is where refunds happen. Add `novice,
   Sprout run 2` to the sim with a ≥ 75 s target. If it fails, ease the perks out over the first 3 Feed runs (run 2:
   calm waves 1–8 and 13 snaps). Core.
2. **Hunger vs a haloed bee (33, 34).** The clock ignores bees that haven't landed (core-R4 rejected "in the bite"
   because at night bees are always arriving). But the frames show a halo inside the rim with "Hungry… bite!". A
   middle rule: count a protected bug as "in the trap" once it is **inside the zone and below `creaseAirHeight` (0.5)**.
   It's on its final approach, the halo is drawn, and it leaves the deep-night "always arriving" bees out. Sim it
   against the perfect ≤ 5-wilt and no-cap checks. Core.
3. **Costly stings need a number (15, 40).** The crimson row flash is subtle at 16 pt glyphs. Add "−2" at the row
   (the mirror of "+1 snap") and a heavier haptic wobble for a wasp than a bee. App + Feel.
4. **Dry snap (41).** A dry snap costs a snap and breaks the chain. Give it a sound and a look: a soft hollow "clop"
   (no squelch), a "Missed!" puff, and the chain chip cracking when it was > ×1. Feel + App.

## P2
1. **The late night ends runs by outrunning hands.** The 0.2 floor makes every night bug but the scarab faster than
   80 ms by about wave 70. That's an honest timer, but it will feel like "nothing is catchable" rather than "I got
   greedy". At wave ≥ 50, telegraph it: "The night is fast now", and a scarab every ~8 waves as the last real catch.
2. **`pilotGiveUp` (12 s) changes the player model, not the game.** That's fine, but the expert/perfect wilt numbers
   now partly measure the pilot. Report them with and without it in `SNAP-BAL`.
3. **The calm first morning is invisible** (core-R4 flags it). Keep it, and say it in GAME-DESIGN §5 (done) and in
   the release notes, so a reviewer who replays run 1 isn't surprised.
4. **39 `chain5` should capture ×5** (the 8th step, the cap), with the chip flare. Today the tag fires at ×3.5. CI.
5. **No real-Duo feel log yet.** Once TestFlight has one, record 50 `SNAP-H` snaps (d, depth, catches) and the
   "Bzzt / lost" blip at 0.20 s over a wasp's second zap (feel-R4 risk).
