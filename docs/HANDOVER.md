# Snapjaw: handover for the founder (night of Wed 28 Oct 2026)

## What it is (since Round 8)
**Snapjaw — "Feed the flytrap. Spare bees."** Your fifth Duo game. £1.99, no ads, no in-app purchases, no data
collected, rated 4+.
- **The phone is the trap.** Open phone = open trap; closed phone = closed trap. The two halves are a Venus flytrap's
  lobes and the hinge is its midrib. Any opening plays: landscape or portrait, wide open or part way. No pose demands.
- **Every round starts closed.** If the phone is open at Play, the game says "Close the phone to start"; opening it
  then opens the trap and the bugs arrive.
- **The bite fires only when the phone fully closes** (about 18°, or iOS's closed status below 25°). A partial close,
  however deep, never bites. Flies feel the closure and flee a slow close, so a decisive close is the skill.
- While it is shut, the **outer screen shows the CHOMP card** (the closed trap, the catch, a tip) and the game clock is
  frozen. Open it again to keep feeding.
- **Other iPhones:** tap to snap. Every level and mode plays in full.
- **Never eat a bee:** a bee in the bite is let go and costs an extra snap; a wasp stings for two.
- **Score** = points × bugs caught × chain (up to ×5; only clean bites of 2+ grow it; an empty bite, an escape or a
  bee breaks it). **Snaps:** 12 to start (14, 13, 12 in your first three runs), 14 max. A Feast (3+) wins one back; a
  clean **FEAST** (5+) scores double and wins two.
- **Modes:** **30 Levels** in three worlds (Morning Bog 1–10, Dusk 11–20, Night 21–30), one goal each, up to 3 stars,
  20 stars open Dusk and 40 the Night; **Levels 1–5 teach** (the First Bite lesson is gone). **Endless** (was "Feed"): the
  arcade run, morning to night. **Daily Bog** (one scored try, streak, Share). **Zen Bog** (never ends).
- **Also in:** three goals at a time from 39, 12 plant ranks, the Garden (8 flytraps), the Bug Book (16 species),
  Game Center (2 leaderboards, 12 achievements). Settings: Sound, Haptics, Respect silent switch, Score on the left,
  Reduce motion, Replay Level 1.

## Why Round 8 happened
You tested TestFlight build 1 (the R7 game) on your Duo on 28 Oct and rejected it: "the flytrap shuts much before the
duo lid", "if the phone is open the flytrap is also open", "super easy", "Menus feel cheap", "Unclear what to do". R7's
22° partial snap drew the trap shut while the phone was still open. The critic panel had scored design 8 and missed
all of it. R8 rebuilt the core verb to your rules (`design/ROUND-8.md` §1b, now in `CLAUDE.md`), made runs genuinely
harder (sim novice median 71 s, casual 145 s, expert 283 s), added Levels and Endless as you chose, and rebuilt the menus.

## Why this idea
- The market check is in `research/01-market.md`.
- **The overlap:** a free game, Fold Smasher (23 Oct), already lets you clap the Duo shut on bugs to *smash* them.
  Snapjaw is choosing your moment, crowds and the multiplier, sparing bees, a snap economy and the plant itself.
- **Store copy** never says "smash" or "lid".

## Where it stands
- **Rounds:** R1–R5 built the game; R6 added depth (goals, the Garden, Zen, the Daily streak, FEAST as an event); R7
  polished it (distinct varieties, FEAST pays ×2, keep-out zones, one message at a time) and became TestFlight build 1.
  **R8** (commit `e3aca91`) is the rebuild; **R8b** (`69f028b`) made portrait/laptop play (no pose card).
- **R9 (in progress tonight, not yet compiled or committed):** clearer menus and "what to do" (Home shows less to a new
  player, Level goals worded for your control, CHOMP card tips, Settings "Replay Level 1"), difficulty and level tuning,
  and the App Store listing and website rewritten for R8.
- **Store kit:** `docs/appstore/` (R9 rewrite, `design/notes/store-R9.md` has the run checklist) and the website
  (`docs/site/`, served through GitHub Pages; updated for R8).
- **Not yet proven:** nobody has played R8 on a real Duo. Your hands are the judge.

## What only you can do (click-by-click in `docs/LAUNCH-RUNBOOK.md` and `design/notes/store-R9.md` §4)
1. **Done:** the repo is public, the App Store record exists (Apple ID 6828066230), TestFlight works.
2. Check GitHub Pages is on (§0b) and the three web addresses load.
3. Install the R9 TestFlight build and run the **§5 Duo test** (rewritten for R8). Tell me: does the trap stay open
   until the phone shuts, does the CHOMP land at the shut, is it hard enough, do the menus feel premium, is it clear.
4. In App Store Connect: App Privacy (Data Not Collected) → Publish; Family Sharing on; untick Mac and Vision Pro;
   the Digital Services Act answer; check the 4+ age rating; Game Center on.
5. **Submit** the build. Release is manual: an approved 1.0 waits for you until **Tue 8 Dec** (fallback 12 Jan).

## Known open items
- `design/notes/store-R9.md` asks: confirm in the next CI run that Level 1 gives 3 stars to a perfect pilot and is
  passable by a tap (App Review plays it first); make the store screenshot run after R9's app changes land.
- Core copy: goal scopes still say "Feed or Daily" (`Snap/Core/Goals.swift`); Endless is the new name.
- Level star thresholds are a first cut tuned on pilots; your hands should re-tune them.
- To confirm on your real Duo: the bite at the shut, the CHOMP card on the outer screen, the reopen, portrait play,
  which half blurs (Settings › "Score on the left" flips the HUD), haptics strength.

The full history is in `docs/PROJECT-LOG.md`, the decisions in `design/`, and every review in `design/REVIEW-*.md` and
`design/SCORE-*.md`.
