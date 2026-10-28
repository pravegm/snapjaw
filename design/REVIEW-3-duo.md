# Review R3: iPhone Duo specialist

**Score: 6 / 10 (provisional, for the third round running).** R3 did more Duo work than any round so far:
- the crease clearance (Core);
- the HUD placed from the real cilia outline, with a 951 × 669 test (App);
- the fold-input diagram on Home, the lesson and the pose card;
- the "Snap the halves together" first-wave copy;
- the inner-top hint slot;
- a deterministic pilot.

But **not one R3 frame is at the Duo's aspect**:
- every log says `canvas 874x402`, including `fold=1` (03, 22, 23);
- `artifacts/duo2/` and `duo3/` don't exist;
- the only Duo evidence is still R1's `duo1` (951 × 669: the trap spans x 95–1905 of 2000).

The score moves up by one for the work that tests can check. It can't go higher until a Duo-aspect frame exists.

## R2 items: fixed / not fixed
| R2 # | Issue | R3 status |
|---|---|---|
| P0-1 / #6 | Run duo.yml; a 951 × 669 letterboxed `fold=1` | **Not done.** `fold=1` only toggles copy and layout flags on the 874 × 402 canvas: 22 is pixel-identical in layout to 21 apart from HUD nudges (score at 1755 vs 1765; glyph rows 1565–1820 vs 1545–1835). |
| P0-2 / #1 | Jaw clamped to the open outline at 951 × 669 | **Claimed by test** (`theBiteStaysInsideTheOpenTrap` at both sizes). On the phone it holds (13, 14, 18). Unseen at Duo aspect. |
| P0-3 / #5 | No resting within r + 16 pt of the crease | **Rules done** (Core: 459,578 resting frames, 0 too close). **Frames still show bugs at the midrib:** 10 housefly (960,250) touching the seam's left edge; 11 gnat (990,355) on it; Home attract 01 fruit fly (1020,630) and 36 housefly (1080,580). They are probably flying or walking, since Core allows crossings. But on a Duo, a sprite crossing the 20 pt hinge gap with no flight shadow reads as resting in the gap. **Badges** `bite5` and `feast` put a fruit fly on the midrib. |
| P0-4 / #4 | HUD ≥ 8 pt off the cilia at 951 × 669 | **Phone: fixed** (23: glyph rows x 175–455 clear the cilia by about 100 px; 22: the score, pause, chip and rows are all on the bog). **Duo: test-only.** |
| P1-5 | Thumb-safe landings | **Not addressed** in any R3 note. 12: the bee enters at the right edge mid-height (1930,620); 11: the bumblebee is at (1630,210) under Pause. |
| P1-6 | Hint slot off the thumb band | **Moved** to the inner top (11, 12, 18, 24: plates at 1060–1470, 20–160), which on the Duo is the top of the right page next to the hinge. Good choice, unseen at Duo aspect. On the phone the plate covers the right lobe's top cilia and, in 18, a dragonfly (1190,170). |
| P1-7 | 60 fps Home thermals | **Not addressed.** |
| P1-8 | CI hinge evidence | **Better:** the pilot now produces real snap durations (`d=0.140`, `0.352`). Real-device `SNAP-H` logs are still missing. |
| P2-9 | Pose clap and cover score | **Partly:** the 31 pose card is TrapArt with 138° (label clipped); the 32 cover score is clipped. |
| P2-10 | Droop pinned at the midrib | **Claimed**; no hunger frame (33). |
| P2-11 | `hudLeft` mirrors the lesson card | **Not verified:** no `hudLeft=1` lesson frame. |

## Fold as the input (founder call)
- **Home (03):**
  - the `DuoClapDiagram` sits at 1610–1770, 235–400: about 65 pt tall, half on the right lobe's cilia, and still in
    the demo;
  - the menu shrank Feed to fit it;
  - it is the right idea at a third of the right size.
  - On a 951 × 669 Duo the right page has about 150 pt between the menu and the outer edge. Give the diagram that
    whole column (or a row above Feed), animated, ≥ 120 pt.
- **The lesson:** no `fold=1` lesson frame exists. Step 2 on a hinge must show the diagram, and CI must capture it.
- **Pose (31):** the clap glyph and 138° are there. The two-panel book is good. The trap is split into two images
  with two stems, and there are no hands.
- **First-wave hint:** absent even on the phone (10). Unseen on a fold.

## P0
1. **A Duo-aspect render, now.** Letterbox 951 × 669 on the phone sim (scale 0.6 and centre, with the fold band
   forced), or run `duo.yml`. Minimum set:
   - Home `fold=1`;
   - lesson step 2 `fold=1`;
   - 10 landed, 13 hold, 21 open-after-bite, 18 last snap with the hint;
   - 23 HUD left;
   - 24 half shut;
   - Results, cover.

   No Duo-first game should go to TestFlight without having been seen at its own aspect for two rounds.
2. **The real Duo checklist** from REVIEW-1-duo ("Must be verified") is untouched for the third round:
   - snap `d` distribution;
   - creep false positives at rest;
   - the 22° depth at 135° and at 170° rest;
   - the blurred-half timing over the HUD.

   The founder's TestFlight build is the only source. Record a `SNAP-H` log of 50 snaps.

## P1
3. **The hold on the Duo.** On the phone the hold is 18–35 % of the width. On the Duo the open trap is about 95 % of
   the width, so the hold will be a narrow pod in a huge empty bog, on two pages, split by the hinge. Check it at
   951 × 669. It may need a wider closed size (≈ 45 %) to keep the screen full at the hero moment.
4. **Crease crossings.** Any sprite inside ±(20 + r) pt of the crease must be visibly airborne:
   - a shadow offset;
   - a 1.1× scale;
   - a wing blur.

   On the Duo, the hinge gap physically eats about 20 pt. A fly drawn across it is cut in two.
5. **Thumb-safe entries.** No landing or entry within 80 pt of either outer edge in the middle 50 % of the height
   (R1 #6, R2 P1-5). Bias entries to the top and bottom edges.
6. **Home thermals.** Drop the attract scene to 30 fps after 5 s idle, and pause it under the Book and Settings blur.

## P2
7. **The badges' trap art** puts bugs on the midrib (`bite5`, `feast`). Apply the same crease rule there.
8. **The cover display.** "Open it up to carry on" plus the subtitle plus the score must fit the cover's smaller
   screen. 32 already clips at 402 pt.
9. **The `hudLeft=1` lesson frame:** capture it, so the lesson card and pointer origin are seen mirrored.
