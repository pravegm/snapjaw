# Snapjaw launch runbook (for the founder)

*Written Tue 27 Oct 2026 by the launch lead, mirroring Swoop's and Hush's runbooks. This is the only document you need to follow. It lists **only the steps that need your own GitHub or Apple login, or your Duo**; Claude does everything else, including putting the whole store listing into App Store Connect with the App Store Connect tool. Each step says exactly where to click and what to type. Everything Apple sees lives in `docs/appstore/`. Whenever a step says "tell Claude", a one-line message in chat is enough.*

**Launch: Tuesday 8 December 2026, about 08:00 UK time, released by you (manual release).** Brim launches Tue 17 Nov and Hush Tue 1 Dec, so Snapjaw takes the next free week and no two games share one.

A few words used below:
- **Repo** (repository): Snapjaw's project page on GitHub, `github.com/pravegm/snapjaw`. It holds the code and these documents.
- **Actions**: GitHub's build robot. It turns the code into an app on Apple's newest Xcode, because your Mac can't.
- **Workflow**: one of the robot's jobs (for example "TestFlight"). You start one from the **Actions** tab with the grey **Run workflow** button.
- **Secret**: a password-like value stored in the repo's settings, which only the build robot can read.
- **TestFlight**: Apple's app for installing test builds on your own phone before launch.

---

## Timeline

| When | What you do | Section |
|---|---|---|
| **Today, Tue 27 Oct** | **Make the repo public** (1 minute: nothing compiles until you do), then turn on the website (5 minutes) | §0 |
| Tue 27 – Fri 30 Oct | The trademark check, then register Snapjaw with Apple and create the app record (30 minutes) | §1 |
| Tue 27 – Fri 30 Oct | Add the 4 GitHub secrets (10 minutes) | §2 |
| When Claude says "first green build" (about Thu 29 Oct – Mon 2 Nov) | Turn on Game Center, then run the App Store Connect tool twice (plan, then push). This also sends the featuring nomination | §3 |
| When Claude says the game is ready to try (early November) | Run the TestFlight build (2 clicks) and install it | §4 |
| The same day or weekend | The 15-step Duo test (about 15 minutes), then send Claude your notes | §5 |
| Until about Fri 27 Nov | Claude tunes from your notes; you repeat §4–§5 on each new build | §5 |
| **Tue 17 Nov** | **Brim's launch day.** No Snapjaw work today | — |
| **Sat 28 – Sun 29 Nov** | The four clicks only you can do, and a check of what the robot filled in (one evening) | §6a–b |
| Mon 30 Nov | Claude: code freeze, the final build and the screenshots | — |
| **Tue 1 Dec** | **Hush's launch day.** No Snapjaw work today | — |
| **Wed 2 Dec** | The last robot run, pick the final build, **submit for review** with manual release (last safe day: Fri 4 Dec) | §6c–e |
| ~Thu 3 – Fri 4 Dec | Apple approves (usually 24–48 hours). Snapjaw then waits for you | §6e |
| Sat 5 – Mon 7 Dec | Promo codes for creators | §7 |
| **Tue 8 Dec, ~08:00 UK** | Press **Release This Version**. Launch-day steps | §7 |

**If Snapjaw isn't submitted by Fri 4 Dec:** move the launch to **Tue 12 Jan 2027** (never 15 Dec, which is Hush's fallback, and not Christmas). Tell Claude: the nomination's date changes too.

---

## §0. Make the repo public, then turn on the website (today)

### 0a. Make the repo public (1 minute; this unblocks everything)

The repo was created **private**, and on this account GitHub refuses to run the build robot on private repos because of a billing hold (the test run said "recent account payments have failed"). Your other games' repos are public for the same reason. Claude checked: there's nothing personal in the repo (no emails, phone numbers or keys).

1. Go to **github.com/pravegm/snapjaw** and sign in.
2. Click **Settings** (the gear tab along the top of the repo, on the right).
3. Stay on **General** (the top of the left list). Scroll all the way down to the red **Danger Zone** box.
4. Next to **Change repository visibility**, click **Change visibility** → **Change to public**.
5. GitHub shows a few warnings: click **I want to make this repository public**, then **I have read and understand these effects**, then **Make this repository public**. If it asks you to confirm who you are (your password, passkey or a code), do that.
6. *Check:* the repo page now shows a **Public** label next to the name.

