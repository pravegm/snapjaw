# Snapjaw: App Store screenshot plan (v1.0)

*First written Tue 27 Oct 2026 by the launch lead. **R9 storyboard (Wed 28 Oct 2026, store lead, `design/notes/store-R9.md`)** for the R8 game: the phone is the trap (open = open, the bite fires as the phone closes), the outer display's CHOMP card, 30 Levels in three worlds (the First Bite lesson is gone), Endless, the Daily Bog, the Zen Bog. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-snapDemo "…"` (keys in `Snap/App/DemoMode.swift`) on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner by `.github/workflows/store.yml` (`ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`). **The scenario files are the source of truth**: `ci/store-scenarios.txt` (iPhone sets) and `ci/duo-store-scenarios.txt` (Duo set). Change a caption there; `tools/appstore/build-metadata.js` fails if this page stops quoting an iPhone sub-line or naming a Duo frame.*

## Sets, sizes and slots (Apple's *Screenshot specifications*, re-read 28 Oct 2026)

Snapjaw plays in landscape on phones (the Duo inner canvas is 951 × 669 pt, the fold top to bottom) and also in portrait on the Duo (the scene turned). Every uploaded set is landscape.

| Upload order | App Store Connect slot | Pixels (landscape) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **2868 × 1320** | P01–P10 | `store-69` | Optional (Apple falls back to Face ID large); we upload it |
| 2 | **iPhone 6.3"** (Dynamic Island, medium display) | **2622 × 1206** | P01–P10 | `store-63` | **Required**: "at least one screenshot for iPhone with Dynamic Island (medium display)" |
| 3 | **iPhone Duo, inner display** | **2853 × 2007** | D01–D10 | `store-duo` | Optional today (required from April 2027 for iOS 27.1 SDK apps); it earns the product page's "optimized for iPhone Duo" badge. Swoop uploaded to it on 27 Oct |
| – | iPhone Duo, outer display | 2034 × 1398 (portrait 1398 × 2034) | none by default | – | A real slot. The CHOMP card on the real cover panel is reserve `DR12-cover` (1398 × 2034). The tool can push a `duoOuter` set, but it shares the iPhone Duo placement group with the inner set, so 1.0 keeps D02 (the same card on the inner panel) instead. Founder's call (`store-R9.md`) |

Rules: PNG or JPEG, **no alpha channel**, 1–10 per size (**we use all 10**). In search results a landscape set shows **only its first frame**, so frame 1 sells the whole game alone, and frames 1–3 each make sense alone: **the Duo is the trap; close it to bite; wait for a crowd.**

