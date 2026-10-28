# Feel R2 hand-off (Input + Feedback)

*Feel engineer, 28 Oct 2026. Not compiled locally (no Swift on this host); every touched file had two read-throughs for
types, isolation, exhaustive switches and the CLAUDE.md Swift Testing gotchas. CI is the compiler.*

## What changed
| Item | Where | What |
|---|---|---|
| Hunger events | `FeedbackDirector.react` | `hungry` → stomach rumble (`FeelSoundBook.hungry`: a 72 → 58 Hz growl with a 9 Hz wobble, a low-passed gurgle, a rising "grrr", three low bubbles) + `FeelHapticBook.hungry` (four soft, round grumbles). `wilted` → a soft droop (`FeelSoundBook.wilted`: G4 → G3 sigh, leafy rustle, low marimba note) + a weak fading haptic. A `lastSnap` / `tired` in the same frame as a wilt waits 0.7 s for the droop. Switch stays exhaustive (no `default`). |
| QA-1 #4 voices | `FeelSynth` | 128 voices. Steal by a monotonic start stamp (oldest first), never a voice started in the current drain; if all are that new, the command is dropped (`droppedVoices`, `stolenVoices` counters). Ring voices end at 5 τ (was 7 τ). Crunches past the 4th bug are light (2 commands). |
| QA-1 #5 creep after reopen | `FeelCreepGuard` (FeelFilters), `HingeTrapSource` | Own 3 s creep reference, re-seeded to θ on every sample during a 0.6 s quiet spell after: the first sample, a re-arm, θ rising (above the last sample and ≥ 1° over the 0.25 s low), θ ≥ 174°. `HingeTrapSource` reports creeping only if the detector **and** the guard agree; on a veto the closure is the plain rest closure. Core's matching change is asked in `design/NEEDS.md`; either order works. |
| Heavier CHOMP | `FeelSoundBook.chomp`, `FeelHapticBook.chomp` | Impact at 0: thump longer/heavier (0.34, τ 90 ms, 6 harmonics) + a 160 → 70 Hz knock + a low body whump (thwack, slap and tick trimmed to keep headroom). The wet tail waits out the Scene's 50 ms hit-stop (`FeelSoundBook.hitStop`): squelch and crunches start at 0.05 / 0.058 s; gulp 0.34 s; chain chime 0.46 s. Haptic: slam, then a deep held clamp for the hit-stop, the rumble steps and crunch taps after it. |
| QA-1 #2 / #7 stale snaps | `HingeTrapSource`, `TouchTrapSource` | A trigger no frame consumed within 0.25 s is dropped (`staleSnapsDropped`, `staleBites`), so a clap on Results / in a menu, or a tap just before a pause, never fires on the next run's first frame. Belt and braces with the App's `reset` calls. |
| Duo sim: impossible durations | `HingeTrapSource.sane` | Any trigger's duration is clamped to ≥ 1/30 s (one Duo report). |
| QA-1 #13 | director `heal` | Audio heals in menus too (and before a menu sound); `heal()` itself leaves a napping engine alone. |
| QA-1 #14 | director watchdog | The stale branch schedules an idle check, so the engines really idle. |
| QA-1 #15 | `FeelBuzzMixer` | A bug in a slot ranks × 1.3 (`hysteresis`): no 8th/9th-bug slot swapping. |
| QA-1 #16 | `FeelSynth` | `apply(.bed)` sanitises every field (`FeelSynth.sanitised`); `resetFilters()` resets the glided bed (glides back up), every oscillator phase and the buzz states (keeping their targets). |
| QA-1 #17 | `FeelAudioEngine` | `'!pla'` / `'!pri'` start refusals (a call) don't count toward the reconnect/rebuild ladder; `heal()` backs off 3 s. |
| QA-1 #18 | director, `FeelHapticBook.merge` | All of a frame's curve-less cues play as one pattern (one player per bite frame instead of ~7). |

## Duo sim run 40603497021 (the founder's two questions)
1. **CREEP-FAST "max closure 0.0°" is the hinge CLI, not the trap.** `logs/hinge.txt` has no `SNAP-H` line between
   t = 805.4 s (the re-open to 154.6°) and 925.7 s: no report reached the app for two minutes. `run.txt` shows all
   three sweeps of that step ("160 → 159", "159 → 160", "160 → 128") "exited non-zero" after 25–55 s each. During the
   window the trap logged `armed 1 creep 0 angle 155.6 ref 155.6` every frame: armed, not un-armed; no samples dropped
   by us (the reader logs ≤ 10/s, so even a trickle would show). The late 155.6 → 125.9 jump at 925.7 s (the
   `caught=5 … d=0.012` snap) landed after the window closed. Asked CI (NEEDS) to mark such a window INCONCLUSIVE.
   Side note: the CLI's "160°" reads as 155.6–155.8° in the app (within the Duo's ~±5°).
2. **d = 0.010 s.** The CLI jumped 152.8 → 125.9° in one report; the detector interpolates both the 4° and the 22°
   crossings inside one (keep-alive-to-report) gap, so d is a fraction of ~15 ms. Now clamped to ≥ 1/30 s in
   `HingeTrapSource.sane` (tested). Note that any d under ~0.12 s still catches everything by the bite rule; that is
   correct for a genuinely fast snap. The CLI's jumps simply make every CI snap "perfect".

## Tests added (FeelTests)
Reopen overshoot never creeps (and a real creep after it still does); bending from flat never creeps; the guard's
unit behaviour; stale hinge snap dropped; one-report jump gets a sane duration; stale touch bite dropped; steal order
and never stealing from the own drain (10 stolen, then 128 stolen + 72 dropped); rings end by 5 τ; a big Feast drops
nothing; a NaN bed can't latch the synth; CHOMP impact at 0 and tail after the hit-stop (sound and haptic); hunger
sounds soft/low/falling; director rumbles/droops and builds one pattern per bite frame; haptic merge; mixer hysteresis;
audio refusal rule. `feelEveryEvent` now includes `hungry` and `wilted`.

## For other modules
- **Scene:** the CHOMP's tail is timed to a 50 ms hit-stop starting on the `snapped` frame (`FeelSoundBook.hitStop`).
  If the Scene changes that, tell Feel.
- **Core:** see NEEDS (creep re-seed in `SnapDetector`; optional duration clamp; sim mirror).
- **App:** `hinge.reset` in `start()` is still the right fix for QA-1 #2; Feel's stale-snap drop is the safety net.

## Risks
- The heavier CHOMP adds energy in the first 40 ms; the mix tests (`hot < 2 %`) should catch overload. Tune by ear.
- The creep guard makes creep detection up to ~0.6 s later after any rise; a sneaky "open a bit, then creep" is
  forgiven for that long (never a false creep). Confirm on a Duo with `SNAP-H` logs of real reopen strokes.
- A frame hitch > 0.25 s right after a real snap would drop that snap (very unlikely at 120 Hz).
