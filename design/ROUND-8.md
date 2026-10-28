# Round 8: the phone IS the trap (brief)

The founder tested TestFlight build 1 on a real Duo (28 Oct 2026). Their verdict, in their words:
- "absolute shit and garbage. terrible UI and UX."
- "the flytrap shuts much before the duo lid".
- "in my mind if the phone is open the flytrap is also open, if phone is closed then flytrap is also closed."
- "this feels super easy to play, which can bore people out very quickly."

The critic panel scored design 8. It was wrong; the founder's hands are the only judge. R8 rebuilds the core verb.

## 1. The new hinge model (one rule: the lid is the jaw)
- **Open phone = open trap; closed phone = closed trap.** The trap closes only when the phone closes. Nothing on the
  inner screen ever draws the trap shutting while the phone is open. With hinge input, the on-screen lobes never
  animate shut.
- **θ** is the hinge angle (180 = flat). The **open reference** is as now: the max θ over 0.6 s. This is where the
  player holds the book, typically 120–170°.
- **Armed** means the trap is open: θ ≥ `Tuning.armAngle` (100°).
- **closure** = clamp(reference − θ, 0, reference) in degrees. It is continuous and drives the bugs' fear and the
  Scene's closing cues.
- **The bite** (the `SnapTrigger`) fires once per close, while armed, at the moment the phone **shuts**: θ ≤
  `Tuning.shutAngle` (25°) or `DeviceHinge.status == .closed`, whichever comes first.
  - A partial close, however deep, is never a bite. Opening back up from 60° does nothing but scare bugs.
  - `duration` = the time from the close's start (closure first passing `Tuning.closeStart`, 8°, on this close) to
    the shut. It is the closing speed.
- **Re-arm:** θ ≥ armAngle again.
- **Bugs during the close:**
  - Every bug in the trap feels the closure. Once closure passes its startle depth (by species: nervy flies at about
    12°, ants and beetles at about 45°), it begins to flee after its reaction time.
  - A bug still in the trap at the shut is caught.
  - **A fast, decisive slam** (≤ 0.3 s from the book to shut) catches the sitters. **A slow, hesitant close** (≥ 1 s)
    loses the flies and gets only the slow ones.
  - Speed is the skill.
- **Shut = digesting.** While the phone is closed after a bite, the session clock is frozen: no spawns, no hunger.
  - iOS moves the app to the outer display. The outer display shows the closed trap from outside, with the result: "CHOMP! 4 bugs · +360", the caught bugs as bumps, and a sting or dry message.
  - The heavy haptic and the CHOMP sound fire at the shut moment, when the lid meets.
- **Reopen:** the inner screen shows the trap reopening, with the remains, a juice stain and the score pop. Bugs come back
  as it opens.
- **The old "closing pause"** (paused under 50°) is removed. Closed is not a pause; it's the bite, and then the clock is
  frozen. The pause menu is only the pause button.
- **Touch (iPhones with no hinge):** a tap is a bite with a 0.12 s duration, and only there does the Scene play its own
  shut animation.

### 1b. Binding founder rules (from Hush, 28 Oct). These override the numbers above.
- **Literal mapping.** Any opening means open: a phone at 90° is open. Arm at θ ≥ 35°. The bite fires at θ ≤ 15–20° or at
  `.closed`. Re-arm at ≥ 35°.
- **No pose demands, ever.** Flat, laptop and any angle all play. The too-flat rule and its prompt are gone.
- **Every round starts closed.** If the phone is open at Play, the game shows "Close the phone to start"
  (`TrapSnapshot.waitingForClose`). Opening it then opens the trap.
- **Copy:** say "phone", never "lid". The first session holds about 3 ideas, with no forced tutorial gate.
- **The phone fallback is first-class:** a tap bites, nothing gets stuck, and the copy says "Tap to snap".

## 2. Difficulty: it must not be easy
These are targets for `tools/balance-sim.js` and BalanceTests. The sim must model the new close: close-time
distributions by skill:
- novice 0.6–1.1 s;
- casual 0.35–0.65 s;
- expert 0.2–0.35 s.

It must also model the reopen time (0.4–0.8 s, during which the clock is frozen until armed).

**Run lengths:**
- **novice:** the median run ends at **60–100 s**, through mistakes (empty bites, stings, starving);
- **casual:** 2–3 min;
- **expert:** 4–6 min.

Nobody survives full night without near-perfect play.

**Levers, the Core's call:**
- fewer snaps (the start and the max);
- faster hunger from noon on;
- shorter lingers as the waves go on;
- flies that startle earlier;
- bees mixed into crowds from wave 3 (a bee sits among the bugs, so you must wait for it to leave);
- wasps from dusk;
- a dry bite costs more;
- the crowd refund only at 3+;
- the chain broken by any miss.

