# Review R2: game UX and onboarding

**Score: 6 / 10** (R1: 4). The lesson now does its job:
- the target bugs sit on real nectar drops;
- a lime ring and dashed arrow point at each one, and a dashed white ring marks the bee;
- the steps are numbered "1 of 4" to "4 of 4" on a phone;
- Skip is always there;
- the closing card names all four rules (cost, refund, bees, wilt).

What holds the score back:
- the lesson never points at the snaps row (the resource the whole game is about);
- the hint copy truncates at the worst moment;
- the HUD glyphs don't look like "snaps";
- a first run still ends in about a minute.

## R1 issues: fixed / not fixed
| R1 # | Issue | R2 status |
|---|---|---|
| 8 | Lesson flies don't sip | **Fixed.** In 04 → 05 the right-lobe fly covers the drop at (1205,513) that was visible in 04; in 08 the third fly covers (905,620). |
| 9 | Pointer, bee linger, "Now!" | **Fixed** (04–08 rings and arrows; 07 holds the bee; 08 says "now tap!" with all three ringed). |
| 13 | Bug Book jokes truncated | **Fixed for 3-line jokes** (28). **New truncation:** "Golden Sca…" title, and the Bee's joke runs off the bottom (29). |
| 16 | Hint plate on the thumb arc | Moved to the right edge at mid-height on the phone (11, 12, 15, 33): OK for the phone. On the Duo that position *is* the thumb band (`REVIEW-1-duo` §Thumbs); unverified. |
| 22 | Phone lesson numbering and copy | **Fixed** ("Step 1 of 4", "Two flies. Get both in one bite."). |
| 23 | Results and Home polish | **Mostly fixed** ("4 bugs · 688", "+2", "First run!", the "Catch 30 bugs to grow" rank hint). New: "A 8-bug FEAST" (26); "×1.5 (1 bite)" (20, 27) is confusing. |
| 24 | First impression too short | **Not really fixed.** Sprout gets 12 snaps, but the novice run is 41 s (sim) / 50 s (Sprout sim); frame 20's log says `seconds=62`. |
| P2 | One "open to carry on" copy | **Not as described.** App-R2 says both cards now read "Open it up to carry on", but 32 reads "Open it like a book / Bugs are gathering in the bog." The run's score is still absent. |

## P0
1. **Truncated climax hint (15, 18):** "Last snap — make i…". Use three lines or "Last snap!", plus a `HUDLayout`
   test that renders every `TrapHint` string at both plate widths with no truncation.
2. **Teach the resource.**
   - The lesson (04–08) shows no snaps row at all.
   - The first time a player sees the 12 glyphs is in play (10), next to a "11" numeral, and the glyphs look like
     watermelon slices.
   - Fix:
     - show the snaps row during lesson steps 3–4;
     - on the card (09), ring it with the same lime pointer ("These are your snaps");
     - on the first Feast in Feed, fly the refunded glyph with a one-time label "+1 snap".
3. **First run length.**
   - A Sprout novice is done in under a minute (41–62 s), and the first Results says "Your trap is tired" before the
     player has seen noon.
   - For a £1.99 first impression, target ≥ 90 s for runs 1–3:
     - no wilt in run 1 (hunger is taught by the card, but the first run shouldn't punish it);
     - the first bee of runs 1–3 costs 0 with a "Bees cost a snap!" toast.

## P1
4. **The snap glyph doesn't say "snap".** The pink-and-green half-ovals with white teeth (10–34) read as melon
   slices or lips. Draw a mini closed trap (green backs, a crimson seam, cilia). An empty slot is a grey outline. The
   draining slot (33) needs to be obvious: today it is a faint pink outline only on the last slot. Pulse it crimson
   and tick the numeral red at 3 s.
5. **Bee lesson (07):** the bee lands on the rim at top-left, not on a nectar drop. The lesson's point is that bees
   sip too ("that's the trap"). Use `lessonSpot` for the bee. Then "Never eat a bee. Wait…" sits on a bee that is
   visibly sipping beside flies.
6. **The hunger copy.** "Hungry… bite!" (33) while 9 bugs are sipping is right. But nothing tells the player *why*
   their snap count fell in 34: "wilted −1" is small, lowercase and off to the side. Use "Too slow! −1 snap" as a
   crimson tag over the snaps row, and the hint "Bite something!" the first time.
7. **Results wording (20, 26, 27):**
   - "Longest chain ×1.5 (1 bite)" sounds like a chain of one. Use "Best chain ×1.5 · 2 bites" or "2 big bites in a
     row".
   - "A 8-bug FEAST" → "An 8-bug FEAST".
   - Show "New best!" next to the previous best ("was 3,200").
8. **Bug Book (28, 29):**
   - "Golden Sca…": use `minimumScaleFactor` on the title or the short name "Scarab".
   - The 4th row is hidden under the screen edge with no fade or scroll cue.
   - The fixtures show "Caught 27" or "Caught 166" for every bug: vary them so the frames don't look fake.
9. **Settings (30):** remove "Debug · input touch". The Credits card is clipped mid-sentence at the bottom with no
   scroll cue.

## P2
10. Lesson frames 05 and 06 are identical because the phone merges step 3. Rename the scenario, or capture the Duo
    re-arm step in duo.yml.
11. Home (01): "Tap the trap. It bites!" is the only instruction on Home. On a Duo it should read "Snap it a little
    shut. It bites!" (it did in duo1 `duo-ui-home-160`); check that the R2 Home keeps the hinge copy.
12. The cover card (32) needs the run's score and the promised copy: "Open it up to carry on · 1,174 so far".
13. The "Now!" hint (11, 34) fires when the bugs are spread over both lobes, so it teaches "snap at any 3+". That is
    right for the rules, but it means the crowd is never one place. See Feel on the nectar clusters.