**Tell Claude "snapjaw is public".** Claude then starts the first build.

### 0b. Turn on the website (support and privacy pages)

Apple needs a working support page and privacy page before it accepts the app. They're already written; this puts them online for free.

1. github.com/pravegm/snapjaw → **Settings** → **Pages** (left list, under "Code and automation").
2. Under **Build and deployment**, **Source**: choose **Deploy from a branch**.
3. **Branch**: choose **main**, then in the folder box next to it choose **/docs**. Click **Save**.
4. Wait 1–2 minutes, then open these on your phone. All three must load:
   - Home: **https://pravegm.github.io/snapjaw/**
   - Support: **https://pravegm.github.io/snapjaw/support.html**
   - Privacy: **https://pravegm.github.io/snapjaw/privacy.html**

   (Each one forwards to the real page under `/site/`, which is fine.)

*If you see "404"*, wait 5 more minutes and reload. If it's still missing, tell Claude.

### 0c. Check Issues are on

Support is through **GitHub issues** (`github.com/pravegm/snapjaw/issues`), the same as Squish, Brim, Swoop and Hush, so there's no email address to set up. **Settings → General → Features → Issues** must be ticked.

**Tell Claude "the site is up".**

---

## §1. Trademark check first, then the app record (about 30 minutes, once)

### 1a. Trademark check for the name "Snapjaw" (10 minutes, before anything else)

The research found no game called Snapjaw, but nobody has checked trademarks. It's a quick search, not legal advice.

1. **UK:** go to **https://trademarks.ipo.gov.uk/ipo-tmtext** (UK IPO, "Search for a trade mark"). Search for the word `SNAPJAW` (and `SNAP JAW`). Under "Classes", tick **9** (software and downloadable games), **28** (games and toys) and **41** (entertainment and online games). Search.
2. **US:** go to **https://tmsearch.uspto.gov** (USPTO Trademark Search). Search `SNAPJAW`. Use the filters to show **Live** marks only, and look at classes **009**, **028** and **041**.
3. For each result, look at three things: is it **live / registered**? Is it for **games or game software**? Who owns it?
4. Tell Claude what you found, in one line per live match (for example "US: SNAPJAW, class 28, toy, owned by X, registered"), or "nothing live".

What happens next:
- **Nothing live for games in 9, 28 or 41:** carry on with "Snapjaw".
- **A live SNAPJAW mark for games:** stop before 1c. Claude switches to the research's runner-up, **"Snaptrap: Feed the Flytrap"** (home-screen name "Snaptrap"), and updates every page.

### 1b. Register the bundle ID (Snapjaw's unique name inside Apple)

Go to **developer.apple.com** → **Account** → **Certificates, IDs & Profiles** → **Identifiers** → the blue **+**.
1. Choose **App IDs** → Continue → **App** → Continue.
2. Description: `Snapjaw`
3. Bundle ID: choose **Explicit** and type `com.pravegm.snapjaw`
4. In the **Capabilities** list, tick **Game Center** (nothing else).
5. **Continue** → **Register**.

### 1c. Create the app record

Go to **appstoreconnect.apple.com** → **Apps** → the blue **+** → **New App**.

