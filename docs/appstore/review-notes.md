# Snapjaw: App Review notes (v1.0)

*First written Tue 27 Oct 2026 by the launch lead. **R9 rewrite (Wed 28 Oct 2026, store lead):** the notes now describe the R8 game (`design/ROUND-8.md`): the phone is the trap, the bite fires as the phone closes, every round starts closed, no pose demands, 30 Levels (Levels 1–5 teach; the First Bite lesson is gone), Endless, Daily, Zen. The block between the markers is what App Review reads. Apple limits the field to 4,000 bytes; the block is plain ASCII (no smart quotes, no degree sign, no multiplication sign), so bytes = characters; `tools/appstore/build-metadata.js` prints the count and fails over 4,000 or on any non-ASCII character. Before submission, tick the "Check against the build" table at the end; if a line is false, change the block, never the build to match the words.*

## Where this goes

App Store Connect → the app → the **1.0** version page → **App Review Information**. **The App Store Connect tool sets all of it** (`asc.yml`, step `review`, from `docs/appstore/asc-metadata.json`): nobody pastes anything.
- **Sign-in required:** unticked (there are no accounts).
- **Contact:** the founder's first name, last name, phone and email, read at run time from Squish's App Store Connect record (`inherit_from: com.pravegm.squish`) and masked in every log. Never in the repo.
- **Notes:** the block below.
- **Attachment (optional, recommended for a hinge game):** a 20–30 s phone video of a real Duo: open it, bugs land, close it (the CHOMP card on the outer display), open again, a bee waited out. The founder can add it in App Store Connect; the tool doesn't upload one.

<!-- REVIEW-NOTES:BEGIN -->
```
Thanks for reviewing Snapjaw: a paid game with no ads, no in-app purchases, no accounts, no data collection and no network requests of its own. Nothing needs a login or a demo account.

1. TESTING WITHOUT AN iPHONE DUO (start here)
You don't need a Duo. The whole game works on any iPhone and in the Simulator, by touch.
- Control: tap anywhere to snap the trap. It opens again by itself.
- Home: Play starts the next level (Level 1 first). Also Endless, Daily, Zen, Levels (the map), Bug Book, Garden, Settings.
- Quickest look (3 minutes): Play (Level 1: one fly, tap while it sips), Level 2, then Home > Endless.
- Bugs land on the gold nectar drops. A tap catches every bug inside the trap. Score = points x bugs x chain (up to x5), so waiting for a crowd pays.
- Bees, bumblebees and wasps wear a white halo. Never eat them: a bee in a bite is let go unharmed and costs an extra snap.
- Endless: 12 snaps to start (up to 14 in a new player's first runs), 14 at most, 1 per bite; 3+ bugs in one bite (a Feast) earn snaps back. At 0, "Your trap is tired" and the results show.
- Levels: 30 in 3 worlds (Morning Bog, Dusk, Night), each with one goal, a bite limit and 1 to 3 stars. They open in order; 20 stars open Dusk, 40 the Night. Levels 1 to 5 teach one idea each; no forced tutorial. Later levels are meant to be hard.

2. HOW THE HINGE IS USED (iPhone Duo)
Snapjaw reads the hinge angle and status only through the public iOS 27.1 API (SwiftUI onHingeChange), behind an availability check. No private API. They are used only while playing and are never stored or sent anywhere.
a) The phone is the trap: open phone, open trap. Every round starts closed: if the Duo is open, the screen says "Close the phone to start"; open it again and the bugs come.
b) To bite, close the phone. The bite fires once, as the halves meet (about 18 degrees, or when iOS reports it closed). A partial close never bites. Opening re-arms the trap.
c) While shut, the run is frozen and the outer display shows a CHOMP card with the catch and "Open to keep feeding".
d) Any pose plays (landscape, portrait, any angle). No pose card, no penalty.
e) The score sits on the right half; Settings > Score on the left moves it.

3. KIND TO THE DEVICE (Guidelines 2.4.2 and 1.4.5)
- A bite is closing the phone, the ordinary way a foldable is closed every day. Force is never measured: the bite fires as the halves meet, so a gentle close catches as much as a hard one. Nothing asks the player to slam, shake or press the phone.
- Bites are limited (12 snaps to start, 14 at most; each level has a bite limit), so the game rewards waiting, not closing often. The Zen Bog has no limit and no timer.
- Flies flee a slow, hesitant close, but no score, achievement or leaderboard rewards closing speed or the number of closes.

4. MODES AND PROGRESS (nothing hidden, nothing to buy)
- Endless: waves from morning to night, until the snaps run out.
- Daily Bog: the same bugs for everyone; one scored try a day, then practice; a streak; Share opens the iOS share sheet with one line of text.
- Zen Bog: relaxed and endless; snaps never run out, nothing wilts, no leaderboard. Pause > End shows the results.
- Goals: three at a time on Home (shown once you have played a little), from 39. Garden: 8 cosmetic flytraps. Bug Book: 16 species. 12 cosmetic plant ranks.

5. CONTENT
A cartoon flytrap catching cartoon bugs, the way a frog catches flies. No blood or injury; bees and wasps are always let go unharmed.

6. PRIVACY
No SDKs, analytics, ads or tracking. Progress stays on the device; Share sends nothing itself. App Privacy: Data Not Collected.

7. GAME CENTER
Optional. 2 leaderboards (Best Score from Endless, and the Daily Bog; Zen and Levels submit none), 12 achievements (575 points), none hidden.

8. OTHER
- No notifications. Debug and demo modes are disabled in Release builds.
- Sound plays with the silent switch on; Settings > Respect silent switch turns that off.
```
<!-- REVIEW-NOTES:END -->

