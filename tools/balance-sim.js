#!/usr/bin/env node
// Snapjaw balance simulator (Round 5): a line-by-line Node port of Snap/Core (Tuning, BugCatalog, WaveFactory,
// TrapSession, TrapPilot). KEEP IN SYNC with Snap/Core/*.swift: same constants, same draw order.
// Used to tune Tuning numerically without a Swift compiler.
//
//   node tools/balance-sim.js                      # 16 seeds x 4 skills at 60 Hz, prints SNAP-BAL lines + target checks
//   node tools/balance-sim.js seeds=40 skills=casual,expert
//   node tools/balance-sim.js verbose=1 seeds=2    # one line per run
//   node tools/balance-sim.js windows=10           # robustness: medians of 10 different 8-seed windows
//   node tools/balance-sim.js attract=1            # attract mode never stalls
//   node tools/balance-sim.js crowd=1              # R2: crowd waves land within 1.2 s
//   node tools/balance-sim.js detector=1           # the SnapDetector checks (incl. QA-1 #5 and #6)
//   node tools/balance-sim.js zen=1                # R6: the Zen Bog (10 min per run: never tires, never wilts, keeps
//                                                  # catching, its day loops); the main run prints it too (zenrows=0 skips)
//   node tools/balance-sim.js crease=1             # R3: no bug rests within creaseGap(radius) of the midrib line;
//                                                  # R4: nothing in the trap is low within 20 + r of it (attract too)
//   Any Tuning value can be overridden: T.beeChanceDusk=0.5
//   With novice / casual in the skills, it also runs their Sprout run 1 (SPROUT1) and checks each lasts >= 90 s.
//   R5: with novice, also its Sprout runs 2 (>= 75 s) and 3 (>= 60 s); with expert / perfect, the same runs without
//   pilotGiveUp ("nogiveup", reported only; nogiveup=0 skips them).
//   Seeds are 1000 + 7919*i (the same as SnapTests/BalanceTests.swift); the pilot seed is seed*7+1.
//
// Numbers are not bit-identical to Swift (libm sin/cos/pow may differ in the last bit and the runs are chaotic), so
// the Swift test uses bands around these medians. The port omits hints, telemetry and the detector (the pilot
// drives TrapInput directly, as in the Swift harness).
// R2: bugs x1.8 with a body rim test, nectar clusters, crowd landings, hunger (wilt), the >= 2 chain rule,
// SessionOptions.startSnaps, spared-on-escape, and the casual pilot's fumbles (design/notes/core-R2.md).
// R3: nothing rests on the crease, the hunger clock (18/16/14/12 s) from the first in-trap landing after a catch,
// stinger bites x1 with no refund, SessionOptions.freeFirstSting, maxSnaps 14, the x5 chain cap, tight nectar
// clusters, the late-night ramp, and the pilot's own clock (design/notes/core-R3.md).
// R4: the hunger clock ticks only while a catchable bug has landed in the trap and no protected bug has; night wilt
// 14 s; SessionOptions.firstRun (Feed only: 14 snaps, no wilting, the first sting free, a calm first morning);
// ground moves and the hover keep to their own lobe and walkers enter on their spot's side, so nothing walks or
// hovers low across the crease; the late reaction floor is 0.2; expert and perfect give up waiting after 12 s
// (design/notes/core-R4.md).
// R5: a protected bug pauses the hunger clock from its final approach (in the zone and below creaseAirHeight); the
// Sprout taper (SessionOptions.sproutRun 1-3: 14 / 13 / 12 snaps); protected entries never start in a Duo thumb band;
// the pilot's giveUp switch for the report (design/notes/core-R5.md).
// R6: the Zen Bog (SessionOptions.for(.zen): snaps never run out, no hunger, stingers cost nothing, the day loops every
// zenDayWaves and the late ramp never starts: TrapRules.paceWave), and the last light (Feed and Daily: from lastLightWave the
// hunger clock ticks whatever is in the trap, so a hand that never gives up still ends) (design/notes/core-R6.md).
// R7: the FEAST multiplier (a clean bite of >= bigFeastCount scores x feastMultiplier: TrapRules.bitePoints), and
// the night pool (day bugs x nightDayBugWeight, fireflies and crickets lead) (design/notes/core-R7.md).
//   node tools/balance-sim.js night=1              # R7: who lands in the trap at night (waves 23-90)
// R8 (design/notes/core-R8.md): the lid is the jaw. The pilot closes the whole phone (close times by skill), the bite
// fires at the shut (duration = the close time), bugs startle at their nerve and flee after their reaction (fear), the
// bite's exposure is max(real, modelExposure), shut and a round waiting for its first close freeze the clock, any miss
// breaks the chain, 12 start snaps, hunger 18/14/12/12, the sleepy morning; and the 30 levels (tools/levels.js):
//   node tools/balance-sim.js levels=1 [levelSeeds=8] [ids=1,2] [debug=1] [all=1]   # every level by the four pilots
//   node tools/balance-sim.js detector=1           # the R8 SnapDetector rules (founder: arm 35, shut 18, start closed)
// R9 (design/notes/core-R9.md): only a RISING closure starts a close (the pilot's reopen never startles bugs); the
// detector's re-arm also needs rearmRise above the lowest theta since the shut, a round's start counts theta <=
// startShutAngle as closed, noteFolded (the outer display); detector=1 adds noisy hardware traces (noisySeeds=200);
// a level's calm (LevelSpec.reactionScale, levels.js `calm`); the level table draws the pilot's first close
// (TrapPilot.drawFirstClose) and prints the star spread, world sums (best of 3 tries) and the R9 level targets;
//   node tools/balance-sim.js levels=1 levelSeeds=24 [ends=1] [debug=1]
//   node tools/balance-sim.js trace=1 seed=7 skill=expert      # one Feed run's bites (the CI demo: pilot seed + 101)
// and the novice's first 20 s (caught by 20 s, first catch) in the main table's checks.
'use strict';
const { LEVELS, goalOf } = require('./levels.js');

// MARK: Tuning (mirror of Snap/Core/Tuning.swift)
const T = {
  // economy (GAME-DESIGN §5)
  startSnaps: 12, maxSnaps: 14, snapCost: 1, feastCount: 3, feastRefund: 1, bigFeastCount: 5, bigFeastRefund: 2,
  // R7 (#3): a clean bite of >= bigFeastCount scores x this, on top of the chain (TrapRules.bitePoints / feastBonus)
  feastMultiplier: 2.0,
  scarabRefund: 2, ladybirdRefund: 1, beeCost: 1, waspCost: 2, chainStep: 0.5, chainMaxMultiplier: 5,
  // bite (GAME-DESIGN §4)
  sipReactionFactor: 1.35, flyingReactionFactor: 0.55, rimReactionFactor: 0.6, catchableHeight: 0.6,
  // R7 (#14): reactions x 0.955 and lingers x 0.91 per late wave (R6: 0.96 / 0.92), so the expert p90 sits <= 340 s on 8 seeds
  lateWaveStart: 30, lateReactionDecay: 0.955, lateReactionFloor: 0.2, lateLingerDecay: 0.91, lateLingerFloor: 0.2,
  // waves (GAME-DESIGN §6)
  firstWaveTime: 1.2, waveDelayMin: 3.0, waveDelayMax: 4.5,
  noonWave: 7, duskWave: 15, nightWave: 23, deepNightWave: 31,
  nectarReseedWaves: 6, nectarMin: 6, nectarMax: 8, nectarRadiusMin: 12, nectarRadiusMax: 16,
  nectarClusterMin: 2, nectarClusterMax: 3, nectarRingMin: 24, nectarRingMax: 30, nectarClusterGap: 190, nectarArcMargin: 0.25, nectarHalfGap: 0.45,
  nectarClusterInner: 0.32, nectarClusterOuter: 0.55, nectarKeptClearance: 60, nectarCreaseClearance: 80,
  nectarTries: 30, crowdNearMin: 60, crowdNearMax: 140,
  lingerMorningMin: 6, lingerMorningMax: 8, lingerNoonMin: 5, lingerNoonMax: 7,
  lingerDuskMin: 4, lingerDuskMax: 6, lingerNightMin: 3.5, lingerNightMax: 5,
  beeFromWave: 3, beeChanceMorning: 0.35, beeChanceNoon: 0.4, beeChanceDusk: 0.5, beeChanceNight: 0.55,
  beeChanceNight2: 0.15, extraBeeEvery: 40, maxProtectedPerWave: 4, beeLingerFactor: 0.6,
  sizeFirstMin: 2, sizeFirstMax: 3, sizeMorningMin: 2, sizeMorningMax: 4, sizeNoonMin: 2, sizeNoonMax: 4,
  sizeDuskMin: 2, sizeDuskMax: 4, sizeNightMin: 2, sizeNightMax: 5,
  // R7 (#14): the night pool: day bugs x nightDayBugWeight, fireflies and crickets lead
  nightDayBugWeight: 0.3, nightFireflyWeight: 8, nightCricketWeight: 6,
  crowdFromWave: 3, crowdChance: 0.45, crowdSpread: 0.1, trickleMin: 0.6, trickleMax: 1.2, beeSpread: 2.5,
  passerChance: 0.12, beePasserChance: 0.15, maxWaveBugs: 7, maxBugsOnScreen: 18,
  scarabFromWave: 7, scarabChance: 1 / 12, gnatFromWave: 4, spotRadius: 0.75,
  // session
  tiredSeconds: 2.2, caughtSeconds: 0.5, openUpDelay: 1.0, crowdHintCount: 3, maxSubstep: 1 / 120,
  // R2 hunger (GAME-DESIGN §5)
  wiltMorning: 18, wiltNoon: 14, wiltDusk: 12, wiltNight: 12, hungryWarning: 3,
  // R4 (REVIEW-3 #11): a Sprout's first Feed run (SessionOptions.firstRun) starts with this many snaps
  firstRunSnaps: 14,
  // R4: ... and a calm first morning: waves 1..firstRunCalmWaves are crowds, each gap after them x firstRunWaveGap
  firstRunCalmWaves: 14, firstRunWaveGap: 1.6,
  // R5 (REVIEW-4 #8, founder call): the Sprout taper. Feed run 2 starts with sproutRun2Snaps (a free sting and the calm
  // morning, wilting on), run 3 with sproutRun3Snaps (the calm morning only); from run sproutTaperRuns + 1, standard
  sproutRun2Snaps: 13, sproutRun3Snaps: 12, sproutTaperRuns: 3,
  // R5 (REVIEW-4 #15): no protected bug's entry lies within thumbBandWidth pt of either outer edge with its y in the
  // middle thumbBandLow..thumbBandHigh of the height (the Duo's book-pose thumbs); such a y is mirrored out of the band
  thumbBandWidth: 90, thumbBandLow: 0.25, thumbBandHigh: 0.75,
  // R3 (REVIEW-2 #5): no bug rests within its radius + creaseClearance of the crease band (creaseHalfWidth each side)
  creaseClearance: 16,
  // R4 (REVIEW-3 #14): a bug within creaseHalfWidth + its radius of the midrib line (in the trap) flies at least this high
  creaseAirHeight: 0.5,
  // R6 (#19, REVIEW-5 P2-5): the last light (Feed and the Daily): from this wave the hunger clock ticks whatever is in the trap
  lastLightWave: 85,
  // R6: the Zen Bog's day loops every this many waves (below lateWaveStart: Zen never speeds up)
  zenDayWaves: 28,
  // R2 bugs x1.8 (REVIEW-1 #4)
  bugRadiusScale: 1.8, chainMinBite: 2,
  // motion (ROUND-1 "Movement")
  hoverMin: 0.3, hoverMax: 0.6, hoverHeight: 0.5, hoverCircle: 6, approachHeightDrop: 0.5, approachPathFactor: 1.1,
  minFlightTime: 0.6, arcBend: 0.25, landSpacing: 4, landMaxRadius: 0.8, spotTries: 10,
  takeoffTime: 0.4, exitMargin: 40, leaveSpeedFactor: 1.2, escapeSpeedFactor: 1.8, releaseSpeedFactor: 1.3,
  walkerEscapeFactor: 3, wanderMin: 25, wanderMax: 70, nectarSeekRadius: 260,
  hopMin: 120, hopMax: 300, hopSpeed: 300, hopTimeMin: 0.5, hopTimeMax: 1.2, hopHeight: 0.8,
  dartMin: 80, dartMax: 180, dartTime: 0.25, dartHeight: 0.3, darterHoverChance: 0.5, crossHeight: 0.85,
  restlessFrom: 0.75,
  // R8 (ROUND-8 §1): the lid is the jaw. Armed at theta >= armAngle; the bite fires at the shut (theta <= shutAngle);
  // a close starts when closure passes closeStart and is abandoned under closeCancel. A bite's modelled exposure for a
  // bug that startles at s degrees is duration x (1 - (s - closeStart) / modelCloseSpan).
  armAngle: 35, shutAngle: 18, closeStart: 8, closeCancel: 4, reopenCancel: 10, modelCloseSpan: 124, slowCloseAfter: 0.6,
  untimedCloseDuration: 2.0,
  // R9 (real hardware): re-arm also >= rearmRise above the lowest theta since the shut; a round's start is closed at
  // theta <= startShutAngle whatever the status (SnapDetector.rearmAngle / isStartShut)
  rearmRise: 15, startShutAngle: 25,
  // R8 (ROUND-8 §4): a level whose script has nothing left to catch ends after this long (s)
  levelIdleEnd: 2.5,
  // R8 (§2): a dry bite costs this many extra snaps; a bite that lets a bug escape breaks the chain
  dryBiteCost: 0, missBreaksChain: 1, morningReactionFactor: 1.3,
  // pilot (ROUND-1 "TrapPilot"; R8: closes the whole phone, shut-angle bites, reopen times by skill)
  pilotIdleAngle: 150, pilotShutAngle: 5,
  novicePatience: 6, casualPatience: 7, expertPatience: 6, perfectPatience: 7,
  noviceBeeMiss: 0.6, casualBeeMiss: 0.25, expertBeeMiss: 0.02, perfectBeeHeight: 0.85,
  shooDepth: 30, shooTime: 0.4, shooHoldMax: 1.6, expertShooAfter: 5, perfectShooAfter: 0,
  expertValue: 120, perfectValue: 400, perfectRestless: 0.7, expertRestless: 0.6,
  // R4: expert and perfect bite a landed bug after this long without a snap even when they judge it too quick (hands
  // never wait for ever; with the R4 hunger rule a trap that is never fed only wilts slowly)
  pilotGiveUp: 12,
};
const SCENE = { w: 952, h: 670 };
const CREASE_HALF = 20; // ScreenLayout.creaseHalfWidth

const args = {};
for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); if (!k.startsWith('T.')) args[k] = v === undefined ? '1' : v; }
for (const a of process.argv.slice(2)) { const [k, v] = a.split('='); if (k.startsWith('T.')) T[k.slice(2)] = Number(v); }

// MARK: SeededRandom (SplitMix64)
const M64 = (1n << 64n) - 1n;
const u64 = (x) => BigInt.asUintN(64, x);
class SeededRandom {
  constructor(seed) { this.state = u64(BigInt(seed)); }
  next() {
    this.state = (this.state + 0x9E3779B97F4A7C15n) & M64;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & M64;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & M64;
    return z ^ (z >> 31n);
  }
  unit() { return Number(this.next() >> 11n) * (1.0 / 9007199254740992.0); }
  range(lo, hi) { return lo + (hi - lo) * this.unit(); }
  int(lo, hi) { if (hi <= lo) return lo; const span = BigInt(hi - lo) + 1n; return lo + Number(this.next() % span); }
  chance(p) { return this.unit() < p; }
}

// MARK: Geometry (Contracts.swift TrapGeometry)
class Geo {
  constructor(w, h) { this.w = w; this.h = h; this.cx = Math.round(w / 2); this.cy = Math.round(h / 2); this.a = 432; this.b = 296; }
  nr(p) { const dx = (p.x - this.cx) / this.a, dy = (p.y - this.cy) / this.b; return Math.sqrt(dx * dx + dy * dy); }
  contains(p) { return this.nr(p) <= 1; }
  onRim(p) { const r = this.nr(p); return r >= 0.84 && r <= 1; }
  point(t, r) { return { x: this.cx + this.a * (Math.cos(t) * r), y: this.cy + this.b * (Math.sin(t) * r) }; }
}

// MARK: BugCatalog
const SPECIES = ['housefly', 'gnat', 'fruitFly', 'bluebottle', 'ant', 'ladybird', 'grasshopper', 'moth', 'mosquito',
  'dragonfly', 'firefly', 'cricket', 'goldenScarab', 'bee', 'bumblebee', 'wasp'];
