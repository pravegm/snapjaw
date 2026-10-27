# Snapjaw: Game Center leaderboards and achievements (v1.0)

*Written Tue 27 Oct 2026 by the launch lead from `design/GAME-DESIGN.md` §5–§7, the `RunResult` fields in `Snap/Shared/Contracts.swift` and the `Achievements.earned(after:lifetimeBugs:lifetimeSpared:speciesFound:alreadyEarned:)` signature in `design/ARCHITECTURE.md`. **IDs are permanent once created in App Store Connect**, so Core and the App engineer must use exactly these strings. **Every trigger below is computable from that signature's inputs alone** (the run's `RunResult` plus the three lifetime totals), so Core can implement `Achievements.all` and `earned(...)` exactly as written, with no new inputs. Every one works the same with the hinge (Duo) and with tap-to-snap (other iPhones). Nothing rewards snap speed, snap count or the fastest snap (App Review 2.4.2); `RunResult.fastestSnap` stays an internal stat.*

## Apple's limits (from Brim's, Swoop's and Squish's sourced notes)
- ≤ 100 points per achievement, ≤ 1,000 points per app, ≤ 100 achievements.
- IDs ≤ 100 characters: letters, digits, `.` and `_`. Permanent.
- Each achievement needs a **1024 × 1024** image (PNG or JPEG, RGB, no transparency, ≥ 72 dpi). Leaderboard images are optional.
- Achievements and leaderboards only go live attached to a version that includes them. The App Store Connect tool (ported from Swoop) creates all of them and attaches them to the 1.0 review submission (`asc.yml` steps `gamecenter` and `attach`); nobody types them in.

## Leaderboards (2)

