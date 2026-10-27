# Snapjaw: App Review notes (v1.0)

*Written Tue 27 Oct 2026 by the launch lead from the design (`design/GAME-DESIGN.md` §3–§9, `design/ROUND-1.md`); the build doesn't exist yet. The block between the markers is what App Review reads. Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes, no degree sign, no multiplication sign), so bytes = characters: **3,962 bytes** (counted with Node; the ported `tools/appstore/build-metadata.js` fails over 4,000). Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**. **The App Store Connect tool sets all of it** (`asc.yml`, step `review`, from `docs/appstore/asc-metadata.json`): nobody pastes anything.
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email, read at run time from Squish's App Store Connect record and masked in every log (Swoop's `tools/appstore/README.md`, "Personal data"). Never in the repo.
- **Notes:** the block below.
- **Attachment (optional):** a 20–30 s phone video of the Duo held like a book: bugs landing, one snap of about 22 degrees catching a crowd, the trap opening again, a bee being waited out. The notes don't depend on it; the tool doesn't upload one.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Snapjaw: a paid game with no ads, no in-app purchases, no accounts, no data collection and no network requests of its own.

1. TESTING WITHOUT AN iPHONE DUO (start here)
You don't need a Duo. Everything works on any iPhone, on iPad (as an iPhone app) and in the Simulator, in landscape.
- Control: tap anywhere to snap the trap shut. It opens again by itself.
- The first launch starts First Bite, a short lesson. A fly lands on a nectar drop: tap while it is sipping to catch it. Skip appears after the second step; Settings > Replay First Bite plays it again.
- Quickest look (about a minute): the first two lesson steps, Skip, then Feed on Home.
- In Feed, bugs fly in and land on the gold nectar drops to sip. A tap bites: every bug inside the trap is caught at once. Score = the bugs' points x the number of bugs x the chain, so waiting for a crowd pays.
- Bees, bumblebees and wasps wear a white halo. Never eat them: a bee in a bite is let go unharmed and costs an extra snap.
- A run starts with 10 snaps and each snap costs 1. Catching 3 or more at once (a Feast) earns snaps back. At 0, "Your trap is tired" and a results card shows the score.

2. HOW THE HINGE IS USED (iPhone Duo)
Snapjaw reads the hinge angle only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API. The angle works the trap while the game is on screen and is never sent anywhere.
a) Hold the Duo open like a book (landscape, fold top to bottom), relaxed, anywhere from about 135 to 175 degrees. The game follows the player's own resting angle; there is no target angle.
b) To snap, close the halves about 22 degrees from that resting angle, then open again. The bite is decided the moment the closure reaches 22 degrees, so going further gains nothing and nothing has to be held. Creeping closed very slowly lets twitchy bugs fly off, so the snap is a short, brisk stroke, like turning a page.
c) The score, snaps and hints sit on the right half, which stays sharp when iOS briefly softens one half of the screen as a fold starts from flat. Settings > HUD on the left moves them.
d) Folded below about 50 degrees for over half a second, the run pauses and a card asks to open it like a book; it carries on when reopened. Closed, the outer display shows a card to open it. Portrait shows a card: hold it open like a book.
e) Nearly flat only shows a hint: "Bend it a little, like a book". No penalty.

3. KIND TO THE DEVICE (Guidelines 2.4.2 and 1.4.5)
- Every snap is a short stroke of about 22 to 40 degrees from a relaxed book pose, in the middle of the hinge's range. Snapjaw never asks the user to close the phone, lay it flat or slam it.
- Snaps are a limited resource (10 to start, 12 at most), so the game rewards waiting for the right moment, not snapping often: a run is about 25 to 40 snaps over 2 to 3 minutes.
- No achievement or leaderboard rewards snap speed or snap count.
- Nothing is placed on the screens.

4. MODES (nothing hidden, nothing to buy)
- Feed: endless waves of bugs from morning to night, until the snaps run out.
- Daily Bog: the same bugs for everyone that day; one scored try, then practice.
- First Bite: the lesson.
- Bug Book: 16 species to collect. Plant rank: 12 cosmetic ranks by lifetime bugs caught.

5. CONTENT
A cartoon Venus flytrap catching cartoon bugs, the way a frog catches flies. No blood or injury is shown: caught bugs are gulped into the trap, and bees and wasps are always let go unharmed.

6. PRIVACY
No third-party SDKs, analytics, ads, accounts or tracking. Progress and settings stay on the device. App Privacy: Data Not Collected.

7. GAME CENTER
Optional. 2 leaderboards (Best Feast, Daily Bog), 12 achievements (575 points), none hidden.

8. OTHER
- No notifications. Debug and demo modes are disabled in Release builds.
- Sound plays with the silent switch on; Settings > Respect silent switch turns that off. All sound is synthesized in the app.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

**Code: not written yet** (27 Oct). Tick "Code" when Round 1 compiles, and **RC** on the build that is submitted.