| Field | Type or pick |
|---|---|
| Platforms | **iOS** |
| Name | `Snapjaw` (if it says the name is taken, try `Snapjaw: Venus Flytrap`, then `Snapjaw: Flytrap`, and tell Claude which one worked) |
| Primary Language | **English (U.K.)** |
| Bundle ID | pick `com.pravegm.snapjaw` from the list (if it's missing, wait 5 minutes and reload) |
| SKU | `snapjaw-2026` |
| User Access | **Full Access** |

Click **Create**.

### 1d. Tell Claude the Apple ID

In the new app, open **App Information** (left list) and copy the **Apple ID** number (10 digits). Send it to Claude: it becomes the App Store link `https://apps.apple.com/app/id<that number>` in the press kit, the website and the posts.

---

## §2. Connect GitHub to Apple: the 4 secrets (10 minutes, once)

GitHub builds Snapjaw for you on Apple's newest Xcode, and fills in the App Store listing for you. It needs four secrets: **the same four names and values you put into `pravegm/swoop`** (and Squish, Brim and Hush). One Apple key works for all your apps.

You don't need to make any certificate or profile. The build uses **Apple's cloud-managed distribution certificate** through the API key, as Swoop's does.

**2a. Gather the four values.** GitHub never shows a saved secret again, so you can't copy them out of Swoop's settings. Get them from the source:

| Secret name | Where to find the value |
|---|---|
| `ASC_KEY_ID` | App Store Connect → **Users and Access** → **Integrations** → App Store Connect API → **Team Keys**: the "Key ID" column of the key you used for Swoop |
| `ASC_ISSUER_ID` | Same page, the **Issuer ID** shown above the table |
| `ASC_PRIVATE_KEY` | The `.p8` file you downloaded when you made that key. Open it in TextEdit (or Notepad) and copy **all** of it, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `APPLE_TEAM_ID` | developer.apple.com → Account → **Membership details** → Team ID (10 characters) |

*Can't find the `.p8` file?* Apple only lets you download it once. Make a new key on the same Team Keys page: **+**, name `Studio CI`, Access **Admin**, **Generate**, **Download** the file straight away, and use the new Key ID. Don't revoke the old key: the other games keep using it.

**2b. Add them to Snapjaw's repo.** github.com/pravegm/snapjaw → **Settings** → **Secrets and variables** (left list) → **Actions** → **New repository secret**. For each of the four: type the name exactly as above (capitals and underscores), paste the value, click **Add secret**. When you're done the list shows four names.

**Tell Claude "secrets in".**

---

## §3. Game Center on, then the App Store Connect tool (when Claude says "first green build")

The App Store Connect tool is already in this repo (`tools/appstore/`, run by the **App Store Connect tool** workflow). Claude tells you when to run it: once the first build is green and the app draws the 12 achievement pictures, because the tool uploads them with the achievements.

*If it stops with a red cross at **Check the secrets exist** ("App Store Connect is not set up") or at **check** ("No App Store Connect app record"):* it is telling you a one-time step is missing. The run's summary page says which: the app record for bundle ID `com.pravegm.snapjaw` (§1b–§1c) or the 4 secrets (§2). Do that step, then run it again. Nothing was changed.

**3a. Turn on Game Center.** appstoreconnect.apple.com → Apps → Snapjaw → **Services** (in some layouts **Features**) → **Game Center** → turn it on.

**3b. Dry run.** github.com/pravegm/snapjaw → **Actions** → **App Store Connect tool** (left list) → **Run workflow** → tick **Contact App Store Connect** → mode **plan** → leave the other boxes as they are → **Run workflow**. It changes nothing. When it shows a green tick (about 10 minutes), **tell Claude "plan done"**. Claude reads what it would change and tells you whether to go ahead.

**3c. The real run.** Same steps with mode **push** → **Run workflow**. Green tick = done. A red cross: send Claude the link; running it again is safe (it only changes what's different).

This one run fills in: the name, subtitle, description, keywords, promotional text and web addresses (English (U.K.) and (U.S.)); the categories; the age rating answers (**4+**); the price (**£1.99**, base country United Kingdom) and the countries (everywhere except China mainland and Vietnam); **manual release**; the App Review notes and your contact details (copied from Squish's record, never written into the public repo); **Game Center: the 2 leaderboards and 12 achievements with their pictures** (so TestFlight can show them); and the **featuring nomination**, which it submits for the 8 Dec launch. The screenshots come later (§6c).

*Check the nomination:* App Store Connect → the app → **Featuring** → **Nominations**: one nomination, status **Submitted**. It must be in by **Mon 16 Nov** (Apple wants 3 weeks' notice). If the robot couldn't do it, make it by hand: **Create Nomination**, copy every field from `docs/appstore/featuring-nomination.md`, press **Submit** (a saved draft doesn't count).

---

## §4. Run TestFlight (when Claude says the game is ready to try)

**4a. Run a build.** github.com/pravegm/snapjaw → **Actions** (tab along the top) → **TestFlight** (left list) → **Run workflow** (grey button on the right) → keep branch `main` → in "What to test" type anything (e.g. `first Duo test`) → leave "Only build…" unticked → **Run workflow**.
- About 20–30 minutes later the run shows a green tick. A red cross with "Missing repository secrets" means a name in §2b is misspelt; anything else, send Claude the link to the run.
- 10–30 minutes after the green tick, the build appears in App Store Connect → the app → **TestFlight**, first as "Processing". You won't be asked about encryption: that answer is already built in.
- **Always use Run workflow, never "Re-run" on an old run**: a re-run reuses the old build number, and Apple rejects the upload as a duplicate.

**4b. Install it (set up once).** App Store Connect → the app → **TestFlight** → **Internal Testing** → **+** → group name `Studio` → add yourself (your Apple Account email) → add the build. On the Duo, open Apple's **TestFlight** app (you have it from the other games) and tap **Install** next to Snapjaw. Later builds appear there automatically.

---

## §5. The Duo test: 15 steps, about 15 minutes

**Why:** the snap is the whole product, and only your Duo can tell us whether it fires when your hands expect it to, whether the CHOMP feels good, and whether anything ever fires by itself. Do this on the first TestFlight build and again on each new one.

**Before you start:** ringer **on**, volume about half, sitting comfortably. Open the Duo and turn it sideways so the fold runs **top to bottom**, like a book, one hand on each half. If an older Snapjaw is on the Duo, delete it first so the lesson runs. **Screen recording** for steps 4, 8 and 11: swipe down from the top-right corner to open Control Centre and tap the round record button, **with the microphone on** (press and hold the button to turn it on). Tap the red time at the top to stop; the video goes to Photos. If something goes wrong, carry on with the next step and write it down.

| Step | Do this | What should happen (note anything different) |
|---|---|---|
| 1 | Open Snapjaw held like a book. On the title screen, close the halves a little and open them again, slowly, then once briskly | The title trap's teeth lean in **with your hands**, and the brisk one **chomps** |
| 2 | First Bite starts. Hold it like a book until the lesson moves on | It passes the pose step by itself within a second or two |
| 3 | A fat fly lands and sips. Snap: close the halves a little, briskly, then open again | **CHOMP.** How far did you close before it bit: **tiny / about right / too far**? Did it bite **when you expected**, or late? |
| 4 | **Start recording.** Carry on through the lesson: "Open up", "Quick snaps catch more", the bee (wait for it to leave), the triple | Each step makes sense. On the slow-close step, the flies leave and the hint says "Snap it — quick!" |
| 5 | Feed (from Home). Play one whole run, catching what you can. **Time it** from the first bug to "Your trap is tired" | Note the time, the score (protein), and roughly how many snaps you made |
| 6 | Second run: this time **wait for crowds** of 3 or more and spare every bee | Did a Feast feel great? Did waiting feel tense in a good way? Did a bee ever sneak into a bite you didn't mean? |
| 7 | **Ghost check.** Mid-run, hold the Duo still for 10 seconds, then shift your grip and re-settle your hands without meaning to snap | **Nothing should bite by itself.** Count any bites you didn't mean |
| 8 | **Start recording.** Try snapping from three rests: nearly flat, a normal book, and quite folded (an L shape and a bit more open) | The snap should feel the **same size** from each. Did one of them feel harder, or bite too easily? |
| 9 | **Blur test.** Open the Duo completely flat, start a run, and make your first snap from flat. Then do it again from a relaxed book | Did one half of the screen blur? Which half (left or right), for about how long? Were the score and snaps on the **sharp** half? Did you see "Bend it a little, like a book"? |
| 10 | Mid-run, close the Duo much further (well past an L shape) and hold it 2 seconds; open it again. Then close it fully, look at the outer screen, and reopen | The run **pauses** with a card asking you to open it, and carries on when you do. What does the outer screen show? Did closing ever cost you snaps or bite something? |
| 11 | **Start recording.** Turn the Duo upright (portrait), like a normal phone | A card shows how to hold it like a book |
| 12 | Play the **Daily Bog** once, then open the **Bug Book** | One counted try, then "practice". New pages show the bugs you caught, with their jokes |
| 13 | Flip the **silent switch on**, play a few seconds, then open **Settings** and try Sound, Haptics, **Respect silent switch**, **HUD on the left** and **Reduce motion** | Sound on silent? Do the switches work? Does the HUD move to the left half? |
| 14 | During any run, close your eyes for a few seconds and listen | Can you hear **where** a bug is (left or right)? Do you feel a tick when one lands? |
| 15 | Play **5 runs in a row** | Then note: is the Duo **warm**? Hands or wrists tired? Did you want "one more go"? |

**Send Claude this (copy, fill in, paste in chat), plus the recordings and any screenshots:**
```
Snapjaw build [number from TestFlight], iPhone Duo, iOS [version]
1  Title trap followed my hands: [yes/no]   Brisk close chomped: [yes/no]
2  Pose step passed by itself: [yes/no]
3  Closed before it bit: [tiny / about right / too far]   Bit when I expected: [yes / late / early]
4  Lesson made sense: [yes/no, where not]   Slow close made the flies leave: [yes/no]
5  Run 1: time [ ] min, score [ ], snaps about [ ]
6  Feast feels great 1-5 [ ]   Waiting feels tense (good) 1-5 [ ]   Bee snuck into a bite: [never / once / often]
7  Bites I didn't mean while holding still or shifting grip: [ ]
8  Snap felt the same from flat / book / folded: [yes / no: which felt different]
9  Half that blurred: [left/right/none]  for about [ ] s   HUD on the sharp half: [yes/no]
10 Deep close paused and resumed: [yes/no]   Outer screen showed: [ ]   Closing cost me: [nothing / snaps / a bite]
11 Portrait card: [yes/no]
12 Daily one try then practice: [yes/no]   Bug Book pages filled: [yes/no]
13 Sound on silent: [yes/no]   Switches work: [yes/no]   HUD moved left: [yes/no]
14 Could hear where bugs were: [yes/no]   Felt landing ticks: [yes/no]
15 Warm after 5 runs: [no / a little / hot]   Want one more go 1-5 [ ]
Scores 1-5: CHOMP sound [ ] / CHOMP haptic [ ] (too weak / right / too strong) / snap feels physical [ ] / comfort [ ]
Comfort (hand or wrist tired? ever had to close further or faster than felt natural?):
Best moment:
Worst moment:
Bugs (what you did, what happened):
Anything confusing:
```
In TestFlight you can also take a screenshot in Snapjaw and tap **Share Beta Feedback**. A phone video of your hands and the Duo from the side while you play helps a lot too.

The release build is the one where every "should" above happens, step 7 shows **no** bites you didn't mean, step 10 never costs anything, and comfort is fine.

---

## §6. Fill in the rest and submit (Sat 28 Nov – Wed 2 Dec)

### 6a. The four clicks only you can do (Sat 28 or Sun 29 Nov; no robot can)

In App Store Connect → the app:
1. **App Privacy** (left list): **Privacy Policy URL** `https://pravegm.github.io/snapjaw/privacy.html` → Save (the tool usually fills it). Then **Get Started** → "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app** → **Save** → **Publish**. The page now says **Data Not Collected**. (Why it's true: `docs/appstore/privacy.md`.)
2. **Family Sharing:** **App Information** (in some layouts Pricing and Availability) → Family Sharing → **Turn On** → confirm (it can't be turned off later, which is fine).
3. **Mac and Vision Pro:** **Pricing and Availability** → "iPhone and iPad Apps on Apple Silicon Macs": untick **Make this app available**; then "Apple Vision Pro": untick it too. **Save**.
4. **EU Digital Services Act:** **App Information** → **App Store Regulations and Permits** → **Digital Services Act** → if it asks, give the same trader answer as for your other games → **Save**.

### 6b. Check what the robot did (5 minutes)

- **Pricing and Availability:** **£1.99** with base country **United Kingdom**; the US shows **$1.99**. Every country **except China mainland and Vietnam**. Pre-order: off.
- **App Information → Age Rating:** the result says **4+**. If it says anything else, tell Claude before submitting.
- **The 1.0 page → App Review Information:** "Sign-in required" unticked, your contact details filled in, and **Notes** starts "Thanks for reviewing Snapjaw".
- **The 1.0 page → Version Release:** **Manually release this version** is chosen.
- **Services → Game Center:** 2 leaderboards (Best Feast, Daily Bog) and 12 achievements, each with a picture (for example **First Feast** and **Bee Kind**).

### 6c. The last robot run (Wed 2 Dec, after Claude names the release build)

Claude makes the final screenshots on Mon 30 Nov (the **App Store screenshots** workflow), puts that run's number into the tool for you, and tells you the release build number. Then: **Actions** → **App Store Connect tool** → **Run workflow** → tick **Contact App Store Connect** → mode **push** → in **"Release build number"** type the number Claude gave you → if Claude also gave you a "header and search art" run number, type it in the box that starts **"ID of a store.yml run with a store-placements artifact"** → **Run workflow**. This uploads the screenshots (6.9", 6.3" and iPhone Duo, 10 each, the first one the Duo open like a book) and puts the build on the 1.0 page with Game Center attached. It refuses any set with a flagged or missing frame, so a green tick means every frame passed its checks. Green tick = done.

### 6d. Check the build and screenshots (Wed 2 Dec)

On the 1.0 page: **Build** shows the number Claude named (if it's empty: **+** → pick it → **Done** → **Save**). **Previews and Screenshots**: 10 in each size, the first one showing the Duo open like a book. In the **Game Center** section, both leaderboards and all twelve achievements are listed.

### 6e. Submit (Wed 2 Dec; last safe day Fri 4 Dec)

1. Click **Add for Review** (top right). If App Store Connect lists anything missing, send Claude a screenshot.
2. Click **Submit to App Review**.
3. Apple usually answers within 24–48 hours, by email.
   - **Approved:** the status becomes **Pending Developer Release**. Do nothing until launch morning (§7).
   - **Rejected:** don't worry, it's common for a first version. Copy Apple's whole message (App Store Connect → the app → **App Review**, or the email) and send it to Claude the same day. Claude writes the reply (ready-made answers are in `docs/appstore/review-notes.md`, "If rejected under…") and tells you exactly what to paste and where.

---

## §7. Launch: Sat 5 – Tue 8 Dec

**Sat 5 – Mon 7 Dec:** App Store Connect → the app → **Promo Codes** → generate codes for the creators in `docs/appstore/social-launch.md` §4, and email them (`press-kit.md` email #5): they post from Tue 8 Dec. Keep a list of who got which. No public posts yet: it's Hush's week.

**Tue 8 Dec, about 08:00 UK:**
1. App Store Connect → the app → the 1.0 page → **Release This Version** → confirm. It can take a few hours to appear in every country.
2. Open Snapjaw's App Store page on your phone and check: price £1.99, **4+**, "Data Not Collected", the screenshots, Game Center.
3. **Accessibility labels:** App Store Connect → the app → **App Accessibility** → **Get Started** → **iPhone**. Tick only the labels `docs/appstore/accessibility.md` marks as passed (planned: **Differentiate Without Color Alone**, **Sufficient Contrast**, **Reduced Motion**; Claude confirms which). **Never tick Larger Text or VoiceOver.** Leave the rest unticked → **Publish**.
4. Post the launch posts from `social-launch.md` §2 once the page shows **Get** with the price, and send the Day 0 emails from `press-kit.md` (`social-launch.md` §4 says which).
5. Tell Claude **"Snapjaw is live"**: Claude swaps "Coming soon to the App Store" on the website for the real link.
6. Play the first Daily Bog yourself and check your score appears on the Daily Bog leaderboard.
7. For the next few days: App Store Connect → the app → **Ratings and Reviews**, and TestFlight's crash reports. Forward anything odd to Claude for 1.0.1.

---

## Reference: what the tool sets (no action needed)

Claude runs the App Store Connect tool (GitHub → Actions → **App Store Connect tool**; `tools/appstore/README.md`). It reads `docs/appstore/asc-metadata.json`, which is built from the docs, and changes only what differs. It never submits for review and never releases. The screenshots and the optional header and search art come from the **App Store screenshots** workflow (`store.yml`, `ci/README.md`).

| What | Value | Source |
|---|---|---|
| Name, subtitle, privacy URL (en-GB and en-US) | `Snapjaw`, `Feed the flytrap. Spare bees.` | `metadata.md` §1–2 |
| Categories | Games: Casual + Arcade (Action if Apple's list has no Arcade); secondary Entertainment | `metadata.md` §7 |
| Age rating | Every answer None / No: 4+ | `metadata.md` §8 |
| Version 1.0 | Copyright `© 2026 pravegm`; release **Manually release this version** | `metadata.md` §9 |
| Description, keywords, promotional text, support and marketing URLs (en-GB and en-US) | | `metadata.md` §3–5, §9 |
| App Review notes, "no sign-in", the contact (copied from Squish's record, never in the repo) | | `review-notes.md` |
| Game Center | On; the 2 leaderboards and 12 achievements below, each achievement with its badge | `achievements.md` |
| Screenshots | 6.9", 6.3" and iPhone Duo sets (10 each) | `screenshots.md` |
| Price and availability | £1.99 (UK base; Apple sets $1.99 and the rest); every country except China mainland and Vietnam | `metadata.md` §9 |
| Featuring nomination | App Launch, publish date Tue 8 Dec 2026, **submitted** (by Mon 16 Nov) | `featuring-nomination.md` |

### Game Center items (created by the tool)

IDs can never be changed once created. These are the exact values (the same as `docs/appstore/achievements.md`).

**Leaderboards:**

| Leaderboard ID | Type | Reference name | Display name | Score format | Suffix | Sort | Submission |
|---|---|---|---|---|---|---|---|
| `snap.best` | **Classic** | Best feast | Best Feast | Integer | ` protein` (singular and plural) | High to Low | Best score |
| `snap.daily` | **Recurring**: start **Mon 2 Nov 2026 at 00:00 UTC**, lasts **1 day**, repeats every **1 day** | Daily Bog | Daily Bog | Integer | ` protein` | High to Low | Best score |

**Achievements** (none hidden, none can be earned more than once, each with its 1024 × 1024 badge drawn by the app):

| Achievement ID | Title | Description before earning | Description after earning | Points |
|---|---|---|---|---|
| `snap.ach.feast` | First Feast | Catch 3 bugs or more in one bite. | Three in one gulp. A proper Feast. | 10 |
| `snap.ach.bite5` | Mouthful | Catch 5 bugs or more in one bite. | Five bugs, one bite, no regrets. | 25 |
| `snap.ach.chain4` | Four Times Hungry | Score a bite at x4: seven clean bites in a row. | The chain hit x4. Bite after bite after bite. | 50 |
| `snap.ach.scarab` | Pure Gold | Catch a Golden Scarab. | The rarest bug in the bog. Shiny. | 50 |
| `snap.ach.dragonfly` | Here Be Dragonflies | Catch a dragonfly. | It hovered. You timed it. | 25 |
| `snap.ach.spare50` | Bee Kind | Spare 50 bees, bumblebees or wasps. | Fifty stripy visitors, all sent home. | 50 |
| `snap.ach.bugbook` | Every Bug in the Book | Fill all 16 pages of the Bug Book. | Sixteen species. A true naturalist. | 100 |
| `snap.ach.monarch` | Bog Monarch | Reach the top plant rank: Bog Monarch. | All hail the hungriest plant in the bog. | 100 |
| `snap.ach.night` | Midnight Snack | Keep your trap going until night falls. | Fed from breakfast to midnight. | 25 |
| `snap.ach.daily` | Daily Diner | Finish a scored Daily Bog. | Same bog as everyone else today. | 15 |
| `snap.ach.score10k` | Well Fed | Score 10,000 protein in one run. | Ten thousand protein. Delicious. | 75 |
| `snap.ach.nobees` | Bee-Free Diet | Catch 30 bugs in one run without biting a bee or wasp. | Thirty bugs, and not one bee in the mix. | 50 |
| | | | **Total** | **575** (of 1,000 allowed) |

English (U.S.) is identical.

### If you ever have to do it by hand

If the robot can't do something (it says so in its output, and Claude will tell you): paste the code blocks from `docs/appstore/metadata.md` §1–5 into App Information and the 1.0 page (English (U.K.), then switch the language menu to English (U.S.) and paste the U.S. description); answer the age rating exactly as the table in §8; set the price and availability as in §6b; paste `review-notes.md`'s block into Notes; add the Game Center items from the tables above (type the IDs exactly: they can never be changed once saved).
