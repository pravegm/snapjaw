// Builds C:\Users\59527\Trap\docs\appstore\asc-metadata.json from the Snapjaw docs, in Swoop's schema
// (a port of C:\Users\59527\Wing\tools\appstore\build-metadata.js), and prints every count.
const fs = require('fs'), path = require('path');
const root = 'C:/Users/59527/Trap';
const rd = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const problems = [];
function blockAfter(text, marker) {
  const i = text.indexOf(marker); if (i < 0) throw new Error('marker ' + marker);
  const s = text.indexOf('```\n', i) + 4;
  const e = text.indexOf('\n```', s);
  return text.slice(s, e);
}
function need(text, what, file) { if (!text.includes(what)) problems.push(`${file} no longer says ${JSON.stringify(what)}`); }

const md = rd('docs/appstore/metadata.md');
const name = blockAfter(md, '## 1. App name');
const subtitle = blockAfter(md, '## 2. Subtitle');
const promo = blockAfter(md, '## 3. Promotional text');
const descGB = blockAfter(md, '### en-GB (English U.K.)');
const descUS = blockAfter(md, '### en-US (English U.S.)');
const keywords = blockAfter(md, '## 5. Keywords');
const whatsNew = blockAfter(md, '## 6. What\'s New');

const catRows = Object.fromEntries([...md.matchAll(/^\| (Primary|Game subcategory 1|Game subcategory 2|Secondary category) \| [^|]+\| `([A-Z_]+)` \|$/gm)].map(m => [m[1], m[2]]));
const categories = {
  _comment: 'metadata.md §7. Apple dropped GAMES_ARCADE from its live list on 26 Oct 2026 (Brim run 40340641267; Swoop was filed as Casual + Action on 27 Oct). The categories step reads the live list first; a wanted subcategory that is not on it is replaced by the first live entry of fallbackSubcategories, or dropped (Casual alone). check/plan print what would be pushed.',
  primary: catRows['Primary'],
  primarySubcategories: [catRows['Game subcategory 1'], catRows['Game subcategory 2']].filter(Boolean),
  fallbackSubcategories: ['GAMES_ACTION'],
  secondary: catRows['Secondary category'] || null
};
if (categories.primary !== 'GAMES' || categories.primarySubcategories.length !== 2) problems.push('category table not parsed ' + JSON.stringify(catRows));

const site = 'https://pravegm.github.io/snapjaw/';
for (const u of [site, site + 'support.html', site + 'privacy.html']) need(md, '`' + u + '`', 'metadata.md §9');
need(md, '**United Kingdom, £1.99**', 'metadata.md §9');
need(md, '**except China mainland and Vietnam**', 'metadata.md §9');
need(md, '**Manually release this version**', 'metadata.md §9');
const copyrightLine = (md.match(/^\| Copyright \| `([^`]+)` \|$/m) || [])[1];
if (!copyrightLine) problems.push('Copyright row not found');
const RELEASE = { type: 'MANUAL', earliestReleaseDate: null };
const LAUNCH = '2026-12-08T08:00:00Z';

const rn = rd('docs/appstore/review-notes.md');
const notes = blockAfter(rn, '<!-- REVIEW-NOTES:BEGIN -->');
const fn = rd('docs/appstore/featuring-nomination.md');
const nomDesc = blockAfter(fn, '### Description');
const nomNotes = blockAfter(fn, '### Helpful Details');
const nomName = (fn.match(/\| Nomination Name \| `([^`]+)`/) || [])[1];
need(fn, 'Specific day: 2026-12-08', 'featuring-nomination.md');

