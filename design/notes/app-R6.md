# App engineer: Round 6 hand-off

Folders: `Snap/App/`, `Snap/UI/` (`AppIconArt.swift` untouched), `Snap/Persistence/`, `SnapTests/AppTests.swift`.
**Not compiled** (no Swift here; CI is the compiler). Every touched file was re-read twice for Swift 5, ViewBuilder
`let`s, isolation, exhaustive switches (`RunMode` with `.zen`, `HUDHint`, `DemoMode.Freeze`, `AppRoute`), no closure or
key-path calls inside `#expect`, no bare `.nan`, no local shadowing a static. New tests: `RoundSixTests`.

## One source of truth
Core owns goals and the Garden; the App only files and shows them (`Snap/App/R6Bridge.swift`):
- `ProgressData.goalBook: GoalBookState?` (Core's, persisted; nil until the first run, `ProgressRules.goalBook(_:)`
  is the same book Home shows meanwhile: a seed fixed by the save).
- Live: `GoalRun` wraps `GoalTracker` (`GoalBook.tracker`, the start phase from `firstWave`); `note(events)` → toasts.
- Filed: `GoalReport` (each goal's tracker progress + ids met) → a tracker with that progress carried →
  `GoalBook.complete(…, rank:)` at the rank the run reached. Finished, left-early and killed runs (checkpointed
  `pendingGoals`) all go this way.
- Rank: `growth = rankBugs + goalBook.growth`. `rankBugs` grows by `PlantRanks.growth(from:)` (Zen a quarter,
  founder rule); `lifetimeBugs` and the Bug Book count every bug. A v1 save takes `rankBugs = lifetimeBugs`.
- Garden: `Varieties.unlocked / effective / newlyUnlocked / ruleText / info`.
- FEAST: `FeastEvent.isBig` (never with a stinger). Feel: `goalCompleted(bonus:)` after `handle`,
  `varietyUnlocked(after:)` (0.8 s after a rank-up's celebrate), `zen = wantsZen(mode)` at every run start and Home.

## Features
- **Goals:** Home card (banked progress), pause menu (this run, live; dimmed if the mode doesn't count or it's
  spoiled), toast "Goal done!" + title (gold-edged plate), Results card (ticked, "+n growth", "All three!", "n new goals
  on Home"), growth on the rank bar.
- **Garden:** Home button ("3/8", "New"), `GardenView` (4 a side, silhouettes + rule, tap to pick, gold ring), the pick
  in play (`BogScene.variety`), Home's bog, Results' and the cover's hero; Results' "New in the Garden" + "Use it".
- **Zen:** Home "Zen Bog"; no snaps row; pause menu End → Results ("bugs caught" hero, no best, no leaderboard);
  Again = Zen.
- **Daily:** streak on Home's Daily button (from 2), DailyView, Results pill; Share text "… · 🔥 4 days 🪤".
- **#6:** `MessageQueue`: every toast and tag through one queue; Core hints only when empty; tags interrupt, toasts wait,
  a warning freezes a toast's clock. No "free!" beside the free-sting plate; the chip glows instead of "×2 held"; the
  lesson's bee step drops the doubled "Bee! Wait…". The plate avoids pops (strict) and bugs on the trap (soft).
  Night cues ("The night gets fast…", "Last light…") are toasts.
- **#12:** cover card insets applied evenly (portrait ignores side insets), bigger tiers, trap up to 92 %; "1,174" +
  "score so far"; "Best score 3,200".
- **#14:** numeral 30/24 pt with "SNAPS" under it, above the rows in the outer corner, the chain chip beside it (or
  above); only where it all clears the cilia, else R5's layout (`numeralLabeled`). The HUD outline is every variety's
  cilia (B52 longer) so the HUD never moves with the Garden. One-time chain explainer ("Chain ×1.5! Big bites in a row
  multiply.") is a persisted flag.
- **#16:** Results "Next for the Bug Book": the unfound page earliest in the day, silhouette + clue.
- **#13:** the lesson re-publishes its words on the first hinge sample.
- Scene `hudKeepOut` = the HUD's two corners (scene space), reset on Home.

## Demo keys (documented in DemoMode)
`screen=garden`, `mode=zen`, `freezeOn=bigFeast` (0.45 s), `freezeOn=goalDone`, `variety=<raw>`;
`screen=results` ticks goals (pilot-played); `screen=results;mode=zen` plays 150 s then End; `mode=daily` results with
`progress=mid` shows 🔥 3 days + Share. Presets carry a goal book (late: Sawtooth and Shark Tooth grown by goal).
New log lines: `SNAP-T goal done <id>`, `night cue`, `zen end`, `results goals`, `variety`.

## Risks
- The union outline (all varieties) is more conservative: on the Duo the chain chip may go short ("×2") and the
  labelled numeral may fall back to R5's on some canvases. Check frames 10/18 and the Duo.
- Long goal titles ("Catch a housefly, a fruit fly and a bluebottle in one run") take 3 lines on the plate.
- The goal toast shows at once; Feel's chime waits 0.62–1.5 s after a bite.
- Home's left page is taller (rank + goals); check frame 01 on a phone.
