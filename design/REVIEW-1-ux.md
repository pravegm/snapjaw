# Review R1 — game UX and onboarding

**Score: 4 / 10.** The structure is right: one resource, a clear HUD corner, a lesson of one sentence per step, and
honest Results. But the lesson doesn't show the thing it names, the HUD truncates its two key numbers, and in the
5-second read of a play frame you can't tell catchable bugs from nectar or from bees.

## The 5-second read (play frames)
- **10-play-landed:** I see gold balls (nectar) first and bugs last. The one sipping fly's gold ring is lost on its
  gold drop.
- **11-play-crowd:** "Now!" sits bottom-right while the crowd is top-left. The three ringed bugs are tiny, and the
  streak artefact draws the eye more than they do.
- **12-play-bee:** The bee has a gold sip ring *and* a white halo, the same treatment as a catchable fly, with a
  sparkle on top. Only the red "Bee! Wait…" pill tells you. **A protected bug must never show the "catchable" ring.**
- **13-play-snap:** I can't tell a bite happened except for the tiny "+10".
- **14-play-feast:** Four stacked lines ("+255 / FEAST ×5 / chain ×1.5 / Feast! +2 snaps") straddle the midrib.
  "chain ×1.5" is dark olive on crimson (low contrast).
- **15-play-sting:** "Bzzt!" is drawn on top of the bee it's about.
- **18-play-last-snap:** Good, clear warning. **19-play-tired:** Clear.

## Fixes (prioritised)
**P0**
1. **Chain chip truncates to "Chain…"** in every frame (10–14, 17, 21–25). `HUDLayout.chain` is 104/120 pt wide, too
   narrow for the link glyph plus "Chain ×1.5" in 17 pt heavy. Add `.fixedSize()` to `ChainChip` and size the rect
   from it, or show just "×1.5" with the glyph.
2. **Snap numeral clips "12" to "1"** (11): the 12 icons squeeze the `Text`. Give the numeral `.fixedSize()`, and
   when there are more than 10 slots shrink `snapIcon` 22 → 18.
3. **Lesson step 2 has no sipping** (04). The log shows the fly landed at (548, 341) with no `bugSipping` event, so it
   isn't on a drop while the card says "When it's sipping… tap to snap!". Spawn it at `snapshot.nectar[k].position`
   exactly (Core's rule). The same goes for the flies in steps 4 and 6 (05, 06, 08), which sit *beside* drops.
4. **Point at the bug.** The target fly is ~20 pt on a ~550 pt trap. In every lesson step, draw a pulsing
   ring plus an arrow from the lesson card to the target bug or bugs. In step 6, show "Now!" only when all three are
   sipping.
5. **The bee step can't be learned** (07). The bee lands and is "spared" within ~4 s, and the frame at 8 s already
   shows step 6. Raise the lesson bee's linger 3 → 6 s, show the in-game "Bee! Wait…" hint, and put the halo on
   screen long enough to learn it.
6. **Protected bugs never get the sip ring** (12, 16). Bees: a white 3 pt ring at r×1.6, pulsing. Wasps: the red one.
   Catchable sippers: a lime-white ring (not gold, which is nectar and score).
7. **Bug Book jokes are truncated** in every card (28, 29). The joke is the reward. Use `lineLimit(3)` with
   `minimumScaleFactor(0.85)`, or tap to flip the card. The 4th row is cut off with no scroll cue (show a row peek or
   a fade), and the back button overlaps the top-right card.

**P1**
8. **Step numbering on a phone:** "STEP 2 OF 6", then 4, then 6 (04–08), because the pose step is skipped. Number
   the visible steps 1–5.
9. **Phone wording for step 4:** with taps, speed means nothing (`d = 0.09`). Use "Two flies. Get both in one
   bite." On touch, step 3 ("It opens again by itself", 05) is a dead step: merge it into step 2's praise.
10. **Hint placement:** hints sit bottom-outer, on the trap's rim and on the Duo under the right thumb (11, 12, 18).
    Move the plate to the HUD page's inner bottom or under the chain chip, never over the trap interior.
11. **Feast and sting feedback:** merge the Feast pops into one hero line, "FEAST ×5 · +255", and fly the +2 snap
    glyphs from the bite into the snaps row, so the economy is *seen* (14). Offset "Bzzt!" to above the bee
    (y + 2r + 20 pt) and crack the lost snap glyph (15).
12. **Results (20, 26, 27):**
    - "Best bite 4 · 48" is cryptic: use "4 bugs · 48".
    - "Golden Scar…" is truncated: use the short name "Scarab" in tiles.
    - The New-in-Bug-Book row overflows (a ":" fragment at the right edge of 26): wrap it, or end with "+2".
    - "Longest chain 1" reads as nothing: show "×1.5 (2 bites)".
    - A first run (27) should still celebrate ("First run!" or "New best!").
13. **Home, fresh (01):** the rank bar is empty and unlabelled. Show "Catch 10 bugs to grow" under "Sprout".

**P2**
14. Copy consistency: the cover says "Open it like a book" (32), the closing card "Open it a little to carry on", the
    design "Open to carry on". Pick one. The cover card is missing the run's score so far.
15. Score label: "PROTEIN" under the score every frame; switch it to "BEST n" once a best exists (it already does
    that once best > 0, so check that demo progress=mid sets it).