const MORNING = 0, NOON = 1, DUSK = 2, NIGHT = 3;
// species: [points, reaction, nerve, radius, firstPhase]. R8: nerve is the startle depth (degrees of closure; the bug
// starts to flee then, and is gone after its reaction time); reaction is that flee time (s).
const INFO = {
  housefly: [10, 0.50, 12, 14, MORNING], gnat: [3, 0.65, 16, 7, MORNING], fruitFly: [6, 0.55, 12, 9, MORNING],
  bluebottle: [25, 0.32, 10, 16, NOON], ant: [8, 0.90, 45, 10, NOON], ladybird: [15, 0.55, 40, 14, NOON],
  grasshopper: [20, 0.40, 22, 18, NOON], moth: [20, 0.50, 25, 18, DUSK], mosquito: [12, 0.25, 8, 9, DUSK],
  dragonfly: [50, 0.22, 8, 24, DUSK], firefly: [35, 0.45, 30, 13, NIGHT], cricket: [25, 0.55, 30, 17, NIGHT],
  goldenScarab: [150, 0.70, 50, 20, NOON], bee: [0, 1.0, 20, 16, MORNING], bumblebee: [0, 1.0, 28, 22, NOON],
  wasp: [0, 1.0, 14, 16, DUSK],
};
const info = (s) => { const r = INFO[s]; return { species: s, points: r[0], reaction: r[1], nerve: r[2], radius: r[3] * T.bugRadiusScale, firstPhase: r[4] }; };
const isProtected = (s) => s === 'bee' || s === 'bumblebee' || s === 'wasp';
// motion: [style, speed, walkSpeed, wobbleAmp, wobbleHz, nectarChance, lingerFactor, pauseMin, pauseMax]
const FLY = 'fly', SWARM = 'swarm', WALKER = 'walker', HOPPER = 'hopper', DARTER = 'darter', FLUTTER = 'flutter';
const MOTION = {
  housefly: [FLY, 230, 60, 18, 2.2, 0.7, 1.0, 0.4, 1.2], gnat: [SWARM, 170, 40, 10, 4.0, 0.0, 1.0, 0.3, 0.9],
  fruitFly: [FLY, 190, 45, 12, 3.0, 0.9, 1.25, 0.5, 1.4], bluebottle: [FLY, 300, 80, 16, 2.6, 0.7, 0.7, 0.3, 0.8],
  ant: [WALKER, 42, 42, 3, 1.5, 0.5, 1.0, 0.3, 0.8], ladybird: [FLY, 170, 35, 10, 1.6, 0.5, 1.0, 0.6, 1.5],
  grasshopper: [HOPPER, 220, 0, 8, 1.0, 0.0, 1.0, 1.0, 2.2], moth: [FLUTTER, 160, 30, 34, 1.4, 0.0, 1.0, 0.6, 1.5],
  mosquito: [FLY, 260, 70, 22, 5.0, 0.4, 0.9, 0.3, 0.9], dragonfly: [DARTER, 320, 0, 10, 0.8, 0.0, 1.0, 0.6, 1.4],
  firefly: [FLUTTER, 160, 30, 20, 0.9, 0.3, 1.0, 0.6, 1.5], cricket: [HOPPER, 200, 0, 6, 1.0, 0.0, 1.0, 1.0, 2.2],
  goldenScarab: [FLY, 170, 30, 8, 1.2, 0.5, 1.1, 0.6, 1.5], bee: [FLY, 200, 40, 14, 1.8, 0.85, 1.0, 0.5, 1.3],
  bumblebee: [FLY, 160, 30, 12, 1.2, 0.85, 1.3, 0.6, 1.5], wasp: [FLY, 250, 70, 20, 3.4, 0.5, 0.9, 0.2, 0.6],
};
const motion = (s) => { const m = MOTION[s]; return { style: m[0], speed: m[1], walkSpeed: m[2], wobbleAmp: m[3], wobbleHz: m[4], nectarChance: m[5], lingerFactor: m[6], pauseMin: m[7], pauseMax: m[8] }; };

// MARK: Rules
// R6: the wave the late factor uses (TrapRules.paceWave): Zen's recipe wave, else the real one.
function paceWave(wave, mode) { return mode === 'zen' ? ((Math.max(wave, 1) - 1) % T.zenDayWaves) + 1 : wave; }
function lateFactor(wave) {
  // R8: the morning's bugs are sleepy (x morningReactionFactor): a slow hand still catches something while it learns
  if (wave < T.noonWave) return T.morningReactionFactor;
  if (wave <= T.lateWaveStart) return 1;
  return Math.max(T.lateReactionFloor, Math.pow(T.lateReactionDecay, wave - T.lateWaveStart));
}
// R9: scale = a level's calm (LevelSpec.reactionScale / TrapRules.reactionScale; 1 outside levels), x catchable bugs only
function reaction(inf, sipping, flying, onRim, wave, scale) {
  let r = inf.reaction;
  if (!isProtected(inf.species)) r *= lateFactor(wave) * (scale == null ? 1 : scale);
  if (sipping) r *= T.sipReactionFactor;
  if (flying) r *= T.flyingReactionFactor;
  if (onRim) r *= T.rimReactionFactor;
  return r;
}
// R8 (TrapRules.modelExposure): how long a bug that startles at `nerve` degrees has been fleeing at the shut of a
// close that took `duration` s from closeStart to the shut (a straight close over modelCloseSpan degrees).
function modelExposure(nerve, duration) {
  const d = isFinite(duration) ? Math.max(0, duration) : 0;
  const frac = clamp((nerve - T.closeStart) / T.modelCloseSpan, 0, 1);
  return d * (1 - frac);
}
// R8 (TrapRules.crossing): the time between (t0, c0) and (t1, c1) where the value crossed `thr` (rising), clamped.
function crossing(t0, c0, t1, c1, thr) {
  if (c1 <= c0) return t1;
  return clamp(t0 + (t1 - t0) * (thr - c0) / (c1 - c0), t0, t1);
}
// R2: the rim test uses the bug's outer edge (its centre pushed out by its radius), so art and rules agree.
function onRimBody(g, p, radius) {
  const rc = g.nr(p);
  if (rc > 1) return false;
  const dx = p.x - g.cx, dy = p.y - g.cy; const len = Math.hypot(dx, dy);
  if (len < 1e-6) return false;
  const q = { x: p.x + dx / len * radius, y: p.y + dy / len * radius };
  return g.nr(q) >= 0.84;
}
function wiltSeconds(ph) {
  switch (ph) { case MORNING: return T.wiltMorning; case NOON: return T.wiltNoon; case DUSK: return T.wiltDusk; default: return T.wiltNight; }
}
function chainMultiplier(chain) { return Math.min(T.chainMaxMultiplier, 1 + T.chainStep * chain); }
// R3 (REVIEW-2 #5): how far (pt) a resting bug's centre must sit from the midrib line: the crease band, its radius and
// creaseClearance.
function creaseGap(radius) { return CREASE_HALF + radius + T.creaseClearance; }
// R3: (x, y) moved straight out sideways to creaseGap if it is closer, then (if that leaves maxR) y pulled in.
// R4: side +1 / -1 keeps it on that lobe (0: the side it is on; a point on the line goes right).
function offCrease(g, p, maxR, radius, side) {
  const gap = creaseGap(radius);
  const dx = p.x - g.cx;
  const sd = side ? side : (dx >= 0 ? 1 : -1);
  if (dx * sd >= gap) return p;
  const x = g.cx + sd * gap;
  const ux = gap / g.a;
  const lim = maxR * maxR - ux * ux;
  let y = p.y;
  if (lim <= 0) y = g.cy;
  else { const ymax = g.b * Math.sqrt(lim); y = clamp(p.y, g.cy - ymax, g.cy + ymax); }
  return { x, y };
}

// MARK: WaveFactory
function phaseForWave(index) {
  const i = Math.max(index, 1);
  if (i >= T.nightWave) return NIGHT;
  if (i >= T.duskWave) return DUSK;
  if (i >= T.noonWave) return NOON;
  return MORNING;
}
function waveSeed(seed, index) {
  const r = new SeededRandom(u64(seed ^ u64(BigInt(index) * 0x9E3779B97F4A7C15n) ^ 0x57415645n));
  return r.next();
}
function waveDelay(seed, index) {
  if (index <= 1) return T.firstWaveTime;
  const r = new SeededRandom(waveSeed(seed, index) ^ 0xD11An);
  return r.range(T.waveDelayMin, T.waveDelayMax);
}
function nectarSeed(seed, block) { return u64(seed ^ u64(BigInt(block) * 0xBF58476D1CE4E5B9n) ^ 0x4E4543n); }
// R2 (REVIEW-1 #19): 6-8 drops in clusters of 2-3, the clusters alternating between the lobes, so crowds form in one place.
function nectarDrops(seed, g) {
  const r = new SeededRandom(seed ^ 0x4E454354n);
  const n = r.int(T.nectarMin, T.nectarMax);
  const kMin = Math.floor((n + T.nectarClusterMax - 1) / T.nectarClusterMax), kMax = Math.floor(n / T.nectarClusterMin);
  const k = r.int(kMin, kMax);
  const extra = n - T.nectarClusterMin * k;
  const firstLeft = r.chance(0.5);
  const centres = [], out = [];
  for (let c = 0; c < k; c++) {
    const size = T.nectarClusterMin + (c < extra ? 1 : 0);
    const left = (c % 2 === 0) === firstLeft;
    // a lobe with two clusters puts its first in the upper half and its second in the lower half
    const inLobe = (c % 2 === 0) ? Math.floor((k + 1) / 2) : Math.floor(k / 2);
    const half = inLobe < 2 ? 0 : (Math.floor(c / 2) === 0 ? 1 : -1);
    const m = T.nectarArcMargin;
    let lo = left ? Math.PI / 2 + m : -Math.PI / 2 + m, hi = left ? 3 * Math.PI / 2 - m : Math.PI / 2 - m;
    if (half === 1) { if (left) hi = Math.PI - T.nectarHalfGap; else lo = T.nectarHalfGap; }
    if (half === -1) { if (left) lo = Math.PI + T.nectarHalfGap; else hi = -T.nectarHalfGap; }
    const ring = r.range(T.nectarRingMin, T.nectarRingMax);
    // the candidate furthest from the other centres (off the crease) wins; the first one clear of them all stops the search
    let p = { x: g.cx, y: g.cy }, best = -Infinity;
    for (let tries = 0; tries < T.nectarTries; tries++) {
      const t = r.range(lo, hi);
      const rr = r.range(T.nectarClusterInner, T.nectarClusterOuter);
      const cand = g.point(t, rr);
      let gap = 1e6;
      for (const q of centres) gap = Math.min(gap, Math.hypot(q.x - cand.x, q.y - cand.y));
      const clear = Math.abs(cand.x - g.cx) >= T.nectarCreaseClearance + ring;
      const score = clear ? gap : gap - 1e9;
      if (score > best) { best = score; p = cand; }
      if (clear && gap >= T.nectarClusterGap) break;
    }
    centres.push(p);
    const phase = r.range(0, 2 * Math.PI);
    for (let j = 0; j < size; j++) {
      const ang = phase + 2 * Math.PI * j / size;
      const radius = r.range(T.nectarRadiusMin, T.nectarRadiusMax);
      out.push({ id: out.length, x: p.x + Math.cos(ang) * ring, y: p.y + Math.sin(ang) * ring, radius });
    }
  }
  return out;
}
function lingerRange(ph, index) {
  switch (ph) {
    case MORNING: return [T.lingerMorningMin, T.lingerMorningMax];
    case NOON: return [T.lingerNoonMin, T.lingerNoonMax];
    case DUSK: return [T.lingerDuskMin, T.lingerDuskMax];
    default: {
      const k = index > T.lateWaveStart ? Math.max(T.lateLingerFloor, Math.pow(T.lateLingerDecay, index - T.lateWaveStart)) : 1;
      return [T.lingerNightMin * k, T.lingerNightMax * k];
    }
  }
}
function pool(ph, index) {
  // R7 (#14): at night the day bugs thin out (x nightDayBugWeight) and fireflies and crickets lead the pool
  const k = ph >= NIGHT ? T.nightDayBugWeight : 1;
  const out = [['housefly', 6 * k], ['fruitFly', 3 * k]];
  if (index >= T.gnatFromWave) out.push(['gnat', 2 * k]);
  if (ph >= NOON) out.push(['bluebottle', 3 * k], ['grasshopper', 2 * k]);
  // ants and ladybirds are day bugs: they go home at dusk
  if (ph === NOON) out.push(['ant', 2], ['ladybird', 2]);
  if (ph >= DUSK) out.push(['moth', 3], ['mosquito', 3], ['dragonfly', 1.5]);
  if (ph >= NIGHT) out.push(['firefly', T.nightFireflyWeight], ['cricket', T.nightCricketWeight]);
  return out;
}
function pickWeighted(p, r) {
  let total = 0; for (const [, w] of p) total += w;
  let x = r.unit() * total;
  for (const [s, w] of p) { if (x < w) return s; x -= w; }
  return p[p.length - 1][0];
}
function groupSize(s, r) {
  if (s === 'gnat') return r.int(4, 5);
  if (s === 'ant') return r.int(3, 5);
  if (s === 'fruitFly') return 2;
  return 1;
}
function groupStep(s) {
  if (s === 'gnat') return 0.08;
  if (s === 'ant') return 0.6;
  if (s === 'fruitFly') return 0.25;
  return 0;
}
const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
function edgeEntry(target, g, r) {
  const left = target.x < g.cx;
  const x = r.unit();
  const W = g.w, H = g.h;
  if (x < 0.6) {
    const near = x < 0.4;
    const sideLeft = near ? left : !left;
    const y = clamp(target.y + r.range(-200, 200), 40, H - 40);
    return { x: sideLeft ? -30 : W + 30, y };
  }
  const xx = clamp(target.x + r.range(-260, 260), 40, W - 40);
  return { x: xx, y: x < 0.9 ? H + 30 : -30 };
}
// R5 (REVIEW-4 #15): a protected bug never enters under a Duo thumb. An entry within thumbBandWidth of either outer
// edge with its y strictly inside the band (thumbBandLow..thumbBandHigh of the height) has its y mirrored across the
// band's nearer edge (the band's lower half goes below it, its upper half above it): same side, same spread, no draws.
function thumbSafeEntry(e, g) {
  if (e.x >= T.thumbBandWidth && e.x <= g.w - T.thumbBandWidth) return e;
  const lo = g.h * T.thumbBandLow, hi = g.h * T.thumbBandHigh;
  if (!(e.y > lo && e.y < hi)) return e;
  return { x: e.x, y: e.y < (lo + hi) / 2 ? 2 * lo - e.y : 2 * hi - e.y };
}
function randomSpot(g, r, maxR) {
  const t = r.range(0, 2 * Math.PI);
  const rr = Math.sqrt(r.unit()) * maxR;
  return g.point(t, rr);
}
function clampToRadius(g, p, maxR) {
  const rr = g.nr(p);
  if (rr <= maxR || rr === 0) return p;
  const k = maxR / rr;
  return { x: g.cx + (p.x - g.cx) * k, y: g.cy + (p.y - g.cy) * k };
}
// R2: the flight time of an approach (what spawn computes), or null for walkers and bugs that never land in the trap.
function flightTime(spec) {
  const m = motion(spec.species);
  if (!spec.landsInTrap || m.style === WALKER) return null;
  return Math.max(T.minFlightTime, Math.hypot(spec.target.x - spec.entry.x, spec.target.y - spec.entry.y) * T.approachPathFactor / m.speed);
}
function protectedCount(index, ph, r) {
  let n = 0;
  switch (ph) {
    case MORNING: n = index >= T.beeFromWave && r.chance(T.beeChanceMorning) ? 1 : 0; break;
    case NOON: n = r.chance(T.beeChanceNoon) ? 1 : 0; break;
    case DUSK: n = r.chance(T.beeChanceDusk) ? 1 : 0; break;
    default: n = (r.chance(T.beeChanceNight) ? 1 : 0) + (r.chance(T.beeChanceNight2) ? 1 : 0); break;
  }
  if (index > T.lateWaveStart) n += Math.floor((index - T.lateWaveStart) / T.extraBeeEvery);
  return Math.min(n, T.maxProtectedPerWave);
}
function protectedSpecies(ph, r) {
  const u = r.unit();
  if (ph === MORNING) return 'bee';
  if (ph === NOON) return u < 0.75 ? 'bee' : 'bumblebee';
  if (u < 0.5) return 'bee';
  return u < 0.72 ? 'bumblebee' : 'wasp';
}
// R4: calm (a Sprout's first Feed run, SessionOptions.firstRun): waves up to firstRunCalmWaves are crowds. The crowd
// chance is still drawn, so the draw order never changes.
function makeWave(seed, index, g, nectar, calm) {
  const r = new SeededRandom(waveSeed(seed, index));
  const ph = phaseForWave(index);
  let size;
  if (index <= 3) size = r.int(T.sizeFirstMin, T.sizeFirstMax);
  else if (ph === MORNING) size = r.int(T.sizeMorningMin, T.sizeMorningMax);
  else if (ph === NOON) size = r.int(T.sizeNoonMin, T.sizeNoonMax);
  else if (ph === DUSK) size = r.int(T.sizeDuskMin, T.sizeDuskMax);
  else size = r.int(T.sizeNightMin, T.sizeNightMax);
  const crowd = (index >= T.crowdFromWave && r.chance(T.crowdChance)) || (!!calm && index <= T.firstRunCalmWaves);
  if (crowd) size = Math.max(size, 3);
  const p = pool(ph, index);
  // shuffled drop order (Fisher-Yates)
  const order = nectar.map((_, i) => i);
  for (let i = order.length - 1; i > 0; i--) { const j = r.int(0, i); const tmp = order[i]; order[i] = order[j]; order[j] = tmp; }
  // R2: a crowd wave goes to one cluster: the drops nearest a random anchor drop first, and its spots lie near it.
  let anchor = null;
  if (crowd && order.length > 0) {
    anchor = nectar[order[0]];
    const dist = (i) => Math.hypot(nectar[i].x - anchor.x, nectar[i].y - anchor.y);
    order.sort((i, j) => { const di = dist(i), dj = dist(j); return di < dj ? -1 : (di > dj ? 1 : i - j); });
  }
  const st = { nextDrop: 0 };
  const bugs = [];
  const [lmin, lmax] = lingerRange(ph, index);
  const addGroup = (s, count, base) => {
    const m = motion(s);
    const prot = isProtected(s);
    const canPass = (m.style === FLY || m.style === FLUTTER) && count === 1;
    if (canPass && r.chance(prot ? T.beePasserChance : T.passerChance)) {
      const cross = r.chance(0.5);
      if (cross) {
        const fromLeft = r.chance(0.5);
        const y0 = r.range(120, g.h - 120), y1 = r.range(120, g.h - 120);
        const e0 = { x: fromLeft ? -30 : g.w + 30, y: y0 };
        bugs.push({ species: s, entry: prot ? thumbSafeEntry(e0, g) : e0, target: { x: fromLeft ? g.w + 40 : -40, y: y1 }, linger: 0, landsInTrap: false, groupOffset: base });
      } else {
        const cl = r.chance(0.5), cb = r.chance(0.5);
        const tx = cl ? r.range(30, 90) : g.w - r.range(30, 90);
        const ty = cb ? r.range(30, 90) : g.h - r.range(30, 90);
        const target = { x: tx, y: ty };
        const e0 = edgeEntry(target, g, r);
        const entry = prot ? thumbSafeEntry(e0, g) : e0;
        const lg = r.range(lmin, lmax) * m.lingerFactor * (prot ? T.beeLingerFactor : 1);
        bugs.push({ species: s, entry, target, linger: lg, landsInTrap: false, groupOffset: base });
      }
      return;
    }
    let target;
    if (s === 'moth') {
      target = { x: g.cx + r.range(-80, 80), y: g.cy + r.range(-180, 180) };
    } else if (m.nectarChance > 0 && st.nextDrop < order.length && r.chance(m.nectarChance)) {
      const d = nectar[order[st.nextDrop]]; st.nextDrop += 1;
      target = { x: d.x, y: d.y };
    } else if (anchor !== null) {
      const t = r.range(0, 2 * Math.PI), dd = r.range(T.crowdNearMin, T.crowdNearMax);
      target = clampToRadius(g, { x: anchor.x + Math.cos(t) * dd, y: anchor.y + Math.sin(t) * dd }, T.spotRadius);
    } else {
      target = randomSpot(g, r, T.spotRadius);
    }
    let entry;
    if (m.style === WALKER) entry = { x: clamp(target.x + r.range(-120, 120), 40, g.w - 40), y: -20 };
    else entry = edgeEntry(target, g, r);
    if (prot) entry = thumbSafeEntry(entry, g); // R5 (REVIEW-4 #15)
    for (let k = 0; k < count; k++) {
      let t = target, e = entry;
      if (s === 'gnat') {
        t = { x: target.x + r.range(-45, 45), y: target.y + r.range(-35, 35) };
        e = { x: entry.x + r.range(-30, 30), y: entry.y + r.range(-30, 30) };
      } else if (s === 'fruitFly' && k > 0) {
        if (st.nextDrop < order.length && r.chance(0.6)) {
          const d = nectar[order[st.nextDrop]]; st.nextDrop += 1;
          t = { x: d.x, y: d.y };
        } else {
          t = { x: target.x + r.range(-50, 50), y: target.y + r.range(-40, 40) };
        }
      }
      const lg = r.range(lmin, lmax) * m.lingerFactor * (prot ? T.beeLingerFactor : 1);
      bugs.push({ species: s, entry: e, target: t, linger: lg, landsInTrap: true, groupOffset: base + k * groupStep(s) });
    }
  };
  let slot = 0, nonProtected = 0;
  while (nonProtected < size && bugs.length < T.maxWaveBugs) {
    const s = pickWeighted(p, r);
    const gsz = Math.min(groupSize(s, r), T.maxWaveBugs - bugs.length);
    const base = crowd ? r.range(0, T.crowdSpread) : slot * r.range(T.trickleMin, T.trickleMax);
    addGroup(s, gsz, base);
    nonProtected += gsz; slot += 1;
  }
  if (index >= T.scarabFromWave && r.chance(T.scarabChance)) {
    const base = crowd ? r.range(0, T.crowdSpread) : slot * r.range(T.trickleMin, T.trickleMax);
    addGroup('goldenScarab', 1, base); slot += 1;
  }
  // R2: a crowd lands together: each flyer starts late by how much quicker its flight is than the slowest one's.
  if (crowd) {
    const fl = bugs.map((b) => flightTime(b));
    let maxF = 0; for (const f of fl) if (f !== null) maxF = Math.max(maxF, f);
    for (let i = 0; i < fl.length; i++) if (fl[i] !== null) bugs[i].groupOffset += maxF - fl[i];
  }
  const np = protectedCount(index, ph, r);
  for (let k = 0; k < np; k++) {
    const s = protectedSpecies(ph, r);
    addGroup(s, 1, r.range(0, T.beeSpread));
  }
  return { index, phase: ph, delay: waveDelay(seed, index), bugs, crowd };
}

