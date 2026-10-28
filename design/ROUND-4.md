# Round 4: launch blockers and hero polish (brief)

R3 compiled (253 tests). Panel: juror 7, UX 7, feel 7, Duo 6 (provisional), fresh players 7 / 7 / 6, icon 7, badges 7
(`design/REVIEW-3-*.md`, `design/fresh/tester4-6.md`, merged list `design/REVIEW-3-summary.md`). QA-2
(`design/QA-2.md`): no P0, one P1, and no Release or App Review blockers. Frames: `artifacts/r3/screenshots/`. Duo
simulator run 40626586037 (R3) is in progress: its frames land in `artifacts/duo3/`.

**Do REVIEW-3-summary #1–#20 and QA-2 (P1 + every P2 in your module).** The founder's calls on the open points:

- **Hunger (QA-2 #1 + REVIEW-3 #12):** the hunger clock ticks **only while at least one catchable bug is in the trap
  and no protected bug is in it**. An empty, bee-only or bee-plus-flies trap never gets hungrier. It resets on any
  catch, as now. Night wilt 14 s (so 18/16/14/14). Sim targets: expert ≤ 6 wilts, perfect ≤ 5, casual ≤ 2.
- **First run (#11):** Sprout run 1 starts with **14 snaps** (the max) and keeps the no-wilt and free-first-sting
  perks. If the player's first ever run is the Daily, the Daily stays standard (fairness), but their first Feed run
  still gets the perks (QA-2 #11). Target: the novice pilot's run 1 is ≥ 90 s.
- **The free-sting toast (#3):** the copy is "Bees and wasps cost snaps. This one's free!". It goes in the hint slot,
  never over a pop, and the snaps row flashes green with "free!".
- **The face (#5) and the hold (#6):** the critics' numbers are right. Outer lobe ≤ #C02A42; the oxblood gradient
  visible across the whole lobe; the yellow-green blush (≈ #B8C25A, ≤ 40 % alpha) only in the last 8–10 %, with no
  peach. The closed trap shades its outer halves toward leaf green with crimson only at the seam, at one consistent
  width. Caught bugs sink into the seam within 60 ms.
- **The isolated trap (#16): a 4+ risk, P0 for me.** On Results, the cover, the pose card and every badge, show the
  trap 3/4-tilted like the icon (or open, with a sipping bug on it), with the leaf back and petiole visible. Never a
  centred vertical slit.
- **The icon (#17):** keep the composition the panel liked. Use the in-game housefly palette (grey-blue body, red
  eyes) so the icon and the game agree, shrink the fly to about 35 % of the trap width, and show both lobes' crimson
  edges.
- **Demo/CI (#2):** play demos default to standard rules (`progress=mid` behaviour) unless `progress=fresh` or
  `firstRun=1` is given. Add freeze tags: `firstHint`, `chain5`, `costlySting`, `drySnap`, `held` ("×1.5 held"), and
  timing offsets (`hungry` +0.5, `wilted` +0.3, `costlySting` +0.2). Story frames come from one continuous seeded run
  where possible.
- **Snaps count truthfulness (QA-2 #2, #3):** the HUD numeral and glyphs never move in the wrong direction. A costly
  sting goes down only, a Feast at the cap shows "+1 (full)" without dipping, and the lesson never shows 10 → 9 → 10.

## Owners
- **Core:** hunger gating, night wilt 14, Sprout run-1 snaps = 14, the Daily-first case (rules side), midrib-avoiding
  attract and crossing paths (#14), the sim and balance tests, and the GAME-DESIGN §5/§6 numbers (§6 late night:
  decay 0.96/0.25, lingers 0.92/0.2, a bee every 40).
- **Scene:** #5, #6, #7 (dusk by phase, a whiter noon), #15 (the snap glyph at small sizes: `TrapArt.snapGlyph` gains
  a simplified silhouette under 24 pt), the pop/toast clearance (the Scene exposes live pop rects; App keeps the hint
  plate off them), and the trap art for #16 (a `TrapArt.trapImage(style: .threeQuarter …)` variant, or an open trap
  with a sipping bug, for App).
- **Feel:** QA-2 #16 (fade stolen voices over ≥ 5 ms; no clicks on two quick big bites), plus any other QA-2 Feel
  items.
- **App/UI:** #2 (demo defaults and freeze tags), #3, #4, #8 (the fold-as-input diagram ≥ 120 pt and off the trap;
  pose card as one trap across the hinge with hands; the lesson step-2 Duo capture), #9, #10, #13, #16 (using Scene's
  art), #18 badges, #19 lesson consistency, and QA-2's App items (#2/#3 numeral truthfulness, #10 dry snap and the
  hunger pulse, #11 the Daily-first case).
- **Icon artist:** #17 (only `Snap/UI/AppIconArt.swift`).
- **CI (founder):** #1 via duo.yml (running), the dusk wave-18 frame, the new freeze-tag scenarios, logging the
  BalanceTests table.

Rules as before: only your own folders; re-read twice for compile errors; exhaustive switches; notes in
`design/notes/<module>-R4.md`.