const ach = rd('docs/appstore/achievements.md');
const rows = ach.split('\n').filter(l => /^\| \d+ \| `snap\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
function split2(c) { const p = c.split(' / '); return [p[0], p[1] || p[0]]; }
const achievements = rows.map(r => {
  const id = r[1].replace(/`/g, '');
  const [tGB, tUS] = split2(r[2]), [bGB, bUS] = split2(r[3]), [aGB, aUS] = split2(r[4]);
  const hidden = /yes/i.test(r[6]);
  const loc = (n, b, a) => ({ name: n, beforeEarnedDescription: b, afterEarnedDescription: a });
  return { vendorIdentifier: id, referenceName: tGB, points: parseInt(r[5], 10), showBeforeEarned: !hidden, repeatable: false,
    localizations: { 'en-GB': loc(tGB, bGB, aGB), 'en-US': loc(tUS, bUS, aUS) }, image: `tools/appstore/badges/${id}.png` };
});
for (const s of ['`snap.best`', '`snap.daily`', '`Best score`', '`Daily Bog`', '`Best Score`', '` point` / ` points`',
                 '0 – 10,000,000', 'Start **Mon 2 Nov 2026, 00:00 UTC**; duration **1 day**; repeats every **1 day**']) need(ach, s, 'achievements.md');
// R5/R6: the word is "score" (suffix "points"), never "protein" (achievements.md, Format suffix row).
const lbLoc = (n) => ({ name: n, formatterSuffix: ' points', formatterSuffixSingular: ' point' });
const leaderboards = [
  { vendorIdentifier: 'snap.best', referenceName: 'Best score', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 10000000, recurrence: null, localizations: { 'en-GB': lbLoc('Best Score'), 'en-US': lbLoc('Best Score') } },
  { vendorIdentifier: 'snap.daily', referenceName: 'Daily Bog', defaultFormatter: 'INTEGER', scoreSortType: 'DESC', submissionType: 'BEST_SCORE',
    scoreRangeStart: 0, scoreRangeEnd: 10000000,
    recurrence: { startDate: '2026-11-02T00:00:00Z', duration: 'PT24H', rule: 'FREQ=DAILY;INTERVAL=1' },
    localizations: { 'en-GB': lbLoc('Daily Bog'), 'en-US': lbLoc('Daily Bog') } }
];

// runbook cross-check
let rb = ''; try { rb = rd('docs/LAUNCH-RUNBOOK.md'); } catch (e) { problems.push('runbook missing'); }
const rbRows = rb.split('\n').filter(l => /^\| `snap\.ach\./.test(l)).map(l => l.split('|').slice(1, -1).map(c => c.trim()));
for (const r of rbRows) {
  const id = r[0].replace(/`/g, ''), a = achievements.find(x => x.vendorIdentifier === id);
  if (!a) { problems.push(`runbook lists ${id}, achievements.md does not`); continue; }
  const g = a.localizations['en-GB'];
  const cmp = [['title', r[1], g.name], ['before', r[2], g.beforeEarnedDescription], ['after', r[3], g.afterEarnedDescription], ['points', r[4], String(a.points)]];
  for (const [k, x, y] of cmp) if (x !== y) problems.push(`runbook ${id} ${k}: ${JSON.stringify(x)} vs ${JSON.stringify(y)}`);
}
if (rbRows.length !== achievements.length) problems.push(`runbook has ${rbRows.length} achievements, achievements.md ${achievements.length}`);

