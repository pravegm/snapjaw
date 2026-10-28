# Round 3: make it a flytrap, make it fair (brief)

R2 compiled (215 tests). Panel: juror 6, UX 6, feel 6, Duo 5 (provisional), fresh players 6 / 7 / 5
(`design/REVIEW-2-*.md`, `design/fresh/`, merged list `design/REVIEW-2-summary.md`). Frames: `artifacts/r2/`, the Duo
simulator R2 frames in `artifacts/duo2/` (once downloaded).

**Do every item in REVIEW-2-summary #1–#25 in your module**, plus the founder calls below.

## Founder calls
- **Art direction for the trap (#2, the founder's own words; this overrides the critics' hex values if they clash).**
  A real Venus flytrap seen from above, not a fruit slice:
  - **Two distinct lobes**, each a rounded clam/kidney shape, meeting at a visible **midrib seam** on the fold. A
    narrow dark gap shows between the lobes' inner edges near the top and bottom of the midrib, so it reads as two
    leaves hinged together, not one ellipse.
  - **No hard rind band.** The face is a soft radial gradient: deep crimson/oxblood at the midrib → crimson → a warm
    yellow-green blush only in the last ~10 % before the margin. The outer leaf back shows only as a thin dark-green
    lip and the cilia bases.
  - **Texture:** stippled red glands (many tiny darker dots, clustered toward the midrib), fine veins radiating from
    the midrib, one soft wet specular per lobe. No pale "seed" dots.
  - **Cilia:** long, thin, slightly curved, pale-green to cream at the tips, densely spaced (60–80 in total), with a
    subtle shadow. Teeth never look like fangs.
  - **The stem:** a green petiole leaf from the bottom centre into the bog, so the trap is plainly a plant.
  - Same art in `TrapArt.trapImage` (Home, cover, Results) and the snap glyph (#11: a mini closed trap, cilia
    interlocked).
- **The bite (#1):** the jaw may never draw outside the open-trap outline. The lobes squeeze toward the midrib, the
  cilia interlock across the gap (the two outer margins meet in the drawing), and there's a dark interior. No green
  ellipse.
- **Economy (#7, #8, #9, #22, #23): yes to all**, with these numbers: wilt 18/16/14/12 s, the timer starts on the first
  in-trap landing after a bite; a stinger bite gets no Feast/chain refund and scores ×1; Sprout run 1 never wilts and
  its first bee costs 0 with the toast "Bees cost a snap!"; chain cap ×5 at step 8; `maxSnaps` 14 (two rows of 7).
  Sim targets: perfect ≤ 6 wilts and 4–8 min; casual ≤ 2 wilts, 100–240 s, longest chain 3–6; Sprout run 1 ≥ 90 s for
  the casual pilot.
- **The Duo's fold must be visible as the input** (all three fresh players only saw "tap"). On a device with a hinge:
  Home shows a small looping DuoDiagram "Snap it shut a little" next to Feed; the lesson's step 2 and the pose card
  show the 160° → 138° clap; the hint on the first wave of each run says "Snap the halves together". On phones the copy
  stays "Tap to snap".
- **Deterministic CI pilot (#21):** yes.
- **Badges:** the App adds `screen=badges` (renders the 12 Game Center achievement images 512 × 512 to Documents and
  prints `SNAP-BADGE <id> <path>` per image), like Swoop's `screen=badges`; art: each a round medallion in the game's
  style with a drawn subject (bug, trap, chain, bee…).

## Owners
- **Core:** #5, #7, #8, #9 (rules side), #16, #22, #23, deterministic pilot (#21, with CI). Sim in lockstep.
- **Scene:** #1, #2 (founder art direction above), #10, #14, #15, #17, #25.
- **Feel:** sound for the new moments (the "Bees cost a snap!" toast, chain ×5 flare, "Too slow! −1 snap"), and make
  the sting read in audio as "you lost something" (a short descending two-note blip after the Bzzt).
- **App/UI:** #3, #4, #9 (toast), #11 glyph, #12, #18, #19, #20, #24, the Duo fold diagram on Home/lesson/pose, the
  first-wave hint, `screen=badges`.
- **Icon artist (separate, owns only `Snap/UI/AppIconArt.swift`):** #13.
- **CI:** #6 (a 951 × 669 letterboxed `fold=1` set), #21 freeze timing, a no-bite night frame, badges render step.

Rules as before: only your own folders; re-read twice for compile errors; exhaustive switches; notes in
`design/notes/<module>-R3.md`.