// MARK: Levels (R8, ROUND-8 §4; LevelBook in Snap/Core/Levels.swift)
function levelSeed(id) { return u64(0x1E7E1n * BigInt(id) + 77n); }
function levelGoalMet(g, r) {
  let sp = 0; for (const s of g.species) sp += r.bySpecies[s] || 0;
  return r.caught >= g.catchAny && sp >= g.speciesCount && r.biggest >= g.biteOf && r.spared >= g.spare;
}
// LevelBook.evaluate: passed (goal met, no sting where none is allowed, within the limits) and stars by bites used
function levelEvaluate(L, r) {
  const passed = levelGoalMet(goalOf(L), r) && (!L.noSting || r.stings === 0) && (L.time == null || r.seconds <= L.time + 1e-6) && (L.bites == null || r.snaps <= L.bites);
  const three = r.snaps <= L.stars[1] && (!L.clean3 || r.escapes === 0);
  const stars = !passed ? 0 : (three ? 3 : (r.snaps <= L.stars[0] ? 2 : 1));
  return { passed, stars };
}
// LevelBook.spawnSpec: a scripted bug as a SpawnSpec (the spot at 0.75 of the trap's semi-axes; a sipper aims at the
// nearest nectar drop on its lobe; flyers enter from their lobe's side edge, walkers from the bottom)
function levelSpawn(b, g, nectar) {
  let target = { x: g.cx + b.u * g.a * 0.75, y: g.cy + b.v * g.b * 0.75 };
  const m = motion(b.s);
  if (b.sip && m.nectarChance > 0 && nectar.length > 0) {
    let best = null, bd = Infinity; const side = b.u < 0 ? -1 : 1;
    for (const d of nectar) { if ((d.x < g.cx ? -1 : 1) !== side) continue; const dd = Math.hypot(d.x - target.x, d.y - target.y); if (dd < bd) { bd = dd; best = d; } }
    if (best !== null) target = { x: best.x, y: best.y };
  }
  let entry = m.style === WALKER ? { x: clamp(target.x, 40, g.w - 40), y: -20 } : { x: b.u < 0 ? -30 : g.w + 30, y: clamp(target.y + 90 * b.v, 40, g.h - 40) };
  if (isProtected(b.s)) entry = thumbSafeEntry(entry, g);
  return { species: b.s, entry, target, linger: b.linger, landsInTrap: true, groupOffset: 0 };
}

// MARK: TrapSession
const A_ARR = 'arriving', A_WALK = 'walking', A_SIP = 'sipping', A_HOP = 'hopping', A_LEAVE = 'leaving', A_CAUGHT = 'caught', A_ESC = 'escaped', A_REL = 'released';
const M = { approach: 0, hover: 1, sip: 2, pause: 3, dash: 4, hop: 5, cross: 6, leave: 7, escape: 8, release: 9, caught: 10 };

