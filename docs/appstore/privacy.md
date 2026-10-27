# Snapjaw: App Privacy answers and privacy policy (v1.0)

**Answer: Data Not Collected.** Based on the design (`CLAUDE.md`: "no data collected"; `design/ARCHITECTURE.md`: no third-party packages; persistence is `ProgressStore` and `SettingsStore` in UserDefaults) and the privacy manifest `Snap/PrivacyInfo.xcprivacy` that the CI engineer copies from Swoop (no tracking, no tracking domains, no collected data types; required-reason APIs UserDefaults `CA92.1` and system boot time `35F9.1`). **The build doesn't exist yet:** Claude runs the grep in §3 when Round 1 compiles and again on the release candidate, and pastes the results here.

The live policy page is `docs/site/privacy.html` (the text in §4 is the same; keep the two in step).

---

## 1. What to click (App Store Connect → the app → App Privacy)

1. **Privacy Policy URL:** `https://pravegm.github.io/snapjaw/privacy.html`. The page must load before you save (runbook §0b turns the website on).
2. Click **Get Started**. "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**
3. **Save**, then **Publish**. The product page shows **"Data Not Collected"**.

There's no tracking question once you choose "No". For the record, Snapjaw doesn't track: no advertising identifier, no `AppTrackingTransparency`, no data brokers.

## 2. Why these things don't change the answer