// R6 storyboard (ci/store-scenarios.txt, ci/duo-store-scenarios.txt: the source of truth for names and captions).
const FRAMES = ['01-book-hero', '02-feast', '03-bee', '04-garden', '05-night', '06-goals', '07-bug-book', '08-zen', '09-results', '10-first-bite'];
for (const [file, prefix] of [['ci/store-scenarios.txt', 'P'], ['ci/duo-store-scenarios.txt', 'D']]) {
  let names = []; try { names = rd(file).split('\n').filter(l => new RegExp('^' + prefix + '\\d\\d-').test(l)).map(l => l.split('|')[0]); } catch (e) { problems.push(file + ' missing'); }
  const want = FRAMES.map(n => prefix + n);
  if (names.join() !== want.join()) problems.push(`${file} frames ${JSON.stringify(names)} != ${JSON.stringify(want)}`);
}
// R7 (SCORE-R6 #9): store truth and consistency, checked on the scenario files against screenshots.md.
{
  const ssDoc = rd('docs/appstore/screenshots.md');
  for (const [file, prefix] of [['ci/store-scenarios.txt', 'P'], ['ci/duo-store-scenarios.txt', 'D']]) {
    let lines = []; try { lines = rd(file).split(/\r?\n/).filter(l => new RegExp('^' + prefix + '\\d\\d-').test(l)); } catch (e) { continue; }
    const states = new Set();
    for (const l of lines) {
      const f = l.split('|'), name = f[0], args = f[1] || '', caption = f[3] || '', num = name.slice(1, 3);
      // One progress state on every frame that shows progress (SCORE-R6: P04's 6 of 8 against P06's Garden 2/8).
      const m = args.match(/(?:^|;)progress=([a-z]+)/);
      if (m) states.add(m[1]);
      else if (['04', '06', '07', '09'].includes(num)) problems.push(`${file} ${name}: no progress= (the set shows one progress state)`);
      // Golden Glow is the game's own variety: no frame says "real cultivars".
      if (/real cultivars?/i.test(caption)) problems.push(`${file} ${name}: "real cultivars" (Golden Glow is fantasy)`);
      // screenshots.md quotes every iPhone sub-line and names every Duo frame (the scenario files win).
      const sub = (caption.split(' / ')[1] || '').trim();
      if (prefix === 'P' && sub && !ssDoc.includes(sub)) problems.push(`screenshots.md does not quote ${name}'s sub-line: ${sub}`);
      if (prefix === 'D' && !ssDoc.includes(name.slice(4)) ) problems.push(`screenshots.md does not mention ${name}`);
    }
    if (states.size > 1) problems.push(`${file}: ${states.size} progress states (${[...states].join(', ')}); the set must read as one player`);
  }
}
const screenshots = {
  _comment: 'store.yml (to be ported from Swoop) artifacts store-69 (6.9", 2868x1320), store-63 (6.3", 2622x1206: the required "Dynamic Island, medium" slot, the APP_IPHONE_61 class) and store-duo (inner 2853x2007), all landscape. Frames P01-P10 / D01-D10 in screenshots.md order. Until a store run exists (DEFAULT_STORE_RUN in asc.yml), validate reports them as gaps and push skips them.',
  APP_IPHONE_67: FRAMES.map(n => `store-69/P${n}.png`),
  APP_IPHONE_61: FRAMES.map(n => `store-63/P${n}.png`),
  duoInner: FRAMES.map(n => `store-duo/D${n}.png`)
};

