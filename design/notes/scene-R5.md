# Scene R5 hand-off (Scene engineer)

Only `Snap/Scene/` and `SnapTests/SceneTests.swift` changed. Nothing is compiled yet. I re-read every touched file
twice for compile errors (CGFloat/Double, MainActor isolation, labels, exhaustive switches, no rethrowing or key-path
calls inside `#expect`, no local shadowing a static of the same name). Frames checked: R4 13, 14, 18, 39, 41, 42 (the
release and the pops), 10, 16, 37 (dusk and the crease), 20, 26, 32, the icon and the badges. `artifacts/duo4/` doesn't
exist yet, so the Duo checks use the R3 frames.

## What changed
- **#3, the release (`BogJaws`).** The bite's darkening now follows the slam only while it closes and holds
  (`BogJaws.biteShade`). It fades to nothing `releaseFade` (80 ms) into the release.
  - So 80 ms after the hold the face is the open-state crimson again, the closure shades are off, and the green rim
    and margin show.
  - The open cilia come back out and stand straight (`teethAlpha`, lean) by then.
  - The closed trap is gone 60 ms into the release (`closedFade`). It used to linger on `slamLevel`.
  - The lobes reopen on an ease-out (`squeezeLevel`, about 60 % open at 80 ms), so the reopening trap is never narrow.
  - "Darken only while closing" also covers the hinge. After a bite, the hinge's own darkening and cilia lean are
    held off (`reopenHold`) while the hands stay shut or reopen. They come back once the hands close again by
    `reclose` (0.08 of the snap depth). On the Duo the trap no longer sits dark at 22° after a bite.
  - The foreshortening still tracks the hands.
- **#6, one hero trap (`TrapArtPose.swift`, rewritten).** `.threeQuarter` is now the icon's own drawing. Every curve is
  `AppIconPainter`'s, scaled from its ±320 corners (`TrapPose.unit`) and flipped to y up. The tilt is the icon's
  (+0.2 rad y up, so the right corner rises; R4's tilt went the other way).
  - The jaws are open: the back lobe's glossy crimson face (the icon's #F46A7E → #D93A56 → #7E0E2A, its gloss crescent
    and glint), with a dark-green band and a lime margin beyond it.
  - The front lobe has a green outside, its crimson inner band and a lime lip.
  - Cilia run on both lips: a 13-hair crown on the back and an 8-hair fringe on the front, with the middle left bare.
    They have a fine dark outline, so they match the outlined bugs in the badges.
  - A short broad stem, then a soft shadow.
  - No stipple and no face veins.
  - `sippingBug:` puts the game's fly on the face just above the mouth, with a dark halo like the icon's.
  - The aspect is ≈ 0.97 (it was > 1 with a long stem), so the cover and pose card's `min(aspect, 1)` clamp is honest.
  - The stem is short, so it shouldn't break a badge ring.
  - The API is unchanged: `trapImage(style:width:scale:sippingBug:)`, `drawThreeQuarterTrap`, `threeQuarterAspect`,
    `TrapPose.bounds/turn/halfSpan/height`. `TrapPose.height` is still the back lobe's peak, so
    `SceneHooks.threeQuarterPoint` keeps landing badge bugs on the face.
- **#9, dusk (`BogLight`).** The R4 multiply (1, 0.7, 0.52) cut the bog's blue harder than its green, and that was the
  olive-khaki. The dusk key is now:
  - a multiply of (1, 0.74, 0.82), which keeps the blue;
  - a rose lift of (1, 0.6, 0.62) at 0.12;
  - a new **sky glow** (`light.sky`, z 6.5, additive, the haze ramp from the top) of peach (1, 0.62, 0.5) at 0.34.
    It is on the bog only, under the trap.

  Over the trap there is only a faint rose haze (0.10, was 0.22), the deep warm overlay, and a rim of 0.12 (was 0.48),
  so the salmon ring at the margin is gone. `BogLight.litBog` reproduces the composite for tests: the top of a dusk bog
  is peach (r ≥ g, b > 0.7 g), and the R4 key fails that check.
