# Snapjaw: App Store screenshot plan (v1.0)

*Written Tue 27 Oct 2026 by the launch lead. Owner: CI captures and captions, the launch lead writes captions, the founder approves. **Every frame comes from a CI demo scenario**: the app's own rendering, launched with `-snapDemo "…"` (the keys in `design/ROUND-1.md`, "Demo mode") on the iPhone Duo simulator and the iPhone simulators, then captioned on the Mac runner. The pipeline is Swoop's (`C:\Users\59527\Wing\.github\workflows\store.yml`, `ci/store-capture.sh`, `ci/store-set.sh`, `ci/store-frame.swift`), **to be ported by the CI engineer** with the scenario files `ci/store-scenarios.txt` (iPhone sets) and `ci/duo-store-scenarios.txt` (Duo set). Once they exist, **the scenario files are the source of truth**: change a caption there, not only here.*

## Sets, sizes and slots (Apple's *Screenshot specifications*, as read for Swoop on 26 Oct 2026)

Snapjaw plays in **landscape** (the Duo held like a book: a 952 × 670 pt canvas with the fold running top to bottom; other iPhones keep height 670 and get wider, the extra width is bog). Every set is landscape.

| Upload order | App Store Connect slot | Pixels (landscape) | Frames | Artifact | Status |
|---|---|---|---|---|---|
| 1 | **iPhone 6.9"** (Dynamic Island, large display) | **2868 × 1320** | P01–P10 | `store-69` | Upload it: Apple scales it for 6.5" |
| 2 | **iPhone 6.3"** (Dynamic Island, medium display) | **2622 × 1206** | P01–P10 | `store-63` | **Required** (Apple's only required iPhone size); scaled for 6.1" and smaller |
| 3 | **iPhone Duo, inner display** | **2853 × 2007** | D01–D10 | `store-duo` | Swoop found the slot live in App Store Connect on 27 Oct and uploaded to it (`C:\Users\59527\Wing\docs\PROJECT-LOG.md`). Duo screenshots show the "optimized for iPhone Duo" badge; Apple requires them from April 2027 |
| – | iPhone Duo, outer (cover) display | 2034 × 1398 | none | – | Not made: Snapjaw isn't played on the cover |

Rules: PNG, **no alpha channel**, 1–10 per size (**we use all 10**). In search results a landscape set shows **only its first frame**, so frame 1 has to sell the whole game alone, and frames 1–3 must each make sense alone on the product page: **the plant, the bite, the bee.**

## Frame 1 is the Duo held like a book, the trap across the fold

The hero is the whole pitch: **an iPhone Duo standing open like a book at about 140°, the flytrap's two lobes filling its two halves, a crowd of bugs sipping nectar on both lobes, the midrib on the hinge.** Swoop's `store-frame --book` takes D01, a **real Duo inner-display capture** (2853 × 2007), splits it at the fold and maps each half by a true perspective transform onto one page of a stylised Duo, with a graphite bezel, the hinge spine and a soft ground shadow. **No hands.**
- **Truthful:** every screen pixel is the app's, only warped and clipped to the display's corners. The device is the real pose Snapjaw is played in, open at a relaxed book angle, never closed, never flat.
- **Used in every set** as frame 1, including the iPhone sets (from the same Duo capture); the iPhone caption's sub-line says other iPhones play too. It never shows a non-folding iPhone folded.
- **Fallback, automatic:** if D01's capture is missing or isn't the folded inner canvas (`SNAP-T canvas 952x670 fold=1`), P01 is made flat from the iPhone capture and **FLAGGED**. Don't upload a flat P01 without telling the founder.

## Caption style

Swoop's compositor, recoloured for the bog:
- **Layout:** the caption band across the top, the capture under it (book frame on the iPhone slots: caption in a left column, the book on the right).
- **Background:** a diagonal sweep from deep bog green `#0E2A1B` to moss `#1F4A2C`, a soft lime glow `#9BCB3C` behind the capture, a darker band along the bottom.
- **Type:** SF Pro Rounded Heavy, dew white `#F4FBEF`. **One** highlighted word per headline (`*word*` in the scenario file), drawn as bog-ink `#10261A` letters on a nectar-gold `#F2B632` marker swash. Sub-line after ` / ` in SF Pro Rounded Semibold, mist green `#B9D7B0`.
- **Headline ≤ 30 characters** (counted without the asterisks) and ≤ 7 words; never "smash", "squish", "Fold to …", "slam", "flat", "shut" on its own, or a competitor name. The ported `store-set.sh` lints all of these.