| Thing | Declare? | Why |
|---|---|---|
| **Hinge angle** | No | Read through the public `onHingeChange` API to work the trap while the game is on screen. The rest reference is a rolling value in memory (`SnapDetector.reference`), not saved. Nothing leaves the phone. Apple: "collect" means transmitting data off the device. *If the build ever saves a resting angle, it stays on the device and the answer is unchanged; only the policy sentence in §4 changes (Swoop's wording)* |
| **Game Center** (sign-in, leaderboard scores, achievements) | No | Apple collects it under Apple's privacy policy. Apple: "You are not responsible for disclosing data collected by Apple." Snapjaw never sends it anywhere itself |
| **Crash reports** via iOS "Share With App Developers" | No | Apple-collected and opt-in. We add no crash SDK. *If one is ever added, the label must declare Crash Data first* |
| **Rating prompt** (if added) | No | Apple's `requestReview` |
| **Support through GitHub issues** | No | Happens on GitHub, outside the app, under GitHub's privacy statement; covered by the policy |
| **Progress, scores, Bug Book, plant rank, achievements, Daily Bog tries, settings** | No | Stored only on the device (`ProgressStore`, `SettingsStore`, UserDefaults). Never transmitted |
| **A Daily share button** (not in the design; `metadata.md` §11 ask 7) | No, if added the iOS way | Text handed to the share sheet only on tap; the policy gains a "Sharing" paragraph first |

**The limit to watch:** if a future version ever sends anything to our own server (Game Center IDs, analytics, a remote daily seed, online ghosts), this answer and the privacy manifest change **before** that build ships.

## 3. Evidence to collect on the build (Claude runs this; paste the result here)

| Look for, in `Snap/` | Expect | Result (Round 1) | Result (RC) |
|---|---|---|---|
| Networking: `URLSession`, `URLRequest`, `NWConnection`, `import Network`, sockets | none (GameKit is the only outbound path) | [ ] | [ ] |
| Web/links: `WKWebView`, `SFSafariViewController`, `openURL`, SwiftUI `Link(` | none, or only a link to the support/privacy page (opening Safari is not collection) | [ ] | [ ] |
| SDKs: Firebase, Crashlytics, Sentry, Mixpanel, Amplitude, AdSupport, `ASIdentifierManager` | none | [ ] | [ ] |
| Tracking: `AppTrackingTransparency`, `ATTrackingManager` | none | [ ] | [ ] |
| Cloud: `CloudKit`, `NSUbiquitousKeyValueStore` | none | [ ] | [ ] |
| Notifications: `UNUserNotificationCenter` | none | [ ] | [ ] |
| Hinge angle written to disk (`ProgressStore`, `SettingsStore`, files) | nothing (or only a resting angle, on the device: then update §4's hinge paragraph) | [ ] | [ ] |
| Packages in `project.yml` | none | [ ] | [ ] |
| `NS*UsageDescription` keys in `project.yml` | none (no camera, microphone, photos, location) | [ ] | [ ] |
| `Snap/PrivacyInfo.xcprivacy` in the built app | present: tracking false, no tracking domains, no collected data types (the TestFlight workflow's upload job checks it in the archive, as Swoop's does) | [ ] | [ ] |
| Required-reason APIs | UserDefaults `CA92.1`, system boot time `35F9.1` (`CACurrentMediaTime`). If the code uses file timestamps or disk space, add those reasons | [ ] | [ ] |

One-line grep: `URLSession|URLRequest|NWConnection|WKWebView|SFSafari|openURL|Link\(|ATTrackingManager|ASIdentifier|CloudKit|NSUbiquitous|Firebase|Sentry|UNUserNotification`

---

## 4. Privacy policy (public text)

*Last updated 27 October 2026. Live at `https://pravegm.github.io/snapjaw/privacy.html`.*

> # Snapjaw Privacy Policy
>
> **The short version: Snapjaw doesn't collect any data about you.** There are no accounts, no ads, no analytics and no tracking, and the app makes no network requests of its own. Your progress stays on your iPhone.
>
> ## What Snapjaw collects
> Nothing. Snapjaw has no sign-up and no login. It contains no advertising, analytics, crash-reporting or tracking code from anyone, and it doesn't ask for your camera, microphone, photos, contacts or location.
>
> ## The hinge on iPhone Duo
> On iPhone Duo, Snapjaw reads how far the phone is folded, only to work the flytrap while you play. That reading is used there and then. It never leaves your iPhone.
>
> ## What stays on your device
> Your scores, your Bug Book, your plant rank, your achievements, your Daily Bog tries and your settings are saved only on your iPhone. We can't see them. If you delete the app, they're deleted too.
>
> ## Game Center (optional)
> If you're signed in to Game Center, your scores and achievements are handled by Apple under Apple's Privacy Policy (apple.com/legal/privacy). We don't receive your Game Center profile.
>
> ## Crash reports
> If you've chosen in iOS Settings to share analytics with app developers, Apple may pass us anonymous crash reports. We use them only to fix bugs. You can turn this off at any time in Settings > Privacy & Security > Analytics & Improvements.
>
> ## Tracking
> Snapjaw doesn't track you across apps or websites, and it never asks for tracking permission.
>
> ## Children
> Snapjaw is rated 4+ and collects no personal information from anyone, including children.
>
> ## This website
> These pages have no cookies, analytics, trackers, embedded media, external fonts or scripts. They are hosted by GitHub Pages, which may keep standard server logs (such as IP addresses) for security, under GitHub's own privacy statement.
>
> ## If you contact us
> Support happens through GitHub issues (github.com/pravegm/snapjaw/issues). Issues are public, so please don't include personal details. GitHub handles your GitHub account under its own privacy statement. We use what you write only to reply and fix the problem, and we'll delete or hide an issue if you ask.
>
> ## Changes
> If this policy ever changes, we'll update this page and its date before the change reaches the app.
>
> ## Contact
> Snapjaw, an independent game by pravegm. Privacy questions: open an issue at github.com/pravegm/snapjaw/issues.

*(Founder to decide: if a legal or trading name, an email address or a postal address is ever required, for example for EU trader status, add it to the Contact section and the live page. It is deliberately left off, as for the sister games.)*

## Sources
- Apple, *App privacy details on the App Store* ("collect" means transmitting off the device beyond real-time servicing; "You are not responsible for disclosing data collected by Apple"): https://developer.apple.com/app-store/app-privacy-details/
- Apple, *Privacy manifest files* and required-reason APIs: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Swoop's submitted answers (structure mirrored): `C:\Users\59527\Wing\docs\appstore\privacy.md`
