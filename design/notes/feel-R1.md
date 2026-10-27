# Feel R1 hand-off (Input + Feedback)

*Feel engineer, 27 Oct 2026. Nothing here has been compiled yet (CI blocked); every file had two read-through passes
for types, optionals, isolation, labels against `Contracts.swift` and the Swift Testing gotchas.*

## Files
| File | What |
|---|---|
| `Snap/Input/HingeReader.swift` | Hush/Swoop's reader, renamed. `SNAP-H <t> <angle>` ≤ 10/s (DEBUG + `-snapDemo`). |
| `Snap/Input/FeelFilters.swift` | `FeelMath`, `OneEuroSmoother` (+ `escape`, `settle`), `HingePredictor`, `FeelClosingGate` (50°/0.6 s, clears > 58°), `FeelDemoLog` (`line`, `emit`). |
| `Snap/Input/HingeTrapSource.swift` | Hinge → filter → Core's `SnapDetector` per report. |
| `Snap/Input/TouchTrapSource.swift` | Tap to snap; `FeelTouchJaw` curve. |
| `Snap/Feedback/FeelSynth.swift` | Lock-free real-time synth, now **stereo**; 64 voices (+ a granular `squelch` voice), 8 buzz slots, groan, bog, marimba. |
| `Snap/Feedback/FeelAudioEngine.swift` | Swoop's hardened engine (interruptions, route, reset, naps, background) + Hush's "audible bed wakes a nap"; stereo source node. |
| `Snap/Feedback/FeelSoundBook.swift` | Every recipe and bed as pure data; `FeelDice`; `FeelBuzzMixer` (slot keeper). |
| `Snap/Feedback/FeelHaptics.swift` | `FeelHapticBook` (cues, Strong profile) + the Core Haptics engine (one looping creep player). |
| `Snap/Feedback/FeedbackDirector.swift` | The contract API + `FeelStretchMeter` (Home). |
| `SnapTests/FeelTests.swift` | 36 tests: detector+filter end to end, touch, recipes, synth render, haptics, director. |

## The hinge path (latency)
- Raw report → `OneEuroSmoother(minCutoff 1.2, β 0.5, dCutoff 4, escape 2°)` → `SnapDetector.ingest(angle:at:)` with the
  report's own time. Any report > 2° from the filtered value passes through **unchanged**: every report of a real snap
  moves 5–8°, so a fast close reaches the rule with **zero** added lag and fires on the crossing report (tested at 30 and
  25 Hz). Slow creeps and jitter (small steps) are smoothed.
- **Still hinge:** the Duo sends nothing while still. Each frame ≥ 50 ms after the last report feeds the detector the
  still angle (every 1/30 s, frame time), so its 0.6 s reference window never empties. The first such sample settles
  the filter onto the raw reading: a hand that stops 0.3° past 22° still bites (≤ ~42 ms late) instead of never.
- A trigger is held until a frame consumes it (two reports in one frame can't lose a snap); asking twice for the same
  frame never delivers it twice.
- `input.closure` is the detector's (truthful: Core's creep nerve check reads it). It steps at the report rate; for
  smoother drawing `predictedAngle(at:)` is there (drawing only). Possible R2 polish with the Scene.

## Touch
Tap while armed → closure eases in 0 → 22° over 0.09 s and the snap fires **when the jaws meet** (tap + 0.09 s,
`duration` 0.09), so the CHOMP lands as the teeth close on screen. Reopen 0.35 s (smoothstep); re-arm at 0.45 s; taps
before then are ignored.

## Sounds (all synthesised, stereo; every one-shot can be panned)
| Sound | Intent |
|---|---|
| **CHOMP** (hero) | rim tick → wet thwack (LP noise 2.4 kHz → 300 Hz / 60 ms + 650 Hz leaf slap) → thump 90 → 45 Hz with harmonics (phone speakers carry it) → teeth clack (wood 1.8 / 2.3 kHz, 18 ± 3 ms) → granular squelch with bubbles (120 ms + 60 ms/bug) → "mm" gulp at 0.3 s + swallow. Pitch ±4 % per bite; +5 % weight per extra bug; low slosh at 3+. |
| crunch | one shell crackle per `bugCaught`, panned to the bug, staggered inside the squelch (countable). |
| dry snap | the clap without the wet: lighter thwack/thump, clack, empty air puff, two falling marimba notes ("nothing…"). |
| Feast / pop | rising C-pentatonic sparkle (4 notes, 5 for 5+), then one bubble "pop" per snap back. |
| lucky | ladybird: two bells + pop. Golden Scarab: glassy glissando over a chord + two pops. |
| sting | "Bzzt!": square 220 Hz (bumblebee 160, wasp 300 ×2 zaps + zing) with angry 32 Hz vibrato, then the trap's "ptoo" spit. |
| spared | a happy rising hum + chime (kindness rewarded). |
| landing tik | wood tick pitched by size (3.4 kHz gnat … 1.9 kHz dragonfly), "pat" for big bugs, half level on the bog. |
| sip / hop / spooked / whiff / whoosh | tiny wet "slp"; spring "boing"; startled rising zip; airy escape; lobes swinging in (snapStarted). |
| re-arm | a soft low G3 pluck. |
| chain | marimba step up a C-pentatonic ladder after the gulp; broken: falling "bwoop" + thud. |
| last snap / tired / new best | two low knocks; a sinking yawn; a rising four-chime. |
| day chime | dawn chime, noon glint, dusk bell, night owl. |
| **Buzz layer** | up to 8 bugs (loudest first, stable slots, 80 ms fades, timbre swaps only through silence), panned by `pan`, louder flying and low: fly saw 190 Hz + wingbeat AM, gnat, bluebottle, mosquito 610 Hz whine, bee 220 Hz hum w/ vibrato (hums softly while sipping — the dilemma), bumblebee 110, wasp nasal 255, dragonfly rattle, moth flutter, cricket chirps, beetle drone, hopper crackle. |
| Creep groan | rubbery stick-slip saw 70 → 140 Hz following closure, leafy formant, rubber squeak; only while creeping. |
| Bog bed | stereo reed wind (half at night), frogs (rib-bit FM / bullfrog every 3–9 s, louder at dusk), drips; two night crickets from dayClock 2.75. |
| Marimba loop | 96 bpm, C–Am–Dm–G in C pentatonic: melody; + bass at chain 2, counter at 4, glass sparkle at 6. Stops when play stops (tired). |

