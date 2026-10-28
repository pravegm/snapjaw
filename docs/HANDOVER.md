# Snapjaw: handover for the founder (morning of Wed 28 Oct 2026)

## What it is
**Snapjaw — "Feed the flytrap. Spare bees."** Your fifth Duo game. £1.99, no ads, no in-app purchases, no data
collected, rated 4+.
- Hold the Duo open like a book: the two halves are a Venus flytrap's lobes, and the hinge is its midrib.
- Bugs fly in and land to sip nectar.
- **Snap the phone a little shut** (about 22° from however you hold it; never flat, never fully shut) to catch
  everything in the trap that's slower than your snap. Then open it again.
- Wait for a crowd: score = points × bugs caught × chain. A Feast (3+ bugs) earns snaps back.
- **Never eat a bee.** Bees and wasps cost snaps. Snaps are your lives.
- **Hunger.** If you dawdle while a catchable bug sits uneaten, the trap wilts a snap.
- **The day.** It runs morning → noon → dusk → night, with 16 species to collect in the Bug Book (golden scarab,
  dragonflies, fireflies at night).
- **Also in:**
  - a Daily Bog, the same for everyone, with a share line;
  - 12 plant ranks;
  - Game Center: 2 leaderboards and 12 achievements, with badges drawn;
  - a 7-step First Bite tutorial;
  - tap-to-snap on non-Duo iPhones.

## Why this idea
- The market check is in `research/01-market.md`.
- **The overlap:** a free game, Fold Smasher (23 Oct), already lets you clap the Duo shut on bugs to *smash* them.
  Snapjaw is built on everything that game doesn't do:
  - choosing your moment;
  - crowds and the multiplier;
  - sparing bees;
  - a snap economy;
  - the plant itself.
- **Store copy** never says "smash".
- **Other October launches:** Foldfish (the hinge as a rod) and ChompDuo (a mouth toy).

## Where it stands
- **Code:** about 20,000 lines of Swift, built in 5 rounds by parallel engineer agents (game rules, input/sound/haptics,
  art, app, CI), with a critic panel and 9 first-time "fresh player" testers in between.
- **Tests:** 283 automated tests, green on GitHub's Mac (CI run 40634463943). Round 5 is in progress.
- **Critic scores R1 → R4:**

  | Critic | R1 | R4 |
  |---|---|---|
  | Apple-juror | 5 | 7 |
  | UX | 4 | 8 |
  | Feel | 4 | 8 |
  | Icon | — | 8 |

  Fresh players rated "feels finished" 6–7.
- **Duo simulator:** the hinge-driven snap has caught bugs (R1: 10 caught). The 951×669 Duo frames look right. Later
  simulator runs kept crashing mid-sweep; that's the CI rig, and it's being hardened.
- **Your real Duo is the last proof:** nobody has snapped a real hinge yet.
- **Store kit ready:** the listing, keywords, review notes, privacy answers, achievements, press kit and site pages
  (`docs/appstore/`, `docs/site/`). The App Store Connect upload tool and the screenshot pipeline are ported from
  Swoop.

## What only you can do (click-by-click in `docs/LAUNCH-RUNBOOK.md`)
1. **Done:** the repo is public (thank you).
2. **§0b:** turn on GitHub Pages (5 min). These are the support and privacy pages Apple needs.
3. **§1:**
   - Do the trademark check for "Snapjaw".
   - Register the bundle ID **com.pravegm.snapjaw**.
   - Create the App Store Connect app record (name Snapjaw, SKU `snapjaw-2026`, English (UK)).
4. **§2:** add the **4 App Store Connect secrets** to pravegm/snapjaw, with the same values as Swoop's (10 min).
5. **§3:** turn on Game Center, then run the "App Store Connect tool" workflow (plan, then push). It fills in the whole
   listing.
6. **§4:** run the **TestFlight** workflow (2 clicks) and install it on your Duo.
7. **§5:** the 15-step Duo test (about 15 min). Tell me how the snap feels, whether the halves blur, and the sound and
   haptics. That's what I tune next.

After that, the runbook plans a launch in early December. It sits between Brim (17 Nov) and Hush (1 Dec), with the
fallback 12 Jan. It can go sooner: once your Duo test is good, Snapjaw can be submitted with "release on approval".
Your call.

## Known open items
- Round 5 (in progress): see `design/ROUND-5.md`.
- Things to confirm on your real Duo:
  - the snap feel and timing (`SNAP-H` logs);
  - which half blurs (the score sits on the right half by default; Settings › "Score on the left" flips it);
  - the 120 fps feel;
  - haptics strength.

The full history is in `docs/PROJECT-LOG.md`, the decisions in `design/`, and every review in `design/REVIEW-*.md`.
