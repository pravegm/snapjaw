# Store, CI and icon: R7 notes

R7 brief items #6, #9, #16 and #18 (`design/ROUND-7.md`, `design/SCORE-R6.md` §4). Nothing is committed. Nothing was compiled
here, so the Swift (`ci/store-frame.swift`, `ci/store-banner.swift`, `Snap/UI/AppIconArt.swift`) is unverified until CI
runs. I did not touch `ci/duo.sh`, `.github/workflows/*` or `ci/duo-scenarios.txt`, because a Duo run is using them.

## #6: store frames 1, 2 and 8

### P01 and D01: a book of about 140°
Two causes. store3 drew the book at 146°, the `auto` reading of a hinge held at 150°. It was also seen nearly head-on
(tilt 8°, camera 3.4 page heights), so only the top edge showed a V.
- `ci/duo-store-scenarios.txt` D01 now adds `ciHinge=140`. `duo.sh` already supports this key today: it moves the real
  hinge to 140° after the launch. The pilot drives the trap, so the angle doesn't change play. The composite's `auto`
  angle is therefore the logged hinge angle.
- `ci/store-set.sh` and `ci/store-placements.sh`: `auto` keeps a reading of 130–150°. Anything outside that range falls
  back to 140° (it was 120–170°).
- `ci/store-frame.swift` and `ci/store-banner.swift` book geometry:
  - The defaults are now tilt 15° and `--distance` 2.8 page heights (a new option, clamped to 2.2–5).
  - store-frame's side layout (the iPhone slots) uses yaw −5°, the banner's side default.
  - In a Node model of the projection at 140°, both the top and the bottom edge now bow toward the spine: top V about
    190 px, bottom about 30 px on the 2007 px page. The outer edges stand about 9% taller than the spine. Before, the
    bottom edge was flat and the outer edges were 6% taller.
- **The halo cut at the edge** is not mine to fix. It needs Scene's clear zone (#4): no halo within the edge margin.
  The crowd at seed 7, wave 6 put the bee on the right edge. Eyeball P01, D01 and the search art.

### P02 and D02: mid-gulp, crowd visible
Today's `bigFeast` freeze holds 0.45 s. By then all five gulps are done: the delays are 0.03 s + 0.07 s × k, and each
gulp takes 0.09 s, so the last ends by about 0.40 s.
- The new args use existing keys only: `pilot=expert;progress=late;freezeOn=snap;freezeAfter=10.5`.
- The seeded run is the same on all three devices in store3. It bites 3 bugs at ~5.7 s, 4 at ~8.6–9.0 s and 5 at
  ~12.3–12.5 s. Times come from counting the 10 Hz closure lines.
- So the `snap` freeze lands 0.12 s after the 5-bug bite. Two bugs are gulped or going in, and three are still held
  over the shut jaws.
- The expect `SNAP-T event snapped caught=[5-9] escaped` FLAGS the frame if R7's Core or Scene changes move that bite.
- **Ask to App: a `feastGulp` freeze tag.** It would fire on a 5+ FEAST and hold about 0.15 s, mid-gulp. A generic
  `freezeHold=<s>` override would also work. Either removes the timing bet. Once it exists, swap in
  `freezeOn=feastGulp` and drop `freezeAfter`.

### P08 and D08: a calm Zen moment
The new args are `mode=zen;pilot=casual;progress=late;freezeOn=crowd;freezeAfter=25`. It is a state freeze, a crowd
sipping, so no "Stung!" or "Bzzt!" is fresh on screen. If a bee is in the crowd, re-seed or wait for a later crowd.
The "Zen Bog" HUD badge is App's (#10).

### Hinge-closure frame (ROUND-7 #6 extra): not possible without duo.sh changes
The store pass can only hold an angle (`ciHinge`), and a held hinge never snaps. Changes I'd want in `duo.sh` later:
1. A store-pass key `ciSnap=<deg>` that runs `snap_once "$SF" <deg>` after the bugs sip, then `shoot_now`. This is
   the frames pass's duo-03 recipe. A reserve `DR15-bite|screen=play;mode=attract;seed=7;ciSnap=130|…` could then be
   promoted to a Duo slot.
2. A per-line `ciShootDelay=<s>`, instead of the global `CI_SHOOT_DELAY`.

