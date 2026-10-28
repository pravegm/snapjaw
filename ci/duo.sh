#!/usr/bin/env bash
# iPhone Duo simulator pass for Snapjaw (called by .github/workflows/duo.yml). Adapted from the sister projects' proven
# ci/duo.sh (the book-pose one and the tabletop one built today); Snapjaw plays in BOOK pose like the former, so no
# orientation request is ever sent.
#
# Lessons inherited from the sister projects (their DUO-CI notes and duo runs):
#  - `simctl io screenshot` needs --display on the Duo; the names vary (LCD/LCD-1, primary/primary-1, 1/3), so we probe
#    them once, capture BOTH panels every shot and keep the lit one (brightness check: a panel that is off is black).
#  - The Duo sim starts in book pose: a landscape inner canvas (~951 x 669 pt) with the fold running top to bottom.
#    That is exactly Snapjaw's play pose (the two halves are the lobes, the fold is the midrib).
#  - Never run `simctl io … screenConfig` on the Duo (SpringBoard crash loop).
#  - Wait ~2.5 s after a hinge move for the display to settle; `hinge` occasionally drops a move, so `set` retries 3x.
#    `hinge sweep` streams at 60 Hz, so the app sees a real motion (and a real snap speed) rather than a jump.
#  - A perfectly still hold made the tool deliver the next fast sweep as 1–2 samples (sister duo run 40533062342), so
#    every fast snap is preceded by tiny silent 1° wiggles (hinge_wiggle) that keep samples flowing.
#  - Closing from open, iOS may hand over to the cover display anywhere from ~60° down to ~20°; 0° is the cover.
#    Reopening from shut, the cover stays lit until ~150°, so a reopen from shut goes to 165° before coming back down.
#  - Every simctl / hinge call has a timeout; a shot takes ~15 s (shoot_now: 3–7 s), so no shot is ever taken inside a
#    timed check window.
#  - The app prints one line per event (print + fflush), so line numbers order events in time.
#
# Hinge checks (R8: design/ROUND-8.md "Owners", design/notes/core-R8.md: the lid is the jaw), each a
# "<CHECK> PASS|FAIL|INCONCLUSIVE|INFO (detail)" line in logs/run.txt, a row in checks.tsv and in the job summary. Every
# hinge launch starts with round_open (founder rule 3: a round starts closed: shut the Duo, no bite, open it again; the
# ROUND INFO row says whether "SNAP-T round open" came and the starting shut bit nothing).
#  1. BITE: launch `screen=play;mode=attract;seed=7` at 150°, round_open, wait for `SNAP-T event bugSipping`, sweep
#     150 → 5 in 0.3 s. PASS: `SNAP-T event snapped caught=<n>` with n ≥ 1 after the sweep began.
#  2. COVER: on that shut, the cover panel is shot (`duo-h1-cover-shut`). PASS: the cover panel is lit.
#  3. REOPEN: then back to 150. PASS: `SNAP-T event rearmed` after the bite and no `SNAP-T event waveStarted|bugArrived`
#     between the bite and the re-arm (the clock is frozen while shut; the cover shot makes the shut ~15 s long).
#  4. SLOW-CLOSE: a fresh launch (the same seed), 150 → 5 over 2.5 s. PASS: its bite caught fewer than BITE's, or
#     escaped ≥ 1.
#  5. NO-BITE-DEEP: a fresh launch, 150 → 60 → 150. PASS: no snapped line in the window (INCONCLUSIVE when the app
#     never logged an angle under 100°).
# Log lines read: `SNAP-T event …` (App), `SNAP-T trap closure … armed … creep … angle … ref …` (App, 10 Hz),
# `SNAP-T hinge closure …` (Input, 2 Hz), and R8's Input lines `SNAP-T shut d=<s> angle <θ> status <s>`,
# `SNAP-T reopened angle <θ>` and `SNAP-T round open angle <θ>` (Snap/Input/HingeTrapSource.swift).
# Frames: open 165, half closed 150 (`closure=11`), the bite's shut (cover), the shut cover display, reopened 165, and
# the pose card. R8: the R1–R7 SNAP / CREEP / REARM / CLOSE-PAUSE checks and the NO-PAUSE-95 / CREEP-FAST rows are gone
# (no partial snap, no creep, no closing pause).
# Rig rows (design/notes/duo-ci-R3.md): SIMULATOR FAIL when the Duo shut down mid-run (then rebooted before the next
# launch; that launch's checks are INCONCLUSIVE), HINGE-TOOL FAIL when the hinge CLI keeps failing on a booted Duo, and
# RIG INFO (failed hinge calls, simulator deaths).
#
# R5 rig (design/notes/ci-R5.md; Duo runs 40626586037 and 40634483657):
#  - The passes always run in the order hinge, frames, ui, store: the hinge checks get the youngest simulator.
#  - Each hinge-driven check launch (FRESH_FOR: bite, slow-close, no-bite-deep, frames-snap, ui-close-to-start) runs on a FRESH Duo:
#    `simctl create` (same device type and runtime), boot, `bootstatus -b`, a pause until SpringBoard is settled (the
#    same PID for 3 polls, at least SETTLE_MIN s), install, then a warm-up `hinge get`. The old Duo is shut down first
#    (one booted Duo at a time), and deleted when this script made it.
#  - No hinge call runs long: a set times out after HINGE_SET_TO (10) s, a sweep after its length + HINGE_PAD (10) s,
#    and a repositioning sweep longer than SWEEP_CHUNK (1.5) s is sent as chunks. The measured sweeps (SLOW-CLOSE's
#    2.5 s) stay whole. A timed-out call is retried once (HINGE_TRIES=2) while the device is still booted.
#  - "Booted" is asked twice (simctl list, then `simctl getenv`), because a slow `simctl list` made a live Duo look
#    dead in run 40634483657 (sim-death-1.txt lists it as Booted).
#  - If a check's launch dies (a SIMULATOR / HINGE-TOOL row, or any INCONCLUSIVE verdict), the WHOLE check is run again
#    on a new Duo, at most CHECK_RETRIES (2) more times. The best attempt's rows go into checks.tsv (ties: the later
#    one); every other attempt is one HINGE-RETRY INFO row, with its rows in logs/<launch>-attempt-<k>.tsv, its app log
#    in logs/<launch>-attempt-<k>.txt and its frames in raw/<frame>-attempt-<k>.png.
#  - A dead Duo before a launch is replaced by a fresh one (then rebooted, then CoreSimulatorService restarted).
#
# Env: UDID (required), OUT (duo-screens), PASSES ("hinge frames ui store"), STRICT (1 = exit 1 when a check FAILs;
# default 0: the frames and the PASS/FAIL table are the evidence), STORE_LIST / STORE_FILTER / STORE_ANGLE (the store
# pass, ci/duo-scenarios.txt at 150°), DUO_TYPE / RUNTIME_ID (for fresh Duos; read from simctl when unset),
# CHECK_RETRIES, FRESH_FOR, SETTLE_MIN, SWEEP_CHUNK, HINGE_PAD, HINGE_SET_TO, HINGE_TRIES, CI_SHOOT_DELAY.
# CI-only scenario keys (stripped before the app sees them): `ciHinge=<deg>` (shoot at that angle; under 30° closes
# the Duo as frames-cover does and shoots the cover display) and `ciShootOn=<event>` (no freeze: shoot the inner panel
# CI_SHOOT_DELAY s after `SNAP-T event <event>`, i.e. the trap open again after the bite).
# Writes: $OUT/*.png (lit panel), $OUT/raw/<shot>-inner|cover.png, $OUT/logs/<launch>.txt (app stdout+stderr),
# $OUT/logs/run.txt (this script), $OUT/checks.tsv (check <TAB> PASS|FAIL|INFO|INCONCLUSIVE <TAB> detail) and, when
# $GITHUB_STEP_SUMMARY is set, a summary table.
set -uo pipefail

