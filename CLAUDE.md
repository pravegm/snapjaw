# CLAUDE.md: working on Snapjaw

**Snapjaw** ("Feed the flytrap. Spare bees.") is a paid iPhone game (£1.99, no ads, no IAP, no data collected), built
**iPhone Duo first**. The Duo is Apple's foldable (iOS 27.1).
- **The phone IS the trap** (R8). Open phone = open trap; closed phone = closed trap. The two halves are a Venus
  flytrap's lobes, the hinge is its midrib. Any opening plays, landscape or portrait.
- Bugs land inside to sip nectar. **The bite fires only when the phone fully closes** (θ ≤ 18°, or `.closed` with
  θ ≤ 25°); a partial close, however deep, never bites. Close decisively: flies feel the closure and flee a slow close.
- Every round starts closed ("Close the phone to start"). While shut, the outer screen shows the CHOMP card; open
  again (θ ≥ 35°) to keep feeding. Other iPhones: tap to snap.
- Wait for a crowd and catch them all in one bite. Never eat a bee.
- Modes: 30 **Levels** in 3 worlds (Morning Bog, Dusk, Night; Levels 1–5 teach), **Endless** (was "Feed"), the
  **Daily Bog**, the **Zen Bog**. 12 snaps to start, 14 max (`Snap/Core/Tuning.swift`).

**Why R8:** the founder rejected TestFlight build 1 on a real Duo (28 Oct 2026): "absolute shit and garbage. terrible
UI and UX", "the flytrap shuts much before the duo lid", "if the phone is open the flytrap is also open, if phone is
closed then flytrap is also closed", and "super easy". R7's 22° partial snap drew the trap shut while the phone was
open. The critic panel had scored design 8; it was wrong. **Only the founder's hands on a real Duo judge.**

### The founder's binding hinge rules (all Duo games; override any brief)
1. **Literal mapping.** The phone's angle IS the trap. Any opening means open (a phone at 90° is open). Nothing on the
   inner screen ever draws the trap shutting while the phone is open.
2. **Every round starts closed.** If the phone is open at Play, ask "Close the phone to start"; opening it then opens
   the trap. Never ask the player to open a phone that is already open.
3. **No pose demands, ever.** Flat, laptop, portrait, any angle all play. No pose card, no "bend it", no "like a book".
4. **Copy says "phone", never "lid".** Never "smash" or "Fold to …".
5. **The first session holds about 3 ideas**, with no forced tutorial gate (Levels 1–5 teach by playing).
6. **The phone fallback is first-class.** A tap bites, nothing waits for a hinge, phone copy says "Tap to snap".
   Re-audit the phone path after every mechanic change.

