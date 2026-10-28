# Round 5: the last blockers (brief)

R4 compiled (283 tests). Panel: juror 7, UX 8, feel 8, Duo 6 (prov.), fresh players 7 / 6 / 7, icon 8, badges 7
(`design/REVIEW-4-*.md`, `design/fresh/tester7-9.md`, `design/REVIEW-4-summary.md`). Frames: `artifacts/r4/screenshots/`;
Duo-aspect R3 frames: `artifacts/duo3/duo-screens/duo-screens/` (R4 Duo: `artifacts/duo4/` once downloaded).

**Do REVIEW-4-summary #2–#14 in your module.** CI items (#1, #11, #15) are the founder's. The founder's calls:
- **Words (#13):** the score word becomes **"score"** everywhere in the UI (HUD caption, Results, Home). The
  leaderboard stays "Best Feast". Settings "HUD on the left" becomes **"Score on the left"**. Card 09 is at most 3
  short sentences.
- **Hungry vs bee (#5):** the rule from R4 stands (no hunger while a protected bug is in the trap). Count a protected
  bug as "in the trap" from its final approach (inside the zone and below `creaseAirHeight`, halo drawn). As a belt
  and braces, the App never shows the hungry plate while a halo is inside the zone; it shows "Bee! Wait…".
- **Sting cost (#7):** "−1 snap" / "−2 snaps" at the row, mirroring "+1 snap".
- **Sprout run 2 (#8):** taper the perks: run 1 has 14 snaps, no wilt, a free sting and the calm morning; run 2 has
  13 snaps, a free sting and the calm morning; run 3 has 12 snaps and the calm morning. From run 4 the rules are
  standard. Sim target: novice run 2 ≥ 75 s and run 3 ≥ 60 s.
- **Daily share (P2, a player asked):** a "Share" button on the Daily results that shares one line of text, e.g.
  "Snapjaw Daily Bog #301 · 4,210 · biggest bite 6 🪤", with no link until launch. Use `ShareLink`.
- Not in 1.0: a relaxed mode. Note it in `docs/PROJECT-LOG.md` ideas.

## Owners
- **Scene:**
  - #3, the release frames: keep the rim and the outer cilia, return to crimson within about 80 ms, and darken only
    while closing.
  - #6, one hero trap: redraw `.threeQuarter` from the icon's geometry, with no stipple at hero size and a sipping
    fly.
  - #9, the dusk tone.
  - The airborne cue for flyers over the crease (#15).
  - #10, the "Missed!" puff at the seam on a dry snap.
  - #12, the pop collisions on the scene side.
- **App/UI:**
  - #2, the pose card: rebuild it simply and robustly, with a snapshot or layout test at 874 × 402, 951 × 669 and
    portrait.
  - #4, sequencing (with Feel): the tired banner never shows while the shown snaps are above 0. Add a test.
  - #5 belt and braces, #7, #12 on the App side, #13 words, #14 badges, the Daily share, and the lesson step
    numbering (#11: the same "Step n of N" on the Duo and phones).
- **Core:** #5 (the protected bug counts from its final approach), #8 (the taper, sim and tests), and #15's thumb-band
  rule: bee entries never start in the outer 90 pt at mid-height on either side.
- **Feel:** #4, the yawn/banner after the drop (`afterLoss` ≥ 0.45 s); #10, a hollow dry-snap "clop" with no
  squelch; a heavier wasp sting wobble.

Rules as before: only your own folders; re-read twice for compile errors; exhaustive switches; never put rethrowing
calls with key paths inside `#expect`; never shadow a property with a local of the same name; notes in
`design/notes/<module>-R5.md`.
