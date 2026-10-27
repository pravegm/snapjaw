#!/usr/bin/env bash
# Boots a regular iPhone simulator, installs the Debug build of Snapjaw (Snap.app) and captures one screenshot per demo
# scenario (called by .github/workflows/ci.yml; adapted from the sister projects' ci/screenshots.sh, proven on these
# runners). Snapjaw plays in LANDSCAPE (book pose), like its book-pose sister; a phone sim has no hinge, so the UI
# turns landscape by itself and the trap is tap-to-snap unless a `pilot=` drives it or `closure=` holds it. There is no
# `simctl` rotate verb (and `simctl io … screenConfig` is never used: it crash-loops SpringBoard on the Duo).
#
# ci/scenarios.txt lines: `name|demo args|wait|caption|expect`
#   demo args  passed as `-snapDemo "<args>"` (Snap/App/DemoMode.swift, DEBUG only; keys in design/ROUND-1.md).
#   wait       seconds before the capture. A scenario with freezeOn=<tag> instead waits (up to max(wait, 60) s) for the
#              app's "SNAP-T freeze <tag>" line, then 2 s; one with freezeAfter=<s> (and no freezeOn) waits the same
#              way for any "SNAP-T freeze" line (WAIT_FREEZE=1, the default here).
#   caption    what the frame should show (for the reviewer; not drawn on the frame).
#   expect     optional extended regex the app log must contain at capture time (reported, never fatal).
#   launch     (optional 6th or 7th column) extra launch arguments, split on spaces and passed after
#              `-snapDemo "<args>"`, e.g. `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`
#              (Large Dynamic Type frames). A column counts as launch arguments only when it starts with `-`, so a
#              store file's 6th `frame` column is ignored here.
# App stdout/stderr per scenario: $OUT/logs/<name>.txt, plus a snapshot taken right after the screenshot:
# $OUT/logs/<name>.at-capture.txt.
# Every simulator call has a timeout; a failed launch or screenshot is retried once, then skipped (the run goes on).
# Env:
#  DEVICE          default "iPhone 18 Pro". One candidate, or several separated by `|`, tried in order:
#                    <exact name>          an available simulator with that name (created from the device type of that
#                                          name if none exists yet)
#                    auto:<suffix>         the newest iPhone whose name ends with <suffix>, e.g. `auto:Pro Max`
#                    screen:<WxH>[,<WxH>]  the newest iPhone device type whose screen is one of these pixel sizes
#                                          (portrait, first size preferred), e.g. `screen:1179x2556,1170x2532`
#                  The pick is written to $OUT/device.txt (ci.yml's icon step reads the udid from it).
#  OUT             default ci-screens.
#  SCENARIOS       default ci/scenarios.txt.
#  SCENARIO_FILTER regex on the name (default ".").
#  EXPECT_SIZE     space-separated WxH list (e.g. "2622x1206"): warn when a capture is another size (never fails).
#  WAIT_FREEZE     1 (default) = freeze-wait as above; 0 = always the fixed wait.
#  EXTRA_LAUNCH_ARGS  launch arguments added to every scenario (before the scenario's own `launch` column).
# Writes $OUT/captures.tsv: name <TAB> ok|launch-failed|screenshot-failed <TAB> WxH <TAB> froze|no-freeze|- <TAB>
# expect-ok|expect-miss|-, and a table to $GITHUB_STEP_SUMMARY when it is set. Always exits 0 (frames are evidence,
# not gates; build + tests are the gate).
set -uo pipefail

DEVICE="${DEVICE:-iPhone 18 Pro}"
APP="build/Build/Products/Debug-iphonesimulator/Snap.app"
BUNDLE="com.pravegm.snapjaw"
OUT="${OUT:-ci-screens}"
FILTER="${SCENARIO_FILTER:-.}"
SCENARIOS="${SCENARIOS:-ci/scenarios.txt}"
EXPECT_SIZE="${EXPECT_SIZE:-}"
WAIT_FREEZE="${WAIT_FREEZE:-1}"
mkdir -p "$OUT/logs"
OUT_ABS="$(cd "$OUT" && pwd)"
INDEX="$OUT_ABS/captures.tsv"
: > "$INDEX"

# to <seconds> <command…>: run with a timeout (gtimeout / timeout from coreutils, else perl's alarm).
to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}

