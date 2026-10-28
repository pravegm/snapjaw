# CI for Snapjaw

There is no Mac on our side. GitHub Actions on the `xcode-27` runner (Apple silicon, Xcode 27.1) is the only compiler.
Everything here is adapted from the sister projects' CI, which has run hundreds of times on these runners and on a real
Duo (the book-pose and tabletop sisters; their folders are listed in `CLAUDE.md`, read-only). Their hard-won fixes are
kept, with the run numbers in the comments. The store pipeline (`store.yml`, `asc.yml`, `ci/store-*`,
`tools/appstore/`) is the book-pose sister's, which took that game through App Store Connect on the same Apple account.

**Before anything runs:** the repo `pravegm/snapjaw` must be **public**. This account's billing blocks Actions on
private repos.

Identity used throughout: project `Snap.xcodeproj` (from `project.yml`), scheme and target `Snap`, tests `SnapTests`,
app `Snap.app`, bundle id `com.pravegm.snapjaw`, display name `Snapjaw`, demo argument `-snapDemo`, log prefix `SNAP-`.

## The workflows

| Workflow | Runs on | What it does | Artifacts |
|---|---|---|---|
| `ci.yml` (CI) | every push to `main` touching `Snap/`, `SnapTests/`, `project.yml`, `ci/` or itself; or by hand | Build, unit tests, phone screenshots, app icon | `logs`, `screenshots` |
| `duo.yml` (Duo) | by hand only (~45–75 min) | The app on an iPhone Duo simulator with a real hinge: the hinge checks and book-pose frames | `duo-screens` |
| `testflight.yml` (TestFlight) | by hand | A signed Release uploaded to App Store Connect (or `check_only`: an unsigned Release archive) | `testflight-logs` / `release-check-log` |
| `tf-status.yml` | by hand | Read-only: the latest builds' processing state in App Store Connect | (job summary) |
| `store.yml` (App Store screenshots) | by hand only (~2–3 h of runners: phones, Duo, then assembly) | The 10-frame App Store sets for 6.9", 6.3" and the iPhone Duo, captioned; plus the header and search art | `store-69`, `store-63`, `store-duo`, `store-placements`, `raw-*` |
| `asc.yml` (App Store Connect tool) | every push touching `tools/appstore/`, `docs/appstore/asc-metadata.json` or itself (offline checks); by hand with `asc` ticked (contacts Apple) | Typecheck and validate the listing; `check` / `plan` / `push` it into App Store Connect | `badges`, `asc-output` |

Run one by hand: the repo's **Actions** tab → the workflow → **Run workflow**, or
`gh workflow run ci.yml -R pravegm/snapjaw` (add `-f filter=play` etc. for inputs).

## ci.yml

1. **Copy check** (warning only): "smash" or "Fold to" in the store text or a Swift string line (CLAUDE.md bar 3).
2. Xcode 27.1, `brew install xcodegen && xcodegen generate`.
3. **Build and test**: `xcodebuild test -project Snap.xcodeproj -scheme Snap` on the iPhone 18 Pro simulator, unsigned.
   `TEST_RUNNER_SNAP_BAL_SEEDS=8` reaches the test process as `SNAP_BAL_SEEDS`. **This is the gate**: the job fails
   only when the build or a test fails. On failure, `errors.txt` lists the errors.
4. **Balance table**: the `SNAP-BAL` lines from BalanceTests in the job summary.
5. **Demo-guard positive control**: checks that the Debug binary contains the literal `SNAP-T paused closing`. That
   literal is what testflight.yml looks for to prove that no demo code shipped, so it has to be visible here.
