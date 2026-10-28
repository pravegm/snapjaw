# QA-1: Snapjaw bug audit (27 Oct 2026)

*QA lead. Read-only pass over every Swift file under `Snap/` (about 17.4k lines), checked against GAME-DESIGN, ARCHITECTURE,
Contracts and the R1 hand-offs. The build compiles and the 151 tests pass, so this pass looks only for logic,
lifecycle and state bugs a player would hit. Two sub-reviewers covered `Feedback/` (audio and haptics) and `Scene/`
(SpriteKit). I re-checked their headline claims against the code.*

**Severity**
- **P0** blocks play, loses a run or loses data.
- **P1** clearly wrong behaviour that a player will notice, or that costs them a snap or score.
- **P2** an edge case, a cosmetic problem, or a risk to confirm on a real Duo.

**Summary:** 1 P0, 4 P1, 19 P2. The P0 and the first P1 are both in the pause and resume glue in `GameController`
and `RootView`, not in Core. Core's rules (bite, score, chain, refunds, nectar occupancy, the tired → finished step)
match GAME-DESIGN §5.

---

## P0

### 1. The closing pause never lifts. Every run where the Duo is half closed is stuck.
- **Where:**
  - `Snap/UI/RootView.swift:205-209`: `sceneIdle` returns true when `controller.isClosingPaused`, which pauses the
    `SpriteView`.
  - `Snap/App/GameController.swift:161` and `406-425`: `checkClosing`, the only code that clears `isClosingPaused`,
    runs only from inside `advance()`. `advance()` runs only from `BogScene.update`.
  - Nothing else ever calls `setClosing(false)`. `hingeSample` (383-398) does not check it.
- **What the player sees:**
  - Mid-run, the player closes the Duo past 50° for 0.6 s, for example to rest it. The closing card shows and the
    `SpriteView` pauses, so `advance()` stops and `checkClosing` never runs again.
  - They open it back to 165°. The card stays up.
  - Menu → Resume clears only `.menu`, so `.closing` is still set and the card comes back.
  - The only ways out are Restart or Home, and both file the run as abandoned.
  - This happens in the lesson too.
- **Why CI missed it:** demo runs keep the scene rendering (`sceneIdle` returns false for demo, line 207). So
  `duo.sh` CLOSE-PAUSE passes, but a real launch soft-locks.
- **Minimal fix:** at the end of `GameController.hingeSample(angle:time:)`, add
  `if isClosingPaused, let s = session { checkClosing(now: time, phase: s.snapshot.phase) }`. Hinge reports keep
  arriving while the phone is opened, so the pause lifts at ≥ 120°.
  - Alternative: remove `|| controller.isClosingPaused` from `sceneIdle`. The paused branch of `advance()` already
    avoids stepping.
  - Add an App test that drives `hingeSample` only, with no frames, and checks that the pause lifts.

---

## P1

### 2. A stale hinge snap from a menu fires at t = 0 of the next run, costing a snap (or the scored Daily's first snap).
- **Where:**
  - `Snap/App/GameController.swift:634-689`: `start()` never calls `hinge.reset`. It calls `clearRunPauses()`, which
    removes reasons directly, so `setPause`'s resume reset does not run either.
  - `Snap/Input/HingeTrapSource.swift:48`: `pendingSnap`.
  - `Snap/Input/HingeTrapSource.swift:133`: `input.snap = pendingSnap`.
  - `Snap/Core/SnapDetector.swift:125` and `164`: the detector's own `pending`.
  - `Snap/UI/RootView.swift:208`: the scene is paused while the menu is open.
- **What the player sees:**
  - Hinge reports keep feeding the detector on every screen. Only the play frames and Home's ticker consume a snap.
    On Results, the Bug Book, Settings, the Daily screen and the open pause menu, nothing consumes it.
  - Example: on Results the player claps the Duo, or just shifts their grip by more than 22°. The trigger waits.
    They tap Again, or go Daily → "Play today's bog", or Menu → Restart. The first play frame delivers the trigger:
    a dry snap at t = 0, −1 snap, and on a scored Daily it burns part of the one scored try.
  - Snaps made with the menu open and then Restart fire the same way.
- **Minimal fix:** in `start()`, after `setInput(...)`, add
  `if input == .hinge && hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }`.
  - Belt and braces: `TrapSession.step` could ignore `snap.time` earlier than the session's start, which would need
    the start time passed in.

