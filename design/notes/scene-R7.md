# Scene R7: distinct traps, clear zones, a real night

Brief: `design/ROUND-7.md`, Scene items #1 (P0), #4 and the Scene part of #14. Files: `Snap/Scene/*` and
`SnapTests/SceneTests.swift` only. **Not compiled locally.** CI is the compiler.

## #1 (P0): 8 varieties that read apart at 120 pt

All of it is cosmetic. The trap zone (`TrapGeometry`), the cilia count (`teethPerSide`) and the play spread (≤ 3 %)
are the same for every variety. `TrapLook` (`TrapVarieties.swift`) has new hero-only fields, each with a default, so
Classic is unchanged:

| field | what it does |
|---|---|
| `heroLobes: CGSize` | scales the hero's lobes about the hinge before the tilt (B52 1.15 × 1.15; Cupped 1 × 1.22) |
| `heroTeeth: Int` | the back crown's count (Classic 13) |
| `heroToothLength`, `heroToothWidth` | the crown's and fringe's cut over Classic's (the play's `toothLength`/`toothWidth` stay separate) |
| `heroFrill: RGBA?` | Fused Tooth: a continuous frill base under the scallops (`TrapPose.frillPath`) |
| `heroRimLine: RGBA?` | Cupped: a dark line down both rims |

The looks, the same in play (lobes, cilia, closed trap, snap glyph) and on the hero (Garden, Results, cover, badges):
- **Classic:** as R6.
- **Red Dragon:** as R6 (crimson inside and out).
- **B52:** the hero's lobes are 15 % larger, with 11 fat, long cilia (1.5 × 2.3), a deeper wine face and a dark leaf.
  In play: cilia 1.4 × 2.2, and the 3 % spread.
- **Sawtooth:** 25 short red saw teeth on an amber margin. In play: red-tipped saw teeth and a bronze lip.
- **Shark Tooth:** 9 wide ivory triangles on a scarlet-coral face (play face too).
- **Fused Tooth:** one lime frill: 15 touching scallops over a continuous base.
- **Cupped:** a deep cup (the hero is 22 % taller), a strong gloss (1.9, with a second glint and a wet sheen) and a dark
  rim (olive margin, dark rim line). In play: cup 2.4, gloss 1.9, dark lip and leaf.
- **Golden Glow:** a gold interior (hero and play; the play face is deep amber at the midrib so the nectar still
  reads), gold closed-trap seam and glyph, plus the R6 sheen and twinkles.

