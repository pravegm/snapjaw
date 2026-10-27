# Round 1: first playable (brief)

Read first: `design/GAME-DESIGN.md`, `design/ARCHITECTURE.md`, `Snap/Shared/Contracts.swift`, `CLAUDE.md`.
**Goal:** a complete, compiling, playable game on the first CI run: First Bite lesson → Feed → Results → Home,
Daily Bog, Bug Book, Settings, with feel (audio, haptics) and art that already sells the fantasy.

**Sister code to copy from (read-only, never modify):**
- Swoop (book pose, landscape, the closest relative): `C:\Users\59527\Wing\Swoop\...`
- Hush (built today, the freshest structure): `C:\Users\59527\Lid\Hush\...`
- Brim: `C:\Users\59527\Fold\Brim\...`

All are battle-tested on a real Duo and in this CI. Copying and adapting is encouraged; rename `Swoop`/`Hush`/`SWOOP-`
/`HUSH-` to `Snap`/`SNAP-`. Never write the product name in Swift: use `AppBrand.name`.

**Compiler reality:** there is no Mac here. Code you write is compiled only on CI, after you finish. Be conservative:
- Swift 5 mode, no macros other than Swift Testing's `#expect`/`@Test`, no new language features beyond Swift 5.10
  unless a sister project already compiles them.
- `@MainActor` on everything that touches UIKit/SpriteKit/SwiftUI/AVFoundation/CoreHaptics. Core is non-isolated.
- Swift Testing gotchas: `#expect(x.mutating())` doesn't compile (call first, then expect). Compare `CGFloat`/`Double`
  with a typed constant and a tolerance.
- Re-read every file you write once, top to bottom, for type errors, missing imports, missing `self.` in closures,
  wrong optional handling and exhaustiveness of `switch` over the contract enums. That pass is worth more than
  anything else you do.

## Demo mode (DEBUG only; launch argument `-snapDemo "k=v;k;…"`)
The App engineer parses it (`Snap/App/DemoMode.swift`); other modules get what they need through the App. Keys:

| Key | Meaning |
|---|---|
| `screen=home\|play\|results\|book\|settings\|lesson\|pose\|cover\|icon` | Start on this screen (`play` = straight into a run) |
| `mode=feed\|daily\|attract` | The run mode for `screen=play` (default `feed`) |
| `seed=<n>` | The run seed |
| `pilot=novice\|casual\|expert\|perfect` | A `TrapPilot` drives the trap. Without it, `screen=play` takes the real hinge (Duo CI) or touch |
| `progress=fresh\|mid\|late` | Seed `ProgressStore` (fresh: nothing; mid: rank 4, 9 species, best 3,200; late: rank 10, 16 species, best 14,800) |
| `freezeOn=<tag>` | Stop stepping the session (the scene keeps drawing) at the first: `landed` (≥ 1 bug sipping in the trap), `crowd` (≥ 3 sipping), `bee` (a protected bug sipping), `snap` (0.12 s after a bite), `feast`, `sting`, `dusk`, `night`, `lastSnap`, `tired`, `results`. Print `SNAP-T freeze <tag>` |
| `freezeAfter=<s>` | Freeze after s seconds of play |
| `closure=<deg>` | Hold the drawn closure at this many degrees (no pilot, no hinge): static frames of the jaws |
| `wave=<n>` | Start the run at wave n (day-phase frames) |
| `lessonStep=<n>` | Start the lesson at step n (1–7) |
| `hudLeft=0\|1` | Force the HUD side |
| `fold=1` | Lay out as if a fold exists (phone sims; frames of the Duo layout) |
| `sound=0` | Mute |

**Log lines** (stdout, DEBUG with `-snapDemo` only, one `print` + `fflush`):
- `SNAP-T canvas <w>x<h> fold=<0|1> hudLeft=<0|1>` on every layout change.
- `SNAP-T input hinge|touch|pilot` when the source changes.
- `SNAP-T trap closure <deg 1dp> armed <0|1> creep <0|1> angle <θ 1dp|-> ref <θ 1dp|->` at 10 Hz while in play.
- `SNAP-T event <name> [details]` for every TrapEvent (names = the enum case names; `snapped` prints
  `caught=<n> escaped=<n> stingers=<n> points=<n> d=<s 3dp>`).
- `SNAP-T paused closing` / `SNAP-T resumed`.
- `SNAP-T freeze <tag>`.
- `SNAP-T frame 120`.
- `SNAP-H <t> <angle>` (Feel engineer, inside HingeReader).