APP="build/Build/Products/Debug-iphonesimulator/Snap.app"
BUNDLE="com.pravegm.snapjaw"
OUT="${OUT:-duo-screens}"
PASSES="${PASSES:-hinge frames ui store}"
STRICT="${STRICT:-0}"
: "${UDID:?UDID is required}"
mkdir -p "$OUT/raw" "$OUT/logs"
OUT_ABS="$(cd "$OUT" && pwd)"
RUNLOG="$OUT_ABS/logs/run.txt"
CHECKS="$OUT_ABS/checks.tsv"
: > "$CHECKS"
SINK="$CHECKS"    # where result() writes: checks.tsv, or the current check attempt's buffer (run_check)
CHECK_RETRIES="${CHECK_RETRIES:-2}"
FRESH_FOR="${FRESH_FOR:-bite slow-close no-bite-deep frames-snap ui-close-to-start}"
SETTLE_MIN="${SETTLE_MIN:-25}"
SWEEP_CHUNK="${SWEEP_CHUNK:-1.5}"
HINGE_PAD="${HINGE_PAD:-10}"
HINGE_SET_TO="${HINGE_SET_TO:-10}"
HINGE_TRIES="${HINGE_TRIES:-2}"
[[ "$HINGE_TRIES" =~ ^[1-9][0-9]*$ ]] || HINGE_TRIES=1
[[ "$CHECK_RETRIES" =~ ^[0-9]+$ ]] || CHECK_RETRIES=2
CI_SHOOT_DELAY="${CI_SHOOT_DELAY:-0.5}"
DUO_TYPE="${DUO_TYPE:-}"
RUNTIME_ID="${RUNTIME_ID:-}"
BASE_UDID="$UDID"
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$RUNLOG" >&2; }
to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}

# result <CHECK> <PASS|FAIL|INFO|INCONCLUSIVE> <detail>: one line in the run log ("SNAP PASS (…)") and in checks.tsv.
result() {
  log "$1 $2 ($3)"
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$SINK"
}

# write_summary: the checks as a table in the job summary (called on every exit path).
write_summary() {
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return 0
  {
    echo "### Snapjaw on the iPhone Duo simulator"
    echo ""
    echo "Passes: \`$PASSES\`; displays inner=\`${INNER:-?}\` cover=\`${COVER:-?}\`."
    echo ""
    echo "| Check | Result | Detail |"
    echo "|---|---|---|"
    awk -F'\t' '{ d = $3; gsub(/\|/, "\\|", d); r = ($2 == "INFO" ? $2 : "**" $2 "**"); printf "| %s | %s | %s |\n", $1, r, d }' "$CHECKS"
    echo ""
    echo "Frames: $(ls "$OUT_ABS"/*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
  } >> "$GITHUB_STEP_SUMMARY"
}

# bail: stop the run (exit 1), keeping the rows of a check attempt in progress.
bail() {
  if [[ "$SINK" != "$CHECKS" ]]; then cat "$SINK" >> "$CHECKS" 2>/dev/null; SINK="$CHECKS"; fi
  write_summary; exit 1
}

INNER=""; COVER=""
# install_app: the app onto the current Duo, 2 tries (returns 1 when both fail; the caller decides).
install_app() {
  to 300 xcrun simctl install "$UDID" "$APP" && return 0
  log "install failed, retrying"; sleep 5
  to 300 xcrun simctl install "$UDID" "$APP"
}
# probe_displays: the inner and cover display names (they vary: LCD/LCD-1, primary/primary-1, 1/3).
probe_displays() {
  local c
  for c in LCD-1 primary-1 3 internal; do
    to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { INNER="$c"; break; }
  done
  for c in LCD primary 1 external; do
    [[ "$c" == "$INNER" ]] && continue
    to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { COVER="$c"; break; }
  done
  rm -f "$OUT_ABS/raw/_p.png"
  log "displays inner=$INNER cover=$COVER"
}

HAVE_HINGE=0; command -v hinge >/dev/null 2>&1 && HAVE_HINGE=1
(( HAVE_HINGE )) || log "WARN no hinge tool: the hinge checks will FAIL and every frame stays at the boot angle"
CUR=180; WANT=180

# ---- a dead simulator / a dead hinge tool (design/notes/duo-ci-R3.md) ----------------------------------------------
# Duo run 40615925900: the Duo simulator shut down ~40 s into the hinge pass (`hinge: no booted simulator`, simctl
# "device is not booted … Bad or unknown session"), and the script went on for 75 minutes against a dead device,
# reporting FAIL/INCONCLUSIVE as if the app were broken. Now: every hinge failure records the tool's exit code and last
# message; a device that is no longer booted is reported as a SIMULATOR FAIL row with diagnostics, the checks of that
# launch become INCONCLUSIVE (a dead device is no evidence about the app), and the next launch reboots the device first.
# A tool that keeps failing on a booted device is a HINGE-TOOL FAIL row.
SIM_LOST=0        # the simulator died since the current launch
SIM_DEATHS=0
HINGE_RUN=0       # consecutive failed hinge calls
HINGE_ERRS=0      # failed hinge calls in the whole run
HINGE_LAST=""     # the last failure: "exit <rc>: <message>"
HINGE_DEAD_LOGGED=0
CUR_LOG=""        # the current launch's app log
CUR_LAUNCH=""
FRESH_N=0         # fresh Duos made by this run
MADE_UDIDS=" "    # the devices this script created (deleted when retired)
HINGE_RETRIES=0   # timed-out hinge calls that were sent again
RERUNS=0          # whole check attempts run again on a new Duo
ATTEMPT_SHOTS=""  # the frames shot during the current check attempt

# sim_booted: 0 when CoreSimulator still lists the Duo as Booted. R5: run 40634483657's first "death" was a live Duo
# (sim-death-1.txt lists it as Booted) whose `simctl list` was slow, so a device that answers `simctl getenv` counts as
# booted too, and both are asked twice, 5 s apart, before the Duo is called dead.
sim_booted() {
  local i
  for i in 1 2; do
    to 30 xcrun simctl list devices 2>/dev/null | grep -F "$UDID" | grep -q "(Booted)" && return 0
    if to 20 xcrun simctl getenv "$UDID" HOME >/dev/null 2>&1; then
      log "NOTE simctl list did not show $UDID as Booted, but the device answers (simctl getenv): booted"
      return 0
    fi
    (( i == 1 )) && sleep 5
  done
  return 1
}
# loadavg: the runner's load averages (a starved host makes every simctl / hinge call slow).
loadavg() { local l; l=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | sed 's/^ *//; s/ *$//'); echo "${l:-?}"; }

# sim_diag <file>: what the host knows about the device's death (device list, the app's last lines, the device's own
# system.log, CoreSimulator's log, fresh crash reports).
sim_diag() {
  local f="$1" crash="$OUT_ABS/logs/crash-$SIM_DEATHS"
  {
    echo "== $(date -u +%FT%TZ) SIM-DEAD during launch '${CUR_LAUNCH:-none}' (hinge ${CUR}°, last hinge failure: ${HINGE_LAST:-none})"
    echo "== simctl list devices"; to 20 xcrun simctl list devices 2>&1
    echo "== host load: $(loadavg); busiest processes"; ps -Ao pcpu,rss,comm -r 2>/dev/null | head -15
    if [[ -n "$CUR_LOG" ]]; then echo "== app log ($CUR_LOG, $(nlines "$CUR_LOG") lines), last 15"; tail -n 15 "$CUR_LOG" 2>&1; fi
    echo "== device system.log, last 300"; tail -n 300 "$HOME/Library/Logs/CoreSimulator/$UDID/system.log" 2>&1
    echo "== CoreSimulator.log, last 150"; tail -n 150 "$HOME/Library/Logs/CoreSimulator/CoreSimulator.log" 2>&1
    echo "== crash reports from the last 15 min (copied to logs/crash-$SIM_DEATHS/)"
    find "$HOME/Library/Logs/DiagnosticReports" "$HOME/Library/Logs/CoreSimulator/$UDID" -type f -mmin -15 2>/dev/null
  } > "$f" 2>&1
  mkdir -p "$crash"
  find "$HOME/Library/Logs/DiagnosticReports" -type f -mmin -15 -exec cp {} "$crash/" \; 2>/dev/null || true
}

# sim_lost <why>: mark the current launch's device as dead (once per launch) and collect the diagnostics.
sim_lost() {
  (( SIM_LOST )) && return 0
  SIM_LOST=1; SIM_DEATHS=$((SIM_DEATHS + 1))
  local f="$OUT_ABS/logs/sim-death-$SIM_DEATHS.txt" at="-"
  [[ -n "$CUR_LOG" ]] && at="$(nlines "$CUR_LOG")"
  log "SIM-DEAD: the Duo simulator is no longer booted ($1; launch '${CUR_LAUNCH:-none}', app log line $at); diagnostics in logs/$(basename "$f")"
  sim_diag "$f"
  result SIMULATOR FAIL "the Duo simulator shut down during launch '${CUR_LAUNCH:-none}' (app log line $at; $1); diagnostics logs/$(basename "$f"); the checks of that launch are INCONCLUSIVE"
}

