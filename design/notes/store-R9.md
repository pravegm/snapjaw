# Store R9: the App Store listing for the R8 game (28 Oct 2026, store lead)

## The lead's run checklist (do these in order)

**0. Before any run**
- [ ] **CI is green on the R8 code** (`ci.yml` on main, R8b `69f028b` or later). store.yml builds the same app.
- [ ] **The website is updated** (not my files, see ask S1): `docs/site/index.html` and `docs/site/support.html` still
      describe the R7 snap. They are the **Marketing and Support URLs** App Review opens. The privacy page is still true.
- [ ] Commit and push my files (list at the end). The push runs `asc.yml`'s tool job (validate only, no Apple contact).
- [ ] **Run store.yml alone** (CLAUDE.md: a Duo simulator next to another macOS job dies). No other macOS run in progress.

**1. App Store screenshots (`store.yml`) → Run workflow on `main`**

| input | value |
|---|---|
| phones | ✓ (default) |
| duo | ✓ (default: needed for frame 1 of every set and the header/search art) |
| duo_from_run | empty |
| device_69 / device_63 | defaults (`iPhone 18 Pro Max\|auto:Pro Max`, `iPhone 18 Pro\|screen:1206x2622,1179x2556`) |
| phone_filter / duo_filter | defaults `^P[0-9]` / `^D[0-9]` |
| book_angle | `auto` |
| placements_from | **empty** (the same run draws the header and search art from its own Duo captures) |
| banner_args | empty |