### 3. First Bite does not teach what it says. Flies never sip, the first snap is not "any speed", and there is no Skip.
- **Where:**
  - `Snap/App/AppRules.swift:199-210`: `lessonSpots` and `lessonSpot`. The targets are fixed fractions of the semi-axes.
  - `Snap/Core/TrapSession.swift:399-404` and `431-432`: a bug sips only if its target is within 1.5 pt of a free
    drop. Core's hand-off says to target `snapshot.nectar[k].position`.
  - `Snap/App/LessonScript.swift:105-111`: the firstSnap step.
  - `Snap/App/LessonScript.swift:74`: `allowsSkip` is false on steps 1–2 of a first run.
- **What the player sees:**
  - Step 2 says "When it's sipping… snap shut!", but the housefly lands and walks forever (infinite linger, no drop).
    It never shows a sip ring. Step 5's bee and step 6's crowd never sip either.
  - GAME-DESIGN §8 says the first snap "can be any speed". In code it is the normal bite rule:
    housefly 0.24 s walking, × 0.6 on the rim.
  - So a cautious first-timer's snap (4° → 22° slower than about 75°/s) whiffs. A creep spooks the fly (nerve 7).
    The fly respawns and the step repeats, with no Skip.
  - The only way out is Pause → Home. `lessonDone` stays false, so the lesson comes back at the next launch.
- **Minimal fix:**
  - Have the controller aim the sip steps at real drops: pass `session.snapshot.nectar[(slot) % count].position` as
    the target, keeping the entry from `lessonSpot`.
  - Pass step 2 on any `snapped` while a fly is in the trap. If it escaped, show the praise "Snap! Quicker catches
    more." and move on. Alternatively, add `SessionOptions.lessonAnySpeed`, used only in step 2.
  - Allow Skip from step 1.

### 4. Big bites run out of synth voices. The best reward sounds are dropped silently and older notes click off.
*Sub-reviewer finding. I confirmed it.*
- **Where:**
  - `Snap/Feedback/FeelSynth.swift:486`: `voiceCount = 64`.
  - `Snap/Feedback/FeelSynth.swift:1162-1177`: stealing picks the highest `age`. `age` only advances after a voice's
    delay has run out, so every voice queued in the same drain has age 0.
  - `Snap/Feedback/FeelSynth.swift:1249`: ring voices hold a slot for up to 6 s.
- **What the player sees:**
  - An 8-bug Feast with a Golden Scarab issues about 76 commands: chomp 13, crunch 4 per bug, feast 12, lucky 16,
    chain 3, plus newBest 4. A 6-bug Feast issues about 68, on top of the marimba voices already playing.
  - `react()` plays events in order, so the ones dropped are the last: the scarab glissando, the chain chime and the
    new-best chime, in the most rewarding bite of the run.
  - Stolen marimba voices cut off with no fade, so they click.
- **Minimal fix:**
  - Set `voiceCount = 128`. Render cost scales with active voices only.
  - End ring voices at about 5τ.
  - Steal by a monotonically increasing start stamp, and never steal a voice started in the current drain. If nothing
    is stealable, drop the incoming command instead.
  - Optionally, cap crunch at 2 commands for bugs past the 4th.

---

## P2

### Snap pipeline

**5. Creep false positive after re-arm, and the flat-start bend.**
- **Where:** `Snap/Core/SnapDetector.swift:135-141` and `175-182`.
- **The cause:** on re-arm both references restart at θ while the hand is still opening. If the reopen overshoots the
  settled rest by more than 6° (for example opening to 172° and settling at 165°), the 3 s creep reference keeps the
  172° peak.
- **What happens:**
  - `creepRef − θ` stays above 6° for more than 0.45 s, so the trap "creeps" with nobody closing it.
  - Reported closure becomes 7°+. Houseflies (nerve 7), mosquitoes and dragonflies (4) and wasps (6) are spooked off
    the nectar, and "Snap it — quick!" shows.
  - The same happens when a player obeys "Bend it a little" from 178° to 168°. A brisk bend of 22° or more is instead
    a real dry snap that costs a snap.
- **Minimal fix:** after a re-arm (and at the first sample of a run), re-seed `slow` to θ on every sample while θ is
  rising and for 0.6 s after the peak. Do the same while `tooFlat` was true in the last 0.6 s. Confirm with the
  `SNAP-H` logs of real Duo reopen strokes before tuning.

