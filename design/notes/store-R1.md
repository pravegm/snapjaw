# Store-pipeline engineer, Round 1 hand-off (28 Oct)

**Files (new):**
- `.github/workflows/store.yml`, `.github/workflows/asc.yml`;
- `ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`, `ci/store-banner.swift`, `ci/store-placements.sh`;
- `ci/store-scenarios.txt` (P01–P10, reserve R2), `ci/duo-store-scenarios.txt` (D01–D10, reserves DR1–DR2);
- `tools/appstore/asc.swift`, `badges.swift`, `README.md`, `fixtures/asc-metadata.sample.json`.

**Edited:** `ci/README.md` (two workflow rows, a `store.yml` section, an `asc.yml` section; the intro no longer names
sister folders) and `docs/LAUNCH-RUNBOOK.md` (only the tool steps: §3 intro and its failure note, §6c, the Reference
intro). Nothing committed.

All of it is the book-pose sister's shipped pipeline, ported with exact-match edits (every edit asserted to apply once),
so the code paths that worked there are byte-identical here except where Snapjaw differs.

## What changed from the sister pipeline
- **Identity:** `Snap.xcodeproj` / scheme `Snap`, `com.pravegm.snapjaw`, the "Snapjaw Duo" sim, `SNAP-T` log lines,
  asset prefix `snapjaw`, compiler caches `snap-store-*`.
- **Canvas checks:** Duo `SNAP-T canvas 951x669 fold=1 hudLeft=0`, iPhones `fold=0 hudLeft=0`, book sources
  `fold=1`. 951x669 is measured (duo run 40603497021); `screenshots.md` says 952 × 670.
- **No mirroring.** The light and the lit bezel page fall on the HUD's half: the right, or the left with `hudLeft=1`.
- **The book angle** comes from the real hinge (`SNAP-H`, else `SNAP-T hinge … angle`), never from the trap line,
  which reads a fixed 160 while a pilot plays. On the Duo store pass it read 146.
- **Log checks:**
  - `freezeOn=` must match the whole tag in either case (`lastSnap`);
  - `freezeAfter=` alone needs any freeze line;
  - `wave=n` needs `SNAP-T start wave n`;
  - the sister's chain, lead and skipTo checks are gone.
- **Glossary:**
  - REJECTED (store-frame/banner): smash, Fold Smasher, "Fold to", squish, squash, splat, kill, slam.
  - FLAGGED (store-set): headline over 30 characters or 7 words, not exactly one `*highlight*`, "flat", "shut" on its
    own ("a little shut" is allowed), quick/fast, free, £/$/€, "#1".
  - I tested all 23 captions and some bad samples in Git Bash. The check_log and book_angle tests ran on the real
    Duo logs.
- **Palette** (`store-frame` and `store-banner`):
  - the sweep runs bog green #0E2A1B → moss #1F4A2C;
  - a lime #9BCB3C glow behind the picture and a faint crimson #D62A4E ember in the far corner;
  - dew #F4FBEF headlines, bog-ink #10261A on a nectar-gold #F2B632 swash, mist-green #B9D7B0 sub-lines;
  - a darker bottom band and a graphite bezel.
- **The header wordmark** is the app's Home title: "Snapjaw" in Rounded Black, a cream → light-lime fill clipped to
  the glyphs, a hard crimson-deep shadow, and the tagline under it.
- **Scenarios:**
  - The names are exactly the ones `asc-metadata.json` lists. The headlines are `screenshots.md`'s.
  - The demo args are the proven ones (crowd wave 6, feast wave 8 with count=5, bee wave 15, all with the perfect
    pilot; feed mode), not that doc's first guesses (attract, seed 11).
  - Dusk and night use waves 17 and 24 with `freezeAfter=3`, for the doc's "freeze delay".
  - D02/P02 expect `feast count=[3-9]`. The sting reserves expect `species=wasp`, because their sub-line names one.
- **asc.swift:**
  - The achievement IDs are resolved from `Achievements.all` / `def("<key>")` in `Snap/Core/Progression.swift`,
    because `GameCenterManager.achievementIDs` is a computed var. This was checked in Node: the 12 IDs match
    `achievements.md` and the metadata.
  - The sister's resolver is kept as the fallback. The leaderboards are still read from `enum Leaderboard`.
  - The comments and manual steps now cite Snapjaw's docs (manual release on 8 Dec, CHN+VNM, runbook §6a).
  - The schema is unchanged, and so are the NSURLErrorDomain retries, the 20-minute image wait and the AUDIT in
    `check`.
- **asc.yml:**
  - The `asc` job timeout stays at 180 minutes.
  - **Missing secrets** fail the run with "App Store Connect is not set up". The run summary lists the missing
    secrets, how to create the app record (com.pravegm.snapjaw, SKU snapjaw-2026) and how to add the 4 secrets.
  - **An app record that isn't there** fails `check` with "No App Store Connect app record" and the same
    instructions.
  - `DEFAULT_STORE_RUN` is empty, and empty counts as a gap.
  - Missing badges give a warning: the IDs are still checked, the upload step only warns, and the badge downloads
    are continue-on-error.

## Checks done (no Mac, so no Swift was compiled)
- `bash -n` on the 3 scripts and on all 41 extracted `run:` blocks (store.yml 22, asc.yml 19): all clean.
- Leftover grep (Swoop/swoop/SWOOP/Wing/bird/gull/storm/Brim/Hush) over every file I wrote. The only hits are
  "ladybirds" in the fixture's copy of the real description (the game's text). The real JSON's comments and
  nomination notes still name the sister apps; that file isn't mine to edit (the fixture scrubs them).
- **Unverified until CI:** `asc.yml`'s tool job typechecks both tools on the first push. `store-frame` and
  `store-banner` first compile in a store run. They fall back to `xcrun swift` and list errors in
  `logs/store-frame-build.log`.
  - The riskiest new Swift is the resolver regexes and `drawMark`'s `.clip` text mode.

## Asks
1. **App:**
   - `screen=badges` (achievements.md "Images");
   - a CI scenario `badges` that writes `snap.ach.<key>.png` to the screenshots artifact's `badges/` and logs
     `SNAP-T badges done 12`.
   - Until then the 12 Game Center images are a gap.
2. **App:** on the Duo, lesson step 2 logged "tap to snap!" (duo run 40603497021), but D10 needs the Duo wording.
3. **Launch lead:** `screenshots.md` should say the canvas is 951 × 669 and point to the scenario files' demo args.
4. **After the first clean store run:** put its ID in `asc.yml`'s `DEFAULT_STORE_RUN`.