# png_dims <file>: "WxH" via sips, or "?".
png_dims() {
  local w h
  w=$(to 20 sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}')
  h=$(to 20 sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
}

# Prints "<udid><TAB><name><TAB><how>", or "CREATE<TAB><type id><TAB><runtime id><TAB><name><TAB><how>" when the device
# has to be created. Exits 1 when no candidate matches. (Verbatim from the sister CI.)
RESOLVE_PY='
import json, os, plistlib, re, subprocess, sys

def simctl(*what):
    return json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", *what], timeout=120))

def model(name):
    m = re.search(r"iPhone (\d+)", name)
    return int(m.group(1)) if m else 0

def rt_version(identifier):
    m = re.search(r"iOS-(\d+)-(\d+)", identifier)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)

# Portrait pixel sizes for when a device type profile cannot be read.
KNOWN = {
    "iPhone 12": "1170x2532", "iPhone 12 Pro": "1170x2532", "iPhone 13": "1170x2532", "iPhone 13 Pro": "1170x2532",
    "iPhone 14": "1170x2532", "iPhone 16e": "1170x2532",
    "iPhone 14 Pro": "1179x2556", "iPhone 15": "1179x2556", "iPhone 15 Pro": "1179x2556", "iPhone 16": "1179x2556",
    "iPhone 16 Pro": "1206x2622", "iPhone 17": "1206x2622", "iPhone 17 Pro": "1206x2622", "iPhone 18 Pro": "1206x2622",
    "iPhone 16 Pro Max": "1320x2868", "iPhone 17 Pro Max": "1320x2868", "iPhone 18 Pro Max": "1320x2868",
}

def screen(t):
    path = os.path.join(t.get("bundlePath", ""), "Contents", "Resources", "profile.plist")
    try:
        with open(path, "rb") as f:
            p = plistlib.load(f)
        w, h = int(p["mainScreenWidth"]), int(p["mainScreenHeight"])
        return "%dx%d" % (min(w, h), max(w, h))
    except Exception:
        return KNOWN.get(t.get("name", ""), "")

devices = simctl("devices", "available")["devices"]
existing = [(d, rt) for rt, ds in devices.items() if "iOS" in rt for d in ds]
types = [t for t in simctl("devicetypes")["devicetypes"] if t.get("name", "").startswith("iPhone")]
runtimes = sorted((r for r in simctl("runtimes")["runtimes"] if r.get("isAvailable") and "iOS" in r.get("identifier", "")),
                  key=lambda r: rt_version(r["identifier"]), reverse=True)

def supports(r, t):
    s = r.get("supportedDeviceTypes")
    return s is None or any(x.get("identifier") == t["identifier"] for x in s)

def done(udid, name, how):
    print(udid + "\t" + name + "\t" + how)
    sys.exit(0)

def from_types(cands, how):
    for t in cands:
        have = sorted(((rt_version(rt), d["udid"], d["name"]) for d, rt in existing
                       if d.get("deviceTypeIdentifier") == t["identifier"] or d["name"] == t["name"]), reverse=True)
        if have:
            done(have[0][1], have[0][2], how + " " + t["name"])
        for r in runtimes:
            if supports(r, t):
                print("CREATE\t" + t["identifier"] + "\t" + r["identifier"] + "\t" + t["name"] + "\t" + how + " " + t["name"] + " (created)")
                sys.exit(0)

cands = [c.strip() for c in sys.argv[1].split("|") if c.strip()]
for i, c in enumerate(cands):
    tag = "candidate %d/%d (%s)%s:" % (i + 1, len(cands), c, "" if i == 0 else " FALLBACK")
    if c.startswith("auto:"):
        suffix = c[5:]
        found = sorted(((model(d["name"]), rt_version(rt)), d["udid"], d["name"]) for d, rt in existing
                       if d["name"].startswith("iPhone") and d["name"].endswith(suffix))
        if found:
            done(found[-1][1], found[-1][2], tag)
        from_types(sorted((t for t in types if t["name"].endswith(suffix)), key=lambda t: model(t["name"]), reverse=True), tag)
    elif c.startswith("screen:"):
        sizes = [s.strip().lower() for s in c[7:].split(",") if s.strip()]
        ranked = []
        for t in types:
            px = screen(t)
            if px in sizes:
                ranked.append((sizes.index(px), -model(t["name"]), t["name"], t))
        ranked.sort(key=lambda x: (x[0], x[1], x[2]))
        from_types([x[3] for x in ranked], tag + " screen " + ",".join(sizes))
    else:
        found = sorted((rt_version(rt), d["udid"], d["name"]) for d, rt in existing if d["name"] == c)
        if found:
            done(found[-1][1], found[-1][2], tag)
        from_types([t for t in types if t["name"] == c], tag)
