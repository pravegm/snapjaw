# CI R5: a Duo rig that survives a sick simulator, and the frames REVIEW-4 asked for

Files: `ci/duo.sh`, `ci/duo-scenarios.txt`, `ci/duo-store-scenarios.txt`, `ci/scenarios.txt` (line 39 only),
`ci/README.md`, `.github/workflows/duo.yml`. No app code changed. Nothing committed.

## What the two runs show

**R3 run 40626586037** (`artifacts/duo3`): the simulator "died" twice, in `hinge` and `close-pause`. Each time a 0.4 s
wiggle sweep hung until the 20 s timeout, and then `simctl list devices` came back empty. The next launch found the
device booted with no reboot, so it was never really shut down: CoreSimulator was stalled. All four checks came back
INCONCLUSIVE, with 6 hinge timeouts.

**R4 run 40634483657** (`artifacts/duo4`, downloaded earlier): **the hinge pass ran first, on a newly booted Duo, and
every check PASSED with hinge input:**
- SNAP: `snapped caught=2 escaped=4 stingers=1 d=0.264` at 125.9°.
- REARM: rearmed@662.
- CREEP: 63 `creep 1` lines, max closure 22.7°, no snap.
- NO-PAUSE-95: no pause at 94.7°.
- CLOSE-PAUSE: paused@370 at 42.8°, resumed@410 at 120.1°. The first pause line was `paused pose`.

Then the run went wrong:
- At 6 min, **frames-snap** was called dead. `sim-death-1.txt` lists the device as **`(Booted)`**, so this was a false
  positive: a hung hinge call plus a `simctl list` slower than 20 s.
- At 15 min, **ui-too-flat** saw shots fail (`size=?`), a hung sweep and an empty `simctl list`. The reboot printed
  "Device already booted", but `sim_booted` still said no, so the script stopped before `ui-cover`.
- The store pass never ran, so there are **no R4 store frames**.

**The common thread:** in both runs `intelligencetasksd` crash-loops inside the simulator (EXC_BREAKPOINT every few
seconds from about 3 min after boot: `logs/crash-*`). simctl and hinge calls slow down as the device ages. The failures
come 3–15 min into a device's life, never in the first minutes. That is why a young device per hinge launch is the fix.

## Rig changes (ci/duo.sh)

- **Hinge first.** The pass order is fixed: hinge, frames, ui, store, whatever `passes` says. It is logged.
- **A fresh Duo per hinge launch** (`FRESH_FOR`: hinge, close-pause, frames-snap, ui-lesson-hinge). For each one:
  - `simctl create` with the same type and runtime (`DUO_TYPE` from the workflow; `RUNTIME_ID` from the job env, or
    read from simctl);
  - `boot` and `bootstatus -b`;
  - `sim_settle`: wait until SpringBoard's PID is the same in 3 polls 3 s apart, and at least `SETTLE_MIN`=25 s have
    passed. If launchctl can't be asked, a plain pause instead;
  - install the app, then a **warm-up `hinge get`** (2 tries; it sets CUR from the reported angle).

  The old Duo is shut down first, so only one is ever booted. Once the new one is up, the old one is deleted, if this
  script made it. The workflow's Duo also gets a settle at the start.
- **Short hinge calls:**
  - a set times out after 10 s (was 20);
  - a sweep times out after its length + 10 s (was + 20);
  - a sweep over 1.5 s is sent as chunks (`frames` 165→150 in 2 s, the reopen in 2.5 s);
  - CREEP's 3 s sweep is kept `whole`, because a gap would let the 0.6 s rest reference settle in the middle of the
    measurement. It is the longest call left, with a 13 s cap.
- **Retries on a timed-out call:** the call is sent once more (`HINGE_TRIES`=2) if the device still answers. Each
  retry is a `WARN … sending it again` line; `ok on try 2/2` follows if it works.
- **"Dead" means dead:** `sim_booted` asks `simctl list`, then `simctl getenv`, twice, 5 s apart. Diagnostics now
  include the host load and the busiest processes.
- **Whole check retries (`run_check`):** a check attempt counts as failed when it has a SIMULATOR or HINGE-TOOL row, an
  INCONCLUSIVE verdict, or a `SIMULATOR DEAD` INFO row. The whole check (launch, moves, verdicts, frames) then runs
  again on a new Duo, at most `CHECK_RETRIES`=2 more times (workflow input `retries`).
  - The best attempt's rows go into `checks.tsv`: the most PASS/FAIL verdicts and live INFO rows, with ties going to
    the later attempt. Its frames and app log are restored.
  - Each other attempt becomes one `HINGE-RETRY INFO` row. Its files are kept: `logs/<launch>-attempt-<k>.tsv` and
    `.txt`, and `raw/<frame>-attempt-<k>.png`.
- **Recovery:** a dead Duo before any launch is replaced by a fresh one. If that fails, the old one is rebooted (with
  a settle and a warm-up). If that fails too, CoreSimulatorService is restarted once and a fresh Duo is tried. Only
  then does the script stop (`bail` keeps the rows of an attempt in progress).
