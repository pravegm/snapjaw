# Snapjaw: the flytrap game. Game design v1

*Owner: founder (Claude). Numbers live in `Snap/Core/Tuning.swift`; this doc gives the intent and the starting values.
Name: **Snapjaw** (name check in `research/01-market.md`). Subtitle: "Feed the flytrap. Spare bees."*

## 1. The pitch (5 seconds)
**Your iPhone Duo is a Venus flytrap.**
- Hold it open like a book. The two halves are the trap's two lobes; the hinge is its midrib.
- Bugs land inside to sip nectar. **Snap the phone half shut** to catch them, then open again.
- Wait for a crowd and catch them all in one bite, but never eat a bee.

Store line: **"Snap shut. Spare the bees."**

## 2. Why it works
- **Duo-native, and literal.** A real flytrap is two hinged lobes with teeth on the rim. So is the Duo. Nothing on the
  screen pretends to be a trap: the phone *is* the trap and your hands are its jaws. The snap is the most natural move
  a book-shaped object has (clapping a book half shut).
- **Different where it counts** (`research/01-market.md`). Fold Smasher (free, 23 Oct 2026) already lets you clap
  the Duo shut on bugs to smash them. Snapjaw is a different game on the same gesture, and we build every decision on
  the difference:
  - a **partial snap** (about 22° from wherever you hold it), never flat and never shut;
  - **choosing**: most of the game is waiting for the right moment (a crowd sipping, no bee in it), not hitting
    whatever moves;
  - **sparing bees** is half the skill;
  - **an economy** (snaps as the resource, big bites earn them back, a chain multiplier) and a day that changes the
    cast;
  - a plant, never "smash": the tone is a cheeky, glossy nature game, not a squash toy.
  - We never pitch it as "smash" or "fold to …".
- **Clear.** Bugs land → snap. Bees → don't. One resource: snaps.
- **Addictive.**
  - Push-your-luck: two flies are sipping. Snap now, or wait for the third and risk the bee drifting in?
  - Multi-catch multiplies the score, so greed is rewarded and punished in the same second.
  - Runs last 2–3 minutes. Score chase, Daily Bog, a Bug Book of 16 species, 12 ranks.
- **Satisfying.**
  - A wet, crunchy CHOMP with the strongest haptic transient the phone has, the teeth clacking shut on the rim, the
    bugs squished into the midrib, and the score popping "TRIPLE ×3".
  - The buzz of each bug is panned to where it is, and a soft tick plays in your hands when one lands.
- **Kind to the hinge.** A snap is a short stroke (about 25–40°), never flat and never shut. A run is about 25–40
  snaps, fewer than turning the pages of a short book.

## 3. Pose, angles and the blurred half (Duo)
- **Book pose.** The Duo is held upright in two hands, like a book you're reading. The canvas is landscape (about
  951 × 669 pt) with the fold vertical at mid-width. Each half is one lobe.
