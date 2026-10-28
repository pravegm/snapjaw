# Review R3: juice and economy

**Score: 7 / 10** (R1: 4, R2: 6). The economy is now fair on paper. `core-R3.md` (16 seeds, 60 Hz):

| skill | seconds | wilts | longest chain | stings |
|---|---|---|---|---|
| novice | 44 | 0 | 2 | 1 |
| casual | 134 | 1.5 | 5 | 2 |
| expert | 329 | **11.5** | 29 | 0 |
| perfect | 353 | 5 | 28.5 | 0 |
| casual, Sprout run 1 | 154 (p10 102) | 0 | 5 | 3 |

The rule changes behind it:
- **hunger** no longer ends patient runs (perfect is down from 16 wilts to 5);
- **a stinger bite** refunds nothing and scores ×1;
- **the chain** has a ×5 cap at step 8;
- **`maxSnaps`** is 14.

On screen:
- the catch pops are big and legible;
- the "+1 snap" tag and the flying glyph sell the refund;
- the open-after-bite frame (21–23) is lovely: juice splats, sparkles, the glyph in flight (1395,605), and escaped
  flies leaving.

What holds it at 7:
- the hold frame (13, 14, 18, 19) still doesn't sell "shut on the bugs";
- the loss moments (sting crack, wilt, hunger) are either hidden (15) or not captured at all (33, 34);
- the expert band wilts 11.5 times a run;
- the first run is short for a real novice.

## R2 items: fixed / not fixed
| R2 # | Issue | R3 status |
|---|---|---|
| P0-1 / #7 | Hunger dominates | **Fixed for perfect** (5 wilts, 5.9 min) and casual (1.5). **Not for expert** (11.5, no target). |
| P0-2 / #8 | Stinger bites net-positive | **Fixed in rules** (Core-R3). In 15 the bite scored 0 (`caught=0 escaped=5 stingers=1`, `d=0.352`), so the "Stung! · +N" pop with points is still unseen. |
| P0-3 / #1 | The closed jaw must look like a clap | **Silhouette fixed** (inside the open outline). **The read is not**: see P1-1. |
| P1-4 / #23 | Sprout start = cap | **Fixed** (`maxSnaps` 14; 11 shows 14/14). |
| P1-5 / #14 | Numbers and glyphs agree; sting crack | **Feast: plausible** (13: the numeral 11 while a glyph is still in flight at 990,520). **Sting: not visible.** 15 is a free sting (cost 0), so there is no crack and no row flash. No frame shows a costly sting. |
| P1-6 / #15 | Small catches need juice | **Pops fixed** (36–48 pt). "×1.5 held" is never captured. |
| P1-7 / #16 | Nectar clusters | **Fixed** (12, 17, 35: 2–3 drops touching). |
| P1-8 / #17 | Hunger telegraph | **Unverified** (33: `no-freeze`; CI runs Sprout run 1 with hunger off). |
| P1-9 / #22 | Chain depth | **Done** (×5 at step 8; the flare audio is in Feel-R3). No frame shows ×3 or more in play; 26's Results says "×3 · 4 big bites". |
| P2-10 | Dry-snap feedback | **Not visible.** No frame, no mention in the notes. |
| P2-11 | Escape marks | **Good** (15: "\|/" marks under 40 pt, 19). |
| P2-12 | Fade by scale | Claimed (Scene-R3); there is no mid-fade frame to judge. |
| P2-13 | CI d-values | The pilot now produces real `d` (13: `d=0.140`; 15: `d=0.352`, a slow snap that lost all 5). Good. A real-Duo `SNAP-H` log is still missing. |

## P0
1. **Capture the loss moments.**
   - Run play demos with `progress=mid` (not first-run options).
   - Add freezes on:
     - `hungry` +0.5 s (the pulse, the red numeral, the droop);
     - `wilted` +0.3 s ("Too slow! −1 snap" over the row);
     - `stung` with cost ≥ 1 at +0.2 s (the crack, the flash, the numeral drop 0.15 s later).
   - The design claims all three. None has a frame, and they are half of the push-your-luck feel.
2. **The free-sting moment (15)** must read as "you got away with it":
   - the toast covers the pop;
   - the copy implies a loss;
   - Feel's `oops` cue (a rising fifth) is right, but the visual says the opposite.
   - Flash the row **green** for 0.3 s with a "free!" tag on the glyph that would have cracked.

## P1
1. **The hold frame (13, 14, 18, 19).**
   - The caught bugs stay on top of the closed lobes (13: 950,610 / 1050,600 / 955,325; 14: 860,540). From
     the hold, a player can't tell eaten from escaped, which Fresh 3 asked for in R2.
   - Sink each caught bug into the seam with a 60 ms slide and a juice puff. Leave only the escapees (with their
     "\|/" marks) outside.
   - Shade the closed lobes' outer halves green, so the shut trap is a leaf, not a red pod.
2. **Expert wilts 11.5 per run.** Real Duo hands are expert-to-casual (0.10–0.15 s), so this band is the dedicated
   players. Give it a target (≤ 6), and try in order:
   - night wilt 14 s (not 12);
   - the hunger clock pausing while a protected bug sits in the trap (waiting out a bee is the skill, not
     dawdling);
   - `extraBeeEvery` 60.
3. **The novice first run is 75 s** (log 20). Novices waste snaps on dry bites: 17 snaps spent for 21 bugs. A
   run-1-only "free miss" for the first 3 dry snaps keeps the lesson ("Snaps run out") and gets the novice to about
   100 s.
4. **The hold width varies 2×** (13: 18 % of the screen width; 14 and 18: 35 %). If the squeeze is a time-based
   animation, freeze CI at a fixed phase. If not, pick one closed size, since the hold is the hero frame.

## P2
1. **Dry snaps** need their own read: an empty "snap!" puff at the seam, a 2 pt shake, and a soft "clack" with no
   squelch.
2. **The ×5 flare** has no frame. Add `freezeOn=chain5`.
3. **The open-after-bite frame (21)** is the best gameplay frame in the set: use it, not the hold, as the store's
   "bite" screenshot.
4. **The +1 snap tag and the chain chip** stack on the outer edge (13: 1665–1850, 655–780). On the Duo that is the
   thumb band. Mirror them to the inner bottom with the snaps row.

## Balance sanity (`core-R3.md`)
- All the brief's targets pass, with thin margins: casual wilts 1.5 vs 2, perfect wilts 5 vs 6, casual chain 5
  vs 6.
- The libm drift risk is noted. CI's BalanceTests should print the actual numbers in the log, so the next review can
  quote them.
- GAME-DESIGN §6 is stale (× 0.97 / floor 0.6 / one bee every 8). Update it to × 0.96 / 0.25, lingers × 0.92 /
  0.2, one bee every 40.