// R5 (REVIEW-4 #8, founder call): the Sprout taper, by Feed run (SproutPerks.forFeedRun in TrapSession.swift).
//   run 1: 14 snaps, no wilting, a free first sting, the calm morning; run 2: 13, a free sting, calm; run 3: 12, calm.
function sproutPerks(run) {
  if (!(run >= 1 && run <= T.sproutTaperRuns)) return null;
  if (run === 1) return { run, startSnaps: T.firstRunSnaps, noWilt: true, freeSting: true, calmMorning: true };
  if (run === 2) return { run, startSnaps: T.sproutRun2Snaps, noWilt: false, freeSting: true, calmMorning: true };
  return { run, startSnaps: T.sproutRun3Snaps, noWilt: false, freeSting: false, calmMorning: true };
}
// SessionOptions.sproutRun (0 = none), with the R4 firstRun flag meaning run 1.
function sproutRunOf(opts) { return opts.sproutRun ? opts.sproutRun : (opts.firstRun ? 1 : 0); }
class Session {
  constructor(seed, opts, mode) {
    this.seed = u64(BigInt(seed)); this.opts = opts; this.mode = mode || 'feed';
    this.g = new Geo(SCENE.w, SCENE.h);
    this.time = 0; this.phase = 'playing'; this.tiredElapsed = 0; this.tiredAt = 0;
    this.bugs = []; this.nextID = 1; this.pending = [];
    this.wave = 0; this.nextWaveAt = T.firstWaveTime; this.lastWaveAt = 0; this.dayPhase = MORNING;
    this.nectar = []; this.nextDropID = 0; this.reservedBy = new Map(); this.retiring = new Set();
    this.installNectar(0);
    // R4 (REVIEW-3 #11): SessionOptions.firstRun (Feed only; the Daily stays standard): 14 snaps, no wilting, the first
    // stinger bite free, whatever startSnaps / hunger / freeFirstSting say.
    // R5 (REVIEW-4 #8): the Sprout taper (SessionOptions.sproutRun 1-3; firstRun is sproutRun 1). Feed only.
    this.perks = this.mode === 'feed' ? sproutPerks(sproutRunOf(opts)) : null;
    this.firstRun = this.perks !== null && this.perks.run === 1;
    const start = this.perks ? this.perks.startSnaps : (opts.startSnaps == null ? T.startSnaps : opts.startSnaps);
    this.snapsLeft = clamp(start, 1, T.maxSnaps); this.score = 0; this.chain = 0;
    this.wilts = opts.snapsRunOut && opts.hunger !== false && !(this.perks && this.perks.noWilt);
    this.freeSting = !!opts.freeFirstSting || (this.perks !== null && this.perks.freeSting);
    this.calm = this.perks !== null && this.perks.calmMorning;
    // R6 (#19): the last light (TrapRules.lastLightApplies: Feed and the Daily, with wilting on)
    this.lastLight = this.wilts && (this.mode === 'feed' || this.mode === 'daily');
    // R4 (QA-2 #1, REVIEW-3 #12): the hunger clock ticks only while hungerTicks() (see tick).
    this.hunger = 0; this.hungrySent = false; this.hungerLive = false; this.freeStingUsed = false;
    this.prevArmed = true; this.prevClosure = 0; this.prevTime = 0;
    // R8: the close in progress (closure past closeStart while armed), the bugs in the trap during it, those that fled
    // it, and the shut (from the bite until the input is armed again: the clock is frozen)
    this.closing = false; this.closeStartAt = 0; this.closeBugs = new Set(); this.fled = 0; this.shut = false;
    // R8 (founder rule 3): every round starts closed: waiting (clock frozen, no spawns) until the input is first armed
    this.waiting = true;
    // R8 (ROUND-8 §4): a level (LevelBook): its scripted bugs, pace wave, bite limit; no waves, hunger or refunds
    this.level = this.mode === 'level' ? opts.level : null;
    this.bySpecies = {}; this.levelEnd = null; this.idleFor = 0;
    this.reactionScale = this.level && this.level.calm ? this.level.calm : 1;
    if (this.level) {
      const L = this.level;
      this.wave = L.pace; this.dayPhase = phaseForWave(L.pace);
      this.snapsLeft = L.bites == null ? T.maxSnaps : clamp(L.bites, 1, T.maxSnaps);
      this.goal = goalOf(L);
      for (const b of L.bugs) this.pending.push({ at: b.at, spec: levelSpawn(b, this.g, this.nectar) });
    }
    this.stats = { snaps: 0, caught: 0, stings: 0, feasts: 0, dry: 0, bestBite: 0, biggest: 0, longestChain: 0, spared: 0, wilts: 0, ratioSum: 0, ratioN: 0, dayRatioSum: 0, dayRatioN: 0, shutTime: 0 };
  }
  installNectar(block) {
    const drops = nectarDrops(nectarSeed(this.seed, block), this.g);
    const kept = this.nectar.filter((d) => this.reservedBy.has(d.id));
    for (const d of kept) this.retiring.add(d.id);
    const fresh = [];
    for (const d of drops) {
      let clash = false;
      for (const k of kept) if (Math.hypot(k.x - d.x, k.y - d.y) < T.nectarKeptClearance) clash = true;
      if (clash) continue;
      fresh.push({ id: this.nextDropID, x: d.x, y: d.y, radius: d.radius }); this.nextDropID += 1;
    }
    this.nectar = kept.concat(fresh);
  }
  freeDrop(b) {
    if (b.dropID === null) return;
    const id = b.dropID; b.dropID = null;
    if (this.reservedBy.get(id) === b.id) this.reservedBy.delete(id);
    if (this.retiring.has(id) && !this.reservedBy.has(id)) {
      this.retiring.delete(id);
      this.nectar = this.nectar.filter((d) => d.id !== id);
    }
  }
  dropAt(p) {
    for (const d of this.nectar) if (!this.retiring.has(d.id) && Math.abs(d.x - p.x) < 1.5 && Math.abs(d.y - p.y) < 1.5) return d;
    return null;
  }
  step(dt, input) {
    if (this.phase === 'finished') return;
    const d = isFinite(dt) ? Math.max(0, dt) : 0;
    const c = isFinite(input.closure) ? Math.max(0, input.closure) : 0;
    if (this.phase === 'playing') {
      if (this.waiting && (input.armed || input.snap)) this.waiting = false;
      this.fear(c, input);
      if (input.snap) this.bite(input.snap, input.armed);
      else if (this.shut && input.armed) this.shut = false; // rearmed
    }
    this.prevArmed = input.armed; this.prevClosure = c; this.prevTime = this.time;
    const n = Math.max(1, Math.ceil(d / T.maxSubstep - 1e-9));
    const h = d / n;
    for (let i = 0; i < n; i++) { this.tick(h); if (this.phase === 'finished') break; }
  }
  // R8 (§1): every bug in the trap feels the closure; past its startle depth (nerve) it flees after its reaction time.
  fear(c, input) {
    const now = this.time;
    const open = input.armed && !this.shut && !this.waiting;
    if (!this.closing) {
      // R9: only a rising closure starts a close (the pilot reports its reopen as a falling closure from ~115 deg; the
      // hinge's closure is ~0 then, as its reference restarts at the re-arm)
      const starts = open && c >= T.closeStart && c > this.prevClosure;
      if (starts || input.snap) {
        this.closing = true; this.fled = 0; this.closeBugs = new Set();
        this.closeStartAt = starts ? crossing(this.prevTime, this.prevClosure, now, c, T.closeStart) : now;
      }
    } else if (c < T.closeCancel && !input.snap) {
      // the close was abandoned (a partial close, opened again): the startled bugs that stayed calm down
      this.closing = false;
      for (const b of this.bugs) b.startledAt = null;
      return;
    }
    if (!this.closing) return;
    for (const b of this.bugs) {
      if (!this.inTrap(b)) continue;
      const a = this.activityOf(b);
      if (a === A_ARR && b.height >= T.catchableHeight) continue;
      if (!(a === A_ARR || a === A_WALK || a === A_SIP || a === A_HOP)) continue;
      if (!isProtected(b.species)) this.closeBugs.add(b.id);
      if (b.startledAt == null && c >= b.info.nerve) {
        b.startledAt = this.prevClosure < b.info.nerve ? crossing(this.prevTime, this.prevClosure, now, c, b.info.nerve) : now;
      }
      if (b.startledAt == null || input.snap) continue;
      const r = reaction(b.info, a === A_SIP, a === A_ARR || a === A_HOP, onRimBody(this.g, b, b.info.radius), paceWave(this.wave, this.mode), this.reactionScale);
      if (now - b.startledAt >= r) { this.fled += 1; this.takeOff(b, M.escape); }
    }
  }
  tick(h) {
    if (this.phase === 'playing' && (this.shut || this.waiting)) {
      // R8: shut = digesting. The clock is frozen (no waves, spawns, lingers or hunger); bugs already leaving finish.
      this.stats.shutTime += h;
      for (const b of this.bugs) if (b.mode === M.caught || b.mode === M.leave || b.mode === M.escape || b.mode === M.release) this.updateBug(b, h);
      this.bugs = this.bugs.filter((b) => !b.gone);
      return;
    }
    this.time += h;
    if (this.phase === 'playing' && this.opts.waves) {
      while (this.time >= this.nextWaveAt) this.startWave();
    }
    if (this.phase === 'playing' && this.pending.length > 0) {
      const keep = [];
      for (const p of this.pending) { if (p.at <= this.time) this.spawn(p.spec); else keep.push(p); }
      this.pending = keep;
    }
    for (const b of this.bugs) this.updateBug(b, h);
    this.bugs = this.bugs.filter((b) => !b.gone);
    // R2 hunger (GAME-DESIGN §5): no catching bite for the phase's wilt time wilts a snap; 3 s before, hungry.
    // R4: it ticks only while a catchable bug has landed in the trap and no protected bug has.
    // R6 (#19): in the last light it ticks whatever is in the trap.
    this.hungerLive = this.phase === 'playing' && this.wilts && ((this.lastLight && this.wave >= T.lastLightWave) || this.hungerTicks());
    if (this.hungerLive) {
      const w = wiltSeconds(this.dayPhase);
      this.hunger += h / w;
      if (!this.hungrySent && (1 - this.hunger) * w <= T.hungryWarning) this.hungrySent = true;
      if (this.hunger >= 1) {
        this.hunger = 0; this.hungrySent = false; this.stats.wilts += 1;
        this.snapsLeft = Math.max(this.snapsLeft - 1, 0);
        if (this.snapsLeft === 0) this.becomeTired();
      }
    }
    if (this.level && this.phase === 'playing') this.checkLevel(h);
    if (this.phase === 'tired') {
      this.tiredElapsed += h;
      if (this.tiredElapsed >= T.tiredSeconds) this.phase = 'finished';
    }
  }
  // R4 (QA-2 #1, REVIEW-3 #12): food in the trap (a landed catchable bug) and no protected bug in it.
  // R5 (REVIEW-4 #5, founder call): a protected bug is in it from its final approach: in the zone and landed, or below
  // creaseAirHeight (the hover down, halo drawn).
  hungerTicks() {
    let food = false;
    for (const b of this.bugs) {
      if (!this.inTrap(b)) continue;
      if (isProtected(b.species)) { if (b.landed || b.height < T.creaseAirHeight) return false; }
      else if (b.landed) food = true;
    }
    return food;
  }
  becomeTired() {
    this.phase = 'tired'; this.tiredElapsed = 0; this.tiredAt = this.time; this.pending = [];
    for (const b of this.bugs) { if (b.mode === M.caught || b.mode === M.leave || b.mode === M.escape || b.mode === M.release) continue; this.takeOff(b, M.leave); }
  }
  startWave() {
    this.wave += 1;
    const idx = this.wave;
    if (idx > 1 && (idx - 1) % T.nectarReseedWaves === 0) this.installNectar(Math.floor((idx - 1) / T.nectarReseedWaves));
    const recipe = this.mode === 'attract' ? ((idx - 1) % (T.nightWave + 5)) + 1 : (this.mode === 'zen' ? ((idx - 1) % T.zenDayWaves) + 1 : idx);
    const spec = makeWave(this.seed, recipe, this.g, this.nectar, this.calm);
    this.dayPhase = spec.phase;
    const at = this.nextWaveAt;
    for (const s of spec.bugs) this.pending.push({ at: at + s.groupOffset, spec: s });
    this.lastWaveAt = at;
    let gap = waveDelay(this.seed, recipe + 1);
    if (this.calm && idx <= T.firstRunCalmWaves) gap *= T.firstRunWaveGap; // R4/R5: the calm morning (Sprout runs 1-3)
    this.nextWaveAt = at + gap;
  }
  bugSeed(id) { return u64(this.seed ^ u64(BigInt(id) * 0xA24BAED4963EE407n) ^ 0x42554753n); }
  spawn(spec) {
    if (this.bugs.length >= T.maxBugsOnScreen) return -1;
    const id = this.nextID; this.nextID += 1;
    const inf = info(spec.species), m = motion(spec.species);
    const b = {
      id, species: spec.species, info: inf, m, rng: new SeededRandom(this.bugSeed(id)),
      x: spec.entry.x, y: spec.entry.y, heading: 0, height: m.style === WALKER ? 0 : 1, activity: m.style === WALKER ? A_WALK : A_ARR,
      mode: M.approach, fx: spec.entry.x, fy: spec.entry.y, tx: spec.target.x, ty: spec.target.y, cx: 0, cy: 0,
      el: 0, dur: 1, age: 0, timer: 0, linger: spec.linger, lingerTotal: spec.linger, landsInTrap: spec.landsInTrap,
      dropID: null, wantsNectar: false, homeX: spec.target.x, homeY: spec.target.y, wobblePhase: 0, landed: false,
      landedInTrap: false, sparedSent: false, hovering: false, restless: 0, sip: 0, gone: false, leavingKind: 0,
      startledAt: null,
    };
    b.wobblePhase = b.rng.range(0, 2 * Math.PI);
    const bend = b.rng.range(-T.arcBend, T.arcBend);
    if (!spec.landsInTrap && !this.g.contains(spec.target) && spec.linger === 0) {
      b.mode = M.cross;
    } else if (spec.landsInTrap) {
      const d = m.nectarChance > 0 ? this.dropAt(spec.target) : null;
      if (d !== null && !this.reservedBy.has(d.id)) {
        this.reservedBy.set(d.id, id); b.dropID = d.id; b.wantsNectar = true;
      } else {
        if (d !== null) b.wantsNectar = true;
        const spot = this.findSpot(b, spec.target.x, spec.target.y, d !== null ? 30 : 0, d !== null ? 70 : 40, T.landMaxRadius);
        b.tx = spot.x; b.ty = spot.y;
      }
      b.homeX = b.tx; b.homeY = b.ty;
      // R4 (REVIEW-3 #14): a walker walks in on its spot's side of the crease (it never crosses it on foot)
      if (m.style === WALKER) {
        const sd = this.sideOf(b.tx), gap = creaseGap(inf.radius);
        const off = (b.fx - this.g.cx) * sd;
        if (off < gap) { b.fx = this.g.cx + sd * Math.max(Math.abs(b.fx - this.g.cx), gap); b.x = b.fx; }
      }
    }
    const dx = b.tx - b.fx, dy = b.ty - b.fy;
    const dist = Math.hypot(dx, dy);
    b.cx = (b.fx + b.tx) / 2 - dy * bend; b.cy = (b.fy + b.ty) / 2 + dx * bend;
    if (m.style === WALKER) {
      b.mode = M.dash; b.dur = Math.max(0.1, dist / m.walkSpeed);
    } else {
      b.dur = Math.max(T.minFlightTime, dist * T.approachPathFactor / m.speed);
    }
    b.heading = Math.atan2(dy, dx);
    this.bugs.push(b);
    return id;
  }
  spawnScripted(species, entry, target, linger) {
    return this.spawn({ species, entry, target, linger, landsInTrap: true, groupOffset: 0 });
  }
  spotOf(o) {
    switch (o.mode) {
      case M.approach: case M.hover: case M.dash: case M.hop: return { x: o.tx, y: o.ty };
      case M.sip: case M.pause: return { x: o.x, y: o.y };
      default: return null;
    }
  }
  spotScore(b, p) {
    let worst = Infinity;
    for (const o of this.bugs) {
      if (o.id === b.id || !o.landsInTrap) continue;
      const q = this.spotOf(o); if (q === null) continue;
      const need = b.info.radius + o.info.radius + T.landSpacing;
      worst = Math.min(worst, Math.hypot(q.x - p.x, q.y - p.y) - need);
    }
    return worst;
  }
  sideOf(x) { return x >= this.g.cx ? 1 : -1; }
  // R4: side +1 / -1 keeps the spot on that lobe (a point across the line is mirrored back first); 0 leaves it free.
  clampIn(p0, maxR, radius, side) {
    const p = side && (p0.x - this.g.cx) * side < 0 ? { x: 2 * this.g.cx - p0.x, y: p0.y } : p0;
    const r = this.g.nr(p);
    let q = p;
    if (r > maxR && r !== 0) { const k = maxR / r; q = { x: this.g.cx + (p.x - this.g.cx) * k, y: this.g.cy + (p.y - this.g.cy) * k }; }
    // R3 (REVIEW-2 #5): never rest on the crease
    return offCrease(this.g, q, maxR, radius, side);
  }
  findSpot(b, x, y, dMin, dMax, maxR, side) {
    let best = this.clampIn({ x, y }, maxR, b.info.radius, side);
    let bestScore = dMin <= 0 ? this.spotScore(b, best) : -Infinity;
    if (bestScore >= 0) return best;
    for (let i = 0; i < T.spotTries; i++) {
      const t = b.rng.range(0, 2 * Math.PI);
      // R2: the search reaches at least this bug's own spacing need (radii are x1.8)
      const dd = b.rng.range(Math.max(dMin, 8), Math.max(dMax, 20, b.info.radius * 2 + T.landSpacing + 10));
      const p = this.clampIn({ x: x + Math.cos(t) * dd, y: y + Math.sin(t) * dd }, maxR, b.info.radius, side);
      const s = this.spotScore(b, p);
      if (s > bestScore) { bestScore = s; best = p; }
      if (s >= 0) break;
    }
    return best;
  }
  activityOf(b) {
    switch (b.mode) {
      case M.approach: return b.m.style === WALKER ? A_WALK : A_ARR;
      case M.hover: case M.cross: return A_ARR;
      case M.sip: return A_SIP;
      case M.pause: return b.hovering ? A_ARR : A_WALK;
      case M.dash: return A_WALK;
      case M.hop: return A_HOP;
      case M.leave: return b.m.style === WALKER ? A_WALK : A_LEAVE;
      case M.escape: return A_ESC;
      case M.release: return A_REL;
      default: return A_CAUGHT;
    }
  }
  inTrap(b) {
    const a = this.activityOf(b);
    if (a === A_LEAVE || a === A_CAUGHT || a === A_ESC || a === A_REL) return false;
    return this.g.contains(b);
  }
  updateBug(b, h) {
    b.age += h;
    const px = b.x, py = b.y;
    switch (b.mode) {
      case M.approach: case M.cross: {
        b.el += h;
        const u = Math.min(1, b.el / b.dur);
        const s = 1 - (1 - u) * (1 - u);
        const bx = (1 - s) * (1 - s) * b.fx + 2 * (1 - s) * s * b.cx + s * s * b.tx;
        const by = (1 - s) * (1 - s) * b.fy + 2 * (1 - s) * s * b.cy + s * s * b.ty;
        const dx = b.tx - b.fx, dy = b.ty - b.fy; const L = Math.max(1, Math.hypot(dx, dy));
        const w = b.m.wobbleAmp * Math.sin(2 * Math.PI * b.m.wobbleHz * b.age + b.wobblePhase) * (1 - s);
        b.x = bx + (-dy / L) * w; b.y = by + (dx / L) * w;
        if (b.mode === M.cross) b.height = T.crossHeight;
        else if (b.m.style === WALKER) b.height = 0;
        else b.height = 1 - T.approachHeightDrop * s * s;
        if (u >= 1) {
          if (b.mode === M.cross) { b.gone = true; break; }
          if (b.m.style === WALKER) { this.land(b); break; }
          const sp = this.landsSpot(b);
          b.tx = sp.x; b.ty = sp.y;
          b.mode = M.hover; b.el = 0; b.dur = b.rng.range(T.hoverMin, T.hoverMax);
          b.fx = b.x; b.fy = b.y;
        }
        break;
      }
      case M.hover: {
        b.el += h;
        const v = Math.min(1, b.el / b.dur);
        const om = 2 * Math.PI * 1.5 * b.age;
        const ex = b.fx + (b.tx - b.fx) * v, ey = b.fy + (b.ty - b.fy) * v;
        b.x = ex + Math.cos(om) * T.hoverCircle * (1 - v); b.y = ey + Math.sin(om) * T.hoverCircle * (1 - v);
        b.height = T.hoverHeight * (1 - v);
        if (v >= 1) this.land(b);
        break;
      }
      case M.sip: {
        this.tickLinger(b, h);
        if (b.mode !== M.sip) break;
        b.sip = isFinite(b.lingerTotal) && b.lingerTotal > 0 ? Math.min(1, 1 - b.linger / b.lingerTotal) : 0;
        break;
      }
      case M.pause: {
        this.tickLinger(b, h);
        if (b.mode !== M.pause) break;
        b.timer -= h;
        if (b.timer <= 0) this.nextGroundMove(b);
        break;
      }
      case M.dash: {
        if (b.landed) { this.tickLinger(b, h); if (b.mode !== M.dash) break; }
        b.el += h;
        const u = Math.min(1, b.el / b.dur);
        const e = b.landed ? u * u * (3 - 2 * u) : u;
        const dx = b.tx - b.fx, dy = b.ty - b.fy; const L = Math.max(1, Math.hypot(dx, dy));
        const w = b.m.style === WALKER ? b.m.wobbleAmp * Math.sin(2 * Math.PI * b.m.wobbleHz * b.age + b.wobblePhase) : 0;
        b.x = b.fx + dx * e + (-dy / L) * w; b.y = b.fy + dy * e + (dx / L) * w;
        b.height = 0;
        if (u >= 1) {
          if (!b.landed) { this.land(b); break; }
          if (b.dropID !== null && this.reservedBy.get(b.dropID) === b.id && this.isAtDrop(b)) this.startSip(b);
          else this.startPause(b);
        }
        break;
      }
      case M.hop: {
        this.tickLinger(b, h);
        if (b.mode !== M.hop) break;
        b.el += h;
        const u = Math.min(1, b.el / b.dur);
        b.x = b.fx + (b.tx - b.fx) * u; b.y = b.fy + (b.ty - b.fy) * u;
        b.height = (b.m.style === DARTER ? T.dartHeight : T.hopHeight) * Math.sin(Math.PI * u);
        if (b.m.style === DARTER) b.height = T.dartHeight;
        if (u >= 1) { b.height = b.m.style === DARTER ? T.dartHeight : 0; this.startPause(b); }
        break;
      }
      case M.leave: case M.escape: case M.release: {
        b.el += h;
        const walker = b.m.style === WALKER;
        const factor = b.mode === M.leave ? T.leaveSpeedFactor : (b.mode === M.escape ? (walker ? T.walkerEscapeFactor : T.escapeSpeedFactor) : T.releaseSpeedFactor);
        const speed = (walker ? b.m.walkSpeed : b.m.speed) * factor;
        const ramp = walker ? 1 : Math.min(1, 0.3 + b.el / T.takeoffTime);
        const dx = b.tx - b.fx, dy = b.ty - b.fy; const L = Math.max(1, Math.hypot(dx, dy));
        b.dur += speed * ramp * h; // dur = distance travelled
        const tr = Math.min(b.dur, L);
        const w = walker ? 0 : b.m.wobbleAmp * 0.5 * Math.sin(2 * Math.PI * b.m.wobbleHz * b.age + b.wobblePhase) * Math.min(1, b.el / T.takeoffTime);
        b.x = b.fx + dx / L * tr + (-dy / L) * w; b.y = b.fy + dy / L * tr + (dx / L) * w;
        b.height = walker ? 0 : Math.min(1, b.timer + b.el / T.takeoffTime * (1 - b.timer));
        if (b.dur >= L || this.offscreen(b)) b.gone = true;
        break;
      }
      case M.caught: {
        b.el += h;
        const u = Math.min(1, b.el / T.caughtSeconds);
        const e = u * u * (3 - 2 * u);
        b.x = b.fx + (this.g.cx - b.fx) * e; b.y = b.fy;
        b.height = b.timer * (1 - e); // R2 (QA-1 #21): eases down from the height it was caught at
        if (b.el >= T.caughtSeconds) b.gone = true;
        break;
      }
    }
    const mx = b.x - px, my = b.y - py;
    if (mx * mx + my * my > 0.01 && b.mode !== M.caught) b.heading = Math.atan2(my, mx);
  }
  offscreen(b) { return b.x < -T.exitMargin - 20 || b.x > this.g.w + T.exitMargin + 20 || b.y < -T.exitMargin - 20 || b.y > this.g.h + T.exitMargin + 20; }
  isAtDrop(b) {
    for (const d of this.nectar) if (d.id === b.dropID) return Math.hypot(d.x - b.x, d.y - b.y) <= 2;
    return false;
  }
  landsSpot(b) {
    // re-check the spacing just before landing (others may have landed since the spawn)
    if (!b.landsInTrap) return { x: b.tx, y: b.ty };
    if (b.dropID !== null) return { x: b.tx, y: b.ty };
    if (this.spotScore(b, { x: b.tx, y: b.ty }) >= 0) return { x: b.tx, y: b.ty };
    return this.findSpot(b, b.tx, b.ty, 0, 50, T.landMaxRadius, this.sideOf(b.tx));
  }
  tickLinger(b, h) {
    if (isFinite(b.linger)) {
      b.linger -= h;
      const f = b.lingerTotal > 0 ? 1 - b.linger / b.lingerTotal : 1;
      b.restless = Math.max(b.restless * Math.exp(-3 * h), clamp((f - T.restlessFrom) / (1 - T.restlessFrom), 0, 1));
      if (b.linger <= 0) { this.takeOff(b, M.leave); }
    } else {
      b.restless = b.restless * Math.exp(-3 * h);
    }
  }
  land(b) {
    b.landed = true; b.height = 0; b.el = 0;
    b.landedInTrap = b.landsInTrap && this.g.contains(b);
    if (!b.landsInTrap) { this.startPause(b); return; }
    if (b.m.style === DARTER) { this.startPause(b); return; }
    if (b.dropID !== null && this.isAtDrop(b)) { this.startSip(b); return; }
    this.startPause(b);
  }
  startSip(b) { b.mode = M.sip; b.hovering = false; b.height = 0; }
  startPause(b) {
    b.mode = M.pause; b.el = 0;
    b.timer = b.rng.range(b.m.pauseMin, b.m.pauseMax);
    b.hovering = b.m.style === DARTER && b.rng.chance(T.darterHoverChance);
    b.height = b.hovering ? T.dartHeight : 0;
  }
  nextGroundMove(b) {
    if (!b.landsInTrap) { this.startPause(b); return; }
    const st = b.m.style;
    if (st === HOPPER || st === DARTER) {
      const darter = st === DARTER;
      const t = b.rng.range(0, 2 * Math.PI);
      const dd = darter ? b.rng.range(T.dartMin, T.dartMax) : b.rng.range(T.hopMin, T.hopMax);
      const want = { x: b.x + Math.cos(t) * dd, y: b.y + Math.sin(t) * dd };
      const p = this.findSpot(b, want.x, want.y, 0, 40, T.landMaxRadius, this.sideOf(b.x));
      b.mode = M.hop; b.fx = b.x; b.fy = b.y; b.tx = p.x; b.ty = p.y; b.el = 0; b.hovering = false;
      const dist = Math.hypot(p.x - b.x, p.y - b.y);
      b.dur = darter ? T.dartTime : clamp(dist / T.hopSpeed, T.hopTimeMin, T.hopTimeMax);
      return;
    }
    if (b.wantsNectar && b.dropID === null) {
      let best = null, bd = T.nectarSeekRadius;
      for (const d of this.nectar) {
        if (this.retiring.has(d.id) || this.reservedBy.has(d.id)) continue;
        if (this.sideOf(d.x) !== this.sideOf(b.x)) continue; // R4: never a walk across the crease
        const dd = Math.hypot(d.x - b.x, d.y - b.y);
        if (dd < bd) { bd = dd; best = d; }
      }
      if (best !== null) {
        this.reservedBy.set(best.id, b.id); b.dropID = best.id;
        this.startDash(b, best.x, best.y);
        return;
      }
    }
    const t = b.rng.range(0, 2 * Math.PI);
    const dd = b.rng.range(T.wanderMin, T.wanderMax);
    const want = { x: b.homeX + Math.cos(t) * dd, y: b.homeY + Math.sin(t) * dd };
    const p = this.findSpot(b, want.x, want.y, 0, 30, T.landMaxRadius, this.sideOf(b.x));
    this.startDash(b, p.x, p.y);
  }
  startDash(b, x, y) {
    b.mode = M.dash; b.fx = b.x; b.fy = b.y; b.tx = x; b.ty = y; b.el = 0; b.hovering = false;
    const dist = Math.hypot(x - b.x, y - b.y);
    b.dur = Math.max(0.15, dist / Math.max(1, b.m.walkSpeed));
  }
  takeOff(b, kind) {
    this.freeDrop(b);
    if ((kind === M.leave || kind === M.escape) && isProtected(b.species) && b.landedInTrap && !b.sparedSent) {
      b.sparedSent = true; this.stats.spared += 1;
    }
    const W = this.g.w, H = this.g.h;
    const dl = b.x, dr = W - b.x, db = b.y, dtp = H - b.y;
    let ex = b.x, ey = b.y;
    const walker = b.m.style === WALKER;
    const mn = walker ? Math.min(dl, dr, db) : Math.min(dl, dr, db, dtp);
    if (mn === dl) ex = -T.exitMargin; else if (mn === dr) ex = W + T.exitMargin; else if (mn === db) ey = -T.exitMargin; else ey = H + T.exitMargin;
    b.timer = b.height; // start height for the climb
    b.mode = kind; b.fx = b.x; b.fy = b.y; b.tx = ex; b.ty = ey; b.el = 0; b.dur = 0; b.hovering = false; b.sip = 0;
  }
  // R8 (§1): the bite at the shut. A bug still in the trap is caught unless it has been fleeing longer than its
  // reaction time: its exposure is the larger of the real one (since it startled in this close) and the modelled one.
  bite(snap, armedAfter) {
    const d = isFinite(snap.duration) ? Math.max(0, snap.duration) : 0;
    const now = this.time;
    const caught = [], stingers = []; let escaped = this.fled;
    for (const b of this.bugs) {
      if (!this.inTrap(b)) continue;
      const a = this.activityOf(b);
      const flying = a === A_ARR || a === A_HOP;
      if (a === A_ARR && b.height >= T.catchableHeight) continue;
      if (!(a === A_ARR || a === A_WALK || a === A_SIP || a === A_HOP)) continue;
      if (!isProtected(b.species)) this.closeBugs.add(b.id);
      let expo = modelExposure(b.info.nerve, d);
      if (b.startledAt != null) expo = Math.max(expo, now - b.startledAt);
      const r = reaction(b.info, a === A_SIP, flying, onRimBody(this.g, b, b.info.radius), paceWave(this.wave, this.mode), this.reactionScale);
      if (expo <= r) {
        if (isProtected(b.species)) { stingers.push(b.species); this.takeOff(b, M.release); }
        else { caught.push(b.species); this.freeDrop(b); b.timer = b.height; b.mode = M.caught; b.el = 0; b.fx = b.x; b.fy = b.y; }
      } else {
        escaped += 1; this.takeOff(b, M.escape);
      }
    }
    for (const b of this.bugs) b.startledAt = null;
    const denom = this.closeBugs.size;
    const ratio = denom > 0 ? Math.min(1, caught.length / denom) : 0;
    this.stats.escapes = (this.stats.escapes || 0) + escaped;
    if (denom > 0) { this.stats.ratioSum += ratio; this.stats.ratioN += 1; if (this.wave < T.duskWave) { this.stats.dayRatioSum += ratio; this.stats.dayRatioN += 1; } }
    this.closing = false; this.fled = 0; this.closeBugs = new Set();
    this.shut = !armedAfter;
    this.stats.snaps += 1;
    // R2/R4: a catch feeds the trap (the clock then waits for food again)
    if (caught.length >= 1) { this.hunger = 0; this.hungrySent = false; }
    const n = caught.length;
    const stung = stingers.length > 0;
    let sum = 0; for (const s of caught) sum += info(s).points;
    // R3 (REVIEW-2 #8): a bite with a stinger in it scores x1 and refunds nothing (the sting cost stays)
    const mult = stung ? 1 : chainMultiplier(this.chain);
    // R7 (#3, founder call): a clean bite of >= bigFeastCount scores x feastMultiplier (TrapRules.feastBonus)
    const feastX = (!stung && n >= T.bigFeastCount) ? T.feastMultiplier : 1;
    const points = Math.round(sum * n * mult * feastX);
    let back = 0;
    if (!stung) {
      if (n >= T.bigFeastCount) back += T.bigFeastRefund; else if (n >= T.feastCount) back += T.feastRefund;
      for (const s of caught) { if (s === 'goldenScarab') back += T.scarabRefund; if (s === 'ladybird') back += T.ladybirdRefund; }
    }
    if (this.opts.refunds === false) back = 0;
    for (const sp of caught) this.bySpecies[sp] = (this.bySpecies[sp] || 0) + 1;
    let lost = 0;
    if (this.opts.stingCosts) for (const s of stingers) lost += s === 'wasp' ? T.waspCost : T.beeCost;
    // R3 (REVIEW-2 #9): Sprout run 1's first stinger bite costs no extra snap ("Bees cost a snap!")
    if (stung && this.freeSting && !this.freeStingUsed) { this.freeStingUsed = true; lost = 0; }
    this.score += points;
    this.stats.caught += n; this.stats.stings += stingers.length;
    if (n >= T.feastCount && !stung) this.stats.feasts += 1;
    if (n === 0 && stingers.length === 0) this.stats.dry += 1;
    this.stats.bestBite = Math.max(this.stats.bestBite, points); this.stats.biggest = Math.max(this.stats.biggest, n);
    // R2 chain rule: a clean bite of >= 2 adds a step, a clean 1-bug bite holds it, a dry snap or a stinger breaks it.
    // R8 (§2): a bite that let a bug escape breaks the chain too (missBreaksChain)
    const missed = T.missBreaksChain && escaped > 0;
    if (n >= T.chainMinBite && stingers.length === 0 && !missed) { this.chain += 1; this.stats.longestChain = Math.max(this.stats.longestChain, this.chain); }
    else if (!(n >= 1 && stingers.length === 0) || missed) this.chain = 0;
    // R8 (§2): a dry bite (nothing caught, no stinger) costs dryBiteCost more
    const dryCost = (n === 0 && stingers.length === 0) ? T.dryBiteCost : 0;
    if (this.opts.snapsRunOut) {
      this.snapsLeft = clamp(this.snapsLeft - T.snapCost - lost - dryCost + back, 0, T.maxSnaps);
      if (this.snapsLeft === 0) this.becomeTired();
    }
    if (this.debug) console.log(`  bite t=${now.toFixed(2)} d=${d.toFixed(2)} caught=${caught.join(',') || '-'} stung=${stingers.join(',') || '-'} escaped=${escaped} left=${this.snapsLeft}`);
    if (this.level && this.phase === 'playing') this.checkLevel(0);
  }
  // R8 (ROUND-8 §4, LevelBook in TrapSession.swift): a level ends at once when its goal is met or a bee is bitten in a
  // no-sting level; when its time is up; and when nothing is left to catch for levelIdleEnd s. Out of bites: tired.
  goalMet() { return levelGoalMet(this.goal, { caught: this.stats.caught, bySpecies: this.bySpecies, biggest: this.stats.biggest, spared: this.stats.spared }); }
  checkLevel(h) {
    const L = this.level;
    if (L.noSting && this.stats.stings > 0) { this.levelEnd = 'stung'; this.becomeTired(); return; }
    if (this.goalMet()) { this.levelEnd = 'goal'; this.becomeTired(); return; }
    if (L.time != null && this.time >= L.time) { this.levelEnd = 'time'; this.becomeTired(); return; }
    let active = this.pending.length > 0;
    for (const b of this.bugs) if (!(b.mode === M.leave || b.mode === M.escape || b.mode === M.release || b.mode === M.caught || b.mode === M.cross)) active = true;
    if (active) this.idleFor = 0; else { this.idleFor += h; if (this.idleFor >= T.levelIdleEnd) { this.levelEnd = 'empty'; this.becomeTired(); } }
  }
  snapshot() {
    const bugs = this.bugs.map((b) => {
      const a = this.activityOf(b);
      const inT = this.inTrap(b);
      return { id: b.id, species: b.species, x: b.x, y: b.y, activity: a, height: b.height, inTrap: inT, onRim: inT && onRimBody(this.g, b, b.info.radius), restless: b.restless };
    });
    return { phase: this.phase, mode: this.mode, time: this.time, bugs, snapsLeft: this.snapsLeft, wave: this.wave, score: this.score, hunger: this.hunger, dayPhase: this.dayPhase, shut: this.shut, reactionScale: this.reactionScale };
  }
}