| | `snap.best` | `snap.daily` |
|---|---|---|
| Type | **Classic** (all-time) | **Recurring** |
| Reference name | `Best feast` | `Daily Bog` |
| Display name (en-GB and en-US) | `Best Feast` | `Daily Bog` |
| Score format | Integer | Integer |
| Format suffix (singular / plural) | ` protein` / ` protein` | ` protein` / ` protein` |
| Sort order | High to Low | High to Low |
| Score submission | Best score | Best score (the app submits only the day's one scored try) |
| Score range (optional) | 0 – 10,000,000 | 0 – 10,000,000 |
| Recurring settings | — | Start **Mon 2 Nov 2026, 00:00 UTC**; duration **1 day**; repeats every **1 day** |
| What the app submits | `RunResult.score` (the protein total) of every finished **Feed** run (the Feed best, as Home shows it; Daily runs go to the Daily board only: `GameCenterManager.report`, 27 Oct) | `RunResult.score` of the **first scored Daily Bog** of the (UTC) day (`RunMode.daily(day:, scored: true)`) |

**Why "protein":** it's the game's own word for the score (GAME-DESIGN §5, Results: "protein, a big counting number"), so the board reads "Best Feast · 12,480 protein". **Why the range goes to 10 million:** one 7-bug bite at ×4 can be worth several thousand, and GAME-DESIGN §5 says a perfect player's run lasts 6–8 minutes; 10 million leaves room. **Never submit** attract or lesson scores.

**Why the Daily starts on Mon 2 Nov:** a few days after the tool first creates Game Center (runbook §3), so TestFlight testers (Game Center sandbox) see the board for weeks before launch. If the tool runs after 1 Nov, Claude moves the start date to the next day before pushing (whether App Store Connect accepts a start date in the past is unconfirmed: Swoop's note).

**The Daily Bog must run on the UTC date** (`metadata.md` §11 ask 3). A recurring leaderboard resets at one UTC moment for everyone, but the contract keys the Daily seed to the player's calendar (`DailySeed.dayNumber(for:calendar: .current)`), which would mix two days' bogs on one board around midnight. Brim and Swoop both switched to UTC. Recommendation: call `DailySeed.dayNumber(for:calendar:)` with a UTC Gregorian calendar everywhere (the Daily changes at 00:00 UTC: midnight in the UK in winter, 4 pm Pacific).

## Achievements (12, 575 points)

**Which runs count:** a finished run whose `mode` is `.feed` or `.daily` (scored or practice). **Never** `.attract` or `.lesson` (First Bite's triple doesn't earn First Feast). The App calls `Achievements.earned(after: run, lifetimeBugs:, lifetimeSpared:, speciesFound:, alreadyEarned:)` once per finished run, with the three lifetime totals **already including this run** (`ProgressStore` updated first), and reports every returned id to Game Center.

| # | Achievement ID | Title | Pre-earned description | Earned description | Points | Hidden | Trigger (for Core: exact) |
|---|---|---|---|---|---|---|---|
| 1 | `snap.ach.feast` | First Feast | Catch 3 bugs or more in one bite. | Three in one gulp. A proper Feast. | 10 | No | `run.feasts >= 1` |
| 2 | `snap.ach.bite5` | Mouthful | Catch 5 bugs or more in one bite. | Five bugs, one bite, no regrets. | 25 | No | `run.biggestBite >= 5` |
| 3 | `snap.ach.chain4` | Four Times Hungry | Score a bite at x4: seven clean bites in a row. | The chain hit x4. Bite after bite after bite. | 50 | No | `run.longestChain >= 7` (the chain is ×1, ×1.5, ×2 … so the 7th clean bite in a row is the first scored at ×4, GAME-DESIGN §5; if Core's count differs, use the count at which a bite is first scored ×4) |
| 4 | `snap.ach.scarab` | Pure Gold | Catch a Golden Scarab. | The rarest bug in the bog. Shiny. | 50 | No | `(run.caughtBySpecies["goldenScarab"] ?? 0) >= 1` |
| 5 | `snap.ach.dragonfly` | Here Be Dragonflies | Catch a dragonfly. | It hovered. You timed it. | 25 | No | `(run.caughtBySpecies["dragonfly"] ?? 0) >= 1` |
| 6 | `snap.ach.spare50` | Bee Kind | Spare 50 bees, bumblebees or wasps. | Fifty stripy visitors, all sent home. | 50 | No | `lifetimeSpared >= 50` (protected bugs that came into the trap and left uneaten: `RunResult.beesSpared` summed over every counted run) |
| 7 | `snap.ach.bugbook` | Every Bug in the Book | Fill all 16 pages of the Bug Book. | Sixteen species. A true naturalist. | 100 | No | `speciesFound >= 16` (a page unlocks on the first catch, or the first spare for bees, bumblebees and wasps: GAME-DESIGN §7) |
| 8 | `snap.ach.monarch` | Bog Monarch | Reach the top plant rank: Bog Monarch. | All hail the hungriest plant in the bog. | 100 | No | `PlantRanks.rank(forLifetimeBugs: lifetimeBugs) == PlantRanks.count - 1` |
| 9 | `snap.ach.night` | Midnight Snack | Keep your trap going until night falls. | Fed from breakfast to midnight. | 25 | No | `run.waves >= 23` (waves counted from 1, as in the GAME-DESIGN §6 table: wave 23 is the first night wave; Core: use the same index base as `WaveFactory.phase(forWave:)`, so this fires exactly when a night wave has started) |
| 10 | `snap.ach.daily` | Daily Diner | Finish a scored Daily Bog. | Same bog as everyone else today. | 15 | No | `run.mode` is `.daily(day: _, scored: true)` |
| 11 | `snap.ach.score10k` | Well Fed | Score 10,000 protein in one run. | Ten thousand protein. Delicious. | 75 | No | `run.score >= 10000` (check with `BalanceTests`, below) |
| 12 | `snap.ach.nobees` | Bee-Free Diet | Catch 30 bugs in one run without biting a bee or wasp. | Thirty bugs, and not one bee in the mix. | 50 | No | `run.bugsCaught >= 30 && run.stings == 0` |
| | | | | | **575** | | |

Points: 10 + 25 + 50 + 50 + 25 + 50 + 100 + 100 + 25 + 15 + 75 + 50 = **575**. **425 points stay in reserve** for later updates (new bugs, a second bog, events), well under the 1,000 cap.

**Titles:** all ≤ 30 characters (longest: "Every Bug in the Book", 21). Game Center truncates long ones, so all twelve are short. The `x4` in #3 is a plain letter x (ASCII), so it reads the same in every Game Center font.

**Achievable more than once:** No, for all twelve. **Hidden:** none. Every goal tells the player something to try. **Progress:** report only when earned (`percentComplete` 100), and re-send every earned one on each Game Center sign-in (Swoop's 1.0 rule). Partial progress (for Bee Kind, the Bug Book and Bog Monarch) is a nice 1.0.1 addition.

**en-US** is identical to en-GB for all twelve (no spelling differences). Enter it once per locale.

**For Core, the shape of `Achievements.all`** (the contract's `AchievementDef(id:title:detail:)`): `id` = the Achievement ID above (the full `snap.ach.<key>` string), `title` = the Title, `detail` = the Pre-earned description, in the table's order. The in-app Results card and any in-app list use the same words.

## The ladder (does it feel right?)

Rough reach from GAME-DESIGN §5–§6 (to be confirmed by `BalanceTests`' `SNAP-BAL` table, 8 seeds × 4 skills):
- **First run:** First Feast (waves 4+ bring a crowd about 1 in 3), Daily Diner if they start with the Daily Bog.
- **First few sessions:** Mouthful (a gnat swarm is 5 on its own), Midnight Snack (a casual run of 2–3 minutes reaches about wave 20–30), Here Be Dragonflies (dusk, from wave 15), Bee-Free Diet.
- **A good week:** Four Times Hungry, Pure Gold (about one scarab per 12 waves from noon), Well Fed, Bee Kind (about 2–4 bees spared per run).
- **The long tail:** Every Bug in the Book (needs the night bugs and the scarab), Bog Monarch.

**Checks before the tool creates them** (descriptions and triggers can still change then; ids never): 
- `Well Fed`: 10,000 protein should be above the casual pilot's median and at or below the expert's; if not, change the number in both descriptions and the trigger together (the title stays).
- `Midnight Snack`: the casual pilot should reach wave 23 in at least a third of its runs. If casual runs end around wave 15, change the trigger to "reach dusk" (`run.waves >= 15`) and the descriptions to match, or keep it as a harder goal and raise it to 50 points.
- `Bog Monarch`: `PlantRanks.threshold(11)` should take a few weeks of play (a suggestion for Core: about 5,000 lifetime bugs, at roughly 60–90 bugs per casual run). The achievement is only fair if the top rank is reachable without grinding for months.
- `Four Times Hungry`: the casual pilot's median `longestChain` should be 3–5, the expert's ≥ 7.
- Every trigger is reachable with taps only (tap snaps count as 0.09 s: GAME-DESIGN §4). The dragonfly is catchable by a tap while it hovers or rests (its reaction 0.12 s is above 0.09 s).

If the harness shows a step is far off, change the **description and trigger** before the achievement is created, never after: changing what an earned achievement meant is unfair.

## Copy rules
- Nothing mentions snap speed, slamming, clapping or closing the phone. "You timed it" (#5) is about timing, not force.
- No "smash", "squish", "squash", "kill" or "splat". Bees are spared, sent home, never hurt.
- No competitor names, no Apple marks.

## Images (needed before you can save each achievement)

Twelve 1024 × 1024 PNGs, one per achievement, opaque (no alpha channel), in the app icon's style: deep bog green with a dewy vignette and the fold as a faint vertical glint down the middle, a medallion whose ring shows the tier (**leaf green** for 10–25 points, **crimson with gold studs** for 50–75, **gold** for 100) and one motif in the trap's glossy crimson-and-lime: the two lobes closed on three flies (First Feast), five dots in a closed trap (Mouthful), "×4" in chunky numerals (Four Times Hungry), a golden beetle (Pure Gold), a dragonfly (Here Be Dragonflies), a bee with a white halo (Bee Kind), an open book with a bug silhouette (Every Bug in the Book), a crowned flytrap (Bog Monarch), a crescent moon and fireflies (Midnight Snack), a sun over a lily pad with a tick (Daily Diner), "10k" (Well Fed), a bee with a tick (Bee-Free Diet). No words, only short numerals.

**Where they come from:** the app draws them itself, the way Brim and Swoop do (`AchievementBadge(id:)` in `Snap/UI/AchievementArt.swift`, from `TrapArt` paths). **Ask (App engineer):** add the demo key `screen=badges`, which renders all twelve into the app's Documents/badges/; CI copies them into the `screenshots` artifact, folder `screenshots/badges/`, one file per achievement named by its id (`snap.ach.feast.png`). The ported `tools/appstore/badges.swift` checks and flattens them, and the App Store Connect tool uploads each one with its achievement (`gamecenter` step). Nothing to upload by hand.

## Implementation checklist (Core and App engineers)
- [ ] `Achievements.all` has exactly these 12 ids, titles and details, in this order; the two leaderboard ids are `snap.best` and `snap.daily` (one constant each in `GameCenterManager`).
- [ ] `earned(...)` returns only ids not in `alreadyEarned`, and only for `.feed` and `.daily` runs.
- [ ] Authenticate once at launch; if the player declines, never show the sign-in sheet again uninvited. Silent when signed out.
- [ ] Banners never appear mid-run: queue them until the Results card.
- [ ] Daily: submit only the first scored run of the (UTC) day to `snap.daily`; every finished Feed run to `snap.best` (matches `GameCenterManager.report` as first written, 27 Oct).
- [ ] Tap play can earn every achievement (no hinge-only trigger).
- [ ] `CoreTests`: one test per achievement with a hand-built `RunResult` just below and just at each threshold.

## Sources
- App Store Connect Help, *Achievements* (limits, hidden, images): https://developer.apple.com/help/app-store-connect/reference/game-center/achievements
- App Store Connect Help, *Leaderboards* (classic and recurring; start date, duration, restart): https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards
- Swoop's Game Center plan (format mirrored): `C:\Users\59527\Wing\docs\appstore\achievements.md`