**The skill readout:** each bite's catch ratio (caught ÷ bugs in the trap at the close's start) is reported, and the
best players see 90%+.

## 3. UI/UX (the founder's answers, 28 Oct)
The worst problems: **"Menus feel cheap"** and **"Unclear what to do"**.
- **Premium menus:**
  - Home, Results, Garden, goals and Settings are rebuilt to look like a crafted game rather than a template;
  - illustrated, with the bog as a living backdrop;
  - one strong focal action per screen;
  - big custom type and real art-directed cards, not stacked rounded rectangles;
  - fewer words;
  - motion on entry.
- **Clarity:**
  - the first-run path is Levels 1–5, which teach one idea each and replace the lesson;
  - the hints say one short thing at the right moment;
  - every bite's result says plainly what was good or bad.

## 4. Levels and Endless (the founder chose "both")
**Levels:** 30 hand-made levels in 3 worlds:
- **Morning Bog**, levels 1–10, which teach;
- **Dusk**, 11–20;
- **Night**, 21–30.

**Each level:**
- a scripted bug set (waves, species, where they land, bees, wasps);
- one clear goal, e.g. "Catch 3 flies", "Catch 5 without biting a bee", "One bite, 4 bugs", "Catch the moth before it
  leaves" or "6 bites, 12 bugs";
- a bite limit and/or a time limit;
- 1–3 stars, for the bites used or the catch ratio.

Levels unlock in order, and the next world unlocks at 20 stars.

**Teaching order:**
1. close the phone on one sitting fly;
2. close fast, because flies flee a slow close;
3. wait for two;
4. a bee: wait until it leaves;
5. a crowd of three for the bonus.

After that it's new species and twists.

**Endless** is the arcade run of §2 (Feed and Daily). Zen stays.

The contract is `RunMode.level(Int)`, which Core adds. Core owns `Snap/Core/Levels.swift`:
- `LevelSpec`: id, world, title, goalText, script, bite and time limits, star rules;
- `LevelBook.all`;
- `LevelBook.evaluate(_ result: RunResult, _ level: LevelSpec) -> LevelOutcome`, where `LevelOutcome` holds the
  stars, whether it passed, and the line of text;
- `SessionOptions.for(.level(id))`.

App owns the level select (a world map), the level intro card, the level results with stars, and the progress
persistence.

## Owners
- **Core + Input + CI hinge checks:**
  - `Snap/Core/*`, `Snap/Input/*`, `SnapTests/CoreTests.swift`, `BalanceTests.swift`, `InputTests` (if any),
    `tools/balance-sim.js`, `ci/duo.sh`;
  - `Snap/Shared/Contracts.swift`, additively where possible.

  Implement §1 (the SnapDetector rule, bug fear from continuous closure, the frozen clock while shut) and §2
  (difficulty), and remove the closing pause from Input.

  Rewrite the duo.sh hinge checks:
  - **BITE:** 150 → 5 in about 0.3 s, then a snapped event with caught ≥ 1;
  - **SLOW-CLOSE:** 150 → 5 over 2.5 s, then fewer caught than a fast close on the same seed, or escapes ≥ 1;
  - **NO-BITE-DEEP:** 150 → 60 → 150, then no snapped event;
  - **REOPEN:** rearmed after the reopen, and the clock frozen while shut;
  - **COVER:** a screenshot while shut.

  Keep the log prefixes `SNAP-T` and `SNAP-H`, and document new log lines.
- **Scene:**
  - `Snap/Scene/*`, `SnapTests/SceneTests.swift`;
  - with hinge input, the jaws never animate shut on the inner screen (`BogJaws`);
  - the closing cues follow closure continuously: cilia lean in, the rim shadow deepens, light dims at the edges,
    bugs panic;
  - on reopen, the digest: remains, the juice stain, the "+N" pop;
  - touch input keeps the shut animation.
- **App, UI and Feel:**
  - `Snap/App/*`, `Snap/UI/*`, `Snap/Feedback/*`, `SnapTests/AppTests.swift`, `FeelTests`;
  - the outer-display CHOMP card (the closed trap, the result, a bump per bug);
  - pause semantics as in §1, with demo keys for CI (a shut screen state);
  - the lesson rewritten: "Hold it open like a book" → "Bugs are landing" → "Now shut it, fast!" → "Open it again";
  - the haptic and CHOMP at the shut moment;
  - the UI simplification (§3).

## Rules
- Only your own files.
- Re-read every edit twice; there's no local Xcode, and CI compiles.
- Keep switches exhaustive.
- Never put a rethrowing key-path call inside `#expect`. Use `CGFloat.nan`. Never shadow a static with a local.
  Compare floats with a tolerance.
- Delete tests of the removed behaviour (22° partial snaps, the closing pause) rather than bending them.
- Don't commit or push.
- Notes go in `design/notes/<module>-R8.md`, with every new or changed API and log line at the top.