## Haptics
Landing tick by size (in-trap only, ≤ 12/s); creep texture (looping player, 0.15 → 0.65 with closure, rubbery jitter);
**CHOMP**: 1.0 transient + second-tooth tap + 3-step rumble (90 ms + 20 ms/bug, stronger with more bugs) + a crunch tap
per bug + gulp thud; dry snap 0.8; Feast double tap; sting buzzy wobble; lucky sparkle; re-arm tick; last snap, tired,
new best, UI. Strong profile (Duo default once `deviceHasFold`) turns taps into bursts the Duo's weak actuator pushes.

## What the App must call
- `FeedbackDirector.shared.start()` at launch; set `soundOn`, `hapticsOn`, `respectSilentSwitch` from Settings;
  `idle = true` in menus.
- Every play frame: `handle(events, telemetry:)` (telemetry `playing` false in pauses/tired/results).
  Every Home frame: `homeTrap(closure:snapped:)` (`snapped` true on the snap frame; a 0.3 s refractory covers repeats).
  `silence()` on pause / leaving play.
- **Additive, please set:** `sceneWidth = Double(layout.size.width)` on every layout change (events' positions are
  panned across it); `deviceHasFold = true` once a hinge is seen (Strong haptics). Optional: `hapticProfile`.
- `HingeTrapSource`: feed `HingeReader` → `ingest(angleDegrees:at:)`. Call **`reset(at:)` when a paused run resumes
  and when the app becomes active** (fresh reference, no stale creep/snap). `isClosing` (or `closing(at:)`) for the
  closing pause; it works without frames. `reference`, `armed`, `angle` are there for the `SNAP-T trap` line.
- `TouchTrapSource.tap(at:)` from `sceneTapped`; `reset()` on a new run.
- The director handles background/active itself (pauses audio in the background).

## Deviations
- Stereo synth (sisters are mono): needed for the panned buzz. Mono routes get the sum.
- Touch snap fires at contact (+0.09 s), not on the tap.
- Landing haptics only for in-trap landings (bog landings tick in sound only, softer).
- `drySnap` event is silent: `snapped` with 0 caught already plays the empty clap.
- Feel keeps its own bug-size table (ROUND-1 radii) instead of reading `BugCatalog`, so Feedback depends only on
  `Tuning` and `SnapDetector` from Core.
- Extra diagnostic lines (DEBUG + `-snapDemo`): `SNAP-T hinge snap d=… angle …` and `SNAP-T hinge closure … ref …` (2/s).

## Names I define (avoid in other modules)
`FeelMath`, `OneEuroSmoother`, `HingePredictor`, `FeelClosingGate`, `FeelDemoLog`, `FeelHingeLog`, `FeelTouchJaw`,
`FeelSynth*`, `FeelBed`, `FeelBuzz*`, `FeelNoiseSpec`/`Tone`/`Ring`/`Drop`/`FM`/`SquelchSpec`, `FeelRingKind`,
`FeelFilterMode`, `FeelAudioEngine`, `FeelAudioRules`, `FeelSoundBook`, `FeelDice`, `FeelHaptic*`, `FeelStretchMeter`.

## Risks
- Untested against the real `SnapDetector`: the end-to-end tests assume GAME-DESIGN §3 exactly (reference = max θ over
  0.6 s; snap at closure ≥ 22 on a sample; armed false until re-arm). A mismatch shows up first in `FeelTests`.
- Loudness balance is by arithmetic, not by ear: tune on the Duo (buzz gains in `FeelSynth.buzzTone`, CHOMP gains).
- 64 voices + 8 buzz slots per sample: fine on the Duo, but watch CPU in a big Feast.
