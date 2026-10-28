# Scene R3 hand-off (Scene engineer)

Only `Snap/Scene/` and `SnapTests/SceneTests.swift` changed. Nothing is compiled yet: every touched file was re-read
twice for compile errors (CGFloat/Double, isolation, labels, exhaustive switches, the CLAUDE.md test gotchas).

## New or changed API for the App
| API | What the App does |
|---|---|
| `TrapArt.snapGlyph(width:height:scale:empty:) -> CGImage?` | #11: the snaps row's glyph, a mini closed flytrap (two crimson lobes shut on a dark seam, cilia interlocked, thin green lip). `empty: true` is the spent slot, a grey outline. Default 30 × 22 pt at 3×. Cache the two images. |
| `TrapArt.drawSnapGlyph(_:size:empty:)` | The same drawing into any `CGContext` (y up), e.g. for the hunger pulse or badges. |
| `scene.snapsShownOffset: Int` | #14: show `snapshot.snapsLeft + scene.snapsShownOffset` as the numeral. It is −1 per Feast glyph still in the air (so the number ticks as each lands) and +cost for 0.15 s after a sting (the glyph cracks first, then the number drops). |
| `scene.snapsRowFlashing: Bool` | #14: the scene's crimson flash across the row (300 × 96 pt, centred 90 pt right of `hudSnapsAnchor`, 0.45 s) is showing; the App may pulse its own row with it. |
| `TrapArt.trapImage(width:scale:)` | Same call, new art (lobes, blush, glands, midrib seam, 76 cilia, **petiole**). It is now ≈ 0.72 × width tall (the petiole hangs below): re-check the cover, Results and Home frames. |
| `TrapArt.palette.lobeInner / lobeOuter` | Now #5C0B1E (oxblood) / #C02A42 (crimson). `SnapTheme` colours built from them darken. New: `TrapArt.lobeCore`, `blush`, `leaf` (#2F5F2B), `interior`, `petiole`, `ciliaBase`, `ciliaMid`. |
| `TrapArt.exteriorWidth` | 26 → 9 (the back is a thin lip now). `AppCanvas.leafBack` (26) is still conservative. |
| `TrapArt.lobePath/teethPath` | Same signatures; the lobe is now a clam (a 40 pt notch at each end of the midrib, a 7 pt seam gap) and there are 38 cilia per side. `TrapPortrait` (the UI fallback) still paints its own R2 colours; switch it to `TrapArt.palette` if it is ever shown. |
| `TrapArt.closedTrapPath(geometry:)` | The closed trap's outline (inside the open one), for the pose card or icon if wanted. |

## Needs from the other modules
- **Feel:** the wilt pop now reads "Too slow! −1 snap" (crimson, 28 pt, over the snaps row). A sting's numeral drop
  lands 0.15 s after `stung` (`BogEconomy.crackLead`): put the descending blip there. Feast glyph timings are unchanged.
- **CI:** `freezeOn=snap` at 0.12 s lands in the hold and now shows the closed trap (a narrow crimson lens with laced
  cilia, the bog around it). For a crowd-on-the-open-trap frame, freeze at hold + 0.3 s (as #21 asks).
- **Core:** none. The art notch only trims ~40 pt at the very top and bottom of the midrib, inside the crease band
  that `findSpot` already avoids.

## What changed (review numbers)
- **#2 / founder art: a Venus flytrap from above.** `TrapArt.lobeShape` + `marginPoint`: two clam lobes with a notch
  at each end of the midrib and a narrow dark gap between their inner edges there (`seamGapPath`, drawn under the
  midrib). The face: a crimson core (#9A1A33) → crimson (#C02A42), an oxblood spine along the midrib, a yellow-green
  blush in soft strokes along the margin only (last ~40 pt), cupped under the lip; 1,300 tiny dark-red glands per lobe
  clustered toward the midrib; 17 fine veins radiating from it. No rind, no pale dots (the rim glands are no longer
  drawn). One soft specular per lobe. The back is a 9 pt dark-green lip. 76 long, thin (≤ 4.7 pt), slightly curled
  cilia, green → pale green → cream, each with a soft shadow. A green petiole runs from the bottom notch into the bog
  (backdrop and `trapImage`). The trap's shadow is now a sprite under the lobes (it squeezes with the bite).
- **#1 the bite.** The lobes squeeze to 0.3 about the midrib in 60 ms; `BogTextures.closedTrap` fades in over them:
  two narrow lobes (same notches and seam), lit crimson on the bulge, a dark interior down the seam, 2 × 24 cilia
  interlocked across it, a thin green lip. The open cilia fold in and hide; the nectar, hairs and glistens ride the
  squeeze and sink under it. No jaw sweeps in from outside any more. Tests: `theBiteStaysInsideTheOpenTrap` (874 × 402
  and 951 × 669: every frame of the bite inside the open frame; the hold inside the open lobes and < 50 % of the open
  width), `theClosedTrapFitsInsideTheOpenOne` (point for point).
- **#10 light.** Dusk: env (1, 0.72, 0.56), a 26 % peach haze, a warm additive rim light on the lobes (62 %). Night:
  a bluer bog, the lobes' overlay is a dark neutral (it darkens, the hue stays crimson; tested), a cool moonlit rim,
  14 fireflies with 58 pt blooms.
- **#14 economy.** `snapsShownOffset`, a stronger crack (halves 1.3×) and the row flash. "Bzzt!"/"Stung!" sits above the
  bee's ring (1.6 r) or, when there is no room, below it; never over the bee.
- **#8 (Scene side).** A bite with a stinger pops "Stung! · +N" (and the wasp's own pop then says "Bzzt!").
- **#15 pops.** Catch pops are 36/40/48 pt and never shrink under 28 unless the crease forces it; they pop in from
  0.72 (readable on the hit-stop's first frame). A clean bite that keeps the chain says "×1.5 held". "Too slow! −1 snap".
- **#17 hunger.** At hunger 0.7 → 1: lobes y 0.95 (pinned at the midrib), a 15 % grey veil, teeth leaning 20°, gloss
  dulled.
- **#25.** The mosquito: six legs in three clear pairs and a proboscis, short antennae. Pops leave by shrinking as they
  lift (opaque until the last 14 %): `BogPops.exitScale/exitAlpha`.

## Risks
- The closed-trap still frame is new and big (it is 5 of the 10 CI play frames): check it on CI first.
- The face's blush is ten soft strokes; if it reads too orange at the margin, lower `TrapArt.blush` alpha (0.085).
- Texture build: two lobes with 1,300 glands each and the closed trap add ~0.1 s to the first warm-up.
