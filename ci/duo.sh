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
# Hinge checks (design/ROUND-1.md "CI engineer"), each a "<CHECK> PASS|FAIL|INCONCLUSIVE|INFO (detail)" line in
# logs/run.txt, a row in checks.tsv and in the job summary:
#  1. SNAP: launch `screen=play;mode=attract;seed=7` at 160°, wait for `SNAP-T event bugSipping`, sweep 160 → 128 in
#     0.15 s. PASS: `SNAP-T event snapped` within 1 s (lines logged since the sweep began, read 1 s after it returns).
#  2. CREEP: re-open to 160, then sweep 160 → 128 over 3 s. PASS: no `snapped` before the closure reached 22° (the
#     logged closure around any snapped line, 2° tolerance for the 10 Hz trap lines) and a `SNAP-T trap … creep 1`.
#  3. REARM: after the snap, sweep back to 160. PASS: `SNAP-T event rearmed` after the snapped line.
#  4. CLOSE-PAUSE: sweep to 40 → `SNAP-T paused closing`; sweep back to 150 → `SNAP-T resumed` (on to 165° if the
#     cover display is still lit and nothing resumed).
#  5. Frames: open 165, half closed 150, snapped 130, the cover display shut, reopened 165, and the pose card.
# INFO rows (evidence, never a verdict): CANVAS, CREEP-FAST (the same close over 1.5 s), NO-PAUSE-95 (a hard snap that
# reaches 95° must never pause: Never put a pause near 90°, CLAUDE.md).
# Rig rows (design/notes/duo-ci-R3.md): SIMULATOR FAIL when the Duo shut down mid-run (then rebooted before the next
# launch; that launch's checks are INCONCLUSIVE), HINGE-TOOL FAIL when the hinge CLI keeps failing on a booted Duo, and
# RIG INFO (failed hinge calls, simulator deaths).
#
# Env: UDID (required), OUT (duo-screens), PASSES ("hinge frames ui store"), STRICT (1 = exit 1 when a check FAILs;
# default 0: the frames and the PASS/FAIL table are the evidence), STORE_LIST / STORE_FILTER / STORE_ANGLE (the store
# pass, ci/duo-scenarios.txt at 150°).
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
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$CHECKS"
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

INNER=""; COVER=""
to 300 xcrun simctl install "$UDID" "$APP" || {
  log "install failed, retrying"; sleep 5
  to 300 xcrun simctl install "$UDID" "$APP" || { result INSTALL FAIL "simctl install failed twice"; write_summary; exit 1; }
}

for c in LCD-1 primary-1 3 internal; do
  to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { INNER="$c"; break; }
done
for c in LCD primary 1 external; do
  [[ "$c" == "$INNER" ]] && continue
  to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>>"$RUNLOG" && { COVER="$c"; break; }
done
rm -f "$OUT_ABS/raw/_p.png"
log "displays inner=$INNER cover=$COVER"

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

# sim_booted: 0 when CoreSimulator still lists the Duo as Booted.
sim_booted() { to 20 xcrun simctl list devices 2>/dev/null | grep -F "$UDID" | grep -q "(Booted)"; }

