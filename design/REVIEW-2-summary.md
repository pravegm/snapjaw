# Review R2: merged top 25

Frames: `artifacts/r2/` (iPhone 18 Pro, tap build). No R2 Duo frames: `artifacts/duo2/` was absent at review time.

## Scores
| Reviewer | R1 | R2 |
|---|---|---|
| ADA juror | 5 | **6** |
| UX / onboarding | 4 | **6** |
| Feel / economy | 4 | **6** |
| Duo specialist | 5 (prov.) | **5** (prov.: no Duo frame) |
| Fresh 1: casual Duo owner, 30 | — | 6 |
| Fresh 2: 12-year-old | — | 7 |
| Fresh 3: hardcore, played Fold Smasher | — | 5 |

**Fixed in R2:**
- the streaks;
- the chain and numeral truncation;
- the bee rings;
- the lesson on nectar, with pointers;
- the crease text;
- one hero pop;
- one art language on Home;
- hunger, the chain rule and Sprout's 12 snaps (all in).

**What all three fresh players raised:**
- the trap and snap icons read as a **watermelon**;
- the bite frame reads as a **giant green eye**;
- "Last snap — make i…" is **cut off**;
- "wilted −1" and "Chain" are unexplained;
- nothing shows that the Duo's fold is the input.

## Top 25
| # | P | Owner | Fix |
|---|---|---|---|
| 1 | P0 | Scene | The bite jaw draws a green ellipse wider than the open trap (13: x 300–1690 vs open 370–1630; 17: 110–1880), which reads as an iris. Clamp the jaw to the open-trap outline: the outer edges slide in, cilia interlock, ghost open-state teeth are hidden (14, 18, 19). SceneTests assert this at 874 × 402 and 951 × 669. |
| 2 | P0 | Scene | It still reads as a watermelon (10, 20, 32): the salmon face, a 26 pt bright rind, pale "seed" dots. The face core ≤ #9A1A33 and rim ≤ #C42A45; crimson pores; the green back 12–14 pt in #2F5F2B with a dark lip; one specular per lobe. This also redraws `TrapArt.trapImage` for Results and the cover. |
| 3 | P0 | App/UI | The hint truncates "Last snap — make i…" (15, 18). Use 3 lines or "Last snap!", plus a test that renders every `TrapHint` copy at both plate widths with no ellipsis. |
| 4 | P0 | App/UI | The HUD overlaps the cilia: in 23 the glyph rows (x 280–580) and chain chip sit on the teeth; in 22 the first glyph is on the cilia. Add the R2 cilia length to `trapReach`, and test ≥ 8 pt clearance at 951 × 669 for both `hudLeft` values. |
| 5 | P0 | Core | Bugs rest on the crease (10, 21–23 housefly at x≈1000; 33, 34 gnat swarm on the midrib). `findSpot`, swarm anchors, hops and moths: never rest within r + 16 pt of the crease. |
| 6 | P0 | CI | Still no Duo-aspect evidence (03 and 22 are phone-aspect with no fold band; duo2 missing). Run duo.yml for R2 and add the 951 × 669 letterboxed `fold=1` render (10, 13, 14, 18, 23, 24, Home, Results). Gate sign-off on it. |
| 7 | P0 | Core | Hunger dominates skilled runs (perfect 16 wilts, expert 11.5 per run). Wilt times 18/16/14/12. Start the timer on the first in-trap landing after a bite. Targets: perfect ≤ 6, casual ≤ 2. Add a sim assertion. |
| 8 | P0 | Core | Stinger bites can be net-positive (19 log: bumblebee + scarab bite = 1,032 at ×1.5, then Feast +1 and scarab +2, a net +1 snap). A bite with a stinger gets no Feast refund and scores at ×1; the pop says "Stung! · +172". |
| 9 | P0 | Core + App | First runs are under a minute (sim 41/50 s; frame 20 is 62 s and 14 bugs). For Sprout runs 1–3: no wilt in run 1, and the first bee costs 0 with a "Bees cost a snap!" toast. Target ≥ 90 s. |
| 10 | P1 | Scene | Dusk is invisible (16 ≈ 10), and night turns the lobes violet (15, 17). Dusk: a peach bog plus a warm rim light. Night: a blue bog with the trap still crimson, and visible firefly blooms. CI: a night frame with no bite hold. |
| 11 | P1 | App/UI | The snap glyph reads as a melon slice or lips (10–34). Redraw it as a mini closed trap; an empty slot is a grey outline. The hunger slot pulses crimson and the numeral ticks red at −3 s (33 is too faint). |
| 12 | P1 | App/UI | The lesson never shows the snaps row. Show it in steps 3–4, ring it on card 09 ("These are your snaps"), and label the first Feast's flying glyph "+1 snap". |
| 13 | P1 | App/UI | The icon is a fanged, black-outlined, side-view Pac-Man (`app-icon-1024.png`), against "cilia, not fangs" and the game's look. Redraw from `TrapArt`: a top-down trap, thin cilia, a cute fly sipping off the midrib. |
| 14 | P1 | Scene | Show the economy truthfully. The numeral changes when each glyph lands (13 jumps early). A sting cracks a glyph and flashes the row crimson, which is invisible in 15. "Stung!" sits above the ring, not over the wasp. |
| 15 | P1 | Scene | Small bites need juice: "+10" in 17 is about 12 pt. Every catch pop is ≥ 28 pt with an overshoot; a held chain says "×1.5 held". "wilted −1" becomes "Too slow! −1 snap", a crimson tag over the snaps row (34). |
| 16 | P1 | Core | Nectar "clusters" don't read (10, 21: drops about 180 px apart). A 24–30 pt cluster ring, so crowds form in one place and "Now!" points at a group. |
| 17 | P1 | Scene | The hunger droop is invisible (33). At hunger 0.7 → 1: y 0.95, a 15% grey, teeth leaning 20°, the anchor pinned at the midrib (Duo). |
| 18 | P1 | App/UI | Bee lesson (07): the bee lands on the rim, not on a drop. Use `lessonSpot`, so the bee visibly sips beside the flies. |
| 19 | P1 | App/UI | The Bug Book truncates: "Golden Sca…" and the Bee joke off-screen (29). Add a 4th-row fade or scroll cue, and vary the fixture counts (all "Caught 27" / "166"). |
| 20 | P1 | App/UI | Remove "Debug · input touch" from Settings › About (30); add a scroll cue for the clipped Credits. |
| 21 | P1 | CI | Story frames come from different runs: same seed and pilot, but 19 has a 1,032 bite and 20 a 688; the HUD says 1,174 but Results 809. Make the pilot deterministic (a seeded RNG, fixed dt), and freeze open-trap moments at +0.3 s after the bite hold. 5 of 10 play frames are the jaw. |
| 22 | P1 | Core | The chain is shallow at the top: expert/perfect longest 24–26 against a ×4 cap at step 6. Try ×5 at step 8 with a HUD flare, or a 1-bug bite decaying ×4 → ×3.5. Re-run the sim (casual longest is already 6 on 64 seeds: watch the 3–6 band). |
| 23 | P2 | Core | Sprout starts at 12 = `maxSnaps` 12, so early Feast refunds can be capped away. Set `maxSnaps` 14 (rows of 7) or Sprout 11. |
| 24 | P2 | App/UI | Copy and polish. Results: "Best chain ×1.5 · 2 bites", "An 8-bug FEAST", "New best! (was 3,200)", and fix the backdrop seam at x≈1060 (20, 26, 27). The cover (32) gets the promised "Open it up to carry on" plus the score. The pose card (31) uses TrapArt with a looping 160° → 138° clap. |
| 25 | P2 | Scene | The mosquito has 8 legs and reads as a spider (12, 16, 18, 28): use 6 legs and a proboscis. Fade pops by scale and lift, not alpha only: the "FEAST ×5" mid-fade in 25 is illegible. |

Also noted, not in the top 25:
- Home's menu stack hides half of the live trap (01–03);
- the live Home scene's 60 fps thermal cost on a Duo;
- the hint slot on the Duo must be confirmed off the thumb band;
- the CI hinge `d = 0.010` makes every snap "perfect": real-Duo `SNAP-H d=` logs are still needed;
- the store page must show a real Duo fold (all three fresh players saw only "tap to snap").