## A. iPhone 6.9" (2868 × 1320) and 6.3" (2622 × 1206): 10 frames

Same frames and captions at both sizes. On these phones there is no hinge, so the HUD sits on the right and the hints say "Tap to snap" where they speak about the control; no Duo-only words appear inside a capture.

| # | Story beat (in-game moment) | Headline (count) / sub-line | Demo args (`ci/store-scenarios.txt`) |
|---|---|---|---|
| **P01** | **The plant.** Book composite of D01: the lobes across the fold, four or five bugs sipping on the gold nectar drops | **Your Duo is a *flytrap*** (21) / Best on iPhone Duo. Plays on other iPhones too. | frame `book:D01-book-hero` (fallback capture `screen=play;mode=attract;seed=7;pilot=expert;freezeOn=crowd`) |
| **P02** | **The bite.** 0.12 s after a crowd bite: teeth interlocked at both outer edges, bugs gulped into the midrib, "TRIPLE ×3" and "Feast! +1 snap" popping | **Wait for a crowd. *CHOMP!*** (24) / One bite catches every bug inside. | `screen=play;mode=attract;seed=7;pilot=expert;freezeOn=feast` |
| **P03** | **The bee.** A bee with its white halo sipping among two flies; the hint "Bee! Wait…" | **Never eat a *bee*** (15) / Bees cost snaps. Wait them out. | `screen=play;mode=attract;seed=7;pilot=expert;freezeOn=bee` |
| **P04** | **The economy.** The snaps row down to one trap icon, the hint "Last snap — make it count", a crowd gathering | **Every snap *counts*** (17) / Big bites win snaps back. | `screen=play;mode=feed;seed=7;pilot=casual;freezeOn=lastSnap` |
| **P05** | **The day.** Peach dusk light, moths drifting toward the fold, a dragonfly hovering | **From morning to *night*** (21) / New bugs as the day goes on. | `screen=play;mode=attract;seed=11;pilot=expert;wave=16;freezeOn=crowd` |
| **P06** | **The night.** Blue night, fireflies glowing, crickets on the lobes | **Fireflies light the *night*** (25) / Crickets, moths and a rare Golden Scarab. | `screen=play;mode=attract;seed=11;pilot=expert;wave=24;freezeOn=crowd` |
| **P07** | **The collection.** The Bug Book, mid progress: drawn pages with jokes and counts, silhouettes for the rest | **Fill the *Bug Book*** (17) / 16 species, each with a joke. | `screen=book;progress=mid` |
| **P08** | **The result.** The Results card: protein counting up, best bite, longest chain, bees spared, the rank bar | **One more *go*?** (12) / Best bite, longest chain, bees spared. | `screen=results;seed=7;progress=mid;pilot=expert` |
| **P09** | **The daily.** Home: the title trap, plant rank, best, today's Daily Bog status | **One *Daily Bog* for everyone** (26) / Same bugs, one try that counts. | `screen=home;progress=mid` |
| **P10** | **The lesson.** First Bite step 6: three flies landing together, "Wait for a crowd… now!" | **Learn it in one *First Bite*** (26) / A short lesson on your first go. | `screen=lesson;lessonStep=6` (freeze once all three are sipping) |

**Why this order:** 1–3 are the pitch and the difference from the free toys (the plant, choosing the moment, sparing bees); 4 is the economy that makes it a game; 5–6 the day that changes the cast; 7–9 the reasons to come back; 10 says it's easy to learn.

**P06's sub-line names the scarab, which may not be in the frame:** that's a claim about the game, not the picture, and it's true (GAME-DESIGN §6: rare from noon). If the founder prefers the frame to show everything the sub-line names, use `Crickets and fireflies after dark.` instead.

