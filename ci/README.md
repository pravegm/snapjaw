# CI for Snapjaw

There is no Mac on our side. GitHub Actions on the `xcode-27` runner (Apple silicon, Xcode 27.1) is the only compiler.
Everything here is adapted from the sister projects' CI, which has run hundreds of times on these runners and on a real
Duo (`C:\Users\59527\Wing` and `C:\Users\59527\Lid`, read-only). Their hard-won fixes are kept, with the run numbers
in the comments.

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

## ci/flatten-png.swift
`xcrun swift ci/flatten-png.swift <png…>` rewrites each PNG as opaque RGB over white. testflight.yml runs it on the
app icon in the workspace (never committed).
