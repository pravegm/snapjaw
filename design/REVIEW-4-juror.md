# Review R4: Apple Design Award juror

**Score: 7 / 10** (R1: 5, R2: 6, R3: 7). R4 fixed most of what I flagged in R3, and much of it landed well:
- the shut trap now shows green leaf backs with a crimson seam and interlaced cilia (13, 40), so it finally reads as a
  closed flytrap;
- the face has no peach rind (10, 38);
- the cover fits (32);
- the free-sting toast sits in the hint slot, clear of the pop (43);
- dusk has its own light (12, 16, 37).

I am holding the score at 7, not raising it, for three reasons:
- **The pose card (31) is visibly broken in this build.** It is the one screen whose only job is to show the Duo pose.
- **The trap mid-release reads as a dark plum, or a bottom** (14, 18, 19, 39, 41, 42, 43). That is the frame a
  Feast screenshot catches, so the R3 "pod / bum" read has moved from the hold to the reopen.
- **No R4 frame is at Duo aspect**, and the only Duo-aspect frames there are (R3 build, `artifacts/duo3/`) show the
  hinge checks INCONCLUSIVE, because the simulator died twice.

Frames: `artifacts/r4/screenshots/` (iPhone 18 Pro, 874 × 402 pt, tap build, deterministic pilot; standard rules
unless the scenario says first run). Every log says `canvas 874x402`, including `fold=1` (03, 22, 23). Coordinates are
in the 2000 × 920 preview.

## R3 items: fixed / not fixed
| R3 # | Issue | R4 status |
|---|---|---|
| 1 | No Duo-aspect evidence | **Not fixed for R4.** `artifacts/duo4/` doesn't exist. The R3 Duo run (`duo3`, 951 × 669) is the first Duo-aspect evidence since R1, but `checks.tsv` reads SNAP / REARM / CREEP / CLOSE-PAUSE **INCONCLUSIVE** (simulator shut down twice, 6 failed hinge calls). |
| 2 | Every demo was a Sprout run 1 | **Fixed.** Only 27 and 43 log `first run options`. 33 and 34 finally show hunger and the wilt; 40 shows a costly sting. |
| 3 | Toast over the pop | **Fixed** (43: "Bees and wasps cost snaps. This one's free!" bottom-inner, pop clear, row lime with "free!"). |
| 4 | Cover clips its score | **Fixed** (32: trap beside the words, "400 so far" whole). |
| 5 | Peach face | **Fixed in play** (10, 38: oxblood→crimson, a thin blush only at the lip). **Partly back at dusk:** 16 and 37 show a salmon glow ring at the margin, and the face turns coral. |
| 6 | Hold reads as a pod / bum | **Hold fixed** (13, 40: green backs, crimson seam, one width; no bugs on top in 13). **New: the release** (14, 18, 19, 39, 41, 42, 43) is a dark oxblood rounded shape, x ≈ 620–1380, with a vertical crease and no green rim, and it reads as a plum or a bottom. |
| 7 | Dusk invisible | **Fixed, with a new tone problem:** waves 15–22 (12, 16, 37) have their own olive-khaki light. It reads as "sickly" more than "peach". Night (35) is right. 17 was frozen during the 1.2 s ease, so it still shows dusk. |
| 8 | Fold as input | **Better on Home** (03: a 120 pt card, "Snap it shut a little", 138°). **Pose card broken** (31, see P0-1). |
| 14 | Bugs on the midrib | **Mostly fixed by rule.** In the frames, 10 (housefly at 960,250) and 41 (fruit fly at 985,780) still sit on the crease with no airborne cue. |
| 16 | Isolated trap is anatomical | **Fixed as a 4+ risk.** It's 3/4 now (20, 26, 27, 32). **New problem:** red speckled face over a ribbed green bowl, which reads as a **watermelon wedge** (see P1-3). |
| 17 | Icon | **Fixed** (see Icon below). |

## P0
1. **The pose card is broken (31).** What the frame shows:
   - a black region over the top-right quarter;
   - the green panel offset to x 0–1630, y 370–920;
   - the Duo diagram rotated to portrait, with two trap images overlapping (430–760, 220–830) and a third cropped at
     the bottom (1000, 900);
   - "138°" turned sideways (190, 520);
   - the hands drawn as beige sticks (430, 290; 320, 800);
   - "Ho" and "The" washed out under a translucent overlay.

   The R4 note says the drawing now "scales to fill the page". On a 402 pt-tall landscape page that produced this.
   Fix the layout at 874 × 402, 951 × 669 and the portrait/tabletop sizes, with a snapshot test, and capture it on the
   Duo run.