**Asks to the CI / App engineers for these frames** (none changes the game):
- `freezeOn=feast` must catch a bite of **≥ 3** with the "TRIPLE ×3" pop visible (freeze 0.12 s after the bite, as `snap` does); pick a seed where it's a triple or more.
- A freeze delay (Swoop's `freezeDelay=<s>`) for P05/P06/P10, so the frame is taken once the bugs have settled and the light has changed.
- `screen=book`, `screen=results`, `screen=home` must render with `progress=mid` (rank 4, 9 species, best 3,200: ROUND-1).

## B. iPhone Duo, inner display (2853 × 2007): 10 frames

The same beats as A, captured on the Duo simulator with the hinge held at **150°** and the pilot driving the closure (no tap control). The Duo frames show the **HUD on the right half** (the sharp half, the Duo default) and the Duo wording ("Hold it open like a book") wherever a hint speaks about the control.

| # | Headline (count) / sub-line where it differs from A |
|---|---|
| **D01** | **Your Duo is a *flytrap*** (21) / Hold it open like a book. |
| **D02** | **Wait for a crowd. *CHOMP!*** (24) / Snap it a little shut. Open again. |
| **D03–D09** | as P03–P09 |
| **D10** | as P10 (the Duo variant: the lesson's pose and snap words) |

Every Duo frame must log the folded inner canvas (`SNAP-T canvas 952x670 fold=1`), so a cover-display capture is FLAGGED, never uploaded. D02 should be taken with the drawn closure at the snap (`closure` ≥ 22 in the `SNAP-T trap` line), so the teeth match the caption.

Reserves (not uploaded unless a frame above fails): `R1-closing` **The teeth follow your *hands*** (26) / Snap it a little shut. Open again. (Duo only: `closure=14` with a crowd sipping, the teeth leaning in); `R2-sting` **A wasp? *Bzzt!*** (13) / Wasps sting: two extra snaps. (`freezeOn=sting`). No frame or caption ever says "quick" or "fast": speed is the bugs' business, not the store page's.

## Truthfulness rules (check every frame before upload)

- [ ] **Only what the app renders.** Every screen is an unedited capture (frame 1: only warped onto the device); captions sit outside it. No composited bugs, pops, nectar or light.
- [ ] **Frame 1's device is a real iPhone Duo pose** (book, 140–150°), never a non-folding iPhone drawn folded, never closed or flat.
- [ ] **No hands, no people, no photos** in 1.0's sets.
- [ ] **Every caption is true of the build** (tick against the code, `metadata.md` §10): a Feast at ≥ 3 bugs wins a snap back; bees cost an extra snap; 10 snaps to start; the day runs morning → noon → dusk → night with the named bugs; 16 Bug Book species; the Daily Bog is one scored try a day; First Bite runs on the first go. If any of these change, change the caption.
- [ ] **No "smash" anywhere,** in captions or in any in-game text visible in a frame.
- [ ] **Bees are clearly bees** (halo, stripes) in every frame they appear in, and no frame shows a bee being eaten (P03 is the moment *before*).
- [ ] **The bite looks like a gulp, not a squash** (`metadata.md` §11 ask 1): no red, no flattened bugs.
- [ ] **Seeded states are reachable states:** a crowd of 3–5, a chain of 2–4, "mid progress" are things a real player sees. Never seed a full Bug Book or an impossible score.
- [ ] **The iPhone frames have no Duo-only line inside the capture**; the Duo frames show the HUD on the right half.
- [ ] **Nothing important in the crease band** (x ≈ 456–496 pt) on the Duo frames, except the midrib, which is the point.
- [ ] **No prices, dates, "#1", Apple logos or the "Made for iPhone Duo" badge** drawn into a frame (Guideline 2.3.7; Apple adds its own badge).
- [ ] **Exact size, PNG, no alpha** (MANIFEST says `slot yes`, `alpha no`). Captions readable at 25 % zoom.

## Upload order and checks (the App Store Connect tool, `screenshots` step)

The tool uploads the sets from the store run named by `DEFAULT_STORE_RUN` in `.github/workflows/asc.yml` (or its `store_run` input), in this order, and refuses a set whose MANIFEST isn't `flagged 0 missing 0`. The founder uploads nothing unless App Store Connect shows a slot the API doesn't offer: then Claude says so and names the files.

1. 6.9" slot: `store-69` P01–P10. 2. 6.3" slot: `store-63`, the same. 3. iPhone Duo slot: `store-duo` D01–D10, then check them in App Store Connect's preview.

**Never upload** anything in `_flagged/`, anything from a `raw-*` artifact, or anything from `ci.yml`'s `screenshots` artifact (test frames).

## Sources
- Apple, App Store Connect Help, *Screenshot specifications*: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App Review Guideline 2.3.7 (no prices in screenshots): https://developer.apple.com/app-store/review/guidelines/
- Swoop's plan and pipeline (mirrored): `C:\Users\59527\Wing\docs\appstore\screenshots.md`, `C:\Users\59527\Wing\ci\store-*`
