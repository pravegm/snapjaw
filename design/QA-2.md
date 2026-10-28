# QA-2: Snapjaw bug audit after R3 (28 Oct 2026)

*QA lead. A read-only pass over `Snap/` at `4da605d`: about 22k lines, focused on what R2 and R3 changed. It covers
App, UI, Persistence, Core hunger and stingers, and Input. A sub-reviewer covered `Feedback/` and `Scene/` (audio,
haptics, SpriteKit and per-frame cost). I re-checked its headline claims in the code, and those findings are marked
"(sub)". No code was changed.*

**Severity** (as in QA-1)
- **P0** blocks play, loses a run or loses data.
- **P1** clearly wrong behaviour that a player will notice, or that costs them a snap or score.
- **P2** an edge case, a cosmetic problem, or a risk to confirm on a real Duo.

**Summary:** 0 P0, 1 P1, 19 P2 (plus one checked non-issue, #20).
- QA-1's P0 (the closing pause) and its three P1s are fixed. QA-1 #4 (voices) has a small leftover, which is #16 here.
- The new findings are mostly about how R3's rules are shown, not the rules themselves:
  - the snaps numeral offset (`snapsShownOffset`) against Core's clamps and the frame order;
  - the hunger warning in the HUD;
  - the Sprout run-1 detection.
- Core's R3 rules are implemented as briefed: stinger bites score ×1 and refund nothing, the free first sting is spent
  once per run, and hunger is off for the lesson, attract and the Daily.
- One gap: the hunger clock doesn't stop once the trap is empty again (#1).

---

## P1

### 1. Once started, the hunger clock keeps running when the trap is empty or holds only a bee. A player who waits correctly loses snaps.
- **Where:**
  - `Snap/Core/TrapSession.swift:806`: `hungerRunning = true` on the first catchable in-trap landing.
  - `:997-1001`: only a catching bite stops it.
  - `:373`: it ticks whenever `hungerRunning` is set.
  - `:397-405`: after a wilt it restarts at 0 and keeps running.
- **What the player sees:**
  - GAME-DESIGN §5 (R3) says "an empty trap (or one with only a bee in it) never gets hungry". That only holds before
    the first landing of a cycle.
  - Example: a housefly lands (the clock starts), then a bee lands beside it. The player waits for the bee to go,
    which is the right play.
  - The fly's linger runs out, or a slight creep spooks it, and it leaves. The trap now holds only the bee, but the
    clock keeps running.
  - "Hungry… bite!" shows, and the only bite available is the bee. A wilt then costs a snap.
  - If nothing catchable lands afterwards, it wilts again every 18/16/14/12 s.
  - core-R3 assumes "a bug is still about" after a wilt, but the code never checks that.
- **Frequency:** not measured. Waves usually refill the trap, so this most often bites at night (12 s wilt, 1–2 bees
  per wave) and while waiting out bees.
- **Minimal fix:**
  - In `tick`, only call `tickHunger` while a catchable bug is in the trap: `inTrap(b)`, landed, `mode` not
    leave/escape/caught/release, and not protected.
  - Alternatively, clear `hungerRunning` (and `hungrySent`) when the last such bug leaves.
  - Mirror the change in `tools/balance-sim.js`, then re-run it: the perfect and casual wilt counts will drop, so the
    `extraBeeEvery` margin in core-R3 needs re-checking.

---

## P2

### Snaps numeral and economy (R3 `snapsShownOffset`)

**2. A costly sting can make the numeral go *up*, and a Feast at 14 snaps dips it below the real count.**
- **Where:**
  - `Snap/Scene/BogEconomy.swift:104` adds the sting's nominal cost.
  - `:150` overwrites `crackCost`, and `BogScene.swift:555` calls `crack` once per stinger.
  - `BogScene.swift:530-531` flies `r.snapsBack` glyphs, and `BiteReport.snapsBack` is nominal (`TrapSession.swift:1053`).
  - Core clamps the result to 0…14 (`TrapSession.swift:1074`).
- **What happens:**
  - With 1 snap left, a bite with a wasp in it takes Core to 0. The offset adds +2, so the HUD shows **2** (it showed 1)
    for about 0.15 s, then 0.
  - A bee and a wasp in one bite keep only the last cost, so part of the drop shows early.
  - At 14 snaps, a 5-bug Feast clamps to 14, but 2 glyphs fly (offset −2). The numeral reads 12, 13, 14.
- **Minimal fix:**
  - Sum the costs in `crack` (`crackCost += cost`, reset when `crackAge` ends).
  - In `handle`, clamp both the flight count and the crack total to the change that really happened. Pass
    `before.snapsLeft` (the previous snapshot) and compare it with the new one.

**3. In the lesson's TRIPLE step the numeral drops 10 → 9 → 10 while a "+1" glyph flies in.**
- **Where:**
  - `TrapSession.swift:1072`: with `snapsRunOut == false`, `snapsLeft` never changes, but `snapsBack` is still
    reported (`:1053`).
  - `BogScene.swift:531` flies it anyway.
  - The lesson shows the snaps row from step 3 (`LessonScript.swift:355`).
- **What happens:** the step that sets up "Big bites earn them back" shows a big bite *taking* a snap for about 0.6 s.
  Home's attract session flies glyphs the same way (#7).
- **Minimal fix:** Core reports `snapsBack: options.snapsRunOut ? back : 0`, or the Scene skips `fly` and `crack` when
  the run doesn't spend snaps. The real-change clamp from #2 covers this too.

**4. (sub) For one frame on every Feast or costly sting, the numeral shows Core's raw count.**
- **Where:**
  - `GameController.swift:296` publishes the HUD from inside `advance`, and `:1085` reads `scene.snapsShownOffset`.
  - The scene only handles that frame's events afterwards, in `draw` (`BogScene.swift:271`, `:286`, `:302`).
  - The publish is marked urgent (`:1095-1096`).
- **What happens:** a Feast from 3 shows 3 → 5 → 3 → 4 → 5. A sting drops the number one frame early, jumps back, and
  then drops after the crack. That defeats the "crack first, then the number" rule.
- **Minimal fix:** republish the HUD after the scene has handled the frame's events (the scene calls the driver back
  at the end of `draw`, or from `didFinishUpdate`).