**6. A snap attempt never expires during a steady slow drift.**
- **Where:** `Snap/Core/SnapDetector.swift:113-120`.
- **What happens:**
  - `attempt` is cancelled only when c < 2°. A drift faster than about 3.5°/s keeps c = rate × 0.6 s ≥ 2°, so the 4°
    `startTime` can be seconds old.
  - A later, honest quick snap gets `d` = several seconds, and every bug escapes. It would be fair if bugs had been
    spooked, but they may not have been: creep needs creepRef − θ > 6° for 0.45 s.
- **Minimal fix:** re-base `startTime` to the latest 4° crossing whenever c has risen by less than 4° in the last
  0.25 s, or cap the attempt's age at about 0.6 s.

**7. Touch fallback: a tap made just before a pause snaps on the first frame after resume.**
- **Where:**
  - `Snap/Input/TouchTrapSource.swift:56-76`: the snap fires on the first `input(at:)` at or after tap + 0.09 s.
  - `Snap/App/GameController.swift:167-174`: the paused branch never asks the touch source.
- **What happens:** the player taps, then Control Centre or the menu opens within 90 ms. On Resume the bite lands
  immediately, on bugs that have moved.
- **Minimal fix:** call `touch.reset()` in `setPause` when a pause begins.

**8. Mid-run hinge arrival switches to hinge input, but the tally keeps `hingeTiming == false`.**
- **Where:** `Snap/App/GameController.swift:264-269` and `678`.
- **What happens:** on the first launch on a Duo whose first report lags the first frame, `fastestSnap` is 0 for that
  run.
- **Minimal fix:** in `refreshInput`, set `tally.hingeTiming = true` when switching to `.hinge`.

### Pauses, results, lesson

**9. Leaving during the tired moment files an abandoned partial instead of the finished run.**
- **Where:** `Snap/App/GameController.swift:355`, `527` and `708-720`.
- **What happens:**
  - Going to the background during the 2.2 s "tired" moment opens the menu (`isLiveRun` is still true). If the player
    taps Home, `abandonLiveRun` files it with `recordAbandoned`, Results are skipped, and a scored Daily is marked
    `finished = false`.
  - If they stay on the menu instead, the end watchdog finishes the run behind it (`finishIfStuck` ignores pauses).
- **Minimal fix:** in `abandonLiveRun`, if `AppRules.isTired(session.snapshot.phase)`, run the `finishIfStuck` loop
  and `handleFinished(immediate: true)` instead of filing a partial.

**10. Lesson step 1 has no way out when no hinge reading arrives.**
- **Where:**
  - `Snap/App/GameController.swift:616-618`: `hasHinge` is true on a fold-shaped layout even with input `.touch`.
  - `Snap/App/LessonScript.swift:80` and `97-103`: the pose step waits for `angle`, which is nil.