- **RIG INFO** adds: timed-out calls sent again, fresh Duos, checks run again, and the host load.
- Every existing check and log line is kept. The new lines are `CHECK-RUN`, `SIM: fresh Duo …`,
  `SIM: SpringBoard settled …` and `SIM: hinge warm-up get …`.

## Frames (#1, #11, #15)

- **Lesson steps 2 and 3, real hinge, `fold=1`.** The ui pass now has `ui-lesson-hinge` (fresh Duo, retried):
  `lessonStep=1;fold=1` at 160°. The pose step passes, step 2 is shot with its fly sipping, a hinge snap
  (160 → 128) moves it to step 3, which is shot at 128°, and the reopen to 160 moves it to step 4.
  - Frames: `duo-ui-lesson-{2,3,4}-hinge-*`, plus a `LESSON-HINGE INFO` row with the step lines and the snapped line.
  - The direct entries `lessonStep=2;fold=1` and `lessonStep=3;fold=1` are review lines 22 and 23.
  - **App finding (not fixed here):** R4's `ui-lesson-2` launched straight into step 2 logs
    `'When it's sipping… tap to snap!'`. The step's text is chosen at `SNAP-T input touch`, before the first hinge
    sample. Via step 1 it says "snap shut!".
- **chain5 at ×5.** `freezeOn=chain5` fires on the 5th chain step: ×3.5 (R4 39's log: `chainUp count=5
  multiplier=3.5`, about 26 s in). The ×5 cap is step 8 (the step is 0.5), estimated at about 41 s. All three lines
  use the perfect pilot with `freezeOn=chain5;freezeAfter=50`, so only a chain step after 50 s of play counts. The
  wait is 300 s, and the expect regex is `chainUp count=[0-9]+ multiplier=5`:
  - phone 39;
  - Duo review line 24;
  - Duo reserve DR14.
- **R4 frames at Duo aspect** (`ci/duo-scenarios.txt`). Existing lines are tagged with their R4 numbers: 01 (R4 02),
  02 (10), 10 (23, now with `fold=1`), 11 (25) and 12 (Results 26). New lines:
  - 17: the pose card;
  - 18: the cover card on the inner display;
  - 19: the cover display, shut (`ciHinge=0`, 1398 × 2034);
  - 20: 13 (the casual hold);
  - 21: 21 (casual play at 8 s, the chip stack; `fold=0` dropped, the Duo has a fold);
  - 22–23: lesson steps 2 and 3;
  - 24: the ×5 chain;
  - 25: the feast open after the bite.

  The frames pass still shoots `duo-04-cover-shut` and `duo-06-pose-card`, and the ui pass shoots Home, Results and
  `duo-ui-cover`.
- **Upload set** (`ci/duo-store-scenarios.txt`):
  - **D02 is now open after the bite.** `ciShootOn=feast` shoots the live run 0.5 s after `SNAP-T event feast`, not
    the 0.3 s freeze, which was the dark release.
  - Reserves DR3–DR14 hold the same R4 frames with captions. DR10 (`hudLeft=1`) and DR12 (the cover display, not a
    slot size) are FLAGGED by design.
- **New CI-only keys** (stripped before launch; the app ignores unknown keys anyway): `ciHinge=<deg>` and
  `ciShootOn=<event>`.

## Checked here, not yet on CI

- `bash -n` passes on every `ci/*.sh` and on the duo.yml `run:` blocks.
- **Dry runs against mock `xcrun`/`hinge`** (Git Bash):
  - healthy: all PASS, 2 fresh Duos;
  - a Duo dying on the 5th hinge call: SIMULATOR FAIL, attempt 1 set aside, attempt 2 clean on a new Duo, one
    HINGE-RETRY row;
  - a hung call: timed out, then `ok on try 2/2`;
  - `passes="frames hinge"`: hinge still ran first;
  - the lesson walk, `ciHinge=0` and `ciShootOn` all worked.
- **Unverified on a real runner:**
  - how long a fresh 27.1 Duo takes to boot first time (guessed at 1–4 min; Capture now has 180 min, the job 260);
  - the `hinge get` output format (CUR falls back to 180);
  - SpringBoard's launchctl label (falls back to a plain pause);
  - whether the feast pop is still up 0.5 s plus the screenshot latency after the bite;
  - whether chain step 8 lands before 50 s on the Duo (if not, it freezes later and still at ×5; if the chain breaks,
    the frame is flagged).
- **Not done:** the phone store set's P02 still uses `freezeOn=feast`, because `ci/screenshots.sh` has no
  `ciShootOn`. Port it if the Duo D02 frame reads well.

**Next:** `gh workflow run duo.yml -R pravegm/snapjaw`. Gate sign-off on hinge-input SNAP, REARM, CREEP and
CLOSE-PAUSE, no pause at 95°, the too-flat frame, `LESSON-HINGE` and `checks.tsv` rows from a single kept attempt per
check.