`TrapPose`: `lobeScale(_:)`, `stemDrop(_:)`, `stemTurn(_:)` (the stem and its shadow drop under a taller belly and
are never scaled) and `variedTurn(_:)` (now `lobeScale` then the tilt; B52's hero no longer uses `spread`).

**Test:** `theEightVarietiesReadApartAtAThumbnail` renders each Garden glyph (`TrapArt.drawThreeQuarterTrap`, 120 pt
at 1×, on the card green `#1E4A2A`) and asserts that every one of the 28 pairs has a mean absolute RGB difference of
≥ `SceneTests.varietyFloor` (0.015). It prints `SNAP-VARIETY-DIFF` with every pair's value. My estimates (untested):
the R6 near-copies were about 0.01, and R7's weakest pair is about 0.03. If CI fails, read that log line before you
move the floor. `everyVarietyDrawsNonEmptyPaths` now expects `heroTeeth` crown cilia, not 13.

## #4: clear zones as a tested rule

Spawn and wander are Core's (`TrapSession.findSpot`), outside my files, so the Scene enforces the rule where it draws:
- `BogBugLayer.clearance(...) -> (offset, clear)` is new. `clearOffset` wraps it, with a new optional `hudGap` and
  `prefer`. A **sitting** bug (walking or sipping, centre on the canvas) is drawn, on every frame, with its footprint
  (its halo included):
  - inside the edge margin (`edgeGap`);
  - off the midrib band, in the trap or beyond it: `midribClearance` = `creaseHalfWidth` + max(r + 16, half + 2),
    so a bee's halo clears it too;
  - clear of every keep-out. It goes by `hudGap` outside the trap. It now also goes clear in the trap: an R6 test
    expected an in-trap bug by the HUD corner never to move, and that test is updated.
- The eased nudge (R6) still runs first. A hard pass then projects whatever the easing left, so the rule never lags.
  The way out favours last frame's direction (`wayStickiness` 160 pt), so a bug crossing a plate doesn't flip sides.
- When no way out exists, the bug is **not drawn**: hidden at once, then faded back in once clear (`clearFade`). One
  case is a bumblebee's halo in Home's button column, where no way out stays on screen and off the midrib.
- Flyers are still only eased (no pops), and a centre that is off the canvas is never pushed.
- **Home:** `BogScene.effectiveKeepOut` is `hudKeepOut` if set. Otherwise it is the HUD corners in play, and
  `BogScene.homeKeepOut(layout)` (an estimate of `HomeView`'s button column) when `showsEconomy` is false. On Home
  the App already passes nil and false, so this works today.
- **For App/UI:** pass Home's real button frames, in scene space, through `SceneHooks.setHUDKeepOut` on Home instead of
  nil, for an exact fit.
- **For Core:** ideally, Home's attract session doesn't land bugs on the HUD page at all.
- New read-outs: `BogScene.sittingBugRects` (every visible sitting footprint; usable by a CI probe), `effectiveKeepOut`,
  and `homeKeepOut(_:)`.

**Test:** `sittingBugsKeepTheClearZones` runs a seeded Zen `TrapSession` for 30 s, once under the play corners and once
as Home. It asserts that no sitting bug's centre or footprint enters a keep-out, the edge margin or the midrib band.
It also has unit checks for Home's column (a bumblebee there is not clear, a fly gets moved out), the App's override
and the bee halo's midrib clearance.

## #14 (Scene part): night reads as night

- The night keys (`BogLight.keys[3]`, `[4]`) are a deeper blue grade, with less green, a bluer lift and sky, and a navy
  trap overlay that still darkens the crimson without turning it violet.
- The vignette turns navy and closes in at night (`BogLight.nightVignette`, read-out `BogScene.vignetteColor`).
- The bog's fireflies: there are 18 (was 14) with a 74 pt glow (was 58), and they never blink below
  `fireflyFloor` 0.45, so a still frame always shows them glowing (read-out `BogScene.glowingFireflies`). They stay
  off the trap, so they're never taken for the catchable fireflies.
- The firefly bug's night bloom is now ×1.45 (was ×1.35), inside the 6 r streak guard.
- **Test:** `nightIsADeepBlueWithGlowingFireflies`. It checks b > 2 g (R6 was ≈ 1.8) and luminance < 0.45 × noon at
  clocks 3, 3.5 and 4. It also checks for a navy vignette, ≥ 12 fireflies and that every visible one is glowing.
- **For CI:** frames 17, 35 and P05 need real night (`dayClock` ≥ 3), and Core supplies the 3+ fireflies.

No new demo keys or freeze tags.

## Follow-up (the founder): truthful clear zones, App's pops, the FEAST ×2

**This replaces the #4 section above.** The hard projection, the hide-when-no-way-out pass and `clearFade` are gone.

### 1. Core owns the clear-zone rule
- **`BogScene.coreKeepOut`** is the keep-out Core judges resting spots by (`TrapSession.keepOut`, in scene space,
  which is the session's own space). It holds:
  - `effectiveKeepOut`: the HUD plates in play, or on Home `homeButtonFrames`, falling back to the `homeKeepOut`
    estimate;
  - the midrib band (the crease's half-width either side of the trap's centre line);
  - four edge strips (`edgeStrip` 10 pt inside the canvas), so Core's radius + 8 keeps the drawn footprint
    `edgeGap` inside.

  Built by `BogScene.coreKeepOut(_:layout:)`.
- **New API:**
  - `protocol SceneKeepOutReceiver { func sceneKeepOutChanged(_ rects: [CGRect]) }`. A driver that conforms is sent
    `coreKeepOut` when it is set as the driver, when the plates, Home or the layout change, and on every `reset()`.
  - `BogScene.applyKeepOut(to: TrapSession)`.
  - `BogScene.homeButtonFrames: [CGRect]?`. On Home, the App passes the real button frames here, not through
    `hudKeepOut`.
  - `BogScene.isHome`, which is `!showsEconomy && hudKeepOut == nil`.
- **The App must, in its own files (the Scene can't reach the sessions):**
  - make `GameController` conform to `SceneKeepOutReceiver` and set `session?.keepOut` and `homeSession?.keepOut`;
  - call `scene.applyKeepOut(to:)` on each new session before its first step (a play session, `makeHomeSession`);
  - set `scene.homeButtonFrames` on Home.
- **Drawing:**
  - A **catchable** bug (`BogBugLayer.isCatchable`: in the trap and `TrapRules.isCandidate`) is drawn exactly at its
    Core position: never nudged, never hidden.
  - The R6 visual-only easing is kept only for a flying bug that can't be caught, and on Home (`decorative`) for
    bugs that can't be caught.
  - Every other bug eases back to its Core spot.
  - No bug is ever hidden.
- **Tests:**
  - `sittingBugsKeepTheClearZones` now checks **Core positions**. Over 30 s of a seeded Zen run in play, no still,
    resting bug (sipping, or walking and not moving) comes within Core's clearance of `coreKeepOut`. The slack is
    3.5 pt, as in Core's own test.
  - The same test checks, in play and on Home, that every catchable bug has a zero nudge and that every sitting bug
    is drawn.
  - It also checks the receiver hand-off (`SceneKeepOutSink`).
  - The R6 HUD test now expects resting bugs drawn at their Core spots, and only the outside flyer eased clear.

### 2. App's Scene-side patch (`design/notes/app-R7.md`)
- **Words:**
  - `heroLabel` and `bigFeastLabel` use `AppRules.biteCallout` ("5 bugs · +540"), and `countLabel` is
    `AppRules.biteName`. "×" is only the chain.
  - `luckyLabel(_:snaps:)` is `AppRules.luckyText` ("Golden scarab! +2 snaps"; with no snaps row, the name only).
- **FEAST:**
  - The banner and callout are centred over the trap (`placePop` side 0 spans the whole trap).
  - The callout is at `feastCalloutSize` = 1.6 × `quadCalloutSize` (48).
  - The refill shows as the glyph flights, the row flourish and App's "FEAST! +2 snaps" row tag.
- **"Stung!" / "Bzzt!":** always above the ring. If dodging other pops pulled it onto the ring, it is lifted back
  above. Only at the very top of the screen does it go beside the ring (`besideRing`), never under it.
- **Optional item 5, done:** no "×N held" line when a lucky line shows.
- **Tests updated for the new words:** `calloutWords`, `closureTracksAndTheBiteSlams`, `everyEventIsHandled`,
  `popsNeverSitOnABug`, `stackedPopsSpreadOutAndGlyphsMissThem` and `theEconomyFliesToTheHUD` (which also checks that
  the FEAST callout is centred and at 1.6×). In `theEconomyIsShownTruthfully`, "Bzzt!" must now be above the ring.

### 3. Core's FEAST ×2
Scene tests build their `BiteReport`s by hand and draw `points` as given, so no expectation hard-codes Core's
scoring. Nothing to change beyond the words.
