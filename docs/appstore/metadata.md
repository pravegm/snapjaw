# Snapjaw: App Store metadata (v1.0)

*Written Tue 27 Oct 2026 by the launch lead, from `design/GAME-DESIGN.md` v1, `design/ARCHITECTURE.md`, `design/ROUND-1.md`, `Snap/Shared/Contracts.swift` and `research/01-market.md`, mirroring Swoop's submitted kit (`C:\Users\59527\Wing\docs\appstore\`) and Hush's (`C:\Users\59527\Lid\docs\appstore\`). **The build doesn't exist yet** (Round 1 is being written), so every feature claim below is from the design and is listed in §10 with an empty "Code" box: tick each one against the code once it compiles, and again on the release candidate ("RC"). If a line is false, change the copy here, never the build to match the words. Nobody pastes these: once the App Store Connect tool is ported from Swoop (`tools/appstore/`, `asc.yml`), `node tools/appstore/build-metadata.js` turns the code blocks into `docs/appstore/asc-metadata.json`. Change the text here, then regenerate. Counts are Unicode characters (counted with Node), except keywords, which Apple counts in bytes (all ASCII here, so the same).*

**Words the copy uses** (the game's own words, GAME-DESIGN §1–§8): *snap* (always "a little shut", "half shut" or "about 22°", never just "shut"), *open it again*, *bite*, *catch*, *crowd*, *sip / nectar*, *Feast*, *chain*, *never eat a bee*, *let go* (a bee in a bite), *spare*, *snaps* (the resource), *the trap is tired*, *score* (the word is "score", never "protein", since R5), *Bug Book*, *plant rank*, *Feed*, *Daily Bog*, *First Bite*. **Never:** "smash", "squash", "squish" (Fold Smasher's and Squish's crush fantasy), "kill", "die", "splat", "slam", "clap", "close it fast", "flat", "Fold to …" (Fold Smasher's "Fold Your Phone to Smash!" and Valley Run's "Fold to Fly"), and no competitor names anywhere.

**The pitch order** (`research/01-market.md`, "Implications"): lead with **the plant**, then **the bees**, then **choosing** (wait for a crowd). The snap is the gesture, not the selling point: Fold Smasher already owns "snap the phone shut on bugs".

Localisations: **English (U.K.)** is the primary language, plus **English (U.S.)**. Every other storefront shows en-GB. Only the description differs between the two (§4); everything else is identical.

---

## 1. App name (limit 30)

```
Snapjaw
```
**7 / 30.** The name check (`research/01-market.md`, "Name check") found **no game called Snapjaw**, so the bare name works and reads cleanly in search next to the subtitle, without repeating "flytrap" (the subtitle already indexes it, and Apple combines words across fields). It reads as both "snap shut" and "jaws", and fits the studio's one-word names (Squish, Brim, Swoop, Hush).

If App Store Connect says the name is taken when you create the record (a non-game app may hold it), use the first that works, and tell Claude:

| Order | Fallback | Count |
|---|---|---|
| 1 | `Snapjaw: Venus Flytrap` | 22 |
| 2 | `Snapjaw: Flytrap` | 16 |
| 3 | `Snaptrap: Feed the Flytrap` | 26 |

The home-screen name under the icon is **Snapjaw** (`CFBundleDisplayName`), whichever store name is used (fallback 3 would also change the home-screen name and `AppBrand.name` follows it).

## 2. Subtitle (limit 30)

```
Feed the flytrap. Spare bees.
```
**29 / 30**, the same in en-GB and en-US. The research's pick: it front-loads the plant and the bee rule, the two things Fold Smasher doesn't have, and indexes "feed", "flytrap", "spare" and "bees" without spending keyword bytes. No "smash", no "Fold to …", no price, superlative or Apple mark (Guideline 2.3.7).

Alternative for a later version (Product Page Optimization can't test the subtitle): `Snap shut. Spare the bees.` (26), the store line in GAME-DESIGN §1. Not for 1.0: "snap shut" on its own invites the full-close reading we avoid everywhere else.

## 3. Promotional text (limit 170; can change any time without a new version)

```
On iPhone Duo, hold it like a book and snap it a little shut to catch the bugs sipping inside. Wait for a crowd. Never eat a bee. Other iPhones: tap to snap. No ads.
```
**165 / 170**, both locales. It leads with the Duo and the pose, says "a little" before anyone can read "shut" as "closed", and says straight away that other iPhones can play.

Rotation ideas for later (count before pasting):
- After launch week: `Today's Daily Bog is open: the same bugs for everyone, one try that counts. Can you catch a crowd without biting a bee?` (115)
- After a press mention: `"real quote" (outlet). ...` (only with a real quote).

## 4. Description (limit 4,000)

**en-GB 3,292 / 4,000; en-US 3,292 / 4,000.** Short paragraphs and capitalised section heads, so it scans on a phone: the first three lines (all that shows before "more") are the plant, the move and the bees.

### en-GB (English U.K.)

```
Your iPhone Duo is a Venus flytrap.

Hold your Duo open like a book. The two halves are the trap's two lobes and the hinge is its midrib. Bugs fly in and land on the glistening nectar to sip. Snap the phone a little shut and the trap bites with you, teeth clacking together: CHOMP. Then open it again and wait for the next ones.

The trick is choosing when. Wait for a crowd and catch them all in one bite, because your score is multiplied by the number of bugs in it. But bees love nectar too, and you must never eat a bee.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

PATIENCE, GREED AND BEES
• Snaps are what you spend. A run starts with 10, and every snap costs one
• Catch 3 or more bugs in one bite for a Feast, and win snaps back
• Your score is the bugs' points, times the number of bugs, times your chain
• Bite after bite with no bee in it, and the chain climbs all the way to ×4
• A bee in the bite is let go, unharmed and cross, and costs an extra snap. A wasp stings: two extra
• Sipping bugs are distracted. Flying ones are quick. Close too slowly and the twitchy ones leave
• When the snaps run out, your trap is tired. One more go?

A DAY IN THE BOG
Every run moves from morning to night, and the bugs change with the light. Houseflies, gnats and fruit flies at breakfast; bluebottles, lines of ants, ladybirds and grasshoppers by noon; moths, mosquitoes, dragonflies and wasps at dusk; fireflies and crickets in the dark. Keep an eye out for the rare Golden Scarab.

THE BUG BOOK
16 species, each with its own drawing and a one-line joke, from the humble housefly to the bumblebee. Catch a bug to add its page; bees and wasps go in when you spare them. As your lifetime catch grows, your plant climbs 12 ranks, from Sprout to Bog Monarch.

FIRST BITE
Your first go starts with a short lesson that teaches by doing: one fat fly, your first snap, a bee to wait out and your first triple. Replay it from Settings any time.

DAILY BOG
The same bugs for everyone, every day, and one try that counts. Then practise as much as you like.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, the hinge is the trap: a short snap of about 22° from however you like to hold it, then open again. You never close the phone or lay it flat. The bite happens at 22°, so there is nothing to gain by going further. iPhone Duo softens one half of the screen for a moment when a fold starts from flat, so your score and snaps sit on the half that stays sharp, and Settings can move them. On any other iPhone, tap anywhere to snap. Same bog, same scores, but the fold is the best way to play.

SOUND AND FEEL
The CHOMP, the teeth clacking shut, every buzz and hum, the frogs by day and the crickets at night are all synthesised live in the app. Each bug's buzz comes from where it is, and you feel a soft tick in your hands when one lands. Sound plays with the silent switch on; a setting makes Snapjaw respect it instead. Sound and haptics each have a switch, and there's a Reduce motion setting.

GAME CENTER
Leaderboards for your Best Feast and the Daily Bog, and 12 achievements. It's optional: Snapjaw works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

### en-US (English U.S.)

Identical except two spellings: synthesised → synthesized, practise → practice. "Ladybirds" stays, because that's the bug's name in the game's Bug Book (US searchers are caught by the keyword `ladybug`, §5). Full text, ready to paste:

```
Your iPhone Duo is a Venus flytrap.

Hold your Duo open like a book. The two halves are the trap's two lobes and the hinge is its midrib. Bugs fly in and land on the glistening nectar to sip. Snap the phone a little shut and the trap bites with you, teeth clacking together: CHOMP. Then open it again and wait for the next ones.

The trick is choosing when. Wait for a crowd and catch them all in one bite, because your score is multiplied by the number of bugs in it. But bees love nectar too, and you must never eat a bee.

No ads. No in-app purchases. No accounts. No data collected. Pay once and it's yours.

PATIENCE, GREED AND BEES
• Snaps are what you spend. A run starts with 10, and every snap costs one
• Catch 3 or more bugs in one bite for a Feast, and win snaps back
• Your score is the bugs' points, times the number of bugs, times your chain
• Bite after bite with no bee in it, and the chain climbs all the way to ×4
• A bee in the bite is let go, unharmed and cross, and costs an extra snap. A wasp stings: two extra
• Sipping bugs are distracted. Flying ones are quick. Close too slowly and the twitchy ones leave
• When the snaps run out, your trap is tired. One more go?

A DAY IN THE BOG
Every run moves from morning to night, and the bugs change with the light. Houseflies, gnats and fruit flies at breakfast; bluebottles, lines of ants, ladybirds and grasshoppers by noon; moths, mosquitoes, dragonflies and wasps at dusk; fireflies and crickets in the dark. Keep an eye out for the rare Golden Scarab.

THE BUG BOOK
16 species, each with its own drawing and a one-line joke, from the humble housefly to the bumblebee. Catch a bug to add its page; bees and wasps go in when you spare them. As your lifetime catch grows, your plant climbs 12 ranks, from Sprout to Bog Monarch.

FIRST BITE
Your first go starts with a short lesson that teaches by doing: one fat fly, your first snap, a bee to wait out and your first triple. Replay it from Settings any time.

DAILY BOG
The same bugs for everyone, every day, and one try that counts. Then practice as much as you like.

MADE FOR THE FOLD. PLAYS ON OTHER iPhone MODELS TOO.
On iPhone Duo, the hinge is the trap: a short snap of about 22° from however you like to hold it, then open again. You never close the phone or lay it flat. The bite happens at 22°, so there is nothing to gain by going further. iPhone Duo softens one half of the screen for a moment when a fold starts from flat, so your score and snaps sit on the half that stays sharp, and Settings can move them. On any other iPhone, tap anywhere to snap. Same bog, same scores, but the fold is the best way to play.

SOUND AND FEEL
The CHOMP, the teeth clacking shut, every buzz and hum, the frogs by day and the crickets at night are all synthesized live in the app. Each bug's buzz comes from where it is, and you feel a soft tick in your hands when one lands. Sound plays with the silent switch on; a setting makes Snapjaw respect it instead. Sound and haptics each have a switch, and there's a Reduce motion setting.

GAME CENTER
Leaderboards for your Best Feast and the Daily Bog, and 12 achievements. It's optional: Snapjaw works fully without signing in.

PRIVATE BY DESIGN
No accounts, no tracking, no data collected. Your progress stays on your iPhone.
```

Copy rules this text keeps:
- **Plant first, bees second, choosing third.** The verb "smash" never appears, and "snap" is always qualified ("a little shut", "about 22°") so nobody reads it as "close the phone".
- **Duo first, then "plays on other iPhone models too"** (not "every iPhone": the deployment target is iOS 18). The tap control is described plainly and not oversold ("the fold is the best way to play"). The store page may talk about the Duo; the *app* never shows a Duo line on a non-Duo iPhone.
- **The blur is explained once, plainly**, as an iOS behaviour Snapjaw works around, never as a Snapjaw fault.
- **The bees are never hurt.** A bee in a bite is "let go, unharmed and cross" (GAME-DESIGN §5); a wasp "stings". Bugs are "caught", never killed.
- **"iPhone Duo" is used only referentially**, never in the name, subtitle or keywords, and "iPhone" keeps its exact form even in a capitalised heading (Apple trademark guidelines).
- **No hinge-wear bait.** Never "slam", "clap", "close it fast" or "as fast as you can". "Quick" appears once, about the bugs ("Flying ones are quick"); the slow-close rule is said from the bugs' side ("close too slowly and the twitchy ones leave").

## 5. Keywords (limit 100 bytes, comma-separated, no spaces)

```
venus,plant,carnivorous,bug,insect,fly,catch,trap,bite,swamp,bog,foldable,hinge,ladybug,dragonfly
```
**97 / 100 bytes**, both locales.
- Nothing repeats the name or subtitle: snapjaw, feed, flytrap, spare and bees are already indexed from them (and Apple matches plurals, so "bee" is covered).
- "fly" + "trap" catch the two-word "fly trap" search; "venus" + "flytrap" (subtitle) catch "venus flytrap"; "carnivorous" + "plant" catch the plant-lovers' search; "bug" / "insect" + "catch" catch "bug catching game".
- Singular forms only ("bug", not "bugs").
- **No competitor names** (Fold Smasher, ChompDuo, Foldfish, Squish-likes) and no "smash", "chomp" or "squish": "chomp" is crowded (ChompDuo, CHOMP!!!, Chomp Catch: `research/01-market.md`) and would put us next to the toys we are not. No Apple marks ("iPhone", "Duo").
- "ladybug" is the US name of the game's ladybird (a real bug in the Bug Book), "dragonfly" is the star catch; "foldable" + "hinge" are the Duo-owners' searches, used by every sister game.

Alternate set to A/B after 4 weeks of Search data (check the bytes first): `venus,plant,carnivorous,bug,insect,fly,catch,trap,bite,swamp,garden,foldable,hinge,beetle,firefly` (94)

## 6. What's New

App Store Connect has no What's New field for an app's first version. Use the 1.0 line for TestFlight's "What to Test", press and social:
```
First bite. Hold your Duo like a book, snap it a little shut on the bugs sipping inside, and open it again. Wait for a crowd, never eat a bee. On other iPhones, tap to snap.
```
(173 characters; TestFlight's field has no 170 limit.) Template for 1.0.1 (fill in only what actually shipped):
```
Crisper snaps on iPhone Duo, [one real change], and small fixes. Thanks for sparing all those bees.
```

## 7. Category

| Field | Choice | API value |
|---|---|---|
| Primary | **Games** | `GAMES` |
| Game subcategory 1 | **Casual** | `GAMES_CASUAL` |
| Game subcategory 2 | **Arcade** | `GAMES_ARCADE` |
| Secondary category | **Entertainment** | `ENTERTAINMENT` |

**Why:** Casual is where paid one-input games chart, and its paid chart is shallow enough for a launch spike to show. Arcade is what Snapjaw is underneath (a score chase with a multiplier, a chain and runs of 2–3 minutes). Entertainment (optional) catches people browsing for "look what my phone does" apps, the same choice as Brim and Swoop. **Apple dropped Arcade from its live list on 26 Oct 2026** (Brim run 40340641267; Swoop was filed as Casual + Action on 27 Oct), so the tool reads the live list and uses **Action** instead if Arcade is still missing (`fallbackSubcategories` in `asc-metadata.json`).

## 8. Age rating: 4+

Answer the questionnaire exactly like this (App Store Connect → the app → App Information → Age Rating → Edit):

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

**Expected result: 4+.** If the form you see has extra or renamed items, the honest answer to each is None or No.

Why each risky item is None:
- **Cartoon or Fantasy Violence: None, on one condition.** A plant catching cartoon bugs is feeding, the way a frog catches flies: round, big-eyed bugs are gulped into the trap, nothing is shown hurt, and bees and wasps are always let go unharmed. **The condition (Scene engineer, §11 ask 1):** the bite's "juice" is a cartoon sparkle in nectar gold and leaf green, never red, never bug parts, and caught bugs vanish into the midrib rather than being shown flattened. If the final art reads as squashing a creature, the honest answer becomes **Infrequent/Mild**, which makes the rating **9+** (Hush answered that way for its mimic's comic bite). Claude re-checks this on the release-candidate frames before the questionnaire is pushed, and tells the founder if it changes.
- **Horror/Fear:** a sunlit bog with frogs and fireflies. The night is blue and soft; nothing jumps out. The end of a run is "Your trap is tired", not a death.
- **Profanity or Crude Humor:** the Bug Book jokes are gentle one-liners ("has never once wiped its feet"). Claude reads all 16 against the build.
- **Simulated gambling / loot boxes:** no chance-based rewards and nothing to buy. The Golden Scarab is a rare bug in the wave table, not a prize draw; the Daily Bog is the same fixed bugs for everyone.
- **Contests:** Game Center leaderboards are not prize contests.
- **Made for Kids: No.** The Kids category adds parental-gate rules and moves the app out of Games; Snapjaw is for everyone, not built for under-11s specifically.

## 9. Other App Store Connect fields

| Field | Value |
|---|---|
| Price | Base country **United Kingdom, £1.99**; Apple equalises every other storefront (check the US shows **$1.99**). No launch discount |
| Availability | Every country or region **except China mainland and Vietnam** (paid games there need a government game licence) |
| Pre-order | **No** |
| Release | **Manually release this version**, pressed by the founder on **Tue 8 Dec 2026 at about 08:00 UK** (§12) |
| Family Sharing | **On** (permanent once on) |
| Small Business Program | Account-level; already enrolled for Squish (just confirm it shows Active) |
| Copyright | `© 2026 pravegm` |
| Support URL | `https://pravegm.github.io/snapjaw/support.html` |
| Marketing URL | `https://pravegm.github.io/snapjaw/` |
| Privacy Policy URL | `https://pravegm.github.io/snapjaw/privacy.html` |
| App Privacy | **Data Not Collected** (`privacy.md`) |
| Accessibility Nutrition Labels | **Differentiate Without Color Alone**, **Sufficient Contrast**, **Reduced Motion**, each only after its check passes, published on launch day (`accessibility.md`) |
| Content Rights | "Does your app contain, show, or access third-party content?" **No** (all art drawn in code, all sound synthesised, system fonts only) |
| Export compliance | Nothing to answer: `ITSAppUsesNonExemptEncryption` is `false` in `project.yml` (CI engineer: copy Swoop's line) |
| Game Center | On; 2 leaderboards and 12 achievements, 575 points (`achievements.md`) |
| Sign-in required | No |
| Version | 1.0 (`MARKETING_VERSION` in `project.yml`) |

**About the three web addresses.** GitHub Pages serves the repo's `docs/` folder at `https://pravegm.github.io/snapjaw/` once Pages is on (runbook §0). The real pages are in `docs/site/`. `docs/index.html`, `docs/support.html` and `docs/privacy.html` are tiny forwarding pages, so the short addresses above work. If a reviewer or tool ever objects to the forward, use the direct addresses: `https://pravegm.github.io/snapjaw/site/`, `…/site/support.html`, `…/site/privacy.html`.

## 10. Claims, and the code that makes each one true

**Code: not written yet** (27 Oct). When Round 1 compiles, Claude ticks "Code" against the files named (or changes the copy here, in `review-notes.md`, the site and the press kit); before submission, every line is ticked again on the release candidate ("RC").

| Claim (where) | Source in the design → where it will live | Code | RC |
|---|---|---|---|
| Book pose; the halves are the lobes, the hinge the midrib; snap about 22° from the player's own rest angle, then open again (description, promo, review notes) | GAME-DESIGN §3; `Tuning.snapDepth` 22, `SnapDetector` (rest reference, re-arm 16° / 150°) | [ ] | [ ] |
| "The bite happens at 22°, so there is nothing to gain by going further"; nothing to hold | GAME-DESIGN §3 (the bite is decided at `tc`) | [ ] | [ ] |
| Never close or lay flat; too flat only shows "Bend it a little, like a book"; deep close pauses; shut shows the cover card | GAME-DESIGN §3; `TrapHint.bendALittle`, `Tuning.closingAngle` 50 / `closingDwell` 0.6, `UI` pose cards | [ ] | [ ] |
| Score = bugs' points × number of bugs × chain; chain +0.5 per clean productive bite up to ×4; dry snap or stinger resets it | GAME-DESIGN §5; `TrapSession` | [ ] | [ ] |
| 10 snaps to start (max 12); every snap costs 1; Feast at ≥ 3 caught (+1), ≥ 5 (+2); bee +1 extra, wasp +2 extra | GAME-DESIGN §5; `Tuning.startSnaps` 10, `maxSnaps` 12 | [ ] | [ ] |
| Sipping bugs react slower, flying ones faster; a slow close (creep) makes twitchy bugs leave and never bites (review notes, support page) | GAME-DESIGN §3 creep (`creepRef`, 3 s) and §4 reaction formula | [ ] | [ ] |
| A bee in the bite is let go unharmed; "Your trap is tired" at 0 snaps | GAME-DESIGN §5; `RunPhase.tired`, `BugActivity.released` | [ ] | [ ] |
| Morning → noon → dusk → night with the named bugs per phase; Golden Scarab rare | GAME-DESIGN §6 table; `WaveFactory`, `BugCatalog` | [ ] | [ ] |
| Bug Book: 16 species, drawing + one-line joke + count; bees and wasps unlock when spared | GAME-DESIGN §7; `BugCatalog.all`, `UI` Bug Book | [ ] | [ ] |
| 12 plant ranks, Sprout to Bog Monarch, by lifetime bugs caught | `PlantRanks` (contract), GAME-DESIGN §7 | [ ] | [ ] |
| First Bite on the first go: fly, first snap, the bee, the triple; replay from Settings ("Replay First Bite") | GAME-DESIGN §8; ROUND-1 App engineer (skip after step 2) | [ ] | [ ] |
| Daily Bog: same bugs for everyone, one scored try a day, then practice; a new one at 00:00 UTC (support page) | `DailySeed` with a UTC calendar (§11 ask 3), `RunMode.daily(day:scored:)` | [ ] | [ ] |
| Other iPhones: tap anywhere to snap; the trap reopens by itself | GAME-DESIGN §9; `TouchTrapSource` | [ ] | [ ] |
| Score and snaps on the sharp (right) half; Settings "HUD on the left" | GAME-DESIGN §3; `ScreenLayout.hudOnLeft` | [ ] | [ ] |
| All sound synthesised live; panned buzz per bug; landing tick haptic; frogs by day, crickets at night | GAME-DESIGN §10; `Feedback/` (no audio files in the bundle) | [ ] | [ ] |
| Sound on silent by default; "Respect silent switch"; Sound and Haptics switches; "Reduce motion" | ROUND-1 Settings list; `FeedbackDirector.respectSilentSwitch` | [ ] exact labels | [ ] |
| 2 leaderboards (Best Feast, Daily Bog) + 12 achievements report from the build | `App/GameCenterManager.swift`; `achievements.md` | [ ] | [ ] |
| No network code, no SDKs, no tracking (privacy) | `privacy.md` §3 grep | [ ] | [ ] |

## 11. Asks to the build team (so the store copy stays true)

| # | Owner | Ask | Why |
|---|---|---|---|
| 1 | Scene | The bite's "juice splat" is a cartoon sparkle in nectar gold / leaf green, never red; caught bugs disappear into the midrib (a gulp), never shown flattened | Keeps the honest age rating at 4+ (§8) and keeps us clear of the "smash" fantasy |
| 2 | Core + App | Keep these exact ids: leaderboards `snap.best`, `snap.daily`; achievements exactly as `achievements.md` (`Achievements.all`). Any change to a key, title, detail or rule: tell the launch lead before the tool creates them | Game Center ids are permanent once created |
| 3 | Core | **Daily Bog runs on the UTC date** (`DailySeed.dayNumber(for:calendar:)` called with a UTC calendar), like Brim and Swoop | Game Center's recurring board resets at one UTC moment for everyone (`achievements.md`) |
| 4 | App | Exact labels the copy quotes: "Feed", "Daily Bog", "Bug Book", "Replay First Bite", "HUD on the left", "Respect silent switch", "Reduce motion", "Your trap is tired", "Bend it a little, like a book", "Never eat a bee". If a label changes, tell the launch lead | The review notes and support page quote them |
| 5 | App | Game Center banners queue until the Results card, never mid-run | A banner over the HUD half hides the snaps count |
| 6 | Design (founder) | Consider Settings → "Play with touch" on a Duo (tap to snap with the hinge ignored). **Not in 1.0 unless built**; no copy claims it | It would answer "what if I'd rather not fold?" and helps motor access; Swoop has one |
| 7 | App | A Daily **Share** button is not in the design. If one is added: a "Sharing" paragraph in the privacy policy and the support page | Keeps the privacy policy exact |

## 12. Launch date

**Tue 8 Dec 2026, about 08:00 UK, released by the founder (manual release).** Swoop goes live on approval (about 29–30 Oct), Brim launches Tue 17 Nov and Hush Tue 1 Dec, and Hush's kit gives Hush the week 1–7 Dec, so Snapjaw takes the next free week and every game keeps its own week of news and its own featuring slot. Six weeks out leaves room for two or three real-Duo tuning rounds (the snap threshold, the filter lag and the creep feel can only be judged on the Duo) and Apple's preferred 3 weeks' featuring notice (nomination by Mon 16 Nov). **Submit Wed 2 Dec** (last safe day Fri 4 Dec). **Fallback: Tue 12 Jan 2027** if 1.0 isn't submitted by Fri 4 Dec: never Tue 15 Dec (Hush's fallback) and not the App Store's Christmas weeks. If the founder would rather release on approval, as with Swoop, the only rule is that it must not go live in Brim's (17–23 Nov) or Hush's (1–7 Dec) week.

## Sources
- Swoop's metadata (structure, copy rules, category fallback): `C:\Users\59527\Wing\docs\appstore\metadata.md`
- Hush's metadata (claims table, the cartoon-violence answer, launch calendar): `C:\Users\59527\Lid\docs\appstore\metadata.md`, `DECISIONS.md` #13–#15
- `research/01-market.md` (Fold Smasher, ChompDuo, the name check, the subtitle)
- Apple, *Age ratings values and definitions*: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- App Review Guidelines 2.3.7 (metadata): https://developer.apple.com/app-store/review/guidelines/
