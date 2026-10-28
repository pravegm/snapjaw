# Review R2: Apple Design Award juror

**Score: 6 / 10** (R1: 5). R2 is a large step. The streaks are gone. The bugs now have character at a glance. Home
is a live, unified scene, and the chain chip and the bee rings finally work. It is not award material yet, for two
reasons. First, the trap still reads as a watermelon. Second, the bite, the game's one hero moment, now turns the
trap into a giant green oval that is bigger than the open trap. On the CI freezes that oval appears in 5 of the 10
play frames, so it would also end up in the store screenshots.

Frames: `artifacts/r2/` (iPhone 18 Pro, 874 × 402 pt, tap build). Coordinates below are in the 2000 × 920 preview of
each frame.

## R1 issues: fixed / not fixed
| R1 # | Issue | R2 status |
|---|---|---|
| 1 | Streaks through flying bugs | **Fixed.** No streak in any of the 34 frames (compare r1/11 with r2/11). |
| 2 | "Chain…" truncation | **Fixed** (11, 13, 21, 23, 25: "Chain ×1.5" fits). |
| 3 | "12" clipped to "1" | **Fixed** (13, 14: "12"). |
| 4 | Bugs too small | **Mostly fixed.** Houseflies and bluebottles read well (12, 16, 17). Gnats and mosquitoes are still specks (14, 18). |
| 5 | Watermelon trap | **Not fixed; arguably worse.** See P0-2. |
| 6 | Bite doesn't read | **Changed, not solved.** It now reads as *something*, but as the wrong thing. See P0-1. |
| 7 | Sip ring on bees | **Fixed** (12: crisp white ring; 15: red-orange wasp ring). |
| 11 | Text on the crease | **Fixed** (19: banner on the right half; 13, 14: pop on the left half). |
| 12 | One art language | **Fixed on Home** (01–03 are the live scene). The pose card (31) is still a separate flat style, and the icon is a third style. |
| 18 | One hero pop | **Fixed** ("TRIPLE ×3 · +66", 13; "FEAST ×6 · +360", 14). |
| 21 | Night keeps the trap crimson | **Not fixed.** The face goes magenta/violet (15, 17). |
| Icon | Midrib through the fly; fangs | The midrib line is gone. **The fangs are worse**: see P1-5. |

## P0
1. **The bite silhouette (13, 14, 15, 17, 18, 19).**
   - On `snapped`, the far-lobe "jaw" draws a green ellipse much wider than the open trap: x 300–1690 in 13 and
     x 110–1880 in 17, while the open trap is x 370–1630 (10). The crimson shrinks to a pupil in the middle.
   - The result reads as a green eye or iris closing, or as the trap zooming out. It does not read as two lobes
     clapping shut.
   - In 14, 18 and 19 the open-trap teeth also stay faintly visible on the olive jaw band, so there are two rings of
     teeth.
   - Fix: the jaw must never exceed the open trap's outline. Each outer lobe edge slides in towards the midrib (the
     green back covering the outer 40% of each lobe), the cilia interlock at the new edge, and everything outside the
     open-trap outline stays bog. Hide the open-state cilia while the jaw is drawn.
2. **It is still a watermelon (every play frame; most of all in 20, 26, 27 and 32).**
   - The face is a light salmon pink, lighter than R1's (compare r1/11 with r2/10). It is not the #7A0C26 → #D23048
     cup the brief asked for.
   - Add the 26 pt bright-green band (rind), the regularly spaced pale dots (seeds) and the snaps row of pink-and-green
     half-ovals (slices).
   - In isolation, the Results and cover trap (20, 32) is a watermelon with spines.
   - Fix:
     - the central 60% of each lobe at most #9A1A33, the rim at most #C42A45;
     - pore dots in a darker crimson (never pale);
     - the green back to 12–14 pt in a deeper #2F5F2B with a dark lip;
     - one specular per lobe, not two;
     - redraw the snap glyph (App/UI, see the summary).
3. **The hint plate truncates "Last snap — make i…" (15, 18).** This is the run's climactic line, on the one plate
   that should never clip. Use a 3-line plate or the copy "Last snap!". Test every `TrapHint` copy at the phone and
   Duo plate widths.

## P1
4. **Dusk is invisible (16, wave 17).** It is indistinguishable from morning (10). Night (15, 17) shifts the lobes to
   violet. The day is a selling point ("the light moves through the day"). Dusk needs a visible peach bog and a warm
   rim light on the lobes. Night should be a blue bog with a crimson trap and glowing fireflies; no frame in R2 shows
   a firefly.
5. **The icon (`app-icon-1024.png`).**
   - Thick triangular fangs, a black throat, heavy black outlines and a side-view mouth: it is a Pac-Man monster. It
     contradicts the in-game top-down glossy plant and the "cheeky, never gross" brief.
   - The brief said cilia, not fangs, and App-R2 claims "12 thin cilia". The rendered icon has about 20 fang
     triangles.
   - Redraw from `TrapArt.trapImage`: the top-down open trap, thin cilia, and a fat cute housefly sipping a gold drop
     at the centre-left (never on the midrib).
6. **The pose card (31)** is a flat rectangle "book" with comb-like lime bars, unlike anything else in the game. Half
   the frame is empty. Use `TrapArt` lobes on a hinged book outline with a 160° → 138° looping fold, and hands.
7. **The scale of incidental text.** The single-bite "+10" pop in 17 is about 12 pt, unreadable at arm's length.
   "wilted −1" (34) is a lowercase 14 pt label. The minimum pop size should be 28 pt, and "Wilted −1" should be a
   glyph-anchored red tag.

## P2
8. Home (01–03): the Feed/Daily/Book stack covers most of the right lobe, so the live attract trap is half hidden. The
   "Tap the trap. It bites!" line sits on the lobe's gloss highlight. Shift the menu 40 pt outwards, or shrink the trap
   on Home to 80%.
9. The mosquito has 8 legs and reads as a spider (12, 16, 18, 28).
10. Results (20, 26, 27): the left column has a 300 px dead band above the trap image, and the backdrop shows a hard
    vertical tone seam at x ≈ 1060 (red-brown | olive).
11. Settings (30) shows "Debug · input touch" in About. Never ship debug strings.
