# Scene R1 hand-off (Scene engineer)

Everything is in `Snap/Scene/`, plus `SnapTests/SceneTests.swift`. Nothing has been compiled yet (CI is blocked). I
re-read every file twice looking for compile errors (isolation, CGFloat/Double, labels against Contracts, exhaustive
switches).

## Files
| File | What it holds |
|---|---|
| `TrapArt.swift` | `SnapPalette`, `TrapArt.palette`, `TrapTooth`, closure maths (`closure01`, `toothLean`, `toothReach`), lobes (`lobePath`, `lobeFacePath`, `halfEllipse`), `midribPath`, `veinsPath`, `triggerHairs`, `rimGlands`, teeth (`teeth`, `toothShape`, `teethPath`). Pure CG, nonisolated. |
| `TrapArtBugs.swift` | The 16 species: `TrapBugArt` (layered paths), `TrapBugStyle` (colours, flap Hz, rest spread, fuzz), `bugBody`, `bugWings`, `bugColors`, `bugArt`, `drawBug`, `drawWings`, `bugImage` (CGImage for SwiftUI: Bug Book, Home), `flippedVertically`, `defaultRadius`, `bugExtent`. |
| `BogPaint.swift` | `BogPaint` (colours, WCAG contrast), `BogMath`, `BogRNG`, `BogPainter` (pure CGContext rendering `image(width:height:scale:draw:)`, gradients, dew drops). |
| `BogArt.swift` | Static art drawn once: the bog backdrop (water, lily pads, reeds, moss, sundews, rosettes, dew, the trap's shadow), lobe face, closure shades, gloss, slam jaw, night glow, midrib, fold band, tooth, nectar, hair, nectar glisten, whiff, startle, anger mark, rings, halo. |
| `BogTextures.swift` | `@MainActor` texture cache. `warm(size:radius:)` builds everything up front. Drawing closures call only nonisolated code. |
| `BogJaws.swift` | `BogLobeSide` and `BogJaws`: two lobes, 42 tooth sprites, midrib, fold band. Closure tracking, the slam, the re-arm spring, the tired droop. |
| `BogBugs.swift` | `BogBugNode` and `BogBugLayer`: pooled per bug id. Flaps, folded wings, bob, sip, twitch, lift and shadow, sip ring, bee halo, firefly glow, the squish into the midrib, the cross mark on released bees. |
| `BogSurface.swift` | Nectar drops (fade in and out with the seeding, wobble while sipped, twinkle, glow at night) and the 6 trigger hairs (they glow when a bug walks on one). |
| `BogLight.swift` | The day light from `dayClock` (5 keys), sky haze, vignette, dew twinkles, 10 bog fireflies at night. |
| `BogEffects.swift` | Particle pools (nectar spray, sparkles, puffs), flashes (glistens, whiffs, startles, landing ripples), `BogPops` (score callouts). |
| `BogScene.swift` | The scene: node tree, frame loop, events → FX and pops, camera punch and shake, touches. |

## The look
- **Bog:** an emerald gradient lit from the top-left. Mottled peat. A water band along the bottom with sky glints and lily pads (one has a flower). Reeds behind the trap at the sides. Moss cushions in the corners (overlapping lit bumps with stipple). Red sundews with dew-tipped tentacles. Grass tufts above the trap. Glossy dew drops. A soft contact shadow ring just outside the trap. Everything is drawn only outside the trap (normalised radius > 1.1).
- **Lobes:** each lobe is a dark-green outline and a lime margin with a wet highlight. The face is crimson, deep by the midrib (`lobeInner`) and bright towards the rim (`lobeOuter`). The face also has:
  - darker ends and a coral glow at the margin;
  - a faint lighter band plus a row of tiny glands at r = 0.84, so the rim zone reads;
  - 420 pores and embossed veins;
  - shade by the midrib and a broad sheen.
- **Gloss:** a separate sprite with two curved specular streaks and wet beads. It slides and fades as the trap closes.
- **Teeth:** 21 per lobe, pale cilia with lime roots and bright tips, evenly spaced by arc length. They are longest at the outer middle.
- **Closure (`closure01 = closure / Tuning.snapDepth`):**
  - Each tooth swings over the rim like a 3-D lean seen from above, with projected length `cos(c × 120°)`. The teeth shorten, point at you at about 0.75, then point inwards.
  - The lobes foreshorten 3 % towards the midrib.
  - Two cached shades (narrow, then wide) darken the lobes from the outer edges in.
  - The teeth dim slightly.
- **Slam** (on `snapped`):
  - The teeth flip to a 165° lean, interlocked.
  - The far lobe's dark jaw sweeps in from beyond each outer edge (scale 1.16 → 1 over 60 ms), holds for 120 ms and releases by 0.5 s. It shows a dark band, the far lobe's lime edge and dark tooth silhouettes between ours.
  - A vignette pulse, a camera punch (1.03 → 1) and a shake that grows with the bugs caught. Reduce Motion turns off the punch and shake.
- **The catch is a cheeky gulp, never gore (4+ rating, founder's note):**
  - Caught bugs shrink, spin and get pulled into the midrib whole over 0.5 s.
  - A pale green-gold nectar spray, a short-lived pale glisten on the lobe, gold sparkles and a white puff.
  - Nothing red: crimson appears only on the lobe interior.
- **Released bees:** they fly off with a red cross mark bobbing over them, unharmed.
- **Bugs:** chunky top-down cartoons, facing +x, with a dark outline, a radial-gradient body, markings, shine and big white eyes with pupils and glints.
  - **Bees:** yellow with dark bands, fuzzy, rosy cheeks, a white pulsing halo.
  - **Bumblebees:** round, fuzzy, white tail.
  - **Wasps:** angular, with a pointed abdomen, chevrons, mean slanted brows and a **red** halo.
  - **Moths:** spread wings with eye spots, flapping slowly.
  - **Dragonflies:** wings spread at rest.
  - **Fireflies:** a glowing lantern, plus an additive blink that gets stronger at night.
  - **Golden Scarab:** a gold shimmer glow.
- **Wings:** flying bugs flap them with a y-scale cycle at their species rate; fast flappers also get a soft blur. Landed bugs fold them to their rest spread, or hide them under wing cases (ladybird, firefly, scarab, grasshopper). Grasshoppers flash their wings open when they hop. Restless bugs twitch and flick their wings.
- **Shadows and sipping:** the shadow is offset and softened by height, and the bug is drawn lifted and larger. Sipping bugs get a pulsing gold ring and a head-bob.
- **Light:**
  - A multiply tint over the bog and trap: warm gold (0), white (1), peach (2), blue (3), deeper blue (4).
  - An additive sky haze.
  - Bugs get a lighter tint of their own: a colour blend of at most 0.36, never a replacement, so they stay readable.
  - At night: the trap glows pink, the nectar glows, bog fireflies drift and blink, and the dew stops twinkling.
- **Pops:** big rounded black labels with a stroke and a drop shadow. They pop in with an overshoot, rise and fade on the FX clock, stacked at the centroid of the caught bugs:
  - "+240" (gold);
  - "TRIPLE ×3" (DOUBLE, QUAD, FEAST ×n);
  - "chain ×1.5";
  - "Feast! +1 snap";
  - "Lucky! +1 snap" or "Golden! +2 snaps";
  - "Bzzt!" or "Stung!" plus "−n snaps" at the stinger;
  - "New best!".

## Node structure (scene z)
```
world (camera punch) → shaker
  backdrop 0 · jaws 10 (fold band 1, lobes 10, shades 11, gloss 12, glow 12.2, midrib 13, jaw 13.5, teeth 14)
  surface 15 (nectar, hairs) · glistens 16 · TINT 20 (multiply) · haze 21 · twinkles/fireflies 21.5
  bug shadows 22 · ripples 23 · bugs 30 (+6×height) · nectar night glow 41 · FX 50 · pops 60
vignette 70 (not shaken)
```
Typical node count is about 330: 42 teeth, about 8 per bug, and fixed pools. Per frame the scene only sets
transforms, alphas and blend factors. It never builds a path or a texture; the test `sceneDrawsEveryBugAndNectar`
checks that the cache count doesn't grow.

## Clocks
- **Moments** (slam, FX, pops, punch, spring) run on the session clock (snapshot time delta). A pause or a CI `freezeOn` therefore holds them at that instant; `freezeOn=snap` (0.12 s) lands in the slam's hold, with the pops up.
- **Ambient life** (flaps, bobs, twinkles, fireflies) runs on wall time.
- If the snapshot time goes backwards, the scene resets itself.

## API notes for the App
- The contract API is exact: `init(layout:)`, `driver`, `reduceMotion`, `layout` (settable; rebuilds the backdrop only when the width changes), `reset()`.
- Extras:
  - `show(_:events:dt:)` (tests and previews without a driver) and `tap(at:time:)`;
  - read-outs: `drawnFrames`, `jawSlam`, `drawnClosure01`, `toothReach`, `liveBugNodes`, `popTexts`, `nightLevel`, `cameraScale`, `foldBandShowing`, `visibleFireflies`, `drawnPoint(ofBug:)`, `nodeCount`.
- For SwiftUI (Bug Book, Home), `TrapArt.bugImage(_:radius:scale:wingSpread:silhouette:)` renders the exact scene art as a `CGImage` (use `silhouette: true` for unfound entries). `TrapArt.flippedVertically` flips paths for y-down drawing.
- Bug radii come from `BugCatalog.info(s).radius`, falling back to `TrapArt.defaultRadius`, which matches the brief.

## Deviations and risks
- `SKBlendMode.multiply` drives the day tint. Neither sister project has used it. It is an opaque full-scene sprite, hidden at noon. If it looks wrong on device, the fallback is a normal-alpha overlay; the change is in `BogLight` only.
- Colour blends on coloured textures stay at or below about 0.6, so it doesn't matter whether SpriteKit's colorize multiplies or mixes.
- The closure the scene receives steps at the hinge rate (Feel's note in NEEDS). R2 could draw from `HingeTrapSource.predictedAngle` for smoother teeth.
- Texture memory is about 35 MB: backdrop @2x, 2 lobes and 2 jaws @2x, shades @1x.
- Bees and wasps both get halos (white for bees, red for wasps) so a protected bug always reads as protected.
