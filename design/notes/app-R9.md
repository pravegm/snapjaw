# App and UI R9: premium menus, what to do, the phone path

Brief: the lead's R9 ask (the founder on build 1: "Menus feel cheap", "Unclear what to do"; phones first-class), on top of
`design/ROUND-8.md` and `design/notes/app-R8.md` / `portrait-R8.md`. Evidence: the 75 R8 CI frames in
`artifacts/r8/screenshots` (some predate the portrait change: 31 still shows the old pose card). **Not compiled
locally**: CI compiles. Nothing committed.

## New and changed APIs, demo keys and log lines (read these first)

**Words in the player's control (`Snap/App/LevelRules.swift`, `LevelWords`, pure, tested)**
- `LevelWords.goal(_ spec:, touch:)`: Core's goal text with its control words made right for the input.
- `LevelWords.outcomeLine(_ line:, touch:)`: the same for Core's level-result line.
- `LevelWords.inputAware(_ text:, touch:)` over `LevelWords.controlPhrases` (core / duo / phone forms, longest first):
  "Shut the phone on the fly" → Duo "Close the phone on the fly", phone "Tap when the fly lands"; ". Shut it fast" →
  Duo ". Close it fast", phone dropped; ". Shut it faster" → ". Close it faster" / ". Snap sooner"; "the lid" → "the
  phone" / "the trap". A text with none of them is returned as is (so a Core rewrite needs no App change).
- `LevelWords.speaksOfTheHinge(_:)`: true for "close the phone", "close it", "shut", "the phone", "lid" (the test guard).
- Used everywhere a level line is shown: Home's Play line, the intro card, the in-play goal badge, the cover's goal line,
  the level results' goal and line (`GameController.hintTouch` picks the words: a pilot on a phone layout reads as a
  phone, as the hint plate always did).

**Home (`HomeView`)**
- `playLine(_ data:, touch:)` (was `playLine(_:)`).
- `showsProgress(_ data:)` + `progressAfterLevel = 3`: the rank strip and the goals show once Level 3 is passed, or a
  run of Endless, the Daily or Zen has been played (`data.goalBook != nil || data.feedRuns > 0`).
- `rowWords` ["Levels", "Bug Book", "Garden", "Settings"], `bookBadge(_:)` (nil until a bug is found),
  `gardenBadge(_:)` (nil until a second variety grows). `QuietIcon(badge:)` is new (a gold count tab on the icon).
- `PlayButton(beckons:)`: a first launch's Play breathes (swell + glow; still in demo captures and Reduce Motion).
- `zenDetail` is kept but no longer shown.

**Levels (`LevelViews.swift`)**: `LevelMapView.padCenter` (new grid), `padSize(in:compact:)`, `path(in:through:)`,
`pathReach(_:world:)`. `OpenCue(icon:)` (nil: no arrows). `LevelIntroCard` lays out wide on a landscape phone.

**CHOMP card (`ChompWords`)**: `note(_:)` now gives a tip for a sting or a dry bite: `stingTip` "Wait for bees to
leave", `stingTipWasp`, `slowTip` "Close faster: flies flee", `emptyTip` "Wait for bugs to land" (a catch keeps "Fast
close" / "2 got away").

**Verdicts (`AppRules.biteVerdict`)**: a bite of 3+ is never "Too slow" (it says "3 bugs! 1 got away", good); a phone's
empty bite with escapes says "Missed, they flew" (never "slow"). `verdictSamples` gains it.

**Settings**: `SettingsView.replayLesson` "Replay Level 1" (replaces the map button: Home has the map),
`SettingsView.aboutLine` (both controls: "close the phone to bite. On other iPhones, tap to snap.").

**Demo pilots (`DemoRunner`)**: `DemoRunner.pilot(skill:seed:mode:)` (a level's pilot reads the goal: `minBite` =
`goal.biteOf`, `targets` = `goal.species`, as BalanceTests' pilot does) and `DemoRunner.play(_:pilot:seconds:…)` (one
pilot across slices). **Bug fixed**: `screen=levelResults` / `screen=chomp` made a fresh pilot every 0.5 s, so a level
pilot never finished a close (frames 08 and 62: "Not yet!", 0 bugs, from a *perfect* pilot). Live pilot runs
(`mode=level;pilot=…`) now get the same level pilot.

**Demo keys**: unchanged (every R8 key works; the store's screen=home/levels/results/garden/book/play and progress=late
too). **Log lines**: none new.

**ci/scenarios.txt**: captions 01, 02, 04, 05, 06, 08, 30, 57, 58, 59, 62 rewritten for R9; new **64-level-1-intro-phone**,
**65-levels-fresh**, **66-level-2-results**, **67-home-duo-fresh**.

## What changed, per screen
- **Home**: first launch = the name (bigger), one line, Play (gold glow, breathing), the three pads, the quiet row. No rank
  strip, no goals until there is progress. Pads lose their filler lines ("Until the night", "No rush, no end"); Endless
  shows a best only when there is one. Every quiet button has its word; the counts ride on the icon as gold tabs. The
  rank strip drops "Best" (it is under Endless; frame 03 truncated "Fly Catc…"). Play's line speaks the control.
