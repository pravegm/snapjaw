# Snapjaw scorecard: R6

*Panel run on 28 Oct 2026 against `design/SCORECARD.md`, with the same 10 personas and 9 dimensions as R5. The baseline
is `design/SCORE-R5.md`. Players scored only the frames, in story order. Experts also had the docs.*

## Evidence
- **The R6 phone build:** `artifacts/r6/screenshots/`. There are 55 numbered frames, plus `app-icon-1024.png` and 12
  badges, shot on the iPhone 18 Pro (2622 × 1206, tap control). All 55 are `ok` and `expect-ok` in `captures.tsv`.
  Captions are in `ci/scenarios.txt`. R6 added frames 44–55.
- **Store set:** `artifacts/store3/`. It holds:
  - store-69 (P01–P10, 2868 × 1320);
  - store-63 (P01–P10, 2622 × 1206);
  - store-duo (D01–D10, 2853 × 2007), from a store pass with no rig failures (`raw-duo/checks.tsv`);
  - store-placements (header and search: "ok 2, problems 0", commit `7faf17f`).

  Captions are in `ci/store-scenarios.txt` and `ci/duo-store-scenarios.txt`. **This is the first store set that shows the
  current build:** no "protein", a crimson release, a real dusk and night, Goals, the Garden and Zen.
- **Duo hinge:**
  - `artifacts/duo5/` has **no frames**. Its `checks.tsv` holds one line: `SIMULATOR FAIL … could not be rebooted`.
  - `artifacts/duo5b/` holds the hinge run:
    - SNAP, REARM, CREEP and CLOSE-PAUSE **pass**;
    - no pause at 95°;
    - `LESSON-HINGE` steps 2 → 3 → 4 run by hinge;
    - one simulator death late in the run ("store-15"), caused by the rig.
  - **Caveat:** duo5b's `duo-ui-results` has no Goals card, while store D09 has one, so the hinge run seems to predate the
    R6 goals UI. The R6 code has been seen at Duo aspect only through the store pass, which holds the hinge still at 150°.
    It has not been seen moving the hinge.
- **Store copy:** `docs/appstore/metadata.md` (R6 rewrite) and `docs/appstore/screenshots.md`.
- **Brief:** `design/ROUND-6.md`.
- **Competitors weighed for D6:** `research/01-market.md`. Fold Smasher, ChompDuo and Foldfish are all free with IAP,
  and Fold Smasher has the same verb.
- **What the players saw:** only the frames, in story order:
  1. the icon;
  2. store P01–P10 (store-69);
  3. the lesson, 04–09;
  4. play, 10–19, 33–43, 46, 48, 49 and 53–55;
  5. Results, 20, 26, 27, 47, 50 and 51;
  6. Home, 01, 02 and 52;
  7. the Garden and the Book, 44, 45, 28 and 29.
- **What the experts saw:** all of the above, the Duo frames (store-duo, duo5b) and the docs.

### Defects found on the frames (what the cells below refer to)