- **Hinge angle θ** (180 = flat). People rest a book anywhere from about 135° to 175°, so everything is **relative to
  the player's own rest angle**, never an absolute target:
  - **Rest reference** `ref` = the highest filtered θ over the last 0.6 s (falls at 25°/s at most, so a slow drift
    follows the player).
  - **Closure** `c = ref − θ` (degrees).
  - **Armed:** the trap is open. It re-arms once θ has risen 16° above the lowest point of the last snap, or θ ≥ 150°.
  - **Snap start** `ts`: the moment c passes 4° while armed.
  - **Snap** `tc`: the moment c passes **22°** (`Tuning.snapDepth`). The bite is decided here, at once: no need to go
    further, no need to hold. Snap time `d = tc − ts`.
  - **Creep:** a slow close never snaps (the 0.6 s reference follows it down), so it is measured against a slower
    reference: `creepRef` = the highest θ over the last 3 s (falling at most 6°/s, reset on re-arm). If
    `creepRef − θ` stays past 6° for 0.45 s without a snap, the trap is "creeping". While creeping the reported
    closure is that creep depth, so the jaws visibly close and twitchy bugs (nerve ≤ depth) notice and leave. The hint
    says "Snap it — quick!".
  - **Closing pause:** θ < 50° for 0.6 s pauses ("Open it like a book to carry on"). Fully shut shows the cover card.
    Never pause near 90°: a hard snap often reaches 90–100° (Swoop's real-Duo lesson).
- **Too flat:** θ ≥ 174° at the start of play shows "Bend it a little, like a book". There is no penalty. Starting a
  fold from flat blurs one half of the screen for about 2 s (an iOS effect), so we never ask for flat.
- **The blurred half.** iOS blurs one fixed physical half (the left half in book pose on the founder's Duo) for 1–2 s
  when a fold starts from flat or the inner display returns from the cover.
  - The HUD (score, snaps, chain, hints) lives on the **right half** by default. Settings → "HUD on the left" mirrors it.
  - Bugs land on both halves; every landing also ticks a haptic, and its buzz is panned, so a soft frame never hides
    one completely.

## 4. The trap and the bugs
- **The lobes.** Each half shows one lobe: a glossy crimson-pink interior with a lime-green rim and long pale teeth
  (cilia) along the **outer** edge of each half and curving round its top and bottom. Together the two lobes make one
  rounded trap spanning the fold. The corners of the canvas are bog: moss, dew, sundew stalks.
- **The trap zone** is the interior of the two lobes (an ellipse-ish shape per half, built in `TrapSpace`). Only bugs
  inside it can be caught.
- **The rim** is the outer 16% of the zone, next to the teeth. Bugs on the rim are half in: they react 40% faster.
- **Nectar glands.** 5–7 glistening drops sit on the lobes (seeded per wave). Bugs that land go to a drop and **sip**.
  A sipping bug shows a soft gold ring and is distracted: it reacts 35% slower.
- **Trigger hairs.** Three small hairs per lobe. A bug walking over one makes it glow briefly (cosmetic in v1; a
  later round can make "double touch" matter).

**Bug lifecycle:** enters from a canvas edge (flying, with a shadow under it) → lands at a nectar drop or a random
spot in the zone → walks/sips for its `linger` time → takes off → flies out. Some bugs never land in the zone (they
cross it, or land on the bog).

**The bite rule** (decided at `tc`): a bug is caught if it is inside the trap zone at `tc` and
`d ≤ reaction(bug)`, where

```
reaction = species.reaction × (sipping ? 1.35 : 1) × (flying ? 0.55 : 1) × (onRim ? 0.6 : 1)
```

A bug that isn't caught but was in the zone **escapes** (a "whiff" puff and it flies off). Bugs outside the zone don't
notice anything. Touch snaps (no hinge) count as `d = 0.09 s`.

**Creep rule:** while creeping (above), each bug in the zone with `nerve ≤ c` takes off at once.

## 5. Snaps, score and chain
- A run starts with **10 snaps** (shown as little trap icons; max held 12).
- **Every snap costs 1.** Then:
  - caught ≥ 3 bugs: **+1 back** ("Feast!");
  - caught ≥ 5: **+2 back**;
  - a Golden Scarab: **+2 back**;
  - a **bee** in the bite: it is let go, unharmed and cross ("Bzzt!"), costs **1 more snap**, and breaks the chain;
  - a **wasp** in the bite stings: **2 more snaps**, breaks the chain.
- **Score per snap** = (sum of the caught bugs' points) × (number of bugs caught) × chain multiplier.
  - "Double ×2", "Triple ×3", "Quad ×4", "FEAST ×5+" on screen.
- **Chain:** each consecutive snap that catches ≥ 1 bug and no stinger adds 0.5 to the multiplier (×1, ×1.5, ×2 … up
  to ×4). A dry snap (nothing caught) or a stinger resets it to ×1.
- **The run ends** when snaps reach 0: "Your trap is tired." The score is the **protein** total.
- A typical casual run: 25–35 snaps, 2–3 minutes. The difficulty ramp (§6) ends runs; a perfect player still ends
  around 6–8 minutes.

## 6. Waves and the day
- Bugs come in **waves**: a group of 1–7 bugs every 3.0–4.5 s (overlapping). Each wave has a recipe from the wave
  table, seeded from `(run seed, wave index)`, so the Daily Bog is identical for everyone.
- **The day** moves with the waves and changes the cast and the light (no clock, the waves are the clock):

| Waves | Time | New bugs | Bees per wave | Linger |
|---|---|---|---|---|
| 1–6 | Morning | Housefly, Gnat swarm, Fruit fly | 0–1 from wave 3 | 6–8 s |
| 7–14 | Noon | Bluebottle, Ant line, Ladybird, Grasshopper | 0–1 | 5–7 s |
| 15–22 | Dusk | Moth, Mosquito, Dragonfly, Wasp | 1 | 4–6 s |
| 23+ | Night | Firefly, Cricket; Golden Scarab rare | 1–2 | 3.5–5 s |

After wave 30 the night repeats with reactions × 0.97 per wave (floor 0.6) and one more bee every 8 waves.

**The cast** (16, the Bug Book):

| Bug | Points | Reaction s | Nerve ° | Notes |
|---|---|---|---|---|
| Housefly | 10 | 0.24 | 7 | The everyman. Lands, sips, wanders |
| Gnat | 3 | 0.32 | 10 | Comes as a swarm of 5, drifting together |
| Fruit fly | 6 | 0.28 | 9 | Pairs; loves nectar (sips longer) |
| Bluebottle | 25 | 0.16 | 5 | Fast, short sips, shiny |
| Ant | 8 | 0.60 | 15 | Walks in from the bottom edge in a line of 3–5; never flies |
| Ladybird | 15 | 0.30 | 10 | Lucky: catching one adds +1 snap |
| Grasshopper | 20 | 0.22 | 7 | Hops between the lobes across the fold |
| Moth | 20 | 0.30 | 9 | Dusk; drawn to the trap's glow (lands near the fold) |
| Mosquito | 12 | 0.14 | 4 | Tiny, darting, high-pitched whine |
| Dragonfly | 50 | 0.12 | 4 | Hovers, darts; catchable only by a sharp snap |
| Firefly | 35 | 0.26 | 8 | Night: glows; at night other bugs are dim |
| Cricket | 25 | 0.34 | 11 | Night; chirps, hops |
| Golden Scarab | 150 | 0.40 | 12 | Rare (≈1 per 12 waves from noon). +2 snaps |
| Bee | — | — | 8 | Never eat. Hums. Lands on nectar too (that's the trap) |
| Bumblebee | — | — | 10 | Never eat. Big and slow, lingers longer |
| Wasp | — | — | 6 | Never eat; stings if bitten (−2) |

## 7. Meta
- **Modes:**
  - **Feed** (main): endless waves until the trap is tired.
  - **Daily Bog**: the same seed for everyone; one scored try a day, plus practice.
  - **First Bite**: the lesson.
- **Bug Book:** 16 entries with a drawing, a one-line joke and your count caught (bees: "spared" count). An entry
  unlocks on the first catch (or the first spare, for bees and wasps).
- **Plant rank:** 12 ranks by lifetime bugs caught, from "Sprout" to "Bog Monarch". The trap's rim grows a little
  fancier with rank (cosmetic).
- **Game Center:** leaderboards "Best Feast" and "Daily Bog"; 12 achievements (first Feast, a 5-bug bite, ×4 chain, a
  Golden Scarab, a dragonfly, 50 bees spared, …).
- **Results:** protein (a big counting number), new best, bugs caught, best bite, longest chain, bees spared, new Bug
  Book entries, rank progress, and one sentence naming the best moment.

## 8. First Bite (lesson; first launch, replayable)
One sentence per step, taught by doing:
1. **Pose:** "Hold it open like a book." Passes when 125° ≤ θ ≤ 176° for 0.6 s (a portrait or tabletop hold shows the
   pose card).
2. **First snap:** one fat housefly lands on a nectar drop and sips (it never leaves). "When it's sipping… snap shut!"
   The snap can be any speed. On the catch: CHOMP.
3. **Open again:** "Open up to reset the trap." Passes on re-arm.
4. **Too slow:** two flies land. "Quick snaps catch more." If the player creeps, the flies leave and come back:
   "Snap it — quick!" Passes on a catch.
5. **The bee:** a bee lands and sips. "Never eat a bee. Wait…" It leaves after 3 s; snapping on it plays "Bzzt!" (no
   cost in the lesson) and repeats the step.
6. **Triple:** three flies land together. "Wait for a crowd… now!" On the catch: TRIPLE ×3.
7. Card: "Snaps run out. Big bites earn them back." Then Feed.

## 9. iPhone without a hinge (fallback)
- The same canvas and trap, laid flat on the phone's screen (a phone is just narrower; the fold is drawn).
- **Tap anywhere to snap.** The scene draws the jaws closing (teeth sweep in from both outer edges, 0.09 s) and
  reopening (0.35 s). The re-arm happens automatically after 0.45 s.
- The lesson's pose step is skipped; steps say "Tap to snap".

## 10. Feel
- **Audio** (synthesised, `.playback` so it is heard with the silent switch on; Settings has "Respect silent switch"):
  - **CHOMP is the hero.** A wet thwack (a filtered noise burst with a fast pitch drop), a crisp teeth clack (two
    short woody clicks 18 ms apart, like the rim meeting), a juicy squelch tail whose length grows with the bugs
    caught, and a little low "mm" gulp 0.3 s later. A Feast adds a rising sparkle and a cheerful "pop" of the snap
    coming back.
  - Bug buzzes, each panned left–right by x and with its own timbre: fly (sawtooth ~180 Hz with AM), mosquito
    (~600 Hz whine), bee (warm 220 Hz hum with vibrato), bumblebee (110 Hz), dragonfly (rattling wings), cricket
    chirps, moth (soft flutter noise).
  - Landing: a soft "tik" (by bug size). Escape: an airy "whiff". Bee caught: a cross "Bzzt!" plus a little spit.
  - Creep: a rubbery leaf-stretch groan that rises with closure (it warns you you're slow).
  - The bog bed: frogs, water drips, wind in reeds by day; crickets at night. A gentle plucked-marimba loop that adds
    a voice as the chain grows.
- **Haptics:** a landing tick per bug, a creep texture, the CHOMP (the heaviest transient plus a short rumble,
  stronger with more bugs), a double tap on a Feast, a buzzy wobble on a sting, UI taps.
- **Look:** a sunlit bog, saturated and glossy. Emerald and lime greens, a crimson-pink trap interior with a wet
  sheen, gold nectar drops, dew. Chunky, round cartoon bugs with big eyes. The light moves through the day: warm gold
  morning, white noon, peach dusk, blue night with glowing fireflies.
  - **Closing tracks the hinge:** as c grows, the teeth lean inwards and the lobes' edges darken, so the screen agrees
    with your hands. At the snap the teeth slam to a closed-jaw silhouette at both outer edges for 0.12 s, the
    caught bugs squish into the midrib with a juice splat, and the numbers pop.