// MARK: TrapPilot (R8: mirror of Snap/Core/TrapPilot.swift)
// R8 (ROUND-8 §1, §2): the pilot closes the whole phone. Its angle is pilotIdleAngle - closure; a close runs at a steady
// rate so the closeStart -> shut stretch (the detector's SnapTrigger.duration) takes exactly the planned close time,
// on to pilotShutAngle, holds shut, and reopens over the reopen time (re-armed at armAngle, idle at the top).
// close times by skill (ROUND-8 §2): novice 0.6-1.1 s, casual 0.35-0.65 s, expert 0.2-0.35 s; perfect 0.18 s.
const PROFILE = {
  novice: { closeMin: 0.6, closeMax: 1.1, delayMin: 0.35, delayMax: 0.6, holdMin: 0.3, holdMax: 0.6, reopenMin: 0.6, reopenMax: 0.8, beeMiss: T.noviceBeeMiss },
  casual: { closeMin: 0.35, closeMax: 0.65, delayMin: 0.25, delayMax: 0.45, holdMin: 0.2, holdMax: 0.4, reopenMin: 0.5, reopenMax: 0.7, beeMiss: T.casualBeeMiss },
  expert: { closeMin: 0.2, closeMax: 0.35, delayMin: 0.15, delayMax: 0.3, holdMin: 0.15, holdMax: 0.3, reopenMin: 0.4, reopenMax: 0.6, beeMiss: T.expertBeeMiss },
  perfect: { closeMin: 0.18, closeMax: 0.18, delayMin: 0.1, delayMax: 0.1, holdMin: 0.15, holdMax: 0.15, reopenMin: 0.4, reopenMax: 0.4, beeMiss: 0 },
};
function pick2(rng, lo, hi) { return lo === hi ? lo : rng.range(lo, hi); }
const P_IDLE = 0, P_DOWN = 1, P_HOLD = 2, P_UP = 3, P_SHOO = 4, P_SHOO_HOLD = 5;
class Pilot {
  // R5 (REVIEW-4 P2): giveUp false switches off the pilotGiveUp rule (TrapPilot.givesUp), for the SNAP-BAL report only.
  constructor(skill, seed, giveUp) {
    this.skill = skill; this.p = PROFILE[skill]; this.rng = new SeededRandom(seed); this.giveUp = giveUp !== false;
    this.stage = P_IDLE;
    this.closure = 0; this.armed = true; this.el = 0; this.d = 0.3; this.hold = 0.2; this.reopen = 0.5; this.peak = 0;
    this.tStart = null; this.closeSince = null; this.decideAt = null; this.beeSince = null; this.missed = new Map();
    this.lastSnap = 0; this.plannedD = this.p.closeMin;
    this.minBite = 0; // R8: a level goal of one bite of n (TrapPilot.minBite): wait for n, never bite fewer
    this.targets = []; // R8: a level goal's species (TrapPilot.targets): one of them landed / catchable is worth a bite
    this.clock = 0; // R3 (REVIEW-2 #21): the pilot's own clock (the sum of its dt), never the caller's time
  }
  static shutClosure() { return T.pilotIdleAngle - T.shutAngle; }
  static fullClosure() { return T.pilotIdleAngle - T.pilotShutAngle; }
  static armClosure() { return T.pilotIdleAngle - T.armAngle; }
  planDuration() { return pick2(this.rng, this.p.closeMin, this.p.closeMax); }
  // R9 (TrapPilot.drawFirstClose): the first close is drawn like every other, not the profile's fastest (the default
  // keeps closeMin, which the CI demo runs depend on). The level table uses it: a level's 3 stars often hang on its
  // first bite.
  drawFirstClose() { this.plannedD = this.planDuration(); }
  // A protected bug sitting in the trap (landed): what a shoo can clear.
  beeSitting(snap) {
    for (const b of snap.bugs) {
      if (!isProtected(b.species) || !b.inTrap) continue;
      if (b.activity === A_WALK || b.activity === A_SIP) return true;
    }
    return false;
  }
  beeBlocks(snap) {
    for (const b of snap.bugs) {
      if (!isProtected(b.species)) continue;
      const a = b.activity;
      if (this.skill === 'perfect') {
        // perfect sees a bee coming: anything in the trap that is landed, hopping or flying lowish
        if (b.inTrap && (a === A_WALK || a === A_SIP || a === A_HOP || (a === A_ARR && b.height < T.perfectBeeHeight))) return true;
        continue;
      }
      if (!b.inTrap) continue;
      if (!(a === A_WALK || a === A_SIP || a === A_HOP || (a === A_ARR && b.height < 0.75))) continue;
      if (!this.missed.has(b.id)) this.missed.set(b.id, this.rng.chance(this.p.beeMiss));
      if (!this.missed.get(b.id)) return true;
    }
    return false;
  }
  // R8: a bug counts as catchable when the planned close's modelled exposure is within its reaction time.
  view(snap, d) {
    let landed = 0, maxPts = 0, n = 0, sum = 0, arriving = 0, restless = 0;
    for (const b of snap.bugs) {
      if (isProtected(b.species)) continue;
      const a = b.activity;
      if (!b.inTrap) continue;
      const inf = info(b.species);
      if (a === A_WALK || a === A_SIP) { landed += 1; maxPts = Math.max(maxPts, inf.points); restless = Math.max(restless, b.restless); }
      if (a === A_ARR && b.height >= T.catchableHeight) { arriving += 1; continue; }
      if (!(a === A_ARR || a === A_WALK || a === A_SIP || a === A_HOP)) continue;
      if (a === A_ARR) arriving += 1;
      const r = reaction(inf, a === A_SIP, a === A_ARR || a === A_HOP, b.onRim, paceWave(snap.wave, snap.mode), snap.reactionScale);
      if (modelExposure(inf.nerve, d) <= r) { n += 1; sum += inf.points; }
    }
    return { landed, maxPts, n, value: sum * n, arriving, restless, target: this.targetView(snap, d) };
  }
  // R8: how many target-species bugs are landed (novice, casual) or catchable at d (expert, perfect)
  targetView(snap, d) {
    if (this.targets.length === 0) return 0;
    let k = 0;
    for (const b of snap.bugs) {
      if (!b.inTrap || !this.targets.includes(b.species)) continue;
      const a = b.activity;
      if (this.skill === 'novice' || this.skill === 'casual') { if (a === A_WALK || a === A_SIP) k += 1; continue; }
      if (a === A_ARR && b.height >= T.catchableHeight) continue;
      if (!(a === A_ARR || a === A_WALK || a === A_SIP || a === A_HOP)) continue;
      const inf = info(b.species);
      const r = reaction(inf, a === A_SIP, a === A_ARR || a === A_HOP, b.onRim, paceWave(snap.wave, snap.mode), snap.reactionScale);
      if (modelExposure(inf.nerve, d) <= r) k += 1;
    }
    return k;
  }
  wants(snap, time) {
    const v = this.view(snap, this.plannedD);
    const waited = time - this.lastSnap;
    let want = false;
    if (this.minBite > 0) {
      const count = (this.skill === 'novice' || this.skill === 'casual') ? v.landed : v.n;
      if (count < this.minBite) return false;
      return !this.beeBlocks(snap);
    }
    if (v.target >= 1) return !this.beeBlocks(snap);
    switch (this.skill) {
      case 'novice': want = v.landed >= 2 || (v.landed >= 1 && waited >= T.novicePatience); break;
      case 'casual': want = v.landed >= 3 || (v.landed >= 2 && v.arriving === 0) || (v.landed >= 1 && v.maxPts >= 20) || (v.landed >= 1 && waited >= T.casualPatience); break;
      case 'expert': want = v.n >= 3 || (v.n >= 1 && v.value >= T.expertValue) || (v.n >= 2 && v.restless >= T.expertRestless) || (v.n >= 1 && waited >= T.expertPatience) || (this.giveUp && v.landed >= 1 && waited >= T.pilotGiveUp); break;
      default: want = v.n >= 5 || (v.n >= 3 && v.arriving === 0) || (v.n >= 3 && v.restless >= T.perfectRestless) || v.value >= T.perfectValue || (v.n >= 1 && waited >= T.perfectPatience) || (this.giveUp && v.landed >= 1 && waited >= T.pilotGiveUp); break;
    }
    if (!want) return false;
    return !this.beeBlocks(snap);
  }
  step(dt, callerTime, snap) {
    // R3 (REVIEW-2 #21): decisions run on the pilot's own clock, so the same seed and dt give the same run
    const time = this.clock;
    this.clock += dt;
    let fired = null;
    const prev = this.closure;
    if (this.stage === P_IDLE) {
      this.closure = 0;
      if (snap.phase === 'playing' && this.armed) {
        // shoo: expert / perfect clear a bee that has sat in the trap too long with a partial close (no bite)
        const shooAfter = this.skill === 'perfect' ? T.perfectShooAfter : (this.skill === 'expert' ? T.expertShooAfter : 0);
        if (this.beeSitting(snap)) { if (this.beeSince === null) this.beeSince = time; } else this.beeSince = null;
        if (shooAfter > 0 && this.beeSince !== null && time - this.beeSince >= shooAfter) {
          this.stage = P_SHOO; this.el = 0; this.decideAt = null; this.beeSince = null;
        } else if (this.decideAt === null) {
          if (this.wants(snap, time)) this.decideAt = time + pick2(this.rng, this.p.delayMin, this.p.delayMax);
        } else if (time >= this.decideAt) {
          this.decideAt = null;
          if (this.wants(snap, time)) {
            this.stage = P_DOWN; this.el = 0; this.d = this.plannedD; this.tStart = null;
            this.hold = pick2(this.rng, this.p.holdMin, this.p.holdMax);
            this.reopen = pick2(this.rng, this.p.reopenMin, this.p.reopenMax);
            this.plannedD = this.planDuration();
          }
        }
      }
    } else if (this.stage === P_SHOO) {
      this.el += dt;
      this.closure = Math.min(T.shooDepth, T.shooDepth * this.el / T.shooTime);
      if (this.el >= T.shooTime) { this.stage = P_SHOO_HOLD; this.el = 0; }
    } else if (this.stage === P_SHOO_HOLD) {
      this.el += dt;
      if (!this.beeSitting(snap) || this.el >= T.shooHoldMax) {
        this.stage = P_UP; this.el = 0; this.peak = this.closure; this.reopen = pick2(this.rng, this.p.reopenMin, this.p.reopenMax);
      }
    } else if (this.stage === P_DOWN) {
      this.el += dt;
      const rate = (Pilot.shutClosure() - T.closeStart) / Math.max(1e-6, this.d);
      this.closure = Math.min(Pilot.fullClosure(), this.closure + rate * dt);
      if (this.tStart === null && this.closure >= T.closeStart) this.tStart = crossing(time - dt, prev, time, this.closure, T.closeStart);
      if (this.armed && this.closure >= Pilot.shutClosure()) {
        const tShut = crossing(time - dt, prev, time, this.closure, Pilot.shutClosure());
        fired = { duration: Math.max(0, tShut - (this.tStart === null ? tShut : this.tStart)), time };
        this.armed = false; this.lastSnap = time;
      }
      if (this.closure >= Pilot.fullClosure()) { this.stage = P_HOLD; this.el = 0; }
    } else if (this.stage === P_HOLD) {
      this.el += dt;
      if (this.el >= this.hold) { this.stage = P_UP; this.el = 0; this.peak = this.closure; }
    } else {
      this.el += dt;
      this.closure = Math.max(0, this.peak * (1 - this.el / Math.max(1e-6, this.reopen)));
      if (!this.armed && this.closure <= Pilot.armClosure()) this.armed = true;
      if (this.closure <= 0) { this.stage = P_IDLE; this.closure = 0; this.armed = true; }
    }
    if (this.armed && this.closure >= T.closeStart) { if (this.closeSince === null) this.closeSince = time; } else this.closeSince = null;
    const creeping = this.closeSince !== null && time - this.closeSince > T.slowCloseAfter;
    return { closure: this.closure, armed: this.armed, creeping, snap: fired, angle: T.pilotIdleAngle - this.closure };
  }
}

