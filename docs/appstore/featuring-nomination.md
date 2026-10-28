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
| Description | the block below | **937 / 1,000** |
| Publish Date | **Specific day: 2026-12-08** | — |
| Related Apps | Snapjaw only (auto-filled). Don't add Squish, Brim, Swoop or Hush: they have their own nominations | up to 10 |
| Platforms | iOS | — |
| Countries or Regions | leave the auto-selection (every territory the app is in) | — |
| Localizations | leave the auto-selection (English (U.K.), English (U.S.)) | — |
| In-App Events | none | — |
| Supplemental Materials | 1. `https://pravegm.github.io/snapjaw/` 2. the teaser clip (`social-launch.md` §3A) once it exists, added by editing the nomination 3. the TestFlight public link (only if you open external testing) | up to 5 URLs |
| Helpful Details | the block below | **453 / 500** |

### Description
```
Snapjaw turns iPhone Duo into a Venus flytrap. The phone is the trap: open it and the lobes open, the hinge is the midrib, and bugs land on the glistening nectar to sip. Close the phone and the trap closes with it: CHOMP. While it is shut, the outer display shows the catch; open it again to keep feeding.

It's a game of choosing, not hitting. Wait for a crowd and catch them all in one bite, close decisively or the flies escape, and never eat a bee. 30 hand-made levels across Morning Bog, Dusk and Night teach it, then test it, with up to three stars each. Endless runs pass from morning to night with new bugs, and a Bug Book of 16 species waits to be filled.

Three goals at a time grow your plant through 12 ranks and a Garden of 8 flytraps. A Daily Bog with a streak, a Zen Bog that never ends, and Game Center. Other iPhones play by tapping. Every sound is synthesized in the app. No ads, no in-app purchases, no data collected.
```

### Helpful Details
```
Optimized for iPhone Duo. Public iOS 27.1 hinge API, read literally: open phone, open trap. The bite fires as the halves meet; a partial close never bites and force is never measured, so a gentle close works. Every round starts closed, any pose plays (landscape or portrait) and the outer display shows a CHOMP card while shut. Bites are limited, so patience beats closing often. Levels 1 to 5 teach by doing. Also from us: Squish, Brim, Swoop and Hush.
```

**Why this copy (R9, the R8 game: 937 / 1,000 and 453 / 500, counted with Node):**
- **New hardware first:** the opening line, and "Optimized for iPhone Duo" in Helpful Details (Apple's Duo guidance asks for exactly that phrase).
- **The fantasy in one image, now literal:** the phone is the trap. Open = open, closed = the bite; the outer display carries the CHOMP. Editors look for apps that use both screens and the hinge honestly.
- **The difference from the free toys, without naming them:** "a game of choosing, not hitting", crowds, bees to spare, a bite economy, 30 levels. Never "smash".
- **Built for the real device:** the bite at the shut (so no force, no "slam"), every round starting closed, no pose demands, the cover display used for the result.
- **Craft:** synthesized sound, levels that teach by doing.
- **Replayability:** 30 levels with stars, goals that grow the plant, the Garden of 8 flytraps, the Daily streak, the Zen Bog, Endless through a day cycle, the Bug Book, Game Center.
- **Reach:** tap to snap on other iPhones (iOS 18 or later). No VoiceOver claim, because that label isn't earned (`accessibility.md`).
- **No ads:** the last line.

## Later nominations (optional)
- **New Content**, for the first update with real new content (for example new bugs or a second bog). Description: what's new, one line restating no ads and a free update. Submit 3 weeks ahead.
- An **In-App Event** (a "Bee Week" Daily Bog, for example) needs a build that implements it first; don't create one for 1.0.

## Sources
- App Store Connect Help, *Nominations template* (name ≤ 60, description ≤ 1,000, helpful details ≤ 500, up to 5 URLs, types): https://developer.apple.com/help/app-store-connect/reference/nominations/nominations-template
- App Store Connect Help, *Nominate your app for featuring* (minimum 3 weeks' lead time): https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring
- Swoop's nomination (format mirrored): `C:\Users\59527\Wing\docs\appstore\featuring-nomination.md`
