# Snapjaw: App Store screenshot plan (v1.0)

*Written Tue 27 Oct 2026 by the launch lead. Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-snapDemo "…"` (the keys in `design/ROUND-1.md`, "Demo mode") on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. The pipeline is Swoop's (`C:\Users\59527\Wing\.github\workflows\store.yml`, `ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`), **to be ported by the CI engineer** with the scenario files `ci/store-scenarios.txt` (iPhone sets) and `ci/duo-store-scenarios.txt` (Duo set). Once they exist, **the scenario files are the source of truth**: change a caption there, not only here.*

## Sets, sizes and slots (Apple's *Screenshot specifications*, as read for Swoop on 26 Oct 2026)

Snapjaw plays in **landscape** (the Duo held like a book: a 951 × 669 pt canvas with the fold running top to bottom; other iPhones keep height 670 and get wider, the extra width is bog). Every set is landscape.

| Upload order | App Store Connect slot | Pixels (landscape) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **2868 × 1320** | P01–P10 | `store-69` | Upload it: Apple scales it for 6.5" |
| 2 | **iPhone 6.3"** (Dynamic Island, medium display) | **2622 × 1206** | P01–P10 | `store-63` | **Required** (Apple's only required iPhone size); scaled for 6.1" and smaller |
| 3 | **iPhone Duo, inner display** | **2853 × 2007** | D01–D10 | `store-duo` | Swoop found the slot live in App Store Connect on 27 Oct and uploaded to it (`C:\Users\59527\Wing\docs\PROJECT-LOG.md`). Duo screenshots show the "optimized for iPhone Duo" badge; Apple requires them from April 2027 |
| – | iPhone Duo, outer (cover) display | 2034 × 1398 | none | – | Not made: Snapjaw isn't played on the cover |

Rules: PNG, **no alpha channel**, 1–10 per size (**we use all 10**). In search results a landscape set shows **only its first frame**, so frame 1 has to sell the whole game alone, and frames 1–3 must each make sense alone on the product page: **the plant, the FEAST, the bee.**

## Frame 1 is the Duo held like a book, the trap across the fold

The hero is the whole pitch: **an iPhone Duo standing open like a book at about 140°, the flytrap's two lobes filling its two halves, a crowd of bugs sipping nectar on both lobes, the midrib on the hinge.** Swoop's `store-frame --book` takes D01, a **real Duo inner-display capture** (2853 × 2007), splits it at the fold and maps each half by a true perspective transform onto one page of a stylised Duo, with a graphite bezel, the hinge spine and a soft ground shadow. **No hands.**
- **R7 (SCORE-R6 #6): the fold must read at 365 pt.** store3's book was drawn at 146° from a hinge held at 150°, seen almost head-on, and the panel read it as ~170°. D01 is now shot with the real hinge at **140°** (`ciHinge=140`); the composite's angle is that logged angle (store-set.sh keeps 130–150°, else 140°); and the camera sits higher and closer (tilt 15°, 2.8 page heights; on the iPhone slots the book also turns 5° toward the caption), so both the top and the bottom edge bow toward the spine. The bee halo cut by the right edge in P01/D01 is Scene's clear-zone rule (R7 #4): eyeball it.
- **Truthful:** every screen pixel is the app's, only warped and clipped to the display's corners. The device is the real pose Snapjaw is played in, open at a relaxed book angle, never closed, never flat.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture); the iPhone caption's sub-line says other iPhones play too. It never shows a non-folding iPhone folded.
- **Fallback, automatic:** if D01's capture is missing or isn't the folded inner canvas (`SNAP-T canvas 951x669 fold=1`), P01 is made flat from the iPhone capture and **FLAGGED**. Don't upload a flat P01 without telling the founder.

## Caption style

Swoop's compositor, recoloured for the bog:
- **Layout:** the caption band across the top, the capture under it (book frame on the iPhone slots: caption in a left column, the book on the right).
- **Background:** a diagonal sweep from deep bog green `#0E2A1B` to moss `#1F4A2C`, a soft lime glow `#9BCB3C` behind the capture, a darker band along the bottom.
- **Type:** SF Pro Rounded Heavy, dew white `#F4FBEF`. **One** highlighted word per headline (`*word*` in the scenario file), drawn as bog-ink `#10261A` letters on a nectar-gold `#F2B632` marker swash. Sub-line after ` / ` in SF Pro Rounded Semibold, mist green `#B9D7B0`.
- **Headline ≤ 30 characters** (counted without the asterisks) and ≤ 7 words; never "smash", "squish", "Fold to …", "slam", "flat", "shut" on its own, or a competitor name. The ported `store-set.sh` lints all of these.