Then check the run:
- [ ] Artifacts `store-69`, `store-63`, `store-duo` each have a MANIFEST ending **`summary: ok 10  flagged 0  missing 0`**
      (the asc tool refuses any set that doesn't). `store-placements` MANIFEST: **`problems 0`**.
- [ ] Eyeball every frame (screenshots.md "Truthfulness rules"). The new-in-R9 ones to look at hardest:
      **D02-chomp** (the CHOMP card forced onto the inner panel: is it laid out well across the fold? it is the first
      time this is captured on the Duo inner display), **P02/D03-feast** (the `bigFeast` freeze: "FEAST!" over open
      lobes, never shut lobes on the Duo), **P05/D06-night**, **P08/D09-zen** (calm; a crowd sipping), **P10-results**
      (goals ticked), **P04/D05-levels**, **P09/D10-goals**.
- [ ] If a frame is FLAGGED or looks wrong: swap in a reserve from the scenario file (same caption rules), or re-run
      only the failing side (phones only, or `duo_from_run=<this run>` to re-caption without a new Duo pass). A
      Duo-only re-shoot: `phones` off, `duo_filter` `^D0[2]` etc. Tell me and I re-point a scenario.
- [ ] Note the run ID: **STORE_RUN**.

**2. TestFlight build** (if the R8b build isn't uploaded yet): `testflight.yml` → Run workflow (never "Re-run"). Note
the build number **BUILD** once it shows "Ready to Submit" in App Store Connect → TestFlight. The founder's §5 Duo test
(`docs/LAUNCH-RUNBOOK.md`, rewritten for R8) should pass on this build before Submit.

**3. App Store Connect tool (`asc.yml`) → Run workflow, first `plan`, then `push`**

| input | plan run | push run |
|---|---|---|
| asc (Contact App Store Connect) | ✓ | ✓ |
| mode | `plan` | `push` |
| only | empty (every step) | empty |
| store_run | **STORE_RUN** | **STORE_RUN** |
| ci_run | empty (latest green CI: its `screenshots/badges/` = the 12 Game Center images) | empty |
| placements_run | **STORE_RUN** (its `store-placements` artifact: header 3840 × 1646 + search 3840 × 2560) | **STORE_RUN** |
| inherit_from | `com.pravegm.squish` (default: the App Review contact) | same |
| build | **BUILD** (or empty in plan) | **BUILD** |

- [ ] Read the plan's summary: every step's diff, and the **"manual"** list it prints at the end.
- [ ] After a green push: optionally set `DEFAULT_STORE_RUN: "<STORE_RUN>"` in `asc.yml` (your edit; I left it empty).
- [ ] A `check` run afterwards reads the whole 1.0 page back.

**4. Only the founder can do these (App Store Connect, in a browser)** — the tool prints most of them as "manual":
1. **App Privacy** → Get Started → "No, we do not collect data from this app" → Save → **Publish** (Data Not Collected;
   `docs/appstore/privacy.md`). The API cannot publish the privacy label.
2. **Family Sharing** → Turn On.
3. **Pricing and Availability**: untick "iPhone and iPad Apps on Apple Silicon Macs" and "Apple Vision Pro" (no API).
   Check £1.99 (base UK) and every country except China mainland and Vietnam (the tool sets these; if it prints an
   availability "manual" line, do it by hand).
4. **Digital Services Act** trader answer (App Information → App Store Regulations and Permits), as for the other games.
5. **Age Rating**: the tool pushes every answer (4+); if its plan says a field was refused, answer by hand from
   `metadata.md` §8 and check the result says **4+**.
6. **Game Center** must be on (Services → Game Center) before the tool's gamecenter step; it rides with the 1.0
   submission (the attach step).
7. If the plan says the API offers **no iPhone Duo screenshot group**: upload `store-duo` D01–D10 by hand
   (2853 × 2007) in the iPhone Duo slot.
8. If the plan says the nomination stayed a draft: Featuring → Nominations → **Submit**.
9. **Optional:** add an App Review attachment video (20–30 s on a real Duo: open, bugs land, close → CHOMP card on the
   outer display, open, a bee waited out). Recommended for a hinge game.
10. **Submit:** the 1.0 page → pick **BUILD** → **Add for Review** → **Submit to App Review**. Release stays
    **manual** (approved = "Pending Developer Release" until 8 Dec, `metadata.md` §12). If the founder wants release on
    approval instead, tell me: `build-metadata.js` `RELEASE` changes to `AFTER_APPROVAL`, and it must not land in
    Brim's (17–23 Nov) or Hush's (1–7 Dec) week.
11. Launch day only: the Accessibility Nutrition Labels (`accessibility.md`; they can only be published once live).

## Validation (run locally, 28 Oct)
- `node tools/appstore/build-metadata.js` → **OK** (name 7, subtitle 29, promo 163/170, description 3,833/4,000 both
  locales, keywords 97/100 bytes, review notes 3,953/4,000 bytes ASCII, nomination 52 / 937 / 453, 12 achievements,
  575 points; every screenshot headline count matches; categories GAMES / CASUAL / ARCADE (fallback ACTION) /
  ENTERTAINMENT). It regenerated `docs/appstore/asc-metadata.json`.
- Every caption (P, D and all reserves) passes `ci/store-set.sh`'s `lint_caption` (run in Git Bash) and has none of
  store-frame's REJECTED words. `bash -n ci/store-placements.sh` clean.
- Apple's specs re-read 28 Oct: iPhone "Dynamic Island (medium)" 2622 × 1206 is the one **required** iPhone size;
  6.9" 2868 × 1320 optional; **iPhone Duo inner 2853 × 2007 and outer 2034 × 1398 / 1398 × 2034** (optional now,
  required from April 2027 for iOS 27.1 SDK apps; they earn the "optimized for iPhone Duo" badge); product page header
  3840 × 1646, search art 3:2 up to 3840 × 2560 (creative assets, iOS 27). The tool's size tables already match.

## What changed (R9)
- **Storyboard** (`ci/store-scenarios.txt`, `ci/duo-store-scenarios.txt`, `docs/appstore/screenshots.md`):
  - iPhone: P01-book-hero, P02-feast, P03-bee, P04-levels, P05-night, P06-garden, P07-bug-book, P08-zen, P09-goals,
    P10-results.
  - Duo: D01-book-hero, **D02-chomp** (the outer display's CHOMP card), D03-feast, D04-bee, D05-levels, D06-night,
    D07-garden, D08-bug-book, D09-zen, D10-goals.
  - First three sell it: the Duo is the trap → close it: CHOMP → wait for a crowd: FEAST (iPhone: hero → FEAST → bee;
    the iPhone set never shows a Duo-only screen).
  - Retired: P10/D10 "first-bite" (the lesson is gone), P09/D09 Results on the Duo, R7's `freezeOn=snap;freezeAfter=10.5`
    gulp (timing-based, and a shut-lobes frame on the Duo is untrue in R8). New play args are all ones that froze in
    the R8 CI run (`artifacts/r8`): `bigFeast` (48), bee wave 15 (12), night wave 24 `landed` (35; wave 26 `crowd` did
    not freeze), levels `late` (60), Home `late` (52), Results expert (50), CHOMP card (09).
  - One progress state (`late`) on every progress frame.
- `tools/appstore/build-metadata.js`: per-set frame lists (PFRAMES / DFRAMES), the progress check by beat name, a
  caption check for R7 claims, no outer-display card in the iPhone set, and the stale-claim regex extended (a little
  shut, 22°, like a book, First Bite lesson, 10 snaps, Bend it, closing pause, lid, Feed).
- `ci/store-placements.sh`: the hero fallback and review variants re-pointed to D03-feast / D04-bee;
  `store.yml`: the banner_args example only.
- Metadata (`metadata.md` → `asc-metadata.json`): name and subtitle unchanged (the subtitle is the app's tagline,
  drawn on the header art); new promo text, description (the phone is the trap; 30 Levels; Endless; 12 snaps), What's
  New line, claims table re-ticked against the R8 source. Review notes, nomination, privacy (grep run: nothing
  collected), accessibility tasks, achievements (ids re-checked: exact; Levels earn what Zen earns), press kit, social
  copy and the runbook's §5 Duo test rewritten for R8.

## Asks (not my files)
- **S1 (site owner / lead, BLOCKS submission):** update `docs/site/index.html` (meta description, the lead paragraph
  l.64, "how it plays" l.156, modes l.218–221, the hinge paragraph l.227, one-liner l.237, platform/modes table
  l.241–244) and `docs/site/support.html` (l.44, l.59, l.69 "10 snaps" → 12, l.74 the hinge answer, remove the
  "Bend it a little" (l.83) and "hold it open like a book" (l.93) entries, l.109/119/146/176 "Feed" → "Endless",
  l.128–129 "Replay First Bite" → "Levels 1–5 teach; replay any level from the Levels map"). Use `metadata.md` §4's
  wording; add a "Nothing bites when I close it part way" entry ("only a full close bites"), and a "Close the phone to
  start" entry. I can do it if you give me those two files.
- **A1 (App / Core):** in R8 CI, `screen=levelResults;level=1;pilot=perfect` logged `SNAP-T level result 1 stars=0
  passed=0` (level 4 too). `design/notes/app-R9.md` (written in parallel) says this was the demo runner making a fresh
  pilot every 0.5 s, now fixed. **Please confirm in the next CI run** (ci/scenarios.txt 08: `level result 1 stars=3`),
  and that Level 1 is passable by a tap on a phone (App Review plays it first). Once confirmed, a "three stars" Results
  frame can replace P10 (`screen=levelResults;level=1;pilot=perfect;progress=late`, expect `level result 1 stars=3`);
  I kept the proven Endless Results for tonight.
- **A3 (App, R9 in flight):** app-R9 changes Home (no filler lines under the pads; goals and rank only once there is
  progress: `late` has it), Level goal texts (input-aware) and the CHOMP card's tips. None changes a caption, but the
  store run must be made **after** those changes land, so the frames show the build that ships.
- **A2 (founder's call, no app work):** the CHOMP card on the **real outer display** can already be captured
  (DR12, `ciHinge=0`, 1398 × 2034, Apple's Duo outer size). If the founder wants an outer-display
  frame on the product page, the tool supports a `duoOuter` set, but it shares the iPhone Duo placement group with the
  inner set (10 frames in all): a founder's call, not for tonight.
- No new demo key or freeze tag is needed: every scenario uses keys in `Snap/App/DemoMode.swift`.

## Files I changed
`ci/store-scenarios.txt`, `ci/duo-store-scenarios.txt`, `ci/store-placements.sh`, `.github/workflows/store.yml`
(one description string), `tools/appstore/build-metadata.js`, `docs/appstore/{metadata.md, asc-metadata.json,
screenshots.md, review-notes.md, privacy.md, accessibility.md, achievements.md, featuring-nomination.md, press-kit.md,
social-launch.md}`, `docs/LAUNCH-RUNBOOK.md`, `design/notes/store-R9.md`.