## Core engineer: `Snap/Core/`, `SnapTests/CoreTests.swift`, `SnapTests/BalanceTests.swift`
- Everything in ARCHITECTURE "Core API", with exactly those signatures.
- **Tuning:** every number in GAME-DESIGN §3–§6.
- **SnapDetector:** the GAME-DESIGN §3 rule exactly (rest reference, closure, arm/re-arm, snap start at 4°, snap at
  22°, creep, too flat). Timing from sample times. One snap per arm.
- **BugCatalog:** 16 entries per the §6 table, each with a charming one-line joke ("Housefly — has never once
  wiped its feet"). Radii: gnat 7, fruit fly 9, mosquito 9, ant 10, housefly 14, ladybird 14, firefly 13, moth 18,
  bluebottle 16, grasshopper 18, cricket 17, bee 16, bumblebee 22, wasp 16, dragonfly 24 (long), scarab 20.
- **Movement:** believable and readable. Flies: approach in a wobbly arc with a little hover before landing; on the
  surface they walk in short dashes and pause, and go to a free nectar drop when there is one (one bug per drop;
  others land near it and wait). Gnats drift as a loose swarm. Ants walk single file. Grasshoppers/crickets hop
  0.5–1.2 s arcs between spots. Dragonflies hover and dart. Moths flutter toward the fold. Keep bugs ≥ radius sum + 4
  pt apart when landed. Linger counts from landing.
- **WaveFactory:** the §6 table; wave sizes 1–2 early → 3–7 later; crowd waves (3+ bugs landing within 1.5 s of each
  other) about 1 in 3 from wave 4; bees land on nectar like everyone else (that is the dilemma).
- **TrapPilot:**
  - Snap durations: novice 0.22–0.40 s, casual 0.14–0.24, expert 0.10–0.15, perfect 0.08.
  - Decisions: novice snaps on any 1 landed bug, sometimes with a bee in; casual waits for 2 (or 1 big one) and avoids
    bees 80 %; expert waits for 3+ or high value and avoids bees 98 %; perfect never bites a bee and waits for the
    best value it can see within the next 2 s.
  - It drives `closure` with a realistic curve (snap down over `duration`, hold 0.15 s, re-open over 0.35 s) and creeps
    occasionally (novice only).
- **BalanceTests:** 8 seeds × 4 skills, a full run at 60 Hz. Assert: median score novice < casual < expert ≤ perfect;
  casual run 90–240 s and 18–45 snaps; perfect is never stung; novice stung ≥ 1 per run on median. Print `SNAP-BAL`
  lines with a table.
- **Unit tests:** detector (rest drift, 22° in 0.12 s at 30 Hz fires once on the crossing sample, slow close creeps and
  never fires before 22°, re-arm rules, too flat), bite rule incl. all reaction factors, snap economy (costs, refunds,
  stingers, max 12), chain rules, determinism (same seed → same snapshot sequence), day phases, DailySeed, ranks,
  achievements, hint priority.

## Feel engineer: `Snap/Input/`, `Snap/Feedback/`, `SnapTests/FeelTests.swift`
- `HingeReader` (copy Swoop's, `SNAP-H`), `HingeTrapSource` (One-Euro filtered → `SnapDetector`), `TouchTrapSource`,
  the filters (copy Swoop's `FeelFilters.swift`).
- **FeedbackDirector**, audio engine (copy and adapt Swoop's `FeelAudioEngine` and `FeelSynth` architecture:
  lock-free render, command queue, beds) and haptics (copy `FeelHaptics`). The sounds are GAME-DESIGN §10:
  - **CHOMP is the hero** and must feel physically satisfying: a wet thwack (noise burst through a low-pass sweeping
    2.4 kHz → 300 Hz in 60 ms, plus a 90 → 45 Hz sine thump), a teeth clack (two woody clicks 18 ms apart: short
    resonant band-passed impulses ~1.8 kHz and ~2.3 kHz), a squelch tail (granular wet noise, 120 ms + 60 ms per bug),
    a gulp 0.3 s later ("mm": a 140 Hz → 90 Hz formant blip). Feast: a rising 4-note sparkle (pentatonic) and a "pop".
    Vary every CHOMP slightly (pitch ±4 %, click spacing ±3 ms) so it never feels canned.
  - **Bug buzz layer:** up to 8 voices, each a buzzer from `telemetry.buzzers`, panned by `pan`, louder when flying
    and when low; per species timbre (§10). Fade voices in/out over 80 ms; never click.
  - Landing tik, escape whiff, sting "Bzzt!" (a harsh 220 Hz square burst with vibrato + a tiny "ptoo" spit), creep
    groan (rubbery: a filtered saw at 70–140 Hz whose pitch follows closure), re-arm "pluck" (soft, low).
  - **Bog bed:** frogs (FM croaks every 3–9 s), drips, wind in reeds (filtered noise) by day; crickets at night
    (`dayClock` ≥ 3). A gentle plucked-marimba loop (≈ 96 bpm, C major pentatonic) that adds a voice at chain 2, 4, 6.
  - `.playback` category so it plays with the silent switch on; "Respect silent switch" switches to `.ambient`.
- **Haptics:** landing ticks (by bug size, capped at 12/s), a creep texture (intensity ∝ closure while creeping), the
  CHOMP (the heaviest transient + 90 ms rumble, more with more bugs), a double tap on Feast, a buzzy wobble on a sting,
  UI taps. Copy Swoop's engine-restart and audio-interruption handling.
- `homeTrap(closure:snapped:)`: Home's title trap creaks and chomps too.
- **Tests:** detector + filter end to end from synthetic sample streams (a 25° close in 0.12 s at 30 Hz fires with
  duration 0.08–0.16; a 40° close over 2 s creeps and never fires early; jitter ±1.5° at rest never arms a snap), the
  touch source's closure curve and re-arm, the noise-free render (no NaN; peak < 1.0 over 10 s of mixed events).

## Scene engineer: `Snap/Scene/`, `SnapTests/SceneTests.swift`
`BogScene` and `TrapArt` per ARCHITECTURE. The look is GAME-DESIGN §10. **It must read on a still frame** and feel
glossy and alive:
- **Bog** in the corners and the wide-phone extension: dark mossy greens, dew drops, sundew stalks, a few lily pads
  at the bottom, soft parallax-free texture (cached).
- **Two lobes** filling the trap ellipse (`layout.geometry`), split by the midrib on the fold band. Outer skin lime
  green; inner face a glossy crimson-to-pink gradient, darker toward the midrib, with wet highlights (a soft specular
  streak per lobe) and veins radiating from the midrib. Three trigger hairs per lobe (glow on a bug walking over).
  The rim: a lime band with **long pale-green teeth (cilia)** all round the outer edge, pointing outward when open.
- **Closure follows the hinge:** `closure01 = min(snapshot.closure / Tuning.snapDepth, 1)`; the teeth lean inward,
  a shadow grows in from the outer edges, the gloss shifts. On `snapped`: the jaw slam — the teeth sweep to interlock
  silhouettes at both outer edges over 60 ms, hold 120 ms, a dark vignette, camera punch (scale 1.03 → 1), juice
  splats on caught bugs, which squish into the midrib; escaped bugs zip out with a whiff line.
- **Nectar drops:** glistening gold domes with a highlight that twinkles.
- **Bugs:** chunky, round, cute (big white eyes with pupils, glossy bodies), from `TrapArt` paths; wings flap fast
  (blur ellipses) when flying; a soft shadow offset by `height`; sipping shows a gold ring and a tiny bobbing; restless
  bugs twitch. Bees are clearly bees (yellow-black bands, a cheerful face) and get a subtle white "protected" halo
  ring so nobody misreads them. Wasps are angular and mean-looking.
- **Day light:** a full-scene tint by `dayClock` (warm gold morning, white noon, peach dusk, blue night). At night
  fireflies glow with additive blooms and other bugs dim slightly.
- **Score pops** in-world at the bite: "+240" and "TRIPLE ×3" (big rounded heavy font), "Bzzt!" on a sting, "Feast!
  +1 snap". These are scene labels (not SwiftUI), cached fonts.
- On `layout.hasFold == false` draw the midrib only (no fold band shadow).
- **Touch:** every `touchesBegan` → `driver.sceneTapped(at:time:)` in scene space.
- **Tests:** geometry/rim sanity, every species has non-empty paths, palette contrast sanity.
- Performance: 120 fps target on the Duo; no per-frame path rebuilding for static art; cache textures; lobes may be
  rebuilt at most when closure01 changes by ≥ 0.02 (or use a few cached closure keyframes and blend).

## App engineer: `Snap/App/`, `Snap/UI/`, `Snap/Persistence/`, `SnapTests/AppTests.swift`
- **`SnapApp`, `RootView`:** a landscape play canvas; portrait on a Duo shows the pose card. Copy Swoop's
  `OrientationLock`, `RootView` structure and `PoseCards`.
- **Screens** (SwiftUI over the scene where it makes sense):
  - **Home:** the title (`AppBrand.name`) with a live trap behind it that follows the hinge (it chomps when you snap;
    `FeedbackDirector.homeTrap`), a bee bumbling across. Buttons: Feed, Daily Bog, Bug Book, Settings. Shows plant rank,
    best, daily status. On a Duo the buttons sit on the right half (the HUD side).
  - **HUD (SwiftUI over the scene, on `layout.hudRect`):** score (big rounded heavy), snaps as little trap icons (up to
    12), the chain multiplier chip, the hint (one line, ≤ 6 words), a pause button and the pause menu (Resume, Restart,
    Home). Keep it in the corners of the HUD half (outside the trap ellipse) so it never covers bugs.
  - **Pose cards:** "Hold it open like a book" (portrait on a Duo) with a drawn diagram; "Open it a little to carry on"
    (closing pause); the cover-display card when shut: "Open to carry on".
  - **Results:** protein (a big counting number), new best, bugs caught, best bite, longest chain, bees spared,
    new Bug Book entries (art), rank bar, one sentence naming the best moment. Buttons: Again, Home.
  - **Bug Book:** 16 slots; found = drawn (`TrapArt`), name, joke, count caught (bees: spared); unfound = silhouette.
  - **Settings:** Sound, Haptics, Respect silent switch, HUD on the left, Reduce motion, Replay First Bite, About,
    Credits.
  - **Daily Bog:** one scored try a day (then practice), today's best.
- **First Bite lesson** (GAME-DESIGN §8): `TrapSession(mode: .lesson)` with `spawnScripted`; the App drives the 7 steps.
  Runs on first launch; skip allowed after step 2. On phones without a hinge the step texts switch to "Tap to snap".
- **GameController:** the hub; pause on closing, app inactive or menu. Sources: `HingeTrapSource` fed by
  `HingeReader` on the root view; `TouchTrapSource` when no hinge; `TrapPilot` when the demo asks.
- **Persistence:** `ProgressStore` (best per mode, lifetime bugs, caught/spared per species, achievements, daily, stats,
  lesson done), `SettingsStore`. Versioned JSON in UserDefaults.
- **Game Center:** copy Swoop's `GameCenterManager`. Leaderboards `snap.best` and `snap.daily`; achievements
  `snap.ach.<key>`. Silent when signed out.
- **Theme** (`SnapTheme.swift`): bog greens with crimson and gold accents, a rounded heavy display font, ≥ 56 pt hit
  targets. Use `TrapArt.palette`.
- **DemoMode** (the keys above) and every `SNAP-T` line listed.
- **App icon as code** (`UI/AppIconArt.swift`, like Swoop's; `screen=icon` writes the 1024 PNG and prints
  `SNAP-ICON <path>`): the trap's two lobes snapping on a fat cartoon fly, teeth interlocking, glossy crimson on deep
  green, readable at 60 px.
- **Tests:** progress/settings round-trip and migration, the daily one-scored-try rule, demo parsing, lesson step gating,
  layout maths.

## CI engineer: `.github/workflows/`, `ci/`, `project.yml`, `.gitignore`, `.gitattributes`
Adapt Swoop's `project.yml`, `ci.yml`, `duo.yml`, `testflight.yml`, `tf-status.yml`, `ci/screenshots.sh`,
`ci/duo.sh` and the scenario files (landscape book pose, like Swoop). Specifics:
- Target `Snap`, test target `SnapTests`, bundle id from the founder (see `CLAUDE.md`), display name from the founder.
- `ci.yml`: build, test, screenshots from `ci/scenarios.txt`, render the app icon (`screen=icon`).
- `ci/duo.sh` hinge pass (book pose landscape like Swoop). Checks:
  1. **SNAP:** launch `screen=play;mode=attract;seed=7`, hinge to 160, wait for `event bugSipping`, then sweep
     160 → 128 in 0.15 s. PASS if `event snapped` is logged within 1 s.
  2. **CREEP:** re-open to 160, then sweep 160 → 128 over 3 s. PASS if no `snapped` fires before closure ≥ 22 (log
     check) and `trap ... creep 1` appears.
  3. **REARM:** after a snap, sweep back to 160. PASS if `event rearmed`.
  4. **CLOSE-PAUSE:** sweep to 40 → `paused closing`; sweep back to 150 → `resumed`.
  5. Frames: open 165, half closed 150, snapped 130, the cover display shut, and the pose card if the sim allows.
- Keep `duo.yml` manual. `testflight.yml` as Swoop's (cloud-managed signing path).