2. **The reopening trap reads as a plum or a bottom (14, 18, 19, 39, 41, 42, 43).** For about 0.3 s after every bite,
   the lobes are dark oxblood, narrower than the open trap, with the cilia reduced to faint inner ticks and no lime rim.
   39 ("FEAST ×5 · +915") is the most store-worthy moment in the set, and it is exactly that silhouette. Keep the lime
   rim and the outer cilia drawn through the release, lift the face to the open-state crimson within ~80 ms, and don't
   darken the edges on the reopen (darkening should track closure only while closing). Store bite shots should use the
   21/22-style open-after-bite frame.
3. **The HUD contradicts the banner (19, 40).** In 19, "Your trap is tired. Out of snaps" shows over a snaps numeral
   of **1** with one full glyph. In 40 the numeral is **2** with two glyphs. 15, the same moment slightly later, shows 0.
   The tired banner arrives before the numeral drop (`crackLead` 0.15 s plus the 50 ms hit-stop). Hold the banner until
   the numeral has reached 0, or drop it at once on the final bite.

## P1
1. **Hungry while a bee is in the trap (33, 34).** In 33, "Hungry… bite!" shows while a bee with its white halo sits
   on the left rim (570,650). In 34 a snap wilts with a haloed bee at (1505,515). In the logs those bees haven't
   "landed", so the clock runs, but on screen the game says "Never eat a bee" and "bite!" in the same frame.
2. **A costly sting doesn't say what it cost (15, 40).** The pop is "Stung!" alone. The only cost signal is the row's
   crimson flash, and because it was the run's last snaps, both frames are also the run's end. The free sting says
   "free!" (43). Say "−2" on the costly one too, and capture a mid-run costly sting.
3. **The 3/4 trap reads as a watermelon wedge** (20, 26, 27, 32; badges `daily`, `feast`, `monarch`, `nobees`,
   `score10k`). The stippled red cap over a ribbed green dome is almost exactly the fruit we spent R2–R3 removing.
   It's also a different illustration from the icon, which has an open jaw, a lime lip and cilia on both lips. Make
   the hero trap the icon's trap: open jaws, cilia on both lips, no stipple on the face at this size.
4. **Dusk tone (12, 16, 37).** The bog goes olive-khaki, and the trap rim gets a salmon ring. Push the haze toward
   warm peach/rose, and keep the warm rim light off the lobe margin.

## P2
1. Home: the menu still covers most of the right lobe (01–03, 36), and the attract fly sits on "bees." (01: 800,370;
   02: 790,400). 03 repeats "Snap it shut a little" twice.
2. Pops collide: in 42 a snap glyph flies across "Golden!" (1180,265); in 18 "DOUBLE ×2 · +32" sits on a bug (830,750).
3. Bug Book 29: "Golden Scarab" wraps and pushes "Caught 1x" into the fade.
4. A black Dynamic Island pill appears at the left edge in 03, 05, 15, 16 and 17 but not in the others. Keep it out
   of the store set.
5. 41, the dry snap, has no feedback at all: no "Missed", and no chain-lost cue.

## Icon (store asset): **8 / 10** (R3: 7)
- It's the strongest single asset in the set. The jaw is open, the lime lip is glossy, the crimson throat shows both
  lobes' faces, and the in-game grey housefly peeks out with cream eyes and pink cheeks. It is cute, readable and on
  brand.
- The fly is about a third of the trap's width, as briefed, and the colours now match the game.
- **Off note:** the two dark dots on the front lip (480,710 and 595,690), the fly's "hands", read as nostrils at
  60 px. Together with the jaw they make the trap look like a smiling creature's face. Lighten or drop them.
- It's still a different drawing from the in-game 3/4 trap (see P1-3). Unify toward the icon.

## Badges (store/Game Center set): **7 / 10** (R3: 7)
- **Good:**
  - `bite5` (a ring of five bugs) and `feast` are no longer duplicates;
  - `spare50` (bee in a dashed halo) vs `nobees` (bee flying off a dashed trail) now differ;
  - `scarab` has elytra;
  - `chain4`, `bugbook`, `dragonfly` and `night` are crisp and readable.
- **Not good:**
  - five of twelve (`daily`, `feast`, `monarch`, `nobees`, `score10k`) are the same watermelon-like 3/4 trap, so the
    set feels samey in the Game Center grid;
  - the petiole leaf breaks the medallion ring on `daily`, `feast`, `monarch` and `nobees` (lower left);
  - outlined bugs sit on an outline-free trap, so two drawing styles meet in one disc.