# sim_diag <file>: what the host knows about the device's death (device list, the app's last lines, the device's own
# system.log, CoreSimulator's log, fresh crash reports).
sim_diag() {
  local f="$1" crash="$OUT_ABS/logs/crash-$SIM_DEATHS"
  {
    echo "== $(date -u +%FT%TZ) SIM-DEAD during launch '${CUR_LAUNCH:-none}' (hinge ${CUR}°, last hinge failure: ${HINGE_LAST:-none})"
    echo "== simctl list devices"; to 20 xcrun simctl list devices 2>&1
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

# sim_recover: before a launch, reboot a dead device (boot, bootstatus, re-warm the hinge helper, re-apply the wanted
# angle). Stops the script when it cannot be rebooted: nothing after that would be evidence.
sim_recover() {
  sim_booted && return 0
  sim_lost "found shut down before launch '$1'"
  log "SIM: rebooting the Duo"
  to 120 xcrun simctl boot "$UDID" >>"$RUNLOG" 2>&1 || true
  if ! to 600 xcrun simctl bootstatus "$UDID" -b >>"$RUNLOG" 2>&1 || ! sim_booted; then
    result SIMULATOR FAIL "the Duo could not be rebooted after shutting down; stopped before launch '$1'"
    write_summary; exit 1
  fi
  (( HAVE_HINGE )) && { to 120 hinge -d "$UDID" get >>"$RUNLOG" 2>&1 || log "WARN hinge get after the reboot failed"; }
  log "SIM: rebooted; re-applying ${WANT}°"
  SIM_LOST=0; HINGE_RUN=0; CUR=180
  hinge_set "$WANT" || true
}

# hinge_call <timeout s> <args…>: one hinge invocation (its output → the run log, via a file: a lingering helper can't
# hold a pipe open). On failure: the exit code (124/137/142 = our timeout) and the tool's last message, then either
# SIM-DEAD (the device is gone) or, after 5 failures in a row on a booted device, one HINGE-TOOL FAIL row.
hinge_call() {
  local s="$1" tmp="$OUT_ABS/raw/_hinge.txt" rc why msg; shift
  to "$s" hinge -d "$UDID" "$@" > "$tmp" 2>&1; rc=$?
  cat "$tmp" >> "$RUNLOG" 2>/dev/null
  if (( rc == 0 )); then HINGE_RUN=0; rm -f "$tmp"; return 0; fi
  HINGE_ERRS=$((HINGE_ERRS + 1)); HINGE_RUN=$((HINGE_RUN + 1))
  case "$rc" in 124|137|142) why="timed out after ${s}s (exit $rc)";; *) why="exit $rc";; esac
  msg=$(grep . "$tmp" 2>/dev/null | tail -1 | tr -d '\r' | tr '\t' ' ' | cut -c1-160); rm -f "$tmp"
  HINGE_LAST="hinge $*: $why${msg:+: $msg}"
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
    hinge_call 20 -t 3 "$1" && { CUR="$1"; return 0; }
    (( SIM_LOST )) && break
    sleep 1
  done
  log "WARN hinge set $1 failed (${HINGE_LAST:-no message})"; return 1
}
hinge_sweep() {   # hinge_sweep <to> <seconds>: continuous 60 Hz stream so the app sees a real motion
  WANT="$1"
  (( HAVE_HINGE )) || return 1
  (( SIM_LOST )) && return 1   # CUR keeps the last angle really set
  hinge_call $(( ${2%.*} + 20 )) sweep "$CUR" "$1" "$2" || log "WARN sweep $CUR -> $1 failed (${HINGE_LAST:-no message})"
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

# snap_once <file> <to angle>: wiggle at $CUR, then a 0.15 s sweep to <to>; sets S0 (the line count before the sweep).
snap_once() {
  local from="$CUR"
  hinge_wiggle "$from" 2
  S0=$(nlines "$1")
  hinge_sweep "$2" 0.15
}

# ---- pass: the hinge checks (design/ROUND-1.md, CI engineer) ---------------------------------------------------
if [[ " $PASSES " == *" hinge "* ]]; then
  hinge_set 160
  launch hinge "screen=play;mode=attract;seed=7"
  HL="$OUT_ABS/logs/hinge.txt"
  result CANVAS INFO "$(canvas_line "$HL"); input $(input_of "$HL"); hinge lines $(count '^SNAP-H' "$HL"); trap lines $(count 'SNAP-T trap closure' "$HL"), hinge closure lines $(count 'SNAP-T hinge closure' "$HL")$(simnote)"

  # 1. SNAP. Attract waves start at 1.2 s; wait for a bug to sip (the moment a player would bite).
  if wait_for "$HL" "SNAP-T event bugSipping" 40; then sip="a bug was sipping"; else sip="no bugSipping in 40 s (snapped anyway)"; fi
  attempt=1; sl=""; minA=none; maxc=none
  while :; do
    snap_once "$HL" 128
    sleep 1
    sl=$(first_line "$HL" "SNAP-T event snapped" "$S0")
    minA=$(after "$HL" "$S0" | trap_vals angle | min_of)
    maxc=$(after "$HL" "$S0" | trap_vals closure | max_of)
    log "SNAP attempt $attempt: snapped@${sl:-none}; logged min angle ${minA}°, max closure ${maxc}°"
    [[ -n "$sl" ]] && break
    (( attempt >= 2 )) && break
    attempt=2
    # Re-open (which also re-arms: θ ≥ 150) and try once more: the hinge tool sometimes under-delivers a fast sweep.
    hinge_sweep 160 1.0; sleep 1.5
  done
  inp=$(input_of "$HL")
  snapline=$( [[ -n "$sl" ]] && sed -n "${sl}p" "$HL" | tr -d '\r' )
  d="attempt $attempt/2; $sip; input=${inp:-none}; ${snapline:-no snapped line}; min angle ${minA}°, max closure ${maxc}°"
  if [[ -n "$sl" ]]; then verdict SNAP PASS "$d"
  elif [[ "$minA" == none ]] || ! lt "$minA" 135; then
    verdict SNAP INCONCLUSIVE "$d (the app never logged an angle under 135°: the hinge tool under-delivered the sweep, or no trap lines)"
  else verdict SNAP FAIL "$d (the app saw the close but did not snap)"; fi
  shoot_now duo-h1-snapped-128

  # 3. REARM (ROUND-1 lists it after CREEP; it is the re-open that CREEP starts with). After the snap, back to 160.
  r0=$(nlines "$HL")
  hinge_sweep 160 0.6; sleep 1.5
  if [[ -n "$sl" ]]; then
    rl=$(first_line "$HL" "SNAP-T event rearmed" "$sl")
    d="rearmed@${rl:-none} (snapped@$sl); armed after the re-open: $(after "$HL" "$r0" | trap_vals armed | tail -1)"
    if [[ -n "$rl" ]]; then verdict REARM PASS "$d"; else verdict REARM FAIL "$d"; fi
  else
    verdict REARM INCONCLUSIVE "no snap to re-arm from; rearmed lines in the run: $(count 'SNAP-T event rearmed' "$HL")"
  fi

  # 2. CREEP: from 160 (the rest reference settles over 0.6 s; the wiggles keep samples flowing), 160 → 128 over 3 s
  #    (~10.7°/s). The 0.6 s rest window absorbs part of a slow close, so the logged closure should sit around 6–7°
  #    (over the 6° creep depth) and never reach 22°. The max closure is in the detail for exactly that reason.
  hinge_wiggle 160 2
  c0=$(nlines "$HL")
  hinge_sweep 128 3; sleep 1
  c1=$(nlines "$HL")
  creeps=$(between "$HL" "$c0" "$c1" | trap_vals creep | grep -c '^1$')
  cmax=$(between "$HL" "$c0" "$c1" | trap_vals closure | max_of)
  spooked=$(between "$HL" "$c0" "$c1" | grep -c "SNAP-T event bugSpooked")
  csl=$(first_line "$HL" "SNAP-T event snapped" "$c0"); [[ -n "$csl" && "$csl" -gt "$c1" ]] && csl=""
  early=""
  if [[ -n "$csl" ]]; then
    cb=$(closure_before "$HL" "$csl"); ca=$(closure_after "$HL" "$csl")
    near=$(printf '%s\n%s\n' "$cb" "$ca" | max_of)
    { [[ "$near" == none ]] || lt "$near" 20; } && early="snapped@$csl at closure ~${near}° (before ${cb}, after ${ca})"
  fi
  d="creep-1 lines=$creeps; max closure ${cmax}°; spooked=$spooked; snapped in the window: ${csl:-none}${early:+; EARLY: $early}"
  if (( creeps > 0 )) && [[ -z "$early" ]]; then verdict CREEP PASS "$d"; else verdict CREEP FAIL "$d"; fi
  # CREEP-FAST (INFO): the same close over 1.5 s (~21°/s, still under the reference's 25°/s fall), closure ~13°.
  hinge_sweep 160 1.0; sleep 1.5; hinge_wiggle 160 1
  f0=$(nlines "$HL")
  hinge_sweep 128 1.5; sleep 1
  f1=$(nlines "$HL")
  fsl=$(first_line "$HL" "SNAP-T event snapped" "$f0"); [[ -n "$fsl" && "$fsl" -gt "$f1" ]] && fsl=""
  result CREEP-FAST INFO "160 → 128 over 1.5 s: creep-1 lines=$(between "$HL" "$f0" "$f1" | trap_vals creep | grep -c '^1$'); max closure $(between "$HL" "$f0" "$f1" | trap_vals closure | max_of)°; snapped: ${fsl:-none}$(simnote)"
  hinge_sweep 160 1.0; sleep 1

  # 4. CLOSE-PAUSE (fresh launch at 150). First NO-PAUSE-95 (INFO): a hard snap often reaches 90–100° on hardware and
  #    must never pause (the closing gate is θ < 50° for 0.6 s). Then on down to 40° → `paused closing`; back to 150
  #    → `resumed`.
  hinge_set 150
  launch close-pause "screen=play;mode=attract;seed=7"
  CP="$OUT_ABS/logs/close-pause.txt"
  n0=$(nlines "$CP")
  hinge_sweep 95 0.4; sleep 1.5
  n1=$(nlines "$CP")
  np=$(first_line "$CP" "SNAP-T paused" "$n0"); [[ -n "$np" && "$np" -gt "$n1" ]] && np=""
  result NO-PAUSE-95 INFO "held 95° for 1.5 s: $( [[ -n "$np" ]] && echo "PAUSED at line $np: $(sed -n "${np}p" "$CP" | tr -d '\r')" || echo "no pause" ); last angle $(angle_before "$CP" $(( n1 + 1 )))°$(simnote)"
  hinge_sweep 150 1.0; sleep 1.5
  p0=$(nlines "$CP")
  hinge_sweep 40 1.5; sleep 1.5
  p=$(first_line "$CP" "SNAP-T paused closing" "$p0")
  other=$(after "$CP" "$p0" | grep -m1 -oE "SNAP-T paused [a-zA-Z]+" | tr -d '\r')
  shoot duo-h3-closing-40 inner
  # A pause line can land in the log after the wait (sister duo run 40510297922), so look again after the shot (still
  # before the reopen).
  [[ -z "$p" ]] && p=$(first_line "$CP" "SNAP-T paused closing" "$p0")
  [[ -z "$other" ]] && other=$(after "$CP" "$p0" | grep -m1 -oE "SNAP-T paused [a-zA-Z]+" | tr -d '\r')
  went=150
  hinge_sweep 150 1.5; sleep 2
  r=""; [[ -n "$p" ]] && r=$(first_line "$CP" "SNAP-T resumed" "$p")
  if [[ -n "$p" && -z "$r" ]]; then
    # The cover display can stay lit up to ~150° on a reopen; go on to 165° (the known relight) and look again.
    went=165; hinge_sweep 165 1; sleep 3
    r=$(first_line "$CP" "SNAP-T resumed" "$p")
  fi
  d="paused@${p:-none} ($( [[ -n "$p" ]] && angle_before "$CP" "$p" || echo -)°; first pause line: ${other:-none}); reopened to ${went}°; resumed@${r:-none} ($( [[ -n "$r" ]] && angle_before "$CP" "$r" || echo -)°); $(canvas_line "$CP")"
  if [[ -n "$p" && -n "$r" ]]; then verdict CLOSE-PAUSE PASS "$d"; else verdict CLOSE-PAUSE FAIL "$d"; fi
  shoot "duo-h4-resumed-$went" inner
fi

# ---- pass: the book-pose frames (open 165, half closed 150, snapped 130, cover shut, reopened, pose card) ---------
if [[ " $PASSES " == *" frames "* ]]; then
  # Attract runs on the real hinge (no pilot: the hinge drives the jaws; snaps never run out).
  hinge_set 165
  launch frames-open "screen=play;mode=attract;seed=7"
  sleep 3; shoot duo-01-open-165 inner
  # The drawn closure is relative to the player's own rest angle (it falls back to 0 within ~1 s of any still hold,
  # and a shot takes ~15 s), so the half-closed frame holds the jaws at 11° (half the 22° snap) with `closure=11`,
  # with the real hinge at 150° under it.
  hinge_sweep 150 2
  launch frames-half "screen=play;mode=attract;seed=7;closure=11"
  sleep 2; shoot duo-02-half-150 inner
  # The bite itself: `freezeOn=snap` stops the session 0.12 s after the bite (the scene keeps drawing the jaw slam),
  # and the inner panel is shot the moment `SNAP-T freeze snap` is logged.
  hinge_set 160
  launch frames-snap "screen=play;mode=attract;seed=7;freezeOn=snap"
  FS="$OUT_ABS/logs/frames-snap.txt"
  wait_for "$FS" "SNAP-T event bugSipping" 40 || log "WARN frames-snap: no bugSipping in 40 s (snapping anyway)"
  snap_once "$FS" 130
  if wait_for "$FS" "SNAP-T freeze snap" 3; then fz="froze on the snap"; else fz="no 'SNAP-T freeze snap' within 3 s"; fi
  shoot_now duo-03-snapped-130
  result FRAME-SNAP INFO "$fz; $(grep -m1 -E 'SNAP-T event snapped' "$FS" | tr -d '\r' || echo 'no snapped line')$(simnote)"
  # Shut (the cover display) and reopened, on a live (unfrozen) run.
  hinge_set 160
  launch frames-cover "screen=play;mode=attract;seed=7"
  FC="$OUT_ABS/logs/frames-cover.txt"
  hinge_sweep 60 1.5; hinge_sweep 10 0.6; hinge_set 0; sleep 3; shoot duo-04-cover-shut cover
  o0=$(nlines "$FC")
  hinge_sweep 165 2.5; sleep 3; shoot duo-05-reopened-165 inner
  result COVER INFO "paused lines=$(count 'SNAP-T paused' "$FC"); resumed after the reopen: $(first_line "$FC" "SNAP-T resumed" "$o0" | grep . || echo none); $(canvas_line "$FC")$(simnote)"
  # The pose card ("Hold it open like a book"). The Duo sim stays in book pose (no CLI rotate), so the card is shown
  # with `screen=pose`; a real portrait frame needs the app's own orientation request (none in R1).
  launch frames-pose "screen=pose"
  sleep 2; shoot duo-06-pose-card inner
  result POSE-CARD INFO "frame $(png_wh "$OUT_ABS/duo-06-pose-card.png"); $(canvas_line "$OUT_ABS/logs/frames-pose.txt")$(simnote)"
fi

# ---- pass: UI frames -----------------------------------------------------------------------------------------------
if [[ " $PASSES " == *" ui "* ]]; then
  hinge_set 160 || true
  launch ui-home "screen=home;progress=mid"; shoot duo-ui-home-160 inner
  # First Bite step 1 (pose) passes when 125° ≤ θ ≤ 176° for 0.6 s, so at 160° it should pass by itself.
  launch ui-lesson-1 "screen=lesson;lessonStep=1"; sleep 2; shoot duo-ui-lesson-1-160 inner
  launch ui-lesson-2 "screen=lesson;lessonStep=2"; sleep 3; shoot duo-ui-lesson-2 inner
  launch ui-results "screen=results;seed=7;progress=mid;pilot=casual"; sleep 3; shoot duo-ui-results inner
  launch ui-book "screen=book;progress=late"; sleep 2; shoot duo-ui-book inner
  launch ui-settings "screen=settings"; sleep 2; shoot duo-ui-settings inner
  # Too flat (θ ≥ 174° at the start of play): "Bend it a little, like a book", no penalty.
  hinge_set 178 || true
  launch ui-too-flat "screen=play;mode=attract;seed=7"; sleep 2; shoot duo-ui-too-flat-178 inner
  hinge_sweep 160 1.5
  launch ui-cover "screen=home;progress=mid"
  hinge_sweep 40 1.5; hinge_set 0; sleep 3; shoot duo-ui-cover cover
  hinge_set 160 || true
fi

# ---- pass: the App Store Duo set (ci/duo-scenarios.txt) ------------------------------------------------------------
# One book-pose launch per line of STORE_LIST (name|demo args|wait|caption|expect), the hinge held at STORE_ANGLE (150°:
# open, so no closing pause; the pilot drives the trap itself). A freezeOn= line waits for "SNAP-T freeze <tag>" (at
# least `wait`, at least 20 s), a freezeAfter= line for any "SNAP-T freeze" line, then 2 s for the held frame; others
# wait `wait` s. Writes store-<name>.png (the lit panel) and logs/store-<name>.at-capture.txt (the log at capture).
if [[ " $PASSES " == *" store "* ]]; then
  LIST="${STORE_LIST:-ci/duo-scenarios.txt}"
  SANGLE="${STORE_ANGLE:-150}"
  [[ -f "$LIST" ]] || log "WARN store list $LIST not found"
  [[ -f "$LIST" ]] && while IFS='|' read -r -u 3 name args wait _caption _expect _rest; do
    name="${name%$'\r'}"; args="${args%$'\r'}"; wait="${wait%$'\r'}"
    [[ -z "$name" || "$name" == \#* ]] && continue
    [[ "$name" =~ ${STORE_FILTER:-.} ]] || continue
    wait="${wait%%.*}"; [[ "$wait" =~ ^[0-9]+$ ]] || wait=6
    hinge_set "$SANGLE" || true
    launch "store-$name" "$args"
    SF="$OUT_ABS/logs/store-$name.txt"
    lim=$(( wait > 20 ? wait : 20 ))
    if [[ "$args" =~ freezeOn=([A-Za-z]+) ]]; then
      tag="${BASH_REMATCH[1]}"
      if wait_for "$SF" "SNAP-T freeze $tag" "$lim"; then sleep 2; else log "WARN store-$name: no 'SNAP-T freeze $tag' in ${lim} s (shooting anyway)"; fi
    elif [[ "$args" == *freezeAfter=* ]]; then
      if wait_for "$SF" "SNAP-T freeze" "$lim"; then sleep 2; else log "WARN store-$name: no 'SNAP-T freeze' in ${lim} s"; fi
    else
      sleep "$wait"
    fi
    shoot "store-$name" inner
    cp "$SF" "$OUT_ABS/logs/store-$name.at-capture.txt" 2>/dev/null || true
  done 3< "$LIST"
fi

ls -la "$OUT_ABS" | tee -a "$RUNLOG" >&2
(( SIM_LOST )) || sim_booted || sim_lost "found shut down at the end of the run"
result RIG INFO "hinge calls failed: $HINGE_ERRS (last: ${HINGE_LAST:-none}); simulator deaths: $SIM_DEATHS"
log "checks: $(awk -F'\t' '$2=="PASS"' "$CHECKS" | wc -l | tr -d ' ') PASS, $(awk -F'\t' '$2=="FAIL"' "$CHECKS" | wc -l | tr -d ' ') FAIL, $(awk -F'\t' '$2=="INCONCLUSIVE"' "$CHECKS" | wc -l | tr -d ' ') INCONCLUSIVE"
grep -E $'\t(PASS|FAIL|INCONCLUSIVE)\t' "$CHECKS" | awk -F'\t' '{ printf "%s %s (%s)\n", $1, $2, $3 }' || true
write_summary
if [[ "$STRICT" == 1 ]] && grep -q $'\tFAIL\t' "$CHECKS"; then exit 1; fi
exit 0
