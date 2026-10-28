# Feel R5 hand-off (Feedback; Input unchanged)

*Feel engineer, 28 Oct 2026. Not compiled locally (no Swift on this host). Every touched file had two read-throughs
for types, exhaustive switches, isolation (the new pure helpers live on the nonisolated `FeelSoundBook` and
`FeelHapticBook`) and the CLAUDE.md Swift Testing gotchas. CI is the compiler.*

## #4: the yawn waits for the numeral and the blip (`FeelSoundBook.swift`, `FeedbackDirector.swift`)
- The run's last bite now speaks in this order:
  - the numeral's drop at `numeralDropAt` (0.20 s), with a costly sting's loss blip on it;
  - then "Your trap is tired" and its yawn, at **≥ `FeelSoundBook.tiredAfterBite` (0.45 s)**.
- The App's tired banner uses the same beat (`AppRules.tiredBannerDelay` 0.45), so the yawn and the banner arrive
  together. Before this round the yawn played at 0.9 s, after a banner that showed at once.
- New pure `FeelSoundBook.tiredDelay(biting:wilting:stingCost:bwoopAt:)`:
  - on a bite, 0.45 at the earliest;
  - never before the loss blip is over (`afterLoss` = 0.20 + `lostLength` 0.32 = 0.52 s for a costly last sting);
  - never over a chain-broken "bwoop" (its start + `chainBrokenLength` 0.25: a dry last snap with a chain yawns at
    0.70 s);
  - after a wilt to zero, once the droop is over (`wiltLength`);
  - otherwise at once.
- `FeedbackDirector.tiredAt` is now `tiredAfterBite`, and the director calls `tiredDelay`.
- `lossAt(biting:)` and `afterLoss(biting:stingCost:)` moved into `FeelSoundBook` as pure helpers, so the director, the
  bwoop and the yawn share one clock.
- New diagnostics: `yawns` and `lastYawnAt`.

## #10: the dry snap is a hollow "clop" (`FeelSoundBook.drySnap`)
- The empty clap had a low-pass "thwack" and a 110 → 60 Hz thump, a wet bite's shape in miniature. It read as nothing,
  and in frames as silence. Now, in order:
  1. the rims' tick;
  2. the **clop**: a hollow wooden knock at `clopPitch` 480 Hz ringing `clopRing` 50 ms (about 5 × the teeth clicks),
     a square-ish odd-harmonic body falling 380 → 300 Hz, and a narrow 800 Hz band of empty cavity air;
  3. lighter teeth;
  4. a small dry 150 → 110 Hz knock;
  5. the two falling marimba notes ("nothing…"), under the Scene's "Missed!" puff.
- There is no squelch, no bubbles, no gulp and nothing below 120 Hz. It is still smaller than any CHOMP.
- The dry snap's haptic is unchanged (firm, lighter than the CHOMP). Home's title trap still chomps with
  `caught: 1`, so it never clops.

## A heavier wasp sting (`FeelHaptics.swift`, REVIEW-4 #7)
- `FeelHapticBook.sting(at:heavy:wasp:)`. The director passes `wasp: species == .wasp`.
- `waspSting` follows the sound's two zaps (`waspZapGap` 0.14 s, the same as `FeelSoundBook.sting`):
  - a firmer, rounder tap on each zap;
  - eight deeper, rounder 35 ms wobble segments (four per zap), where a bee has six;
  - when the sting cost snaps, two low thuds as its two snaps go.
- Its energy is about 1.65 × a heavy bee's, and it lasts 0.48 s against 0.29 s.
- Bees and bumblebees are unchanged.

## Tests (FeelTests)
- New tests:
  - `theTiredYawnWaitsForTheNumeralAndTheBlip`: the pure delays, the shared beat with `AppRules.tiredBannerDelay`, and
    the director on three last bites (plain, a costly wasp, a dry snap with a chain).
  - `aDrySnapIsAHollowClopWithNoSquelch`: one hollow knock, an odd-harmonic body, nothing wet or deep, and rendered
    audibly (peak > 0.02, finite, < 1).
  - `aWaspStingWobblesHeavierThanABee`: more energy, longer, a tap per zap at the sound's zap gap, a wobble at least
    as deep, and every note in range.
- Existing tests are unchanged. The empty-clap checks (no squelch, below the CHOMP) still hold.

## Risks
- **A cross-module test.** `theTiredYawnWaitsForTheNumeralAndTheBlip` reads `AppRules.tiredBannerDelay`, which the
  App engineer is adding this round (it is in the working tree). If App renames it, update the test, not the beat.
- **Overlap at the yawn.** On a costly last sting, the yawn at 0.52 s starts as the wasp's second "Bzzt!" tail and its
  spit (0.50 s) end. On a Duo, check that it reads as "and now you're tired", not as noise.
- **The clop is unheard on a device.** It is tuned for a phone speaker's band (300 Hz–1 kHz). If it reads too woody
  on a Duo, lower `clopPitch` toward 400.