sys.exit(1)
'
RESOLVED=$(to 300 python3 -I -c "$RESOLVE_PY" "$DEVICE") || {
  echo "no simulator named $DEVICE"
  to 60 xcrun simctl list devices available || true
  exit 1
}
HOW=""
if [[ "$RESOLVED" == CREATE* ]]; then
  IFS=$'\t' read -r _ TYPE_ID RUNTIME_ID DEVICE_NAME HOW <<< "$RESOLVED"
  echo "creating '$DEVICE_NAME' ($TYPE_ID, $RUNTIME_ID)"
  UDID=$(to 120 xcrun simctl create "$DEVICE_NAME" "$TYPE_ID" "$RUNTIME_ID") || { echo "could not create $DEVICE_NAME"; exit 1; }
else
  IFS=$'\t' read -r UDID DEVICE_NAME HOW <<< "$RESOLVED"
fi
[[ -n "${UDID:-}" ]] || { echo "no simulator named $DEVICE"; exit 1; }
echo "device $DEVICE_NAME $UDID ($HOW)"
printf 'requested=%s\nname=%s\nudid=%s\nresolved=%s\n' "$DEVICE" "$DEVICE_NAME" "$UDID" "$HOW" > "$OUT_ABS/device.txt"

to 120 xcrun simctl boot "$UDID" 2>/dev/null || true
to 600 xcrun simctl bootstatus "$UDID" -b || echo "warning: bootstatus did not finish for $DEVICE_NAME"
to 30 xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 2>/dev/null || true
to 300 xcrun simctl install "$UDID" "$APP" || {
  echo "install failed, retrying"; sleep 5
  to 300 xcrun simctl install "$UDID" "$APP" || echo "install failed"
}

