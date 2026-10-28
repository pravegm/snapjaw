# Review R5: the launch review

**Evidence.**
- **R5 phone build:** `artifacts/r5/screenshots/`. That is 43 frames on the iPhone 18 Pro (874 × 402 pt, tap build), plus
  `app-icon-1024.png` and 12 badges. The capture log has 43 rows, all `ok` and `expect-ok`. CI is green: 307 tests in
  16 suites (`artifacts/r5/logs/build.log`).
- **Duo aspect:** the R4 Duo run (`artifacts/duo4/`, 951 × 669, run 40634483657) on the R4 build.
- **Store set:** the R4-era set (`artifacts/store1/`: store-63, store-69, store-duo, store-placements).
- **Not available when this was written:** `artifacts/duo5/` (the R5 Duo run) and `artifacts/store2/` (the R5 store
  set). **So no R5 frame has been seen at Duo aspect, and the R5 hinge checks have not been run.**

The brief mentions 48 frames. The run produced 43 numbered frames; with the icon that is 44.

## 1. Scores

| Reviewer | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|
| ADA juror | 5 | 6 | 7 | 7 | **8** |
| UX / onboarding | 4 | 6 | 7 | 8 | **8** |
| Feel / economy | 4 | 6 | 7 | 8 | **8** |
| Duo specialist | 5 (prov.) | 5 (prov.) | 6 (prov.) | 6 (prov.) | **7** (prov.) |
| Icon, as a store asset | — | (fanged Pac-Man) | 7 | 8 | **8** |
| Badges, as a set | — | — | 7 | 7 | **8** |
| Store screenshot set | — | — | — | (not scored) | **5** (all R4-era) |

**Why each score:**
- **Juror 8.** All four R4 screen blockers are gone on the phone. The release is a crimson, open trap. There is one
  hero trap: the icon's, on Results, the cover and the badges. The HUD and banners agree, and the word is "score"
  everywhere in play. What stops a 9 is that nobody has seen this build on a Duo.
- **UX 8.** The pose card is clean and reads at a glance (31). "Step n of 4" is consistent (04). "Missed!", "−2 snaps"
  and "free!" make the economy legible (40, 41, 43). There are two small contradictions left (P2 list).
- **Feel 8.**
  - The release (14, 18, 39) is now the hero frame it should be.
  - The sting costs a number (40), and the tired banner waits for the 0 (19).
  - The economy passes every target. CI's 8 seeds give casual 131 s with 0 wilts, and Sprout runs 1 / 2 / 3 at
    98 / 95 / 85 s.
  - The clop and the heavier wasp wobble can only be judged on a device.
- **Duo 7 (provisional).**
  - In R4's hinge pass, every hinge-input check PASSED for the first time: SNAP at 125.9°, REARM, CREEP, CLOSE-PAUSE
    at 42.8° resuming at 120°, and no pause at 94.7°. That earns the point.
  - It stays provisional because:
    - these were R4 code;
    - the too-flat and cover checks were lost to a simulator death;
    - there is no R5 Duo frame;
    - there is no real-Duo snap log.
