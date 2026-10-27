# CI engineer, Round 1 hand-off (27 Oct)

**Files:**
- `project.yml`;
- `.github/workflows/ci.yml`, `duo.yml`, `testflight.yml`, `tf-status.yml`;
- `ci/screenshots.sh`, `ci/scenarios.txt`, `ci/duo.sh`, `ci/duo-scenarios.txt`, `ci/flatten-png.swift`, `ci/README.md`.

The temporary `probe.yml` is deleted. Everything is described in `ci/README.md`. Nothing has run yet: the repo is
private, and Actions are blocked by billing until the founder makes it public. I checked the work by reading it:
- `bash -n` on both scripts and on every `run:` block of the workflows (extracted with a Node script);
- one grep for sister-project names;
- one grep for consistent names (`Snap.xcodeproj`, scheme `Snap`, `Snap.app`, `com.pravegm.snapjaw`, `-snapDemo`,
  `SNAP-`).

## What I built
- **project.yml**:
  - The book-pose sister's spec renamed: target `Snap` (sources `Snap/`), tests `SnapTests`, bundle id `com.pravegm.snapjaw`,
    `CFBundleDisplayName: Snapjaw`.
  - Its 4-orientation list and its full-screen keys (`UIRequiresFullScreen`, status bar hidden, Dark,
    `CADisableMinimumFrameDurationOnPhone`, `ITSAppUsesNonExemptEncryption: false`, `GKGameCenterBadgingDisabled`).
  - The Game Center entitlement in `Snap/Snap.entitlements` (generated, gitignored).
- **ci.yml**: these steps, in order:
  - copy check (warning only);
  - build and test (the only gate);
  - errors.txt;
  - a `SNAP-BAL` table;
  - the demo-guard positive control;
  - 32 phone screenshots;
  - the app icon (`screen=icon` → `SNAP-ICON <path>` → `app-icon-1024.png`);
  - `logs` and `screenshots` artifacts.
- **duo.yml / duo.sh**:
  - The ROUND-1 checks (SNAP, CREEP, REARM, CLOSE-PAUSE) as PASS/FAIL/INCONCLUSIVE rows, in the job summary.
  - Book-pose frames (open 165, half 150, snapped 130, cover shut, reopened 165, pose card), UI frames and a 16-frame
    Duo store set.
  - The structure is the tabletop sister's (result rows, checks.tsv, summary), without its orientation request,
    because book pose is the sim's own pose.
- **testflight.yml / tf-status.yml**: the sister path, unchanged in substance:
  - ad-hoc archive, or unsigned plus ad-hoc-stamped entitlements;
  - the cloud-managed distribution certificate;
  - a build-number check, the Game Center entitlement check, and the demo-code guard in both jobs.
  - One addition: the icon step stops with a clear error when the appiconset has no PNG.

## What the first runs should check
1. **CI, first push** (after the engineers land their code):
   - The build and tests pass. If not, start from `errors.txt`.
   - Watch for XcodeGen errors if `SnapTests/` is missing; the path is required.
2. **The Balance table** appears. If it is empty, BalanceTests doesn't print `SNAP-BAL` or doesn't read
   `SNAP_BAL_SEEDS`.
3. **The demo-guard control** says the literal is present. If it says it is missing, testflight's guard is blind.
4. **The screenshots table** in the summary:
   - every scenario `ok`, landscape (2622×1206 on the iPhone 18 Pro);
   - few `no-freeze` rows. `lastSnap`, `tired` and `results` use a novice pilot with waits of 150–200 s; `bee` and
     `sting` start at wave 15. Tune `wave=`/waits if they miss;
   - few `expect-miss` rows (each one names a missing log line).
5. **`app-icon-1024.png`**: present, 1024×1024, `hasAlpha=no`.
6. **Duo** (manual):
   - The runtime install takes ~10–25 min.
   - The `CANVAS` row should read ~951x669 with `fold=1` and `input hinge`.
   - SNAP PASS with a `d=` near 0.1–0.2 s, then REARM, CREEP and CLOSE-PAUSE.
   - Look at `duo-03-snapped-130` (the slam) and `duo-04-cover-shut` (the cover card).