The founder (GitHub `pravegm`) is the product owner and is away while this is built. Claude runs the studio as founder,
designer and developer, with parallel subagents per role and a critic loop (advisory only: get a TestFlight build into
the founder's hands every round).

**Sister projects:** Squish (`C:\Users\59527\Squish`), Brim (`C:\Users\59527\Fold`), Swoop (`C:\Users\59527\Wing`)
and Hush (`C:\Users\59527\Lid`). Never modify them. Reuse their lessons and code by copying.

## Identity
- Product name **Snapjaw** (`CFBundleDisplayName`); Swift code reads it via `AppBrand.name`, never a literal.
- Xcode target and folder `Snap`, tests `SnapTests`. Bundle id **com.pravegm.snapjaw**.
- Log prefix `SNAP-`; demo launch argument `-snapDemo`; Game Center ids `snap.*`.
- Repo folder `C:\Users\59527\Trap` → GitHub **pravegm/snapjaw**.

## The bar
1. **Duo-first, literally.** Judge every change on a real Duo: the phone's angle is the trap's, at any opening,
   landscape or portrait. Tap-to-snap on other iPhones must play every level and mode in full.
2. **The bite is the product.** CHOMP lands the moment the halves meet: sound and heavy haptic at the shut, the CHOMP
   card on the outer screen, the digest (remains, juice, score pop) on reopen. With hinge input the inner screen never
   animates the jaws shut; only touch input plays the Scene's own shut.
3. **Choosing, not smashing.** Fold Smasher (free) already smashes bugs. Our game is patience, crowds and bees, and a
   decisive close. Never use "smash" or "Fold to …" in copy.
4. **The full close is the bite; it must not be easy.** Only a full close bites; a partial close never does. Speed is
   the skill (flies flee a slow close). Difficulty is real: novice runs end in 60–100 s (ROUND-8 §2). Force is never
   measured, so a gentle close catches as much as a hard one. Starting a fold from flat blurs one half of the screen
   for about 2 s (an iOS effect), so the HUD lives on the sharp half ("Score on the left" moves it).
5. **Truthful store frames.** Nothing appears on a frame that the app doesn't do (no shut lobes on a Duo inner frame).

## Working rules
- Push straight to `main` (the founder's standing rule; solo project). No PRs.
- **No Mac on the Claude side. CI is the compiler.** A Swift change is unverified until a GitHub Actions run passes.
- **Repo:** https://github.com/pravegm/snapjaw, **public** (created private on 27 Oct 2026; Actions on private repos
  are blocked by this account's billing, so it was made public). Nothing personal goes in it: no emails,
  names beyond `pravegm`, or secrets. App Store Apple ID 6828066230; TestFlight builds come from `testflight.yml`.
- **Website:** GitHub Pages serves `docs/` (main, `/docs`). `docs/index.html`, `support.html` and `privacy.html` only
  forward to the real pages in `docs/site/`; edit those. They are the App Store Marketing, Support and Privacy URLs.
- On this Windows host Bash ignores `cd`. Use absolute paths and `git -C`. There is no Python; use Node.

## Build
`brew install xcodegen && xcodegen generate && open Snap.xcodeproj`
- Xcode 27.1 with the iOS 27.1 SDK. Deployment target iOS 18.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Swift 5 mode.
- The `.xcodeproj` and `Info.plist` are generated, not committed.

## Docs (read in this order)
1. `design/ROUND-8.md` (the current game: the phone is the trap, difficulty, Levels) and the R8/R9 notes
   (`design/notes/core-R8.md`, `app-R8.md`, `portrait-R8.md`, `app-R9.md`, `store-R9.md`). Where they differ from
   older docs, they win.
2. `design/GAME-DESIGN.md`: the original game (pre-R8: its 22° partial snap, book pose and First Bite lesson are gone).
3. `design/ARCHITECTURE.md` and `Snap/Shared/Contracts.swift`: modules, owners, APIs.
4. `design/ROUND-N.md` (briefs), `design/REVIEW-N*.md` (critics), `design/notes/` (engineer hand-offs),
   `docs/HANDOVER.md` (state now) and `docs/PROJECT-LOG.md` (what happened when).
5. `docs/appstore/metadata.md` (the store copy; its §4 is the wording for how it plays).
6. `research/`: the market and name checks.

## Hinge facts that bite (from the sister projects' real-Duo logs)
- Use the **angle**; never trust `status == .closed` alone (it turns on at about 85° on hardware). R8 bites at
  θ ≤ 18°, or `.closed` only with θ ≤ 25° (`Tuning.shutAngle` / `statusShutAngle`).
- At the shut iOS moves the app to the outer display and scene frames stop; the App steps the run from the hinge
  report (`stepFromHinge`), so the bite, CHOMP and haptic still land at the shut.
- Samples arrive at 25–30 Hz while moving and not at all while still.
- Re-enable `onHingeChange` on each activation to get a fresh reading.
- A natural quick fold goes "about halfway" (≈ 90°). Never put a pause or warning near 90° (Swoop).
- Full-screen apps are refused upside down, and a Duo lying flat never auto-rotates.

## Swift Testing gotchas (found on CI)
- `#expect(x.mutatingMethod())` doesn't compile, because the macro captures `x` immutably. Call it first:
  `let r = x.mutatingMethod(); #expect(r)`.
- Compare `CGFloat` with a typed constant and a tolerance, never with literal arithmetic.

## CI rule learned the hard way (28 Oct)
- **Run `duo.yml` alone.** The `xcode-27` runner is shared, and every Duo simulator death (R2–R5 runs) came with
  another Mac job (CI or store) running beside it: host load ~800, the simulator starved and shut down. Start a Duo
  run only when no other macOS workflow is in progress, and push nothing under `Snap/` while it runs.