| Claim in the block | Source in the code (expected) | Code | RC |
|---|---|---|---|
| Tap anywhere snaps on a phone without a hinge; the trap reopens by itself (0.35 s) and re-arms after 0.45 s | `Input/TouchTrapSource.swift`, `Tuning.touchRearmDelay`; `BogScene.touchesBegan` → `GameController.sceneTapped` | [ ] | [ ] |
| First Bite runs on the first launch; **Skip** only after step 2; Settings **"Replay First Bite"**; on phones the pose step is skipped and steps say "Tap to snap" | `App/` lesson script, `UI/SettingsView.swift` | [ ] exact labels | [ ] |
| Home has **Feed**, **Daily Bog**, **Bug Book**, Settings | `UI/HomeView.swift` | [ ] exact labels | [ ] |
| Score = points × count × chain; 10 snaps, max 12; Feast refunds; bee +1, wasp +2; **"Your trap is tired"** | `Core/TrapSession.swift`, `Core/Tuning.swift`, the HUD / Results words | [ ] | [ ] |
| Bees, bumblebees and wasps wear a white "protected" halo ring | `Scene/` (ROUND-1 Scene brief) | [ ] | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; the angle is never sent; nothing about the angle is saved (if a rest angle is ever persisted, add "only the usual resting angle is saved, on the device", as Swoop's notes do) | `Input/HingeReader.swift`, `Persistence/SettingsStore.swift` | [ ] grep | [ ] |
| Rest reference follows the player; snap at 22° (`Tuning.snapDepth`); no hold; creep makes twitchy bugs leave | `Core/SnapDetector.swift`, `Core/Tuning.swift` | [ ] update if tuning moves them | [ ] |
| HUD on the right half by default; Settings **"HUD on the left"** | `ScreenLayout.hudOnLeft`, `UI/SettingsView.swift` | [ ] exact label | [ ] |
| Closing pause below 50° for 0.6 s with a card asking to open it like a book; cover-display card when shut; portrait pose card | `Tuning.closingAngle` / `closingDwell`, `UI/PoseCards.swift` | [ ] exact wording | [ ] |
| Too flat (≥ 174°): hint **"Bend it a little, like a book"**, no penalty | `TrapHint.bendALittle`, `Tuning.tooFlatAngle` | [ ] exact wording | [ ] |
| Never uses `status == .closed` in play (CLAUDE.md: it turns on at about 85° on hardware) | every `.closed` in `Snap/` is a pose enum; `HingeReader` reads only the angle | [ ] | [ ] |
| A run is about 25–40 snaps over 2–3 minutes (casual) | `BalanceTests` `SNAP-BAL` table (casual 90–240 s, 18–45 snaps: ROUND-1) | [ ] update the numbers from the table | [ ] |
| No achievement or leaderboard rewards snap speed or count; `fastestSnap` is not shown or reported | `Core/Achievements` (`achievements.md`), `App/GameCenterManager.swift` | [ ] | [ ] |
| Daily: one scored try that counts, then practice | `RunMode.daily(day:scored:)`, `UI` Daily | [ ] | [ ] |
| Bug Book 16 species (drawing, joke, count); 12 plant ranks, cosmetic | `BugCatalog.all`, `PlantRanks`, `UI` Bug Book | [ ] | [ ] |
| Caught bugs are gulped, no blood or injury; bees released unharmed | `Scene/` juice FX (`metadata.md` §11 ask 1) | [ ] | [ ] |
| 2 leaderboards, 12 achievements, 575 points, none hidden | `achievements.md`, `App/GameCenterManager.swift` | [ ] | [ ] |
| Setting **"Respect silent switch"**, default off; `.playback` category | `Feedback/`, `UI/SettingsView.swift` | [ ] exact label | [ ] |
| No notifications, no rating prompt | no `UNUserNotificationCenter` / `requestReview` / `SKStoreReview` in `Snap/` | [ ] (if a rating prompt is added, add: "A one-time rating prompt may appear on a results card, never mid-run.") | [ ] |
| Debug and demo modes disabled in Release (`-snapDemo` and `SNAP-` logs are DEBUG only) | `App/DemoMode.swift` (`#if DEBUG`), the TestFlight workflow's archive check | [ ] | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Snapjaw never asks users to close the phone, lay it flat or slam it. A snap is a short stroke of about 22 degrees from whatever relaxed book pose the player holds, in the middle of the hinge's range; the bite is decided at 22 degrees, so there is nothing to gain by closing further or harder, and nothing has to be held. Snaps are a limited resource in the game (10 to start), so the design rewards waiting for the right moment rather than folding often: a typical run is 25 to 40 snaps, fewer than turning the pages of a short book. No score, achievement or leaderboard rewards snap speed or snap count. Nothing is ever placed on the device. Any iPhone without a hinge plays the full game by tapping the screen."

(If the founder chose to build "Play with touch" on the Duo, `metadata.md` §11 ask 6, add: "and on iPhone Duo, Settings > Play with touch plays the whole game by tapping.")

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable without a Duo, by tapping. Offer the phone video attachment.

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4 and the 12 achievements: an endless mode with a day cycle and 16 species, a daily mode, a Bug Book and 12 plant ranks, and a tutorial; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules). The difference from free "snap shut on bugs" toys is the point: choosing when to bite, crowds, bees to spare and a snap economy.

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Swoop's submitted notes (structure mirrored): `C:\Users\59527\Wing\docs\appstore\review-notes.md`
