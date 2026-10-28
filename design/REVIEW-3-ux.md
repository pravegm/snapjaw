# Review R3: game UX and onboarding

**Score: 7 / 10** (R1: 4, R2: 6). The resource is now taught:
- the snaps row appears from lesson step 2 (05–08);
- the closing card rings it with "These are your snaps ↘" (09);
- the first Feast labels its flying glyph "+1 snap" (13, 14, 21–23).

The other R2 fixes:
- the hint plates never clip (18);
- the bee lesson puts the bee on a drop beside the flies (07);
- the Results copy is right ("Best chain ×2 · 2 big bites", "New best! was 3,200");
- the Bug Book wraps "Golden Scarab";
- the Debug string is gone.

What holds UX back now:
- the key teaching toast collides with a pop and names the wrong bug;
- the first-wave hint is missing;
- the chain is still never explained;
- the first run is still 75 s for a novice;
- scroll chevrons and labels overlap content in three screens.

## R2 items: fixed / not fixed
| R2 # | Issue | R3 status |
|---|---|---|
| P0-1 / #3 | Truncated climax hint | **Fixed** (18). |
| P0-2 / #12 | Teach the resource | **Fixed** (05–09; "+1 snap" tag in 13). |
| P0-3 / #9 | First run ≥ 90 s | **Half.** The rules are in: no wilt and a free first sting (15 log: `stung … cost=0`, `toast bees-cost`). But the CI novice's Sprout run 1 lasts **75 s** (log 20: `run score=419 bugs=21 snaps=17 seconds=75`), and Results 20/27 is what a first-timer sees. The sim's casual pilot (154 s) isn't a first-timer. |
| P1-4 / #11 | The glyph reads as a melon | **Better, not solved.** It is no longer pink and green. But at 16 pt (05–35) the crimson oval with a white comb still reads as **lips or a mouth with teeth**. Empty slots are grey outlines (good). The hunger pulse is unverified (33 has no hunger). |
| P1-5 / #18 | Bee on the rim | **Fixed** (07). The pointer's arrowhead lands on the fly above the bee (880,370), not the bee: aim it at the bee ring's edge. |
| P1-6 / #15 | Hunger copy | **Unverified.** 34 shows no wilt (see the summary: CI runs every demo as Sprout run 1, which never wilts). |
| P1-7 / #24 | Results wording | **Fixed** (20, 26). |
| P1-8 / #19 | Bug Book | **Fixed:** names wrap and counts vary. **New:** the chevron sits on joke text (28: "for her"; 29: "Absolutely not on the menu"). |
| P1-9 / #20 | Settings debug, Credits | **Debug fixed.** The Credits chevron overlaps "eaten." (30). |
| P2-10 | 05 = 06 | **Still identical** (05 and 06 are both "Step 2 of 4"). |
| P2-11 | Home hinge copy | **Fixed on fold layouts** (03: "Snap it shut a little. It bites!"). |
| P2-12 | Cover score | **Added but clipped** (32: "400 so far" is cut off at the bottom edge). |
| P2-13 | "Now!" over a spread | **Better:** clusters exist (12: three drops at 1110–1170, 255–320; 17: three at 1210–1280, 320–380). In 24, "Now!" still fires on bugs spread across both lobes. |

## P0
1. **The rule toast (15).**
   - "Bees cost a snap!" covers the "Stung!" pop. It fired for a **wasp**, and it says "cost" on the one sting
     that cost nothing.
   - A new player reads it as "I just lost a snap", which is the opposite of what happened.
   - The copy: "Bees and wasps cost snaps. This one's free!" (or species-aware: "Wasps cost 2 snaps! This one's
     free").
   - Place it in the hint slot (inner top), and delay the pop or move it below the ring when a toast is up.
   - Add a test: no plate rect intersects a live pop rect.
2. **Cover card clipped (32).** "400 so far" falls off the screen. On the Duo's cover display the room is smaller.
3. **CI shows a first run everywhere.**
   - 38 logs say `first run options`, so every play demo is a Sprout run 1: hunger is off, and the first bee is
     free.
   - That is why 33 and 34 are `no-freeze / expect-miss`. The hunger pulse, the red numeral, the droop, "Hungry…
     bite!" and "Too slow! −1 snap" have **never been rendered** since R2.
   - The App should honour `progress=` (or a new `firstRun=0`) in play demos.

## P1
4. **The first-wave hint is missing (10).** Wave 2, before any snap: no "Tap to snap" plate (App-R3 says it shows on
   phones). A first-timer who skipped the lesson gets no instruction. Capture `freezeOn=firstHint`.
5. **The chain is never explained.**
   - The chip is a link icon plus "×2" (11, 25, 35) or "×1.5" (13), with no word on the phone.
   - The lesson card doesn't mention it either.
   - Add one sentence to card 09: "Big bites in a row build a chain".
   - Give the first `chainUp` of a player's life a one-time tag over the chip: "Chain ×1.5: keep the big bites
     coming".
6. **First run length.**
   - A novice Sprout run 1 is 75 s and 21 bugs.
   - Levers:
     - a run-1-only "Missed! This one's free" for the first 3 dry snaps (novices waste snaps on empty bites);
     - or Sprout run 1 starts at 14 (`maxSnaps` is 14 now).
   - Target the *novice* pilot ≥ 90 s for run 1.
7. **The lesson's snap count lies.** The lesson shows **10** (05–09), but Sprout's first run starts at **12** (10, 12,
   16). Show the row the player will actually get.
8. **The Daily label (25)** overlaps the pause button.
9. **The chevrons** (28, 29, 30) overlap text: add a fade gutter.

## P2
10. **The snaps numeral.** On the phone it sits left of the rows (05–35), on the inner side. In 23 (HUD left) it is
    right of the rows. Good, but "12" next to 12 glyphs still duplicates. Consider showing the numeral only ≤ 3, or
    only when it changes.
11. **Home's fold diagram (03).** About 65 pt tall, on the lobe's cilia, with "Snap it shut a little" in 2 lines of
    16 pt. It is the only place a store screenshot could show that the fold is the input, and it is the smallest thing
    on Home. Make it a 140 pt looping card between the title block and the menu.
12. **Pose (31).** The "138°" label is clipped. Add hand silhouettes: "like a book" needs hands.
13. **"Protein" as the score word.** Fresh 4 paused on it ("I thought it was a diet app"). Keep it
    (it's charming), but the first Results could add "protein = points" once.
