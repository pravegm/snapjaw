# Scene R6 hand-off (Scene engineer)

Only `Snap/Scene/`, `SnapTests/SceneTests.swift`, this note and `design/NEEDS.md` changed. Nothing is compiled yet. I
re-read every touched file twice for compile errors (CGFloat/Double, MainActor isolation, labels, exhaustive switches
over `TrapVariety` / `TrapToothKind` / `BugSpecies`, no key-path or mutating calls inside `#expect`, `CGFloat.nan`
spelt out, no local shadowing a static). Frames checked: R5 10, 11, 13, 14, 16, 17, 19, 33, 35, 37, 39, 41.

## What changed
- **Varieties (new `TrapVarieties.swift`).** `TrapArt.look(_:)` is every cultivar's look (an exhaustive switch):
  colours, the cilia's cut (`TrapToothKind`: `.cilia`, `.saw`, `.shark`, `.fused`), their length and width, B52's
  `spread` (the lobes drawn 3 % wider about the midrib), the cup's depth, the gloss, Golden Glow's gold sheen and
  twinkles, the closed trap's stops, the glyph's and the hero's colours. Classic's look is R5's exactly.
  - Classic as R5. Red Dragon is crimson inside and out (face, lip, leaf back, closed backs, hero front lobe).
  - B52 has 1.28× longer, 1.9× wider cilia and wider lobes. Sawtooth has short jagged notched teeth.
  - Shark Tooth has broad triangles. Fused Tooth has round scallops that touch, so the row reads as a frill.
  - Cupped Trap has a 2.1× cup, a second wet glint and 1.6× gloss. Golden Glow has a gold rim, gold cilia and twinkles.
  - Drawn everywhere: `BogArt.drawLobe/drawTooth/drawClosedTrap(…, variety:)`, `TrapArt.teeth/teethPath(…, variety:)`,
    `TrapArt.trapImage(width:scale:variety:)`, `trapImage(style:width:scale:sippingBug:variety:)`,
    `drawThreeQuarterTrap(…, variety:)`, `TrapPose.draw/bounds/backCilia/frontCilia(variety)`,
    `TrapArt.snapGlyph(…, variety:)` (both sizes). All default to `.classic`, so every R5 call is unchanged.
  - **Scene:** `BogScene.variety` re-dresses the lobes, the 76 cilia sprites (reused), the closed trap and the
    economy's glyphs. Textures are cached per variety (`BogTextures.varietyKey`; Classic keeps its R5 keys) and built
    once at the set (`BogTextures.warm(variety:)`), never per frame. Tooth textures are sized per cut
    (`BogArt.varietyToothTexSize`). The teeth's canvas clamp allows for B52's spread.
- **FEAST event** (`FeastEvent.isBig`: a clean bite of `Tuning.bigFeastCount` (5)+ bugs, or one scored at ×4+):
  - an 80 ms hit-stop (`bigHitStopTime`), a 6 % camera punch and a 16 pt shake;
  - a gold juice burst (`BogEffects.feastBurst`) and banner sparkles;
  - a big "FEAST!" banner (68 pt, `BogPops` banner style: in from 0.35 to a 1.42 overshoot), with "×6 · +720" under it;
  - the caught bugs held in the closing jaws over the closed trap, then gulped into the midrib one after another,
    nearest first (`FeastEvent.gulpDelays`: ≤ 70 ms apart, all in by 0.46 s), each with a gold sparkle;
  - the snaps row's refill flourish (`BogEconomy.flourish`: a gold glow and a sparkle sweep, after the glyphs land).

  A 3–4 bug Feast keeps the R5 look. A stung bite is never an event.
- **Gold juice.** The spray (`juiceColor` #FFC83D), the splat glisten and the catch sparkles are nectar gold.
- **#5 dusk and night (`BogLight`).**
  - Dusk: a multiply of (1, 0.62, 0.7), a peach lift of 0.14 and a peach sky glow of 0.52. The top of the bog is ≈
    #E1B084, peach. A new warm sun glow (`light.sun`, z 6.6, additive, bog only) sits top-left.
  - Night: a deep blue (≈ #0B2B4A at the bottom → #1A3E77 at the top), not teal.
  - Fireflies bloom bigger at night. Crickets get a moonlit sheen. Both keep most of their colour under the night tint.
- **#7 clearance (`BogBugLayer.clearOffset`, pure).** Every uncaught bug is drawn with a small eased nudge, so that:
  - its footprint (a bee's ring too) is 6 pt inside the canvas. A resting bug is pushed fully in; a flyer is eased in
    (`edgePush`), so one entering never pops;
  - outside the trap, it is clear of the HUD's corners (`BogScene.hudKeepOut`, else `defaultKeepOut`);
  - while it rests in the trap, it is Core's clearance off the midrib.

  Caught bugs start from where they were drawn.
- **#17 the tired trap.** Tiredness no longer drives the closure shades (they cover the margin and back). The tired
  trap dims its face only (`faceDim`, the new face-only `BogTextures.lobeFace`); the hunger veil is face-only too. The
  green margin, the back and the cilia stay bright.

## New API for the App and Feel
| API | What it's for |
|---|---|
| `scene.variety` | The Garden's pick (SceneHooks already sets it). |
| `scene.hudKeepOut: [CGRect]?` | The HUD's plates in scene space (see NEEDS). |
| `FeastEvent.isBig(_:)`, `.gulpDelays` | The FEAST rule (pure), for Feel's CHOMP and the App's freeze. |
| `TrapArt.snapGlyph(…, variety:)` | The HUD row's glyph in the chosen variety. |
| `scene.lastBiteWasFeastEvent`, `lastHitStop`, `banners`, `rowFlourishing`, `gulped(ofBug:)` | Read-outs (tests, CI). |
| `scene.bogSunAlpha`, `tiredFaceDim`, `marginShade`, `rimSparkles`, `drawnToothTips`, `bugKeepOut` | Read-outs. |

## Tests (SceneTests)
- `everyVarietyDrawsNonEmptyPaths`: every cut and every variety's teeth, hero cilia, images, glyphs, closed trap; the
  cultivars' differences (pixels: Red Dragon's back is red, Golden Glow's rim gold); the scene draws each with no
  texture built per frame and every cilium inside the canvas.
- `theFeastIsAnEventFromFiveBugsOrAFourChain`: the threshold, the 80 ms hit-stop, the banner, the punch, the gulps one
  after another, the flourish; 3 bugs, ×4 with 2 bugs, and a stung 6.
- `noHaloIsClippedAndNothingParksInTheHUD`, `theTiredTrapKeepsItsGreenRim`, `duskIsAPeachSkyAndNightIsBlue` (with the
  gold splat).
- Updated: `paletteContrast` (the juice is gold), `theEconomyFliesToTheHUD` (a 5-bug bite now shows the banner).

## Risks
- Hand-tuned: the dusk numbers are arithmetic (Node), not by eye. Check the wave-18 and night frames.
- Golden Glow's rim and the Red Dragon's back are checked by pixel at fixed points. Nudge the point, not the art.
- The nudge is cosmetic and bounded. The real fix for spawn spots is Core's (NEEDS).
- Feel's `isFeastChomp` and the App's `isBigFeast` don't exclude stung bites; the Scene does (NEEDS).