## #9: truth and consistency
- **P04 and D04 sub-line:** "From Red Dragon to B52, and one of gold." (SCORE-R6's line). "Real cultivars" is gone.
- **One progress state, `late`, across the store set.** This covers P02, P04, P06, P07, P08 and P09, and their D
  twins. The set reads as one player: Garden 6 of 8 on both P04 and P06, Bug Book 16/16, best 14,800. A casual run
  then never shows "New best!" over "tired" on P09.
  - I chose `late` over `mid` because `mid`'s Garden is 2/8, six silhouettes, under "Grow 8 flytraps".
  - The screenshots.md rule "never seed a full Bug Book" is relaxed, since rank 10 is a real state.
  - **Ask to App (optional):** a middle preset, for example `progress=story` (rank 7, 13 species, Garden 5/8). The
    Bug Book could then still show what's left to find.
- **P09 and D09:** the expect `SNAP-T results goals [1-3] growth=` FLAGS a Results with no goal ticked.
- **P10 and D10** use the same step and caption. The double "now" is App copy: `LessonScript.line(.triple)` says
  "…now tap!" or "…now!" over a "Now!" pill. **Ask to App:** make the card say "Wait for a crowd…" and let the pill
  carry the cue. Then the two frames match word for word, apart from the control.
- **D06** shows Home's pose card, `HomeView.foldCaption = "Snap it shut a little"` (AppTests.swift:545 pins it).
  **Ask to App:** change it to "Snap it a little shut". It's an App string; the caption files are already right.
- **Leaderboard "Best Feast" → "Best Score"** (#8). The display name lives in my files, so I renamed it in
  `tools/appstore/build-metadata.js`, regenerated `asc-metadata.json`, and updated `achievements.md`, `metadata.md`,
  `review-notes.md`, `press-kit.md`, `LAUNCH-RUNBOOK.md` and the site.
  - The reference name is now "Best score".
  - The `snap.best` id is unchanged.
  - The old "Best Feast" wording is still in comments in `GameCenterManager.swift` (App's file).
- **`build-metadata.js` now fails** in three cases:
  - two progress states in a store set;
  - "real cultivars" in a caption;
  - a P sub-line not quoted in screenshots.md, or a D frame not named there.

  "best feast" is also on its stale-claims list.
- **docs:** `screenshots.md` is updated to match the scenario files: the rows, the notes, the asks, section B and the
  checklist. The builder runs clean ("OK").

## #16: scenario hygiene (`ci/scenarios.txt`)
- **05** was a duplicate of 06. On touch, step 3 is merged into step 2, so the old frame always showed step 4.
  - The new args are `lessonStep=3;fold=1;closure=24`.
  - `fold=1` gives the Duo lesson. `closure=24` uses the fixed source, which is unarmed at ≥ 4°, so the step waits on
    "Open up to reset the trap." for good.
- **14** caption: a 4-bug Feast, with the R7 "4 bugs · +N" pop. The expect is `feast count=[34] snapsBack`.
- **17** is now a settled night: wave 26, a crowd 6 s in. Before, it froze on the dusk-to-night change.
- **23** and **30** say "Score on the left", the Settings string.
- **26** says "score", not "protein".
- **De-duplication:**
  - **40** uses seed 11, so it is no longer 15's moment.
  - **50** uses the expert pilot, with expect `results goals 3 growth=`. This is the goals-3/3-bonus frame, though not
    guaranteed: if it logs fewer than 3 goals, try `pilot=perfect` or another seed.
  - **52** uses `progress=late`.
- **New frame 56, the Garden pick:** `screen=garden;progress=late;variety=redDragon`. The `variety=` key sets
  `controller.trapVariety`, so Red Dragon wears the gold check.

## #18: the icon (`Snap/UI/AppIconArt.swift`)
- The fly's two hands, the "lip studs" at about (480,710) and (595,690), are removed: `hands()`, `handOffsets`,
  `handLight` and `lipPoint` are gone, and so is the call in `paint`. Everything else is unchanged.
- No test or other file references them; `TrapArtPose` doesn't draw hands.
- I re-read the edit twice. No local shadows a static, and every remaining helper is still used.
- **Check on the next ci.yml icon render:** look at AppIcon-60 and AppIcon-40.

## Risks
In order: the P02/D02 freeze timing; 05's fixed-closure behaviour in the lesson; 50 reaching 3 of 3; the D01 hinge
sweep under a pilot; the edge halo, which depends on Scene. Every one is either gated by an expect (FLAGGED, never
uploaded) or flagged here for a human look.
