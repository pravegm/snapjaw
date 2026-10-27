# Snapjaw: Featuring nomination (App Launch)

*Written Tue 27 Oct 2026 by the launch lead. **The App Store Connect tool creates and submits it** (`asc.yml`, step `nomination`, `"submit": true`, from `docs/appstore/asc-metadata.json`); nobody pastes it. Change the text here, regenerate the JSON, and push the `nomination` step again. It needs only the app record and the GitHub secrets (runbook §1–§2), not a build.*

## Timing

**Launch date: Tue 8 Dec 2026, about 08:00 UK, released by the founder** (`metadata.md` §12). Swoop goes live on approval (about 29–30 Oct), Brim on Tue 17 Nov, Hush on Tue 1 Dec; Snapjaw takes the next free week.

Apple asks for nominations as early as possible, ideally **at least 3 weeks before** the date: **submit by Mon 16 Nov** (3 weeks and a day; not on Tue 17 Nov, Brim's launch day). Sooner is better: the tool submits it in runbook §3, as soon as the app record and secrets exist (about 6 weeks' notice).

Where to see it: App Store Connect → Apps → Snapjaw → **Featuring** → **Nominations**. A saved draft is not a nomination, which is why the tool submits it.

If the launch moves (the fallback is Tue 12 Jan 2027), tell Claude: the Publish Date changes in the JSON and the tool pushes it (or edit it by hand on the same page).

## Fields

| Field | Value | Count / limit |
|---|---|---|
| Nomination Name | `Snapjaw - App Launch - iPhone Duo Venus flytrap game` | 52 / 60 |
| Nomination Type | **App Launch** | — |
| Description | the block below | **925 / 1,000** |
| Publish Date | **Specific day: 2026-12-08** | — |
| Related Apps | Snapjaw only (auto-filled). Don't add Squish, Brim, Swoop or Hush: they have their own nominations | up to 10 |
| Platforms | iOS | — |
| Countries or Regions | leave the auto-selection (every territory the app is in) | — |
| Localizations | leave the auto-selection (English (U.K.), English (U.S.)) | — |
| In-App Events | none | — |
| Supplemental Materials | 1. `https://pravegm.github.io/snapjaw/` 2. the teaser clip (`social-launch.md` §3A) once it exists, added by editing the nomination 3. the TestFlight public link (only if you open external testing) | up to 5 URLs |
| Helpful Details | the block below | **470 / 500** |

### Description
```
Snapjaw turns iPhone Duo into a Venus flytrap. Hold the Duo open like a book: the two halves are the trap's lobes and the hinge is its midrib. Bugs land on the glistening nectar to sip; snap the phone a little shut and the trap bites with you, teeth clacking together, then open it again.

It's a game of choosing, not hitting. Wait for a crowd and catch them all in one bite, for a score multiplied by the number of bugs, but bees love nectar too and must never be eaten. Snaps are the resource, and big bites earn them back. Every run passes from morning to night with new bugs, from houseflies to dragonflies and fireflies, and a Bug Book of 16 species to fill.

A First Bite lesson teaches by doing. A Daily Bog that's the same for everyone, 12 plant ranks and Game Center. Other iPhones play by tapping. Every sound, from the CHOMP to the frogs, is synthesized in the app. No ads, no in-app purchases, no data collected.
```

### Helpful Details
```
Optimized for iPhone Duo: built for book pose on the inner display. Public iOS 27.1 hinge API: a snap is a short close of about 22 degrees from the player's own resting angle, never flat and never shut, and the bite fires at 22 degrees, so closing further gains nothing. The score stays on the half that doesn't blur when a fold starts from flat. Snaps are a limited resource, so patience beats folding often. Taught by doing. Also from us: Squish, Brim, Swoop and Hush.
```

**Why this copy:**
- **New hardware first:** the opening line, and "Optimized for iPhone Duo" in Helpful Details (Apple's Duo guidance asks for exactly that phrase).
- **The fantasy in one image:** the phone's halves are the trap's lobes and the hinge its midrib. It's literally what a flytrap is.
- **The difference from the free toys, without naming them:** "a game of choosing, not hitting", crowds, bees to spare, a snap economy. Never "smash".
- **Built for the real device:** a relative snap that follows the player's own pose, the HUD on the sharp half, the bite decided at 22° so nobody is tempted to close it further. Editors look for apps that handle the Duo's quirks, not just its hinge.
- **Craft:** synthesized sound, a lesson that teaches by doing.
- **Replayability:** endless runs through a day cycle, the Daily Bog, the Bug Book, plant ranks, Game Center.
- **Reach:** tap to snap on other iPhones (iOS 18 or later). No VoiceOver claim, because that label isn't earned (`accessibility.md`).
- **No ads:** the last line.

## Later nominations (optional)
- **New Content**, for the first update with real new content (for example new bugs or a second bog). Description: what's new, one line restating no ads and a free update. Submit 3 weeks ahead.
- An **In-App Event** (a "Bee Week" Daily Bog, for example) needs a build that implements it first; don't create one for 1.0.

## Sources
- App Store Connect Help, *Nominations template* (name ≤ 60, description ≤ 1,000, helpful details ≤ 500, up to 5 URLs, types): https://developer.apple.com/help/app-store-connect/reference/nominations/nominations-template
- App Store Connect Help, *Nominate your app for featuring* (minimum 3 weeks' lead time): https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring
- Swoop's nomination (format mirrored): `C:\Users\59527\Wing\docs\appstore\featuring-nomination.md`
