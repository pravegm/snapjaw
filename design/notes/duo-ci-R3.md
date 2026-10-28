# Duo CI, R3: the R2 "hinge regression" was a dead simulator

Runs compared: **R1** Duo run 40603497021 (head 4288a1f, SNAP/REARM/CREEP/CLOSE-PAUSE PASS) and **R2** Duo run
40615925900 (head 02d0827, SNAP/REARM INCONCLUSIVE, CREEP/CLOSE-PAUSE FAIL). Both used the same runner image
(xcode-27-arm64 20261023.0307.1, GitHub-hosted), the same `hinge` 0.3.0 and an unchanged `ci/duo.sh` and `duo.yml`
(both last touched in 21ed1db).

## Root cause

The iPhone Duo simulator **shut down about 40 s into the hinge pass** (~01:46:09 UTC), before the first fast sweep.
For the remaining 77 minutes of the job, `ci/duo.sh` drove a device that no longer existed. It recorded every check as
FAIL or INCONCLUSIVE, as if the app were at fault, and saved 0 frames (the artifact is 25 KB). This was not an app
regression, and none of the R2 App/Input/UI changes is involved.

Evidence (artifacts/duo2/duo-screens/duo-screens/logs/run.txt and the job log):

- The first hinge call of the SNAP wiggle came back from simctl with `Process spawn via launchd failed because device
  is not booted` / `Bad or unknown session: com.apple.CoreSimulator.SimDevice.2C1D5F58-…`, logged as
  `[01:46:17] WARN sweep 160 -> 159 exited non-zero`.
- After that, every one of the 109 hinge calls printed `hinge: no booted simulator (boot one: xcrun simctl boot
  "iPhone Duo")`. Every launch from close-pause on failed with `Unable to lookup in current state: Shutdown`, then
  `no 'SNAP-T frame 120' after 45 s`, and every shot had `inner=-1 cover=-1 … size=?`. `close-pause.txt` and every
  later app log are empty.
- `hinge.txt` (670 lines) ends mid-play with an ordinary `SNAP-T trap closure …` line. It has no crash, no pause and
  no route change. The last `SKView … no drawables` stamp is 01:46:05.979, about 40 lines (about 4 s) before the end.
  The app was killed along with the device.
- The R1 job log contains no `no booted` lines.

The collected logs do not show why the device died (no CoreSimulator logs, device system.log or crash reports were
uploaded). The script now collects them (see below). If it recurs at the same moment, compare the new
`logs/sim-death-*.txt` against the app's memory and audio use (R2 added 128 voices) and the hinge helper.

## The three questions

1. **Was the app in play?** Yes, the whole time. `SNAP-T demo 'screen=play;mode=attract;seed=7' starts`,
   `SNAP-T screen playing`, waves 1 to 12 and 19 `bugSipping` events were logged, with no `paused`, `lesson`, `pose`
   or `screen home` line. **The brief's claim that there were no trap lines is wrong:** `hinge.txt` has **399
   `SNAP-T trap closure …` lines**. Between the 01:45:30.3 and 01:45:35.4 stamps there are 47 trap lines (about
   9 Hz) and 10 `SNAP-T hinge closure` lines (2 Hz, Feel's diagnostic). R1's log shows the same pattern.
2. **Why did the hinge samples stop?** They never "stopped" for an app reason. `HingeReader` is attached once at
   `RootView` (UI/RootView.swift:45), and only a scene-phase change toggles its `isEnabled`. Neither happened: there
   was no background or pause line. `FeelHingeLog` is gated only by `FeelDemoLog.isEnabled` at 10 Hz, and it was
   clearly on. The hinge only reports while it moves, and the CLI only moves during sweeps. A still hinge at 160°
   gives one sample at launch (156.1°, the same offset as R1's `SNAP-H 709.834 156.1`).
   - R2 logged 6 samples: the launch sample, the first wiggle (155.8 → 155.4 at about 01:45:45) and part of the
     second (155.7 at about 01:45:58).
   - R1's log has the same 3 or 4 samples at the same point (lines 10, 213, 223, 230).
   - Then the device died, so the 0.15 s snap sweep never happened. That is why the angle looks "stuck at 156".
   - The hinge calls were already slow beforehand: about 13 s between the wiggle samples, against about 0.5 to 4 s
     in R1. That suggests the simulator was degrading.
   - The hinge tool itself was not failing. Its errors are a consequence of the dead device, not a cause.
3. **Did a CI log line change?** No. `git diff 4288a1f 02d0827 -- Snap` and `02d0827..HEAD` add only `SNAP-T hinge
   stale snap dropped …`, `SNAP-T toast bees-cost`, `SNAP-T first run options` and the `SNAP-T badges`/`SNAP-BADGE`
   lines. `SNAP-T trap closure`, `SNAP-H`, `event snapped|rearmed|bugSipping|bugSpooked`, `paused closing`,
   `resumed`, `freeze`, `frame 120`, `canvas` and `input` are byte-identical. The `SNAP-T hinge closure` line exists
   in R1 too, and it is not new.

## Fix (ci/duo.sh only; no app code changed)

- **Every hinge call goes through `hinge_call`.** It writes the output to a file, so a lingering helper can't hold a
  pipe open, and it records the exit code (124/137/142 = our timeout) and the tool's last message in each `WARN`.
- **A dead simulator is detected and reported.** The trigger is a hinge message such as `no booted simulator`,
  `not booted`, `unknown session` or `Shutdown`, or `simctl list devices` no longer showing the device as Booted.
  The script then:
  - records one `SIMULATOR FAIL` row, naming the launch and the app log line;
  - writes `logs/sim-death-N.txt` (device list, the app's last lines, the device's system.log, CoreSimulator.log,
    fresh crash reports, which are also copied to `logs/crash-N/`);
  - skips further hinge moves;
  - turns that launch's SNAP/REARM/CREEP/CLOSE-PAUSE verdicts into **INCONCLUSIVE**, and tags its INFO rows
    `SIMULATOR DEAD`.
- **The next `launch` reboots the device** (`boot`, `bootstatus -b`, a fresh `hinge get`, then the wanted angle again),
  so the rest of the run still yields evidence. If the device can't be rebooted, the script stops with exit 1 instead
  of running 75 minutes against nothing.
- **A dead hinge tool is detected.** After 5 failures in a row on a booted device, the script adds one
  `HINGE-TOOL FAIL` row. A verdict taken right after 3 or more consecutive hinge failures becomes INCONCLUSIVE.
- **New info rows:** `RIG INFO` (failed hinge calls, simulator deaths). CANVAS and the launch log now count the trap
  lines and the hinge closure lines.
- **Both line names are accepted.** The `trap_vals`, `closure_before/after` and `angle_before` helpers now accept
  `SNAP-T (trap|hinge) closure` (same fields), so a check survives either line going missing.

Dry-run against mock `xcrun`/`hinge` (Git Bash):
- **Device dying on the 4th hinge call:** SIMULATOR FAIL, then SNAP/REARM/CREEP INCONCLUSIVE, then a reboot, and
  close-pause launched normally.
- **Tool always failing:** HINGE-TOOL FAIL, and all four checks INCONCLUSIVE.
- **Healthy tool:** the same verdicts as before.

`bash -n` passes. Not yet run on the real Duo workflow: the next step is to re-dispatch Duo on the R3 head.
