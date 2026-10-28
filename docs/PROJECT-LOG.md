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