fails=0
size_warnings=0
nofreeze=0
expect_miss=0
while IFS='|' read -r -u 3 name args wait caption expect col6 col7; do
  name="${name%$'\r'}"; args="${args%$'\r'}"; wait="${wait%$'\r'}"; caption="${caption%$'\r'}"; expect="${expect%$'\r'}"
  col6="${col6%$'\r'}"; col7="${col7%$'\r'}"; col7="${col7%%|*}"
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ "$name" =~ $FILTER ]] || continue
  wait="${wait:-6}"
  wait="${wait%%.*}"
  [[ "$wait" =~ ^[0-9]+$ ]] || wait=6
  # Extra launch arguments: EXTRA_LAUNCH_ARGS, then a 6th or 7th column that starts with "-" (sister R3: Dynamic Type).
  extra="${EXTRA_LAUNCH_ARGS:-}"
  for c in "$col6" "$col7"; do
    c="${c#"${c%%[![:space:]]*}"}"
    [[ "$c" == -* ]] && extra="$extra $c"
  done
  # Sister R4: a "|" inside the expect regex splits it into a bogus 6th column and the expect can never match. Flag any
  # 6th/7th column that is neither launch arguments nor a store `frame` value.
  for c in "$col6" "$col7"; do
    c="${c#"${c%%[![:space:]]*}"}"
    [[ -z "$c" || "$c" == -* || "$c" == book* || "$c" == phone* ]] && continue
    echo "warning: $name: unexpected extra column '$c' (a '|' inside the caption or the expect regex?)"
  done
  launch_extra=()
  read -r -a launch_extra <<< "$extra"
  echo "== $name ($args) wait ${wait}s${extra:+ launch:$extra}${caption:+ — $caption}"
  applog="$OUT_ABS/logs/$name.txt"
  rm -f "$OUT_ABS/$name.png"
  : > "$applog"
  to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  launched=0
  for attempt in 1 2; do
    if to 90 xcrun simctl launch --terminate-running-process \
      --stdout="$applog" --stderr="$applog" \
      "$UDID" "$BUNDLE" -snapDemo "$args" ${launch_extra[@]+"${launch_extra[@]}"} >/dev/null; then
      launched=1; break
    fi
    echo "launch attempt $attempt failed: $name"
    sleep 3
  done
  if (( ! launched )); then
    echo "launch failed: $name"; fails=$((fails+1))
    printf '%s\tlaunch-failed\t-\t-\t-\n' "$name" >> "$INDEX"
    continue
  fi

  # freezeOn tags are camelCase (lastSnap), so the tag match must allow capitals (the sister CI once missed a camelCase
  # tag this way). A freezeAfter=<s> scenario without freezeOn waits for any "SNAP-T freeze" line (the tag the App
  # prints for a timed freeze is its own).
  freeze=""; froze="-"
  if [[ "$WAIT_FREEZE" == 1 && "$args" =~ freezeOn=([A-Za-z]+) ]]; then freeze="SNAP-T freeze ${BASH_REMATCH[1]}"
  elif [[ "$WAIT_FREEZE" == 1 && "$args" == *freezeAfter=* ]]; then freeze="SNAP-T freeze"; fi
  if [[ -n "$freeze" ]]; then
    limit=$(( wait > 60 ? wait : 60 )); t=0
    while (( t < limit )); do grep -q "$freeze" "$applog" 2>/dev/null && break; sleep 1; t=$((t+1)); done
    if grep -q "$freeze" "$applog" 2>/dev/null; then
      echo "froze ('$freeze') after ${t}s"; froze="froze"; sleep 2
    else
      echo "warning: $name: no '$freeze' line after ${limit}s (capturing anyway)"
      froze="no-freeze"; nofreeze=$((nofreeze+1))
    fi
  else
    sleep "$wait"
  fi

  shot=0
  for attempt in 1 2; do
    to 60 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>&1 && { shot=1; break; }
    sleep 2
  done
  # Sister R11: a shot taken while the app is still launching or rotating out of portrait is a blank launch colour
  # (~60 KB) or a portrait frame. Every iPhone scenario plays in landscape (unless it asks orient=portrait), so re-shoot
  # (up to 3 times, 4 s apart) instead of shipping it. The size floor is 80 KB, not 100 KB (the bog is dark by design).
  for retry in 1 2 3; do
    (( shot )) || break
    dims=$(png_dims "$OUT_ABS/$name.png"); w=${dims%x*}; h=${dims#*x}
    bytes=$(wc -c < "$OUT_ABS/$name.png" | tr -d ' ')
    [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || break
    portrait=0; [[ "$args" != *orient=portrait* ]] && (( h > w )) && portrait=1
    if (( portrait || bytes < 80000 )); then
      echo "warning: $name looks unsettled ($dims, $bytes bytes); re-shooting ($retry/3)"
      sleep 4
      to 60 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$name.png" >/dev/null 2>&1 || break
    else
      break
    fi
  done
  cp "$applog" "$OUT_ABS/logs/$name.at-capture.txt" 2>/dev/null || : > "$OUT_ABS/logs/$name.at-capture.txt"

  exp="-"
  if [[ -n "$expect" ]]; then
    if grep -qE -- "$expect" "$OUT_ABS/logs/$name.at-capture.txt" 2>/dev/null; then exp="expect-ok"
    else exp="expect-miss"; expect_miss=$((expect_miss+1)); echo "warning: $name: log has no match for /$expect/"; fi
  fi

  if (( shot )); then
    dims=$(png_dims "$OUT_ABS/$name.png")
    printf '%s\tok\t%s\t%s\t%s\n' "$name" "$dims" "$froze" "$exp" >> "$INDEX"
    if [[ -n "$EXPECT_SIZE" && " $EXPECT_SIZE " != *" $dims "* ]]; then
      echo "warning: $name is $dims, expected one of: $EXPECT_SIZE"
      size_warnings=$((size_warnings+1))
    fi
  else
    echo "screenshot failed: $name"; fails=$((fails+1))
    printf '%s\tscreenshot-failed\t-\t%s\t%s\n' "$name" "$froze" "$exp" >> "$INDEX"
  fi
  grep -E "SNAP-" "$applog" | tail -5 || true
done 3< "$SCENARIOS"

to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
ls -la "$OUT_ABS"
echo "screenshot failures: $fails; freeze misses: $nofreeze; expect misses: $expect_miss"
if [[ -n "$EXPECT_SIZE" ]]; then echo "size warnings: $size_warnings (expected $EXPECT_SIZE on $DEVICE_NAME)"; fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Screenshots on $DEVICE_NAME"
    echo ""
    echo "$(awk -F'\t' '$2=="ok"' "$INDEX" | wc -l | tr -d ' ') captured, $fails failed, $nofreeze freeze misses, $expect_miss expect misses."
    echo ""
    echo "| Scenario | Result | Size | Freeze | Expect |"
    echo "|---|---|---|---|---|"
    awk -F'\t' '{printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5}' "$INDEX"
  } >> "$GITHUB_STEP_SUMMARY"
fi
exit 0
