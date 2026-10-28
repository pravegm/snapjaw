# Round 6: depth, moments and truth (brief)

R5 is the scorecard baseline (`design/SCORECARD.md`, `design/SCORE-R5.md`). Every dimension is below target:
- **Below 8:** fun 7, satisfaction 7, willingness to pay 7 (3 of 5 players), replay 7, store 6, polish 7.
- **Close:** design 8, ease 8, Duo 7.5.

The two players who said no to £1.99 gave the reason: "endless only, and Fold Smasher is free". So R6 adds **depth and
reasons to come back**, makes the **big bite an event**, and fixes **truth and polish**.

## Founder decisions (new features)
1. **Goals (D3, D6, D7).** Three active goals at a time, from a pool of about 36, shown on Home and in the pause
   menu, ticked live with a toast when completed, and summarised on Results.
   - **Examples:** "Catch 3 dragonflies in one run", "A 5-bug bite", "Spare 8 bees in one run", "Reach ×3 chain",
     "Catch a firefly at night", "Score 2,000 in the Daily", "Feast twice in one run", "No dry snaps until dusk".
   - **Difficulty:** goals scale with plant rank.
   - **Payoff:** each completed goal gives growth (it adds to the rank bar; a goal is worth bugs-equivalent) and is
     replaced by a new one. Completing 3 at once gives a bonus.
   - **Ownership:** Core defines the pool and pure evaluation (from events and the RunResult); the App tracks
     progress and persists it.
2. **The Garden: trap varieties (D6, D7, D1).** The new contract enum is `TrapVariety`. There are 8 cosmetic
   varieties based on real cultivars:
   - Classic (start);
   - Red Dragon (all crimson, even outside);
   - B52 (big, wide lobes, chunky cilia);
   - Sawtooth (jagged short teeth);
   - Shark Tooth (triangular teeth);
   - Fused Tooth (teeth fused into a frill);
   - Cupped Trap (deep cup, glossier);
   - Golden Glow (fantasy gold sheen, the final unlock).

   They unlock by rank (about every 1.5 ranks) and by special goals. Home → **Garden** shows them (locked ones as
   silhouettes with the unlock rule), and you pick one. The play scene, Home and Results use it. Rules are identical.
3. **Zen Bog (D6, D3).** The new `RunMode.zen` is in the contract:
   - no snaps running out, no hunger, no leaderboard;
   - a gentle endless bog (bees still cost nothing but the chain);
   - an "End" button in the pause menu goes to Results;
   - it still fills the Bug Book and counts toward goals marked "any mode";
   - Home gets a Zen button.

   This answers the grandparent and the 12-year-old.
4. **Daily streak + Share (D7).** The Daily result shows a streak ("🔥 4 days") and the Share line (with the streak).
   Home shows the streak. Persisted.
5. **FEAST as an event (D4, D3).** A bite of 5 or more bugs, or ×4 chain or more, gets:
   - an 80 ms hit-stop;
   - a gold juice burst and a camera punch;
   - a big "FEAST!" banner (scale overshoot, sparkles);
   - the caught bugs visibly gulped into the midrib one after another;
   - the snaps row refilling with a flourish;
   - a special CHOMP (a deeper body, a crunch cascade per bug, then a choir/marimba sting and a "burp");
   - a heavier haptic.

   A 3–4 bug Feast keeps the current treatment. Caught-bug juice is gold, not beige, everywhere.

## Fix list (SCORE-R5 §4)
Items #3–#7, #9–#20 are in scope, by owner below. #1 and #2 are CI (founder).

## Owners
- **Core:**
  - the goals pool and evaluation (pure, tested, deterministic per seed where it matters);
  - `Varieties`: unlock rules by rank and goals, with names and blurbs;
  - Zen `SessionOptions` (`.for(.zen)`);
  - #13: the Duo lesson's step text is chosen on the first hinge sample, if that's Core-side;
  - #15;
  - #19: late-night pacing, an expert run ≤ 6 min with a telegraphed end ("The night gets fast…");
  - the sim and the tests.
- **Scene:**
  - **varieties:** `BogScene.variety` and `TrapArt` drawing for all 8, in play, the hero trap and the snap glyph;
  - **FEAST:** the visuals;
  - **#5:** a real dusk and a blue night, with night bugs in the trap;
  - **#7:** the HUD zone, midrib and edge clearance for bugs and halos;
  - **#17:** the tired trap keeps its lime rim;
  - gold juice.
- **Feel:**
  - the FEAST CHOMP and haptic;
  - a goal-complete chime;
  - a variety-unlock fanfare;
  - a gentle Zen bed (softer, no warnings).
- **App/UI:**
  - **Goals UI:** Home card, pause menu, live toast, Results;
  - **Garden:** the screen and picking a variety;
  - **Zen:** a Home button, the pause "End" button, and Results for Zen;
  - **Daily:** Results with streak + Share, the streak on Home;
  - **#6:** one message at a time, through a message queue, with pops never over their subject;
  - **#12:** the Duo cover card;
  - **#14:** a bigger snaps numeral with a "snaps" label and a one-time chain explainer;
  - **#16:** Results names the next Bug Book target;
  - all new demo keys for CI frames: `screen=garden`, `mode=zen`, `freezeOn=bigFeast`, `freezeOn=goalDone`,
    `screen=results` with goals, the Daily share.
- **Icon:** #18, lighten the two dots on the front lip.
- **Store copy (founder):** #3. ×5, "Score on the left", max 14, plus the new features: goals, Garden, Zen, streak.

Rules as before: only your own folders; re-read twice for compile errors; exhaustive switches. `RunMode` has a new
case `.zen`, and there's a new enum `TrapVariety`. Never put rethrowing key-path calls inside `#expect`; never write
an ambiguous `.nan`; never shadow a static with a local. Notes go in `design/notes/<module>-R6.md`.