7. **TestFlight**: run `check_only` first (no secrets). Then the 4 secrets, the app record and the committed icon,
   then a real upload. Then `tf-status`.

## Asks for other roles (none blocks the CI files)
1. **App: `Snap/Assets.xcassets` doesn't exist yet.** It needs `AppIcon.appiconset` (a Contents.json with a 1024
   slot, then the committed render), `AccentColor` and `LaunchBackground`.
   - project.yml names `AppIcon`, `AccentColor` and `LaunchBackground` (like the sister apps). Without a catalog the build
     still works, but testflight stops at the icon step.
   - A catalog with an empty AppIcon set only warns.
2. **App: `PrivacyInfo.xcprivacy`** ("no data collected"; copy the book-pose sister's, under C:\Users\59527\Wing). testflight lints it when present.
3. **App: `mode=attract` without `pilot=` must take the real hinge on the Duo**, as ROUND-1 says. ARCHITECTURE's frame
   loop says "TrapPilot in attract/CI", which could be read the other way. Every hinge check launches exactly
   `screen=play;mode=attract;seed=7`, and the `input` field of the SNAP row will show which source is live.
4. **App/Feel: the log lines CI parses:**
   - `SNAP-T trap closure <c> armed <0|1> creep <0|1> angle <θ|-> ref <θ|->` (read by key, so the order doesn't
     matter, but the words must be exactly these);
   - `SNAP-T event <caseName>` (bugSipping, snapped, rearmed, bugSpooked, stung, feast, dayPhaseChanged, lastSnap,
     tired);
   - `SNAP-T paused closing` and `SNAP-T resumed`;
   - `SNAP-T freeze <tag>` (also for a `freezeAfter=` freeze: any tag);
   - `SNAP-T canvas <w>x<h> fold=<0|1> hudLeft=<0|1>`;
   - `SNAP-T input hinge|touch|pilot`;
   - `SNAP-T frame 120`;
   - `SNAP-ICON <absolute path>`.
   - **Print `SNAP-T paused closing` as one literal under `#if DEBUG`.** That is the Release demo guard's long
     string; Swift inlines strings of 15 bytes or fewer, so `freezeAfter` alone may be invisible to `strings`.
5. **Core: BalanceTests should read `SNAP_BAL_SEEDS`** (CI sets 8) and print `SNAP-BAL` lines.

## Known risks
- **CREEP is marginal by the rule's own maths.** The reference is the max θ over 0.6 s, so a 10.7°/s close holds the
  closure at about 0.6 × 10.7 ≈ 6.4°, just over the 6° creep depth (before filter lag).
  - If CREEP fails on "creep-1 lines=0" with a max closure of ~5–6°, the check is too gentle, not the app wrong.
  - CREEP-FAST (the same close over 1.5 s, ~13° of closure) is logged next to it to tell which.
  - The "no snap before 22°" leg uses the trap lines around the snapped line, with a 2° tolerance (they are 10 Hz).
- **SNAP's "within 1 s"** is measured from the line count before the sweep to 1 s after the `hinge sweep` call
  returns. The tool's start-up lag only makes the window longer. The snapped line's own `d=` is in the detail.
- **Half-closed frame:** a hinge held at 150° shows open jaws once the reference relaxes (in under a second), and a
  shot takes ~15 s. So `duo-02` uses `closure=11` over a real 150° hinge.
- **The pose card on the Duo is `screen=pose`** in book pose. A real portrait (tabletop) frame would need the app to
  ask for portrait itself; there is no CLI rotate, and screenConfig is banned.
- **Timings are unmeasured**: the Duo run takes ~45–75 min, the CI screenshot pass ~25–35 min (freeze waits included).
