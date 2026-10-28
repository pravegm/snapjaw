# App engineer: Round 5 hand-off

Folders: `Snap/App/`, `Snap/UI/` (`AppIconArt.swift` untouched), `Snap/Persistence/` (untouched), `SnapTests/AppTests.swift`.
**Not compiled.** Every touched file was re-read twice for exhaustive switches, ViewBuilder `let`s, isolation, labels
and local shadowing. No rethrowing or key-path calls sit inside `#expect`. New tests are in `RoundFiveTests`.

## REVIEW-4 items
- **#2 pose card** (`UI/PoseCards.swift`, rebuilt).
  - One diagram in one `Canvas` (`PoseDiagram` / `PoseDiagramArt`). It has no `rotation3DEffect`, no `scaleEffect`,
    no stacked scene images, no hands and no "138°".
  - The Duo is seen from the front, held like a book. Its screens show one trap's two lobes (midrib on the hinge,
    a fly sipping), and it claps 160° → 138° with inward chevrons at the outer edges. Its perspective is computed
    point by point, and the tilt is drawn 1.8× so the snap reads.
  - Phones: an iPhone turning sideways.
  - The card has a title and one line ("Snap it a little shut to bite."), with no second trap under the words.
  - `PoseCardLayout` places both as plain rects:
    - portrait: the diagram on the top half, the words on the bottom half;
    - landscape: side by side;
    - either way, clear of the 80 pt fold band.
  - `poseCardFits` tests it at 874×402, 951×669, 402×874 and 669×951, Duo and phone: no overlap, inside the safe
    area, off the band, the words fit.
- **#4 tired banner.**
  - The banner shows only when the shown numeral is 0 and ≥ 0.45 s into the tired moment
    (`AppRules.showsTiredBanner`).
  - If the Scene's crack still holds the numeral up at 0.8 s, it is set to 0 (`tiredNumeral`).
  - Demo `freezeOn=tired` now holds at 1.0 s.
  - Test: `tiredBannerWaitsForZero` (never with shown > 0, and a frame-by-frame 19/40 case).
- **#5 belt and braces.** While any protected bug that isn't being caught is in the zone (`protectedHaloInTrap`),
  Core's `hungry` becomes "Bee! Wait…" (`guardedHint`), and the hungry pulse and red numeral are off.
- **#7.** A costly sting puts a crimson "−1 snap" / "−2 snaps" tag at the row for 1.8 s (`HUDValues.snapLoss`), with
  the bite's total cost and a true minus sign.
- **#12.**
  - Home: the tagline and subtitle now sit on the rank card, so the attract fly passes under them.
  - On a Duo the subtitle is "Wait for a crowd, then bite." (no second "Snap it shut a little").
  - Bug Book: names are one line, shrinking to fit, so "Golden Scarab" keeps its count.
- **#13 words.**
  - "score" everywhere in the UI: the HUD caption "SCORE", Results, the cover, the Daily status, the pause menu and
    the Results story.
  - Settings: "Score on the left".
  - Card 09 is 3 sentences (it drops the stinger and wilt lines).
  - The snaps numeral is 24 pt on the Duo and 20 pt on phones (it was 17 and 15), in a 36 pt box.
- **#14 badges.**
  - Only First Feast, Bog Monarch and Bee-Free Diet draw the hero trap, each in its own layout: big with two flies
    flying in; crowned; low-left with the bee flying off.
  - Daily Diner is now a calendar page with a sun and a fly. Well Fed is "10K" in a ring of nectar.
  - The trap's only bug is the Scene's own sipper (`TrapImageCache.heroImage(bug: true)`). Other bugs fly off the
    trap.
  - Every subject is clipped to the disc, and `heroFit` shrinks the hero to fit inside it.
- **Daily share.** On a scored Daily's Results, a `ShareLink` shares "Snapjaw Daily Bog #301 · 4,210 · biggest bite
  6 🪤". The bog number is day + 1, and there is no link.
- **#11 numbering.** "Step n of 4" is the same on the Duo and on phones.
  - The Duo's pose step is labelled "Get ready".
  - Its re-arm step shares step 1.
- **#8 Sprout taper.**
  - Feed runs 1–3 pass Core's `SessionOptions.sproutRun` (`GameController.applySprout`, with the run number from
    `AppRules.sproutFeedRun`, counted on Feed runs only).
  - Run 1 also keeps its R3/R4 switches.
  - The lesson's row shows the next run's start (14 / 13 / 12).

## For other modules
- **Core:** `Achievements.score10k`'s detail still says "protein" (Game Center text, `Core/Progression.swift`).
- **CI:**
  - `freezeOn=tired` now freezes at 1.0 s into the tired moment, so frame 19 shows 0 under the banner.
  - Capture a mid-run `costlySting` to see the "−2 snaps" tag.
  - Capture a scored Daily's Results for the Share button.
- **Scene:** the badges and pose card use only `TrapImageCache.heroImage` / `TrapArt.threeQuarterAspect` /
  `TrapPose.bounds`, `halfSpan`, `height` and `turn`, all still present in the R5 redraw.

## Risks
- The numeral's wider box (36 pt) may shrink the Duo's glyphs a point to keep the cilia clearance.
- The Home rank card is taller. Check frame 01 on the phone.