- **What happens:** on the first launch, if `onHingeChange` delivers nothing, step 1 waits forever. Skip is not
  offered (see #3).
- **Minimal fix:** after about 3 s at step 1 with `angle == nil`, enter `.firstSnap` (touch wording), or allow Skip.

**11. The lesson card swallows taps in touch mode.**
- **Where:** `Snap/UI/PlayHUD.swift:67-69`. `LessonCard` has no `.allowsHitTesting(false)`.
- **What happens:** on a phone, taps on the card's area (the HUD page, which covers part of the right lobe) don't
  snap.
- **Minimal fix:** add `.allowsHitTesting(false)` to the card's text block, and keep hit testing only on the Skip
  button.

**12. A protected bug that escapes a slow bite counts as neither stung nor spared.**
- **Where:**
  - `Snap/Core/TrapSession.swift:890-893`: escaped, with `takeOff(b, .escape)`.
  - `Snap/Core/TrapSession.swift:808`: only `.leave` counts as a spare.
- **What happens:** a bee or wasp on the rim while flying has reaction 1.0 × 0.55 × 0.6 = 0.33 s. A slower snap lets
  it escape. It came into the trap and left uneaten, but `beesSpared`, the Bug Book and Friend of Bees don't count it.
- **Minimal fix:** in `takeOff`, count `kind == .escape` for protected bugs that `landedInTrap`, the same as `.leave`.

### Audio and haptics (sub-reviewer, spot-checked)

**13. Audio never self-heals in menus.**
- **Where:**
  - `Snap/Feedback/FeedbackDirector.swift:455`: `if !audioIdle { audio.heal() }`. Menus set `idle = true`, so heal
    never runs there.
  - `FeelAudioEngine.play()` skips its restart while `interrupted`.
- **What happens:** an interruption `.began` with no `.ended`, or a failed restart after a Bluetooth route change,
  leaves Home and the menus silent until the next run or the next activation.
- **Minimal fix:** call `audio.heal()` regardless of `audioIdle`. Heal already guards `!isNapping`.

**14. The watchdog fades the layers but never idles the engines.**
- **Where:** `Snap/Feedback/FeedbackDirector.swift:500-507`.
- **What happens:** `refreshIdle` runs about 0.25 s after the last frame, when `quiet` (> 3 s) is still false, and
  nothing re-checks. The engine renders silence and the looping haptic creep player stays alive, which drains the
  battery.
- **Minimal fix:** call `scheduleIdleCheck()` in the stale branch.

**15. The buzz mixer has no hysteresis at its 8-slot limit.**
- **Where:** `Snap/Feedback/FeelSoundBook.swift:836-864`.
- **What happens:** with 9 or more audible bugs at similar heights, the 8th and 9th bugs swap slots every few frames,
  heard as roughly 0.3 s dips and pan jumps.
- **Minimal fix:** keep the bug already in a slot unless a newcomer is about 1.3× louder.

**16. The NaN latch would be permanent (latent).**
- **Where:** `Snap/Feedback/FeelSynth.swift:721-725` and `1106-1149`.
- **What happens:**
  - `apply(.bed)` doesn't sanitise its fields.
  - `resetFilters()` doesn't reset `bed`, `target` or the oscillator phases. One NaN would then silence the synth for
    the rest of the session.
  - There is no live producer today: every field goes through `clamp01`.
- **Minimal fix:** sanitise every bed field in `apply(.bed)`, and reset `bed`, `target` and the phases in
  `resetFilters()`.

**17. During a call, a rebuild may churn (uncertain).**
- **Where:** `Snap/Feedback/FeelAudioEngine.swift:191-198` and `350-367`.
- **What happens:** heal treats an interruption older than 3 s as stale when `isOtherAudioPlaying` is false. During a
  cellular call with the app active, this can cause a `start` failure every second and a rebuild every 5 s on the
  main thread, which means frame hitches.
- **Minimal fix:** don't count `.cannotStartPlaying` or `.insufficientPriority` toward the rebuild ladder.

**18. Haptic players are built per cue on the main thread.**
- **Where:** `Snap/Feedback/FeelHaptics.swift:463`.
- **What happens:** the bite frame can build about 7 `CHHapticPattern`s and players. This needs profiling on a Duo.
- **Minimal fix (if needed):** merge one frame's cues into one pattern.

### Scene (sub-reviewer, spot-checked)

**19. Flying bugs' halos, glows and bob strobe.** This is clearly visible on every arriving bee.
- **Where:** `Snap/Scene/BogBugs.swift:221`, `307`, `325`, `330-331`, `339` and `342`.
- **The cause:** `ph = n.phase` is meant to be a fixed per-bug offset, but `n.phase` is the wing-flap accumulator. It
  advances about 1.8 rad per frame while the bug flies.
- **What happens:** a bee's protected halo flickers between alpha 0.3 and 0.7 every frame, a flying firefly strobes,
  and fliers jitter ±1.6 pt.
- **Minimal fix:** add a separate `flapPhase` for the wings (reset it in `dress()`) and leave `phase` fixed.

**20. Bite shake shows dark slivers at the screen edges.**
- **Where:** `Snap/Scene/BogScene.swift:158` and `274`.
- **What happens:** the backdrop is exactly scene-sized. The shake (up to 14 pt) outlasts the 3 % punch margin, which
  is gone by 0.25 s. For about 0.4 s after a multi-bug bite, a strip of up to about 6 pt shows along the edges.
- **Minimal fix:** give the backdrop a 20 pt bleed (as `BogLight` does with its 120 pt pad), or clamp the shake to
  the punch margin.

**21. A bug caught mid-air drops and shrinks in one frame.**
- **Where:**
  - `Snap/Scene/BogBugs.swift:223` and `286-287`: drawn lift comes from the current height.
  - `Snap/Core/TrapSession.swift:675`: a caught bug's height is set to 0.
- **What happens:** a grasshopper caught mid-hop jumps down about 14 pt before the squish starts.
- **Minimal fix:** store the last drawn height on the node at the catch and ease it to 0 over the squish.

**22. The score-pop pool (10) recycles live pops.**
- **Where:** `Snap/Scene/BogEffects.swift:404` and `474`.
- **What happens:** one heavy bite emits 7–9 pops. A quick follow-up bite (touch re-arms in 0.45 s) makes the
  previous "+240" vanish mid-rise.
- **Minimal fix:** raise capacity to 20 and recycle the oldest pop.

**23. The callout stack for a low bite runs off the bottom.**
- **Where:** `Snap/Scene/BogScene.swift:378-402`.
- **What happens:** `clampPop` clamps only the anchor, and the lines step down unclamped. With feast, chain and two
  lucky lines, the last line lands at about y = 5.
- **Minimal fix:** count the lines first, then raise the anchor so the last line sits at y ≥ 40.

**24. Nectar textures are not warmed before play.**
- **Where:**
  - `Snap/Scene/BogTextures.swift:269-302`: `warm()` has no `nectar(radius:)` entry.
  - `Snap/Scene/BogSurface.swift:33`: draws the texture on first use.
- **What happens:** up to 5 textures are drawn on the main thread during the first seconds of a run. Small hitches.
- **Minimal fix:** warm radii 12–16 (`Tuning.nectarRadiusMin…Max`).

*(Sub-reviewer also noted, unlikely in practice:)*
- **Where:** `Snap/App/GameController.swift:307-309`.
- **What happens:** a canvas width change mid-run re-lays out the scene while the session keeps its old geometry, so
  the trap moves but the bugs don't, and a full backdrop is rebuilt.
- **This cannot happen on the Duo** (the width stays 952).
- **Minimal fix:** defer width changes to the next session.

---

## Checked and found correct
- **Bite rule and economy.** These match GAME-DESIGN §4–§5 exactly:
  - candidates;
  - the reaction formula;
  - points = sum × count × chain, with the chain applied before the increment;
  - +1 back at ≥ 3 caught and +2 at ≥ 5; scarab +2; ladybird +1;
  - bee −1 and wasp −2, each breaking the chain;
  - a clamp to 0…12;
  - `lastSnap` once;
  - tired after 2.2 s, then finished, with the result set once.
- **Nectar occupancy.** Every exit path calls `freeDrop`: caught, leave, escape, release, tired. Crossers never
  reserve a drop. Retired drops are removed when their sipper leaves, so nothing leaks.
- **Bugs always leave.** Every mode either has a finite linger or a finite path. Only lesson spawns use
  `linger: .infinity`.
- **Bee spares.** These are counted once (`sparedSent`). A released bee is never counted as spared, and the tally and
  Core agree.
- **Wide phones.** Entries, crossers, bog sitters and ant lines all use `geometry.sceneSize`. The trap is centred, and
  the scene uses `layout.size` throughout. The fold band is hidden without a fold.
- **The snap pipeline.**
  - Snap timing uses report times, and the interpolated 4°/22° crossings are correct.
  - A trigger is delivered exactly once (the detector's `pending`, the source's `pendingSnap`, and repeated queries
    for the same frame are all handled).
  - Still-hinge keep-alive runs at 30 Hz with a settle, and reset runs on activation and resume.
  - The closing gate's dwell matures without frames, and resume needs ≥ 120° and not shut.
- **Results are saved exactly once.** The `recorded` flag guards `handleFinished`, `abandonLiveRun` and
  `finishIfStuck`. `record` and `recordAbandoned` clear the background checkpoint, and a kill in the background is
  recovered at the next launch.
- **The Daily** is used up at start (`dailyAttempted`), and Restart and Again become practice. Clock-back protection
  holds. Practice never reaches Game Center. Stale daily scores are dropped before they are flushed.
- **Touch: HUD taps never snap.** The score, chain, snaps, hint, banner, toast and tired banner are not hit-testable,
  and the menu and closing card have full-screen tap catchers. Two-finger taps are deduplicated by the 0.45 s re-arm.
- **Audio, according to the sub-reviewer:**
  - the silent-switch category is applied before start and re-applied when toggled;
  - a nap wakes synchronously for a one-shot, so nothing is lost;
  - interruption, route, config and media-reset handling are all present;
  - buzz slots and the creep groan fade when their sources go away;
  - the render path has no allocations, locks or ARC.
- **Scene, according to the sub-reviewer:**
  - pooled bug nodes are returned when ids vanish;
  - `reset()` on every new run, so ids restarting at 1 inherit nothing;
  - no per-frame paths, textures, labels or actions;
  - no force unwraps;
  - touch coordinates are correct under aspectFill.