// MARK: SnapDetector (R8: mirror of Snap/Core/SnapDetector.swift; not used by the balance runs, checked by detector=1)
// The lid is the jaw (ROUND-8 §1 with the founder's binding rules): a shut phone is a closed trap and any opening is
// open. Armed at theta >= armAngle (35); the shut zone is theta <= shutAngle (18), or the hinge status .closed at
// theta <= statusShutAngle (25; hardware reads .closed from ~85). closure = reference - theta, the reference being the
// max theta over refWindow, falling at most refFallRate, held while a close is under way. A close starts at closure
// closeStart and is abandoned under closeCancel or when the phone opens reopenCancel above the close's lowest theta.
// The bite fires once per arm at the shut; duration = shut - close start (untimedCloseDuration when no close start was
// seen: a creep too slow to time is a slow close). requireShut (a round's start): not armed until the phone has been
// shut once and opened again.
const D = { armAngle: T.armAngle, shutAngle: T.shutAngle, closeStart: T.closeStart, closeCancel: T.closeCancel,
  statusShutAngle: 25, refWindow: 0.6, refFallRate: 25, slowCloseAfter: T.slowCloseAfter,
  reopenCancel: T.reopenCancel, untimedCloseDuration: T.untimedCloseDuration,
  // R9 (real hardware, Tuning.rearmRise / startShutAngle): after a shut the re-arm also needs theta >= the lowest theta
  // since that shut + rearmRise; a round's start counts theta <= startShutAngle (any status) as closed
  rearmRise: T.rearmRise, startShutAngle: T.startShutAngle };
class RollingMax {
  constructor(window, fall) { this.window = window; this.fall = fall; this.samples = []; this.value = 0; this.last = 0; }
  reset(t, a) { this.samples = [{ t, a }]; this.value = a; this.last = t; }
  add(t, a, hold) { this.samples.push({ t, a }); this.update(t, hold); }
  update(t, hold) {
    while (this.samples.length > 1 && this.samples[0].t < t - this.window) this.samples.shift();
    let w = -Infinity; for (const s of this.samples) w = Math.max(w, s.a);
    const dt = Math.max(0, t - this.last); this.last = Math.max(this.last, t);
    if (w >= this.value) this.value = w; else if (!hold) this.value = Math.max(w, this.value - this.fall * dt);
  }
}
class SnapDetector {
  constructor(requireShut, rearmLow) {
    this.ref = new RollingMax(D.refWindow, D.refFallRate);
    this.has = false; this.angle = 0; this.lastC = 0; this.prevTime = 0; this.armed = false; this.closing = false;
    this.closeStartAt = 0; this.lowest = 0; this.snapRef = 0; this.pending = null;
    this.waiting = !!requireShut; // a round's start: not armed until shut once
    // R9: the lowest theta since the last shut while unarmed (null: armed, or no shut yet); carried across a restart
    this.rearmLow = (!requireShut && rearmLow != null && isFinite(rearmLow)) ? rearmLow : null;
  }
  rearmAngle() { return this.rearmLow === null ? D.armAngle : Math.max(D.armAngle, this.rearmLow + D.rearmRise); }
  isShutAt(angle, status) { return angle <= D.shutAngle || (status === 'closed' && angle <= D.statusShutAngle); }
  isStartShut(angle, status) { return angle <= D.startShutAngle || this.isShutAt(angle, status); }
  // R9 (SnapDetector.noteFolded): the app is on the outer display: a waiting round counts as closed; else the latest
  // angle again as .closed
  noteFolded(time) {
    if (!this.has || !isFinite(time)) return null;
    if (this.waiting) { this.waiting = false; this.armed = false; this.closing = false; this.rearmLow = this.angle; return null; }
    return this.ingest(this.angle, Math.max(time, this.prevTime), 'closed');
  }
  ingest(angle, time, status) {
    if (!isFinite(angle) || !isFinite(time)) return null;
    if (!this.has) {
      this.has = true; this.ref.reset(time, angle); this.angle = angle; this.lastC = 0; this.prevTime = time;
      const shutNow = this.isShutAt(angle, status);
      if (this.waiting && this.isStartShut(angle, status)) { this.waiting = false; this.rearmLow = angle; }
      else if (!this.waiting && (shutNow || this.rearmLow !== null)) this.rearmLow = Math.min(this.rearmLow === null ? angle : this.rearmLow, angle);
      this.armed = !this.waiting && angle >= this.rearmAngle() && !shutNow;
      if (this.armed) this.rearmLow = null;
      return null;
    }
    const prevAngle = this.angle;
    this.ref.add(time, angle, this.armed && this.closing);
    let c = Math.max(0, this.ref.value - angle);
    let fired = null;
    if (!this.armed) {
      if (this.waiting && this.isStartShut(angle, status)) { this.waiting = false; this.rearmLow = angle; }
      if (this.rearmLow !== null) this.rearmLow = Math.min(this.rearmLow, angle);
      if (!this.waiting && angle >= this.rearmAngle()) { this.armed = true; this.rearmLow = null; this.closing = false; this.ref.reset(time, angle); c = 0; }
    } else {
      if (!this.closing) {
        if (c >= D.closeStart) { this.closing = true; this.lowest = angle; this.closeStartAt = crossing(this.prevTime, this.lastC, time, c, D.closeStart); }
      } else {
        this.lowest = Math.min(this.lowest, angle);
        if (c < D.closeCancel || angle - this.lowest >= D.reopenCancel) {
          // opened again: the close is over, and the reference starts again from here
          this.closing = false; this.ref.reset(time, angle); c = 0;
        }
      }
      if (this.isShutAt(angle, status)) {
        const byAngle = angle <= D.shutAngle;
        const tShut = byAngle && prevAngle > D.shutAngle ? crossing(this.prevTime, -prevAngle, time, -angle, -D.shutAngle) : time;
        const duration = this.closing ? Math.max(0, tShut - this.closeStartAt) : D.untimedCloseDuration;
        fired = { duration, time };
        this.pending = fired; this.armed = false; this.closing = false; this.snapRef = this.ref.value; this.rearmLow = angle;
      }
    }
    this.lastC = c; this.prevTime = time; this.angle = angle;
    return fired;
  }
  input(time) {
    if (this.has && isFinite(time)) this.ref.update(time, this.armed && this.closing);
    let closure = 0;
    if (this.has) closure = this.armed ? Math.max(0, this.ref.value - this.angle) : Math.max(0, this.snapRef - this.angle);
    if (this.has && !this.armed && this.snapRef === 0) closure = 0;
    const creeping = this.has && this.armed && this.closing && time - this.closeStartAt > D.slowCloseAfter;
    const snap = this.pending; this.pending = null;
    return { closure, armed: this.has ? this.armed : true, creeping, snap, tooFlat: false, angle: this.has ? this.angle : null };
  }
}
// detPath(d, from, to, seconds, t0, status): feeds a straight move at 30 Hz
function detPath(d, from, to, seconds, t0, status) {
  const n = Math.max(1, Math.round(seconds * 30)); let fires = 0; const durs = []; let maxC = 0; let creep = false;
  for (let i = 1; i <= n; i++) {
    const t = t0 + i / 30; const a = from + (to - from) * i / n;
    const r = d.ingest(a, t, status); if (r) { fires += 1; durs.push(r.duration); }
    const inp = d.input(t + 0.001); maxC = Math.max(maxC, inp.closure); if (inp.creeping) creep = true;
  }
  return { fires, t: t0 + n / 30, durs, maxC, creep };
}
function detRest(d, a, seconds, t0) { const n = Math.round(seconds * 30); for (let i = 0; i <= n; i++) d.ingest(a, t0 + i / 30); return t0 + n / 30; }
function detectorChecks() {
  const out = [];
  { // BITE: 150 -> 5 in 0.3 s: one bite at the shut, duration ~0.25 s (closeStart -> 18 deg)
    const d = new SnapDetector(); const t = detRest(d, 150, 1, 0);
    const r = detPath(d, 150, 5, 0.3, t);
    out.push([`a slam bites once at the shut (fires=${r.fires}, d=${(r.durs[0] || 0).toFixed(3)})`, r.fires === 1 && r.durs[0] >= 0.2 && r.durs[0] <= 0.3 && !d.armed]);
  }
  { // SLOW-CLOSE: 150 -> 5 over 2.5 s: one bite, a long duration, reported creeping on the way
    const d = new SnapDetector(); const t = detRest(d, 150, 1, 0);
    const r = detPath(d, 150, 5, 2.5, t);
    out.push([`a slow close bites at the shut with a long duration (fires=${r.fires}, d=${(r.durs[0] || 0).toFixed(2)}, creep=${r.creep})`, r.fires === 1 && r.durs[0] >= 1.5 && r.creep]);
  }
  { // a creep too slow to time (150 -> 5 over 20 s) still counts as a slow close
    const d = new SnapDetector(); const t = detRest(d, 150, 1, 0);
    const r = detPath(d, 150, 5, 20, t);
    out.push([`a very slow creep is a slow bite (fires=${r.fires}, d=${(r.durs[0] || 0).toFixed(2)})`, r.fires === 1 && r.durs[0] >= 1.5]);
  }
  { // NO-BITE-DEEP: 150 -> 60 -> 150, and 150 -> 30 -> 150: never a bite, however deep; armed throughout
    const d = new SnapDetector(); let t = detRest(d, 150, 1, 0);
    const a = detPath(d, 150, 60, 0.4, t); t = detRest(d, 60, 1, a.t);
    const b = detPath(d, 60, 150, 0.6, t); t = detRest(d, 150, 1, b.t);
    const c = detPath(d, 150, 30, 0.4, t); const e = detPath(d, 30, 150, 0.6, c.t);
    out.push([`a partial close never bites (fires=${a.fires + b.fires + c.fires + e.fires}, max closure ${a.maxC.toFixed(0)})`, a.fires + b.fires + c.fires + e.fires === 0 && a.maxC >= 60 && d.armed]);
  }
  { // a half reopen (150 -> 60 -> 120) ends the close: the reference starts again, so a later slam is timed afresh
    const d = new SnapDetector(); let t = detRest(d, 150, 1, 0);
    const a = detPath(d, 150, 60, 0.4, t); const b = detPath(d, 60, 120, 0.4, a.t); t = detRest(d, 120, 1, b.t);
    const was = d.closing;
    const c = detPath(d, 120, 5, 0.25, t);
    out.push([`opening again ends the close (closing after: ${was}, next slam d=${(c.durs[0] || 0).toFixed(2)})`, !was && c.fires === 1 && c.durs[0] <= 0.3]);
  }
  { // REOPEN: after the bite, unarmed until theta >= 35, then armed; the next close bites again
    const d = new SnapDetector(); let t = detRest(d, 150, 1, 0);
    const a = detPath(d, 150, 5, 0.3, t); t = a.t;
    const b = detPath(d, 5, 30, 0.2, t); t = b.t; const still = d.armed;
    const c = detPath(d, 30, 150, 0.4, t); t = detRest(d, 150, 0.7, c.t); const re = d.armed;
    const e = detPath(d, 150, 5, 0.3, t);
    out.push([`re-arms at 35 and bites again (armed at 30: ${still}, at 150: ${re}, fires ${a.fires + b.fires + c.fires + e.fires})`, !still && re && a.fires + b.fires + c.fires === 1 && e.fires === 1]);
  }
  { // STATUS: .closed bites at theta <= 25 only (hardware reads .closed at ~85: 90 is open)
    const d = new SnapDetector(); let t = detRest(d, 150, 1, 0);
    const a = detPath(d, 150, 40, 0.3, t, 'closed'); t = a.t;
    const b = detPath(d, 40, 24, 0.1, t, 'closed');
    out.push([`status .closed bites only at <= 25 deg (at 40: ${a.fires}, at 24: ${b.fires})`, a.fires === 0 && b.fires === 1]);
  }
  { // jitter at rest (and flat) never closes or bites; nothing is ever too flat
    const d = new SnapDetector(); const r = new SeededRandom(5); let bad = 0;
    for (let i = 0; i < 600; i++) { const t = i / 30; if (d.ingest(178 + r.range(-1.5, 1.5), t)) bad += 1; const inp = d.input(t); if (inp.creeping || inp.snap || inp.tooFlat || inp.closure >= D.closeStart) bad += 1; }
    out.push([`jitter never closes or bites, flat is fine (bad=${bad})`, bad === 0]);
  }
  { // a round's start (requireShut): open is not armed; shut then open arms; a 90 deg phone is open
    const d = new SnapDetector(true); let t = detRest(d, 150, 0.5, 0);
    const before = d.armed;
    const a = detPath(d, 150, 5, 0.3, t); t = a.t;
    const b = detPath(d, 5, 90, 0.4, t); t = detRest(d, 90, 0.5, b.t);
    const open90 = d.armed;
    const c = detPath(d, 90, 5, 0.2, t);
    out.push([`a round starts closed (armed open: ${before}, shut-bite: ${a.fires}, armed at 90: ${open90}, then bites: ${c.fires})`, !before && a.fires === 0 && open90 && c.fires === 1]);
  }
  for (const r of noisyDetectorChecks(Number(args.noisySeeds || 200))) out.push(r);
  return out;
}

// R9 (real hardware): noisy hinge traces, as SnapTests/CoreTests.swift's R9 detector tests. Reports every 25-45 ms with
// a 150 ms gap 5 % of the time (the Duo: 25-30 Hz while moving, occasional 100-200 ms gaps), uniform report noise of
// +-amp degrees, an optional bias (the +-5 deg accuracy), and the hardware's status (.closed from 85 deg down).
// `legs`: [[from, to, seconds], ...] of the hand's true angle. Returns the bites and what the trap did.
function noisyTrace(d, rng, legs, opt) {
  const o = Object.assign({ amp: 3, bias: 0, t0: 0, status: true }, opt || {});
  let t = o.t0; const fires = []; let armedEver = false; let maxC = 0; let armedAfterFirst = false;
  for (const [from, to, secs] of legs) {
    const end = t + secs; let lt = t;
    while (lt < end) {
      lt += rng.chance(0.05) ? 0.15 : rng.range(0.025, 0.045);
      const u = Math.min(1, (lt - t) / Math.max(secs, 1e-9));
      const truth = from + (to - from) * u;
      const a = clamp(truth + o.bias + rng.range(-o.amp, o.amp), 0, 180);
      const status = !o.status ? 'unknown' : (truth <= 85 ? 'closed' : (truth >= 175 ? 'fullyOpen' : 'partiallyOpen'));
      const f = d.ingest(a, lt, status);
      if (f) fires.push(f);
      const inp = d.input(lt + 0.001); maxC = Math.max(maxC, inp.closure);
      if (d.armed) { armedEver = true; if (fires.length > 0) armedAfterFirst = true; }
    }
    t = end;
  }
  return { fires, t, armedEver, maxC, armedAfterFirst };
}
function noisyDetectorChecks(n) {
  const out = []; const bad = {};
  const fail = (k) => { bad[k] = (bad[k] || 0) + 1; };
  for (let k = 0; k < n; k++) {
    const rng = new SeededRandom(9000 + k);
    { // a noisy slam bites once, timed like a slam
      const d = new SnapDetector(); const r = noisyTrace(d, rng, [[150, 150, 1], [150, 3, 0.3], [3, 3, 1]]);
      if (r.fires.length !== 1 || r.fires[0].duration > 0.4) fail('slam');
    }
    { // a slow close (40 deg/s) with stick-slip stops still bites once at the shut, slowly
      const d = new SnapDetector();
      const r = noisyTrace(d, rng, [[150, 150, 1], [150, 110, 1], [110, 110, 0.4], [110, 60, 1.25], [60, 60, 0.3], [60, 3, 1.4], [3, 3, 1]]);
      if (r.fires.length !== 1 || r.fires[0].duration < 1.0) fail('slow');
    }
    { // a creep at 8 deg/s still bites once at the shut
      const d = new SnapDetector(); const r = noisyTrace(d, rng, [[150, 150, 1], [150, 3, 18], [3, 3, 1]]);
      if (r.fires.length !== 1) fail('creep');
    }
    { // partial closes to 40 and to 60 never bite (the status says .closed below 85)
      const d = new SnapDetector();
      const r = noisyTrace(d, rng, [[150, 150, 1], [150, 40, 0.4], [40, 40, 1], [40, 150, 0.5], [150, 60, 0.3], [60, 60, 2], [60, 150, 0.4]]);
      if (r.fires.length !== 0 || !d.armed) fail('partial');
    }
    { // a phone hovering at 25-35 with .closed and +-5 noise: at most the one bite, never flapping
      const d = new SnapDetector(); const r = noisyTrace(d, rng, [[150, 150, 1], [150, 30, 0.4], [30, 30, 6]], { amp: 6 });
      if (r.fires.length > 1) fail('hover');
    }
    { // jitter round the shut line after a slow close: one bite
      const d = new SnapDetector(); const r = noisyTrace(d, rng, [[150, 150, 1], [150, 20, 2], [20, 16, 3], [16, 22, 2], [22, 3, 1]], { amp: 4 });
      if (r.fires.length !== 1) fail('jitter-shut');
    }
    { // opened only to 45: open, and the close bites
      const d = new SnapDetector(true); const r = noisyTrace(d, rng, [[3, 3, 0.5], [3, 45, 0.5], [45, 45, 1.5], [45, 3, 0.3], [3, 3, 0.5]], { amp: 2 });
      if (!r.armedEver || r.fires.length !== 1) fail('open45');
    }
    { // a round's starting close never bites; then open, then the first real close bites once
      const d = new SnapDetector(true); const r = noisyTrace(d, rng, [[150, 150, 1], [150, 3, 0.3], [3, 3, 0.5], [3, 150, 0.6], [150, 150, 1], [150, 3, 0.3], [3, 3, 0.5]]);
      if (r.fires.length !== 1 || d.waiting) fail('start-close');
    }
    { // a round starting at 10 deg (status not .closed), and one at 22 deg: never stuck waiting
      const a = new SnapDetector(true); noisyTrace(a, rng, [[10, 10, 0.5], [10, 150, 0.6], [150, 150, 0.5]], { amp: 1, status: false });
      const b = new SnapDetector(true); noisyTrace(b, rng, [[22, 22, 0.5], [22, 150, 0.6], [150, 150, 0.5]], { amp: 1, status: false });
      if (a.waiting || !a.armed || b.waiting || !b.armed) fail('start-low');
    }
    { // biased +8 (a shut phone reads 8-14): still one bite a close, two closes two bites
      const d = new SnapDetector(); const r = noisyTrace(d, rng, [[150, 150, 1], [150, 0, 0.3], [0, 0, 0.6], [0, 150, 0.6], [150, 150, 1], [150, 0, 0.3], [0, 0, 0.6]], { bias: 8 });
      if (r.fires.length !== 2) fail('bias');
    }
  }
  const names = { slam: 'a noisy slam bites once', slow: 'a noisy slow close with stops bites once, slowly', creep: 'a noisy 8 deg/s creep bites once',
    partial: 'noisy partial closes (to 40 and 60, .closed) never bite', hover: 'a .closed phone hovering at 30 +-6 never flaps',
    'jitter-shut': 'jitter round the shut line bites once', open45: 'opened only to 45 plays (armed, then bites)',
    'start-close': "a round's starting close never bites; the next close does", 'start-low': 'a round starting at 10 or 22 deg is never stuck',
    bias: 'biased +8: one bite per close' };
  for (const [k, name] of Object.entries(names)) out.push([`noisy ${name} (${n - (bad[k] || 0)}/${n} traces)`, !bad[k]]);
  { // noteFolded: a waiting round counts as closed; an armed trap at 22 bites, at 40 does not
    const w = new SnapDetector(true); detRest(w, 150, 0.5, 0); w.noteFolded(1); const waitOk = !w.waiting && !w.armed;
    const hi = new SnapDetector(); detRest(hi, 150, 1, 0); detPath(hi, 150, 40, 0.3, 1); const fHi = hi.noteFolded(2);
    const lo = new SnapDetector(); detRest(lo, 150, 1, 0); detPath(lo, 150, 22, 0.3, 1); const fLo = lo.noteFolded(2);
    out.push([`noteFolded: a waiting round is closed (${waitOk}), bites at 22 (${!!fLo}) not at 40 (${!!fHi})`, waitOk && !!fLo && !fHi]);
  }
  return out;
}