# sim_settle <min s>: after a boot, wait until SpringBoard is settled: the same SpringBoard PID in 3 polls 3 s apart,
# and at least <min> s since the call (first boots run data migration and crash-looping daemons: intelligencetasksd
# crashed every few seconds in runs 40626586037 and 40634483657). At most 120 s; if launchctl can't be asked at all,
# a plain <min> s pause.
sim_settle() {
  local min="${1:-0}" t0=$SECONDS pid last="" same=0 miss=0
  while (( SECONDS - t0 < 120 )); do
    pid=$(to 20 xcrun simctl spawn "$UDID" launchctl list 2>/dev/null \
      | awk 'tolower($3) ~ /(^|[.:])com\.apple\.springboard$/ && $1 ~ /^[0-9]+$/ { print $1; exit }')
    if [[ -n "$pid" ]]; then
      miss=0
      if [[ "$pid" == "$last" ]]; then same=$((same + 1)); else same=1; last="$pid"; fi
    else
      same=0; last=""; miss=$((miss + 1))
      if (( miss >= 4 )); then
        log "WARN SIM: SpringBoard not found by launchctl (4 polls); a plain pause to ${min} s"
        (( SECONDS - t0 < min )) && sleep $(( min - (SECONDS - t0) ))
        return 1
      fi
    fi
    if (( same >= 3 && SECONDS - t0 >= min )); then
      log "SIM: SpringBoard settled (pid $pid, the same in 3 polls; $((SECONDS - t0)) s; host load $(loadavg))"
      return 0
    fi
    sleep 3
  done
  log "WARN SIM: SpringBoard not settled after 120 s (last pid ${last:-none}); going on"
  return 1
}

# hinge_warm: the warm-up `hinge get` after a boot (the first call on a device installs the tool's in-simulator
# helper; do it outside any timed check). Sets CUR from the reported angle when one can be read, else 180.
hinge_warm() {
  (( HAVE_HINGE )) || return 1
  local tmp="$OUT_ABS/raw/_warm.txt" try a
  for try in 1 2; do
    if to 120 hinge -d "$UDID" get > "$tmp" 2>&1; then
      cat "$tmp" >> "$RUNLOG"
      a=$(grep -iE 'angle|°|^[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]*$' "$tmp" | grep -oE '[0-9]+(\.[0-9]+)?' | tail -1)
      a="${a%.*}"
      if [[ "$a" =~ ^[0-9]+$ ]] && (( a <= 180 )); then CUR="$a"; else CUR=180; fi
      log "SIM: hinge warm-up get ok on try $try (${a:-?}°)"
      rm -f "$tmp"; return 0
    fi
    cat "$tmp" >> "$RUNLOG" 2>/dev/null
    log "WARN hinge warm-up get failed (try $try): $(grep . "$tmp" 2>/dev/null | tail -1 | tr -d '\r' | cut -c1-160)"
    sleep 3
  done
  rm -f "$tmp"; CUR=180; return 1
}

# boot_ready <label> <settle min s>: boot the current Duo, wait for bootstatus, settle SpringBoard, install the app,
# warm the hinge helper. Returns 1 when it doesn't boot or the app won't install.
boot_ready() {
  local t0=$SECONDS
  to 120 xcrun simctl boot "$UDID" >>"$RUNLOG" 2>&1 || true
  to 600 xcrun simctl bootstatus "$UDID" -b >>"$RUNLOG" 2>&1 || true
  sim_booted || { log "WARN SIM: $1 ($UDID) did not boot"; return 1; }
  log "SIM: $1 ($UDID) booted after $((SECONDS - t0)) s"
  sim_settle "$2"
  install_app || { log "WARN SIM: the app did not install on $1 ($UDID)"; return 1; }
  hinge_warm || log "WARN SIM: no warm-up hinge reading on $1"
  SIM_LOST=0; HINGE_RUN=0
  return 0
}

# duo_ids: DUO_TYPE and RUNTIME_ID of the current Duo (from the env, else from simctl's JSON).
duo_ids() {
  [[ -n "$DUO_TYPE" && -n "$RUNTIME_ID" ]] && return 0
  local ids
  ids=$(to 30 xcrun simctl list devices -j 2>/dev/null | python3 -I -c '
import json, sys
u = sys.argv[1]
for rt, devs in json.load(sys.stdin).get("devices", {}).items():
    for d in devs:
        if d.get("udid") == u:
            print(d.get("deviceTypeIdentifier", ""), rt)
            sys.exit(0)
' "$UDID" 2>/dev/null)
  [[ -z "$DUO_TYPE" ]] && DUO_TYPE="${ids%% *}"
  [[ -z "$RUNTIME_ID" ]] && RUNTIME_ID="${ids#* }"
  [[ -z "$DUO_TYPE" ]] && DUO_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-Duo"
  [[ -n "$RUNTIME_ID" ]]
}

# retire <udid>: delete a device this script created (the workflow's own Duo is only shut down).
retire() {
  to 60 xcrun simctl shutdown "$1" >>"$RUNLOG" 2>&1 || true
  if [[ "$MADE_UDIDS" == *" $1 "* ]]; then
    to 60 xcrun simctl delete "$1" >>"$RUNLOG" 2>&1 || true
    MADE_UDIDS="${MADE_UDIDS/ $1 / }"
  fi
}

# fresh_device <why>: a new Duo (same type and runtime), freshly booted, settled, with the app and a warm hinge helper.
# The old Duo is shut down first, so only one is ever booted; it is deleted once the new one is up (if we made it).
# On failure the old Duo is booted again and 1 is returned.
fresh_device() {
  local why="$1" old="$UDID" new
  duo_ids || { log "WARN SIM: the Duo's device type / runtime are unknown: no fresh Duo for $why"; return 1; }
  FRESH_N=$((FRESH_N + 1))
  new=$(to 90 xcrun simctl create "Snapjaw Duo fresh $FRESH_N" "$DUO_TYPE" "$RUNTIME_ID" 2>>"$RUNLOG" | tr -d '\r' | tail -1)
  if [[ ! "$new" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
    log "WARN SIM: simctl create failed ($DUO_TYPE, $RUNTIME_ID) for $why"; return 1
  fi
  MADE_UDIDS="$MADE_UDIDS$new "
  log "SIM: fresh Duo $FRESH_N ($new) for $why; shutting down $old first (host load $(loadavg))"
  to 90 xcrun simctl shutdown "$old" >>"$RUNLOG" 2>&1 || true
  UDID="$new"
  if boot_ready "fresh Duo $FRESH_N" "$SETTLE_MIN"; then
    retire "$old"
    CUR_LOG=""; SIM_LOST=0; HINGE_RUN=0
    return 0
  fi
  log "WARN SIM: fresh Duo $FRESH_N did not come up; back to $old"
  retire "$new"
  UDID="$old"
  boot_ready "the previous Duo" 10 || log "WARN SIM: the previous Duo ($old) did not come back either"
  return 1
}

# sim_recover: before a launch, replace a dead Duo with a fresh one; failing that, reboot it (boot, bootstatus,
# settle, re-warm the hinge helper, re-apply the wanted angle); failing that, restart CoreSimulatorService once and try
# a fresh one again. Stops the script when none works: nothing after that would be evidence.
sim_recover() {
  sim_booted && return 0
  sim_lost "found shut down before launch '$1'"
  if fresh_device "recovery before launch '$1'"; then
    log "SIM: fresh Duo up; re-applying ${WANT}°"
    hinge_set "$WANT" || true
    return 0
  fi
  log "SIM: rebooting the Duo"
  if ! boot_ready "the rebooted Duo" 10; then
    log "SIM: restarting CoreSimulatorService (simctl itself may be wedged), then a fresh Duo"
    killall -9 com.apple.CoreSimulator.CoreSimulatorService >>"$RUNLOG" 2>&1 || true
    sleep 10
    if ! fresh_device "recovery after a CoreSimulatorService restart"; then
      result SIMULATOR FAIL "the Duo could not be rebooted after shutting down; stopped before launch '$1'"
      bail
    fi
  fi
  log "SIM: rebooted; re-applying ${WANT}°"
  SIM_LOST=0; HINGE_RUN=0
  hinge_set "$WANT" || true
}

# hinge_call <timeout s> <args…>: one hinge invocation (its output → the run log, via a file: a lingering helper can't
# hold a pipe open). On failure: the exit code (124/137/142 = our timeout) and the tool's last message, then either
# SIM-DEAD (the device is gone) or, after 5 failures in a row on a booted device, one HINGE-TOOL FAIL row.
# R5: a call that timed out is sent once more (HINGE_TRIES) while the Duo is still booted: in runs 40626586037 and
# 40634483657 every hinge failure was a 20 s timeout of an otherwise ordinary call.
hinge_call() {
  local s="$1" tmp="$OUT_ABS/raw/_hinge.txt" rc why msg try; shift
  for (( try = 1; try <= HINGE_TRIES; try++ )); do
    to "$s" hinge -d "$UDID" "$@" > "$tmp" 2>&1; rc=$?
    cat "$tmp" >> "$RUNLOG" 2>/dev/null
    if (( rc == 0 )); then
      HINGE_RUN=0; rm -f "$tmp"
      (( try > 1 )) && log "hinge $*: ok on try $try/$HINGE_TRIES"
      return 0
    fi
    HINGE_ERRS=$((HINGE_ERRS + 1)); HINGE_RUN=$((HINGE_RUN + 1))
    case "$rc" in 124|137|142) why="timed out after ${s}s (exit $rc)";; *) why="exit $rc";; esac
    msg=$(grep . "$tmp" 2>/dev/null | tail -1 | tr -d '\r' | tr '\t' ' ' | cut -c1-160); rm -f "$tmp"
    HINGE_LAST="hinge $*: $why${msg:+: $msg}"
    grep -qiE "no booted simulator|not booted|unknown session|current state: Shutdown" <<<"$msg" && break
    case "$rc" in 124|137|142) ;; *) break;; esac
    (( try < HINGE_TRIES )) || break
    sim_booted || break
    HINGE_RETRIES=$((HINGE_RETRIES + 1))
    log "WARN $HINGE_LAST; sending it again (try $((try + 1))/$HINGE_TRIES)"
    sleep 1
  done
  if grep -qiE "no booted simulator|not booted|unknown session|current state: Shutdown" <<<"$msg" || ! sim_booted; then
    sim_lost "$HINGE_LAST"
  elif (( HINGE_RUN >= 5 && ! HINGE_DEAD_LOGGED )); then
    HINGE_DEAD_LOGGED=1
    result HINGE-TOOL FAIL "$HINGE_RUN hinge calls in a row failed on a booted Duo (last: $HINGE_LAST); the app sees no hinge motion"
  fi
  return "$rc"
}

