# Review R2: juice and economy

**Score: 6 / 10** (R1: 4). The bite now has the ingredients R1 asked for:
- the hit-stop;
- the lobe squeeze;
- white catch puffs at each caught bug (13: 800,315 / 770,655 / 1080,615);
- the midrib impact puff;
- one hero line, "TRIPLE ×3 · +66";
- refund glyphs that visibly leave the bite (13: the mini trap at 905,510; 14: two at 890,470 and 1040,445).

Feel's CHOMP rework (impact at 0, tail after a 50 ms hit-stop) is the right shape. Two things undercut it:
- the closed-jaw silhouette is wrong (see the juror's P0-1), so the most-seen frame of the game is visually confusing;
- the economy has three leaks that make skilled play feel clock-driven and greedy play unpunished.

## R1 issues: fixed / not fixed
| R1 # | Issue | R2 status |
|---|---|---|
| 6 | Bite read (hit-stop, squeeze, flash, shake) | **Implemented**, but the squeeze draws a green ellipse larger than the open trap (13: x 300–1690 vs open x 370–1630). |
| 10 | Hunger | **Implemented** (33 "Hungry… bite!", 34 "wilted −1"). Balance: see P0-1. |
| 15 | Chain rule | **Implemented.** Casual longest chain 4.5 on 16 seeds, but 6 on 64 seeds (the edge of 3–6). |
| 17 | Show the economy | **Half.** Feast glyphs fly (13, 14), but the numeral updates before the glyph lands (13 already shows "12"). The sting crack is not visible in 15: the row is at 1 with no crimson flash in the frame, and "Stung!" covers the wasp. |
| 18 | Hero pop | **Fixed** (13, 14, 25). |
| 19 | Nectar −30% and clustered | **Smaller: yes. Clustered: no visible clusters.** In 10/21, the drops sit about 180 px apart, evenly spread (the 40–48 pt ring is too wide to read as a group). |
| 20 | Closure tracking | **Better** (24: shorter teeth leaning in, a dark lip). But the green back vanishes entirely at 11°, so the look jumps rather than tracks. |
| 24 | First runs | Sprout 12 snaps: novice 41 → 50 s. Still short (see UX). |

## P0
1. **Hunger is the run-ender for good players.**
   - `core-R2.md`: perfect **16 wilts** per run, expert 11.5, against 25–29 snaps spent. That is one wilt (and one
     stomach rumble) about every 18 s for 5 minutes.
   - A wilt is meant to cap infinite patience, not to tax normal crowd-waiting. Today the best strategy (wait for 5+)
     is punished every cycle, and the sound design will nag.
   - Targets: perfect ≤ 6 wilts, expert ≤ 5, casual ≤ 2 (casual is 2.5 today).
   - Levers, in order:
     - wilt times 18/16/14/12 s (from 15/14/12/10);
     - the timer starts only when the first bug *lands in the trap* after a bite (empty-trap time is not the player's
       fault);
     - keep the perfect median 4–7 min by raising the night bee count instead.
   - Re-run `balance-sim.js` with a `wilts` assertion.
2. **Stinger bites can be net-positive.**
   - Frame 19's log: `snapped caught=4 … stingers=1 points=1032`, then `stung bumblebee cost=1`, `feast snapsBack=1`
     and `luckySnap goldenScarab`.
   - The snap ledger: −1 (the snap) −1 (the bee) +1 (the Feast) +2 (the scarab) = **+1 snap**. The points are also
     scored at ×1.5, the multiplier *before* the stinger breaks it.
   - "Never eat a bee" is half the game, and here eating one was the best move of the run.
   - Rule: a bite with a stinger gets **no Feast refund** (the scarab's +2 stays, since it's a pickup) and scores at
     ×1. Show it in the pop: "Stung! · +172".
3. **The closed jaw must look like a clap** (Scene). Same fix as the juror's P0-1. For feel: the frame after the
   hit-stop must show two lobes meeting at the midrib with interlocked cilia, not an iris. Every freeze in 13–19 is
   that frame.

## P1
4. **Sprout start = cap.** `Tuning.startSnaps` is 10, but Sprout gets 12, and `maxSnaps` is 12. A Sprout who Feasts
   on the first bite (12 → 11 → +2) loses one refund to the cap, and the first glyph flight lands on a full row. Raise
   `maxSnaps` to 14 (two rows of 7) or start Sprout at 11.
5. **Numbers and glyphs must agree.** Increment the numeral when each glyph *lands*
   (0.05 + k·0.12 + 0.45 s), with a tick per glyph. Today it jumps on `snapped` (13). On a sting, crack the glyph
   *before* the numeral drops, and flash the row crimson for 0.3 s. Capture `freezeOn=stung` +0.25 s so CI shows it.
6. **Small catches need juice too.** The single-bug "+10" in 17 is about 12 pt and sits under the fly. Give every
   catching bite a ≥ 28 pt pop; 1-bug bites get "+10" at 32 pt with a 1.15× overshoot. A clean 1-bug bite that holds
   the chain should say so ("×1.5 held").
7. **Nectar clusters.** Shrink the cluster ring to 24–30 pt so the 2–3 drops touch visually. Then crowds form in one
   place on one lobe, and "Now!" (11, 34) points at a *group*, which is the push-your-luck picture the pitch promises.
8. **Hunger telegraph (33).**
   - The draining glyph is a faint pink outline only.
   - At `hunger` 0.7 → 1, the lobes should visibly droop (Scene says y 0.985, x −2%: invisible in 33). Use y 0.95,
     a 15% grey, and teeth leaning 20°.
   - The rumble haptic plus the visual should land together at −3 s.
9. **Chain depth.** Expert longest chain 26 and perfect 24, against a ×4 cap reached at the 6th step: skilled scores
   are mostly "sit at ×4". Consider ×5 at 8 steps with a HUD flare, or decay ×4 → ×3.5 on a 1-bug bite, so skilled
   play keeps choosing.

## P2
10. The dry-snap feedback (2 of the 14 novice snaps in frame 20's log are `caught=0 escaped=0 d≈0.9`) has no frame.
    Add a "snap!" whiff and a 2 pt shake, so a dry snap still feels like a bite, just an empty one.
11. Escape startle marks (15, 18, 19: "\|/" plus motion lines) are good. Keep them short (≤ 40 pt): in 15 they
    stack into white streaks next to the drops.
12. The fade-out pop in 25 ("FEAST ×5 · +170" at about 40% alpha, pink on pink) is illegible mid-fade. Fade by scale
    and lift, not alpha only.
13. CI d-values: the hinge CLI gives `d = 0.010`, clamped to 1/30 s, so every CI hinge snap is "perfect". The
    bite-window feel for the dragonfly (0.12 s) and the mosquito (0.14 s) is unverified until a real Duo logs
    `SNAP-H d=`.