- **#10, "Missed!".** On a dry snap there is now a pale dusty puff at the seam (upper third) as well as the old one.
  `BogScene.missedLabel` "Missed!" (32 pt, pale #E9E2D0, short rise) sits beside the seam on the half without the HUD,
  clear of the crease. It also shows on Home.
- **#12, pop collisions.** `placePop` now keeps each pop's whole footprint (its overshoot box, swept up its rise, plus
  `popGap`) off every free bug and every live pop.
  - It tries nearby spots nearest-first (`popOffsets`; downward first for the lines under a callout). If no spot is
    clear, it takes the least overlap.
  - Caught bugs don't count: they reach the seam in 60 ms.
  - Stacks spread out: each line under a callout is placed below the previous one's footprint (`lineStep` 56 of room).
  - Glyph flights take the arc that crosses the fewest live pops (`BogEconomy.route`). The candidates are the R4 high
    arc, a low arc, a dogleg or a higher arc, with the start nudged off the stack. So a glyph doesn't fly over
    "Golden!".
- **#15, the airborne cue (`BogBugs`).** Any uncaught bug whose centre is within `creaseHalfWidth` + 0.6 r of the
  midrib is drawn 1.1× (`creaseScale`). Its shadow is pushed out by at least (10, −8) (`creaseShadow`), a little smaller
  and softer. The effect eases off over one more radius.

## New or changed API for the App
| API | What it's for |
|---|---|
| `scene.faceShade`, `scene.biteShade`, `scene.ciliaAlpha` | Read-outs (tests, CI). They show the release is crimson by 80 ms. |
| `scene.bogSkyAlpha`, `BogLight.Key.sky/skyAlpha`, `BogLight.litBog` | The dusk sky glow. |
| `scene.bugRects`, `scene.glyphPaths` | Read-outs: what the pops avoid, and where the glyphs fly. |
| `scene.creaseCue(ofBug:)`, `scene.shadowOffset(ofBug:)` | Read-outs for the airborne cue. |
| `BogScene.missedLabel`, `.missedColor` | The dry-snap word, if the App wants to match it. |
| `BogEconomy.fly(…, avoid:)` | Already called by the scene with `livePopRects`. Nothing for the App to do. |

## Needs from the other modules
- **App:** look at the first CI render of Results, the cover and the badges with the new hero. It is taller at the
  back (the crown) and has a shorter stem; the badge compositions may want re-centring. Nothing in the API changed.
  The App's #12 side (the attract fly, "Golden Scarab" in the book) is still yours.
- **Feel:** the "clop" for #10 is yours; the scene's "Missed!" fires on the same `.drySnap` event.
- **CI:** capture 14/39 at about 0.26 s after the bite, which should now show an open crimson trap with cilia. Capture
  wave 18 for the peach dusk. The 41 dry snap should show "Missed!".

## Tests added or changed (SceneTests)
- `theReleaseIsCrimsonWithinEightyMs`: the closed form (`biteShade`, `squeezeLevel`), and a scene bite with the hands
  still shut. From 80 ms it checks shade < 0.02, the drawn face crimson, the cilia out, the closed trap gone and the
  lobes wide. Opening is still crimson; closing again darkens again.
- `popsNeverSitOnABug`: the R4 18 case. No pop box touches a free bug for 40 frames.
- `stackedPopsSpreadOutAndGlyphsMissThem`: the R4 42 case. The glyph arcs miss "Golden!", and no two pops overlap.
- `aDrySnapSaysMissed`: "Missed!" beside the seam, on the non-HUD half, for both HUD sides.
- `duskIsPeachNotOlive`: the composite, with the R4 key as the negative.
- `nothingRestsOnTheHinge`: 1.1× and the shadow offset over the crease, and nothing away from it.
- `theHeroTrapIsTheIconsTrap` replaces `theIsolatedTrapIsThreeQuarterTilted`. It checks the icon's geometry and tilt,
  and pixels for the crimson face (smooth: no stipple), the lime margin and lip, the green band, the front lobe and the
  stem, and a cream crown hair. It also checks the cilia on both lips, an aspect ≤ 1, and the fly.
- I updated the R4 dusk expectations (`nightKeepsTheTrapCrimson`, `duskShowsThroughWave22AndNightStartsAt23`). Their
  "rim > 0.4" and "blue < 0.6" checks were the olive and the salmon ring. They now check the sky glow, a rim ≤ 0.15 and
  a multiply that keeps its blue.

## Risks
- The pixel tests sample fixed points (worked out from the curves in Node). If an antialiased edge lands on one, nudge
  the point, not the art.
- The pop search moves lines further from the callout when bugs crowd it. If a frame looks disconnected, lower
  `lineStep` or make the lines' footprint ignore the callout's rise.
- Dusk is tuned by arithmetic, not by eye. Check the wave-18 frame. If it is too pink, lower `sky` alpha to 0.26.
