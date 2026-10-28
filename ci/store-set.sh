#!/usr/bin/env bash
# Assemble one Snapjaw App Store screenshot set from a capture folder (ci/store-capture.sh → ci/screenshots.sh or
# ci/duo.sh output): frame every scenario of <scenarios> that matches <filter> under its caption (ci/store-frame.swift)
# and write <dir>/store/<name>.png, <dir>/store/MANIFEST.txt and <dir>/store/MANIFEST.tsv. Ported from the sister
# book-pose game's store pipeline (it shipped through this exact script), with Snapjaw's log lines and glossary.
#
#   bash ci/store-set.sh <dir> <label> "<slot sizes>" [scenarios] [filter] [raw prefix]
#   e.g. BOOK_DIR=raw-duo bash ci/store-set.sh raw-69 'iPhone 6.9-inch' "2868x1320" ci/store-scenarios.txt '^P[0-9]'
#        REQUIRE_LOG='SNAP-T canvas 951x669 fold=1 hudLeft=0' \
#          bash ci/store-set.sh raw-duo 'iPhone Duo inner' "2853x2007" ci/duo-store-scenarios.txt '^D[0-9]' store-
#
#  <slot sizes>  the landscape WxH sizes App Store Connect accepts for this slot, space separated, the set's own device
#                size first. A flat frame is made at its raw capture's size when that is one of them; a raw capture of
#                any other size (wrong simulator, the Duo's cover display) is FLAGGED and not framed.
#  raw prefix    ci/duo.sh names captures store-<name>.png (logs/store-<name>.txt); ci/screenshots.sh uses none.
#
# Scenario lines: name|demo args|wait|caption|expect|frame   (the 6th column is optional; capture scripts ignore it)
#   frame = flat (default) | book | book:<duo scenario name>
#     book            this set's own raw (a Duo inner capture) drawn as the book-pose composite (store-frame --book).
#     book:<name>     the composite made from another set's Duo capture: $BOOK_DIR/$BOOK_PREFIX<name>.png. The iPhone
#                     sets use this for frame 1 (D01's Duo capture). If that capture is missing or not $BOOK_SOURCE_SIZE,
#                     the frame falls back to this set's own flat capture and is FLAGGED.
#   A book frame is made at the set's own raw size if that is a slot size, else at the first slot size.
#
# Checks per frame, against the app log snapshotted at capture (logs/<prefix><name>.at-capture.txt, else .txt; for a
# book:<name> frame, the source capture's log): "SNAP-T demo '…' starts"; "SNAP-T freeze <tag>" for freezeOn=<tag>
# (any "SNAP-T freeze" line for a freezeAfter= without freezeOn); "SNAP-T start wave <n>" for wave=<n> (n > 1); the
# expect regex (5th column); $REQUIRE_LOG; and for every book source $BOOK_REQUIRE (default: the Duo's folded 951x669
# canvas). Captions are linted (docs/appstore/screenshots.md "Caption style"): headline ≤ 30 characters without the
# asterisks and ≤ 7 words, exactly one *highlight*; never "flat", "shut" on its own ("a little shut" is the game's own
# phrase), "quick", "fast", "free", a price or "#1". Output size and alpha are read back with sips. A frame that fails a
# check is still framed but goes to store/_flagged/, so store/ holds only clean frames. A caption with a banned word
# (store-frame.swift: smash, squish, squash, splat, kill, slam, "Fold to", the competitor's name) is REJECTED: no frame
# at all. The light side (--light) follows the HUD: the capture's last "SNAP-T canvas … hudLeft=<0|1>" line. The HUD
# sits on the sharp half (the right one, the default) and the light falls on that page.
# Never fails the job: always exits 0; every problem is a MANIFEST line and a ::warning::.
# Env: STORE_RADIUS (flat capture corner radius, a fraction of its shorter side; default 0.06), STORE_LAYOUT
#      (auto|top|side, default auto), REQUIRE_LOG, BOOK_DIR, BOOK_PREFIX (default store-), BOOK_SOURCE_SIZE (default
#      2853x2007), BOOK_REQUIRE, BOOK_ANGLE (degrees, or auto = the real hinge angle in the source log's last
#      "SNAP-H <t> <θ>" or "SNAP-T hinge … angle <θ>" line if 130–150 (R7: D01 is shot at ciHinge=140), else 140; never the "SNAP-T trap … angle" line,
#      which reads a fixed 160 while a pilot plays), STORE_ROTATE (90|270: rotate a capture whose size is a slot size
#      turned sideways before framing; default off = FLAGGED), STORE_FRAME_BIN (compiled compositor cache).
set -uo pipefail