6. **Screenshots**: `bash ci/screenshots.sh` (below).
7. **App icon**: it launches `-snapDemo "screen=icon"` and reads the `SNAP-ICON <path>` line. If there is none, it
   falls back to `Documents/AppIcon-1024.png`, then to any `*icon*.png` in Documents. The file is copied to
   `ci-screens/app-icon-1024.png`, with a warning if it isn't 1024×1024 or has alpha. Commit it as
   `Snap/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. CI never commits.

Inputs (by hand): `filter`, a regex on scenario names (e.g. `play`, `^1[0-9]-`), and `device`, the capture simulator
(e.g. `screen:750x1334` for the smallest iPhone).

**Artifacts:**
- `logs`: build.log, errors.txt.
- `screenshots`: `<scenario>.png`, `logs/<scenario>.txt` and `.at-capture.txt` (the app's stdout), `captures.tsv`,
  `device.txt`, `app-icon-1024.png`.

### ci/screenshots.sh + ci/scenarios.txt
Each line of `ci/scenarios.txt` is `name|demo args|wait|caption|expect`.
- **demo args** are passed as `-snapDemo "<args>"`. The keys are in `design/ROUND-1.md` "Demo mode".
- **wait** is the number of seconds before the shot. A `freezeOn=<tag>` scenario instead waits for the app's
  `SNAP-T freeze <tag>` line, up to max(wait, 60) s, then 2 s more. A `freezeAfter=` scenario waits for any
  `SNAP-T freeze` line. A missed freeze is still captured, and flagged `no-freeze`.
- **caption** says what the frame should show, for the reviewer.
- **expect** is a regex the app log must contain at capture time. It is reported, never fatal.
- Never put a `|` inside a field: it splits the line into a bogus extra column (the script warns).

The phone sim has no hinge, so a `pilot=` drives the trap, or `closure=` holds the jaws. The app turns landscape by
itself. A shot that comes out portrait or under 80 KB (still launching) is re-taken up to 3 times. Every simulator
call has a timeout, and a failed launch or shot is retried once and then skipped. The script always exits 0.

The 32 scenarios cover:
- Home: fresh, mid, and the Duo layout (`fold=1`).
- The First Bite lesson, steps 2–7 (phone texts; step 1, the pose step, is skipped on a phone).
- Play with pilots, frozen on `landed`, `crowd`, `bee`, `snap`, `feast`, `sting`, `dusk`, `night`, `lastSnap`,
  `tired` and `results`.
- Layout variants: the wide phone (`fold=0`), the Duo layout (`fold=1`), `hudLeft=1`, and the jaws held half shut.
- Daily Bog, Results (mid and fresh), the Bug Book (mid and late), Settings, the pose card and the cover card.

## duo.yml + ci/duo.sh + ci/duo-scenarios.txt (manual)

The job does this:
1. Installs the iOS 27.1 runtime (~7.85 GB, 3 tries). The runner image only has 27.0, which has no Duo.
2. Creates and boots an "iPhone Duo".
3. Installs the `hinge` CLI (`brew install artemnovichkov/tap/hinge`, 3 tries; the job stops without it).
4. Builds for the Duo.
5. Warms up the hinge helper.
6. Runs `bash ci/duo.sh`.

The Duo sim boots in book pose (landscape, the fold vertical), which is exactly how Snapjaw is played, so the app
never has to ask for an orientation.

**Inputs:**
- `passes`: `hinge frames ui store` (any subset).
- `store_filter`: a regex.
- `strict`: if true, a FAIL fails the job. The default only reports.

**Hinge checks** (design/ROUND-1.md). Each one prints `<CHECK> PASS|FAIL|INCONCLUSIVE (detail)` to `logs/run.txt`,
adds a row to `checks.tsv` and appears in the job-summary table.

| Check | How | PASS |
|---|---|---|
| SNAP | `screen=play;mode=attract;seed=7` at 160°. Wait for `event bugSipping`, then sweep 160→128 in 0.15 s | `event snapped` within 1 s. If the app never saw the angle drop, it retries once, then reports INCONCLUSIVE |
| REARM | After the snap, sweep back to 160 | `event rearmed` after the snapped line |
| CREEP | From 160, sweep 160→128 over 3 s | A `SNAP-T trap … creep 1` line, and no `snapped` before the closure reached 22° |
| CLOSE-PAUSE | Fresh launch at 150. Sweep to 40, then back to 150 (on to 165 if the cover is still lit) | `paused closing`, then `resumed` |

INFO rows give evidence without a verdict:
- CANVAS: the canvas size, `fold=` and `hudLeft=`, and the input source.
- CREEP-FAST: the same close over 1.5 s.
- NO-PAUSE-95: holding 95° must never pause.
- FRAME-SNAP, COVER, POSE-CARD.

**Frames:**
- `duo-01-open-165`.
- `duo-02-half-150`: the jaws held at 11° with `closure=11`, because the drawn closure follows the player's own rest
  angle and relaxes within a second of a still hold.
- `duo-03-snapped-130`: frozen on the bite with `freezeOn=snap`.
- `duo-04-cover-shut`, `duo-05-reopened-165`, `duo-06-pose-card`.
- `duo-h*`: the frames from the hinge checks.
- `duo-ui-*`: Home, lesson steps 1 and 2, Results, the Bug Book, Settings, too flat (178°) and the cover.
- `store-*`: one frame per line of `ci/duo-scenarios.txt`, at 150° with a pilot.

**Artifact `duo-screens`:** the PNGs (the lit panel), `raw/` (both panels), `logs/run.txt`, `logs/<launch>.txt`,
`checks.tsv` and `build.log`.

These lessons are kept from the sister projects:
- The display names are probed. Both panels are shot every time, and the lit one is kept.
- `simctl io … screenConfig` is never used (it crash-loops SpringBoard).
- `hinge set` retries 3 times, and moves are 60 Hz `sweep`s.
- Silent 1° wiggles come before every fast snap, so the tool doesn't deliver it as one or two samples.
- No shot is taken inside a timed window.
- Every call has a timeout.

## testflight.yml

- **`check_only: true`** needs no secrets. It makes an unsigned Release archive and checks the Info.plist values, the
  asset catalog, `PrivacyInfo.xcprivacy`, and that the Release binary has no demo code (`^freezeAfter$` or
  `SNAP-T paused closing`). Run this first.
- **Normal run:** it checks that the 4 secrets exist and flattens the app icon (an alpha channel is refused,
  ITMS-90717), then archives in Release **without creating a development certificate**. It tries an ad-hoc
  signature first. If that fails, it archives unsigned and stamps the Game Center entitlement on with a local ad-hoc
  signature. Then it exports with **Apple's cloud-managed distribution certificate**, through the Admin API key
  (`-allowProvisioningUpdates`). It checks the build number and the Game Center entitlement, and uploads. The build
  number is the run number.
  - Why: the sister run 40266619846 hit "maximum number of certificates", and 40268420116 lost the Game Center
    entitlement in an unsigned archive.
- **Before the first upload**, all three must be in place:
  - the bundle id `com.pravegm.snapjaw` registered with Game Center;
  - an App Store Connect app record for it;
  - the 1024 icon committed in `Snap/Assets.xcassets/AppIcon.appiconset/`.

### TestFlight secrets (the founder, once)
The same 4 repository secrets as the sister apps, with the same names and the same Apple key:

| Secret | What it is | Where to find it |
|---|---|---|
| `ASC_KEY_ID` | The App Store Connect API key's ID (10 characters) | App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys: the key's row |
| `ASC_ISSUER_ID` | The issuer ID (a UUID) | The same page, above the key list |
| `ASC_PRIVATE_KEY` | The full text of `AuthKey_<KEY_ID>.p8`, including the `-----BEGIN PRIVATE KEY-----` / `END` lines | The file saved when the key was made (Apple lets you download it only once) |
| `APPLE_TEAM_ID` | The 10-character team ID | developer.apple.com → Account → Membership details |

GitHub never shows a secret's value again, so they can't be copied out of the other repos. Enter the same values
again, either way:
- **Website:** github.com/pravegm/snapjaw → Settings → Secrets and variables → Actions → **New repository secret**,
  once for each of the 4 names above.
- **Terminal:**
  ```
  gh secret set ASC_KEY_ID      -R pravegm/snapjaw --body "<key id>"
  gh secret set ASC_ISSUER_ID   -R pravegm/snapjaw --body "<issuer id>"
  gh secret set APPLE_TEAM_ID   -R pravegm/snapjaw --body "<team id>"
  gh secret set ASC_PRIVATE_KEY -R pravegm/snapjaw < AuthKey_<KEY_ID>.p8
  ```

The key must have the **Admin** role, because cloud-managed signing needs it. If the `.p8` file is lost, make a new
Admin key on the same page and use its 3 values here (the old key keeps working for the other apps). The workflow
writes the key to a temporary file (mode 600), never prints it, and deletes it at the end.

## tf-status.yml
A read-only job, on Ubuntu. It uses the same `ASC_*` secrets to list the 10 latest builds of `com.pravegm.snapjaw`:
version, upload time, processing state, internal testing state and expiry. Use it to answer "I can't see build N in
TestFlight" without opening the website.

## store.yml: the App Store screenshot sets (manual)

The sets and captions are `docs/appstore/screenshots.md`; once the scenario files exist **they are the source of
truth** for captions. Four jobs:

1. **phones**: builds Debug, then `ci/store-capture.sh phone` runs `ci/store-scenarios.txt` (P01–P10) through
   `ci/screenshots.sh` on the iPhone 18 Pro Max (6.9", 2868 × 1320) and the iPhone 18 Pro (6.3", 2622 × 1206).
   Artifacts `raw-69`, `raw-63`.
2. **duo**: the same runtime / simulator / `hinge` setup as `duo.yml` (keep them in step), then
   `ci/store-capture.sh duo` runs `ci/duo-store-scenarios.txt` (D01–D10) through `ci/duo.sh`'s store pass, hinge held
   at 150°. Artifact `raw-duo`. Skipped with `duo_from_run=<run id>` (reuses that run's `raw-duo`).
3. **assemble**: `ci/store-set.sh` + `ci/store-frame.swift` caption each set. **Frame 1 of every set is D01 drawn as
   the book-pose composite** (the Duo open like a book, each half of the real capture warped onto its page: the lobes
   on the pages, the midrib on the hinge). Artifacts `store-duo`, `store-69`, `store-63`: the upload PNGs (named as
   `asc-metadata.json` lists them), `MANIFEST.txt` / `.tsv`, and `_flagged/` (never upload those).
4. **placements**: `ci/store-placements.sh` + `ci/store-banner.swift` draw the product page header (3840 × 1646, the
   app's wordmark and tagline beside the book) and the search results art (3840 × 2560, D01's caption over the book)
   from clean Duo captures only. Artifact `store-placements`. `placements_from=<run id>` re-renders them alone from
   an earlier run (nothing captured, its own concurrency group).

Inputs: `phones`, `duo`, `duo_from_run`, `device_69`, `device_63`, `phone_filter` (`^P[0-9]`), `duo_filter`
(`^D[0-9]`; add `|DR` for the reserves), `book_angle` (`auto` = the capture's real hinge angle from `SNAP-H`, else 140),
`placements_from`, `banner_args` (e.g. `bee=--kind search --from D03-bee` for a review variant).

**Scenario files** (`ci/store-scenarios.txt`, `ci/duo-store-scenarios.txt`): `name|demo args|wait|caption|expect|frame`.
- The play frames reuse the seeds, waves and pilots proven in duo run 40603497021 and `ci/scenarios.txt` (crowd at wave
  6, a 5-bug feast at wave 8, a bee at wave 15, all with the perfect pilot; feed mode, so the snaps row is real).
- `caption` is `headline / sub-line` with one `*gold*` word. `frame` is `flat`, `book` (Duo) or `book:D01-book-hero`
  (the iPhone sets' frame 1).
- `ci/duo-scenarios.txt` stays `duo.yml`'s 16-frame review set; `ci/duo-store-scenarios.txt` is the upload set.

**What makes a frame FLAGGED** (it still gets framed, into `_flagged/`): the app log lacks
`SNAP-T demo '…' starts`, the `SNAP-T freeze <tag>` of its `freezeOn=`, the `SNAP-T start wave <n>` of its `wave=`, the
expect regex, or the set's canvas line (`REQUIRE_LOG`: Duo `SNAP-T canvas 951x669 fold=1 hudLeft=0`; iPhones
`fold=0 hudLeft=0`; book sources `fold=1`); a wrong size; alpha; or a caption over 30 characters / 7 words, without
exactly one highlight, or with "flat", "shut" on its own, quick, fast, free, a price or "#1". **REJECTED** (no frame):
smash, squish, squash, splat, kill, slam, "Fold to", or the competitor's name (`store-frame.swift`). A missing D01
makes every set's frame 1 a flat, FLAGGED fallback. One bad frame never fails the run.

**Look:** bog green #0E2A1B → moss #1F4A2C, a lime glow #9BCB3C behind the picture and a faint crimson ember in the
far corner; SF Pro Rounded Heavy dew-white headlines, the one highlight in bog ink on a nectar-gold #F2B632 swash, the
sub-line in mist green. The light (and the lit bezel page) falls on the HUD's half: the right, unless `hudLeft=1`.

```
gh workflow run store.yml -R pravegm/snapjaw                                  # everything
gh workflow run store.yml -R pravegm/snapjaw -f duo=false -f duo_from_run=<id> # recaption with an earlier Duo pass
gh workflow run store.yml -R pravegm/snapjaw -f placements_from=<id>           # header + search art only
```

## asc.yml + tools/appstore: the App Store Connect tool

Details in `tools/appstore/README.md`. On every push it typechecks `asc.swift` and `badges.swift`, collects the 12
Game Center badges from the latest green CI run (a warning and a gap until the app has `screen=badges`,
`docs/appstore/achievements.md` "Images"), self-tests the validator on `tools/appstore/fixtures/`, and validates
`docs/appstore/asc-metadata.json` (leaderboards `snap.best` / `snap.daily` and the 12 `snap.ach.*` achievements,
checked against `GameCenterManager.Leaderboard` and `Achievements.all` in `Snap/Core/Progression.swift`).

By hand with `asc` ticked it contacts App Store Connect: `mode` = `check` (read-only; its AUDIT reads the whole 1.0
page back), `plan` (dry run) or `push` (writes; never submits, never releases). Screenshots come from the store run in
`DEFAULT_STORE_RUN` (**empty until the first clean `store.yml` run**: put its ID there) or the `store_run` input.

**It stops with a plain error, not a cryptic one,** when the founder's two one-time steps aren't done:
- no `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_PRIVATE_KEY` → *App Store Connect is not set up* (lists the missing
  secrets; `APPLE_TEAM_ID` is reported too, since TestFlight needs it);
- no app record for `com.pravegm.snapjaw` (Apple's API can't create apps) → *No App Store Connect app record*.

Both write the instructions (create the record: Apps → + → New App, bundle ID `com.pravegm.snapjaw`, SKU
`snapjaw-2026`; add the 4 secrets above) into the run summary. Kept from the sister tool as it shipped: requests that
fail with an `NSURLErrorDomain` error are retried (reads 8×, writes 3×; matched by error domain, because Apple's hangs
arrive as an `NSError`), each library image may take up to 20 minutes to process, and the `asc` job's timeout is 180
minutes.

## ci/flatten-png.swift
`xcrun swift ci/flatten-png.swift <png…>` rewrites each PNG as opaque RGB over white. testflight.yml runs it on the
app icon in the workspace (never committed).