// MARK: Runs
// R8 (ROUND-8 §4): one level played by a pilot (LevelBook.session in Swift): the result LevelBook.evaluate reads.
function levelOptions(L) { return { snapsRunOut: L.bites != null, waves: false, stingCosts: false, hunger: false, refunds: false, level: L }; }
function runLevel(L, skill, pilotSeed, drawFirst) {
  const s = new Session(levelSeed(L.id), levelOptions(L), 'level');
  if (args.debug) s.debug = true;
  const pilot = new Pilot(skill, pilotSeed);
  pilot.minBite = goalOf(L).biteOf; pilot.targets = goalOf(L).species;
  if (drawFirst) pilot.drawFirstClose();
  const dt = 1 / 60; let t = 0; let frames = 0;
  while (s.phase !== 'finished' && frames < 60 * 180) { s.step(dt, pilot.step(dt, t, s.snapshot())); t += dt; frames += 1; }
  const r = { snaps: s.stats.snaps, caught: s.stats.caught, bySpecies: s.bySpecies, biggest: s.stats.biggest, spared: s.stats.spared, stings: s.stats.stings, escapes: s.stats.escapes || 0, seconds: s.phase === 'finished' ? s.tiredAt : s.time };
  if (args.debug) console.log(`  level ${L.id} ${skill}: caught=${r.caught} spared=${r.spared} stings=${r.stings} escapes=${r.escapes} snaps=${r.snaps} end=${s.levelEnd}`);
  return Object.assign(levelEvaluate(L, r), { r, end: s.levelEnd || (s.phase === 'finished' ? 'bites' : 'cap') });
}
// Pilot seeds for the level table (the same in BalanceTests.swift): 1 + 7 * k
function levelTable(n, ids) {
  const rows = [];
  for (const L of LEVELS) {
    if (ids && !ids.includes(L.id)) continue;
    const row = { id: L.id, title: L.title };
    for (const sk of ['novice', 'casual', 'expert', 'perfect']) {
      let wins = 0, three = 0, ends = {}; const bites = [], esc = []; const st = [0, 0, 0, 0]; const all = [];
      for (let k = 0; k < n; k++) {
        const o = runLevel(L, sk, u64(BigInt(1 + 7 * k)), true);
        if (o.passed) { wins += 1; bites.push(o.r.snaps); esc.push(o.r.escapes); }
        if (o.stars === 3) three += 1; st[o.stars] += 1; all.push(o.stars); ends[o.end] = (ends[o.end] || 0) + 1;
      }
      // R9: a player retries: the best of each 3 tries in a row, averaged (what the world unlock sees)
      let best3 = 0, groups = 0; for (let g = 0; g + 3 <= n; g += 3) { best3 += Math.max(all[g], all[g + 1], all[g + 2]); groups += 1; }
      row[sk] = { wins, three, ends, st, mean: all.reduce((a, b) => a + b, 0) / n, best3: groups ? best3 / groups : 0,
        bites: bites.length ? Math.min(...bites) + '-' + Math.max(...bites) : '-', esc: esc.length ? Math.min(...esc) + '-' + Math.max(...esc) : '-' };
    }
    rows.push(row);
  }
  return rows;
}
// R9: the CI demo runs of the levels (GameController: the pilot seed is the level seed + 101): what the frames show
function levelDemo(id, skill) { const L = LEVELS[id - 1]; return runLevel(L, skill, u64(levelSeed(id) + 101n)); }
// R8 (ROUND-8 §4) + R9 (design/notes/core-R9.md): the level targets. Novice passes 1-8 easily and struggles from Dusk;
// casual passes most of Morning and Dusk with 1-2 stars, Night is hard; expert can 3-star most; perfect 3-stars all;
// every world opens for a casual player who retries (best of 3 tries) without the levels it can't pass.
function levelChecks(rows, n) {
  const out = [];
  const by = (id) => rows.find((r) => r.id === id);
  for (const r of rows) {
    out.push([`level ${r.id} expert wins >= half (${r.expert.wins}/${n})`, r.expert.wins * 2 >= n]);
    out.push([`level ${r.id} perfect 3 stars at least once (${r.perfect.three}/${n})`, r.perfect.three >= 1]);
    // (level 4 is the bee lesson: the novice pilot ignores 60 % of bees by design, so it fails it often; CI frame 62 needs that)
    if (r.id <= 8 && r.id !== 4) out.push([`level ${r.id} novice wins >= 3/4 (${r.novice.wins}/${n})`, r.novice.wins * 4 >= 3 * n]);
    if (r.id === 4) out.push([`level 4 (the bee) novice wins >= 1/3 (${r.novice.wins}/${n})`, r.novice.wins * 3 >= n]);
  }
  if (rows.length !== 30) return out;
  const world = (w) => rows.filter((r) => Math.ceil(r.id / 10) === w);
  const sum = (rs, f) => rs.reduce((a, r) => a + f(r), 0);
  // 3 stars takes skill from level 3: the casual pilot 3-stars at most 2 of levels 3-10 in half its tries or more
  const easy3 = rows.filter((r) => r.id >= 3 && r.id <= 10 && r.casual.three * 2 >= n).length;
  out.push([`3 stars takes skill from level 3: casual 3-stars >= half its tries on <= 2 of levels 3-10 (${easy3})`, easy3 <= 2]);
  for (const w of [1, 2]) {
    const ws = world(w); const passes = ws.filter((r) => r.casual.wins * 10 >= 7 * n).length;
    out.push([`world ${w}: casual passes >= 70% of tries on >= 7 of 10 levels (${passes})`, passes >= 7]);
  }
  const duskNovice = sum(world(2), (r) => r.novice.wins) / (10 * n);
  out.push([`Dusk: the novice struggles (passes ${(duskNovice * 100).toFixed(0)}% <= 50%)`, duskNovice <= 0.5]);
  const nightCasual = sum(world(3), (r) => r.casual.wins) / (10 * n);
  out.push([`Night is hard: casual passes ${(nightCasual * 100).toFixed(0)}% <= 60%`, nightCasual <= 0.6]);
  const expert3 = rows.filter((r) => r.expert.three * 2 >= n).length;
  out.push([`expert 3-stars >= half its tries on >= 20 of 30 levels (${expert3})`, expert3 >= 20]);
  const notAll = rows.filter((r) => r.id > 10 && r.expert.three < n).length;
  out.push([`3 stars is never automatic late: the expert misses them sometimes on >= 5 Dusk/Night levels (${notAll})`, notAll >= 5]);
  // World unlocks (LevelBook.worldUnlockStars 20): a casual player's best of 3 tries
  const w1 = sum(world(1), (r) => r.casual.best3), w2 = sum(world(2), (r) => r.casual.best3);
  out.push([`casual opens Dusk: world 1 best-of-3 stars ${w1.toFixed(1)} >= 20`, w1 >= 20]);
  out.push([`casual opens Night: worlds 1-2 best-of-3 stars ${(w1 + w2).toFixed(1)} >= 40`, w1 + w2 >= 40]);
  // CI frames (ci/scenarios.txt): level 1 by perfect is 3 stars (08, 30); level 4 by the novice is a failed level (62)
  const l1 = levelDemo(1, 'perfect'), l4 = levelDemo(4, 'novice');
  out.push([`CI: level 1 by the perfect demo pilot is 3 stars (${l1.stars})`, l1.stars === 3]);
  out.push([`CI: level 4 by the novice demo pilot fails (passed=${l4.passed}, end ${l4.end})`, !l4.passed]);
  void by;
  return out;
}

