# Snapjaw: App Store metadata (v1.0)

*First written Tue 27 Oct 2026 by the launch lead, mirroring Swoop's submitted kit (`C:\Users\59527\Wing\docs\appstore\`) and Hush's (`C:\Users\59527\Lid\docs\appstore\`). Nobody pastes these: `node tools/appstore/build-metadata.js` turns the code blocks into `docs/appstore/asc-metadata.json`, and `asc.yml` pushes that. Change the text here, then regenerate. Counts are Unicode characters (counted with Node), except keywords, which Apple counts in bytes (all ASCII here, so the same).*

*R9 rewrite (Wed 28 Oct 2026, store lead, `design/notes/store-R9.md`):* the copy now describes the **R8 game** (`design/ROUND-8.md`): **the phone is the trap.** Open phone = open trap; the bite fires as the phone **closes** (at about 18°, or when iOS reports it closed), and a partial close never bites; flies flee a slow close, so the skill is when and how decisively you close; while it is shut the outer display shows the CHOMP card; every round starts closed; no pose is ever asked for (landscape and portrait both play). The First Bite lesson is gone: **30 Levels** in three worlds (Levels 1–5 teach) sit beside **Endless** (the old Feed), the **Daily Bog** and the **Zen Bog**. Every number was re-read in the R8 source (`Snap/Core/Tuning.swift`, `LevelData.swift`, `Levels.swift`, `Goals.swift`, `Varieties.swift`, `Progression.swift`, `Snap/UI/HomeView.swift`, `SettingsView.swift`). Removed as untrue: "snap it a little shut", "about 22°", "hold it open like a book", the closing pause, "Bend it a little", "10 snaps to start" (12 now), First Bite and "Replay First Bite". `build-metadata.js` fails if any of them comes back.

**Words the copy uses** (the game's own words): *open*, *close the phone*, *bite*, *CHOMP*, *catch*, *crowd*, *sip / nectar*, *Feast* (3+ bugs) and *FEAST* (a clean 5+), *chain*, *never eat a bee*, *let go* (a bee in a bite), *spare*, *snaps* (the resource: every bite costs one), *the trap is tired*, *score*, *Levels*, *stars*, *Morning Bog / Dusk / Night* (the worlds), *Endless*, *Daily Bog*, *streak*, *Share*, *Zen Bog*, *goals*, *growth*, *the Garden* and its *flytraps*, *Bug Book*, *plant rank*. **Never:** "lid" (founder rule: say "phone"), "smash", "squash", "squish", "kill", "die", "splat", "slam", "fast", "quick", "as fast as you can", "Fold to …", "hold it like a book" or any other pose demand, and no competitor names anywhere.

**The pitch order:** lead with **the plant on the Duo** (the phone is the trap), then **the bite** (close it: CHOMP, on the outer screen), then **choosing** (wait for a crowd, never eat a bee), then the reasons to come back (30 levels, Endless, goals and the Garden, the Daily streak, Zen).

Localisations: **English (U.K.)** is the primary language, plus **English (U.S.)**. Every other storefront shows en-GB. Only the description differs between the two (§4); everything else is identical.

---

## 1. App name (limit 30)

```
Snapjaw
```
**7 / 30.** The name check (`research/01-market.md`) found **no game called Snapjaw**. It reads as both "snap" and "jaws", and fits the studio's one-word names (Squish, Brim, Swoop, Hush). The App Store record already exists (Apple ID 6828066230), so the name is held.

If App Store Connect ever says the name is taken, the fallbacks are `Snapjaw: Venus Flytrap` (22), `Snapjaw: Flytrap` (16). The home-screen name under the icon is **Snapjaw** (`CFBundleDisplayName`).

## 2. Subtitle (limit 30)

```
Feed the flytrap. Spare bees.
```
**29 / 30**, the same in en-GB and en-US. Still true of R8 and still the app's own tagline (`AppBrand.tagline`), which the product page header art draws under the wordmark (`ci/store-banner.swift`), so the subtitle, the header and Home agree. It indexes "feed", "flytrap", "spare" and "bees" without spending keyword bytes. No price, superlative or Apple mark (Guideline 2.3.7).

## 3. Promotional text (limit 170; can change any time without a new version)

```
Your iPhone Duo is a Venus flytrap. Open it, wait for a crowd, then close it to bite. Never eat a bee. 30 levels, Endless, a Daily Bog and Zen. Other iPhones: tap.
```
**163 / 170**, both locales. The Duo and the verb first (open, wait, close), then the bee, then what there is to play, then the non-Duo control, so nobody on a regular iPhone thinks the game isn't for them.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Daily Bog is open: the same bugs for everyone, one try that counts. Keep your streak going, and never eat a bee.` (120)
- After a press mention: a real quote from a real outlet only.

## 4. Description (limit 4,000)

**en-GB and en-US: counted by `build-metadata.js` (the run prints both; under 4,000).** Short paragraphs and capitalised section heads, so it scans on a phone: the first lines (all that shows before "more") are the plant on the Duo, open and close; the next paragraph is the skill; then the phone fallback and the promise (no ads, no data); then the modes in order of pull.

### en-GB (English U.K.)

```
Your iPhone Duo is a Venus flytrap.

Open your phone and the trap opens: the two halves are its lobes and the hinge is its midrib. Bugs fly in and land on the glistening nectar to sip. Close your phone and the trap closes with it: CHOMP. Every bug still inside is caught. But bees love nectar too, and you must never eat a bee.

The trick is choosing your moment, then meaning it. Wait for a crowd and close without dithering: the flies feel the lobes coming, and a slow, hesitant close lets them escape. A half close never bites, so it is all or nothing. While the phone is shut, the outer screen shows your catch. Open it again to keep feeding.

No Duo? Every other iPhone plays the whole game: tap to snap.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

30 LEVELS
Hand-made levels in three worlds: Morning Bog, Dusk and Night. The first five teach one idea each; then come ant marches, gnat clouds, moths, wasps, dragonflies and the bugs of the night. Every level has one clear goal and up to three stars, and stars open the next world. The Night is hard.

ENDLESS
The arcade run, from morning to night, until your snaps run out. The bugs change with the light: houseflies and gnats at breakfast, ladybirds and grasshoppers by noon, moths and dragonflies at dusk, fireflies and crickets in the dark, and now and then a rare Golden Scarab.
• Snaps are what you spend. A run starts with 12 (a few more in your first runs), you hold up to 14, and every bite costs one
• Catch 3 or more bugs in one bite for a Feast and win a snap back. Catch 5 or more in a clean bite for a FEAST: double score and two snaps back
• Score = the bugs' points × the number of bugs × your chain
• Every clean bite of 2 or more bugs grows the chain, all the way to ×5. An empty bite, a bug that gets away or a bee in the bite starts it again
• A bee in the bite is let go, unharmed and cross, and costs an extra snap. A wasp stings: two extra
• Keep a bug waiting too long and a snap wilts
• When the snaps run out, your trap is tired. One more go?

GOALS AND GROWTH
Three goals are always on the go, from a pool of 39: a 5-bug bite, spare 8 bees in one run, catch a firefly at night, and more. Each one you complete grows your plant through 12 ranks, from Sprout to Bog Monarch; all three in one run earns a bonus.

THE GARDEN
Grow 8 flytraps: Classic, Red Dragon, B52, Sawtooth, Shark Tooth, Fused Tooth, Cupped Trap and, for a Bog Monarch only, Golden Glow. Some grow as you rank up; others are won with a special goal. Pick one and it's your trap everywhere. Same bite, new look.

THE BUG BOOK
16 species, each with a drawing and a one-line joke. Catch a bug to add its page; bees and wasps go in when you spare them.

DAILY BOG
The same bugs for everyone, every day, and one try that counts. Play day after day to grow your streak, and share your score with friends. Then practise as much as you like.

ZEN BOG
No rush, no end. Snaps never run out, nothing wilts, and a bee costs you nothing but your chain. Catch at your own pace and stop whenever you like. No leaderboard.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, hold it any way you like, landscape or portrait, open wide or part way. Every round starts with the phone closed: open it and the bugs arrive. The bite lands as the halves meet, so a gentle close catches as much as a hard one. On any other iPhone, tap anywhere to snap.

SOUND AND FEEL
The CHOMP, every buzz and hum, the frogs by day and the crickets at night are all synthesised live in the app. You feel the bite in your hands the moment the halves meet. Sound, haptics, the silent switch and Reduce motion each have a setting.

GAME CENTER
Leaderboards for your Best Score and the Daily Bog, and 12 achievements. Optional: Snapjaw works fully without signing in.
```

### en-US (English U.S.)

Identical except two spellings: synthesised → synthesized, practise → practice. "Ladybirds" stays, because that's the bug's name in the game's Bug Book (US searchers are caught by the keyword `ladybug`, §5). Full text, ready to paste:

```
Your iPhone Duo is a Venus flytrap.

Open your phone and the trap opens: the two halves are its lobes and the hinge is its midrib. Bugs fly in and land on the glistening nectar to sip. Close your phone and the trap closes with it: CHOMP. Every bug still inside is caught. But bees love nectar too, and you must never eat a bee.

The trick is choosing your moment, then meaning it. Wait for a crowd and close without dithering: the flies feel the lobes coming, and a slow, hesitant close lets them escape. A half close never bites, so it is all or nothing. While the phone is shut, the outer screen shows your catch. Open it again to keep feeding.

No Duo? Every other iPhone plays the whole game: tap to snap.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

30 LEVELS
Hand-made levels in three worlds: Morning Bog, Dusk and Night. The first five teach one idea each; then come ant marches, gnat clouds, moths, wasps, dragonflies and the bugs of the night. Every level has one clear goal and up to three stars, and stars open the next world. The Night is hard.

ENDLESS
The arcade run, from morning to night, until your snaps run out. The bugs change with the light: houseflies and gnats at breakfast, ladybirds and grasshoppers by noon, moths and dragonflies at dusk, fireflies and crickets in the dark, and now and then a rare Golden Scarab.
• Snaps are what you spend. A run starts with 12 (a few more in your first runs), you hold up to 14, and every bite costs one
• Catch 3 or more bugs in one bite for a Feast and win a snap back. Catch 5 or more in a clean bite for a FEAST: double score and two snaps back
• Score = the bugs' points × the number of bugs × your chain
• Every clean bite of 2 or more bugs grows the chain, all the way to ×5. An empty bite, a bug that gets away or a bee in the bite starts it again
• A bee in the bite is let go, unharmed and cross, and costs an extra snap. A wasp stings: two extra
• Keep a bug waiting too long and a snap wilts
• When the snaps run out, your trap is tired. One more go?

GOALS AND GROWTH
Three goals are always on the go, from a pool of 39: a 5-bug bite, spare 8 bees in one run, catch a firefly at night, and more. Each one you complete grows your plant through 12 ranks, from Sprout to Bog Monarch; all three in one run earns a bonus.

THE GARDEN
Grow 8 flytraps: Classic, Red Dragon, B52, Sawtooth, Shark Tooth, Fused Tooth, Cupped Trap and, for a Bog Monarch only, Golden Glow. Some grow as you rank up; others are won with a special goal. Pick one and it's your trap everywhere. Same bite, new look.

THE BUG BOOK
16 species, each with a drawing and a one-line joke. Catch a bug to add its page; bees and wasps go in when you spare them.

DAILY BOG
The same bugs for everyone, every day, and one try that counts. Play day after day to grow your streak, and share your score with friends. Then practice as much as you like.

ZEN BOG
No rush, no end. Snaps never run out, nothing wilts, and a bee costs you nothing but your chain. Catch at your own pace and stop whenever you like. No leaderboard.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, hold it any way you like, landscape or portrait, open wide or part way. Every round starts with the phone closed: open it and the bugs arrive. The bite lands as the halves meet, so a gentle close catches as much as a hard one. On any other iPhone, tap anywhere to snap.

SOUND AND FEEL
The CHOMP, every buzz and hum, the frogs by day and the crickets at night are all synthesized live in the app. You feel the bite in your hands the moment the halves meet. Sound, haptics, the silent switch and Reduce motion each have a setting.

GAME CENTER
Leaderboards for your Best Score and the Daily Bog, and 12 achievements. Optional: Snapjaw works fully without signing in.
```

Copy rules this text keeps:
- **The phone is the trap, said plainly.** Open = open, close = bite. "A half close never bites" (R8: only the shut bites), so nobody expects a partial snap.
- **Speed is said from the bugs' side, never as an instruction.** "A slow, hesitant close lets them escape"; never "fast", "quick", "slam" or "as hard as you can". "A gentle close catches as much as a hard one" is true (the bite fires at the shut angle, ~18°, or the closed status; force is never measured) and is the 2.4.2 answer in one line.
- **No pose demands** (founder rule): "any way you like, landscape or portrait". Every round starts closed (`TrapSnapshot.waitingForClose`, "Close the phone to start").
- **Duo first, then "plays on other iPhone models too"** (not "every iPhone": the deployment target is iOS 18). The tap control is first-class and said in the first screen of text.
- **The bees are never hurt.** A bee in a bite is "let go, unharmed and cross"; a wasp "stings". Bugs are "caught", never killed.
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading.
- **Numbers are the code's, and only the code's** (§10). If Core moves one, this text moves with it.
- **Cosmetic means cosmetic.** The Garden is "same bite, new look"; Zen is sold as relaxing, never as "easy mode" (it has no leaderboard).

## 5. Keywords (limit 100 bytes, comma-separated, no spaces)

```
venus,plant,carnivorous,bug,insect,fly,catch,trap,zen,garden,bog,foldable,hinge,ladybug,dragonfly
```
**97 / 100 bytes**, both locales (unchanged in R9: every word is still a real feature or search).
- Nothing repeats the name or subtitle: snapjaw, feed, flytrap, spare and bees are already indexed from them (and Apple matches plurals, so "bee" is covered).
- "fly" + "trap" catch "fly trap"; "venus" + "flytrap" (subtitle) catch "venus flytrap"; "carnivorous" + "plant" the plant-lovers' search; "bug" / "insect" + "catch" "bug catching game".
- **No competitor names** and no "smash", "chomp" or "squish" ("chomp" is crowded with toys). No Apple marks ("iPhone", "Duo").
- "ladybug" is the US name of the game's ladybird; "dragonfly" the star catch; "foldable" + "hinge" the Duo owners' searches.

Alternate set to A/B after 4 weeks of Search data (check the bytes first): `venus,plant,carnivorous,bug,insect,fly,catch,trap,level,garden,bog,foldable,hinge,beetle,firefly` (96)

## 6. What's New

App Store Connect has no What's New field for an app's first version. Use the 1.0 line for TestFlight's "What to Test", press and social:
```
The phone is the trap. Open your Duo, wait for a crowd, then close it to bite. Never eat a bee. 30 levels in three worlds, Endless, the Daily Bog, the Zen Bog and a Garden of 8 flytraps.
```
Template for 1.0.1 (fill in only what actually shipped):
```
[one real change], and small fixes. Thanks for sparing all those bees.
```

## 7. Category

| Field | Choice | API value |
|---|---|---|
| Primary | **Games** | `GAMES` |
| Game subcategory 1 | **Casual** | `GAMES_CASUAL` |
| Game subcategory 2 | **Arcade** | `GAMES_ARCADE` |
| Secondary category | **Entertainment** | `ENTERTAINMENT` |

**Why:** Casual is where paid one-input games chart. Arcade is what Snapjaw is underneath (a score chase with a multiplier, a chain and short runs). Entertainment (optional) catches "look what my phone does" browsers, as with Brim and Swoop. **Apple dropped Arcade from its live list on 26 Oct 2026** (Brim run 40340641267; Swoop was filed as Casual + Action on 27 Oct), so the tool reads the live list and uses **Action** instead if Arcade is still missing (`fallbackSubcategories` in `asc-metadata.json`).

## 8. Age rating: 4+

The tool pushes these answers (`asc.yml` step `agerating`, `ageRating` in `asc-metadata.json`). If the API refuses a field, answer it by hand exactly like this (App Store Connect → the app → App Information → Age Rating → Edit):

| Section | Item | Answer |
|---|---|---|
| In-app controls | Parental Controls | **No** |
| | Age Assurance | **No** |
| Capabilities | Unrestricted Web Access | **No** |
| | User-Generated Content | **No** |
| | Messaging and Chat | **No** |
| | Advertising | **No** |
| Mature themes | Profanity or Crude Humor | **None** |
| | Horror/Fear Themes | **None** |
| | Alcohol, Tobacco, or Drug Use or References | **None** |
| | Mature or Suggestive Themes | **None** |
| Medical or wellness | Medical or Treatment Information | **None** |
| | Health or Wellness Topics | **No** |
| Sexuality or nudity | Sexual Content or Nudity | **None** |
| | Graphic Sexual Content and Nudity | **None** |
| Violence | Cartoon or Fantasy Violence | **None** |
| | Realistic Violence | **None** |
| | Prolonged Graphic or Sadistic Realistic Violence | **None** |
| | Guns or Other Weapons | **None** |
| Chance-based activities | Simulated Gambling | **None** |
| | Contests | **None** |
| | Gambling | **No** |
| | Loot Boxes | **No** |
| Kids | Made for Kids | **No** |

**Expected result: 4+.** If the form shows extra or renamed items, the honest answer to each is None or No.

Why each risky item is None:
- **Cartoon or Fantasy Violence: None.** A plant catching cartoon bugs is feeding, the way a frog catches flies: round, big-eyed bugs are gulped into the trap, nothing is shown hurt, and bees and wasps are always let go unharmed. R8 makes it gentler still on the Duo: with the hinge the lobes never draw shut on the inner screen (caught bugs are simply gone when it reopens, with a gold juice stain); the CHOMP card shows the closed trap from outside with a bump per bug. The juice is nectar gold, never red. If the final art ever reads as squashing a creature, the honest answer becomes **Infrequent/Mild** (9+): tell the founder.
- **Horror/Fear:** a sunlit bog with frogs and fireflies; the night is blue and soft. The end of a run is "Your trap is tired", not a death.
- **Profanity or Crude Humor:** the Bug Book jokes are gentle one-liners ("Has never once wiped its feet.").
- **Simulated gambling / loot boxes:** nothing to buy, no chance-based rewards. The Golden Scarab is a rare bug, not a prize draw.
- **Contests:** Game Center leaderboards are not prize contests.
- **Made for Kids: No.** Snapjaw is for everyone, not built for under-11s specifically.

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99**; Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland and Vietnam** (paid games there need a government game licence) |
| Pre-order | **No** |
| Release | **Automatically release this version after approval** (the founder's choice on 29 Oct, after submitting 1.0 with build 3; §12). It was manual for Tue 8 Dec 2026 |
| Family Sharing | **On** (permanent once on) |
| Small Business Program | Account-level; already enrolled for Squish (just confirm it shows Active) |
| Copyright | `© 2026 pravegm` |
| Support URL | `https://pravegm.github.io/snapjaw/support.html` |
| Marketing URL | `https://pravegm.github.io/snapjaw/` |
| Privacy Policy URL | `https://pravegm.github.io/snapjaw/privacy.html` |
| App Privacy | **Data Not Collected** (`privacy.md`) |
| Accessibility Nutrition Labels | **Differentiate Without Color Alone**, **Sufficient Contrast**, **Reduced Motion**, each only after its check passes (`accessibility.md`) |
| Content Rights | "Does your app contain, show, or access third-party content?" **No** (all art drawn in code, all sound synthesised, system fonts only) |
| Export compliance | Nothing to answer: `ITSAppUsesNonExemptEncryption: false` in `project.yml` (checked 28 Oct). The app makes no network requests of its own |
| Game Center | On; 2 leaderboards and 12 achievements, 575 points (`achievements.md`). The Zen Bog and Levels submit no scores |
| Sign-in required | No |
| Version | 1.0 (`MARKETING_VERSION` in `project.yml`); iPhone only (`TARGETED_DEVICE_FAMILY` 1), landscape and portrait |

**About the three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/snapjaw/` once Pages is on (runbook §0). The real pages are in `docs/site/`; `docs/index.html`, `docs/support.html` and `docs/privacy.html` forward to them. If a reviewer or tool ever objects to the forward, use the direct addresses: `https://pravegm.github.io/snapjaw/site/`, `…/site/support.html`, `…/site/privacy.html`. **R9:** the site's game copy (`docs/site/index.html`, `support.html`) still describes the R7 snap; it is not this file's owner's to edit, and `design/notes/store-R9.md` asks for it to be updated before submission (the privacy page is still true).

## 10. Claims, and the code that makes each one true

**R9 (Wed 28 Oct):** "Code" is ticked **[x] src** where the R8 source says exactly what the copy says (read on this host; no Swift compiler here, so not a build check). Before submission, tick **RC** on the release candidate (the founder's real-Duo TestFlight pass). If a line is false, change the copy here, in `review-notes.md`, the site and the press kit, never the build to match the words.

| Claim (where) | Source in the code | Code | RC |
|---|---|---|---|
| Open phone = open trap; the bite fires when the phone shuts (about 18°, or `.closed` with θ ≤ 25°); a partial close never bites; re-arm at 35° (description, promo, review notes) | `Tuning.armAngle` 35, `shutAngle` 18, `statusShutAngle` 25; `SnapDetector` (`design/notes/core-R8.md`) | [x] src | [ ] |
| "Flies feel the lobes coming, and a slow, hesitant close lets them escape" | bug fear from continuous closure: nerve / reaction per species (`BugCatalog.all`, e.g. housefly 0.50 s / 12°), `TrapSession` `bugSpooked` | [x] src | [ ] |
| "A gentle close catches as much as a hard one": force is never read, only the angle and the close's duration | `SnapDetector` (angle + time only), `HingeReader` (angle + status) | [x] src | [ ] |
| Every round starts closed ("Close the phone to start"); no pose demand; portrait and landscape both play | `TrapSnapshot.waitingForClose`, `HingeTrapSource.startRound`, `LevelViews.CloseToStartCard`; `AppRules.pose` never returns a pose card (`design/notes/portrait-R8.md`) | [x] src | [ ] |
| While shut, the outer screen shows the catch (CHOMP card); reopen to keep feeding | `GameController.coverChomp`, `UI/ChompCard.swift` ("Open to keep feeding") | [x] src | [ ] |
| Other iPhones: tap anywhere to snap; the trap reopens by itself | `TouchTrapSource` (instant bite, `Tuning.touchSnapTime` 0.12, `touchRearmDelay` 0.45) | [x] src | [ ] |
| **30 levels, 3 worlds** (Morning Bog 1–10, Dusk 11–20, Night 21–30), one goal each, up to 3 stars; the first five teach; stars open the next world (20 for Dusk, 40 for the Night); species named (ants L6, gnat cloud L7, moth L11, wasps L13, dragonfly L14, scarab L19, fireflies L21, crickets L22) | `Snap/Core/LevelData.swift` (30 `LevelSpec`), `LevelBook.worldUnlockStars` 20, `worldUnlocked`; the R8 level map (`artifacts/r8` 04, 60) | [x] src | [ ] |
| **12 snaps to start ("a few more in your first runs": 14, 13, 12), hold at most 14**, every bite costs 1; Feast at ≥ 3 (+1), ≥ 5 (+2); bee +1 extra, wasp +2 extra | `Tuning.startSnaps` 12, `maxSnaps` 14, `firstRunSnaps` 14, `sproutRun2Snaps` 13, `sproutRun3Snaps` 12, `feastRefund` 1 / `bigFeastRefund` 2, `beeCost` 1 / `waspCost` 2 | [x] src | [ ] |
| **FEAST: a clean bite of 5+ scores double** | `Tuning.bigFeastCount` 5, `feastMultiplier` 2.0 (never with a stinger) | [x] src | [ ] |
| Score = bugs' points × number of bugs × chain; chain to ×5, grown only by clean bites of 2+; an empty bite, an escape or a stinger breaks it | `Tuning.chainStep` 0.5, `chainMaxMultiplier` 5, `chainMinBite` 2, `missBreaksChain` true | [x] src | [ ] |
| "Keep a bug waiting too long and a snap wilts" | `Tuning.wiltMorning` 18 / `wiltNoon` 14 / `wiltDusk` 12 / `wiltNight` 12 | [x] src | [ ] |
| A bee in the bite is let go unharmed; "Your trap is tired" at 0 snaps | `BugActivity.released`, `RunPhase.tired` | [x] src | [ ] |
| Morning → noon → dusk → night with the named bugs; Golden Scarab rare | `Tuning.noonWave` 7, `duskWave` 15, `nightWave` 23; `BugCatalog.all` `firstPhase` | [x] src | [ ] |
| Goals: three at a time from a pool of 39; examples are real pool titles ("A 5-bug bite", `spare8`, `fireflyNight`) | `Tuning.goalsActive` 3, `GoalBook.pool` (39, counted 28 Oct) | [x] src | [ ] |
| 12 plant ranks, Sprout to Bog Monarch | `PlantRanks` | [x] src | [ ] |
| The Garden: 8 flytraps as named; cosmetic only | `TrapVariety` (8), `Varieties.all` | [x] src | [ ] |
| Bug Book: 16 species with a joke each | `BugSpecies` (16), `BugCatalog.all` | [x] src | [ ] |
| Daily Bog: same bugs for everyone, one scored try a day, then practice; streak; Share (iOS share sheet, only when tapped) | `RunMode.daily(day:scored:)`, `ResultsView` `ShareLink` (the only share code in `Snap/`) | [x] src | [ ] |
| Zen Bog: snaps never run out, nothing wilts, a bee costs only the chain, no leaderboard | `SessionOptions.for(.zen)`, `GameCenterManager.report` | [x] src | [ ] |
| Haptic and CHOMP at the moment the halves meet | `.snapped` fires at the shut (`design/notes/app-R8.md` Feel) | [x] src | [ ] on a real Duo |
| All sound synthesised live; settings Sound, Haptics, Respect silent switch, Reduce motion, Score on the left | `Feedback/` (no audio files), `UI/SettingsView.swift` labels | [x] src | [ ] |
| 2 leaderboards + 12 achievements | `GameCenterManager.Leaderboard` (`snap.best`, `snap.daily`), `Achievements.all` = `achievements.md` | [x] src | [ ] |
| No network code, no SDKs, no tracking | `privacy.md` §3 grep (28 Oct: no `URLSession`/`URLRequest`/`Network`/analytics in `Snap/`) | [x] src | [ ] |

## 11. Asks to the build team (so the store copy stays true)

| # | Owner | Ask | Why |
|---|---|---|---|
| 1 | Scene | The juice stays nectar gold, never red; caught bugs are never shown flattened | Keeps the honest 4+ (§8) |
| 2 | Core + App | Keep these exact ids: leaderboards `snap.best`, `snap.daily`; achievements exactly as `achievements.md` | Game Center ids are permanent once created |
| 3 | App | Exact labels the copy quotes: "Endless", "Daily", "Daily Bog", "Zen", "Zen Bog", "Levels", "Garden", "Bug Book", "Share", "Score on the left", "Respect silent switch", "Reduce motion", "Your trap is tired", "Close the phone to start", "Tap to snap", "Open to keep feeding", "CHOMP!". If a label changes, tell the launch lead | The review notes and the support page quote them |
| 4 | App / Core | The R8 CI run's `screen=levelResults;level=1;pilot=perfect` ended `stars=0 passed=0` (and level 4 too); app-R9 says the demo pilot was at fault and is fixed: confirm on the next CI run. Not a store frame tonight, but App Review will play Level 1 first (`design/notes/store-R9.md`) | Level 1 must be passable on a phone by a tap |

## 12. Launch date

**29 Oct update: on approval.** 1.0 (build 3) was submitted on 29 Oct with release on approval, by the founder's choice, so Snapjaw goes live when App Review approves it (expected about 30 Oct – 1 Nov, clear of Brim's and Hush's weeks). If a rejection pushes a re-submit's approval into 17–23 Nov or 1–7 Dec, set Version Release to manual before re-submitting. The featuring nomination still says Tue 8 Dec: update its date in App Store Connect once the real launch day is known. The original plan follows.

**Tue 8 Dec 2026, about 08:00 UK, released by the founder (manual release).** Swoop is live, Brim launches Tue 17 Nov and Hush Tue 1 Dec, so Snapjaw takes the next free week. Submitting now (late Oct) leaves time for review and a re-submit before 8 Dec; with manual release, an approved 1.0 simply waits. **Fallback: Tue 12 Jan 2027.** If the founder would rather release on approval, the only rule is that it must not go live in Brim's (17–23 Nov) or Hush's (1–7 Dec) week.

## Sources
- Apple, *Screenshot specifications* (read 28 Oct 2026: iPhone Duo inner 2853 × 2007 and outer 2034 × 1398; "Dynamic Island (medium)" required): https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Apple, *Creative assets specifications* (product page header 3840 × 1646, search results 3:2 up to 3840 × 2560): https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
- Apple, *Age ratings values and definitions*: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App Review Guidelines 2.3.7 (metadata), 2.4.2, 1.4.5: https://developer.apple.com/app-store/review/guidelines/
- Swoop's and Hush's metadata (structure, category fallback): `C:\Users\59527\Wing\docs\appstore\metadata.md`, `C:\Users\59527\Lid\docs\appstore\metadata.md`
