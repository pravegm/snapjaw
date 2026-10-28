# Round 2: make it read, make it bite (brief)

R1 compiled first time (CI 40601210488, 151 tests) and already looks like a game. Critics scored it Juror 5, UX 4,
Feel 4, Duo 5 (`design/REVIEW-1-*.md`, merged list `design/REVIEW-1-summary.md`). QA-1 (`design/QA-1.md`) found 1 P0
and 4 P1. Frames: `artifacts/r1/*.png`.

**Do every item in REVIEW-1-summary #1–#25 and every QA-1 finding (P0, P1 and the P2s that are yours), in your own
module**, plus the founder items below. The founder's calls on the open questions:
- **#10 Hunger: yes**, exactly as GAME-DESIGN §5 "Hunger" (now in the doc). Contract: `TrapSnapshot.hunger`,
  `TrapEvent.hungry(secondsLeft:)`, `TrapEvent.wilted(snapsLeft:)` and `TrapHint.hungry` (already in
  `Contracts.swift`). **Every module must handle the new cases** (exhaustive switches: AppTrace logs
  `event hungry` / `event wilted`; Feel plays a soft wilting "droop" sound and a weak haptic on `wilted` and a
  stomach-rumble on `hungry`; Scene drains/greys the next snap glyph if the Scene draws it, or App/UI does in the HUD;
  a small "wilted −1" pop).
- **#15 Chain rule: yes** (GAME-DESIGN §5).
- **#24 First runs: yes**, Sprout starts with 12 snaps. Core adds `SessionOptions.startSnaps: Int?` (nil = Tuning);
  the App passes 12 while `PlantRanks.rank(...) == 0`.
- **#12 One art language: yes.** Home, cover, Results and Bug Book use `TrapArt.bugImage` and a scene-rendered (or
  TrapArt-path) trap identical in style to play. The Home title trap may be a live `BogScene` in attract mode behind
  the menu.
- **#5 Trap look:** yes to the darker, deeper lobe and the thinner, longer teeth. Keep it glossy and cartoon-cute,
  never gross.
- **Bugs ×1.8** (#4): Scene scales the art; Core multiplies `BugInfo.radius` by 1.8 (spacing, rim test, landing
  spots) so art and rules agree; re-run the sim.
- **Crowds:** with bigger bugs, crowds must still form. Core: nectar drops 6–8, clustered 2–3 per lobe region (#19),
  and crowd waves land within 1.2 s.

## Owners
- **Core** (`Snap/Core`, Core/Balance tests, `tools/balance-sim.js`): #4 radii, #10 hunger, #15 chain, #19 nectar
  clusters, #24 startSnaps, QA-1 items in Core, any `partialResult` fix. Keep the sim in lockstep and re-tune so the
  R1 balance assertions plus these hold: perfect run median 4–7 min; casual 100–240 s; casual longest chain 3–6.
- **Feel** (`Snap/Input`, `Snap/Feedback`, FeelTests): QA-1 #4 voices (128, steal by start order), #5 creep after
  reopening (reset creepRef on any rise above it; no creep within 0.6 s of a re-arm or while θ is rising), the new
  hunger sounds/haptics, and anything else in QA-1 for you. CHOMP: make the bite feel heavier with the new hit-stop
  (a 50 ms gap before the squelch tail is fine).
- **Scene** (`Snap/Scene`, SceneTests): #1 streaks (find and test), #4, #5, #6 bite read (hit-stop, lobe squeeze,
  flash, shake), #7 rings, #11 pop clamping off the crease, #17 economy glyph flights (coordinate with App: the snaps
  row is App/UI; Scene can expose `hudSnapsAnchor: CGPoint` for App to set), #18, #19 drop look, #20 closure tracking
  (use `HingeTrapSource.predictedAngle(at:)` only via a value the App passes, e.g. `scene.drawnClosure`), #21 night,
  QA-1 #19 halo flicker and other Scene P2s. Also the icon (`REVIEW-1-juror`: no midrib through the fly; cilia not
  fangs) if the icon art lives in Scene; otherwise App.
- **App/UI** (`Snap/App`, `Snap/UI`, `Snap/Persistence`, AppTests): QA-1 #1 closing pause (P0), #2 reset in `start()`,
  #3 lesson, #2/#3/#11/#12/#13/#14/#16/#22/#23 of the summary, startSnaps for Sprout, the hunger HUD, the icon.
- **CI** (`ci/`, workflows): #25 frames (05, 07, 16 timing; a 951 × 669 `fold=1` render with the fold band forced,
  letterboxed if needed), add frames for hunger (`freezeOn=hungry`) and `wilted`. App adds the matching freeze tags.

## Rules (unchanged from R1)
- No compiler locally: re-read every file you touch twice for compile errors. Exhaustive switches over the contract
  enums (`TrapEvent` has two new cases, `TrapHint` one).
- Only write in your own folders; needs go in `design/NEEDS.md`.
- Hand-off note: `design/notes/<module>-R2.md`.