hinge_set() {   # hinge_set <angle>: a confirmed set, 3 tries
  WANT="$1"
  (( HAVE_HINGE )) || return 1
  (( SIM_LOST )) && return 1   # the device is gone until the next launch reboots it
  local a
  for a in 1 2 3; do
    hinge_call "$HINGE_SET_TO" -t 3 "$1" && { CUR="$1"; return 0; }
    (( SIM_LOST )) && break
    sleep 1
  done
  log "WARN hinge set $1 failed (${HINGE_LAST:-no message})"; return 1
}
# hinge_sweep <to> <seconds> [whole]: continuous 60 Hz stream so the app sees a real motion. R5: a sweep longer than
# SWEEP_CHUNK s is sent as equal chunks (no single call runs long) unless it is `whole` (a measured motion: CREEP).
hinge_sweep() {
  WANT="$1"
  (( HAVE_HINGE )) || return 1
  (( SIM_LOST )) && return 1   # CUR keeps the last angle really set
  local n step i a from="$CUR"
  n=$(awk -v s="$2" -v c="$SWEEP_CHUNK" 'BEGIN { n = int(s / c - 1e-9) + 1; print (n < 1 ? 1 : n) }')
  if [[ "${3:-}" == whole ]] || (( n <= 1 )); then
    hinge_call $(( ${2%.*} + HINGE_PAD )) sweep "$CUR" "$1" "$2" || log "WARN sweep $CUR -> $1 failed (${HINGE_LAST:-no message})"
  else
    step=$(awk -v s="$2" -v n="$n" 'BEGIN { printf "%.2f", s / n }')
    for (( i = 1; i <= n; i++ )); do
      a=$(awk -v f="$from" -v t="$1" -v i="$i" -v n="$n" 'BEGIN { x = f + (t - f) * i / n; printf "%d", (x < 0 ? x - 0.5 : x + 0.5) }')
      (( i == n )) && a="$1"
      if ! hinge_call $(( ${step%.*} + HINGE_PAD )) sweep "$CUR" "$a" "$step"; then
        log "WARN sweep $CUR -> $a failed (chunk $i/$n of $from -> $1 over $2 s; ${HINGE_LAST:-no message})"
        (( SIM_LOST )) && break
      fi
      CUR="$a"
    done
  fi
  CUR="$1"
}

# verdict <CHECK> <PASS|FAIL|INCONCLUSIVE> <detail>: result(), except that a FAIL / INCONCLUSIVE while the device was
# lost since the launch, or right after 3+ failed hinge calls in a row, is INCONCLUSIVE with the reason (a dead
# simulator or a dead hinge tool says nothing about the app).
verdict() {
  (( SIM_LOST )) || sim_booted || sim_lost "found shut down at the $1 verdict"
  if (( SIM_LOST )) && [[ "$2" != PASS ]]; then
    result "$1" INCONCLUSIVE "$3 (the Duo simulator died during this launch: no evidence about the app)"
  elif (( HINGE_RUN >= 3 )) && [[ "$2" != PASS ]]; then
    result "$1" INCONCLUSIVE "$3 (the hinge tool's last $HINGE_RUN calls failed: $HINGE_LAST)"
  else result "$1" "$2" "$3"; fi
}
# simnote: "; SIMULATOR DEAD" for INFO rows recorded after the device died.
simnote() { (( SIM_LOST )) && echo "; SIMULATOR DEAD (no evidence)"; return 0; }
# hinge_wiggle <angle> <n>: n tiny 1° sweeps (angle → angle−1 → angle, 0.4 s each way, ~2.5°/s: far under the 4° snap
# start, so it never arms a snap) so hinge samples keep flowing through a "hold" before a fast snap.
hinge_wiggle() {
  (( HAVE_HINGE )) || return 1
  local i
  for (( i = 0; i < $2; i++ )); do hinge_sweep $(( $1 - 1 )) 0.4; hinge_sweep "$1" 0.4; done
}

# brightness of a PNG, 0-255 (sips → 16×16 BMP)
brightness() {
  local tmp="$OUT_ABS/raw/_b.bmp"
  to 20 sips -z 16 16 -s format bmp "$1" --out "$tmp" >/dev/null 2>&1 || { echo -1; return; }
  python3 -I - "$tmp" <<'PY' 2>/dev/null || echo -1
import struct, sys
b = open(sys.argv[1], "rb").read()
off = struct.unpack_from("<I", b, 10)[0]; w, h = struct.unpack_from("<ii", b, 18); bpp = struct.unpack_from("<H", b, 28)[0]
step = bpp // 8; row = (w * step + 3) & ~3; tot = n = 0
for y in range(abs(h)):
    for x in range(w):
        p = off + y * row + x * step; tot += b[p] + b[p + 1] + b[p + 2]; n += 3
print(int(tot / n))
PY
  rm -f "$tmp"
}