// R4: SPROUT1 is the App's options for a Sprout's first Feed run (SessionOptions.firstRun: 14 snaps, no wilting, the
// first stinger bite free; startSnaps 12 is what the App passes for every Sprout Feed run and firstRun overrides it).
const SPROUT1 = { startSnaps: 12, firstRun: true };
// R5 (REVIEW-4 #8): SessionOptions.sprout(feedRun: 2 / 3) plus the Sprout rank's startSnaps 12 (the taper overrides it).
const SPROUT2 = { startSnaps: 12, sproutRun: 2 };
const SPROUT3 = { startSnaps: 12, sproutRun: 3 };
function runOne(skill, seed, extra, mode, giveUp, pilotSeed) {
  const s = new Session(seed, Object.assign({ snapsRunOut: true, waves: true, stingCosts: true }, extra || {}), mode || 'feed');
  const pilot = new Pilot(skill, pilotSeed != null ? pilotSeed : u64(BigInt(seed) * 7n + 1n), giveUp);
  if (args.trace) s.debug = true;
  const dt = 1 / 60; let t = 0; let frames = 0;
  // R9: the first 20 s of session time (a novice must catch something and feel good early)
  let caught20 = null, firstCatch = null;
  while (s.phase !== 'finished' && frames < 60 * 600) {
    const input = pilot.step(dt, t, s.snapshot());
    s.step(dt, input);
    if (firstCatch === null && s.stats.caught > 0) firstCatch = s.time;
    if (caught20 === null && s.time >= 20) caught20 = s.stats.caught;
    t += dt; frames += 1;
  }
  if (caught20 === null) caught20 = s.stats.caught;
  if (firstCatch === null) firstCatch = 999;
  return { score: s.score, seconds: s.phase === 'finished' ? s.tiredAt : s.time, snaps: s.stats.snaps, caught: s.stats.caught,
    stings: s.stats.stings, feasts: s.stats.feasts, dry: s.stats.dry, waves: s.wave, chain: s.stats.longestChain,
    biggest: s.stats.biggest, spared: s.stats.spared, wilts: s.stats.wilts, capped: s.phase !== 'finished',
    // R8: wall seconds (the session clock plus the frozen shut time) and the mean catch ratio of the bites
    wall: (s.phase === 'finished' ? s.tiredAt : s.time) + s.stats.shutTime,
    ratio: s.stats.ratioN > 0 ? s.stats.ratioSum / s.stats.ratioN : 0,
    dayRatio: s.stats.dayRatioN > 0 ? s.stats.dayRatioSum / s.stats.dayRatioN : 0,
    caught20, firstCatch };
}
// R6: a Zen Bog run (SessionOptions.for(.zen)) for `seconds`: it must never tire, never change its snaps, and keep
// catching (the day loops, so the night never outruns the hand).
const ZEN = { snapsRunOut: false, waves: true, stingCosts: false, hunger: false };
function runZen(skill, seed, seconds) {
  const s = new Session(seed, Object.assign({}, ZEN), 'zen');
  const pilot = new Pilot(skill, u64(BigInt(seed) * 7n + 1n));
  const dt = 1 / 60; let t = 0; const start = s.snapsLeft; let snapsChanged = 0; let caughtAt = 0;
  const frames = Math.round(seconds * 60);
  for (let f = 0; f < frames && s.phase !== 'finished'; f++) {
    s.step(dt, pilot.step(dt, t, s.snapshot()));
    t += dt;
    if (s.snapsLeft !== start) snapsChanged += 1;
    if (f === frames - 120 * 60) caughtAt = s.stats.caught;
  }
  return { tired: s.phase === 'playing' ? 0 : 1, snapsChanged, late: s.stats.caught - caughtAt, caught: s.stats.caught,
    snaps: s.stats.snaps, stings: s.stats.stings, chain: s.stats.longestChain, wilts: s.stats.wilts, waves: s.wave };
}
function zenTable(seeds, base, stride, skills) {
  const out = {};
  for (const sk of skills) {
    const runs = []; for (let i = 0; i < seeds; i++) runs.push(runZen(sk, base + i * stride, 600));
    out[sk] = { tired: runs.filter((r) => r.tired).length, snapsChanged: runs.reduce((a, r) => a + r.snapsChanged, 0),
      minLate: Math.min(...runs.map((r) => r.late)), caught: pct(runs.map((r) => r.caught), 0.5),
      stings: pct(runs.map((r) => r.stings), 0.5), chain: pct(runs.map((r) => r.chain), 0.5),
      wilts: Math.max(...runs.map((r) => r.wilts)), waves: pct(runs.map((r) => r.waves), 0.5) };
  }
  return out;
}
// R7 (#14): who lands in the trap at night: waves nightWave..90 of each seed, catchable bugs that land in the trap
// (mirror of CoreTests' nightIsFirefliesAndCrickets)
function nightShare(seeds, base, stride) {
  const g = new Geo(SCENE.w, SCENE.h); const counts = {}; let total = 0;
  for (let i = 0; i < seeds; i++) {
    const seed = u64(BigInt(base + i * stride));
    for (let w = T.nightWave; w <= 90; w++) {
      const block = Math.floor((w - 1) / T.nectarReseedWaves);
      const nectar = nectarDrops(nectarSeed(seed, block), g);
      for (const b of makeWave(seed, w, g, nectar, false).bugs) {
        if (isProtected(b.species) || !b.landsInTrap) continue;
        counts[b.species] = (counts[b.species] || 0) + 1; total += 1;
      }
    }
  }
  let top = ''; for (const [k, v] of Object.entries(counts)) if (!top || v > counts[top]) top = k;
  return { total, counts, top, share: ((counts.firefly || 0) + (counts.cricket || 0)) / Math.max(total, 1) };
}
function zenLine(sk, m) { return `SNAP-BAL zen ${sk} 600 s: caught=${m.caught} minLate120s=${m.minLate} stings=${m.stings} chain=${m.chain} waves=${m.waves} tired=${m.tired} snapsChanged=${m.snapsChanged} maxWilts=${m.wilts}`; }
function pct(a, p) { if (a.length === 0) return 0; const s = a.slice().sort((x, y) => x - y); const pos = (s.length - 1) * p; const lo = Math.floor(pos); const hi = Math.min(s.length - 1, lo + 1); return s[lo] + (s[hi] - s[lo]) * (pos - lo); }
const KEYS = ['score', 'seconds', 'snaps', 'caught', 'stings', 'feasts', 'dry', 'waves', 'chain', 'biggest', 'spared', 'wilts', 'wall', 'ratio', 'dayRatio', 'caught20', 'firstCatch'];
function medians(runs) {
  const m = {};
  for (const k of KEYS) m[k] = pct(runs.map((r) => r[k]), 0.5);
  m.maxStings = Math.max(...runs.map((r) => r.stings));
  m.maxWilts = Math.max(...runs.map((r) => r.wilts));
  m.p90seconds = pct(runs.map((r) => r.seconds), 0.9);
  // R9: the slowest tenth of first catches (a novice must catch something early)
  m.p90firstCatch = pct(runs.map((r) => r.firstCatch), 0.9);
  m.capped = runs.filter((r) => r.capped).length;
  return m;
}
// R7: the "Well Fed" achievement's score (Achievements.score10k, R6's 10,000; not a balance value, so not in T)
const WELL_FED = 10000;
// MARK: Targets (mirror of SnapTests/BalanceTests.swift)
function checks(med) {
  const out = [];
  const c = med.casual, n = med.novice, e = med.expert, p = med.perfect;
  // R8 (ROUND-8 §2): run lengths (session seconds, the frozen shut time excluded): novice 60-100 s, casual 2-3 min,
  // expert 4-6 min; the best players' daytime catch ratio is 90 %+.
  if (n) out.push([`novice seconds 60-100 (${n.seconds.toFixed(1)})`, n.seconds >= 60 && n.seconds <= 100]);
  // R9 (hard is not unfair): a novice catches in its first 20 s (median >= 2 bugs; 9 runs in 10 catch by 20 s)
  if (n) out.push([`novice catches >= 2 in the first 20 s (median ${n.caught20})`, n.caught20 >= 2]);
  if (n) out.push([`novice first catch by 20 s in 9 runs of 10 (p90 ${n.p90firstCatch.toFixed(1)} s)`, n.p90firstCatch <= 20]);
  if (c) {
    out.push([`casual seconds 120-180 (${c.seconds.toFixed(1)})`, c.seconds >= 120 && c.seconds <= 180]);
    out.push([`casual snaps 15-45 (${c.snaps})`, c.snaps >= 15 && c.snaps <= 45]);
    out.push([`casual wilts <= 2 (${c.wilts})`, c.wilts <= 2]);
  }
  if (e) out.push([`expert seconds 240-360 (${e.seconds.toFixed(1)})`, e.seconds >= 240 && e.seconds <= 360]);
  if (e) out.push([`expert daytime catch ratio >= 0.9 (${e.dayRatio.toFixed(2)})`, e.dayRatio >= 0.9]);
  if (p) out.push([`perfect daytime catch ratio >= 0.9 (${p.dayRatio.toFixed(2)})`, p.dayRatio >= 0.9]);
  if (n && e) out.push([`novice catch ratio < expert (${n.ratio.toFixed(2)} < ${e.ratio.toFixed(2)})`, n.ratio < e.ratio]);
  if (c && e) out.push([`casual longest chain <= expert (${c.chain} <= ${e.chain})`, c.chain <= e.chain]);
  if (med.sprout) out.push([`casual Sprout run 1 seconds >= 90 (${med.sprout.seconds.toFixed(1)})`, med.sprout.seconds >= 90]);
  if (med.sproutNovice) out.push([`novice Sprout run 1 seconds >= 90 (${med.sproutNovice.seconds.toFixed(1)})`, med.sproutNovice.seconds >= 90]);
  if (med.sproutNovice) out.push([`novice Sprout run 1 never wilts (${med.sproutNovice.maxWilts})`, med.sproutNovice.maxWilts === 0]);
  // R5 (REVIEW-4 #8): the taper keeps a weak hand's runs 2 and 3 long
  if (med.sprout2Novice) out.push([`novice Sprout run 2 seconds >= 75 (${med.sprout2Novice.seconds.toFixed(1)})`, med.sprout2Novice.seconds >= 75]);
  if (med.sprout3Novice) out.push([`novice Sprout run 3 seconds >= 60 (${med.sprout3Novice.seconds.toFixed(1)})`, med.sprout3Novice.seconds >= 60]);
  for (const [tag, m] of [['1', med.sproutNovice], ['2', med.sprout2Novice], ['3', med.sprout3Novice]]) if (m) out.push([`novice Sprout run ${tag} never capped (${m.capped})`, m.capped === 0]);
  if (e) out.push([`expert wilts <= 6 (${e.wilts})`, e.wilts <= 6]);
  // R6 (#19): an expert run lasts at most about 6 minutes (median)
  if (e) out.push([`expert seconds <= 360 (${e.seconds.toFixed(1)})`, e.seconds <= 360]);
  // R7 (#14): ... and nine expert runs in ten (p90), with the night pool led by fireflies and crickets
  if (e) out.push([`expert p90 seconds <= 360 (${e.p90seconds.toFixed(1)})`, e.p90seconds <= 360]);
  if (med.night) {
    out.push([`night: fireflies + crickets >= 40% of landing bugs (${(med.night.share * 100).toFixed(1)}%)`, med.night.share >= 0.4]);
    out.push([`night: the firefly is the commonest landing bug (${med.night.top})`, med.night.top === 'firefly']);
  }
  // R6 (#19): with the last light even a hand that never gives up ends (the nogiveup rows)
  for (const [tag, m] of [['expert', med.nogiveupExpert], ['perfect', med.nogiveupPerfect]]) if (m) out.push([`${tag} without pilotGiveUp never capped (${m.capped})`, m.capped === 0]);
  // R6: the Zen Bog never tires or wilts, keeps its snaps, and the pilot still catches in its last 2 minutes
  if (med.zen) for (const [sk, z] of Object.entries(med.zen)) {
    out.push([`zen ${sk} never tires (${z.tired})`, z.tired === 0]);
    out.push([`zen ${sk} snaps never change (${z.snapsChanged})`, z.snapsChanged === 0]);
    out.push([`zen ${sk} never wilts (${z.wilts})`, z.wilts === 0]);
    out.push([`zen ${sk} catches late (min ${z.minLate} in the last 120 s)`, z.minLate >= 10]);
  }
  if (p) out.push([`perfect seconds 240-480 (${p.seconds.toFixed(1)})`, p.seconds >= 240 && p.seconds <= 480]);
  if (p) out.push([`perfect wilts <= 5 (${p.wilts})`, p.wilts <= 5]);
  if (n) out.push([`novice stings >= 1 (${n.stings})`, n.stings >= 1]);
  if (p) out.push([`perfect never stung (max ${p.maxStings})`, p.maxStings === 0]);
  if (n && c) out.push([`novice < casual (${n.score} < ${c.score})`, n.score < c.score]);
  if (c && e) out.push([`casual < expert (${c.score} < ${e.score})`, c.score < e.score]);
  // R7 (#3): "Well Fed" (Tuning.wellFedScore, not in T) sits above the casual median and at or below the expert's
  if (c && e) out.push([`casual < Well Fed ${WELL_FED} <= expert (${c.score}, ${e.score})`, c.score < WELL_FED && WELL_FED <= e.score]);
  if (e && p) out.push([`expert <= perfect (${e.score} <= ${p.score})`, e.score <= p.score]);
  for (const sk of ['novice', 'casual', 'expert', 'perfect']) if (med[sk]) out.push([`${sk} never capped (${med[sk].capped})`, med[sk].capped === 0]);
  return out;
}
function main() {
  const seeds = Number(args.seeds || 16);
  const base = Number(args.base || 1000), stride = Number(args.stride || 7919);
  const skills = (args.skills || 'novice,casual,expert,perfect').split(',');
  if (args.levels) {
    const n = Number(args.levelSeeds || 8);
    const ids = args.ids ? args.ids.split(',').map(Number) : null;
    const rows = levelTable(n, ids);
    // R9: per skill, passes / tries and the star spread [0*,1*,2*,3*]
    for (const r of rows) console.log(`SNAP-LVL ${String(r.id).padStart(2)} ${r.title.padEnd(18)} ` + ['novice', 'casual', 'expert', 'perfect'].map((sk) => `${sk[0]} ${String(r[sk].wins).padStart(2)}/${n} [${r[sk].st.join(',')}] b${r[sk].bites}`).join(' | '));
    if (args.ends) for (const r of rows) console.log(`SNAP-LVL ends ${r.id} ` + ["novice", "casual", "expert", "perfect"].map((sk) => `${sk[0]} ${JSON.stringify(r[sk].ends)}`).join(" "));
    if (!ids) for (const w of [1, 2, 3]) {
      const ws = rows.filter((r) => Math.ceil(r.id / 10) === w);
      console.log(`SNAP-LVL world ${w} ` + ['novice', 'casual', 'expert', 'perfect'].map((sk) => `${sk} pass ${(100 * ws.reduce((a, r) => a + r[sk].wins, 0) / (10 * n)).toFixed(0)}% stars ${ws.reduce((a, r) => a + r[sk].mean, 0).toFixed(1)} (best of 3: ${ws.reduce((a, r) => a + r[sk].best3, 0).toFixed(1)})`).join(' | '));
    }
    for (const [name, ok] of levelChecks(rows, n)) if (!ok || args.all) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
    return;
  }
  if (args.detector) {
    for (const [name, ok] of detectorChecks()) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
    return;
  }
  if (args.crowd) {
    // R2: crowd waves land within 1.2 s (first landing to last, flyers that land in the trap; nobody snaps)
    let worst = 0, waves = 0, over = 0; const spreads = [];
    for (let i = 0; i < seeds; i++) {
      const s = new Session(base + i * stride, { snapsRunOut: true, waves: true, stingCosts: true, hunger: false }, 'feed');
      const landed = new Map();
      const sw = s.startWave.bind(s);
      s.startWave = () => {
        const n0 = s.pending.length; sw();
        const crowd = makeWave(s.seed, s.wave, s.g, s.nectar).crowd;
        for (let k = n0; k < s.pending.length; k++) { s.pending[k].spec.wave = s.wave; s.pending[k].spec.crowdWave = crowd; }
      };
      const sp = s.spawn.bind(s);
      s.spawn = (spec) => { const id = sp(spec); if (id > 0) s.bugs[s.bugs.length - 1].spec = spec; return id; };
      const ld = s.land.bind(s);
      s.land = (b) => {
        ld(b);
        const q = b.spec;
        if (q && q.crowdWave && !isProtected(b.species) && b.m.style !== WALKER && q.landsInTrap) {
          if (!landed.has(q.wave)) landed.set(q.wave, []);
          landed.get(q.wave).push(s.time);
        }
      };
      for (let fr = 0; fr < 60 * 120; fr++) s.step(1 / 60, { closure: 0, armed: true, creeping: false, snap: null });
      for (const [, ts] of landed) {
        if (ts.length < 2) continue;
        const d = Math.max(...ts) - Math.min(...ts); spreads.push(d); worst = Math.max(worst, d); waves += 1; if (d > 1.2) over += 1;
      }
    }
    console.log(`CROWD waves=${waves} median spread=${pct(spreads, 0.5).toFixed(2)} s p90=${pct(spreads, 0.9).toFixed(2)} worst=${worst.toFixed(2)} over1.2=${over}`);
    return;
  }
  if (args.crease) {
    // R3 (REVIEW-2 #5): no bug ever rests (sips or pauses) in the trap within creaseGap(radius) of the midrib line
    let rests = 0, bad = 0, worst = Infinity, banded = 0, low = 0; const lowKinds = {};
    for (let i = 0; i < seeds; i++) {
      for (const sk of ['casual', 'perfect', 'attract']) {
        const attract = sk === 'attract';
        const s = new Session(base + i * stride, { snapsRunOut: !attract, waves: true, stingCosts: true }, attract ? 'attract' : 'feed');
        const pilot = new Pilot(attract ? 'casual' : sk, 3n);
        for (let fr = 0; fr < 60 * 240 && s.phase !== 'finished'; fr++) {
          s.step(1 / 60, pilot.step(1 / 60, 0, s.snapshot()));
          // R4 (REVIEW-3 #14): anything over the trap within creaseHalfWidth + r of the line flies >= creaseAirHeight
          for (const b of s.bugs) {
            if (b.mode === M.caught || !s.g.contains(b)) continue;
            if (Math.abs(b.x - s.g.cx) >= CREASE_HALF + b.info.radius) continue;
            banded += 1;
            if (b.height < T.creaseAirHeight - 1e-9) { low += 1; const k = b.species + '/' + b.mode; lowKinds[k] = (lowKinds[k] || 0) + 1; }
          }
          for (const b of s.bugs) {
            if (!b.landsInTrap || !(b.mode === M.sip || b.mode === M.pause)) continue;
            rests += 1;
            const slack = Math.abs(b.x - s.g.cx) - creaseGap(b.info.radius);
            worst = Math.min(worst, slack);
            // a walker ends a dash up to its wobble amplitude (ant: 3 pt) off its spot
            if (slack < -(b.m.style === WALKER ? b.m.wobbleAmp : 0) - 0.5) bad += 1;
          }
        }
      }
    }
    console.log(`CREASE resting frames=${rests} too close=${bad} worst slack=${worst.toFixed(2)} pt`);
    console.log(`CREASE band frames=${banded} low=${low} ${JSON.stringify(lowKinds)}`);
    return;
  }
  if (args.night) {
    // R7 (#14): who lands in the trap at night
    const nt = nightShare(seeds, base, stride);
    console.log(`NIGHT bugs=${nt.total} firefly+cricket=${(nt.share * 100).toFixed(1)}% top=${nt.top} ${JSON.stringify(nt.counts)}`);
    for (const [name, ok] of checks({ night: nt })) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
    return;
  }
  if (args.zen) {
    const z = zenTable(seeds, base, stride, ['casual', 'perfect']);
    for (const [sk, m] of Object.entries(z)) console.log(zenLine(sk, m));
    for (const [name, ok] of checks({ zen: z })) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
    return;
  }
  if (args.attract) {
    for (const sk of skills) {
      const s = new Session(7, { snapsRunOut: false, waves: true, stingCosts: true }, 'attract');
      const pilot = new Pilot(sk, 7n);
      const dt = 1 / 60; let t = 0;
      for (let f = 0; f < 60 * 300; f++) { s.step(dt, pilot.step(dt, t, s.snapshot())); t += dt; }
      console.log(`ATTRACT skill=${sk} snaps@300s=${s.stats.snaps} caught=${s.stats.caught} waves=${s.wave} bugsNow=${s.bugs.length}`);
    }
    return;
  }
  if (args.windows) {
    const nw = Number(args.windows); let fails = 0; const failNames = {};
    for (let w = 0; w < nw; w++) {
      const med = {};
      for (const sk of skills) { const runs = []; for (let i = 0; i < seeds; i++) runs.push(runOne(sk, base + (w * seeds + i) * stride)); med[sk] = medians(runs); }
      if (skills.includes('novice')) {
        for (const [key, o] of [['sproutNovice', SPROUT1], ['sprout2Novice', SPROUT2], ['sprout3Novice', SPROUT3]]) {
          const runs = []; for (let i = 0; i < seeds; i++) runs.push(runOne('novice', base + (w * seeds + i) * stride, o)); med[key] = medians(runs);
        }
      }
      const bad = checks(med).filter(([, ok]) => !ok);
      if (bad.length) { fails += 1; for (const [name] of bad) { const k = name.replace(/ \(.*\)$/, ''); failNames[k] = (failNames[k] || 0) + 1; } }
      console.log(`window ${w}: ` + skills.map((sk) => `${sk} ${med[sk].score}/${med[sk].seconds.toFixed(0)}s/${med[sk].snaps}sn/${med[sk].stings}st`).join(' | '));
    }
    console.log(`windows failing a check: ${fails}/${nw}`, JSON.stringify(failNames));
    return;
  }
  if (args.trace) {
    // R9: one Feed run with every bite printed. trace=1 seed=7 skill=expert pilotSeed=108 is the App's CI demo run
    // (DemoRunner / GameController: the pilot seed is the run seed + 101)
    const sd = Number(args.seed || 7), sk = args.skill || 'expert';
    const ps = args.pilotSeed != null ? u64(BigInt(args.pilotSeed)) : u64(BigInt(sd) + 101n);
    const r = runOne(sk, sd, null, 'feed', true, ps);
    console.log(`TRACE seed=${sd} skill=${sk} score=${r.score} s=${r.seconds.toFixed(1)} snaps=${r.snaps} caught=${r.caught} biggest=${r.biggest}`);
    return;
  }
  const med = {};
  for (const sk of skills) {
    const runs = [];
    for (let i = 0; i < seeds; i++) {
      const seed = base + i * stride;
      const r = runOne(sk, seed); runs.push(r);
      if (args.verbose) console.log(`  ${sk} seed=${seed} score=${r.score} s=${r.seconds.toFixed(1)} snaps=${r.snaps} caught=${r.caught} stings=${r.stings} feasts=${r.feasts} dry=${r.dry} waves=${r.waves} chain=${r.chain} biggest=${r.biggest} spared=${r.spared} wilts=${r.wilts}${r.capped ? ' CAPPED' : ''}`);
    }
    med[sk] = medians(runs);
    const m = med[sk];
    console.log(`SNAP-BAL skill=${sk} score=${m.score} p10=${pct(runs.map((r) => r.score), 0.1).toFixed(0)} p90=${pct(runs.map((r) => r.score), 0.9).toFixed(0)} seconds=${m.seconds.toFixed(1)} p10s=${pct(runs.map((r) => r.seconds), 0.1).toFixed(1)} p90s=${pct(runs.map((r) => r.seconds), 0.9).toFixed(1)} wall=${m.wall.toFixed(1)} ratio=${m.ratio.toFixed(2)} dayRatio=${m.dayRatio.toFixed(2)} snaps=${m.snaps} caught=${m.caught} stings=${m.stings} maxStings=${m.maxStings} feasts=${m.feasts} dry=${m.dry} waves=${m.waves} chain=${m.chain} biggest=${m.biggest} spared=${m.spared} wilts=${m.wilts} capped=${m.capped} n=${runs.length}`);
  }
  for (const sk of ['novice', 'casual']) {
    // R3/R4 (REVIEW-2 #9, REVIEW-3 #11): the pilot's Sprout run 1 (SPROUT1 options)
    if (!skills.includes(sk)) continue;
    const runs = [];
    for (let i = 0; i < seeds; i++) runs.push(runOne(sk, base + i * stride, SPROUT1));
    const m = medians(runs);
    if (sk === 'casual') med.sprout = m; else med.sproutNovice = m;
    console.log(`SNAP-BAL sprout1 ${sk} score=${m.score} seconds=${m.seconds.toFixed(1)} p10s=${pct(runs.map((r) => r.seconds), 0.1).toFixed(1)} snaps=${m.snaps} caught=${m.caught} stings=${m.stings} feasts=${m.feasts} chain=${m.chain} wilts=${m.wilts} capped=${m.capped}`);
  }
  if (skills.includes('novice')) {
    // R5 (REVIEW-4 #8): the novice pilot's Sprout runs 2 and 3 (the taper)
    for (const [tag, key, o] of [['sprout2', 'sprout2Novice', SPROUT2], ['sprout3', 'sprout3Novice', SPROUT3]]) {
      const runs = [];
      for (let i = 0; i < seeds; i++) runs.push(runOne('novice', base + i * stride, o));
      const m = medians(runs); med[key] = m;
      console.log(`SNAP-BAL ${tag} novice score=${m.score} seconds=${m.seconds.toFixed(1)} p10s=${pct(runs.map((r) => r.seconds), 0.1).toFixed(1)} snaps=${m.snaps} caught=${m.caught} stings=${m.stings} feasts=${m.feasts} chain=${m.chain} wilts=${m.wilts} capped=${m.capped}`);
    }
  }
  for (const sk of ['expert', 'perfect']) {
    // R5 (REVIEW-4 P2): pilotGiveUp changes the player model, not the game: the same runs without it, reported only
    if (!skills.includes(sk) || args.nogiveup === '0') continue;
    const runs = [];
    for (let i = 0; i < seeds; i++) runs.push(runOne(sk, base + i * stride, null, 'feed', false));
    const m = medians(runs);
    if (sk === 'expert') med.nogiveupExpert = m; else med.nogiveupPerfect = m;
    console.log(`SNAP-BAL nogiveup ${sk} score=${m.score} seconds=${m.seconds.toFixed(1)} snaps=${m.snaps} caught=${m.caught} stings=${m.stings} waves=${m.waves} wilts=${m.wilts} maxWilts=${m.maxWilts} capped=${m.capped} (with pilotGiveUp: wilts=${med[sk].wilts} capped=${med[sk].capped})`);
  }
  if (args.zenrows !== '0') {
    // R6: the Zen Bog, 4 seeds x 10 min per pilot (zenrows=0 skips it)
    med.zen = zenTable(Math.min(seeds, 4), base, stride, ['casual', 'perfect']);
    for (const [sk, m] of Object.entries(med.zen)) console.log(zenLine(sk, m));
  }
  for (const [name, ok] of checks(med)) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
}
main();
