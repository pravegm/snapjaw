# Review R1 — merged top 25

Scores: **Juror 5 · UX 4 · Feel 4 · Duo 5** (Duo is provisional: no r1 frame is Duo-aspect). Frames are in
`artifacts/r1/`.

| # | P | Owner | Fix |
|---|---|---|---|
| 1 | P0 | Scene | Kill the long, pale, tapered streaks (600–1100 pt) through flying bugs in 10, 11, 12, 18, 19, 21–23. Find the runaway `BogBugNode` child (wings/blur) or pooled flash, and test that each bug child's frame is ≤ 6× radius. |
| 2 | P0 | App/UI | The chain chip truncates to "Chain…" in every frame. `HUDLayout.chain` is 104/120 pt: add `.fixedSize()` to `ChainChip` and size the rect from it (or show "×1.5" plus the glyph). |
| 3 | P0 | App/UI | The snap numeral clips "12" to "1" (11): `.fixedSize()` on the numeral, and `snapIcon` 22 → 18 when slots > 10. |
| 4 | P0 | Scene | Bugs are ~3% of the canvas width, smaller than the nectar drops: scale the bug art ×1.8 (housefly 28 → 50 pt on the Duo, gnat ≥ 25 pt), with Core spacing radius ×1.3. |
| 5 | P0 | Scene | The trap reads as a watermelon: drop the lime rind band for a thin dark-green lip plus a 24–32 pt green exterior; face #7A0C26 at the midrib → #D23048 at the rim; teeth 1.5× longer and 40% thinner. |
| 6 | P0 | Scene | The bite doesn't read (13): on `snapped`, lobes x-scale 0.6 towards the midrib for the 120 ms hold, the jaw silhouette covers 40% of each lobe, 50 ms hit-stop, caught bugs flash white for 2 frames, shake 4 + 2/bug pt. |
| 7 | P0 | Scene | Never draw the sip ring on bees or wasps (12, 16). Bees get a white 3 pt ring at r×1.6; catchable sippers get a lime-white ring (gold stays for nectar and score). |
| 8 | P0 | App | Lesson flies never sip (04: landed at 548,341, no `bugSipping`; 05, 06, 08 sit beside drops): spawn on `snapshot.nectar[k].position` exactly. |
| 9 | P0 | App | Lesson: a pulsing ring plus an arrow from the card to the target bug(s); bee step linger 3 → 6 s with the "Bee! Wait…" hint (07 lost the bee within 4 s); in step 6, "Now!" only when all three sip. |
| 10 | P0 | Core | Hunger: `wiltSeconds` 15/14/12/10 by phase with no catching bite wilts a snap. A dry snap doesn't reset the timer. `TrapEvent.hungry` fires 3 s before (the snap glyph drains, "Hungry… bite!"). Sim: perfect ≈ 5.8 min, casual unchanged. |
| 11 | P0 | App/UI + Scene | Nothing on the crease: `TiredBanner` at `hudPage.midX` (19); pop text clamped ≥ 24 pt from the crease, on the side with most catches (14); test `isFoldClear` for every play text rect. |
| 12 | P0 | App/UI | One art language: replace `TrapPortrait`/`BugPortrait` on Home, the cover, Results and the Bug Book (01–03, 20, 26–29, 32: the bee is an olive blob) with `TrapArt.bugImage` and a scene-rendered trap. |
| 13 | P0 | App/UI | Bug Book jokes truncated (28, 29): `lineLimit(3)` with `minimumScaleFactor(0.85)` or tap to flip; peek or fade the cut-off 4th row; move the back button off the top-right card. |
| 14 | P0 | App/UI + CI | HUD vs trap rim on the Duo: `HUDLayout` tests against `trapRect` at 951 × 669 (both `hudLeft` values); pull the score in 12 pt if it fails. |
| 15 | P1 | Core | Chain: only bites of ≥ 2 bugs add +0.5, 1-bug bites hold it, dry snaps and stingers break it (casual longest 11 → ~4–5). Re-run `balance-sim.js`. |
| 16 | P1 | App/UI | Move the hint plate off the thumb arc and the trap rim: to the HUD page's inner bottom or under the chain chip (11, 12, 18). |
| 17 | P1 | Scene | Show the economy: on a Feast, +N snap glyphs fly from the bite to the snaps row (0.45 s, a tick each); on a sting, the lost glyph cracks and the row flashes crimson; "Bzzt!" sits above the bee (y + 2r + 20) (14, 15). |
| 18 | P1 | Scene | One hero Feast pop, "FEAST ×5 · +255" at 1.4×; the chain step bumps the HUD chip instead of an olive "chain ×1.5" line on the lobe (14, 25). |
| 19 | P1 | Scene | Nectar drops −30% radius, translucent amber, clustered 2–3 per lobe so crowds form in one place (10, 17). |
| 20 | P1 | Scene | Closure tracking: lobe foreshortening 3% → 15% at `closure01 = 1`, shade to 30% of lobe width, teeth drawn from `predictedAngle` (24). |
| 21 | P1 | Scene | Night and dusk keep the trap crimson: a 25% normal-alpha blue/peach over the lobes, multiply on the bog only (12, 15, 17). |
| 22 | P1 | App | Lesson on a phone: renumber the visible steps 1–5 (today 2/4/6 "of 6"); merge the dead step 3 into step 2's praise; step 4 says "Two flies. Get both in one bite." |
| 23 | P1 | App/UI | Results and Home polish: "4 bugs · 48", "Scarab" short name, wrap or "+2" the new-entries row (26), "×1.5 (2 bites)" chain, celebrate first runs (27); clear the title and tagline off the teeth, remove the pink smudge, fix the right-edge background seam and label the empty rank bar (01). |
| 24 | P1 | Core | First impression: `startSnaps` 12 for runs 1–3 (Sprout), or the first bee of a run costs 0 extra with a teach line. The novice run is 46 s / 12 snaps. |
| 25 | P1 | CI | Frames don't show their captions: 05 (step 3 auto-passes on touch), 07 (bee gone before 8 s), 16 (freeze +2 s after `dayPhaseChanged`, the tint hasn't lerped), 03/22 (no fold band, phone aspect). Add a 951 × 669 letterboxed `fold=1` render with the fold band forced, and run `duo.yml`. |

Also in the reviews but not in the top 25:
- the icon (remove the midrib line skewering the fly; use cilia, not fangs);
- Settings alignment and the back button overlap (30);
- the pose-card animation (31);
- one copy for "open to carry on", plus the run's score on the cover (32);
- thumb-safe landing exclusion;
- hardware checks (`REVIEW-1-duo.md`): hinge `d` stability for the 0.12–0.14 s species, the blurred half, the crease
  x, the haptics, the speaker pan and 120 fps.