DIR="${1:?usage: store-set.sh <dir> <label> <slot sizes> [scenarios] [filter] [raw prefix]}"
LABEL="${2:-store}"
SIZES="${3:?slot sizes, e.g. 2868x1320}"
SCEN="${4:-ci/store-scenarios.txt}"
FILTER="${5:-.}"
PREFIX="${6:-}"
RADIUS="${STORE_RADIUS:-0.06}"
LAYOUT="${STORE_LAYOUT:-auto}"
REQUIRE_LOG="${REQUIRE_LOG:-}"
BOOK_DIR="${BOOK_DIR:-}"
BOOK_PREFIX="${BOOK_PREFIX:-store-}"
BOOK_SOURCE_SIZE="${BOOK_SOURCE_SIZE:-2853x2007}"
BOOK_REQUIRE="${BOOK_REQUIRE:-SNAP-T canvas 951x669 fold=1}"
BOOK_ANGLE="${BOOK_ANGLE:-auto}"
STORE_ROTATE="${STORE_ROTATE:-}"
FIRST_SIZE="${SIZES%% *}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/store-frame.swift"
CACHE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
BIN="${STORE_FRAME_BIN:-${CACHE%/}/snap-store-frame}"

if [[ ! -d "$DIR" ]]; then
  echo "::warning::$LABEL: no capture folder $DIR (its capture job was skipped or failed); no set made"
  exit 0
