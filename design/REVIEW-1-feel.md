# Review R1 — juice and economy (Vlambeer school)

**Score: 4 / 10.** The sound and haptic design on paper (`feel-R1.md`) is excellent: layered CHOMP, countable
crunches, a marimba that grows with the chain. The *picture* of the bite doesn't match it. From the stills, the snap
is a vignette and a "+10"; the bugs are crumbs; and the economy lets a patient player live for ever.

## The snap moment
- **13-play-snap (0.12 s after a bite):**
  - The lobes are still fully open: nothing moves inward except a ring of tiny teeth on the rim.
  - The caught fly is a gold spark the size of a nectar drop.
  - A second fly sits there untouched.
  - There's no impact frame, no displacement, and no squash. It reads as "the screen dimmed".
- **14-play-feast:** the best frame, but the reward is four lines of text stacked over the midrib. The sparkles land
  *on* the "FEAST ×5" text. Nothing travels to the HUD, so the "+2 snaps" is told, not shown.
- **15-play-sting:** "Bzzt!" covers the bee, and the snaps row just goes hollow. There's no hurt beat.
- **24-play-jaws-half:** the teeth lean in and the rim browns, but the lobes' 3% foreshortening is invisible. The
  screen doesn't agree with your hands yet.

## Fixes (prioritised)
**P0**
1. **Make the bite a bite** (Scene, `BogJaws`). On `snapped`:
   - scale each lobe's x to 0.6 towards the midrib for the 120 ms hold, with the teeth interlocked at the new edge;
   - widen the slam-jaw silhouette to cover 40% of each lobe;
   - add a 50 ms hit-stop (freeze bug motion and FX, keep audio);
   - flash the caught bugs white for 2 frames;
   - shake 4 pt + 2 pt per bug (Reduce Motion: none);
   - spring the lobes back with a 1.08 overshoot on re-arm.
2. **Bugs ×1.8** (Scene art scale; keep Core's radius ×1.3 for spacing):
   - housefly 28 → 50 pt across on the Duo, gnat 14 → 25 pt;
   - their charm (eyes, cheeks, brows) only exists at that size;
   - today a fly is ~3% of the canvas width.
3. **Kill the streak artefact** (10, 11, 12, 18, 19, 21–23). It also reads as motion where none exists.
4. **Hunger, the fix for endless patient play** (Core + Feel + Scene + App):
   - **The rule:** `Tuning.wiltSeconds` = 15 s in the morning, 14 at noon, 12 at dusk, 10 at night. That long without
     a catching bite (≥ 1 bug, no stinger) wilts one snap. A dry snap does *not* reset the timer.
   - **Warning:** 3 s before, a `TrapEvent.hungry` fires: the leftmost snap glyph drains like a clock, the teeth
     droop 10%, the hint says "Hungry… bite!", and a stomach-rumble haptic plays.
   - **Why it works:** the sim's `T.wiltSeconds=15` ends perfect at ~5.8 min and expert at ~5.5 min, with novice
     and casual unchanged. That's the design's 6–8 min. It caps hinge wear (a run is ≤ ~60 snaps) and makes the
     leaderboard a skill race, not a patience test.
   - Patience is still the core skill: 10–15 s is 3–4 waves of choosing.

**P1**
5. **Chain is too cheap** (casual longest chain 11; ×4 at 7 clean bites). Only bites of **≥ 2 bugs** grow the chain
   (+0.5). A 1-bug bite *holds* it, and a dry snap or a stinger breaks it. Expect a casual longest chain of ~4–5,
   which is the store kit's 3–5. Four Times Hungry (`longestChain >= 7`) stays as written, but now means something.
   Re-run `balance-sim.js`.
6. **Show the economy.** On a Feast, fly the +1/+2 snap glyphs from the bite centroid to the snaps row (0.45 s ease-in,
   and a pop plus a haptic tick as each lands). On a sting, crack the lost glyph (two halves fall 20 pt and fade) and
   flash the row crimson once.
7. **One hero pop.** Merge the four Feast lines into "FEAST ×5 · +255" at 1.4× size, and put the chain step on the
   chip ("×2!" bump) instead of on the lobe. Offset every pop to above its bugs (y + 2r + 20 pt), clamped to one half
   (never across the crease).
8. **Closure tracking:** lobe foreshortening 3% → 15% at `closure01 = 1`, and the edge shade reaches 30% of the lobe
   width (24). Draw from `HingeTrapSource.predictedAngle` so the teeth glide instead of stepping at the report rate.
9. **Crowd density.** Frames show 2–5 bugs on a trap that fills 60% of the screen (10, 16, 17). After the ×1.8 scale
   it'll feel fuller. Also put the nectar drops 30% nearer each other per lobe (cluster 2–3 drops), so crowds *form*
   visibly in one place and the "wait for it" read is spatial.
10. **Novice run is 46 s / 12 snaps** (balance table). That's too short for a paid first impression. Give runs 1–3
    (rank Sprout) `startSnaps` 12, or make the first bee of each run cost 0 extra with a "Bzzt — bees cost a snap!"
    teach.

**P2**
11. **Escapes.** The whiff should be a visible 3-line burst plus the bug darting off at 1.8× with a tiny "!" (the
    startle exists; make it 1.5× bigger). That way a missed slow snap reads as *your* fault.
12. **Sip read.** Have sipping bugs dip their heads into the drop (the drop shrinks 3% per second while sipped), so
    "it's busy, now's the time" is visible without the ring.
