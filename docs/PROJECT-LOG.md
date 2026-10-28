# Project log

## 27 Oct 2026 (evening)
- Founder brief: fifth Duo-first paid game, unique, unsupervised, 2-3 days.
- Market check (`research/01-market.md`): flytrap theme free; Fold Smasher (free, 23 Oct) owns snap-shut-on-bugs, so Snapjaw is built on choosing, crowds, bees, a partial snap and an economy. Name: Snapjaw.
- Design v1, architecture, contracts, Round 1 brief.

## 27–28 Oct 2026 (night)
- The founder made the repo public; CI unblocked.
- Round 1 written by five parallel engineers (Core, Feel, Scene, App, CI) plus the launch kit, ~17.4k lines of Swift.
- **CI 40601210488: first build green, 151 tests in 13 suites passed** (the first compile ever).
- R1 frames: the trap, bog, HUD and night read well. Problems seen by the founder: bugs far too small for the trap,
  thin crowds, long white streaks across the trap, an empty "Chain…" chip, snap icons over the rim, and Home's flat
  trap not matching the game art.
- Started: Duo sim run 40603497021, the R1 critic panel, QA-1.

## 28 Oct 2026 (early hours)
- R1 panel: juror 5, UX 4, feel 4, Duo 5. QA-1: 1 P0 (the closing pause never lifted), 4 P1.
- Duo sim run 40603497021 (R1): a real hinge-driven SNAP caught 10 bugs; REARM, CREEP and CLOSE-PAUSE passed.
- Round 2 (Core, Feel, Scene, App in parallel) plus the store/ASC pipeline port:
  - hunger and wilt, the ≥ 2-bug chain rule, 12 snaps while Sprout;
  - bugs ×1.8, clustered nectar, and the streak bug fixed (reused wing sprites kept a 0.001 y-scale);
  - a deeper trap, a bite read (hit-stop, squeeze, flash), bee/wasp/catchable rings, economy glyph flights;
  - the lesson reworked, the HUD placed off the trap and crease, one art language, a new icon.
- CI 40611262935 compiled first time; one test expectation was wrong (the snap's own closure counted). After the fix
  **CI 40612235669: 215 tests green**.
- Next: the R2 panel with fresh-player testers, Duo sim run 40615925900.
- R2 panel: juror 6, UX 6, feel 6, Duo 5 (prov.), fresh 6/7/5 ("watermelon", "giant eye" bite, truncated hint).
- Round 3: the founder's flytrap art direction (two hinged lobes, glands, 76 cilia, stem), the bite inside the
  outline, stinger bites ×1 with no refunds, wilt 18/16/14/12, Sprout run 1 (no wilt, free first bee), chain ×5,
  14 snaps, the fold drawn as the input, badges, a new icon. CI fixes: an icon variable shadowing (40621685004), a
  rethrowing call in #expect (40621872386), two over-strict tests (40622079094).
  **CI 40623216966: 253 tests green.** The trap now reads as a flytrap; the icon is a 3/4 trap with a fly.
- Duo sim R2 run 40615925900 was inconclusive: only 6 hinge samples reached the app, and no trap lines. An
  investigator is on it.
- R3 panel: juror 7, UX 7, feel 7, Duo 6 (prov.), fresh 7/7/6, icon 7, badges 7. QA-2: no P0; P1 = the hunger clock
  ran with an empty or bee-only trap. No Release or App Review blockers.
- Duo R3 run 40626586037: the simulator died twice mid-sweep (a rig flake; duo.sh now detects it: SIMULATOR FAIL →
  INCONCLUSIVE). First real 951×669 frames of R3: the trap fills both halves, the midrib on the fold.
- Round 4:
  - hunger only while a catchable bug waits with no bee, night wilt 14, Sprout run 1 at 14 snaps with a calm first
    morning;
  - the face without peach, the green-backed closed trap, light by phase, the small snap glyph, and a 3/4 trap for
    Results, the cover, the pose card and the badges;
  - the free-sting toast in the hint slot, truthful snap counts, the chain explained, voice-steal fades, and the icon
    fly in the game's colours.
  - Sim: novice run 1 105 s, casual 147 s with 0 wilts, expert 3 wilts.
  - CI fixes: an ambiguous `.nan`, a stale floor test, the cap rule, the face colour tolerance.
  - **CI 40634463943: 283 tests green**, and all 43 frames froze on their moments.
- Duo R4 run 40634483657: **SNAP PASS from the real hinge** (d 0.264 s: caught 2, escaped 4, one bee), REARM, CREEP and CLOSE-PAUSE PASS (paused at 42.8°, resumed at 120.1°). The simulator still died twice later (the rig).
- R4 panel: juror 7, UX 8, feel 8, Duo 6 (prov.), fresh 7/6/7, icon 8, badges 7. The blockers it named: the pose
  card, the plum-like release, "Out of snaps" over 1–2, and no hinge evidence.
- First store run 40637893235: all four jobs green; the P01 hero ("Your Duo is a flytrap" on a framed Duo) is strong.
  D02 caught the release frame, so it gets re-shot.
- Round 5:
  - the release stays crimson, one hero trap from the icon, a warmer dusk, "Missed!", pop collisions, airborne
    flyers over the crease;
  - the pose card rebuilt, the tired banner after the drop, the sting cost shown, "score" (not "protein"), varied
    badges, the Daily share line;
  - the Sprout taper (sim novice runs 1/2/3 = 101/100/90 s), bees pause hunger from their final approach, the
    dry-snap clop;
  - the CI Duo rig hardened (a fresh Duo per hinge launch, retries), the lesson and R4 Duo frames, open-after-bite
    store shots.
  - **CI 40645123693: 307 tests green.** All four R4 blockers are visibly fixed (frames 31, 14, 19, 20).
- Ideas after 1.0: a relaxed mode that never runs out (a player asked).