- **Icon 8.** It's unchanged and still strong. The two dark "nostril" dots on the front lip (about 480,710 and 595,690)
  were not lightened (R4 #14).
- **Badges 8.**
  - The set is properly varied now: a calendar (Daily), 10K in nectar, a crowned hero (Monarch), a hero with flies
    (Feast), and a hero with a bee leaving (No Bees).
  - All the art stays inside the disc, and the bugs and trap are both outlined.
  - Three hero badges still share one drawing, but in distinct layouts, which is fine.
- **Store set 5.** The layout, typography and Duo mock-up are excellent. But every frame is from the R4 build. Two
  frames show the R4 plum release, every play frame says "PROTEIN", and two captions don't match their frames (§4).

## 2. The R4 blockers

| # | R4 blocker | Status | Evidence |
|---|---|---|---|
| 1 | No one has seen the hinge work | **Half fixed.** | **Done:** R4 hinge pass (`duo4/checks.tsv`): SNAP `caught=2 escaped=4 stingers=1 d=0.264` at 125.9°, REARM, CREEP (63 creep lines, no snap), CLOSE-PAUSE, and no pause at 95° (frames duo-h1/h3/h4). **Still missing:** the R5 Duo run (`duo5/`), the too-flat check at 178°, the cover check, the lesson-hinge walk (`LESSON-HINGE`), any R5 Duo frame and any real-Duo snap. |
| 2 | The pose card renders broken | **Fixed on the phone.** | 31: one front-on Duo diagram with chevrons and a sipping fly, the title and one line beside it, no black quadrant and nothing overlapping. `poseCardFits` passed at 874×402, 951×669 and both portraits. The R5 Duo-aspect frame (duo-scenarios line 17) is still unseen. `duo4/duo-06` is the R4 card. |
| 3 | The release reads as a plum | **Fixed in the app. Still present in the store set.** | 14 (QUAD, crimson face, lime rim, cilia out), 18, 39 (FEAST ×6, open crimson trap), 40–42. `theReleaseIsCrimsonWithinEightyMs` passed. **But** store1 D02 and D04 are the R4 plum release (dark oxblood, no rim) and must not ship. |
| 4 | "Out of snaps" over a non-zero numeral | **Fixed.** | 19: a red **0** under "Your trap is tired. / Out of snaps". 40: "−2 snaps" while the numeral reads 2 mid-run, with no tired banner. `tiredBannerWaitsForZero` passed. |

**Verdict on the blockers:** #2–#4 are fixed in code and on screen. #1 is a CI deliverable. Its first half (the hinge
logic works in the simulator) is proven; its second half (the R5 build on a Duo) is not.

## 3. Remaining issues

### P0: would get the app rejected or embarrass it at launch

| # | Owner | Issue | Frames |
|---|---|---|---|
| P0-1 | CI (founder) | **The R5 build has never run at Duo aspect.** Land `duo5` before submission. Gate it on: hinge-input SNAP, REARM, CREEP, CLOSE-PAUSE, no pause at 95°, the too-flat plate at 178°, `LESSON-HINGE` (steps 2 → 3 → 4 by hinge), and R5 frames of the pose card, the cover, Results (hero trap) and lesson steps 2–3. This is a premium Duo-first game, so submitting a build nobody has seen on its own screen is the launch risk. | duo4 only (R4 code) |
| P0-2 | CI (founder) | **No store frame in store1 can ship.** Regenerate the whole set (phone 6.3/6.9, Duo, header, search) from the R5 build as `store2`: <ul><li>D02 and D04 are the plum release, the R4 P0 itself;</li><li>every play frame and D08 say "PROTEIN" where the app now says "score";</li><li>D10 says "Step 5 of 5" (the app says "of 4");</li><li>the D06 caption is untrue of its frame (§4).</li></ul> Screenshots that don't match the shipped UI are a 2.3 metadata risk and a reviewer's first impression. | store1 D01–D10, P01, header, search |

There is no P0 in the R5 code itself.

### P1: fix before or with submission

| # | Owner | Issue | Frames |
|---|---|---|---|
| P1-1 | CI | **The Daily Share button is untested.** No frame captures a scored Daily's Results. Capture it, and check that the text is right and that there's no link before launch. A broken share sheet in review is a cheap reject. | none (25 is Daily in play) |
| P1-2 | CI + founder | **No real-Duo snap log.** Run the 10 checks in §6 on TestFlight. The hinge constants (22° snap, 0.6 s reference, 50° pause) have only ever met a simulated hinge. | — |
| P1-3 | Core | **The Game Center text still says "protein".** `Achievements.score10k`'s detail is in `Core/Progression.swift` (App's hand-off). It's visible in Game Center, and Game Center text must also be updated in App Store Connect. | — |
| P1-4 | App | **A direct launch into lesson step 2 on a Duo says "tap to snap!"** The step's text is chosen before the first hinge sample (ci-R5). Through step 1 it is correct, so players are unlikely to see it, but a resumed or replayed lesson might. Pick the text on the first hinge sample, or default to "snap shut!" when `fold=1`. | R4 `duo-ui-lesson-2` log |

### P2: polish, 1.0.1 is fine