**5. The App's own crimson row flash fires on Sprout's free sting, where nothing is lost.**
- **Where:**
  - `PlayHUD.swift:139-142` flashes on any rise of `v.stings`.
  - `GameController.swift:268-269` counts every `stung`, including `cost == 0`.
- **What happens:** the free first bee says "Bees cost a snap!" and Feel plays the soft "oops", but the row flashes
  "lost" red.
- **Minimal fix:** count only `stung` with `cost > 0` in `stings`, or flash on `values.rowFlashing` alone (the
  Scene's flash already skips cost 0 at `BogScene.swift:555`).

**6. (sub) Crack, droop and Feast glyphs all land on slot 0, not on the slot that changes.**
- **Where:** `Layout.swift:414-417`. `anchor(snapsLeft:)` ignores its argument and returns `glyphCenter(0)`. The HUD
  empties slot `shown − 1` (`PlayHUD.swift:337`).
- **What happens:** the cracked or drooping glyph appears over the top-left glyph, which stays whole. The slot that
  really empties can be about 200 pt away on the lower row.
- **Minimal fix:** report `glyphCenter(snapsLeft − 1)` as the anchor. `PlayLayer` already re-reports it on every
  `snapsLeft` change (`PlayHUD.swift:136-138`). Then centre the Scene's row flash on the row, not "90 pt right".

**7. (sub) Home shows play-HUD economy effects in an empty corner.**
- **Where:**
  - The attract session has `stingCosts: true` (`TrapSession.swift:38`).
  - `advanceHome` hands its events to the scene (`GameController.swift:574-580`).
  - The scene cracks or flies at `snapsAnchor`, which on Home is the last play HUD point or the fallback
    (`BogScene.swift:124-128`).
- **What happens:** a hinge chomp over a bee on Home shows a crimson 300 × 96 flash and a cracked glyph with no row
  behind them. A Home Feast flies glyphs there.
- **Minimal fix:** add a `showsEconomy` flag to the scene, false on Home, that skips `fly`, `crack` and `wilt`.

**8. (sub) A wilt snaps the drooped trap upright in one frame.**
- **Where:**
  - `BogJaws.swift:296`: `droop = smoothstep(0.7, 1, hunger)`, with no easing.
  - Hunger goes 1 → 0 at the wilt (`TrapSession.swift:398`).
- **What happens:** on the frame "Too slow! −1 snap" pops, all of these jump back at once, with no slam to cover it:
  the lobes from y 0.95 to 1, the grey veil, and the 20° cilia lean.
- **Minimal fix:** ease `droop` like `tiredLevel` (`BogMath.approach`: fast rise, about 0.6 s release).

**9. (sub) The sting "lost" blip sounds about 0.26 s after the numeral drops.**
- **Where:**
  - The numeral drops at 0.05 + `crackLead` 0.15 = 0.20 s (`BogEconomy.swift:34`).
  - Feel's `stingVerdictAt` is 0.46 s for a bee (`FeelSoundBook.swift:443-446`, `FeedbackDirector.swift:334-343`).
- **What happens:** the number drops, and the "lost" sound comes a quarter of a second later.
- **Minimal fix:** use one time for both: either raise `crackLead` to about 0.41, or move the blip earlier.

### Hunger HUD

**10. A dry snap, a miss or a bee-only bite switches the hunger warning off, though the wilt is still coming.**
- **Where:** `GameController.swift:259-262` clears `hungryOn` on any `.snapped`. Core keeps `hungrySent` and the
  hunger level (`TrapSession.swift:997-1001` only resets on a catch). The `.hungry` hint stays (`:1090`).
- **What happens:**
  - "Hungry… bite!" stays on the plate.
  - The draining glyph's crimson pulse and the red ticking numeral stop (`PlayHUD.swift:331-343`).
  - The wilt still lands within 3 s.
  - The player reads the calmer row as "fed".
- **Minimal fix:** clear `hungryOn` only on a `snapped` whose `report.caught` is not empty, or on `wilted`. A simpler
  alternative is `values.hungry = s.hint == .hungry`.

### Sprout run 1, persistence, Game Center

**11. Sprout run 1 is missed if the player's first run is a Daily.**
- **Where:** `AppRules.swift:178-181` (`runs <= 0`). `ProgressRules.record` counts Daily runs too
  (`ProgressStore.swift:313-314`).
- **What happens:** Skip the lesson (or finish it with Home), then play the Daily Bog. The first Feed run then has
  `runs == 1`, so it wilts and charges the first bee.
- **Minimal fix:** decide Sprout run 1 on a Feed-only count (a new `feedRuns`, decoded tolerantly), or "no Feed run
  recorded yet".
- **Not a bug, noted:** a Restart before anything is caught keeps the run-1 options, because the abandoned run isn't
  recorded. This is intended.

**12. A scored Daily that ends after UTC midnight never reaches the leaderboard, and nothing says so.**
- **Where:** `GameCenterManager.swift:121-125` and `:184-188`.
- **What happens:** a run started at 23:58 UTC is filed for the day it started on, and then dropped as stale in
  `flush`. The store keeps the score; Game Center does not.
- **Minimal fix:** accept day == today − 1 within a short grace (for example 15 minutes after midnight), or accept
  it silently as policy and document it in the review notes.

**13. Achievements are reported twice at once, and the "reported" set is per device, not per player.**
- **Where:**
  - `GameCenterManager.swift:86` (`queueScore` → `flush`) and `:95` (`unlock` → `flush`): two `GKAchievement.report`
    calls for the same ids, with nothing in flight to stop the second.
  - `:30`: `snap.gc.reported` is not keyed by player.
- **What happens:**
  - Probably harmless (GameKit dedupes completed achievements), but a doubled banner is possible.
  - When a second Game Center account signs in on the same device, it never receives the achievements already earned
    on that device.
- **Minimal fix:** keep an `achievementsInFlight` flag in `flush`. Key both sets by `GKLocalPlayer.local.gamePlayerID`,
  and re-queue everything in `progress.achievements` when the player changes.

### Lifecycle, input, lesson

**14. A stored "has hinge" with no hinge report makes the run unplayable (edge).**
- **Where:**
  - `GameController.swift:332`: `hingeSeen` alone picks `.hinge`.
  - `:304`: taps snap only with `input == .touch`.
  - `HingeTrapSource.input` returns an open trap until the first report.
- **What happens:** if `onHingeChange` delivers nothing after launch (an iOS hiccup, or a restored backup on another
  Duo-shaped device), the trap can't snap, and taps are ignored. Skip and the menu still work.
- **Minimal fix:** choose `.hinge` only once `hinge.hasHinge` is true. Alternatively, accept taps while
  `!hinge.hasHinge`.

**15. Lesson step 1 never tells a player who is too flat what to do.**
- **Where:** `LessonScript.swift:54` (`poseRange` 125…176) and `:126-139`.
- **What happens:** a Duo held at 177–180° (flat, or nearly) shows "Hold it open like a book." for ever. The player
  *is* holding it open, and nothing says "bend it". Skip is the only way on.
- **Minimal fix:** while `angle > 176`, set the warning "Bend it a little, like a book" (Core's `bendALittle` copy).

**16. (sub, QA-1 #4 leftover) Two big bites close together can still click.**
- **Where:**
  - A stolen voice is replaced outright (`FeelSynth.swift:1246`, `:1328`).
  - Protection covers only the current drain (`:1122`).
- **What happens:**
  - Two Feasts 0.45 s apart (touch re-arm), each with about 80 commands plus the bed, exceed 128 voices.
  - The first bite's ringing sparkle is cut dead.
  - A bite whose commands are split across two render callbacks can steal from its own first half.
- **Minimal fix:** fade a stolen voice over 2–5 ms first. Protect voices by a short time window (about 20 ms) instead
  of by drain.

**17. Real-launch pause and resume of the `SpriteView` has never run on CI. This is a risk to confirm.**
- **Where:** `RootView.swift:214-218`. `sceneIdle` returns false for every demo launch, so every CI run keeps the
  scene drawing.
- **What could happen:** the menu, closing-card, cover and pose resumes all depend on SwiftUI pushing
  `SpriteView(isPaused:)` changes through to the `SKView`. QA-1 #1 was exactly this blind spot.
- **Minimal fix:** add a demo key (for example `realPause=1`) that leaves `sceneIdle` honest. Add a `duo.sh` step:
  open the menu, Resume, and check that `SNAP-T frame` lines and session time advance. Alternatively, test it by hand
  on the founder's TestFlight Duo.

### Performance (no blockers)

**18. `HUDLayout.make` is rebuilt on every HUD publish.**
- **Where:**
  - `PlayHUD.swift:20`, and again at `:134` and `:137`.
  - `Layout.swift:313`: `trapOutline()` makes about 3,300 points (720 ellipse samples plus 2 × `TrapArt.teeth`, each
    with a 481-sample margin walk).
  - Then about 20 `room()` scans of roughly 2,300 points each.
- **What happens:** this runs at up to 15 Hz plus every urgent publish, about 0.3–1 ms of main-thread work each time.
  It is harmless today, and it shares the frame with SpriteKit at 120 Hz.
- **Minimal fix:** memoise `HUDLayout` per `AppCanvas` (it is `Equatable`) in a static one-entry cache.

**19. (sub) Small per-frame allocations.**
- **Where:**
  - `BogScene.swift:380-381`: a `[Int: BugState]` dictionary on every frame that has events, which is most frames.
  - `BogScene.swift:319`: an array literal every frame.
  - `BogJaws.swift:320`: one `UIColor` per frame.
  - `BogEconomy.swift:129`: when all 8 flight slots are busy, a live flight is overwritten, so the numeral jumps up
    one glyph early.
- **What happens:** nothing a player would notice today.
- **Minimal fix:** reuse one dictionary. For the flights, give the pool 12 slots.
- **Checked by the sub-reviewer:**
  - no texture rebuilds per frame: the hunger droop, dusk and night light, and the closed trap are transforms and
    alphas only;
  - the glyph images are cached;
  - the hunger `TimelineView` runs at 30 Hz only while hungry;
  - Home renders at 60 fps and pauses whenever it isn't on screen.

**20. Home and play never run twice (checked; not a bug).**
- **What happens:** nothing is played twice. Home calls only `feedback.homeTrap` and play calls only
  `feedback.handle` (`GameController.swift:254`, `:576`), and there is one director, one scene, one `HingeReader`
  (`RootView.swift:45`), and the display-link ticker only runs while there is no scene (`:622-625`).
- This is listed so the next audit doesn't repeat the check. No action.

**21. Info.plist lists `PortraitUpsideDown`; the comments say "never upside down".**
- **Where:** `project.yml` (`UISupportedInterfaceOrientations`) and `OrientationLock.swift:11`.
- **What happens:** nothing in practice: the run-time mask never returns it, and iOS refuses upside down for
  full-screen apps.
- **Minimal fix:** drop it from the plist, or fix the comment. This is cosmetic and doesn't affect App Review.

---

## Release, App Review, privacy: checked, no findings
- **Demo and debug code:**
  - `DemoMode.current` is nil in Release (`DemoMode.swift:163-177`), so `screen=badges`, `icon`, presets and freezes
    can't be reached.
  - `BadgeExport` and `IconExport` are compiled in, but nothing calls them.
- **Logs:**
  - `AppTrace.enabled` is false and `t()` is empty in Release.
  - `FeelDemoLog` and `FeelHingeLog` are false.
  - The one `print` is behind `#if DEBUG` (`GameController.swift:510-516`).
  - os `Logger` writes only `.error`s (audio and haptics failures).
- **Diagnostics:** the Settings hinge-angle line shows only on TestFlight with a hinge (`SettingsView.swift:115`).
- **iOS 18 without the hinge API:**
  - `onHingeChange` and `reservedRegions(.division)` are behind `#available(iOS 27.1, *)` (`HingeReader.swift:31`,
    `RootView.swift:186`).
  - Every other API used is iOS ≤ 18: `onScrollGeometryChange` is 18, `onChange` with two parameters is 17.
  - The only `fatalError` is `init(coder:)`, which is never used. There are no force unwraps or `try!`.
- **Private API:** none (no `value(forKey:)`, `NSSelectorFromString` or `dlopen`).
- **Usage strings:** none are needed (no camera, microphone, motion or tracking).
- **Info.plist:** `ITSAppUsesNonExemptEncryption` is false; the Game Center entitlement is present.
- **Privacy manifest:** `PrivacyInfo.xcprivacy` declares UserDefaults CA92.1 and SystemBootTime 35F9.1
  (`CACurrentMediaTime`), no tracking and no collected data. No file-timestamp or disk-space APIs are used.
- **Game Center while signed out:** scores and achievements are queued and nothing blocks. The Settings button presents
  the stored sign-in view controller, or shows the toast "Sign in to Game Center in Settings". The access point stays
  off.
- **Achievements unlock once:** `ProgressRules.record` passes `alreadyEarned`, and `outcome.newAchievements` only holds
  new ids. (On the Game Center side, see #13.)
- **The Daily:**
  - one scored try (`dailyAttempted` is set at start);
  - Restart and Again become practice;
  - clock-back protection holds;
  - Sprout's 12 snaps, no-wilt and free bee never apply to it (`AppRules.swift:171-181`).
- **Bug Book counts:** finished runs use Core's counts. Abandoned, killed or tired-moment runs use `RunTally`, which is
  fed by `finishHeadless` too, so nothing is counted twice or lost.

## Checked and found correct (R2/R3 paths)
- **The hunger clock:**
  - it starts on the first in-trap landing of a catchable bug;
  - it ticks only while the session steps, so it stops in menus, the closing pause, pose and cover cards, the
    background and Results;
  - it never ticks while tired, in the lesson or attract, or in Sprout run 1;
  - `hungry` fires once per cycle.
- **Stinger bites:**
  - they score ×1 and refund nothing (no Feast or lucky event), and the chain breaks;
  - the free first sting is spent once per session (`freeStingUsed`) and its `stung` events carry `cost: 0`;
  - the "Bees cost a snap!" plate shows only in Feed and Daily (`AppRules.swift:185-191`).
- **`snapsShownOffset` across Restart, Home, Again and the lesson:** it goes back to 0. `start()` calls `scene.reset()`
  before its forced `publishHUD` (`GameController.swift:902-904`). `goHome()` resets through `makeHomeSession` and
  publishes empty HUD values. The offset runs on session time, so pauses freeze it and it never drifts.
- **The closing pause:**
  - it lifts from hinge reports (`GameController.swift:490`; the gate updates from `ingest` once frames stop,
    `HingeTrapSource.swift:135-136`);
  - the menu and Resume work over the closing card;
  - Restart while half shut re-pauses at once, because the gate's latch survives `reset`;
  - the tired moment steps through closing and pose pauses, and the watchdog finishes it when no frames are drawn.
- **Resume:** every resume, activation, start and Home resets the hinge detector, and touch is reset when a pause
  begins. Stale hinge and touch triggers (older than 0.25 s) are dropped.
- **The lesson:**
  - Skip is on every step;
  - the pose step falls back after 3 s with no hinge reading;
  - step 2 passes on any snap with a fly in the trap;
  - every step refills its cast after a miss, spook or sting;
  - only Skip is hit-testable;
  - touch numbering is 1–4;
  - I found no soft-lock other than #15's copy gap.

## QA-1 findings: status

| # | QA-1 finding | Status | Evidence |
|---|---|---|---|
| 1 | P0: the closing pause never lifts | **Fixed** | `GameController.swift:490` (`checkClosing` from `hingeSample`); the gate fed from `ingest` (`HingeTrapSource.swift:134-136`). See #17 for the CI blind spot that remains. |
| 2 | P1: a stale hinge snap fires at t = 0 | **Fixed** | `hinge.reset` in `start()` (`:894`) and `goHome()` (`:730`); 0.25 s stale drop (`HingeTrapSource.swift:154-160`) |
| 3 | P1: the lesson doesn't sip, isn't "any speed", has no Skip | **Fixed** | Drops targeted (`AppRules.swift:377-401`, claims at `GameController.swift:233-247`); any snap passes step 2 (`LessonScript.swift:142-150`); Skip on every step (`:101`) |
| 4 | P1: synth voices run out | **Partly fixed** | 128 voices, oldest-stamp steal, current drain protected, rings end at 5τ, light crunches (`FeelSynth.swift:489`, `:1223-1248`); steals still cut with no fade (#16) |
| 5 | Creep after re-arm, flat bend | **Fixed** | `SnapDetector.swift:24-26`, `:188-190`; `FeelCreepGuard` veto (`HingeTrapSource.swift:161-171`) |
| 6 | An attempt never expires in a drift | **Fixed** | `SnapDetector.swift:158-160` |
| 7 | A touch tap before a pause bites after it | **Fixed** | `touch.reset()` when a pause begins (`GameController.swift:1116`); stale bite drop (`TouchTrapSource.swift:74-79`) |
| 8 | Mid-run hinge arrival: `hingeTiming` false | **Fixed** | `GameController.swift:348` |
| 9 | Leaving in the tired moment files a partial | **Fixed** | `GameController.swift:935-939` (finished headless, recorded as finished). Staying on the menu now ends in Results via the watchdog, which is fine. |
| 10 | Lesson step 1 waits for ever with no hinge | **Fixed** | `LessonScript.swift:132-138` |
| 11 | The lesson card swallows taps | **Fixed** | `PlayHUD.swift:661` (Skip overlay is the only hit target) |
| 12 | A protected bug's escape isn't a spare | **Fixed** | `TrapSession.swift:901` |
| 13 | Audio never heals in menus | **Fixed** (sub) | `FeedbackDirector.swift:555-560` |
| 14 | The watchdog never idles the engines | **Fixed** (sub) | `FeedbackDirector.swift:613` |
| 15 | No buzz mixer hysteresis | **Fixed** (sub) | `FeelSoundBook.swift:979`, `:1006-1007` |
| 16 | NaN latch | **Fixed** (sub) | `FeelSynth.swift:1135`, `:1158-1210`, plus a non-finite output reset at `:740-744` |
| 17 | Rebuild churn during a call | **Fixed** (sub) | `FeelAudioEngine.swift:20-30`, `:204`, `:363-366` |
| 18 | Haptic players per cue | **Fixed** (sub) | One merged pattern per frame (`FeedbackDirector.swift:346-347`, `:537-544`) |
| 19 | Halo, glow and bob strobe | **Fixed** (sub) | Separate `flapPhase` (`BogBugs.swift:146-147`, `:319`, `:407`) |
| 20 | Shake slivers at the edges | **Fixed** (sub) | 24 pt bleed, shake clamped (`BogScene.swift:225-227`, `:367`) |
| 21 | A mid-air catch drops in one frame | **Fixed** (sub) | `BogBugs.swift:232-237`, `:388` |
| 22 | The pop pool recycles live pops | **Fixed** (sub) | 20 slots, oldest recycled (`BogEffects.swift:416`, `:520-525`) |
| 23 | The callout stack runs off the bottom | **Fixed** (sub) | `BogScene.swift:503-505`, `:621` |
| 24 | Nectar not warmed | **Fixed** (sub) | `BogTextures.swift:378-381` |
| — | A width change mid-run (Scene P2) | **Fixed** | Deferred to the next session (`GameController.swift:392`) |