**Garden and varieties (R6's headline feature):**
- **Four of the eight varieties look like Classic** (45, P04, D04):
  - **Shark Tooth and Cupped Trap** are Classic's pink dome with a lime rim. Shark Tooth's "triangular teeth" are the
    same white specks as Classic's.
  - **Sawtooth** has fewer cilia than Classic and nothing jagged.
  - **B52** has slightly longer cilia but is the same size as Classic. It isn't "big, wide lobes". In play, 54 against
    11 shows lobes only about 5% wider and longer teeth.

  Only Red Dragon (crimson, 53) reads as different. Golden Glow (55) is gold cilia and rim on the same pink inside, so
  it's subtle.
- **Garden counts disagree across the store set.** P04 says "6 of 8 grown" (progress=late), but P06 and D06 Home say
  "Garden 2/8" (progress=mid).
- **P04's sub-line, "Real cultivars", is only partly true.** Golden Glow is a fantasy variety (ROUND-6).
- **Unlock rules are worded inconsistently** (44): "Goal: A 6-bug bite" against "Reach Gnat Gobbler". The locked
  silhouettes mix spiky and smooth outlines.

**FEAST (D4):**
- **A 5-bug FEAST pays less on screen than a QUAD:**
  - 48, P02 and D02: "FEAST! ×5 · +180";
  - 14: "QUAD ×4 · +260";
  - 49: "QUAD ×4 · +520".

  The event that should feel biggest shows the smallest number.
- **"×" means two things on screen at once.** "×5" is the bug count, while the chain chip says ×2.5 (48, P02). It's
  the same in 18 ("DOUBLE ×2" next to ×1.5).
- **No visible gulp in any FEAST frame.** The bugs are already gone, leaving sparkles (48, P02, D02, 39). The +2 snaps
  refund shows only in 39 ("+2 (full)"). In 48 and P02, the snaps row reads 10 with no pop.

**Messages over their subject, and messages stacked (R5 #6 not done):**
- "Stung!" is still drawn on the wasp (15, 40, 43).
- In 43:
  - a fly sits under "Stung!";
  - the free-sting hint covers bugs at the bottom of the trap;
  - "Stung!", the hint and the row flash all show at once.
- Three pops at once:
  - 19: "+12", "×1.5 held" and "Your trap is tired.";
  - 42: "+300", "×2 held" and "Golden!";
  - 46 and P08: "+45", "×3 held" and "Lucky!".
- "Lucky!", "Golden!" and "+2 (full)" are never explained.
- P10, D10 and 08 double up: "…now tap!" in the card and a "Now!" pill.

**HUD zone, midrib and edges (R5 #7 not done):**
- A housefly is parked beside SCORE (10, 13, 41) or at the HUD edge (02).
- A bee halo is cut by the right screen edge:
  - in play: 11, 53, 54, 55;
  - in the store: P01, D01, search-365pt;
  - at the top edge: D08.
- Gnats cluster on the midrib (11, 53–55). A fruit fly sits on the midrib base (41). A bluebottle sits on the midrib
  top (42).
- Bugs are cut by the bottom screen edge (P05, 15, 39) or the left edge (16, 39).
- A bug sits over the snaps numeral or row (48, P02, D02), and a lily pad sits over the snaps glyphs (05–09).
- Bugs peek out from behind Home buttons (01, 52, D06).
- The goal toast covers a bug at the top edge (49).

**Clipping:**
- Results' third card is cut by the scroll and shows only as an empty top edge: the rank card in 20, 26, 27, 47 and 50,
  and the rank bar in P09.
- In 51 (the Daily), the goals card is cut after two rows, mid-line.
- The Duo D09 is fine.

**Consistency:**
- The SNAPS label appears under the numeral on 6.9" (store-69 P02, P03, P05, P10), but not on 6.3" (r6 10–55,
  store-63) or on the Duo (D01–D10). R5 #14 is half done.
- Zen play shows a score (46: 1,834; D08: 1,507), but Zen Results shows no score, only "94 bugs caught" (47).
- Zen Results (47) shows the same best bite and chain as Feed Results 26 and 50: "7 bugs · 696" and "×3 · 4 big bites".
  It looks like a reused demo result.
- Every Results screen says "YOUR TRAP IS TIRED" over a "New best!" (26, 50, P09). That's a mood clash.
- **Duo cover:**
  - It is still off-centre, with the right third empty (duo-ui-cover, duo-h3).
  - duo-ui-cover says **"Best feast 3,200"**, but 3,200 is the best score. The phone cover (32) correctly says "score so
    far".
  - The Game Center leaderboard is also called "Best Feast" (metadata §4), which clashes with "Feast" = a 3+ bite.
- **Duo lesson:**
  - The card reads "STEP 1 OF 4: Open up to reset the trap." during the reset step (duo-ui-lesson-3-hinge-128). The
    counter doesn't advance.
  - Store-duo D06 Home says "Snap it shut a little", but the captions say "Snap it a little shut".
- **Too-flat (duo-ui-too-flat-178):** the frame shows normal play with "Now!". `ui-too-flat.txt` logs no too-flat line.
  The 178° prompt is unproven.

**Duplicate frames and false captions (R5 #20 not done):**
- These pairs are the same frame: 05 = 06 (both "Step 2 of 4, Two flies"), 15 = 40, 26 = 50 and 02 = 52.
- Captions that don't match the frame:
  - 05's caption is "Open up to reset the trap.";
  - 14's caption promises "TRIPLE ×3 / Feast! +1 snap", but the frame shows QUAD;
  - 17's caption says "Night", but the frame is at dusk;
  - 23's caption still says "HUD on the left";
  - 26's caption still says "protein".

**Story:**
- Night 35 has only houseflies, with no fireflies or crickets in the trap. P05 has a single firefly under "Fireflies
  light the night".
- "Hungry… bite!" fires while a bee halo overlaps the trap edge (33; R5 #15 not done).

**Store craft (R5 #10 partly done):**
- P01, D01 and the search placement still show the book opened to about 170°, so the fold barely reads at thumbnail size.
- The Dynamic Island pill is gone (fixed).
- The P03 crowd-and-bee choice is good.
- D08 ("Or just relax") shows "Stung! · +15" and "Bzzt!", the wrong moment for that caption.
- P02 and D02 show an empty trap with sparkles, not the crowd being eaten.

**Icon:** the two lip dots are now silver-grey studs, lighter than R5's, but they still read as two dots.

**Fixed since R5:**
- **Store and Duo evidence:**
  - the store set is regenerated;
  - the Duo hinge closure is visible (duo-03 at 130°, interlocked teeth);
  - the phone cover (32) is centred and says "score".
- **Scene:**
  - dusk is peach (12, 16, 37, P03);
  - night is blue with firefly blooms (15, 35, 40, P05);
  - the juice is gold;
  - the tired trap keeps its rim (19).
- **Messages:**
  - the lesson's bee step (07) is a single message;
  - one "held" label, not two (42);
  - the Duo lesson's step text now reads "snap shut!" with the 138° diagram (duo-ui-lesson-2).
- **Copy:** "×5", "14" and "Score on the left" are corrected in metadata.md.
- **R6 features:**
  - Goals are coherent across Home → toast → Results. 02 shows 0/12 · 0/10 · 0/3, 49 shows "Goal done!", and 26 shows
    7/12 · ✓ · ✓ with "+90 growth".
  - The Daily streak is consistent: Home shows 2 before today, and 51 shows "3 days" with Share.

**Delta from R5:**
- **Up:** D3 +1.0, D7 +1.0, D8 +1.0, D4 +0.5.
- **Flat:** D1, D2, D5, D6 and D9.
- **The game is not done:** 8 of 9 dimensions are below target, and there are 2 P0s.
- **Players' yes at £1.99:** 4 of 5 (80%; R5 was 3 of 5).

## 1. The grid

A 9 means best-in-class on the App Store.

| # | Panelist | D1 Design | D2 Ease | D3 Fun | D4 Satisf. | D5 Duo-first | D6 Pay | D7 Replay | D8 Store | D9 Polish |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ADA juror | 8 | 8 | 8 | 8 | 8 | 7 | 8 | 7 | 7 |
| 2 | Game-UX / onboarding lead | 8 | 7 | 8 | 7 | 7 | 7 | 8 | 7 | 6 |
| 3 | Game-feel designer | 8 | 8 | 8 | 7 | 8 | 7 | 8 | 7 | 7 |
| 4 | iPhone Duo specialist | 8 | 7 | 7 | 8 | 7 | 7 | 7 | 7 | 6 |
| 5 | Premium games publisher | 8 | 8 | 7 | 7 | 7 | 7 | 8 | 7 | 7 |
| 6 | Casual 30-year-old Duo owner | 9 | 9 | 8 | 8 | 9 | 8 (yes) | 8 | 8 | 8 |
| 7 | 12-year-old | 9 | 9 | 8 | 9 | 8 | 6 (no) | 9 | 8 | 7 |
| 8 | Puzzle player | 8 | 8 | 7 | 7 | 7 | 7 (yes) | 8 | 8 | 8 |
| 9 | 60-year-old grandparent | 9 | 7 | 8 | 7 | 7 | 8 (yes) | 8 | 8 | 8 |
| 10 | Duo-roundup journalist | 8 | 8 | 8 | 8 | 8 | 7 (yes) | 8 | 7 | 7 |
| | **Median** | **8.0** | **8.0** | **8.0** | **7.5** | **7.5** | **7.0** | **8.0** | **7.0** | **7.0** |
| | **R5 median** | 8.0 | 8.0 | 7.0 | 7.0 | 7.5 | 7.0 | 7.0 | 6.0 | 7.0 |
| | **Delta** | 0 | 0 | **+1.0** | +0.5 | 0 | 0 | **+1.0** | **+1.0** | 0 || | **Target** | 8.5 | 8.5 | 8.5 | 8.5 | 8.5 | 8.0 | 8.0 | 8.5 | 9.0 |
| | **Gap** | −0.5 | −0.5 | −0.5 | −1.0 | −1.0 | −1.0 | **met** | −1.5 | **−2.0** |

*(D5's sorted column is 7,7,7,7,7,8,8,8,8,9, so the median is 7.5 and the R5 → R6 delta is 0. The Duo gains, which are
hinge closure shown and the hinge lesson walked, are cancelled by the duo5 failure and by duo5b running pre-R6 code.)*

**Only D7 meets its target. 8 dimensions are below target, and there are 2 P0s, so the game is not done.**

On D6, 4 of the 5 players would pay (80%). The bar is 70%, so the players' bar is met. The panel median is 7.0, below
8.0, because all five experts say the page and the first minute don't yet convert against three free games.

**Weakest:** D9 Polish (−2.0), D8 Store (−1.5), then D4, D5 and D6 (−1.0 each). R7 leads with these.

## 2. One reason per cell

### 1. ADA juror
- **D1 8.** The Garden cards, Results and the peach dusk (16, 37) are lovely, and the night is finally blue (35). Four
  near-identical traps in the Garden (45) stop the 9.
- **D2 8.** The lesson is four clean steps, and the bee step (07) is now one message.
- **D3 8.** Goals give each run a shape: 02, then 49, then 26 reads like a small story.
- **D4 8.** The Duo's interlocked jaws (duo-03) and the gold FEAST burst (39) are proper hero moments.
- **D5 8.** The closure on the hinge is now in a frame. The P01 book is still almost flat.
- **D6 7.** It's a crafted object worth £1.99, but the page leads with its weakest frame (P01).
- **D7 8.** Goals, a streak, Share, 8 traps and Zen add up to a real reason to come back.
- **D8 7.** The set is finally the real build. P04 sells "8 flytraps" while showing 4 that look the same.
- **D9 7.** "Stung!" is still on the wasp (40). Results cards are cut by the scroll (26).

### 2. Game-UX / onboarding lead
- **D1 8.** Goals fit the card system, and so do the Home buttons, but Home is now busy: 7 controls plus 3 goals
  (02).
- **D2 7.** Popups still stack, three at once in 19, 42 and 46. "×" means bug count and chain in the same frame (48).
  "Lucky!", "Golden!" and "+2 (full)" are never taught.
- **D3 8.** "Spare 12 bees in one run" turns the bee rule into a goal. That's good design.
- **D4 7.** The FEAST shows +180 next to a QUAD's +260 (14). The number undercuts the event.
- **D5 7.** The Duo lesson counter stays at "Step 1 of 4" during the reset step. The 178° frame shows no too-flat prompt.
- **D6 7.** The first minute is clear, but the store doesn't show a goal being ticked (49 would).
- **D7 8.** Results ticks goals and points to "2 new goals on Home". There's still no next-Bug-Book target.
- **D8 7.** The P10 card and pill both say "now". There's no Zen badge in P08, so the frame doesn't read as Zen.
- **D9 6.** The CI file still has the 05 = 06 duplicate, the 14, 17, 23 and 26 caption lies, and 15 = 40 and 26 = 50.

### 3. Game-feel designer
- **D1 8.** The juice is gold at last (13, 48), and dusk and night now read at a glance.
- **D2 8.** Good and bad are still readable at a glance: gold, white and red rings.
- **D3 8.** Zen and goals widen the loop without breaking the economy.
- **D4 7.** The FEAST has a banner and sparkles, but no visible gulp, no scaled pop, and a smaller payout than a QUAD.
  Hit-stop and the CHOMP can't be judged from stills.
- **D5 8.** CREEP passes with nothing snapped at 22°, and the partial snap is real hinge design.
- **D6 7.** The craft is visible, but the free toy is still on the same verb.
- **D7 8.** Collecting traps and keeping a streak are classic hooks.
- **D8 7.** P02 is an empty trap with glitter. It shows the after, not the crowd being eaten.
- **D9 7.** A bug overlaps the "10" snaps numeral (48, P02).

### 4. iPhone Duo specialist
- **D1 8.** The D06 Home with the pose card is the best Duo layout yet.
- **D2 7.** The duo-ui-lesson-2 wording is right. The step counter is wrong in hinge-128. Too-flat is not shown.
- **D3 7.** Still not judged on a device moving the hinge with R6 code.
- **D4 8.** duo-03 at 130° finally shows the bite closing.
- **D5 7.** SNAP, REARM, CREEP and CLOSE-PAUSE pass, but on what looks like pre-R6 code. duo5 failed outright. The cover
  card is off-centre and says "Best feast". There's no real-Duo log.
- **D6 7.** Duo owners pay for real Duo games, and D01 still doesn't prove the fold at thumbnail size.
- **D7 7.** Zen is good for comfort. There's no session-length signal for 6+ minute runs.
- **D8 7.** The D-set is current, but D01 is opened to about 170° with the bee halo cut, and D08 shows a sting.
- **D9 6.** The Duo HUD has no SNAPS label and its snaps row is tiny (D01–D10). The cover is off-centre.

### 5. Premium games publisher
- **D1 8.** It's still the best-looking Duo bug game.
- **D2 8.** It's understood in 30 seconds.
- **D3 7.** It's still one loop at heart (Feed, Daily and Zen are the same bite). Goals help, but there are no levels.
- **D4 7.** The hook is under-sold. No FEAST frame shows bugs going in.
- **D5 7.** Featuring needs the R6 hinge run and the founder's device test.
- **D6 7.** The page now argues depth (P04, P06, P09). Reviews will catch the near-identical traps and say "half the
  Garden is the same plant".
- **D7 8.** A streak and Share give day-7 a fighting chance.
- **D8 7.** The captions are mostly true. P04's "Real cultivars" is half true (Golden Glow). P04's 6/8 against P06's
  2/8 looks like two players.
- **D9 7.** The app is mostly clean. The capture set and captions are not.

### 6. Casual 30-year-old Duo owner
- **D1 9.** "The sunset level is gorgeous."
- **D2 9.** "Wait for flies, skip bees. Easy."
- **D3 8.** "Goals made me want one more."
- **D4 8.** "FEAST! is satisfying."
- **D5 9.** "Nothing else uses my Duo like this."
- **D6 8, yes.** "Two quid, no ads, loads to unlock."
- **D7 8.** "The streak will get me."
- **D8 8.** "The flytrap icon and the night shot sold it."
- **D9 8.** "Didn't notice anything broken."

### 7. 12-year-old
- **D1 9.** "The red dragon one!"
- **D2 9.** "Bite flies, not bees."
- **D3 8.** "Zen is chill. Goals are cool."
- **D4 9.** "FEAST ×6 +1,080 (39) is sick."
- **D5 8.** "You actually close the phone?"
- **D6 6, no.** "Most of the traps look the same as the first one, and Fold Smasher is free."
- **D7 9.** "I want every flytrap."
- **D8 8.** "The garden picture looks cool."
- **D9 7.** "The words cover the wasp again" (40).

### 8. Puzzle player
- **D1 8.** "Tidy, like Two Dots."
- **D2 8.** "Clear rules, clear goals."
- **D3 7.** "Goals are good. I'd still like levels or stars."
- **D4 7.** "Nice pops, but why is a FEAST worth less than a QUAD?"
- **D5 7.** "Neat."
- **D6 7, yes.** "Three goals, a garden and a daily streak. OK for £1.99."
- **D7 8.** "Ticking goals is my thing."
- **D8 8.** "The goals screenshot is what got me."
- **D9 8.** "Fine."

### 9. 60-year-old grandparent
- **D1 9.** "The evening and night colours are lovely now."
- **D2 7.** "What's 'Lucky!', 'Golden!', '+2 (full)'? Too many words pop up at once" (42, 46).
- **D3 8.** "Zen is perfect for me."
- **D4 7.** "Can't feel it in a picture."
- **D5 7.** "If it's gentle on the phone."
- **D6 8, yes.** "No adverts, and a relaxing mode."
- **D7 8.** "A daily one and a little garden, yes."
- **D8 8.** "Big, clear words."
- **D9 8.** "Nothing odd."

### 10. Duo-roundup journalist
- **D1 8.** It's the best art of the four, but the Garden's 8 are really 4 or 5.
- **D2 8.** It's self-explaining.
- **D3 8.** Goals plus selective catching beat Fold Smasher's clap and ChompDuo's toy.
- **D4 8.** The FEAST banner and the Duo closure (duo-03) read well.
- **D5 8.** The partial snap and bees still beat Fold Smasher's flat clap.
- **D6 7, yes.** It's the premium pick, if the Garden delivers what P04 says.
- **D7 8.** The Daily streak and Share are my roundup line.
- **D8 7.** The P01 book is too flat to read as a fold in search. The halo is cut by the edge.
- **D9 7.** The Duo cover says "Best feast 3,200". That's the score, not a feast.

## 3. Below target: the 3 changes that raise each dimension most

### D1 Design (8.0 → 8.5)
1. **Scene.** Make the 8 varieties distinct in silhouette, not just in colour. *Frames 44, 45, 54; store P04, D04.*
   - **B52:** lobes 15–20% larger, with fat, sparse cilia.
   - **Sawtooth:** short, jagged, saw-edged teeth all round, with no long cilia.
   - **Shark Tooth:** wide triangular teeth on the lip.
   - **Fused Tooth:** a continuous frill.
   - **Cupped Trap:** a deeper cup with a visible inner wall and a stronger gloss.
   - **Golden Glow:** a gold inside, not just gold cilia.

   Add a Garden check: no two card thumbnails within a set pixel-difference threshold.
2. **Scene.** Enforce the clear zones, as R5 #7 asked and R6 didn't deliver:
   - no bug parked beside SCORE or pause (10, 13, 41, 02);
   - nothing on the midrib (11, 41, 42, 53–55);
   - no halo or bug cut by a screen edge (11, 15, 16, 39, P01, P05, D01, D08).
3. **App/UI.** Calm Home and Results:
   - Results' third card fits above the fold, or the hero shrinks so the rank bar shows (20, 26, 51, P09).
   - Results doesn't say "tired" over a "New best!" ("What a feast!" instead).
   - Bugs on Home stay out from behind the buttons (01, 52, D06).

### D2 Ease (8.0 → 8.5)
1. **App/UI.** One message at a time, for real (R5 #6):
   - a message queue that holds pops, toasts and hints apart by at least 0.4 s;
   - "Stung!" above the ring;
   - the hint never covers bugs.

   *Frames 15, 19, 40, 42, 43, 46.*
2. **App/UI.** One meaning per "×":
   - the bite pop says "5 bugs · +180" or "FEAST · 5 bugs";
   - "×" is kept for the chain chip.

   Explain "Lucky!", "Golden!" and "+2 (full)" once, or rename them: "Golden scarab!", "+2 snaps (full)". *Frames 18, 39,
   42, 46, 48.*
3. **App/UI.** The Duo lesson counter advances with its text (duo-ui-lesson-3-hinge-128). The SNAPS label shows at every
   size, on phones and on the Duo (10, D01; R5 #14). The P10 and 08 card says "Wait for a crowd…" and lets the "Now!"
   pill carry the cue.

### D3 Fun (8.0 → 8.5)
1. **Core.** Make the FEAST pay like an event: a 5+ FEAST bonus big enough that it always out-scores a QUAD in the
   same run state (48 +180 against 14 +260). Greed is the game, so its biggest moment must be the biggest number.
2. **Core + App/UI.** Goal variety you can see:
   - each Home shows one easy, one medium and one hard goal, labelled;
   - Results says "Next goal: …" with a preview, so a run ends with a plan, not just a tally.

   *Frames 02, 26.*
3. **Core + Scene.** Night has to be night: fireflies and crickets dominate the night trap (35 is all houseflies). P05
   should show 3+ fireflies glowing. Late-night pacing, carried over from R5 #19: a "The night gets fast…" banner, with
   expert runs ≤ 6 min (39: 8,462).

### D4 Satisfaction (7.5 → 8.5)
1. **Scene + Feel.** Capture and show the gulp: freeze the FEAST frame mid-gulp, with bugs visibly sliding into the
   midrib one after another, and show the "+2 snaps" refill pop. Re-shoot 48, P02 and D02 at that moment. Today all three
   show an empty trap with glitter.
2. **App/UI + Scene.** Scale the bite pop by size. FEAST at 1.6× the QUAD pop size, with an overshoot. The banner sits
   centred over the trap, not off to one side (48 against 14).
3. **Feel (founder).** Run the real-Duo checks 2, 8 and 9 on TestFlight with the R6 build: the FEAST CHOMP and burp, the
   heavier haptic, and the first-try snap feel. This half of D4 still can't be scored from stills.

### D5 Duo-first (7.5 → 8.5)
1. **CI.** Land a clean R6 Duo hinge run as `duo6`, on the commit that made store3 (`7faf17f`) or later. It must cover:
   - SNAP, REARM, CREEP and CLOSE-PAUSE;
   - TOO-FLAT at 178° with a visible prompt and a log line;
   - LESSON-HINGE with the counter advancing;
   - a goal toast and the Garden at Duo aspect.

   *(duo5 failed. duo5b predates the goals UI.)*
2. **App/UI.** Centre the cover card and fill it, and say "Best score 3,200", not "Best feast" (duo-ui-cover, duo-h3).
   R5 #12 is still open. Rename the Game Center "Best Feast" leaderboard to "Best Score" (metadata §4).
3. **Store/CI.** Re-shoot P01, D01 and the search placement with the book at about 140°, so the fold reads at 365 pt.
   Move the bee halo off the screen edge. Promote the duo-03 hinge closure (interlocked teeth at 130°) to D02, or to a Duo
   frame 2.

### D6 Willingness to pay (7.0 → 8.0; players 4 of 5, bar met)
1. **Scene (via D1 #1).** Distinct varieties. The Garden is the main new reason to pay, and today it's the easiest
   review complaint to write (P04, 45).
2. **Store/CI.** Lead with proof of depth in frames 1–3:
   - P01 is a readable book at about 140°;
   - P02 is a mid-gulp FEAST with bugs visible;
   - P03 is the bee (keep it).

   Then P04 Garden, with all 8 visibly different and the same progress as P06. Add a frame of 49 (the "Goal done!"
   toast).
3. **Core (via D3 #1).** The FEAST payout fix, so "Wait for a crowd. FEAST!" is mathematically true on screen.

### D8 Store appeal (7.0 → 8.5)
1. **Store/CI.** Fix the three weakest frames:
   - **P01/D01:** the book closed to about 140°, with no halo at the edge.
   - **P02/D02:** a mid-gulp FEAST with the crowd visible.
   - **P08/D08 Zen:** a calm moment (a crowd sipping, a ladybird), not "Stung!" and "Bzzt!", with a visible "Zen Bog"
     badge in the HUD.
2. **Store copy + CI.** Make every frame truthful and consistent:
   - P04's sub-line becomes "From Red Dragon to B52, and one of gold." (Golden Glow isn't a real cultivar);
   - one progress state across P04, P06 and P09, so the Garden count agrees;
   - P10 and D10 show one "now", not two.
3. **Icon.** Remove or blend the two lip studs (icon about 480,710 and 595,690). Check the icon at 60 pt and 40 pt
   against Fold Smasher's and ChompDuo's in a search mock.

### D9 Polish (7.0 → 9.0)
1. **Scene.** Clear-zone enforcement as a tested rule:
   - **HUD rect:** score, pause, chain and snaps + 24 pt;
   - **midrib:** 20 pt + r + 16 pt;
   - **screen edge:** r + halo.

   Add a CI probe that fails a frame if any bug or halo centre is inside those zones. *Frames 10, 11, 13, 15, 41, 42, 48,
   53–55, P01, P02, P05, D01, D02, D08.*
2. **App/UI.** Pops never cover their subject, and nothing is cut by a scroll:
   - "Stung!" above the ring (15, 40, 43);
   - the hint clear of bugs (43);
   - Results cards fit (20, 26, 27, 47, 50, 51, P09);
   - Zen play and Zen Results agree on whether there's a score (46, 47);
   - Zen Results uses a real Zen run, not the Feed demo result (47 = 26's numbers).
3. **CI + Store copy.** Truth in the capture set:
   - fix 05's args (it duplicates 06);
   - fix the 14, 17, 23 and 26 captions, and make 17 a real night;
   - de-duplicate 15/40, 26/50 and 02/52 (give 40 a different seed, 50 a goals-complete bonus, 52 a 3-of-3 goals state);
   - make D06's "Snap it shut a little" read "Snap it a little shut".

## 4. Merged, prioritised fix list (becomes `design/ROUND-7.md`)

| # | Pri | Owner | Fix | Frames | Lifts |
|---|---|---|---|---|---|
| 1 | **P0** | Scene | **Make the 8 varieties distinct in silhouette** (B52 bigger lobes and fat cilia; Sawtooth saw-edge; Shark Tooth wide triangles; Fused Tooth frill; Cupped deep cup; Golden Glow gold inside). Add a thumbnail-difference check in CI. The store sells "8 flytraps", and 4 look like Classic. | 44, 45, 54, 55, P04, D04 | D1, D6, D8, D7 |
| 2 | **P0** | CI | **Land `duo6`, an R6 hinge run** (commit ≥ `7faf17f`), with SNAP, REARM, CREEP, CLOSE-PAUSE, TOO-FLAT at 178° (prompt plus log), LESSON-HINGE (counter advancing), a goal toast and the Garden. duo5 failed, and duo5b is pre-goals. | duo5, duo5b | D5, D9 |
| 3 | P1 | Core + App/UI | **The FEAST must out-pay a QUAD.** Add a 5+ bonus. The bite pop says "5 bugs · +N" (no "×" for bug count). The FEAST pop is scaled 1.6× and centred, and shows the "+2 snaps" refill. | 14, 18, 39, 48, 49, P02, D02 | D4, D3, D2, D6 |
| 4 | P1 | Scene | **Clear zones as a tested rule:** HUD rect, midrib and screen edge for bugs and halos, plus a CI probe that fails the frame. Bugs stay out from behind Home buttons. | 10, 11, 13, 15, 39, 41, 42, 48, 53–55, 01, 52, P01, P05, D01, D06, D08 | D9, D1 |
| 5 | P1 | App/UI | **One message at a time:** a message queue (≥ 0.4 s apart); "Stung!" above the ring; the hint never over bugs; no three-pop stacks; rename or teach "Lucky!", "Golden!" and "+2 (full)". | 15, 19, 40, 42, 43, 46 | D2, D9 |
| 6 | P1 | Store/CI | **Store frames 1, 2 and 8:** P01/D01 and search at a book of about 140° with no edge-cut halo; P02/D02 mid-gulp with the crowd visible; P08/D08 a calm Zen moment with a "Zen Bog" badge. Promote duo-03's hinge closure to a Duo frame. | P01, P02, P08, D01, D02, D08, search-365pt | D8, D5, D6, D4 |
| 7 | P1 | App/UI | **Results fit:** the third card (rank) is visible without scrolling, and the Daily goals card isn't cut mid-row; no "tired" over a "New best!". | 20, 26, 27, 47, 50, 51, P09 | D9, D1 |
| 8 | P1 | App/UI | **Duo cover card:** centred and filled, "Best score", not "Best feast". Rename the Game Center "Best Feast" leaderboard to "Best Score". (R5 #12 is still open.) | duo-ui-cover, duo-h3 | D5, D9 |
| 9 | P1 | Store copy + CI | **Store truth and consistency:** P04's sub-line drops "Real cultivars" (Golden Glow is fantasy); one progress state across P04, P06 and P09 (6/8 against 2/8); P10 and D10 show one "now"; D06 says "Snap it a little shut". | P04, P06, P09, P10, D04, D06, D10 | D8, D9 |
| 10 | P1 | App/UI + Core | **Zen identity:** a "Zen Bog" badge in the HUD; Zen play and Zen Results agree on the score; Zen Results comes from a real Zen run (47 repeats 26's numbers). | 46, 47, P08, D08 | D9, D3, D8 |
| 11 | P1 | Feel (founder) | Real-Duo §6 test on TestFlight with the R6 build: snap feel, the FEAST CHOMP and burp, the heavy haptic, the Zen bed. | — | D4, D5 |
| 12 | P1 | App/UI | **Duo lesson and too-flat:** the step counter advances with its text ("Step 1 of 4" shows during the reset step); a visible too-flat prompt at 178°. | duo-ui-lesson-3-hinge-128, duo-ui-too-flat-178 | D5, D2 |
| 13 | P2 | App/UI | The SNAPS label at every size (6.3", the Duo), plus a bigger Duo snaps row. (R5 #14 is half done.) | 10, P05 (63), D01–D10 | D2, D9 |
| 14 | P2 | Core + Scene | Night is night: fireflies and crickets dominate 35, and P05 shows 3+ fireflies. 17 is captured at real night. Late-night pacing banner, with expert runs ≤ 6 min (R5 #19 is still open). | 17, 35, 39, P05 | D3, D1 |
| 15 | P2 | Core + App/UI | Goals: an easy, medium and hard label on Home; "Next goal" on Results. Results names the next Bug Book target (R5 #16 is still open). | 02, 26, 50 | D3, D7 |
| 16 | P2 | CI | Capture-set hygiene: fix 05 (it duplicates 06); fix the 14, 17, 23 and 26 captions; de-duplicate 15/40, 26/50 and 02/52; add a frame for each new state (goals 3/3 bonus, Garden pick). | 05, 06, 14, 15, 17, 23, 26, 40, 50, 52 | D9 |
| 17 | P2 | App/UI + Core | No "Hungry… bite!" while a halo overlaps the trap edge (R5 #15 is still open). | 33 | D2 |
| 18 | P2 | Icon | Remove or blend the two lip studs, and check at 60 pt and 40 pt in a search mock. | app-icon-1024 | D8 |
| 19 | P2 | App/UI | The Garden's unlock rules all in one style ("Goal: …" or "Rank: …"); consistent silhouettes for locked cards. | 44 | D1, D2 |

**Order:**
1. #1 (Scene) and #2 (CI) are the P0s and run first.
2. #3–#10 and #12 are the R7 build.
3. #6, #9 and #16 re-shoot `store4` once #1, #3 and #4 land.
4. The founder runs #11 on TestFlight in parallel.
5. Then re-score R7 on this card.

The weakest dimensions, which R7 must move: D9 (needs #4, #5, #7 and #16), D8 (#1, #6, #9) and D4 (#3, #11).