## A. iPhone 6.9" (2868 × 1320) and 6.3" (2622 × 1206): 10 frames

Same frames and captions at both sizes. On these phones there is no hinge, so the HUD sits on the right and the hints say "Tap to snap" where they speak about the control; no Duo-only words appear inside a capture. **R6 storyboard (founder, 28 Oct):** the economy, dusk and Daily frames (R5's 04, 05, 09) make way for R6's reasons to come back: the Garden (04), goals with the Daily streak (06) and the Zen Bog (08); P02 is now the big FEAST. Names, args and captions below are copied from `ci/store-scenarios.txt` and `ci/duo-store-scenarios.txt`, which win if the two ever differ (`tools/appstore/build-metadata.js` checks the file names against them).

| # (file) | Story beat (in-game moment) | Headline (count) / sub-line | Demo args (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **P01** `P01-book-hero` | **The plant.** Book composite of D01: the lobes across the fold, a crowd of bugs sipping on the gold nectar drops | **Your Duo is a *flytrap*** (21) / Best on iPhone Duo. Plays on other iPhones too. | frame `book:D01-book-hero` (fallback capture `screen=play;seed=7;wave=6;pilot=perfect;freezeOn=crowd`) |
| **P02** `P02-feast` | **The big FEAST, mid-gulp.** 0.12 s into a bite of 5+ bugs: the jaws shut, the crowd still held over them and gulped into the midrib one after another, the bite pop | **Wait for a crowd. *FEAST!*** (24) / One bite catches every bug inside. | `screen=play;mode=feed;pilot=expert;progress=late;freezeOn=snap;freezeAfter=10.5` |
| **P03** `P03-bee` | **The bee.** A bee with its white halo sipping among the flies; the hint "Bee! Wait…" | **Never eat a *bee*** (15) / Bees cost snaps. Wait them out. | `screen=play;seed=7;wave=15;pilot=perfect;freezeOn=bee` |
| **P04** `P04-garden` | **The Garden.** Late progress: 6 of 8 grown (Classic, Red Dragon, B52 …) with their blurbs, two as silhouettes with their unlock rule | **Grow *8 flytraps*** (15) / From Red Dragon to B52, and one of gold. | `screen=garden;progress=late` |
| **P05** `P05-night` | **The night.** Blue night, fireflies glowing, night bugs in the trap | **Fireflies light the *night*** (25) / New bugs as the day goes on. | `screen=play;seed=7;wave=24;pilot=expert;freezeOn=crowd;freezeAfter=3` |
| **P06** `P06-goals` | **Goals and the streak.** Home, late progress (Garden 6/8, as P04): the Goals card (three goals with progress), the rank bar, the Daily Bog button with its 🔥 streak badge | **Three *goals* every run** (21) / And a Daily Bog with a streak. | `screen=home;progress=late` |
| **P07** `P07-bug-book` | **The collection.** The Bug Book, late progress (as P06's Home): the 16 drawn pages with jokes and counts, bees "spared" | **Fill the *Bug Book*** (17) / 16 species, each with a joke. | `screen=book;progress=late` |
| **P08** `P08-zen` | **The Zen Bog, calm.** Zen play 25 s in, frozen on a crowd sipping (a state, so no fresh pop or sting): the Zen Bog badge, no snaps row | **Or just *relax*** (13) / Zen Bog: no rush, no end. | `screen=play;mode=zen;pilot=casual;progress=late;freezeOn=crowd;freezeAfter=25` |
| **P09** `P09-results` | **The result.** Results, late progress: the score counting up under the best to beat (14,800), best bite, best chain, bees spared, the Goals card ticked with "+n growth", the rank bar | **One more *go*?** (12) / Goals, growth and a best to beat. | `screen=results;pilot=casual;progress=late` |
| **P10** `P10-first-bite` | **The lesson.** First Bite step 6: three flies landing together, "Wait for a crowd… now!" | **Learn it in one *First Bite*** (26) / A short lesson on your first go. | `screen=lesson;lessonStep=6` |

**Why this order:** 1–3 are the pitch and the difference from the free toys (the plant, choosing the moment and its payoff, sparing bees); 4–9 are the reasons to come back, alternating progress and play (the Garden, the night, goals and the streak, the Bug Book, the Zen Bog, the results that feed it all); 10 says it's easy to learn.

**Caption notes (truth):**
- **P02:** a big FEAST is a clean bite of 5 or more (or one at ×4 chain or more, `FeastEvent.isBig`). R7: the frame is the gulp, not the glitter after it. The seeded expert run bites 3, 4, then 5 bugs (~5.7, ~8.8 and ~12.4 s on all three devices in store3), so `freezeOn=snap;freezeAfter=10.5` holds 0.12 s after the 5-bug bite, and the expect (`caught=[5-9]`) FLAGS the frame if the timing ever moves. A `feastGulp` freeze tag is asked of App (`design/notes/ci-R7.md`).
- **P04:** "From Red Dragon to B52, and one of gold" (R7: no longer "Real cultivars"; Golden Glow is the game's own fantasy and the old line half-claimed it). Red Dragon and B52 are real cultivar names; the gold one is Golden Glow.
- **One progress state (R7, SCORE-R6 #9):** every frame that shows progress (P02 and P08's HUD, P04, P06, P07, P09) uses `progress=late`, so the set reads as one player: Garden 6 of 8 on P04 and on P06's Home, Bug Book 16/16 on P06 and P07, best 14,800. `tools/appstore/build-metadata.js` fails if two states ever appear.
- **P06:** "Three goals every run" means the three active goals are there in every run (on Home and in the pause menu); progress on an unfinished goal carries over to the next run. The 🔥 badge shows from a 2-day streak; `progress=late` carries 4.
- **P08:** "no rush, no end" is the Home button's own sub-line; Zen has no hunger and no snaps running out. R7: a calm moment (a crowd sipping), never "Stung!" or "Bzzt!" (store3's D08).
- **P09:** the best to beat is the Feed best (late: 14,800, so no "New best!" over a tired trap); the Goals card shows the run's three goals, ticked where done, and the expect FLAGS a run that ticked none.
- **P10 and D10:** the same lesson step (6) and the same caption; the card's line differs only by the control ("now tap!" on a phone, "now!" on the Duo). The "Now!" pill under it doubles the cue: App is asked to let the pill carry it (`design/notes/ci-R7.md`).

**Asks to the CI / App engineers for these frames** (none changes the game): `screen=garden;progress=late` must show grown and locked varieties side by side; `screen=home`, `screen=book` and `screen=results` must render with `progress=late` (rank 10, 16 species, best 14,800, a goal book and a Daily streak of at least 2). R7 asks (`design/notes/ci-R7.md`): a `feastGulp` freeze tag for P02/D02; Home's pose card saying "Snap it a little shut" (D06); one "now" on P10/D10.

## B. iPhone Duo, inner display (2853 × 2007): 10 frames

The same beats as A, captured on the Duo simulator with the hinge held at **150°** (D01 at **140°**, `ciHinge=140`, for the book) and the pilot driving the closure (no tap control). The Duo frames show the **HUD on the right half** (the sharp half, the Duo default) and the Duo wording ("Hold it open like a book") wherever a hint speaks about the control.

| # (file) | Headline (count) / sub-line where it differs from A |
|---|---|
| **D01** `D01-book-hero` | **Your Duo is a *flytrap*** (21) / Hold it open like a book. (frame `book`) |
| **D02** `D02-feast` | **Wait for a crowd. *FEAST!*** (24) / Snap it a little shut. Open again. (the same mid-gulp freeze as P02) |
| **D03–D10** `D03-bee`, `D04-garden`, `D05-night`, `D06-goals`, `D07-bug-book`, `D08-zen`, `D09-results`, `D10-first-bite` | as P03–P10 (D06: Home's Duo pose card must read "Snap it a little shut", an App string; D10: the Duo variant, the lesson's pose and snap words; eyeball its hint) |

Every Duo frame must log the folded inner canvas (`SNAP-T canvas 951x669 fold=1 hudLeft=0`), so a cover-display capture is FLAGGED, never uploaded.

Reserves (not uploaded unless a frame above fails; the full list is in the scenario files): phone `R2-sting` **A wasp? *Bzzt!*** (13) / Wasps sting: two extra snaps.; Duo `DR1-closing` **The teeth follow your *hands*** (27) / Snap it a little shut. Open again. (`closure=14`, the teeth leaning in), `DR2-sting`, and the R5 reserves DR3–DR14 (among them `DR14-chain5`, "Chain bites to x5"). No frame or caption ever says "quick" or "fast": speed is the bugs' business, not the store page's.

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture (frame 1: only warped onto the device); captions sit outside it. No composited bugs, pops, nectar or light.
- [ ] **Frame 1's device is a real iPhone Duo pose** (book, about 140°: the hinge angle D01 was shot at), never a non-folding iPhone drawn folded, never closed or flat. The fold must read in the 365 pt search thumbnail.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build** (tick against the code, `metadata.md` §10): a Feast at ≥ 3 bugs wins a snap back and a big FEAST is 5+; bees cost an extra snap; 10 snaps to start, 14 at most; the chain to ×5, grown by bites of 2+ bugs; the day runs morning → noon → dusk (wave 15) → night (wave 23); 16 Bug Book species; 8 Garden flytraps; three active goals from 39; the Zen Bog never ends and has no leaderboard; the Daily Bog is one scored try a day, with a streak; First Bite runs on the first go. If any of these change, change the caption.
- [ ] **No "smash" or "Fold to …" anywhere,** in captions or in any in-game text visible in a frame.
- [ ] **No "protein"** on any Results, HUD or Home frame (the word is "score").
- [ ] **Bees are clearly bees** (halo, stripes) in every frame they appear in, and no frame shows a bee being eaten (P03 is the moment *before*).
- [ ] **The bite looks like a gulp, not a squash** (`metadata.md` §11 ask 1): gold juice, no red, no flattened bugs (P02 especially).
- [ ] **Seeded states are reachable states:** a crowd of 3–7, a chain of 2–5, "mid" and "late" progress are things a real player sees. Never seed a full Garden or an impossible score. (`late`'s full Bug Book is a real rank-10 state; R7 shows it on P06 and P07 so the set agrees with itself.)
- [ ] **The iPhone frames have no Duo-only line inside the capture**; the Duo frames show the HUD on the right half.
- [ ] **Nothing important in the crease band** (x ≈ 456–496 pt) on the Duo frames, except the midrib, which is the point.
- [ ] **No prices, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha** (MANIFEST says `slot yes`, `alpha no`). Captions readable at 25 % zoom.

## Upload order and checks (the App Store Connect tool, `screenshots` step)

The tool uploads the sets from the store run named by `DEFAULT_STORE_RUN` in `.github/workflows/asc.yml` (or its `store_run` input), in this order, and refuses a set whose MANIFEST isn't `flagged 0 missing 0`. The founder uploads nothing unless App Store Connect shows a slot the API doesn't offer: then Claude says so and names the files.

1. 6.9" slot: `store-69` P01–P10. 2. 6.3" slot: `store-63`, the same. 3. iPhone Duo slot: `store-duo` D01–D10, then check them in App Store Connect's preview.

**Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames).

## Sources
- Apple, App Store Connect Help, *Screenshot specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Swoop's plan and pipeline (mirrored): `C:\Users\59527\Wing\docs\appstore\screenshots.md`, `C:\Users\59527\Wing\ci\store-*`