const meta = {
  _comment: 'Built from docs/appstore/metadata.md, review-notes.md, achievements.md and featuring-nomination.md in the schema of Swoop\'s docs/appstore/asc-metadata.json (tools/appstore/build-metadata.js, to be ported to this repo); asc.swift pushes it. Do not edit by hand: change the docs and regenerate. No personal data: the App Review contact is read at run time from Squish (--inherit-from com.pravegm.squish). The copyright is the public handle, not a personal name.',
  bundleId: 'com.pravegm.snapjaw',
  primaryLocale: 'en-GB',
  copyrightHolder: copyrightLine || null,
  contentRights: 'DOES_NOT_USE_THIRD_PARTY_CONTENT',
  categories,
  localizations: {
    'en-GB': { name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: descGB, keywords, promotionalText: promo, supportUrl: site + 'support.html', marketingUrl: site },
    'en-US': { name, subtitle, privacyPolicyUrl: site + 'privacy.html', description: descUS, keywords, promotionalText: promo, supportUrl: site + 'support.html', marketingUrl: site }
  },
  ageRating: {
    _comment: 'metadata.md §8: 4+; every content item None, every capability No, Contests None (leaderboards are not prize contests), not Made for Kids. Cartoon or Fantasy Violence is None on the condition in metadata.md §8 / §11 ask 1 (the bite is a gulp, no red, no flattened bugs); if the final art fails it, the answer becomes INFREQUENT_OR_MILD (9+) and the founder is told. Names from AgeRatingDeclarationUpdateRequest (as Brim and Swoop).',
    parentalControls: false, ageAssurance: false, unrestrictedWebAccess: false, userGeneratedContent: false, messagingAndChat: false,
    advertising: false, socialMedia: false, socialMediaAgeRestricted: false,
    profanityOrCrudeHumor: 'NONE', horrorOrFearThemes: 'NONE', alcoholTobaccoOrDrugUseOrReferences: 'NONE', matureOrSuggestiveThemes: 'NONE',
    medicalOrTreatmentInformation: 'NONE', healthOrWellnessTopics: false, sexualContentOrNudity: 'NONE', sexualContentGraphicAndNudity: 'NONE',
    violenceCartoonOrFantasy: 'NONE', violenceRealistic: 'NONE', violenceRealisticProlongedGraphicOrSadistic: 'NONE', gunsOrOtherWeapons: 'NONE',
    gamblingSimulated: 'NONE', contests: 'NONE', gambling: false, lootBox: false, kidsAgeBand: null,
    ageRatingOverrideV2: 'NONE', koreaAgeRatingOverride: 'NONE'
  },
  review: { notes, demoAccountRequired: false, contact: { firstName: null, lastName: null, phone: null, email: null } },
  release: { _comment: 'metadata.md §9 and §12: manual release; the founder presses Release This Version on Tue 8 Dec 2026 at about 08:00 UK (runbook §7). The tool never releases or submits.', ...RELEASE },
  price: { baseTerritory: 'GBR', customerPrice: '1.99' },
  availability: { _comment: 'metadata.md §9: every territory except China mainland and Vietnam (both need a local game licence; Brim, Swoop and Hush exclude both). Mac and Vision Pro availability has no public API: the tool prints the clicks.', excludedTerritories: ['CHN', 'VNM'], availableInNewTerritories: true },
  achievements,
  leaderboards,
  screenshots,
  nomination: {
    _comment: 'docs/appstore/featuring-nomination.md. notes = Helpful Details. submit: true presses Submit (a saved draft is not a nomination). Submit by Mon 16 Nov 2026 (3 weeks before the Tue 8 Dec launch); the tool submits it in runbook §3.',
    name: nomName, type: 'APP_LAUNCH', description: nomDesc, notes: nomNotes, publishStartDate: LAUNCH,
    deviceFamilies: ['IPHONE'], locales: ['en-GB', 'en-US'], supplementalMaterialsUris: [site],
    hasInAppEvents: false, launchInSelectMarketsFirst: false, preOrderEnabled: false, submit: true
  }
};

