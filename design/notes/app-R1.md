# App engineer: Round 1 hand-off

Folders: `Snap/App/`, `Snap/UI/`, `Snap/Persistence/`, `Snap/Assets.xcassets`, `Snap/PrivacyInfo.xcprivacy`,
`SnapTests/AppTests.swift`. **Not compiled** (no compiler here). I re-read every file twice and ran a bracket-balance
check. Code that compiles in Swoop/Hush was copied wherever it fit.

## Files
- **App:**
  - `SnapApp` (in-memory stores in demo runs).
  - `AppBrand` (`CFBundleDisplayName`; the one product-name literal is its fallback).
  - `AppTrace` (`SNAP-T` lines, `describe(TrapEvent)` covers every case, the trap line).
  - `AppModels`: routes, poses, input kinds, `HUDState`/`HUDValues`, `HomeTrapState`, `ResultSummary`,
    `FixedTrapSource`, `AppFrameTicker`.
  - `AppRules` (pure rules):
    - pose and fold rules, dt clamp, the resume angle;
    - hint words (≤ 6), banners, numbers, Daily dates (UTC, matching `DailySeed`);
    - telemetry and buzzers, lesson spots, the Results sentence, near miss, again-mode;
    - `RunTally`, the partial result for a run left early.
  - `OrientationLock`: Swoop's rule. Portrait and landscapes on a Duo, landscape only elsewhere, never upside down.
  - `BuildChannel`, `GameCenterManager` (Hush's, ids `snap.best`, `snap.daily`, `snap.ach.<key>`), `SnapPNG` (Hush's
    OpaquePNG).
  - `DemoMode` + `DemoPresets` + `IconExport`, `DemoRunner`, `LessonScript`, `GameController`.
- **UI:**
  - Theme and layout: `SnapTheme` (bog greens, crimson, gold, SF Rounded, chunky lipped buttons, ≥ 56 pt), `Layout`
    (`AppCanvas` scene↔screen mapping, pages, `HUDLayout`).
  - Drawing: `TrapDrawing` (`TrapPortrait`, `BugPortrait` from TrapArt paths and palette, `SnapGlyph`).
  - Screens: `RootView`, `PoseCards`, `HomeView`, `PlayHUD`, `ResultsView`, `BugBookView`, `SettingsView`,
    `DailyView`, `AppIconArt`.
- **Persistence:** `ProgressStore` (v1, tolerant decode, corrupt-save backup, checkpoint) and `SettingsStore`.

## Screens and flows
- **Launch.** A first launch goes to the First Bite. After that it goes to Home. A run killed in the background is
  filed at the next launch.
- **Home:**
  - A live title trap (TrapArt paths) follows the hinge. A snap closes it and pops "CHOMP!", and
    `FeedbackDirector.homeTrap` gets the closure in degrees. On phones a tap does the same.
  - A bee bumbles across. The title and tagline sit on the other page, with the rank card and its bar.
  - Feed, Daily Bog (with its status), Bug Book (n/16) and Settings sit on the HUD page (right).
- **Play:**
  - The HUD sits in the corners of `layout.hudRect`'s page. Score and best are top-outer with the pause button. The
    chain chip sits under the score. The snaps row (trap glyphs) is bottom-outer, with the hint plate above it.
  - `hudLeft` mirrors all of it.
  - The pause menu has Resume, Restart ("Restart as practice" on a scored Daily) and Home.
  - The closing card says "Open it a little to carry on", with a Menu button. "Your trap is tired." shows at the end,
    then Results after 0.6 s.
- **Results:**
  - The other page counts the protein up, then shows new best, first feast or the near-miss line, and the story
    sentence.
  - The HUD page shows the stats, the new Bug Book pages, the rank bar and Again / Home. Again on a Daily plays
    practice.
- **Bug Book:** two pages of 8. A found entry has its art, name, count ("Caught n", or "Spared n" for protected bugs)
  and joke. An unfound one is a silhouette with a clue.
- **Settings:** the five toggles, Replay First Bite, Game Center, About (the version, plus the channel and input in
  test builds) and Credits.
- **Daily Bog:** one scored try a day, started when it begins. After that you get practice and a history of recent
  days.
- **Pose card:** portrait on a Duo shows "Hold it open like a book". A phone held upright waits 0.6 s, then asks iOS
  for landscape.
- **Cover card:** the shut Duo or the cover display shows "Open to carry on" mid-run, with the score so far.
- **Pauses:**
  - What pauses: the closing gate, the app going inactive or to the background (the menu opens only on background),
    the menu, and a pose card.
  - The closing pause ends once the hinge is open again past 120° and not shut.
  - The tired ending keeps stepping under a closing or pose pause, and a watchdog finishes it headless if the scene
    stops drawing.
  - `HingeTrapSource.reset(at:)` runs on every resume and every activation. `sceneWidth` and `deviceHasFold` are set
    (Feel's request).
- **First Bite:**
  - It has 7 steps per GAME-DESIGN §8, with scripted spawns via `spawnScripted`.
  - Misses, creeps and bites on the bee repeat the step. Skip appears after step 2.
  - Touch wording switches automatically. Without a hinge the pose step is skipped.
  - The last card offers "Start feeding" or Home.

## Demo keys (all from ROUND-1)
- Keys: `screen=home|play|results|book|settings|lesson|pose|cover|icon` (plus `daily`), `mode`, `seed`, `pilot`,
  `progress`, `freezeOn` (all 11 tags), `freezeAfter`, `closure`, `wave`, `lessonStep`, `hudLeft`, `fold`, `sound`.
  `SNAP_ICON=1` also renders the icon.
- `results` plays a real pilot run headless and records it.
- `wave` uses Core's `SessionOptions.firstWave`.
- Event freezes hold for a beat (`snap` 0.12 s, the others 0.3 s), then pause the scene.
- Lines printed:
  - `SNAP-T canvas`, `input`, `trap` (10 Hz), `event <case>` (snapped with caught, escaped, stingers, points, d),
    `paused closing`, `resumed`, `freeze <tag>`, `frame 120`.
  - Also: `screen`, `pose`, `lesson step`, `run`, `abandoned`, `icon ok`, `SNAP-ICON <path>`.

## Deviations
- **The scene keeps rendering in demo runs on every screen**, so `SNAP-T frame 120` always prints. In real runs it
  pauses off-play.
- **Runs left early are filed** from the App's `RunTally`, because Core has no partial result. See NEEDS.
- **Settings has no Diagnostics panel or hidden gesture** yet. Test builds show the channel, input and angle under
  About.
- **The App icon is my own vector drawing** (`AppIconPainter`), not a Scene drawing. `Assets.xcassets` holds Swoop's
  1024 PNG as a placeholder until CI writes ours.
- **Bug portraits draw their eyes from the body's bounding box.** If the Scene's bodies differ, that is cosmetic only.

## Risks
- This code has never been compiled. It uses SwiftUI view-builder `let`s in switch cases, `UnevenRoundedRectangle`,
  `reservedRegions(kind: .division)` (behind `#available(iOS 27.1, *)`) and `GraphicsContext` gradients. All of
  these patterns compile in Swoop or Hush.
- The HUD corners on the Duo overlap the outer rim of the trap ellipse slightly at the top. Needs judging on frames.
- The lesson's timings (respawns 1.2 s, the stung bee's exit 2.4 s) are untested against Core's real motion.
