# CLAUDE.md: working on Snapjaw

**Snapjaw** ("Feed the flytrap. Spare bees.") is a paid iPhone game (£1.99, no ads, no IAP, no data collected), built
**iPhone Duo first**. The Duo is Apple's foldable (iOS 27.1).
- Hold it open like a book: the two halves are a Venus flytrap's lobes, the hinge is its midrib.
- Bugs land inside to sip nectar. Snap the phone a little shut (about 22°) to catch them, then open again.
- Wait for a crowd and catch them all in one bite. Never eat a bee.

The founder (GitHub `pravegm`) is the product owner and is away while this is built. Claude runs the studio as founder,
designer and developer, with parallel subagents per role and a critic loop.

**Sister projects:** Squish (`C:\Users\59527\Squish`), Brim (`C:\Users\59527\Fold`), Swoop (`C:\Users\59527\Wing`)
and Hush (`C:\Users\59527\Lid`). Never modify them. Reuse their lessons and code by copying.

## Identity
- Product name **Snapjaw** (`CFBundleDisplayName`); Swift code reads it via `AppBrand.name`, never a literal.
- Xcode target and folder `Snap`, tests `SnapTests`. Bundle id **com.pravegm.snapjaw**.
- Log prefix `SNAP-`; demo launch argument `-snapDemo`; Game Center ids `snap.*`.
- Repo folder `C:\Users\59527\Trap` → GitHub **pravegm/snapjaw**.

## The bar
1. **Duo-first.** Judge every change in book pose first: the Duo held in two hands at 135–175°, the trap spanning
   both halves. Tap-to-snap on other iPhones is the fallback.
2. **The snap is the product.** CHOMP must feel physically satisfying: sound, haptics, jaw slam, juice, score pop.
3. **Choosing, not smashing.** Fold Smasher (free) already smashes bugs. Our game is patience, crowds and bees.
   Never use "smash" or "Fold to …" in copy.
4. **Gentle on the hinge.** Short partial snaps. Never ask for flat or a full close. Starting a fold from flat blurs
   one half of the screen for about 2 s (an iOS effect), so the HUD lives on the right (sharp) half.
5. **Truthful store frames.** Nothing appears on a frame that the app doesn't do.

## Working rules
- Push straight to `main` (the founder's standing rule; solo project). No PRs.
- **No Mac on the Claude side. CI is the compiler.** A Swift change is unverified until a GitHub Actions run passes.
- **Repo:** https://github.com/pravegm/snapjaw. It was created **private** on 27 Oct 2026, because the permission
  guard blocks creating public repos. Actions on private repos are blocked by this account's billing (probe run
  40595444902: "recent account payments have failed"). Making it public is the founder's one click
  (Settings → General → Danger Zone → Change visibility); until then nothing compiles.
- On this Windows host Bash ignores `cd`. Use absolute paths and `git -C`. There is no Python; use Node.

## Build
`brew install xcodegen && xcodegen generate && open Snap.xcodeproj`
- Xcode 27.1 with the iOS 27.1 SDK. Deployment target iOS 18.
- Hinge code goes behind `#available(iOS 27.1, *)`.
- Swift 5 mode.
- The `.xcodeproj` and `Info.plist` are generated, not committed.

## Docs (read in this order)
1. `design/GAME-DESIGN.md`: the game.
2. `design/ARCHITECTURE.md` and `Snap/Shared/Contracts.swift`: modules, owners, APIs.
3. `design/ROUND-N.md` (briefs), `design/REVIEW-N*.md` (critics), `design/notes/` (engineer hand-offs),
   `docs/PROJECT-LOG.md` (what happened when).
4. `research/`: the market and name checks.

## Hinge facts that bite (from the sister projects' real-Duo logs)
- Use the **angle**, never `status == .closed` (it turns on at about 85° on hardware).
- Samples arrive at 25–30 Hz while moving and not at all while still.
- Re-enable `onHingeChange` on each activation to get a fresh reading.
- A natural quick fold goes "about halfway" (≈ 90°). Never put a pause or warning near 90° (Swoop).
- Full-screen apps are refused upside down, and a Duo lying flat never auto-rotates.

## Swift Testing gotchas (found on CI)
- `#expect(x.mutatingMethod())` doesn't compile, because the macro captures `x` immutably. Call it first:
  `let r = x.mutatingMethod(); #expect(r)`.
- Compare `CGFloat` with a typed constant and a tolerance, never with literal arithmetic.