const c = s => [...s].length, b = s => Buffer.byteLength(s);
const placeholder = s => (s.includes('[') && s.includes(']')) || /todo|tbd|placeholder|example\.com|\{domain\}|<domain>/i.test(s);
const limits = [['name', name, 30], ['subtitle', subtitle, 30], ['promo', promo, 170], ['descGB', descGB, 4000], ['descUS', descUS, 4000], ['nomName', nomName, 60], ['nomDesc', nomDesc, 1000], ['nomNotes', nomNotes, 500]];
for (const [k, v, l] of limits) { if (!v) problems.push(`${k}: empty`); else { if (c(v) > l) problems.push(`${k}: ${c(v)} > ${l}`); if (placeholder(v)) problems.push(`${k}: placeholder-like`); } }
if (b(keywords) > 100) problems.push(`keywords ${b(keywords)} bytes`);
if (/\s/.test(keywords)) problems.push('keywords contain whitespace');
if (b(notes) > 4000) problems.push(`notes ${b(notes)} bytes`);
if (/[^\x00-\x7F]/.test(notes)) problems.push('notes not ASCII: ' + JSON.stringify([...new Set(notes.match(/[^\x00-\x7F]/g))]));
if (placeholder(notes)) problems.push('notes placeholder-like');
const pts = achievements.reduce((a, x) => a + x.points, 0);
if (achievements.length !== 12) problems.push(`achievements ${achievements.length}`);
if (pts > 1000) problems.push('points > 1000');
for (const a of achievements) { const t = a.localizations['en-GB'].name; if (c(t) > 30) problems.push('title > 30: ' + t); if (a.points > 100) problems.push('points > 100 ' + a.vendorIdentifier); }
const banned = /smash|squish|squash|\bkill|splat|fold to /i;
for (const [k, v] of [['name', name], ['subtitle', subtitle], ['promo', promo], ['descGB', descGB], ['descUS', descUS], ['keywords', keywords], ['notes', notes], ['nomDesc', nomDesc], ['nomNotes', nomNotes.replace('Squish, ', '')]]) if (banned.test(v)) problems.push(`${k} has a banned word: ${v.match(banned)[0]}`);
for (const a of achievements) for (const x of Object.values(a.localizations['en-GB'])) if (banned.test(x)) problems.push('banned word in ' + a.vendorIdentifier);
// R6: the untrue R5 claims (SCORE-R5 §4 #3) must never come back.
// R7 (SCORE-R6 #8): "Best Feast" was the leaderboard's old name (a Feast is a 3+ bite; the board holds the best score).
const stale = /protein|HUD on the left|to (×|x)4\b|12 at most|max(imum)? 12|up to 12 snaps|seven clean bites in a row|best feast/i;
for (const [k, v] of [['promo', promo], ['descGB', descGB], ['descUS', descUS], ['notes', notes], ['nomDesc', nomDesc], ['nomNotes', nomNotes], ['whatsNew', whatsNew]]) if (stale.test(v)) problems.push(`${k} repeats an untrue claim: ${v.match(stale)[0]}`);
for (const a of achievements) for (const x of Object.values(a.localizations['en-GB'])) if (stale.test(x)) problems.push('untrue claim in ' + a.vendorIdentifier + ': ' + x);
for (const lb of leaderboards) for (const l of Object.values(lb.localizations)) if (stale.test(l.formatterSuffix + l.formatterSuffixSingular)) problems.push('leaderboard suffix says protein: ' + lb.vendorIdentifier);

fs.writeFileSync(path.join(root, 'docs/appstore/asc-metadata.json'), JSON.stringify(meta, null, 2) + '\n');
console.log({ name: c(name), subtitle: c(subtitle), promo: c(promo), descGB: c(descGB), descUS: c(descUS), kwBytes: b(keywords), notesBytes: b(notes),
  whatsNew: c(whatsNew), nomName: c(nomName), nomDesc: c(nomDesc), nomNotes: c(nomNotes), ach: achievements.length, pts, copyright: meta.copyrightHolder,
  categories: [categories.primary, ...categories.primarySubcategories, categories.secondary].join(' ') });
console.log(achievements.map(a => `${a.vendorIdentifier} ${a.points} t=${c(a.localizations['en-GB'].name)} | ${a.localizations['en-GB'].name} | ${a.localizations['en-GB'].beforeEarnedDescription} | ${a.localizations['en-GB'].afterEarnedDescription}`).join('\n'));

// screenshot headline counts
const ss = rd('docs/appstore/screenshots.md');
for (const m of ss.matchAll(/\*\*([^*]*(?:\*[^*]+\*[^*]*)?)\*\* \((\d+)\)/g)) {
  const h = m[1].replace(/\*/g, ''); const n = c(h);
  console.log(`caption ${n} (doc says ${m[2]})${n !== +m[2] ? '  MISMATCH' : ''}${n > 30 ? '  TOO LONG' : ''} | ${h}`);
}
if (problems.length) { console.log('\nPROBLEMS:\n  ' + problems.join('\n  ')); process.exitCode = 1; } else console.log('\nOK');
