# Feel R6 hand-off (Feedback; Input unchanged; the icon's #18)

*Feel engineer, 28 Oct 2026. Not compiled locally (no Swift on this host). Every touched file had two read-throughs
for types, exhaustive switches (the new `RunMode` switch in `FeelSoundBook.isZen` lists all five cases), locals that
shadow a static (none; the haptic's `sting`/`burp` locals were renamed), `#expect` captures and `.nan` (always
`Double.nan`/`Float.nan`). CI is the compiler. Nothing committed.*

## API for the App (call these)
| Call | When | What plays |
|---|---|---|
| `FeedbackDirector.shared.goalCompleted(bonus: Bool = false)` | a goal ticks (live toast, Results); `bonus: true` when three complete at once | a checkbox tick + "ding-ding" G6 → C7 (bonus: a third note to E7 and a shimmer), two keen taps (bonus: three) |
| `FeedbackDirector.shared.varietyUnlocked(after: Double = 0)` | a new trap variety unlocks | a ~1.4 s fanfare: "ta-ta-taaa" G5 G5 C6, a C major swell, a chime run, glints; a tap per call and a swell |
| `FeedbackDirector.shared.zen = FeedbackDirector.wantsZen(mode)` | **every** run start (it must go back to false for Feed, Daily, lesson and attract) | the gentle Zen bed, and no hunger or warning cues |

- **Call `goalCompleted` after `handle(_:telemetry:)`** for the frame whose events completed the goal. The director
  remembers the last bite. When that frame had one, the chime waits until the bite's sounds are over
  (`FeelSoundBook.goalDelay`):
  - 0.62 s (`goalAfterBite`) after a plain bite, past the chain chime and the Feast pops;
  - 1.52 s (`feastChompLength`) after a FEAST CHOMP, past the burp.
  With no recent bite it plays at once. If the toast should appear with the chime, delay it by the same amount.
- `varietyUnlocked(after:)` clamps to 0…2 s. If a rank-up's `celebrate()` plays in the same moment, pass about 0.8.
- **Zen is a director property, not read from the events.** Neither `TrapTelemetry` nor `TrapEvent` carries the
  mode, so the App is the one source. Home's title trap ignores it.

## The FEAST CHOMP (ROUND-6 decision 5, SCORE-R5 D4 #1)
- **Who gets it:** `FeelSoundBook.isFeastChomp(_ report: BiteReport)` is true when the bite caught ≥ 5
  (`feastChompCount` = `Tuning.bigFeastCount`) or its `chainMultiplier` ≥ 4 (`feastChompChain`), and caught ≥ 1. A
  3–4 bug Feast keeps the plain CHOMP and the Feast sparkle, as before. **Scene: use the same rule** for the hit-stop,
  banner and gulp (or call this helper), so the sound and the picture agree.
- **The sound, `FeelSoundBook.feastChomp(caught:dice:)`**, in order:
  1. the plain CHOMP's slam at 0;
  2. a **deeper body** under it: a sub "thoom" 64 → 30 Hz (an 8-harmonic stack so a phone speaker carries it) and a
     dark low-passed chest;
  3. after the **80 ms FEAST hit-stop** (`feastHitStop`, vs 50 ms), the squelch;
  4. the **crunch cascade**: one full crunch per caught bug (up to 8, `FeedbackDirector.feastFullCrunches`),
     `cascadeSpacing` 38 ms apart from 88 ms (`cascadeDelay(index:)`), the shell ring rising 6 % per bug. The
     director passes `crunch(..., cascade: true)` per `bugCaught`;
  5. at `feastStingAt` 0.74 s, after the sparkle, the chain chime and the snaps' pops, the **sting**
     (`feastSting`): a marimba run C6–E6–G6–C7 with a glint, over a soft "aah" choir (C5 E5 G5 C6 with slow vibrato
     and a breathy 1.1 kHz band);
  6. at `burpAt` 1.12 s, a cute **burp** (`burp`): a raspy 210 → 140 Hz belch, a puff, a lip "pop" and a glint. It
     replaces the plain gulp.
- **Under the master peak.** The extra body adds at most a quarter to the slam's summed gain (tested against the
  plain CHOMP for 1, 5, 8 and 12 bugs). A whole 8-bug FEAST frame, with the Golden Scarab, the ×5 flare and a new
  best over the full bed and a crowd, is 104 commands (< 128 voices). It renders finite, never above
  `tanh(FeelSynth.ceiling)`, with < 5 % of samples over 0.6 and no dropped voices.
