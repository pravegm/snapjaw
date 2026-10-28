# App engineer: Round 4 hand-off

Folders: `Snap/App/`, `Snap/UI/` (`AppIconArt.swift` untouched), `Snap/Persistence/`, `SnapTests/AppTests.swift`.
**Not compiled.** Every touched file re-read twice (exhaustive switches, ViewBuilder `let`s, isolation, tuple labels,
no rethrowing or key-path calls inside `#expect`). Checked against the R3 phone frames and the founder's Duo frames
(`artifacts/duo3/duo-screens/duo-screens/`: home-160, cover, pose card, store-11).

## REVIEW-3 items
- **#2 demo rules.** Play demos run the standard rules unless `firstRun=1` or `progress=fresh`. With no `progress=` they
  also use Core's standard start (10 snaps, as `progress=mid` does). `firstRun=0` forces standard rules. A demo
  lesson shows the first-run row (14) unless `firstRun=0`. New freeze tags:
  - `firstHint`: the fold line is on its plate (a state, frozen at once);
  - event tags: `chain5`, `drySnap` and `held` hold +0.3 s, `costlySting` (cost > 0) +0.2 s;
  - re-timed: `hungry` is now +0.5 s, `wilted` +0.3 s.
- **#3 free sting.** The founder's copy is in the hint slot, on the cream plate, a size smaller (`HintFit.toastSize`
  14/18) so it fits in 3 lines. `HUDLayout.hintSlot` moves the plate to the inner bottom while a live pop
  (`scene.livePopRects`, rounded to 8 pt) is under the top slot. If both slots are covered, the plate waits. The
  banner is kept off pops too. The row flashes lime with a "free!" tag. QA-2 #5: the crimson flash and
  `HUDValues.stings` only count stings that cost something.
- **#4 cover.** `CoverLayout` measures the type. On a wide canvas the trap sits beside the words; there is no scroll.
  Tested at 874×402, 402×874, 466×678 and 678×466.
- **#8 fold.**
  - Home: a 120 pt looping clap card ("Snap it shut a little" plus one line) above Feed. It is opaque, so it never
    sits on the cilia.
  - Pose card: one trap image laid across both screens (one stem, the midrib on the hinge), hands (palms behind,
    thumbs in front), and "138°" under the hinge. The drawing scales to fill the page (it was ~250 pt on the Duo).
  - Lesson: demo `fold=1` plays the Duo lesson on a phone sim: the clap on step 2, the "Open up to reset" re-arm step
    and "Step n of 5".
- **#9.** The fold line shows in waves 1–2 (it was wave 1 only), up to 40 s after the run-start line, until the first
  snap.
- **#10 chain.** Card 09 adds "Big bites in a row build a chain." A player's first chain step ever
  (`longestChain == 0`) shows "Chain ×1.5! Keep the big bites coming" in the hint slot. A clean one-bug bite sets the
  chip to "×1.5 held" for 1.4 s.
- **#13.**
  - The Daily's name is now the score's caption line ("DAILY BOG · 28 OCT", under 165). It was under Pause on both the
    phone and the Duo.
  - Scroll columns end in a clear 40 pt gutter. The chevron sits in it, and `contentMargins` lets the last card scroll
    clear of it.
- **#16.** Results (1.4×, on a moss patch) and the cover use `TrapArt.trapImage(style: .threeQuarter, sippingBug:
  .housefly)`. The pose card adds the same 3/4 trap under its words. Its Duo diagram keeps the play trap on the
  screens, because the card shows what the screens show, with the fly always on. Badges draw the 3/4 trap
  (`SceneHooks.threeQuarterPoint` puts the bugs on its back face). If the Scene image is nil, the open trap is tilted
  instead.
- **#18 badges.**
  - `bite5`: a ring of five bugs round the 5, with no trap.
  - `feast`: the 3/4 trap with three sippers.
  - `nobees`: the trap with flies and a bee flying off along a dashed trail, with no halo (unlike `spare50`).
  - `scarab`: folded wings under drawn gold elytra.
  - `daily`, `monarch`, `score10k`: resized to fit the disc.
- **#19 lesson.**
  - The lesson's row shows what the next Feed run starts with (14 for a first run).
  - The bee pointer's arrow curves in from the side that misses the other bugs (`LessonPointer.approach`).
  - 05 vs 06: capture step 3 with `fold=1` (see CI below).

## QA-2
- **#2/#3/#4:** `AppRules.truthfulSnaps` keeps the shown count between what was shown and Core's count, and holds for
  the one frame whose events the Scene hasn't drawn yet (that replaces the republish-after-draw idea). A Feast at the
  cap shows "+n (full)".
- **#6:** the anchor is `glyphCenter(snapsLeft − 1)`, and `hudSnapsRowRect` is set.
- **#7:** `showsEconomy` is false on Home and true in play.
- **#10:** the hunger pulse follows Core's `hint == .hungry`, which stays up through a dry snap and drops while the
  clock is paused (core-R4).
- **#11:** `ProgressData.feedRuns` counts Feed runs only. Older saves take `runs`. Run 1 uses Core's
  `options.firstRun`. Its R3 switches and `startSnaps = Tuning.firstRunSnaps` (14) are set too.
- **#15:** above 176° the pose step says "Bend it a little, like a book".
- Duo glyphs are 24 pt (`glyphDuo`) for Scene's full glyph. They shrink only to clear the cilia.

## For CI (`ci/scenarios.txt` is not mine)
- First-run scenes (frames 15 and 20) need `firstRun=1` (or `progress=fresh`). Frames 33 and 34 (hungry, wilted) now
  get real rules with no extra key.
- New captures:
  - `freezeOn=firstHint`, `chain5`, `costlySting`, `drySnap` and `held`;
  - `screen=lesson;lessonStep=2;fold=1` (the Duo clap);
  - `screen=lesson;lessonStep=3;fold=1` (the re-arm step, so 05 ≠ 06).
