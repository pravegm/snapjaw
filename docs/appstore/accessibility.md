# Snapjaw: Accessibility Nutrition Labels (v1.0)

*Decided Tue 27 Oct 2026 by the launch lead, from the design (`design/GAME-DESIGN.md` §3–§10, `design/ROUND-1.md` Settings and Scene briefs); the build doesn't exist yet. The rule, the same as Squish, Brim, Swoop and Hush: **claim a label only when the build earns it across every common task**, and verify on the release build first. Labels are voluntary, per device, and can only be published once a version is live, so this happens on **launch day, Tue 8 Dec** (runbook §6). The App Store Connect tool doesn't set labels: the founder ticks them by hand.*

Common tasks for Snapjaw:
1. the first launch: get through **First Bite** (or skip it after step 2);
2. start **Feed**, the **Daily Bog** or the **Zen Bog** from Home, and read the **Goals** card there;
3. play: watch bugs land, tell a bee from a fly, snap (a short fold on a Duo; a tap elsewhere), open again, read the HUD (score, snaps as little trap icons, the chain chip, the one-line hint) and the in-world pops ("TRIPLE ×3", "Feast! +1 snap", the big "FEAST!" banner, "Goal done!", "Bzzt!");
4. pause (Resume, Restart, Home; the run's goals; **End** in the Zen Bog);
5. read the Results card (the score, or bugs caught in the Zen Bog; best bite, best chain, bees spared, the goals ticked and their growth, the Daily streak and **Share**, new Bug Book pages, the next Bug Book clue, rank bar, a new flytrap);
6. open the **Bug Book**, and the **Garden** to pick a flytrap;
7. change **Settings** (Sound, Haptics, Respect silent switch, Score on the left, Reduce motion, Replay First Bite).

## What the design gives us (to be confirmed on the build)

- **Two ways to snap:** the hinge (Duo) and a tap anywhere (any iPhone without a hinge). A tap is a single touch, no hold and no gesture, which helps motor access and works with Switch Control on those phones. On a Duo there is no touch alternative in the design (`metadata.md` §11 ask 6 proposes "Play with touch").
- **Bees don't depend on colour:** bees, bumblebees and wasps get a white "protected" halo ring (a shape), stripes and their own body shapes (ROUND-1 Scene brief), the hint "Bee! Wait…" in words, a distinct hum, and "Bzzt!" as a word on a sting.
- **Sipping has a ring, not just a tint:** a sipping bug shows a soft gold ring (a shape) and a tiny bob.
- **Every landing is felt and heard, not only seen:** a haptic tick per landing (by bug size) and a soft "tik", and each buzz is panned to where the bug is. This helps players who miss a bug on a softened half.
- **Words for every outcome:** "Double ×2", "Triple ×3", "Quad ×4", "FEAST ×5+" and the big "FEAST!" banner, "Feast! +1 snap", "Goal done!", "Bzzt!", "Your trap is tired", and the hint line ("Snap it — quick!", "Open up to reset", "Last snap — make it count", "Now!").
- **Reduce motion:** a setting in Settings (ROUND-1) that the scene reads (`BogScene.reduceMotion`). **Ask (App engineer):** default it to the iOS setting (`UIAccessibility.isReduceMotionEnabled`) so a player who has Reduce Motion on in iOS gets it without visiting Settings, and say so in the row.
- **Sound and haptics:** Sound on/off, Haptics on/off, Respect silent switch.
- **HUD side:** "Score on the left" ("Your score and snaps on the left half") lets a player put the score and snaps on the half they see best.
- **R6, the Zen Bog:** no snaps running out, no hunger and no timer, so a player who can't keep up with the bog still plays, fills the Bug Book and completes goals marked Zen or Any mode. It helps players with slower reactions or motor limits, but it doesn't earn a label by itself.
- **R6, the Garden and goals** are words and shapes: locked flytraps are silhouettes with a lock and their rule in words ("Reach Nibbler", "Goal: A 6-bug bite"); goals show a ring that ticks and a number ("0/12").

## The answer, at a glance

| Label | 1.0 answer | Status | Why |
|---|---|---|---|
| VoiceOver | **No** | Decided | Menus will be labelled, but play (task 3) depends on seeing where bugs land and whether a bee is among them. Apple's bar is all common tasks |
| Voice Control | **No** | Decided | The snap needs timing on a moving crowd; there's no spoken alternative |
| Larger Text | **No** | Decided | No Dynamic Type in the design; the HUD and pops are fixed-size scene labels. Never tick it unless 1.0 is built with it |
| Dark Interface | **No** | Decided | The default play screen is a sunlit bog (only the night phase is dark) |
| Differentiate Without Color Alone | **Yes**, if check A passes | **Verify** | Bees have a halo shape and a word; sipping has a ring; every score state is a word |
| Sufficient Contrast | **Yes**, if check B passes | **Verify** | HUD text and pops sit over a busy, changing bog (gold morning to blue night); they need an outline or a backing plate everywhere |
| Reduced Motion | **Yes**, if check C passes | **Verify** | The camera punch, the screen vignette and juice FX must calm down; the bugs and the jaws still move (that's the game) |
| Captions | **No** (not applicable) | Decided | No dialogue, video or audio-only content |
| Audio Descriptions | **No** (not applicable) | Decided | No time-based video content |

**Publish for iPhone: Differentiate Without Color Alone, Sufficient Contrast, Reduced Motion**, each only if its check below passes on the release build. Leave every other box unticked. If a check fails, leave that box unticked: an honest "not indicated" beats a false claim.

## Checks (on the release build, on a Duo and on a non-Duo iPhone)

### A. Differentiate Without Color Alone
- [ ] With **Settings > Accessibility > Display & Text Size > Color Filters > Grayscale** on, a tester can tell a bee, a bumblebee and a wasp from every edible bug at a glance (halo ring, stripes, shape), at day and at night.
- [ ] A **sipping** bug is visible by its ring and bob, not only by a gold tint.
- [ ] The **snaps** count is readable by the number of trap icons (filled vs empty differ by shape or outline, not only colour). The last snap shows its hint words.
- [ ] The **chain** chip shows the multiplier as text ("×2.5"), not only a colour.
- [ ] The **rim** (bugs half in, react faster) needs no colour to play: it's a skill detail, not a state the player must read. Fine as is.
- [ ] Locked Bug Book pages are **silhouettes** with "?" or a lock glyph, not only greyed colour.
- [ ] Locked **Garden** flytraps are silhouettes with a lock and their rule in words; the picked one has a check mark, not only a gold ring (R6 frame 44 shows both).
- [ ] **Goals** read done by the tick in the ring and the number, not only by turning green; a spoiled goal (dimmed in the pause menu) is also readable without colour, or the dimming is only a hint.
- [ ] Selected options in Settings show a toggle position or check mark, not only a tint.

### B. Sufficient Contrast
Apple's bar: about 4.5:1 for text, 3:1 for large text, controls and state indicators.
- [ ] HUD text (score, the chain chip, the hint line) and the in-world pops ("TRIPLE ×3", "Feast! +1 snap", "Bzzt!") keep ≥ 4.5:1 (3:1 for the large ones) against **every** phase's light (warm gold morning, white noon, peach dusk, blue night) and over the crimson lobes. White on noon light won't pass without an outline or plate.
- [ ] The snaps icons, the pause button and First Bite's Skip reach 3:1 against what's behind them.
- [ ] Menu, Bug Book and Results text ≥ 4.5:1 on its panel, the quiet lines included.
- [ ] Check with Increase Contrast and Bold Text on.

Measure with a contrast checker on the release-build frames (the CI store frames) and paste the ratios here (Brim's table format).

### C. Reduced Motion
- [ ] With Reduce motion on (the in-app setting, and iOS Reduce Motion if the ask above is built): no camera punch (the 1.03 → 1 scale at the bite), no screen vignette flash, no shake on a sting; firefly blooms don't pulse.
- [ ] **The big FEAST (R6)** with Reduce motion on: no camera punch and no banner overshoot; the 80 ms hit-stop and the gold burst are short and calm; the gulps and the snaps refill still read. The goal toast and the variety-unlock fanfare fade rather than spring.
- [ ] The jaw slam is still shown (it is the game's feedback) but without the camera move; juice FX are a short fade.
- [ ] Menu transitions become fades or short moves, not springs and slides.
- [ ] Bugs flying, the jaws following the hinge and the day's light still move: that motion is the game itself, which Apple's criteria allow.

## What we can say in copy today

The description says: "Sound and haptics each have a switch, and there's a Reduce motion setting" and "On any other iPhone, tap anywhere to snap". None of this claims a VoiceOver, Voice Control or Larger Text label. If check C fails, cut "and there's a Reduce motion setting" from the description too (or keep it, since the setting exists, but don't tick the label).

## 1.0.1 list to earn more labels honestly

| Fix | Size | Earns |
|---|---|---|
| "Play with touch" on a Duo (tap to snap, hinge ignored) | S | Motor access on the Duo; makes Switch Control work there |
| Spoken crowd cues for VoiceOver ("Three bugs sipping, no bees", "Bee in the trap") announced as the scene changes, plus a double-tap-anywhere snap | M | VoiceOver (maybe), and helps low-vision players |
| HUD, Results, Bug Book and menus scale to AX3 with reflow | M | Larger Text |

Re-check the labels with every update; add one only after the fix is on device and tested.

## Sources
- App Store Connect Help, *Overview of Accessibility Nutrition Labels*: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- App Store Connect Help, *Manage Accessibility Nutrition Labels* (publish only for devices with a live version): https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels
- Swoop's label decisions (method mirrored): `C:\Users\59527\Wing\docs\appstore\accessibility.md`