- **The haptic, `FeelHapticBook.feastChomp(caught:)`:**
  - a 1.0 slam and a full-strength clamp through the 80 ms hit-stop;
  - a **second 1.0 slam** as the hit-stop ends (the "double");
  - a 0.32 s full rumble in four fading steps;
  - one keen tap per bug on the cascade;
  - three rising taps on the sting, a round thud on the burp and a tap on its pop.

  It is heavier (energy) and longer than an 8-bug CHOMP, has no curve, and merges into the frame's one pattern.
- New helper `FeelSynthCommand.delayed(by:)` (never before 0) retimes the CHOMP's tail.
- New diagnostics: `feastChomps` (each is also counted in `chomps`).

## Goal chime and variety fanfare
- `FeelSoundBook.goalChime(bonus:delay:dice:)`, `FeelSoundBook.varietyFanfare(delay:dice:)`,
  `FeelHapticBook.goal(at:bonus:)` and `FeelHapticBook.fanfare(at:)`. Both sounds are audible and stay well under the
  CHOMP (peak × 1.3 < the CHOMP's; every voice < 0.2).
- New diagnostics: `goalChimes`, `lastGoalChimeAt`, `fanfares`.

## The Zen bed (`zen = true`)
- **`FeelSoundBook.playBed(..., zen: true)`:**
  - the marimba loop at 0.55 with at most 3 voices (the chain still adds them up to 3);
  - wind, frogs and crickets at 0.75, drips at 0.45;
  - the creep groan at 0.7 (it still tells you the bugs feel it);
  - the master, the buzz layer (a bee's hum is still the choice) and every one-shot unchanged.
- **Kept silent:**
  - `hungry` (the rumble) and `wilted` (the droop);
  - `lastSnap` (the knocks) and `tired` (the yawn);
  - the free sting's "oops" (bees cost nothing in Zen).

  Each is counted in `hushed`. A costly sting's loss blip still plays if Core ever sends one (it would be true).
  The "Bzzt!", the chain's "bwoop" and every CHOMP (including the FEAST) are unchanged.
- `FeelSoundBook.isZen(_:)` (exhaustive over `RunMode`) and `FeedbackDirector.wantsZen(_:)`.

## Icon (SCORE-R5 #18, `Snap/UI/AppIconArt.swift`)
- The two "nostril" dots were the fly's hands on the front lip: dark grey ovals (#575E6B, 18 × 12) with dark drop
  shadows. They are now small (15 × 10), pale grey-blue lit from the upper left (`handLight` #D4DCE6 → `flyLight`
  #9AA5B5), with a faint green shadow (alpha 0.18) and a soft highlight. On the lime margin they read as a highlight,
  not as two holes. Nothing else moved. **Re-export `screen=icon` and eye-check at 29 px.**

## Tests (FeelTests)
- New:
  - `aFeastChompIsABiggerEventThanAnyChomp`: the rule; the body, hit-stop, sting, choir and burp; the impact bound; the
    cascade's timing and rise; `delayed(by:)`.
  - `aWholeFeastFrameStaysUnderTheMasterPeak`
  - `aFeastChompHapticIsHeavierAndLongerThanAnyChomp`
  - `theDirectorPlaysTheFeastChompOnlyForABigBite`
  - `aGoalChimesAfterItsBiteAndANewVarietyGetsAFanfare`: the pure delay, the sounds, the haptics, and the director's
    timing.
  - `zenIsAGentleBedWithNoHungerOrWarnings`: `isZen` over every mode, the bed, a rendered RMS against Feed's, the
    director's hush and back.
- `everyRecipeIsSane` now also covers every new recipe.

## Risks
- **The Scene's hit-stop.** The sound assumes the Scene's FEAST hit-stop is 80 ms. If Scene picks another value,
  change `FeelSoundBook.feastHitStop` (one constant; the haptic follows it).
- **A costly sting inside a FEAST bite.** The loss blip still lands at `numeralDropAt` (0.20 s), which assumes the
  50 ms hit-stop; in a FEAST frame the numeral drops about 30 ms later. That is rare (5+ bugs and a bee) and inaudible
  in practice.
- **The burp on a Duo.** It is tuned for a phone speaker (fundamental about 200 Hz, rasp from the vibrato). If it
  reads as rude rather than cute, lower its gain (0.12) or raise its pitch toward 260 Hz.
- **Goal timing depends on call order.** If the App calls `goalCompleted` before `handle` for the bite frame, the
  chime lands on the CHOMP.
