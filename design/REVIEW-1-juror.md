# Review R1 — Apple Design Award juror (visual craft)

**Score: 5 / 10.** The painted bog (moss cushions, sundews, lily pads, dew) is genuinely lovely and the bug faces
have charm. But the game's hero object doesn't read as a flytrap, the frames carry a large rendering artefact, half
the HUD text is truncated, and the menus look like a different, flatter app. Right now it doesn't look like £1.99.

## What works
- The bog backdrop (04–25): rich, cohesive, well lit top-left, nothing cheap in it.
- The bug art is charming when it's big enough to see: dragonfly (15), golden scarab (18), grasshopper (12).
- SF Rounded Heavy for the score and the cream/gold/crimson pill system is a sound base (10, 11, 18).
- Results (20, 26): the 3-D "7,450" number is the best piece of typography in the build.

## Fixes (prioritised)
**P0**
1. **The rendering artefact.** Long, tapered, pale streaks 600–1100 pt long cross the scene in 10, 11, 12, 18, 19,
   21, 22, 23 (they pass through flying bugs). It reads as a broken build. Find the runaway sprite (suspect a
   `BogBugNode` child: wings/blur, or a pooled flash with a stale size) and add a test that every bug child's
   accumulated frame stays ≤ 6× the bug radius.
2. **It's a watermelon, not a flytrap** (every play frame). The lime band is a rind, the pink flesh and the radial
   veins finish the joke, and the pale trigger hairs read as seeds. Remove the lime rind band; make the margin a thin
   dark-green lip with a 24–32 pt green leaf exterior visible outside it; deepen the face (≈#7A0C26 at the midrib →
   #D23048 at the rim); make the teeth 1.5× longer and 40% thinner (cilia, not spikes).
3. **Truncated HUD text in every play frame:** the chain chip says "Chain…" (10–14, 17, 21–25), and the snap
   numeral clips "12" to "1" (11). Truncation in the HUD is disqualifying at this price point. See UX fixes 1–2.
4. **Two art languages.** Home (01–03) and the cover card (32) use a flat vector trap (`TrapPortrait`) with a pink
   smudge highlight; the Bug Book and Results portraits (20, 26, 28, 29) are a generic oval-and-two-eyes template in
   which the bee, bumblebee, wasp and firefly are all olive blobs with no stripes. The in-game bugs are painted and
   striped. Use `TrapArt.bugImage` (the Scene already exposes it) for every portrait and a rendered scene trap on Home
   and the cover.

**P1**
5. **Bugs are the subject but the smallest thing on screen.** A housefly is ~20 pt on the phone and 28 pt on the
   Duo, smaller than the gold nectar drops (04, 10, 17). Scale bug art ×1.8 and shrink the drops 30%.
6. **Gold overload.** Nectar drops, sip rings, the chain chip, score pops, the scarab and the Feed button are all
   the same gold; the sip ring vanishes on a gold drop (10, 13). Keep gold for score and nectar only. Make the sip
   ring lime-white.
7. **Menus have no world.** Results, Bug Book and Settings (20, 26–30) are flat green slabs. Put the bog backdrop,
   dimmed 45% and blurred 12 pt, behind them so the app feels like one place.
8. **Home composition (01–03).** The title and tagline sit on the trap's rim, with teeth poking through "Snapjaw" and
   "Tap the trap". A stray pink ellipse sits behind "Spare bees". There's a background seam at x≈1875/2000 on the
   right (the background stops at the safe area). The "bee" is a dull olive beetle.
9. **Night and dusk tint (12, 15, 17)** turns the crimson into magenta, so the trap loses its identity at night.
   Keep the lobe's hue: put a 25% normal-alpha blue over the lobes and keep multiply for the bog only.

**P2**
10. **Icon (app-icon-1024.png).** Good idea, readable, charming fly. But the lime midrib line runs straight through
    the fly's body (it looks skewered). The white fangs don't match the game's cilia, and the flat vector style
    doesn't match the painted game. Remove the line, use interlocking cilia, add the scene's gloss, and grow the
    subject to ~85% of the canvas.
11. **Settings (30).** The back button overlaps the Replay First Bite card, the About card's right edge doesn't line
    up with the buttons above it, and Credits is cut off with no scroll cue.
12. **Pose card (31).** The diagram (a pink book with ladder rungs) is static and empty-feeling. Show the clap: two
    frames or an animated 22° close with a little fly.