## Check against the build (before submission)

**R9 (28 Oct):** "Code" ticked where the R8 source says so (read on this host; not compiled here). Tick **RC** on the build that is submitted (the founder's real-Duo pass and one regular-iPhone pass).

| Claim in the block | Source in the code | Code | RC |
|---|---|---|---|
| Tap anywhere snaps on a phone without a hinge; the trap reopens by itself | `Input/TouchTrapSource.swift` (instant bite, `Tuning.touchRearmDelay` 0.45) | [x] src | [ ] |
| Home: Play = the next level (Level 1 first); Endless, Daily, Zen; Levels, Bug Book, Garden, Settings | `UI/HomeView.swift` labels; `GameController.play()` = `LevelRules.next`; every launch opens on Home (`design/notes/app-R8.md`) | [x] src | [ ] |
| Level 1 is one fly and passable by a tap | `LevelData.swift` L1 (catch 1, 3 bites) | [x] src | [ ] **R8 CI's perfect pilot logged `level result 1 stars=0`: play it by hand on the RC** |
| Score = points × count × chain (to ×5); 12 snaps (14 / 13 / 12 in the first three Endless runs), max 14; Feast refunds; bee +1, wasp +2; "Your trap is tired" | `Core/Tuning.swift` | [x] src | [ ] |
| 30 levels, 3 worlds, goal + bite limit + 1–3 stars; 20 / 40 stars open Dusk / Night | `LevelData.swift`, `LevelBook.worldUnlockStars` | [x] src | [ ] |
| Public `onHingeChange` only, behind `#available(iOS 27.1, *)`; angle + status never stored or sent | `Input/HingeReader.swift` | [x] src | [ ] |
| Every round starts closed: "Close the phone to start" | `TrapSnapshot.waitingForClose`, `LevelViews.CloseToStartCard` | [x] src | [ ] exact wording on the Duo |
| The bite fires at the shut (θ ≤ 18°, or `.closed` with θ ≤ 25°); a partial close never bites; re-arm at 35° | `SnapDetector`, `Tuning.shutAngle` / `statusShutAngle` / `armAngle` | [x] src | [ ] |
| While shut: clock frozen; the outer display's CHOMP card, "Open to keep feeding" | `TrapSnapshot.shut`, `UI/ChompCard.swift` | [x] src | [ ] |
| Any pose plays; no pose card | `AppRules.pose` (`AppPose` is `play` / `cover`), `PoseCard` deleted (`design/notes/portrait-R8.md`) | [x] src | [ ] |
| Settings **"Score on the left"**, **"Respect silent switch"** | `UI/SettingsView.swift` | [x] src | [ ] |
| No achievement or leaderboard rewards close speed or count | `achievements.md` = `Achievements.all` | [x] src | [ ] |
| Daily: one scored try, practice; streak; **Share** (scored Daily only) | `RunMode.daily(day:scored:)`, `ResultsView` `ShareLink` | [x] src | [ ] |
| Zen: snaps never run out, no wilts, no leaderboard; pause **End** | `SessionOptions.for(.zen)`, `GameCenterManager.report` | [x] src | [ ] |
| Levels submit no score | `GameCenterManager.report` (`.level`: none, `design/notes/app-R8.md`) | [x] src | [ ] |
| 2 leaderboards, 12 achievements, 575 points, none hidden | `achievements.md` | [x] src | [ ] |
| No notifications, no rating prompt | no `UNUserNotificationCenter` / `requestReview` in `Snap/` (grep, 28 Oct) | [x] src | [ ] |
| Debug and demo modes disabled in Release | `App/DemoMode.swift` (`#if DEBUG`) | [x] src | [ ] |

## If rejected under 2.4.2 (hardware) or 1.4.5 (physical harm)

Reply in the Resolution Center, calmly and specifically:
> "Snapjaw's bite is simply closing the phone, the way a foldable is closed many times a day. The game never measures force: the bite fires as the halves meet, so a gentle close catches exactly as much as a hard one, and nothing asks the player to slam, shake or press the device. Bites are a limited resource (12 to start, 14 at most in Endless; each level has a small bite limit), so the design rewards waiting for the right moment rather than closing often. No score, achievement or leaderboard rewards closing speed or the number of closes. Any iPhone without a hinge plays the full game by tapping the screen."

## If rejected under 2.1 (couldn't use the hinge)

Point to §1: the full game is playable without a Duo, by tapping. Offer the Duo video attachment.

## If rejected under 4.2 or 2.3 (minimum functionality / accurate metadata)

Point to §4: 30 hand-made levels in three worlds with stars, an endless mode with a day cycle and 16 species, a daily mode with a streak, a relaxed Zen Bog, 39 goals, a Garden of 8 flytraps, a Bug Book and 12 plant ranks; the store copy and screenshots show only what the build does (`screenshots.md` truthfulness rules).

## Sources
- App Review Guidelines (2.1, 2.3, 2.4.2, 1.4.5, 4.2): https://developer.apple.com/app-store/review/guidelines/
- App Store Connect Help, *Platform version information* (App Review notes up to 4,000 bytes): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
