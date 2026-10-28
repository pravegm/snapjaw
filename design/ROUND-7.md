# Round 7: distinct traps, a FEAST that pays, clean frames (brief)

R6 was scored in `design/SCORE-R6.md`. Medians:
- D1 design 8, D2 ease 8, D3 fun 8;
- D4 satisfaction 7.5, D5 Duo 7.5, D6 pay 7 (but 4 of 5 players say yes);
- D7 replay 8 (target met);
- D8 store 7, D9 polish 7.

R7 must move **D9, D8 and D4** first. The fix list is SCORE-R6 §4; every item there is in scope except #11 (the founder's real-Duo test). The CI Duo run (#2) is run by the founder agent before R7 lands.

## Owners and items (numbers are SCORE-R6 §4)
- **Scene** (`Snap/Scene/*`, `SnapTests/SceneTests.swift`):
  - **#1 (P0): 8 distinct varieties.** A thumbnail at 120 pt must tell each one apart by silhouette or colour, not by name:
    - **B52:** about 15% larger lobes and fat, long cilia;
    - **Sawtooth:** short jagged saw cilia;
    - **Shark Tooth:** wide triangular teeth;
    - **Fused Tooth:** a continuous frill, not single cilia;
    - **Cupped:** a deep cup with a strong gloss and a darker rim;
    - **Red Dragon:** crimson inside and out;
    - **Golden Glow:** a gold interior;
    - **Classic:** as now.

    The same look must show in play, on the hero trap, in the Garden glyph and on Results. Add a test that renders the 8 glyphs and checks that every pair differs by a pixel-difference floor.
  - **#4: clear zones as a tested rule.** Bugs and halos never sit in the HUD rects (`hudKeepOut`), on the midrib band, within the edge margin, or behind the Home buttons. The test runs a seeded sim for N s and asserts that no bug centre and no halo rect enters the keep-out.
  - **#14 (Scene part):** a real night look in 17, 35 and P05, where fireflies glow.
- **Core** (`Snap/Core/*`, `SnapTests/CoreTests.swift`, `BalanceTests.swift`, `tools/balance-sim.js` in lockstep):
  - **#3:** at any chain, a bite of 5 or more bugs must always out-score any 4-bug bite at that chain (one feast bonus, in `Tuning`), with tests;
  - **#14 (Core part):** night spawns favour fireflies and crickets; late-night pacing keeps expert runs ≤ 6 min in the sim;
  - **#15:** goal difficulty tiers exposed (`GoalSpec.tier`: easy / medium / hard);
  - **#10:** Zen scoring is the same function in play and on Results.
- **App/UI** (`Snap/App/*`, `Snap/UI/*` except `AppIconArt.swift`, `SnapTests/AppTests.swift`):
  - **#3:** the bite pop says "5 bugs · +N" (never "×" for a bug count; "×" is only the chain). The FEAST pop is centred, at 1.6×, and shows the snaps refill;
  - **#5:** one message at a time, ≥ 0.4 s apart, with no stacks. "Stung!" goes above the ring and never covers the stinger, and hints never cover bugs. "Lucky!", "Golden!" and "+2 (full)" get plain words;
  - **#7:** Results fits without scrolling on the 6.3" phone, the Duo and the 6.9". No "tired" shows over a "New best!";
  - **#8:** the Duo cover card is centred and filled and says "Best score". The leaderboard's display name is "Best Score";
  - **#10:** a "Zen Bog" HUD badge; the Zen Results demo uses a real Zen run's numbers;
  - **#12:** the Duo lesson's step counter advances with its text, and a visible "Fold it a little" prompt shows when too flat (178°);
  - **#13:** the SNAPS label at every size, with a bigger snaps row on the Duo;
  - **#15 (UI):** a tier dot on Home goals; "Next goal" on Results; Results names the next Bug Book target;
  - **#17:** no "Hungry… bite!" while a halo overlaps the trap edge;
  - **#19:** unlock rules in one style ("Rank: …" / "Goal: …") and identical locked silhouettes.
- **Store, CI and icon** (`ci/*`, `docs/*`, `tools/*` except `balance-sim.js`, `Snap/UI/AppIconArt.swift`):
  - **#6:** store frames 1, 2 and 8:
    - P01 and D01 at a book of about 140°, with no halo cut at the edge;
    - P02 and D02 mid-gulp with the crowd visible;
    - P08 and D08 a calm Zen moment, with no sting.

    Add a Duo hinge-closure frame if `duo.sh` can save one;
  - **#9:** truth and consistency:
    - P04 drops "Real cultivars";
    - P04, P06 and P09 show one progress state;
    - P10 and D10 agree;
    - D06 says "Snap it a little shut";
  - **#16:** scenario hygiene: fix 05 (a duplicate of 06), fix the captions of 14, 17, 23 and 26, de-duplicate, and add a goals-3/3-bonus frame and a Garden-pick frame;
  - **#18:** blend the icon's two lip studs into the lip.

## Shared contracts
- Core puts the feast bonus **inside** `points` in the snapped report. App reads `caught.count` for "N bugs" and the chain from the snapshot; App does not recompute score.
- New Core API: `GoalSpec.tier: GoalTier` (`.easy`, `.medium`, `.hard`), with a static `GoalTier.label`.
- Any new demo key or freeze tag: App adds it to `DemoMode`, and Store/CI uses it in the scenario files. List new keys in your notes so the other side can use them.

## Rules
- Only touch your own files (above).
- Re-read every edit twice for compile errors (there's no local Xcode; CI is the compiler).
- Keep switches exhaustive.
- Never put a rethrowing key-path call inside `#expect`, never write an ambiguous `.nan`, never shadow a static with a local, and compare floats with a tolerance.
- Do not commit or push; the founder agent batches the push.
- Notes go in `design/notes/<module>-R7.md`.
