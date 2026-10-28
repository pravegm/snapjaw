# App engineer: Round 7 hand-off

Files: `Snap/App/*`, `Snap/UI/*` (not `AppIconArt.swift`), `SnapTests/AppTests.swift` (new suite `RoundSevenTests`,
R5/R6 expectations updated where R7 changed the words). **Not compiled.** Every edit was re-read for Swift 5, builder
`let`s, exhaustive switches (`DemoMode.Freeze` +`feastGulp`, `DemoMode.Preset` +`story`, `GoalTier`, `VarietyUnlock`,
`HUDHint`), no closure/key-path calls inside `#expect`, `CGFloat.nan`/`Double.nan` only, no local shadowing a static.
Core API used as briefed: `GoalSpec.tier` and `tier.label` (`GoalLine.tier`, `GoalRow.tierColor` switches
`.easy/.medium/.hard`). Points are read from the report, never recomputed.

## New demo keys and log lines (for CI)
- `freezeOn=feastGulp`: a clean 5+ bug bite; holds 0.15 s and pauses the **scene at once** (no 0.4 s scene-hold
  delay), so two gulps are going in and the rest of the crowd is still in the jaws. P02/D02:
  `pilot=expert;progress=late;freezeOn=feastGulp` (drop `freezeAfter`). Logs `SNAP-T freeze feastGulp`.
- `progress=story`: rank 7, 13 species, best 9,400, the Garden 5/8 (Sawtooth and Shark Tooth by goal), 3 dailies.
- `freezeOn=tired` now holds at 1.6 s (was 1.0): the banner waits for the bite's pops (cap 1.5 s).
- `screen=results;mode=zen` without `seed=` plays seed 23 (`DemoMode.zenResultsSeed`), not 7.
- New line `SNAP-T too-flat on|off angle=<deg>` (play on a hinge at ≥ 174°). duo.sh's too-flat expect can grep
  `SNAP-T too-flat on`.

## Items
- **#3:** the row tag shows a FEAST's refill ("FEAST! +2 snaps"), lucky bugs in plain words ("Golden scarab! +2
  snaps", "Ladybird! +1 snap"), "+1 snap (row full)", and the first Feast's "+1 snap". `AppRules.biteName` has no "×".
- **#5:** `MessageQueue.gap` 0.4 s between messages (warnings and interrupts excepted). A toast with no slot clear of
  the trap's bugs waits with its clock still (`hold`, max 2 s, then shows in the slot covering fewest). The tired
  banner waits for live pops. "+2 (full)" is now "+2 snaps (row full)".
- **#7:** Results has no scroll: `ViewThatFits` over 5 column fits (list → grid → strip → tight → tightest; a scroll
  only beyond that). Feed's title on a new best is "What a feast!".
- **#8:** the cover's GeometryReader ignores the safe area (the 43 pt left shift was an 86 pt stale trailing inset
  applied before `evenInsets`). Leaderboard comments say "Best Score"; `AppRules.leaderboardName`.
- **#10:** "Zen Bog" lime badge under the HUD score; Zen Results shows the score plus "94 bugs in 2:30 · no best kept".
- **#12:** Duo lesson counts 5 steps (the re-arm step is "Step 2 of 5"); phones 4. "Fold it a little" replaces any
  non-warning hint while the hinge reads ≥ 174° in play (the lesson's pose step: "Fold it a little, like a book").
- **#13:** where the numeral sits on the row, a "SNAPS" caption (`HUDLayout.snapsLabel`); Duo glyphs 24 → 28 pt.
- **#15:** tier dot + word on Home's goals, dot elsewhere; Results "Next goal" (first new goal, else first open) and
  the Bug Book's next page (own cards, or one shared card in tight fits).
- **#17:** a bee whose halo (+8 pt) reaches the trap's edge blocks "Hungry… bite!".
- **#19:** "Rank: …" / "Goal: …"; every locked card draws Classic's silhouette.
- CI asks: D06 Home caption "Snap it a little shut" (the pose card already said it); the triple step's card says
  "Wait for a crowd of three…" so only the "Now!" plate says now (P10/D10/08). Caption of 08 needs updating.

## Needs Scene (not my files: please apply in `BogScene.swift`)
The bite pop, the FEAST banner, "Stung!" and "Lucky!/Golden!" are Scene pops. Strings are ready in `AppRules`:
1. `heroLabel`/`bigFeastLabel`/`countLabel`: use `AppRules.biteCallout(count:points:)` ("5 bugs · +540").
2. FEAST banner: centre it over the trap (`g.center`, not the crowd's side) and draw the callout at 1.6× the QUAD size.
3. `luckyLabel`: `AppRules.luckyText(s, snaps: showsEconomy)`.
4. "Stung!": try above the ring first (today it tries below and only moves on overlap).
5. Optional: drop the "×1.5 held" line when a lucky line shows (frame 46's three pops).

## Risks
- Results fits are by `ViewThatFits`; check 20/26/47/50/51/P09 and D09 that the chosen fit isn't the scroll.
- Duo glyph 28 pt and the moved chain chip: `hudClearsTheCiliaOnTheDuo` will catch a cilia hit.
- The too-flat prompt needs the hinge to have sent a sample (duo.sh sets 178° before launch).

## Follow-up (the founder): Core's clear zones wired in
- `GameController: SceneKeepOutReceiver` (a `nonisolated` witness that runs on the main actor through
  `MainActor.assumeIsolated`; the Scene always calls it from the main actor). It sets `keepOut` on the play session
  and on Home's session, and keeps the last set for a session made before a scene exists.
- Each new session (`start`, `makeHomeSession`) takes `scene.applyKeepOut(to:)` before its first step. The HUD plates
  (`setHUDKeepOut`) and Home (`setShowsEconomy`, `homeButtonFrames`) then reach both sessions through the receiver.
- Home's real button frames: each button row reports its frame (`homeButtonFrame()`, `HomeButtonFramesKey`, measured
  in the `snap.home` coordinate space, which is the canvas). `HomeView.sceneRects` turns them into scene space, rounded
  out to 2 pt, and sends them through `SceneHooks.setHomeButtonFrames`. Tested in `homeButtonFramesInSceneSpace`.
- No demo key changed. No AppTests expectation hard-codes Core's bite points: they use hand-built `BiteReport`s, so
  the FEAST ×2 needs no test change. Demo frames move: resting bugs now avoid the HUD, the midrib, the edges and
  Home's buttons.