- **Level map**: a U path on an even grid (top row 1–5 left to right, a soft bend, 6–10 back), pads sized to the page
  (≤ 70, ≤ 50 compact, a fifth of the width apart less 16 pt), the next pad a gold ring and glow at the same size (no
  more overlap), locked pads without empty stars, the trail gold up to the next level.
- **Level intro**: a wide, low card on a landscape phone (picture beside the goal and Go!), so it clears the pause button;
  the score hidden while it is up; the Duo's start cue has the closing phone beside it (no "open" arrows).
- **In-play goal badge**: three lines before it shrinks (frame 07 cut "Never bite the…"), a size smaller.
- **Results**: "Rank up!" never wraps (one line, fixed size; the next rank's name gives way to it).
- **CHOMP card**: the second line is a tip, not the callout again (frames 57, 58).
- **Cover, shut before the first bite**: no "0 score so far"; a level shows its goal there.
- **Settings**: Replay Level 1; About true on every iPhone.

## Phone fallback audit (no hinge)
- Nothing waits for a hinge: touch input is armed at once, so Core's `waitingForClose` clears on the first step; the
  level intro waits for Go or a tap anywhere (`sceneTapped`); `CloseToStartCard` is hidden under the intro and gone a
  frame after Go. The cover / CHOMP card only ever shows with `hingeSeen` (phones never get `.cover`).
- After a tap bite a phone sees the Scene's own shut animation, the pop and the verdict toast (never "Fast close",
  never "Too slow").
- Every control line a phone can read is tested free of close/shut/phone/lid (`phoneCopyNeverSpeaksOfTheHinge`).
- Small phones: the map's pads are sized from the page (tested at 290 × 280, the SE's page); the intro card's Go is
  capped, not fixed, so it fits a 667 × 375 page; Home's stacks fit 375 pt tall (78 + 96 + 57 + gaps).

## Tests (SnapTests/AppTests.swift)
- New `RoundNineTests`: `noPlayerLineSaysLid` (every hint, coach line, verdict, level goal and result line in both
  controls, Home, Settings, CHOMP and cover words; "lid" as a word), `phoneCopyNeverSpeaksOfTheHinge` (and the Duo's
  level lines never say "shut"), `homeShowsLessToANewPlayer`, `theMapsPadsNeverOverlap` (four page sizes, tap frames
  and star rows, the glow, the path's order), `aLevelsDemoPilotReadsItsGoal` (and Level 1 passes, played in 0.5 s
  slices with one pilot), `settingsSpeakBothControls`.
- Updated: `chompCardWords` (the tips), `biteVerdicts` (a feast with escapes, a phone's miss). HUD/cilia clearance tests
  untouched (no HUD layout change).

## Asks for other owners (exact strings; not edited: not my files)
**Core (`Snap/Core/LevelData.swift` via tools/levels.js, `Levels.swift`)**. The App maps these already, so nothing
breaks either way; control-free Core text is still better (one source, no mapping):
- Level 1 goalText `"Shut the phone on the fly"` → `"Catch the fly"`.
- Level 2 goalText `"Catch 2 flies. Shut it fast"` → `"Catch 2 flies"` (the Duo's coach already says "Slow closes lose
  flies" and "Now! Close it fast!").
- `LevelBook.evaluate` line `"Out of time. Shut it faster"` → `"Out of time. Bite sooner"`.
- Shorter goals for the in-play badge: Level 4 `"Catch 2 flies. Never bite the bee"` → `"2 flies. Spare the bee"`;
  Level 5 `"One bite, 3 bugs: the Feast"` → `"One bite, 3 bugs"`.
- `Snap/Shared/Contracts.swift` comment on `TrapHint.bendALittle` (`"Bend it a little, like a book"`) is a stale pose
  demand (comment only; the App shows nothing for it).
**Scene (`BogScene.wiltedLabel`)**: `"Too slow! −1 snap"` → `"Hungry! −1 snap"` (R8 made "too slow" mean the close's
speed; a wilt is hunger), and frame 34 shows that pop sitting on the "SNAPS" caption: lift it clear of the row's label.
**Lead / docs**: CLAUDE.md's opening still describes the R7 verb ("Hold it open like a book", "Snap the phone a little
shut (about 22°)"); store captions in ci/store-* that mention Home's "0/16" / "1/8" counts or the Play line need a look.

## Unsure / for review (CI and the founder's hands)
- Not one pixel of this has been seen: every layout number above is reasoned, not captured. Check 01, 04, 05, 08, 64–67.
- `fold=1` on a phone sim: Home speaks the Duo's words (`showsFoldInput`), the HUD and level lines the phone's
  (`hintTouch`). A real phone never has a fold, so this only shows in CI frames.
- The level pilot now bites as soon as its goal's bugs land, so frame 06 (`freezeOn=landed`, casual) may miss its
  sipping moment; it is captured anyway.
- Level 1's pass in `aLevelsDemoPilotReadsItsGoal` leans on Core's balance (a 60 s linger, the perfect pilot's
  patience); if Core retunes Level 1 that test is the canary.
- The Play button's breathing uses `repeatForever`; under the store's demo captures it is still (`AppTrace.enabled`).