| # | Owner | Issue | Frames |
|---|---|---|---|
| P2-1 | App + Core | **"Hungry… bite!" while a haloed bee hovers on the rim/bog edge**, just outside the zone. The rule is right (it isn't in the trap), but it reads as a contradiction. Suppress the halo outside the zone, or show "Bee! Wait…" while a halo overlaps the rim. | 33 (bee at 575,835) |
| P2-2 | Scene | **The tired trap has no lime rim.** The dull oxblood edge is the old "plum" margin, only at run end. Keep the lime rim. | 19 |
| P2-3 | Scene | **Dusk is better but still sage-grey at the edges**, with no peach glow at the top-left. Check wave 18 on a Duo, and consider a sky alpha of 0.38. | 16, 37 |
| P2-4 | Icon | **Lighten the two dark dots on the front lip** (R4 #14, not done). | app-icon-1024 |
| P2-5 | Core | **Runs can be very long.** Without `pilotGiveUp`, expert and perfect reach the 600 s cap in 7 of 8 seeds (`SNAP-BAL nogiveup`). A patient human could play 10+ minutes. That isn't a bug, but telegraph the late night or cap the leaderboard concern before it's noticed. | build.log |
| P2-6 | App/UI | **Swift 6 isolation warnings** (`TrapDrawing.scale`, `ProgressStore.backupKey`) and a deprecated `appStoreReceiptURL`. They're harmless now, but they are errors in Swift 6 mode. | build.log |
| P2-7 | Scene (tests) | **The hero-trap margin probe now only logs.** It logged "found no lime". The frames show the lime margin, so fix the probe's mapping and re-arm the assert. | build.log, 26, badges |
| P2-8 | CI | **Stale review captions in `ci/scenarios.txt`:** 23 and 30 say "HUD on the left", and 26 says "protein". | — |

## 4. The store set

**Nothing in `store1` ships.** All of it was built from the R4 build (commit a9515f4, run 40637893235).

| Frame | Verdict | Why | Caption truthful? |
|---|---|---|---|
| D01 / P01 book hero, header, search | Re-shoot (same scene) | "PROTEIN"; a bee's halo is cut off by the right screen edge, next to "Now!" (it looks as if it says "now" with a bee on the rim). | Yes. "Best on iPhone Duo. Plays on other iPhones too." is accurate and good. |
| D02 feast | **Re-shoot (must)** | The R4 dark plum release. Use the R5 `ciShootOn=feast` open-after-bite frame (like phone 14). | Yes |
| D03 bee | Re-shoot | The R4 olive dusk; "PROTEIN". | Yes |
| D04 last snap | **Re-shoot (must)** | The plum release again. | Partly. "Big bites win snaps back" isn't shown, since the frame is at 1 snap. Use phone 14/39's "+1 snap" / "+2 (full)" moment, or change the subtitle. |
| D05 dusk | **Replace** | It's a night frame almost identical to D06 (same wasp, bumblebee and firefly positions). Shoot real dusk at wave 18 on R5. | No. It's captioned as the day's arc but shows night only. |
| D06 night | Re-shoot | "PROTEIN". | **No.** "Crickets, moths and a rare Golden Scarab", but the frame shows a dragonfly, a wasp, a bumblebee, a firefly and a grasshopper. Shoot a frame with a cricket and a moth, or recaption it "Fireflies light the night / New bugs come out after dark." |
| D07 Bug Book | Re-shoot for consistency | The content is fine (9/16, jokes). R5 changed the name line (Golden Scarab). | Yes |
| D08 results | Re-shoot | "protein" under the score. | Yes |
| D09 daily | Re-shoot | It shows the Home menu, not the Daily. Show the Daily's Results with the Share button. | Weak: it shows a button, not the feature. |
| D10 First Bite | Re-shoot | "Step 5 of 5" (R5 says "of 4"). | Yes |
| P02–P10 (phone 6.3/6.9) | Re-shoot | The same scenarios from the same R4 build. I only opened P01; the rest share D's problems by construction. Port `ciShootOn` to `ci/screenshots.sh` so P02 isn't the 0.3 s freeze. | as D |

**Rules for store2:** check every frame by eye at full size and at thumbnail size:
- no "protein";
- no hint that contradicts the frame;
- no halo cut by a screen edge;
- each caption's nouns visible in its frame;
- the bite frames open and crimson.

## 5. Launch verdict

**The R5 build is a launch-quality 1.0 *as software*, and it should go to TestFlight now.** On the phone evidence:
- the rules teach themselves;
- the four R4 screen and HUD blockers are gone;
- the economy passes every target, including the new Sprout taper;
- there's one hero trap from the icon;
- CI is green.

I found nothing in the R5 frames that would get it rejected.

**It is not yet ready for App Review, and it is pending more than the founder's real-Duo test.** Three things gate
submission, and none needs a code change unless one fails:
1. **`duo5` passes** (P0-1): the R5 build at Duo aspect, with hinge-input SNAP, REARM, CREEP, CLOSE-PAUSE, no pause
   at 95°, too-flat, and the lesson walked by hinge.
2. **`store2` is regenerated from R5 and passes the §4 eye-check** (P0-2). That means a new D05, a fixed D06 caption,
   and Daily + Share for D09.
3. **The founder's real-Duo test (§6) passes**, plus the Daily Share check (P1-1) and the Game Center "protein" string
   (P1-3).

Order: TestFlight build → founder runs §6 while `duo5` and `store2` run on CI → if all three are green, submit.

## 6. The real-Duo test (for the founder)

Install the TestFlight build on the Duo. Turn the sound on and the silent switch off. For each check, note pass or fail,
and if it fails, what you saw.

1. **First launch.** Hold the Duo open like a book. Within a couple of seconds, the lesson should notice and move on to
   "When it's sipping… snap shut!" If you hold it upright like a phone or lay it flat on a table, you should see a
   clean card with a picture of a Duo held like a book, with nothing overlapping.
2. **The first bite.** When the fly is sipping, close the Duo a little: a quick flick, about the width of two fingers
   at the top, not all the way. It should CHOMP on the first try, with a strong buzz in your hands. If you have to
   close it far, or it bites before you meant it to, that's a fail.
3. **Open again.** Open it back to where you were. The trap should be ready at once, and the lesson should move on. You
   shouldn't need to open it wider than you started.
4. **The slow close.** Close the Duo very slowly, over about 3 seconds. It should *not* bite. The bugs should get
   nervous and fly off, and you should see "Snap it — quick!"
5. **Big hard snaps.** In a Feed run, do 10 fast, hard snaps, including a few where you close it to about a right
   angle. The game should never pause. Every snap should bite once, never twice.
6. **Shut it and reopen.** Close the Duo fully mid-run. The outside screen should show "Open it up to carry on" with
   your score. Open it: the game should carry on where you left off. Note whether one half of the screen blurs for a
   moment, and whether that hid anything you needed (the score and snaps are on the right half).
7. **Too flat.** Open the Duo completely flat and start a Feed run. You should see "Bend it a little, like a book".
   Bend it a little, and play should work normally.
8. **The CHOMP.** In a Feed run, wait for 3 or more bugs and bite. You should hear a wet crunch and feel a strong
   double buzz, and "+1 snap" should pop. Then bite on nothing: you should hear a hollow "clop" and see "Missed!", with
   no crunch. Both should feel satisfying and clearly different.
9. **Bees cost.** Deliberately bite a bee (and a wasp, if you see one). You should hear "Bzzt!", feel a cross buzz (the
   wasp heavier), and see a red "−1 snap" or "−2 snaps" by your snaps row. The count should drop by exactly that.
   When the run ends, the counter should show **0** before "Your trap is tired" appears.
10. **A whole run, and the Daily.** Play one full Feed run and one Daily Bog. Check that:
    - nothing looks broken or cut off on either half or across the fold;
    - the hinge never stops responding;
    - your hands don't ache;
    - Results says "score", not "protein";
    - the Daily's **Share** button opens the share sheet with one line like "Snapjaw Daily Bog #… · score · biggest
      bite …".

    Note roughly how long the run lasted.

If any of 2, 3, 4, 5 or 6 fails, stop and send a screen recording. Those are the hinge numbers, and they are the only
thing the simulator can't prove.