Product page header and search results art (Apple's creative assets, iOS 27): **header 3840 × 1646** (21:9) and **search 3840 × 2560** (3:2), opaque, drawn by `ci/store-placements.sh` + `ci/store-banner.swift` from D01's real Duo capture in the same `store.yml` run (artifact `store-placements`): the wordmark "Snapjaw", the tagline "Feed the flytrap. Spare bees." (= the subtitle), and the book-pose Duo; the search art carries D01's caption. Fallback hero: D03-feast.

## Frame 1 is the Duo standing open, the trap across the fold

The hero is the whole pitch: **an iPhone Duo standing open at about 140°, the flytrap's two lobes filling its two halves, a crowd of bugs sipping nectar on both lobes, the midrib on the hinge.** `store-frame --book` takes D01, a **real Duo inner-display capture** (2853 × 2007, shot with the hinge at 140°, `ciHinge=140`), splits it at the fold and maps each half onto one page of a stylised Duo with a graphite bezel, the hinge spine and a soft ground shadow. **No hands.**
- **Truthful:** every screen pixel is the app's, only warped. Open phone = open trap is exactly what the frame shows: the phone open, the trap open.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture); the iPhone caption's sub-line gives the tap control.
- **Fallback, automatic:** if D01's capture is missing or isn't the folded inner canvas (`SNAP-T canvas 951x669 fold=1`), P01 is made flat from the iPhone capture and **FLAGGED**. Don't upload a flat P01 without telling the founder.

## Caption style

- **Layout:** the caption band across the top, the capture under it (the book frame on the iPhone slots: caption in a left column, the book on the right).
- **Background:** a diagonal sweep from deep bog green `#0E2A1B` to moss `#1F4A2C`, a soft lime glow `#9BCB3C` behind the capture, a darker band along the bottom.
- **Type:** SF Pro Rounded Heavy, dew white `#F4FBEF`. **One** highlighted word per headline (`*word*` in the scenario file), bog-ink `#10261A` on a nectar-gold `#F2B632` swash. Sub-line after ` / ` in SF Pro Rounded Semibold, mist green `#B9D7B0`.
- **Headline ≤ 30 characters** (without the asterisks) and ≤ 7 words; never "smash", "squish", "Fold to …", "slam" (REJECTED by store-frame), "flat", "shut" on its own, "quick", "fast", "free", a price or "#1" (FLAGGED by store-set, sub-line included). Never "lid" (founder rule: "phone"), never a pose demand.

## A. iPhone 6.9" (2868 × 1320) and 6.3" (2622 × 1206): 10 frames

Same frames and captions at both sizes. These phones have no hinge: the HUD sits on the right, a tap is the bite and the hints say "Tap to snap". **No Duo-only screen appears inside an iPhone capture** (so the CHOMP card, the Duo's outer display, is in the Duo set only; `build-metadata.js` fails if a P frame uses `screen=chomp|shut|cover`).

| # (file) | Story beat (in-game moment) | Headline (count) / sub-line | Demo args (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **P01** `P01-book-hero` | **The Duo is the trap.** Book composite of D01: the lobes across the fold, a crowd sipping on the gold nectar | **Your Duo is a *flytrap*** (21) / Close your Duo to bite. Other iPhones: tap. | frame `book:D01-book-hero` (fallback `screen=play;seed=7;wave=6;pilot=perfect;freezeOn=crowd`) |
| **P02** `P02-feast` | **The FEAST.** 0.45 s after a clean 5-bug bite, the lobes open again: "FEAST!", "5 bugs · +360", the "FEAST! +2 snaps" chip, the ×2.5 chain (R8 CI frame 48) | **Wait for a crowd. *FEAST!*** (24) / Five bugs in one bite: double score. | `screen=play;mode=feed;pilot=expert;progress=late;freezeOn=bigFeast` |
| **P03** `P03-bee` | **The bee.** A bee with its white halo sipping among the flies; the hint "Bee! Wait…" | **Never eat a *bee*** (15) / Bees cost snaps. Wait them out. | `screen=play;seed=7;wave=15;pilot=perfect;freezeOn=bee` |
| **P04** `P04-levels` | **30 levels.** The level map, late progress: Morning Bog ★ 28, Dusk ★ 26, Night open and picked (★ 6), levels 21–23 starred, 24 glowing, "★ 60 of 90" (R8 CI frame 60) | **30 *levels* to master** (19) / Morning Bog, Dusk and Night. Three stars each. | `screen=levels;progress=late` |
| **P05** `P05-night` | **The night.** Blue night, fireflies glowing, night bugs and a wasp in the trap, "Bee! Wait…" (R8 CI frame 35) | **Fireflies light the *night*** (25) / Endless runs from morning to night. | `screen=play;seed=7;wave=24;pilot=expert;freezeOn=landed` |
| **P06** `P06-garden` | **The Garden.** Late progress: 6 of 8 grown with their blurbs, two silhouettes with their unlock rule | **Grow *8 flytraps*** (15) / From Red Dragon to B52, and one of gold. | `screen=garden;progress=late` |
| **P07** `P07-bug-book` | **The collection.** The Bug Book, late progress: the 16 drawn pages with jokes and counts | **Fill the *Bug Book*** (17) / 16 species, each with a joke. | `screen=book;progress=late` |
| **P08** `P08-zen` | **The Zen Bog, calm.** Zen play 25 s in, frozen on a crowd sipping: the ZEN BOG badge, no snaps row | **Or just *relax*** (13) / Zen Bog: no rush, no end. | `screen=play;mode=zen;pilot=casual;progress=late;freezeOn=crowd;freezeAfter=25` |
| **P09** `P09-goals` | **Everything on Home.** Late progress: Play "Level 24 · One bite, 5 bugs", the Goals card, ★ 60 and best 14,800, the Endless / Daily (🔥 4) / Zen pads, Levels, 16/16, 6/8 (R8 CI frame 52) | **Three *goals* at a time** (21) / Plus Endless, a Daily Bog and Zen. | `screen=home;progress=late` |
| **P10** `P10-results` | **The result.** Endless Results after an expert run: the big score, "New best!", the four stats, the Goals card ticked, the rank bar (R8 CI frame 50, there with `mid`) | **One more *go*?** (12) / Goals, growth and a best to beat. | `screen=results;seed=7;pilot=expert;progress=late` |

**Why this order:** 1–3 are the pitch and the difference from the free toys (the Duo is the trap, choosing the moment and its payoff, sparing bees); 4 says there is a lot of game (and a hard one); 5–10 alternate play and progress (the night, the Garden, the Bug Book, Zen, Home with goals and the modes, the results that feed it all).

## B. iPhone Duo, inner display (2853 × 2007): 10 frames

Captured on the Duo simulator with the hinge held at **150°** (D01 at **140°**) and the pilot driving the trap. The Duo frames show the **HUD on the right half** and the Duo's own hint words. The pilot's bites are drawn by the Scene, so the Duo frames freeze only on **open-trap** moments (a crowd, a bee, the FEAST pop after the lobes reopen): never lobes drawn shut on the inner screen, which a real Duo never shows.

| # (file) | Story beat | Headline (count) / sub-line | Demo args (`ci/duo-store-scenarios.txt`) |
|---|---|---|---|
| **D01** `D01-book-hero` | The Duo is the trap (frame `book`) | **Your Duo is a *flytrap*** (21) / Open phone, open trap. Close it to bite. | `…;freezeOn=crowd;ciHinge=140` |
| **D02** `D02-chomp` | **The bite, on the outer screen.** The CHOMP card: the closed trap from outside with a bump per bug, "CHOMP!", "4 bugs · +128", the verdict, "Open to keep feeding", the score (R8 CI frame 09, there on a phone sim). A real bite of 3+ bugs, played headless first | **Close the phone. *CHOMP!*** (23) / The outer screen shows your catch. | `screen=chomp;chomp=catch` |
| **D03** `D03-feast` | The FEAST, as P02 | **Wait for a crowd. *FEAST!*** (24) / A slow close? The flies escape. | as P02 |
| **D04** `D04-bee` | as P03 | **Never eat a *bee*** (15) / as P03 | as P03 |
| **D05** `D05-levels` | as P04 | **30 *levels* to master** (19) / as P04 | as P04 |
| **D06** `D06-night` | as P05 | **Fireflies light the *night*** (25) / as P05 | as P05 |
| **D07** `D07-garden`, **D08** `D08-bug-book`, **D09** `D09-zen`, **D10** `D10-goals` | as P06, P07, P08, P09 | as P06–P09 | as P06–P09 |

The Duo set has no Results frame (the CHOMP card took its place); `DR3-results` is its reserve. Every Duo frame must log the folded inner canvas (`SNAP-T canvas 951x669 fold=1 hudLeft=0`), so a cover-display capture is FLAGGED, never uploaded.

**Caption notes (truth):**
- **D02:** the card is the outer display's (`UI/ChompCard.swift`), forced onto the inner panel by the demo (`screen=chomp`), so its pixels are the app's. The sub-line says where it really appears. "Fast close" on the card is the app's verdict for a close under 0.3 s; the caption never says "fast". The expect FLAGS a made-up bite (`SNAP-T chomp card catchBite made up`).
- **P02 / D03:** a FEAST is a clean bite of 5+ bugs (`Tuning.bigFeastCount`), scored ×2 (`feastMultiplier`) with 2 snaps back (`bigFeastRefund`); the expect requires `feast count=[5-9] snapsBack=2`. D03's sub-line is the R8 skill (flies flee a slow close), said without a speed word.
- **P04 / D05:** "Three stars each": every level gives 1–3 stars (`LevelOutcome.stars`); `late` shows 60 of 90, the same ★ 60 as Home on P09/D10.
- **P05 / D06:** Endless's day: noon at wave 7, dusk 15, night 23 (`Tuning`); wave 24 is night. (R8 CI: wave 26 + `freezeOn=crowd` never froze; wave 24 + `landed` did.)
- **P09 / D10:** "Three goals at a time" (`Tuning.goalsActive` 3, pool of 39); the goals are Endless, Daily and Zen's, not the levels'; the sub-line names those three modes.
- **One progress state:** every frame that shows progress uses `progress=late`, so the set reads as one player (★ 60, Garden 6/8, Bug Book 16/16, best 14,800). `build-metadata.js` fails if two states appear.

Reserves (not uploaded unless a frame above fails; the full list is in the scenario files): phone `R2-sting`, `R3-level-5` (Level 5 in play, a crowd of three), `R4-daily`; Duo `DR2-sting`, `DR3-results`, `DR4-portrait` (the Duo held like a laptop: FLAGGED by design, its canvas is portrait), `DR5-level-5`, `DR6-chomp-sting`, `DR7-landed`, `DR9-play`, `DR10-hud-left` (FLAGGED by design), `DR11-daily`, `DR12-cover` (the real outer display, 1398 × 2034: FLAGGED in this set by design), `DR14-chain5`. **No level-results frame:** in R8 CI the perfect pilot did not pass Level 1 (`SNAP-T level result 1 stars=0`), so a "three stars" Results frame is not safe yet (`store-R9.md` app ask).

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture (frame 1: only warped onto the device); captions sit outside it.
- [ ] **Frame 1's device is a real iPhone Duo pose** (open at about 140°), never a non-folding iPhone drawn folded. The fold must read in the 365 pt search thumbnail.
- [ ] **No inner-screen frame shows the lobes drawn shut** (on a real Duo the phone itself closes; the inner screen never animates the bite).
- [ ] **No hands, no people, no photos.**
- [ ] **Every caption is true of the build** (`metadata.md` §10): the bite fires as the phone closes and a partial close never bites; a Feast ≥ 3 (+1 snap), a FEAST a clean ≥ 5 (×2, +2 snaps); bees cost an extra snap, wasps 2; 12 snaps to start, 14 at most; 30 levels in 3 worlds with 1–3 stars; the day runs morning → night; 16 species; 8 flytraps; three goals from 39; the Zen Bog never ends and has no leaderboard.
- [ ] **No "smash", "Fold to …", "lid" or a pose demand** anywhere, in captions or in any in-game text visible in a frame.
- [ ] **Bees are clearly bees** (halo, stripes), and no frame shows a bee being eaten.
- [ ] **The bite looks like a gulp, not a squash:** gold juice, no red, no flattened bugs (P02/D03 especially).
- [ ] **Seeded states are reachable states:** `late` (rank 10, 16 species, ★ 60, best 14,800) is a real state.
- [ ] **The iPhone frames have no Duo-only screen**; the Duo frames show the HUD on the right half.
- [ ] **Nothing important in the crease band** on the Duo frames, except the midrib.
- [ ] **No prices, "#1", Apple logos or the "optimized for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha** (MANIFEST says `slot yes`, `alpha no`, and `summary: ok 10 flagged 0 missing 0`). Captions readable at 25 % zoom.

## Upload order and checks (the App Store Connect tool, `screenshots` step)

The tool uploads the sets from the store run named by `asc.yml`'s `store_run` input (or `DEFAULT_STORE_RUN`), in this order, and refuses a set whose MANIFEST isn't `flagged 0 missing 0`: 1. 6.9" `store-69` P01–P10. 2. 6.3" `store-63`, the same. 3. iPhone Duo `store-duo` D01–D10 (if the API offers no iPhone Duo group, the tool says so and the founder uploads the 10 Duo PNGs by hand). The header and search art go up with `placements_run` (the same store run's `store-placements` artifact).

**Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames).

## Sources
- Apple, App Store Connect Help, *Screenshot specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple, App Store Connect Help, *Creative assets specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
