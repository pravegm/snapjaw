# App, UI and Feel R8: the phone IS the trap

Brief: `design/ROUND-8.md` §1, §3, §4 (App, UI and Feel owner) plus the founder's binding rules (no pose demands, every
round starts closed, "phone" not "lid", no forced tutorial, phones first-class). **Not compiled locally**: CI compiles.

## New and changed APIs and log lines (read these first)

**App (GameController)**
- Closed is not a pause. `isClosingPaused`, `ClosingCard`, `AppRules.mayResume/resumeAngle` and every `isClosing` call
  are gone. Pause reasons: `menu`, `background`, `pose`, `intro` (a touch level's intro). The pause menu comes only
  from the pause button.
- `stepFromHinge()` (from `hingeSample`): when no scene frame has come for `AppRules.sceneFrameGap` (0.12 s; the Duo
  shut moves the app to the outer display) a live hinge run is stepped from the hinge report itself, ignoring the
  pose/background pauses (never the menu). The bite at the shut, its CHOMP and haptic, therefore land at the shut.
  Rule: `AppRules.stepsFromHinge(sinceSceneFrame:liveHingeRun:menuOpen:)` (+∞ = never drawn counts; NaN never).
- A pose-pause resume no longer resets the hinge (the reopen is the re-arm; Core must see it whole).
- `@Published coverChomp: ChompInfo?` (the run's last bite, for the outer display), `levelIntro: LevelIntro?`,
  `bitesThisRun`, `awaitingFirstBite`, `levelID`, `levelGoalLine`, `nextLevelLine`.
- `play()` = the next level (`LevelRules.next`), else Endless; `playEndless()`, `playLevel(_:)`, `playNextLevel()`,
  `beginLevel()` (Go), `feedbackTap()`, `starLanded(_:)`. Every launch opens on Home (no forced tutorial).
- Menus (`AppRoute.showsLiveBog`: everything but `.playing`) run Home's attract bog live behind them; Results makes a
  fresh one. `AppRoute.lesson` is gone, `.levels` is new.
- Sets `BogScene.usesHinge` (`SceneHooks.setUsesHinge`) on every input change and new scene.
- Uses `TrapSnapshot.waitingForClose` (the "Close the phone to start" card; the plate is quiet meanwhile) and
  `TrapSnapshot.shut`, `BiteReport.catchRatio`, `RunResult.escapes` (RunTally now counts escapes).
- Levels: `SessionOptions.for(.level(id))`, seed `LevelBook.seed(id)`, no goals (the three goals are Endless/Daily/
  Zen's). Core ends a level itself; the App ticks the goal line when `LevelBook.evaluate` on the run so far passes,
  and only if Core hasn't ended it 4 s later (`levelEndBeat`) does it end it. `file(_:)` records every run once and,
  for a level, `fileLevel` keeps the stars (`ProgressStore.recordLevel`).

**Persistence**: `ProgressData` v3: `levelStars: [Int: Int]` (id → best 1…3; migrate drops bad ids/values).
`RecordOutcome.level`. A level run fills the Bug Book and the rank, keeps no best, no leaderboard.

**LevelRules / LevelBridge / LevelWords** (`Snap/App/LevelRules.swift`): the one place the App reads `LevelSpec`;
world and level unlocks are Core's `LevelBook.worldUnlocked/levelUnlocked`; `next`, `nextAfter`, `record`.

**Words** (`AppRules`): `biteVerdict(_:touch:)` ("3 bugs! Fast close", "Too slow, they flew", "Bee! −1 snap",
"Empty bite"; ≤ 0.3 s is fast; < 60 % caught with escapes is too slow; a tap never says "Fast close"), shown as
`HUDHint.verdict` (a toast, cream or crimson) on the reopen. `coachLine` for Levels 1–5 (`HUDHint.coach`).
Hints: `.bendALittle` says nothing (no pose demands); "Close it fast!", "Open it again", "Now! Close it!" / "Now!
Tap!", "Last snap!", "Hungry! Bite soon"; the first-wave line is "Close the phone to bite" / "Tap to snap".
Removed: `tooFlatCopy`, `isTooFlat`, `flatGuardedHint`, `lessonShowsHint`, `lessonSpot(s)`, `liveClaims`.

**Feel**: the CHOMP and its heavy haptic still fire on `.snapped`, which Core now fires at the shut. The slow-close
groan and its haptic texture stretch over the whole close: `FeelSoundBook.closeFrom` 8° … `closeFull` 120° (no more
`Tuning.snapDepth/creepDepth`); Home's stretch meter too.

**UI**: `Craft.swift` (DisplayText, LeafShape/LeafPanel: every `snapCard` is now a leaf-cut panel, PadButton,
LilyPadShape, StarRow, `entrance(_:)`), `ChompCard.swift` (ChompArt, ChompCard, ChompWords, OpenCue, CoverBackdrop),
`LevelViews.swift` (LevelMapView, LevelPad, LevelIntroCard, LevelGoalBadge, CloseToStartCard, LevelResultsView,
LevelArt). Rebuilt Home, restyled Results/Garden/Bug Book/Settings headers and every button. `LessonScript.swift`,
LessonCard and LessonFinalCard are deleted (CI no longer needs them).

**Log lines (new)**: `SNAP-T verdict '<words>' ratio=<r>`, `SNAP-T hinge step shut=<0|1> angle=<deg>`,
`SNAP-T level intro <id>`, `SNAP-T level go`, `SNAP-T level passed <id> t=<s>`,
`SNAP-T level result <id> stars=<n> passed=<0|1> best=<n>[ world=<w>]`, `SNAP-T chomp card <kind> …`,
`SNAP-T level demo <id> played=<s>`, `SNAP-T screen levels`, `SNAP-T paused intro`. **Gone**: `SNAP-T paused
closing`, `SNAP-T lesson step …`, `SNAP-T too-flat on|off`.

## Demo keys (for ci/scenarios.txt)

| key | what |
|---|---|
| `screen=levels` | the level map (`progress=mid`: 7 next; `late`: Night open) |
| `screen=levelIntro;level=<n>` | a level's intro card, held (no pilot: a phone sim waits for Go) |
| `screen=levelResults;level=<n>[;pilot=…]` | the level played by the pilot (default perfect) until Core ends it, then its Results (3 stars on level 1 with `perfect`) |
| `screen=results;mode=level;level=<n>` | the same |
| `screen=chomp[;chomp=catch\|sting\|dry]` | the outer display's CHOMP card on a real bite of that kind (made up and logged if the pilot never makes one) |
| `screen=shut` | the shut state: a run just started, closed before its first bite ("Open to start") |
| `screen=cover` | R8: the outer display off a run (closed trap at rest, "Open to play") |
| `mode=level;level=<n>` | play level n (with `pilot=`, past its intro) |
| retired | `screen=lesson`, `lessonStep=` (parse to nothing: the app opens on Home) |

All older keys still parse. ci/scenarios.txt 04–09 now are the level map, intro, two level frames, level results and
the CHOMP card; 57–63 are new (sting/dry CHOMP, shut, late map, level 5, a failed level, Endless Results).
P10/D10 and DR1/DR4/DR5/DR6/DR8/DR12 in the store files are re-pointed off the lesson and the old verb.

## For other owners (not edited: not my files)
- **ci/duo.sh** (Core/CI): the `ui-lesson-*` launches use `screen=lesson;lessonStep=…` (now Home) and grep
  `SNAP-T lesson step`; `close-pause` greps `SNAP-T paused closing` (gone). **ci/duo-scenarios.txt** 14, 15, 22, 23
  are lesson frames too, and 17/18 captions say "Hold it open like a book" / "the score".
- The Duo's portrait canvas (tabletop/"laptop") still shows the pose card (now "Snapjaw plays sideways", no hold
  instruction): playing in portrait needs a portrait layout (founder rule 2 asks "any angle plays"). Not done.
- `DuoClapDiagram` (TrapDrawing) still claps 160° → 138° (the old verb); only the pose card draws it now.
