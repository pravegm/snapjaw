# Feel R3 hand-off (Input + Feedback)

*Feel engineer, 28 Oct 2026. Not compiled locally (no Swift on this host); every touched file had two read-throughs for
types, argument order, isolation, exhaustive switches and the CLAUDE.md Swift Testing gotchas. CI is the compiler.
Nothing in `Snap/Input/` changed this round.*

## What changed
| Moment | Detected from | Sound (`FeelSoundBook`) | Haptic (`FeelHapticBook`) |
|---|---|---|---|
| Free first bee ("Bees cost a snap!") | every `stung` of the frame has `cost == 0` | the usual "Bzzt!", then `oops`: a soft scoop up a fifth (G4 → D5), a light D6 marimba and a G6 glint that end high (a warning, nothing lost). No loss blip. | usual sting + `oops` (two light taps, ≤ 0.3) |
| Stinger bite that costs snaps | any `stung` of the frame has `cost ≥ 1` | the "Bzzt!", then `snapLost`: a descending two-note blip (A5 → E5, a wasp's 2 snaps fall to D5), hollow square-ish tone doubled on the marimba, 120 ms apart | `sting(heavy: true)` (firmer tap, deeper wobble, a low thud) + `snapLost` (two falling taps) |
| Chain ×5 | the first `chainUp` with `multiplier ≥ 5` (`flareMultiplier`) since the last break or lower step | `chainFlare`: a C6–E6–G6–C7 chime roll spreading L → R over a soft C major shimmer, two glints; once per climb | `chainFlare` (four rising taps) |
| Chain 8 marimba | `telemetry.chain ≥ 8` | a 5th loop voice: the melody an octave up on a soft chime (`FeelSynth.musicVoiceCount` 5) | — |
| "Too slow! −1 snap" | `wilted` | `wilted` redone as two sad little sighs: a short sagging G4, then a longer E4 → B3 with a wobbly vibrato, a leafy rustle, a falling drip, a low C3 plop. Still under the last-snap knocks. | `wilted`: a soft round tap on sigh 1, three fading steps on sigh 2 (all < the last-snap nudge) |
| Small bites (1–2 bugs) | `snapped` with 1–2 caught | `chomp` adds a "nom" after the 50 ms hit-stop: 230 → 150 Hz, 5 harmonics (the band a phone speaker plays) | rumble floor 0.88 (was 0.84 for 1 bug) + a settle tap at the hit-stop; a big bite still rumbles harder |

## Timing (s after the bite)
- The verdict (blip or oops) is one per frame, after the **last** "Bzzt!" played: `stingVerdictAt` = sting start +
  0.3 (spit) + 0.14 per extra wasp zap + 0.1. A bee alone: 0.46.
- When a sting cost snaps, the chain's "bwoop", the last-snap knocks and the tired yawn wait for the blip to end
  (`afterLoss` = verdict + 0.32).
- The flare: `chainAt` 0.46 + 0.1 = 0.56, after the gulp (0.34), never on the CHOMP's impact.
- After a wilt the last-snap knocks / the yawn wait `afterWiltAt` = `FeelSoundBook.wiltLength` 0.9 s (was 0.7).

## Mix
Every new command's gain ≤ 0.07 (the CHOMP's thump is 0.34). Tests render each new cue alone and require its peak ×
1.3 under a 1-bug CHOMP's; a stinger bite (bee + wasp, blip, bwoop, last snap) and a ×5 Feast (sparkle, chain step,
flare, new best), each over the full bed with 5 marimba voices and 8 buzzers, stay under peak 1.0 with < 2 % of
samples over 0.6 and no dropped voice.

## Tests (FeelTests)
New: `theNewMomentsAreAudibleButNeverDrownTheChomp`, `aStingerBiteAndATopChainBiteNeverClip`,
`aCostlyStingSaysYouLostSomethingAndAFreeOneSaysOops`, `theDirectorJudgesEachStingFrameOnce`,
`theChainFlaresOnceAtTimesFive`, `aSmallBiteStillHasWeight`, `theWiltIsTwoSadLittleSighs`. Updated for the 5th voice
(`musicVoices` 5 at chain ≥ 8, the pentatonic loop test over 5 voices, beds at 5 voices) and the recipe/haptic sanity
lists. New director counters: `lossBlips`, `oopses`, `flares`.

## Assumptions about Core (no `core-R3.md` yet at hand-off)
- `stung(id:species:cost:)` keeps firing on the bite frame for every protected bug in the bite, with `cost` 0 for the
  free first bee (and in the lesson, where `stingCosts` is off: the lesson's bees say "oops", which fits).
- `chainUp(count:multiplier:)` carries the new step's multiplier, reaching 5 at step 8. The flare keys on the
  multiplier, not the count, so a changed step size still works; staying at ×5 never re-flares.
- `wilted(snapsLeft:)` unchanged. If Core adds a separate event for the Sprout toast or the ×5 cap, Feel can move to
  it; today none is needed.

## Risks
- The flare and the blip are tuned on paper; check on a Duo that the blip reads as "lost" and not as the chain
  "bwoop" (they are different timbres and intervals, and the bwoop now waits for the blip).
- The "nom" adds low-mid energy at 50 ms on every 1–2 bug bite (and Home's chomp); the mix tests cover clipping.