fi
mkdir -p "$DIR/store/_flagged" "$DIR/logs" "$DIR/store/.work"
DIR="$(cd "$DIR" && pwd)"
STORE="$DIR/store"
WORK="$STORE/.work"
rm -f "$STORE"/*.png "$STORE"/_flagged/*.png "$WORK"/*
MANIFEST="$STORE/MANIFEST.txt"
TSV="$STORE/MANIFEST.tsv"
: > "$MANIFEST"
printf 'file\tsize\tstatus\tframe\tcaption\tnotes\n' > "$TSV"
BOOK_DIR_ABS=""
if [[ -n "$BOOK_DIR" && -d "$BOOK_DIR" ]]; then BOOK_DIR_ABS="$(cd "$BOOK_DIR" && pwd)"; fi

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}

note() { echo "$*" | tee -a "$MANIFEST"; }
warn() { echo "::warning::$LABEL: $*"; }
row() {   # row <file> <size> <slot> <alpha> <status> <frame> <caption> <notes>
  note "$(printf '%-26s %-10s %-5s %-6s %-8s %-5s %s' "$1" "$2" "$3" "$4" "$5" "$6" "$8")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$5" "$6" "$7" "$8" >> "$TSV"
}

# png_info <file>: "WxH alpha=<yes|no|?>" via sips, or "? alpha=?".
png_info() {
  local out w h a
  out=$(to 20 sips -g pixelWidth -g pixelHeight -g hasAlpha "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out")
  h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  a=$(awk '/hasAlpha/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h} alpha=${a:-?}"; else echo "? alpha=?"; fi
}
is_slot() { [[ " $SIZES " == *" $1 "* ]]; }
turned() { local w="${1%x*}" h="${1#*x}"; echo "${h}x${w}"; }

# The compositor: compiled once (cached across sets in one job), else interpreted with `xcrun swift`.
if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  built=0
  for attempt in 1 2; do
    if to 600 xcrun swiftc -O -swift-version 5 -module-name StoreFrame "$SRC" -o "$BIN" > "$DIR/logs/store-frame-build.log" 2>&1; then
      built=1; echo "compiled ci/store-frame.swift -> $BIN"; break
    fi
    echo "warning: compile attempt $attempt of ci/store-frame.swift failed"; sleep 3
  done
  if (( ! built )); then
    tail -40 "$DIR/logs/store-frame-build.log" || true
    warn "could not compile ci/store-frame.swift (see logs/store-frame-build.log); falling back to xcrun swift"
    BIN=""
  fi
fi
compose() {
  local status
  for attempt in 1 2; do
    if [[ -n "$BIN" ]]; then to 180 "$BIN" "$@"; else to 600 xcrun swift "$SRC" "$@"; fi
    status=$?
    (( status == 0 )) && return 0
    (( status == 1 || status == 2 )) && return "$status"   # its own error / a rejected caption: no retry
    sleep 2                                 # a timeout or a crash: one more try
  done
  return "$status"
}

problems=()
# check_log <log> <demo args> <expect regex> <require regex…>: append every failed check to problems.
check_log() {
  local f="$1" a="$2" e="$3" fz wave r
  shift 3
  if [[ ! -f "$f" ]]; then problems+=("no app log for this capture"); return 0; fi
  grep -q "SNAP-T demo '.*' starts" "$f" || problems+=("no \"SNAP-T demo '…' starts\" line (demo args not applied?)")
  # Tags are camelCase (lastSnap): letters of both cases, and the whole tag must match.
  if [[ "$a" =~ freezeOn=([A-Za-z]+) ]]; then
    fz="${BASH_REMATCH[1]}"
    grep -qE "SNAP-T freeze $fz( |\$)" "$f" || problems+=("never froze on $fz before the capture")
  elif [[ "$a" == *freezeAfter=* ]]; then
    grep -q "SNAP-T freeze" "$f" || problems+=("never froze (freezeAfter) before the capture")
  fi
  # wave=<n>: the first waves are played headless with the trap held open; the app logs "SNAP-T start wave <n>".
  if [[ "$a" =~ (^|;)wave=([0-9]+) ]]; then
    wave="${BASH_REMATCH[2]}"
    if (( wave > 1 )); then
      grep -qE "SNAP-T start wave $wave( |\$)" "$f" || problems+=("no 'SNAP-T start wave $wave' line")
    fi
  fi
  if [[ -n "$e" ]] && ! grep -qE -- "$e" "$f"; then problems+=("log has no line matching '$e'"); fi
  for r in "$@"; do
    if [[ -n "$r" ]] && ! grep -qE -- "$r" "$f"; then problems+=("log has no line matching '$r'"); fi
  done
  return 0
}

# lint_caption <caption>
lint_caption() {
  local c="$1" head words w plain stars
  [[ -z "${c// /}" ]] && { problems+=("empty caption"); return 0; }
  shopt -s nocasematch
  # docs/appstore/screenshots.md "Caption style": never "flat", "shut" on its own, a speed word (speed is the bugs'
  # business, not the store page's), "free", a price or "#1" (Guideline 2.3.7). store-frame.swift rejects the harder
  # words (smash, squish, slam, "Fold to", the competitor) outright.
  plain="${c//little shut/little-closed}"
  for w in flat shut quick quickly fast faster free; do
    [[ "$plain" =~ (^|[^a-z])$w([^a-z]|$) ]] && problems+=("caption uses '$w' (screenshots.md caption rules)")
  done
  [[ "$c" == *"£"* || "$c" == *'$'* || "$c" == *"€"* || "$c" == *"#1"* ]] && problems+=("caption has a price or '#1' (Guideline 2.3.7)")
  shopt -u nocasematch
  head="${c%% / *}"
  stars="${head//[^*]/}"
  (( ${#stars} == 2 )) || problems+=("headline needs exactly one *highlight* (it has ${#stars} asterisks)")
  head="${head//\*/}"
  words=$(wc -w <<< "$head" | tr -d ' ')
  (( words > 7 )) && problems+=("headline has $words words (max 7)")
  (( ${#head} > 30 )) && problems+=("headline has ${#head} characters (max 30)")
  return 0
}

# book_angle <source log>
book_angle() {
  local a=""
  if [[ "$BOOK_ANGLE" != auto ]]; then echo "$BOOK_ANGLE"; return; fi
  # The real hinge: HingeReader's "SNAP-H <t> <θ>" samples, else HingeTrapSource's "SNAP-T hinge … angle <θ>". Never
  # the 10 Hz "SNAP-T trap … angle" line: it reads a fixed 160 while a pilot plays.
  if [[ -f "$1" ]]; then
    a=$(sed -nE 's/^SNAP-H [0-9.]+ ([0-9]+)(\.[0-9]+)?.*/\1/p' "$1" | tail -1)
    [[ -z "$a" ]] && a=$(sed -nE 's/.*SNAP-T hinge .*angle ([0-9]+)(\.[0-9]+)?.*/\1/p' "$1" | tail -1)
  fi
  if [[ -n "$a" ]] && (( a >= 130 && a <= 150 )); then echo "$a"; else echo 140; fi   # R7: the store book is ~140° (130–150 kept)
}

device="(see the capture log)"
if [[ -f "$DIR/device.txt" ]]; then
  device="$(sed -n 's/^name=//p' "$DIR/device.txt") [$(sed -n 's/^resolved=//p' "$DIR/device.txt")]"
fi
note "Snapjaw App Store set: $LABEL"
note "slot sizes: $SIZES   device: $device   book source: ${BOOK_DIR_ABS:-this set}"
note "built: $(date -u '+%Y-%m-%d %H:%M UTC')  commit: ${GITHUB_SHA:-local}  run: ${GITHUB_RUN_ID:-local}"
note "upload: store/*.png only, in name order. store/_flagged/ = framed but a check failed: fix or eyeball first."
note ""
note "$(printf '%-26s %-10s %-5s %-6s %-8s %-5s %s' frame size slot alpha status mode notes)"

ok=0; flagged=0; missing=0
while IFS= read -r -u 3 line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line// /}" || "$line" == \#* ]] && continue
  IFS='|' read -r name args wait caption expect frame <<< "$line"
  frame="${frame//[[:space:]]/}"; frame="${frame%%|*}"
  [[ -n "$name" && "$name" =~ $FILTER ]] || continue
  raw="$DIR/$PREFIX$name.png"
  applog="$DIR/logs/$PREFIX$name.at-capture.txt"
  [[ -f "$applog" ]] || applog="$DIR/logs/$PREFIX$name.txt"
  problems=()
  notes=()
  lint_caption "$caption"

  # Which picture, which mode.
  mode=flat; src="$raw"; srclog="$applog"; srcargs="$args"
  if [[ "$frame" == book || "$frame" == book:* ]]; then
    bsrc="$raw"; blog="$applog"; bargs="$args"
    if [[ "$frame" == book:* ]]; then
      bname="${frame#book:}"; bargs=""
      if [[ -n "$BOOK_DIR_ABS" ]]; then
        bsrc="$BOOK_DIR_ABS/$BOOK_PREFIX$bname.png"
        blog="$BOOK_DIR_ABS/logs/$BOOK_PREFIX$bname.at-capture.txt"
        [[ -f "$blog" ]] || blog="$BOOK_DIR_ABS/logs/$BOOK_PREFIX$bname.txt"
      else
        bsrc=""
      fi
    fi
    bdims="-"
    [[ -n "$bsrc" && -f "$bsrc" ]] && { binfo=$(png_info "$bsrc"); bdims="${binfo%% *}"; }
    if [[ "$bdims" == "$BOOK_SOURCE_SIZE" ]]; then
      mode=book; src="$bsrc"; srclog="$blog"; srcargs="$bargs"
    elif [[ -z "$bsrc" || ! -f "$bsrc" ]]; then
      problems+=("book source ${frame#book:} missing (no Duo capture${BOOK_DIR:+ in $BOOK_DIR}): flat fallback; frame 1 must be the book")
    else
      problems+=("book source is $bdims, not the Duo inner $BOOK_SOURCE_SIZE: flat fallback")
    fi
  fi

  if [[ "$mode" == flat && ! -f "$raw" ]]; then
    row "$name.png" - no - MISSING "$mode" "$caption" "no capture $PREFIX$name.png (launch or screenshot failed; see the capture log)"
    warn "$name MISSING (no capture)"
    missing=$((missing + 1))
    continue
  fi

  # Content checks against the log of the picture actually shown.
  # A book:<name> source is another set's Duo capture: this set's REQUIRE_LOG (e.g. the iPhone's unfolded canvas)
  # doesn't apply to it, only BOOK_REQUIRE does.
  if [[ "$mode" == book && "$frame" == book:* ]]; then check_log "$srclog" "$srcargs" "$expect" "$BOOK_REQUIRE"
  elif [[ "$mode" == book ]]; then check_log "$srclog" "$srcargs" "$expect" "$REQUIRE_LOG" "$BOOK_REQUIRE"
  else check_log "$srclog" "$srcargs" "$expect" "$REQUIRE_LOG"; fi

  # The light falls on the HUD's page: the sharp half, the right one by default (a fold started from flat blurs the
  # left half for ~2 s, so the HUD lives on the right). hudLeft=1 (the Settings option) → the light from the left.
  # The last canvas line in the log is the layout that was on screen.
  light=right
  if [[ -f "$srclog" ]] && grep -E "SNAP-T canvas " "$srclog" | tail -1 | grep -q "hudLeft=1"; then light=left; fi
  [[ "$light" == left ]] && notes+=("HUD on the left: light from the left")

  # Output size.
  if [[ "$mode" == book ]]; then
    outsize="$FIRST_SIZE"
    if [[ -f "$raw" ]]; then rinfo=$(png_info "$raw"); is_slot "${rinfo%% *}" && outsize="${rinfo%% *}"; fi
    angle=$(book_angle "$srclog")
    notes+=("book from $(basename "$src") at ${angle}°")
  else
    rinfo=$(png_info "$raw"); rawdims="${rinfo%% *}"
    if ! is_slot "$rawdims"; then
      if [[ -n "$STORE_ROTATE" ]] && is_slot "$(turned "$rawdims")"; then
        if to 30 sips -r "$STORE_ROTATE" "$raw" --out "$WORK/$name.png" >/dev/null 2>&1; then
          src="$WORK/$name.png"; rawdims="$(turned "$rawdims")"; notes+=("raw turned ${STORE_ROTATE}°: eyeball the orientation")
        fi
      fi
    fi
    if ! is_slot "$rawdims"; then
      why="raw capture is $rawdims, not a slot size ($SIZES): not framed"
      [[ "$rawdims" != "?" ]] && is_slot "$(turned "$rawdims")" && why="raw capture is $rawdims, a slot size turned sideways (unrotated framebuffer?); set STORE_ROTATE=90|270 or recapture: not framed"
      row "$name.png" "$rawdims" no - FLAGGED "$mode" "$caption" "$why"
      warn "$name: $why"
      flagged=$((flagged + 1))
      continue
    fi
    outsize="$rawdims"
  fi

  dest="$STORE/$name.png"
  (( ${#problems[@]} > 0 )) && dest="$STORE/_flagged/$name.png"
  cargs=(--in "$src" --out "$dest" --size "$outsize" --radius "$RADIUS" --layout "$LAYOUT" --light "$light"
         --caption "$caption")
  [[ "$mode" == book ]] && cargs+=(--book --angle "$angle")
  report=$(compose "${cargs[@]}" 2>&1)
  status=$?
  if (( status == 2 )); then
    row "$name.png" - no - REJECTED "$mode" "$caption" "$(tail -1 <<< "$report")"
    warn "$name: caption REJECTED ($(tail -1 <<< "$report"))"
    missing=$((missing + 1))
    continue
  fi
  if (( status != 0 )) || [[ ! -f "$dest" ]]; then
    row "$name.png" - no - FAILED "$mode" "$caption" "store-frame exit $status: $(tail -1 <<< "$report")"
    warn "$name: store-frame failed ($(tail -1 <<< "$report"))"
    missing=$((missing + 1))
    continue
  fi
  outinfo=$(png_info "$dest")
  outdims="${outinfo%% *}"
  alpha="${outinfo##*alpha=}"
  match=no
  is_slot "$outdims" && match=yes
  [[ "$match" == yes ]] || problems+=("output is $outdims, not a slot size")
  [[ "$alpha" == no ]] || problems+=("output alpha=$alpha (App Store Connect rejects alpha)")
  [[ "$report" == *"extent=mismatch"* ]] && problems+=("book warp extent mismatch: eyeball the screen mapping")
  summary=$(grep -oE '(layout|cap|lines|rounded|warp)=[^ ]+' <<< "$report" | tr '\n' ' ' | sed 's/ $//')
  if (( ${#problems[@]} > 0 )); then
    if [[ "$dest" == "$STORE/$name.png" ]]; then mv -f "$dest" "$STORE/_flagged/$name.png"; fi
    joined=$(printf '%s; ' "${problems[@]}" ${notes[@]+"${notes[@]}"}); joined="${joined%; }"
    row "_flagged/$name.png" "$outdims" "$match" "$alpha" FLAGGED "$mode" "$caption" "$joined"
    warn "$name FLAGGED: $joined"
    flagged=$((flagged + 1))
  else
    joined=$(printf '%s; ' ${notes[@]+"${notes[@]}"} "$summary"); joined="${joined%; }"
    row "$name.png" "$outdims" "$match" "$alpha" OK "$mode" "$caption" "$joined"
    ok=$((ok + 1))
  fi
  note "    caption: $caption"
  facts=$(grep -oE "SNAP-T (freeze|start wave|canvas|event feast|event stung|run) .*" "$srclog" 2>/dev/null | sed 's/^SNAP-T //' | sort -u | head -6 | tr '\n' ';' | sed 's/;$//; s/;/; /g')
  [[ -n "$facts" ]] && note "    app log: $facts"
done 3< "$SCEN"

rm -rf "$WORK"
note ""
note "summary: ok $ok  flagged $flagged  missing $missing"
note "before upload (docs/appstore/screenshots.md): eyeball every frame. The checks read the app log, not the picture:"
note "the caption must be true of the frame, no stale hint text, nothing important in the crease band, no prices."

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  { echo "### $LABEL"; echo '```'; cat "$MANIFEST"; echo '```'; } >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true
fi
ls -la "$STORE" "$STORE/_flagged" 2>/dev/null || true
exit 0
