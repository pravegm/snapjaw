# Feel R4 hand-off (Feedback; Input unchanged)

*Feel engineer, 28 Oct 2026. Not compiled locally (no Swift on this host). Every touched file had two read-throughs for
types, isolation and the CLAUDE.md Swift Testing gotchas. CI is the compiler.*

## QA-2 #16: stolen voices fade, and two big bites never click (`FeelSynth.swift`)
- **Steals fade.** When all 128 voices are busy, the oldest takeable voice gets a 6 ms smoothstep fade-out
  (`FeelSynth.stealFade` 0.006 s, so at least 5 ms). The new command waits in that voice (`FeelVoice.next`) and
  starts in its slot when the fade ends. Its delay is shortened by the fade, so a cue with ≥ 6 ms of delay still plays
  on time, and one with no delay plays at most 6 ms late. A victim that is still waiting out its own delay is silent,
  so the new command replaces it at once.
- **Protection by time, not by drain.** A voice younger than `FeelSynth.protectWindow` (0.03 s, by the synth's
  sample clock) is never taken. This replaces the old `drainFloor`. A voice that is already fading for another command
  is never taken twice. If nothing is takeable, the command is dropped and counted in `droppedVoices`, as before. So a
  bite whose ~80 commands straddle two render callbacks (10 ms buffers, about 23 ms if iOS ignores the preference) can
  no longer steal from its own first half.
- **The bog never steals.** Drips and frog croaks now use only a free voice (`start(_, mayTake: false)`), so ambience
  can't fade out a bite's sparkle. The marimba loop still steals, to keep its rhythm.
- **New diagnostic:** `loudestVoiceEnd` is the largest last-sample magnitude of any voice when it stopped (it ended,
  faded or was replaced; `stopAll` is excluded). Natural ends already ramp out over the 30 ms release, so anything
  near 0.01 would be a click.
- `stopAll` and the NaN reset now clear whole voices, including any pending command.

## QA-2 #9: the loss blip lands with the numeral (`FeedbackDirector.swift`, `FeelSoundBook.swift`)
- On a bite frame, the descending loss blip and its haptic play at `FeelSoundBook.numeralDropAt` = 0.20 s. That is
  the Scene's 50 ms hit-stop plus `BogEconomy.crackLead` 0.15 s, when the HUD numeral drops. They used to play at the
  verdict, 0.46 s for a bee. On a frame with no bite they play at 0.15 s.
- The blip now sits on the "Bzzt!"'s tail (it starts 0.06 s). The free sting's "oops" still waits for the spit,
  because nothing drops.
- The chain "bwoop", the last-snap knocks and the yawn still wait for the blip to end (`afterLoss` = 0.52 s).
- **Coordination:** QA-2 also offered the Scene fix (raise `crackLead` to about 0.41). If Scene does that, set
  `numeralDropAt` back to the verdict time. `aCostlyStingsBlipLandsWithTheNumeralDrop` checks
  `numeralDropAt ≈ BogScene.hitStopTime + BogEconomy.crackLead` (±20 ms), so a mismatch fails CI instead of shipping.

## Tests (FeelTests)
- New: `aStolenVoiceFadesOutOverAtLeastFiveMilliseconds` (a loud 1 kHz voice is stolen: no sample step above the
  sine's own, still audible at 4.75–5 ms, gone by 6.5 ms).
- New: `aBiteSplitAcrossTwoCallbacksNeverTakesItsOwnVoices`.
- New: `twoBigBitesCloseTogetherNeverClick`. This is the render peak check: two 8-bug Feasts 0.45 s apart over the
  full bed, 8 buzzers and 90 ringing bells. Peak < 1, < 2 % hot, steals > 0, drops 0, `loudestVoiceEnd` < 0.003.
- New: `aCostlyStingsBlipLandsWithTheNumeralDrop`.
- Updated: the steal-order test renders 40 ms between rounds (past the window), and the stinger mix test places the
  blip at `numeralDropAt`.

## Other QA-2 items, not Feel's
- #14 (no hinge report means no snaps) is fixed App-side: `GameController` should pick `.hinge` only once
  `hinge.hasHinge` is true, or accept taps until then. `HingeTrapSource` is unchanged.

## Risks
- On a Duo, check that the blip at 0.20 s still reads as "lost" over the "Bzzt!"'s tail (a wasp's second zap is also
  at 0.20).
- A stolen cue can start up to 6 ms late, which can't be heard.