# png_wh <file>: "WxH" of a PNG, or "?".
png_wh() {
  local w h
  w=$(to 20 sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  h=$(to 20 sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
}

shoot() {   # shoot <name> <inner|cover>: both panels to raw/, the lit one (or the wanted one) to <name>.png
  local name="$1" want="$2" ib=-1 cb=-1 pick
  ATTEMPT_SHOTS="$ATTEMPT_SHOTS $name"
  [[ -n "$INNER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT_ABS/raw/$name-inner.png" >/dev/null 2>>"$RUNLOG" && ib=$(brightness "$OUT_ABS/raw/$name-inner.png")
  [[ -n "$COVER" ]] && to 30 xcrun simctl io "$UDID" screenshot --display="$COVER" "$OUT_ABS/raw/$name-cover.png" >/dev/null 2>>"$RUNLOG" && cb=$(brightness "$OUT_ABS/raw/$name-cover.png")
  if [[ -z "$INNER$COVER" ]]; then to 30 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"; return; fi
  if (( ib > 6 && cb <= 6 )); then pick=inner; elif (( cb > 6 && ib <= 6 )); then pick=cover; else pick="$want"; fi
  [[ -f "$OUT_ABS/raw/$name-$pick.png" ]] && cp "$OUT_ABS/raw/$name-$pick.png" "$OUT_ABS/$name.png"
  [[ "$pick" != "$want" ]] && log "NOTE $name: wanted the $want panel, the $pick panel was the lit one"
  log "shot $name (inner=$ib cover=$cb -> $pick, hinge ${CUR}°) size=$(png_wh "$OUT_ABS/$name.png")"
}

# shoot_now <name>: the inner panel only, at once (no cover capture, no brightness probe): for a moment that must not
# be missed (the bite). ~3–7 s instead of ~15 s.
shoot_now() {
  local name="$1"
  ATTEMPT_SHOTS="$ATTEMPT_SHOTS $name"
  if [[ -n "$INNER" ]]; then to 30 xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"
  else to 30 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>>"$RUNLOG"; fi
  log "shot $name (inner only, at once, hinge ${CUR}°) size=$(png_wh "$OUT_ABS/$name.png")"
}

# wait_for <file> <regex> <seconds>: poll (0.2 s) until the log has the line; returns 1 on a timeout.
wait_for() {
  local i=0 n=$(( $3 * 5 ))
  while (( i < n )); do grep -qE "$2" "$1" 2>/dev/null && return 0; sleep 0.2; i=$((i+1)); done
  return 1
}

# Log helpers.
nlines() { local n; n=$(wc -l < "$1" 2>/dev/null | tr -d ' '); echo "${n:-0}"; }
count() { local n; n=$(grep -cE "$1" "$2" 2>/dev/null); echo "${n:-0}"; }
after() { tail -n +"$(( $2 + 1 ))" "$1" 2>/dev/null; }     # after <file> <line>: the lines logged since <line>
# between <file> <a> <b>: lines a+1 … b (awk, because BSD head rejects -n 0)
between() { awk -v a="$2" -v b="$3" 'NR > a + 0 && NR <= b + 0' "$1" 2>/dev/null; }
# trap_vals <field>: from "SNAP-T trap closure <c> armed <0|1> creep <0|1> angle <θ|-> ref <θ|->" lines on stdin, the
# <field> values (closure, armed, creep, angle, ref; "-" when the App has no hinge reading). The App's 10 Hz line and
# Feel's 2 Hz "SNAP-T hinge closure …" diagnostic (Input/HingeTrapSource.swift, same fields) are both read, so the
# checks survive either one going missing or being renamed. TRAP_RE is that match, shared by the helpers below.
TRAP_RE='SNAP-T (trap|hinge) closure '
trap_vals() { awk -v k="$1" -v re="$TRAP_RE" '$0 ~ re { for (i = 1; i < NF; i++) if ($i == k) print $(i + 1) }'; }
max_of() { awk 'BEGIN { m = "" } $1 ~ /^-?[0-9.]+$/ { if (m == "" || $1 + 0 > m + 0) m = $1 } END { print (m == "" ? "none" : m) }'; }
min_of() { awk 'BEGIN { m = "" } $1 ~ /^-?[0-9.]+$/ { if (m == "" || $1 + 0 < m + 0) m = $1 } END { print (m == "" ? "none" : m) }'; }
lt() { [[ "$1" =~ ^-?[0-9.]+$ ]] && awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 < b + 0) }'; }   # lt <a> <b>: a < b
# first_line <file> <regex> <after line>: the line number of the first match after <after line>, or "".
first_line() { awk -v a="$3" -v re="$2" 'NR > a + 0 && $0 ~ re { print NR; exit }' "$1" 2>/dev/null; }
# closure_before <file> <line> / closure_after <file> <line>: the closure of the last trap line before <line> / the
# first one after it, or "none".
closure_before() { awk -v n="$2" -v re="$TRAP_RE" 'NR >= n + 0 { exit } $0 ~ re { for (i = 1; i < NF; i++) if ($i == "closure") c = $(i + 1) } END { print (c == "" ? "none" : c) }' "$1" 2>/dev/null; }
closure_after() { awk -v n="$2" -v re="$TRAP_RE" 'NR > n + 0 && $0 ~ re { for (i = 1; i < NF; i++) if ($i == "closure") { print $(i + 1); exit } }' "$1" 2>/dev/null | grep . || echo none; }
# angle_before <file> <line>: the last hinge angle logged before line <line> ("SNAP-H <t> <θ>" samples, or the angle
# field of a "SNAP-T trap …" line), or "none".
angle_before() {
  awk -v n="$2" -v re="$TRAP_RE" 'NR >= n + 0 { exit }
    /^SNAP-H / { a = $3 }
    $0 ~ re { for (i = 1; i < NF; i++) if ($i == "angle" && $(i + 1) ~ /^[0-9.]+$/) a = $(i + 1) }
    END { print (a == "" ? "none" : a) }' "$1" 2>/dev/null
}
# canvas_line <file>: the latest "SNAP-T canvas <w>x<h> fold=<0|1> hudLeft=<0|1>" line.
canvas_line() { grep -oE "SNAP-T canvas [0-9]+x[0-9]+.*" "$1" 2>/dev/null | tail -1 | tr -d '\r'; }
input_of() { grep -oE "SNAP-T input [a-z]+" "$1" 2>/dev/null | tail -1 | awk '{print $3}'; }

# launch <name> <demo args>: start the app (stdout+stderr → logs/<name>.txt) and wait for its 120th frame.
launch() {
  local name="$1" args="$2" f t=0
  f="$OUT_ABS/logs/$name.txt"
  local was_lost="$SIM_LOST"
  sim_recover "$name"
  SIM_LOST=0; CUR_LOG="$f"; CUR_LAUNCH="$name"
  # Moves skipped while the device was lost: put the hinge where the caller wanted it.
  (( was_lost )) && [[ "$CUR" != "$WANT" ]] && { hinge_set "$WANT" || true; }
  to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  : > "$f"
  to 60 xcrun simctl launch --terminate-running-process --stdout="$f" --stderr="$f" \
    "$UDID" "$BUNDLE" -snapDemo "$args" >/dev/null 2>>"$RUNLOG" || {
      log "WARN launch $name failed, retrying"; sleep 3
      to 60 xcrun simctl launch --terminate-running-process --stdout="$f" --stderr="$f" \
        "$UDID" "$BUNDLE" -snapDemo "$args" >/dev/null 2>>"$RUNLOG" || log "WARN launch $name failed twice"
    }
  while (( t < 45 )); do grep -q "SNAP-T frame 120" "$f" 2>/dev/null && break; sleep 1; t=$((t+1)); done
  if (( t >= 45 )); then
    log "WARN $name: no 'SNAP-T frame 120' after 45 s"
    sim_booted || sim_lost "found shut down after launching '$name'"
  fi
  log "launched $name ($args) after ${t}s: $(canvas_line "$f"); input $(input_of "$f"); $(count '^SNAP-H' "$f") hinge lines, $(count 'SNAP-T trap closure' "$f") trap lines"
  sleep 2
}

# bite_once <file> <to angle> <seconds>: wiggle at $CUR, then a sweep to <to>; sets S0 (the line count before the sweep).
bite_once() {
  local from="$CUR"
  hinge_wiggle "$from" 2
  S0=$(nlines "$1")
  hinge_sweep "$2" "$3"
}

# round_open <file> <angle>: R8 (founder rule 3) a round starts closed: shut the Duo (that shut is no bite) and open it
# to <angle>, where the round opens (`SNAP-T round open`) and the bugs come. Sets ROUND_DETAIL.
ROUND_DETAIL=""
round_open() {
  local r0 rl bites
  r0=$(nlines "$1")
  hinge_sweep 5 0.5; sleep 1.5
  hinge_sweep "$2" 0.8; sleep 1.5
  rl=$(first_line "$1" "SNAP-T round open" "$r0")
  bites=$(after "$1" "$r0" | grep -c "SNAP-T event snapped")
  ROUND_DETAIL="shut, then opened to $2°: round open line@${rl:-none}; bites on the starting shut: $bites (want 0)"
}

# attempt_bad <rows file>: 0 when an attempt's rows show the rig failed (a SIMULATOR / HINGE-TOOL row, an INCONCLUSIVE
# verdict, or an INFO row recorded on a dead Duo).
attempt_bad() {
  awk -F'\t' '$1 == "SIMULATOR" || $1 == "HINGE-TOOL" || $2 == "INCONCLUSIVE" || $3 ~ /SIMULATOR DEAD/ { f = 1 } END { exit !f }' "$1"
}
# attempt_score <rows file>: how much evidence an attempt gave (PASS/FAIL verdicts and live INFO rows).
attempt_score() {
  awk -F'\t' '($2 == "PASS" || $2 == "FAIL") && $1 != "SIMULATOR" && $1 != "HINGE-TOOL" { n++ }
    $2 == "INFO" && $3 !~ /SIMULATOR DEAD/ { n++ } END { print n + 0 }' "$1"
}
# attempt_rows <rows file>: "SNAP PASS, REARM INCONCLUSIVE, …"
attempt_rows() { awk -F'\t' '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $1, $2 }' "$1"; }

# run_check <launch name> <function>: one check (its launch, moves, verdicts and frames) with whole retries. The first
# attempt runs on a fresh Duo when the launch is in FRESH_FOR; a retry always does. An attempt whose launch died is run
# again, up to CHECK_RETRIES times; the best attempt's rows go into checks.tsv and its frames and app log are put back.
run_check() {
  local name="$1" fn="$2" k=0 max=$(( CHECK_RETRIES + 1 )) best=1 bestscore=-1 score buf clean ran j s
  while (( k < max )); do
    k=$((k + 1))
    if (( k > 1 )) || [[ " $FRESH_FOR " == *" $name "* ]]; then
      fresh_device "'$name' attempt $k/$max" || log "WARN $name: no fresh Duo for attempt $k/$max; it runs on $UDID"
    fi
    buf="$OUT_ABS/logs/$name-attempt-$k.tsv"; : > "$buf"
    SINK="$buf"; ATTEMPT_SHOTS=""; HINGE_DEAD_LOGGED=0
    log "CHECK-RUN '$name' attempt $k/$max on $UDID (host load $(loadavg))"
    "$fn"
    (( SIM_LOST )) || sim_booted || sim_lost "found shut down at the end of '$name'"
    SINK="$CHECKS"
    cp "$OUT_ABS/logs/$name.txt" "$OUT_ABS/logs/$name-attempt-$k.txt" 2>/dev/null || true
    echo "$ATTEMPT_SHOTS" > "$OUT_ABS/logs/$name-attempt-$k.shots"
    for s in $ATTEMPT_SHOTS; do cp "$OUT_ABS/$s.png" "$OUT_ABS/raw/$s-attempt-$k.png" 2>/dev/null || true; done
    score=$(attempt_score "$buf")
    (( score >= bestscore )) && { best=$k; bestscore=$score; }
    clean=1; (( SIM_LOST )) && clean=0; attempt_bad "$buf" && clean=0
    if (( clean )); then log "CHECK-RUN '$name' attempt $k/$max: clean ($(attempt_rows "$buf"))"; break; fi
    if (( k < max )); then
      RERUNS=$((RERUNS + 1))
      log "CHECK-RUN '$name' attempt $k/$max: the rig failed ($(attempt_rows "$buf")); the whole check again on a new Duo"
    fi
  done
  ran=$k
  cat "$OUT_ABS/logs/$name-attempt-$best.tsv" >> "$CHECKS"
  if (( best != ran )); then
    for s in $(cat "$OUT_ABS/logs/$name-attempt-$best.shots" 2>/dev/null); do
      cp "$OUT_ABS/raw/$s-attempt-$best.png" "$OUT_ABS/$s.png" 2>/dev/null || true
    done
    cp "$OUT_ABS/logs/$name-attempt-$best.txt" "$OUT_ABS/logs/$name.txt" 2>/dev/null || true
  fi
  for (( j = 1; j <= ran; j++ )); do
    (( j == best )) && continue
    result HINGE-RETRY INFO "'$name' attempt $j/$max set aside ($(attempt_rows "$OUT_ABS/logs/$name-attempt-$j.tsv")); kept attempt $best of $ran run; rows logs/$name-attempt-$j.tsv, app log logs/$name-attempt-$j.txt"
  done
  (( ran > 1 )) && log "CHECK-RUN '$name': $ran attempts, kept $best"
  return 0
}

# ---- set-up: settle the workflow's Duo, install, probe the displays -----------------------------------------------
log "passes: $PASSES (always run in the order hinge, frames, ui, store); fresh Duo for: $FRESH_FOR; whole retries: $CHECK_RETRIES; host load $(loadavg)"
sim_settle 0 || true
install_app || { result INSTALL FAIL "simctl install failed twice"; write_summary; exit 1; }
probe_displays

# ---- pass: the hinge checks (R8, design/ROUND-8.md "Owners", design/notes/core-R8.md) ------------------------------
# Run first (R5): the hinge checks get the youngest simulator, each launch on its own freshly booted Duo.
# R8 (founder rule 3) every hinge round starts closed: after the launch the Duo is shut and opened again
# (round_open: no bite, `SNAP-T round open`), and only then do the bugs come.
BITE_CAUGHT=""   # the BITE check's caught count (SLOW-CLOSE compares with it; the same seed)

# The BITE launch: ROUND (INFO), BITE, then COVER and REOPEN on the same shut.
check_bite() {
  hinge_set 150
  launch bite "screen=play;mode=attract;seed=7"
  BL="$OUT_ABS/logs/bite.txt"
  result CANVAS INFO "$(canvas_line "$BL"); input $(input_of "$BL"); hinge lines $(count '^SNAP-H' "$BL"); trap lines $(count 'SNAP-T trap closure' "$BL"), hinge closure lines $(count 'SNAP-T hinge closure' "$BL")$(simnote)"
  round_open "$BL" 150
  result ROUND INFO "$ROUND_DETAIL$(simnote)"

  # BITE: 150 → 5 in about 0.3 s, then a snapped event with caught ≥ 1. Attract waves start 1.2 s after the round
  # opens; wait for a bug to sip (the moment a player would bite). One retry: the hinge tool sometimes under-delivers.
  if wait_for "$BL" "SNAP-T event bugSipping" 40; then sip="a bug was sipping"; else sip="no bugSipping in 40 s (bit anyway)"; fi
  attempt=1; sl=""; minA=none
  while :; do
    bite_once "$BL" 5 0.3
    sleep 1.5
    sl=$(first_line "$BL" "SNAP-T event snapped" "$S0")
    minA=$(after "$BL" "$S0" | trap_vals angle | min_of)
    log "BITE attempt $attempt: snapped@${sl:-none}; logged min angle ${minA}°"
    [[ -n "$sl" ]] && break
    (( attempt >= 2 )) && break
    attempt=2
    hinge_sweep 150 1.0; sleep 1.5; wait_for "$BL" "SNAP-T event bugSipping" 10 || true
  done
  snapline=$( [[ -n "$sl" ]] && sed -n "${sl}p" "$BL" | tr -d '\r' )
  BITE_CAUGHT=$(grep -oE 'caught=[0-9]+' <<<"$snapline" | head -1 | cut -d= -f2)
  shutl=$(first_line "$BL" "SNAP-T shut " "$S0")
  d="attempt $attempt/2; $sip; input=$(input_of "$BL"); ${snapline:-no snapped line}; shut line: $( [[ -n "$shutl" ]] && sed -n "${shutl}p" "$BL" | tr -d '\r' || echo none); min angle ${minA}°"
  if [[ -n "$sl" && "${BITE_CAUGHT:-0}" -ge 1 ]]; then verdict BITE PASS "$d"
  elif [[ -n "$sl" ]]; then verdict BITE FAIL "$d (a bite, but nothing caught)"
  elif [[ "$minA" == none ]] || ! lt "$minA" 40; then
    verdict BITE INCONCLUSIVE "$d (the app never logged an angle under 40°: the hinge tool under-delivered the sweep, or no trap lines)"
  else verdict BITE FAIL "$d (the app saw the shut but did not bite)"; fi

  # COVER: a screenshot while shut (the cover display's CHOMP card). The shot (~15 s) also makes the shut long.
  shoot duo-h1-cover-shut cover
  cb=$(brightness "$OUT_ABS/raw/duo-h1-cover-shut-cover.png")
  d="cover panel brightness ${cb} (inner $(brightness "$OUT_ABS/raw/duo-h1-cover-shut-inner.png")); hinge ${CUR}°"
  if [[ "$cb" =~ ^[0-9]+$ ]] && (( cb > 6 )); then verdict COVER PASS "$d"; else verdict COVER FAIL "$d (the cover panel was dark or not captured)"; fi

  # REOPEN: rearmed after the reopen, and the clock frozen while shut (no wave started and no bug arrived between the
  # bite and the re-arm, over the ~15 s shut; attract waves come every 3–4.5 s).
  hinge_sweep 150 0.8; sleep 2
  if [[ -n "$sl" ]]; then
    rl=$(first_line "$BL" "SNAP-T event rearmed" "$sl")
    ro=$(first_line "$BL" "SNAP-T reopened" "$sl")
    frozen="?"
    [[ -n "$rl" ]] && frozen=$(between "$BL" "$sl" "$rl" | grep -cE "SNAP-T event (waveStarted|bugArrived)")
    d="rearmed@${rl:-none} (snapped@$sl); reopened line@${ro:-none}; waves/arrivals while shut: ${frozen}; armed after the reopen: $(after "$BL" "${rl:-$sl}" | trap_vals armed | tail -1)"
    if [[ -n "$rl" && "$frozen" == 0 ]]; then verdict REOPEN PASS "$d"
    elif [[ -n "$rl" ]]; then verdict REOPEN FAIL "$d (the clock ran while shut)"
    else verdict REOPEN FAIL "$d (never rearmed)"; fi
  else
    verdict REOPEN INCONCLUSIVE "no bite to reopen from; rearmed lines in the run: $(count 'SNAP-T event rearmed' "$BL")"
  fi
  shoot "duo-h2-reopened-150" inner
}

# SLOW-CLOSE (its own fresh launch, the same seed): 150 → 5 over 2.5 s. PASS: fewer caught than BITE's fast close,
# or escapes ≥ 1 (the flies fled the slow close).
check_slow() {
  hinge_set 150
  launch slow-close "screen=play;mode=attract;seed=7"
  SL="$OUT_ABS/logs/slow-close.txt"
  round_open "$SL" 150
  if wait_for "$SL" "SNAP-T event bugSipping" 40; then sip="a bug was sipping"; else sip="no bugSipping in 40 s"; fi
  hinge_wiggle 150 2
  c0=$(nlines "$SL")
  hinge_sweep 5 2.5 whole; sleep 1.5
  c1=$(nlines "$SL")
  sl=$(first_line "$SL" "SNAP-T event snapped" "$c0")
  snapline=$( [[ -n "$sl" ]] && sed -n "${sl}p" "$SL" | tr -d '\r' )
  caught=$(grep -oE 'caught=[0-9]+' <<<"$snapline" | head -1 | cut -d= -f2)
  esc=$(grep -oE 'escaped=[0-9]+' <<<"$snapline" | head -1 | cut -d= -f2)
  spooked=$(between "$SL" "$c0" "$c1" | grep -c "SNAP-T event bugSpooked")
  slowc=$(between "$SL" "$c0" "$c1" | trap_vals creep | grep -c '^1$')
  d="$sip; ${snapline:-no snapped line}; fled the close (bugSpooked) $spooked; slow-close (creep 1) lines $slowc; the fast close caught ${BITE_CAUGHT:-?}"
  if [[ -z "$sl" ]]; then
    minA=$(between "$SL" "$c0" "$c1" | trap_vals angle | min_of)
    if [[ "$minA" == none ]] || ! lt "$minA" 40; then verdict SLOW-CLOSE INCONCLUSIVE "$d (no angle under 40° logged)"
    else verdict SLOW-CLOSE FAIL "$d (shut, but no bite)"; fi
  elif (( ${esc:-0} >= 1 )) || { [[ -n "$BITE_CAUGHT" ]] && (( ${caught:-0} < BITE_CAUGHT )); }; then
    verdict SLOW-CLOSE PASS "$d"
  else verdict SLOW-CLOSE FAIL "$d (a slow close lost nothing)"; fi
  hinge_sweep 150 1.0; sleep 1
}

# NO-BITE-DEEP (its own fresh launch): 150 → 60 → 150. PASS: no snapped event, however deep the partial close.
check_nobite() {
  hinge_set 150
  launch no-bite-deep "screen=play;mode=attract;seed=7"
  NL="$OUT_ABS/logs/no-bite-deep.txt"
  round_open "$NL" 150
  wait_for "$NL" "SNAP-T event bugSipping" 30 || log "WARN no-bite-deep: no bugSipping in 30 s (closing anyway)"
  hinge_wiggle 150 2
  n0=$(nlines "$NL")
  hinge_sweep 60 0.5; sleep 1.2
  hinge_sweep 150 0.6; sleep 1.5
  n1=$(nlines "$NL")
  nsl=$(first_line "$NL" "SNAP-T event snapped" "$n0"); [[ -n "$nsl" && "$nsl" -gt "$n1" ]] && nsl=""
  minA=$(between "$NL" "$n0" "$n1" | trap_vals angle | min_of)
  maxc=$(between "$NL" "$n0" "$n1" | trap_vals closure | max_of)
  d="snapped in the window: ${nsl:-none}; min angle ${minA}°, max closure ${maxc}°; fled (bugSpooked) $(between "$NL" "$n0" "$n1" | grep -c 'SNAP-T event bugSpooked')"
  if [[ -n "$nsl" ]]; then verdict NO-BITE-DEEP FAIL "$d ($(sed -n "${nsl}p" "$NL" | tr -d '\r'))"
  elif [[ "$minA" == none ]] || ! lt "$minA" 100; then verdict NO-BITE-DEEP INCONCLUSIVE "$d (the close never logged under 100°)"
  else verdict NO-BITE-DEEP PASS "$d"; fi
}

if [[ " $PASSES " == *" hinge "* ]]; then
  run_check bite check_bite
  run_check slow-close check_slow
  run_check no-bite-deep check_nobite
fi

# ---- pass: the book-pose frames (open 165, half closed 150, snapped 130, cover shut, reopened, portrait) ----------
if [[ " $PASSES " == *" frames "* ]]; then
  # Attract runs on the real hinge (no pilot: the hinge drives the jaws; snaps never run out).
  hinge_set 165
  launch frames-open "screen=play;mode=attract;seed=7"
  round_open "$OUT_ABS/logs/frames-open.txt" 165
  sleep 3; shoot duo-01-open-165 inner
  # The drawn closure is relative to the player's own rest angle (it falls back to 0 within ~1 s of any still hold,
  # and a shot takes ~15 s), so the half-closed frame holds the jaws at 11° (half the 22° snap) with `closure=11`,
  # with the real hinge at 150° under it.
  hinge_sweep 150 2
  launch frames-half "screen=play;mode=attract;seed=7;closure=11"
  sleep 2; shoot duo-02-half-150 inner
  # The bite itself (R8: at the shut, so the cover panel): `freezeOn=snap` stops the session 0.12 s after the bite,
  # and the panels are shot once `SNAP-T freeze snap` is logged. R5: a hinge launch, so on a fresh Duo with
  # whole retries (run 40634483657 lost it to a hung hinge call).
  frame_snap() {
    hinge_set 160
    launch frames-snap "screen=play;mode=attract;seed=7;freezeOn=snap"
    FS="$OUT_ABS/logs/frames-snap.txt"
    wait_for "$FS" "SNAP-T event bugSipping" 40 || log "WARN frames-snap: no bugSipping in 40 s (snapping anyway)"
    round_open "$FS" 160
    wait_for "$FS" "SNAP-T event bugSipping" 30 || log "WARN frames-snap: no bugSipping after the round opened"
    bite_once "$FS" 5 0.3
    if wait_for "$FS" "SNAP-T freeze snap" 3; then fz="froze on the snap"; else fz="no 'SNAP-T freeze snap' within 3 s"; fi
    shoot duo-03-bite-shut cover
    result FRAME-SNAP INFO "$fz; $(grep -m1 -E 'SNAP-T event snapped' "$FS" | tr -d '\r' || echo 'no snapped line')$(simnote)"
  }
  run_check frames-snap frame_snap
  # Shut (the cover display) and reopened, on a live (unfrozen) run.
  hinge_set 160
  launch frames-cover "screen=play;mode=attract;seed=7"
  FC="$OUT_ABS/logs/frames-cover.txt"
  round_open "$FC" 160
  hinge_sweep 60 1.5; hinge_sweep 10 0.6; hinge_set 0; sleep 3; shoot duo-04-cover-shut cover
  o0=$(nlines "$FC")
  hinge_sweep 165 2.5; sleep 3; shoot duo-05-reopened-165 inner
  result SHUT-FRAMES INFO "bites $(count 'SNAP-T event snapped' "$FC"); shut lines $(count 'SNAP-T shut ' "$FC"); rearmed after the reopen: $(first_line "$FC" "SNAP-T event rearmed" "$o0" | grep . || echo none); $(canvas_line "$FC")$(simnote)"
  # R8b: portrait plays (no pose card). The Duo sim stays in book pose (no CLI rotate), so `screen=pose` lays the app
  # out at the turned canvas over Home; the PNG comes out turned and reads after `sips -r 90`. Want `turned=1`.
  launch frames-pose "screen=pose"
  sleep 2; shoot duo-06-portrait inner
  result PORTRAIT INFO "frame $(png_wh "$OUT_ABS/duo-06-portrait.png"); $(canvas_line "$OUT_ABS/logs/frames-pose.txt")$(simnote)"
fi

# ---- pass: UI frames -----------------------------------------------------------------------------------------------
if [[ " $PASSES " == *" ui "* ]]; then
  hinge_set 160 || true
  launch ui-home "screen=home;progress=mid"; shoot duo-ui-home-160 inner
  # R8 (app-R8.md): the lesson is gone; Levels 1–5 teach. The level map, a level's intro card, a level's results.
  launch ui-levels "screen=levels;progress=mid"; sleep 2; shoot duo-ui-levels inner
  launch ui-level-intro "screen=levelIntro;level=1"; sleep 2; shoot duo-ui-level-intro-1 inner
  launch ui-level-results "screen=levelResults;level=1;pilot=perfect"
  wait_for "$OUT_ABS/logs/ui-level-results.txt" "SNAP-T level result " 60 || log "WARN ui-level-results: no 'SNAP-T level result' in 60 s"
  sleep 2; shoot duo-ui-level-results-1 inner
  result LEVEL-RESULT INFO "$(grep -m1 'SNAP-T level result ' "$OUT_ABS/logs/ui-level-results.txt" | tr -d '\r' | grep . || echo 'no level result line')$(simnote)"
  # R8 (founder rule 3): "Close the phone to start": a hinge round launched with the Duo open waits for the shut.
  close_start() {
    hinge_set 160 || true
    launch ui-close-to-start "screen=play;mode=attract;seed=7"
    CS="$OUT_ABS/logs/ui-close-to-start.txt"
    sleep 3; shoot duo-ui-close-to-start-160 inner
    result CLOSE-TO-START INFO "waves before the first shut: $(count 'SNAP-T event waveStarted' "$CS") (want 0); input $(input_of "$CS")$(simnote)"
    # Then shut and open: the round starts.
    round_open "$CS" 160
    sleep 2; shoot duo-ui-round-open-160 inner
    result ROUND-OPEN INFO "$ROUND_DETAIL; waves after it opened: $(count 'SNAP-T event waveStarted' "$CS")$(simnote)"
  }
  run_check ui-close-to-start close_start
  hinge_set 160 || true
  launch ui-results "screen=results;seed=7;progress=mid;pilot=casual"; sleep 3; shoot duo-ui-results inner
  launch ui-book "screen=book;progress=late"; sleep 2; shoot duo-ui-book inner
  launch ui-settings "screen=settings"; sleep 2; shoot duo-ui-settings inner
  # R8 (founder rule 2): no pose demands: a flat Duo plays like any other angle.
  hinge_set 178 || true
  launch ui-flat "screen=play;mode=attract;seed=7"; round_open "$OUT_ABS/logs/ui-flat.txt" 178; sleep 2; shoot duo-ui-flat-178 inner
  hinge_sweep 160 1.5
  # R8: the outer display's CHOMP card (app-R8.md `screen=chomp`), the Duo shut.
  launch ui-chomp "screen=chomp;chomp=catch"
  hinge_sweep 60 1.5; hinge_sweep 10 0.6; hinge_set 0 || true; sleep 3; shoot duo-ui-chomp-card cover
  result CHOMP-CARD INFO "$(grep -m1 'SNAP-T chomp card' "$OUT_ABS/logs/ui-chomp.txt" | tr -d '\r' | grep . || echo 'no chomp card line')$(simnote)"
  hinge_sweep 165 1.5; sleep 2
  launch ui-cover "screen=home;progress=mid"
  hinge_sweep 40 1.5; hinge_set 0; sleep 3; shoot duo-ui-cover cover
  hinge_set 160 || true
fi

# ---- pass: the App Store Duo set (ci/duo-scenarios.txt) ------------------------------------------------------------
# One book-pose launch per line of STORE_LIST (name|demo args|wait|caption|expect), the hinge held at STORE_ANGLE (150°:
# open; the pilot drives the trap itself, and a hinge round without a pilot waits for its first shut: R8). A freezeOn= line waits for "SNAP-T freeze <tag>" (at
# least `wait`, at least 20 s), a freezeAfter= line for any "SNAP-T freeze" line, then 2 s for the held frame; others
# wait `wait` s. Writes store-<name>.png (the lit panel) and logs/store-<name>.at-capture.txt (the log at capture).
# R5 CI-only keys (stripped before launch): `ciHinge=<deg>` moves the hinge there after the launch (under 30°: closed
# as frames-cover does, and the cover panel is shot); `ciShootOn=<event>` shoots the inner panel CI_SHOOT_DELAY s after
# `SNAP-T event <event>` on a live run (no freeze): the trap open again after the bite, not the hold (REVIEW-4 #15).
if [[ " $PASSES " == *" store "* ]]; then
  LIST="${STORE_LIST:-ci/duo-scenarios.txt}"
  SANGLE="${STORE_ANGLE:-150}"
  [[ -f "$LIST" ]] || log "WARN store list $LIST not found"
  [[ -f "$LIST" ]] && while IFS='|' read -r -u 3 name args wait _caption _expect _rest; do
    name="${name%$'\r'}"; args="${args%$'\r'}"; wait="${wait%$'\r'}"
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ "$name" =~ ${STORE_FILTER:-.} ]] || continue
    wait="${wait%%.*}"; [[ "$wait" =~ ^[0-9]+$ ]] || wait=6
    ang="$SANGLE"; [[ "$args" =~ (^|;)ciHinge=([0-9]+) ]] && ang="${BASH_REMATCH[2]}"
    shot_on=""; [[ "$args" =~ (^|;)ciShootOn=([A-Za-z]+) ]] && shot_on="${BASH_REMATCH[2]}"
    app_args=$(sed -E 's/(^|;)ci(Hinge|ShootOn)=[^;]*//g; s/^;//' <<< "$args")
    panel=inner
    hinge_set "$SANGLE" || true
    launch "store-$name" "$app_args"
    SF="$OUT_ABS/logs/store-$name.txt"
    lim=$(( wait > 20 ? wait : 20 ))
    if (( ang < 30 )); then
      # The cover display: closed as frames-cover does (iOS hands over somewhere between ~60° and ~20°).
      hinge_sweep 60 1.5; hinge_sweep 10 0.6; hinge_set "$ang" || true; sleep 3; panel=cover
    elif (( ang != SANGLE )); then
      hinge_sweep "$ang" 1.0; sleep 2
    fi
    if [[ -n "$shot_on" ]]; then
      if wait_for "$SF" "SNAP-T event $shot_on( |\$)" "$lim"; then
        sleep "$CI_SHOOT_DELAY"; shoot_now "store-$name"
        log "store-$name: shot ${CI_SHOOT_DELAY} s after '$(grep -m1 -E "SNAP-T event $shot_on( |\$)" "$SF" | tr -d '\r')' (live, unfrozen)"
      else
        log "WARN store-$name: no 'SNAP-T event $shot_on' in ${lim} s (shooting anyway)"; shoot "store-$name" "$panel"
      fi
      cp "$SF" "$OUT_ABS/logs/store-$name.at-capture.txt" 2>/dev/null || true
      continue
    fi
    if [[ "$args" =~ freezeOn=([A-Za-z]+) ]]; then
      tag="${BASH_REMATCH[1]}"
      if wait_for "$SF" "SNAP-T freeze $tag" "$lim"; then sleep 2; else log "WARN store-$name: no 'SNAP-T freeze $tag' in ${lim} s (shooting anyway)"; fi
    elif [[ "$args" == *freezeAfter=* ]]; then
      if wait_for "$SF" "SNAP-T freeze" "$lim"; then sleep 2; else log "WARN store-$name: no 'SNAP-T freeze' in ${lim} s"; fi
    else
      sleep "$wait"
    fi
    shoot "store-$name" "$panel"
    cp "$SF" "$OUT_ABS/logs/store-$name.at-capture.txt" 2>/dev/null || true
    # Back open after a cover shot: the cover stays lit up to ~150° on a reopen, so via 165°.
    [[ "$panel" == cover ]] && { hinge_sweep 165 1.5; sleep 2; }
  done 3< "$LIST"
fi

ls -la "$OUT_ABS" | tee -a "$RUNLOG" >&2
(( SIM_LOST )) || sim_booted || sim_lost "found shut down at the end of the run"
result RIG INFO "hinge calls failed: $HINGE_ERRS (last: ${HINGE_LAST:-none}); simulator deaths: $SIM_DEATHS; timed-out calls sent again: $HINGE_RETRIES; fresh Duos: $FRESH_N; checks run again: $RERUNS; host load $(loadavg)"
log "checks: $(awk -F'\t' '$2=="PASS"' "$CHECKS" | wc -l | tr -d ' ') PASS, $(awk -F'\t' '$2=="FAIL"' "$CHECKS" | wc -l | tr -d ' ') FAIL, $(awk -F'\t' '$2=="INCONCLUSIVE"' "$CHECKS" | wc -l | tr -d ' ') INCONCLUSIVE"
grep -E $'\t(PASS|FAIL|INCONCLUSIVE)\t' "$CHECKS" | awk -F'\t' '{ printf "%s %s (%s)\n", $1, $2, $3 }' || true
write_summary
if [[ "$STRICT" == 1 ]] && grep -q $'\tFAIL\t' "$CHECKS"; then exit 1; fi
exit 0
