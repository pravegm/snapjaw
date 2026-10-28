#!/usr/bin/env node
// Snapjaw balance simulator (Round 2): a line-by-line Node port of Snap/Core (Tuning, BugCatalog, WaveFactory,
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
//   Any Tuning value can be overridden: T.beeChanceDusk=0.5
//   Seeds are 1000 + 7919*i (the same as SnapTests/BalanceTests.swift); the pilot seed is seed*7+1.
//
// Numbers are not bit-identical to Swift (libm sin/cos/pow may differ in the last bit and the runs are chaotic), so
// the Swift test uses bands around these medians. The port omits hints, telemetry and the detector (the pilot
// drives TrapInput directly, as in the Swift harness).
// R2: bugs x1.8 with a body rim test, nectar clusters, crowd landings, hunger (wilt), the >= 2 chain rule,
// SessionOptions.startSnaps, spared-on-escape, and the casual pilot's fumbles (design/notes/core-R2.md).
'use strict';

// MARK: Tuning (mirror of Snap/Core/Tuning.swift)
const T = {
  // economy (GAME-DESIGN §5)
  startSnaps: 10, maxSnaps: 12, snapCost: 1, feastCount: 3, feastRefund: 1, bigFeastCount: 5, bigFeastRefund: 2,
  scarabRefund: 2, ladybirdRefund: 1, beeCost: 1, waspCost: 2, chainStep: 0.5, chainMaxMultiplier: 4,
  // bite (GAME-DESIGN §4)
  sipReactionFactor: 1.35, flyingReactionFactor: 0.55, rimReactionFactor: 0.6, catchableHeight: 0.6,
  lateWaveStart: 30, lateReactionDecay: 0.97, lateReactionFloor: 0.6, lateLingerDecay: 0.98, lateLingerFloor: 0.5,
  // waves (GAME-DESIGN §6)
  firstWaveTime: 1.2, waveDelayMin: 3.0, waveDelayMax: 4.5,
  noonWave: 7, duskWave: 15, nightWave: 23, deepNightWave: 31,
  nectarReseedWaves: 6, nectarMin: 6, nectarMax: 8, nectarRadiusMin: 12, nectarRadiusMax: 16,
  nectarClusterMin: 2, nectarClusterMax: 3, nectarRingMin: 40, nectarRingMax: 48, nectarClusterGap: 190, nectarArcMargin: 0.25, nectarHalfGap: 0.45,
  nectarClusterInner: 0.32, nectarClusterOuter: 0.55, nectarKeptClearance: 60, nectarCreaseClearance: 50,
  nectarTries: 30, crowdNearMin: 60, crowdNearMax: 140,
  lingerMorningMin: 6, lingerMorningMax: 8, lingerNoonMin: 5, lingerNoonMax: 7,
  lingerDuskMin: 4, lingerDuskMax: 6, lingerNightMin: 3.5, lingerNightMax: 5,
  beeFromWave: 3, beeChanceMorning: 0.5, beeChanceNoon: 0.4, beeChanceDusk: 0.5, beeChanceNight: 0.55,
  beeChanceNight2: 0.15, extraBeeEvery: 8, maxProtectedPerWave: 4, beeLingerFactor: 0.6,
  sizeFirstMin: 2, sizeFirstMax: 3, sizeMorningMin: 2, sizeMorningMax: 4, sizeNoonMin: 2, sizeNoonMax: 4,
  sizeDuskMin: 2, sizeDuskMax: 4, sizeNightMin: 2, sizeNightMax: 5,
  crowdFromWave: 3, crowdChance: 0.45, crowdSpread: 0.1, trickleMin: 0.6, trickleMax: 1.2, beeSpread: 2.5,
  passerChance: 0.12, beePasserChance: 0.15, maxWaveBugs: 7, maxBugsOnScreen: 18,
  scarabFromWave: 7, scarabChance: 1 / 12, gnatFromWave: 4, spotRadius: 0.75,
  // session
  tiredSeconds: 2.2, caughtSeconds: 0.5, openUpDelay: 1.0, crowdHintCount: 3, maxSubstep: 1 / 120,
  // R2 hunger (GAME-DESIGN §5)
  wiltMorning: 15, wiltNoon: 14, wiltDusk: 12, wiltNight: 10, hungryWarning: 3,
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
  // pilot (ROUND-1 "TrapPilot")
  pilotOvershoot: 6, pilotHold: 0.15, pilotReopen: 0.35, pilotIdleAngle: 160,
  noviceCreepChance: 0.25, noviceCreepDepth: 12, noviceCreepTime: 1.2,
  casualPatience: 7, expertPatience: 6, perfectPatience: 7,
  casualFumbleChance: 0.3, casualFumbleMin: 0.3, casualFumbleMax: 0.45,
  noviceBeeMiss: 0.6, casualBeeMiss: 0.25, expertBeeMiss: 0.02, perfectBeeHeight: 0.85,
  shooDepth: 11, shooTime: 0.5, shooHold: 0.1, expertShooAfter: 5, perfectShooAfter: 0,
  expertValue: 120, perfectValue: 400, perfectRestless: 0.7, expertRestless: 0.6,
};
const SNAP_DEPTH = 22, SNAP_START = 4, CREEP_DEPTH = 6, CREEP_DWELL = 0.45, REARM_RISE = 16;
const SCENE = { w: 952, h: 670 };

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
// species: [points, reaction, nerve, radius, firstPhase]
const INFO = {
  housefly: [10, 0.24, 7, 14, MORNING], gnat: [3, 0.32, 10, 7, MORNING], fruitFly: [6, 0.28, 9, 9, MORNING],
  bluebottle: [25, 0.16, 5, 16, NOON], ant: [8, 0.60, 15, 10, NOON], ladybird: [15, 0.30, 10, 14, NOON],
  grasshopper: [20, 0.22, 7, 18, NOON], moth: [20, 0.30, 9, 18, DUSK], mosquito: [12, 0.14, 4, 9, DUSK],
  dragonfly: [50, 0.12, 4, 24, DUSK], firefly: [35, 0.26, 8, 13, NIGHT], cricket: [25, 0.34, 11, 17, NIGHT],
  goldenScarab: [150, 0.40, 12, 20, NOON], bee: [0, 1.0, 8, 16, MORNING], bumblebee: [0, 1.0, 10, 22, NOON],
  wasp: [0, 1.0, 6, 16, DUSK],
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
function lateFactor(wave) {
  if (wave <= T.lateWaveStart) return 1;
  return Math.max(T.lateReactionFloor, Math.pow(T.lateReactionDecay, wave - T.lateWaveStart));
}
function reaction(inf, sipping, flying, onRim, wave) {
  let r = inf.reaction;
  if (!isProtected(inf.species)) r *= lateFactor(wave);
  if (sipping) r *= T.sipReactionFactor;
  if (flying) r *= T.flyingReactionFactor;
  if (onRim) r *= T.rimReactionFactor;
  return r;
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
  const out = [['housefly', 6], ['fruitFly', 3]];
  if (index >= T.gnatFromWave) out.push(['gnat', 2]);
  if (ph >= NOON) out.push(['bluebottle', 3], ['grasshopper', 2]);
  // ants and ladybirds are day bugs: they go home at dusk
  if (ph === NOON) out.push(['ant', 2], ['ladybird', 2]);
  if (ph >= DUSK) out.push(['moth', 3], ['mosquito', 3], ['dragonfly', 1.5]);
  if (ph >= NIGHT) out.push(['firefly', 3], ['cricket', 2.5]);
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
function makeWave(seed, index, g, nectar) {
  const r = new SeededRandom(waveSeed(seed, index));
  const ph = phaseForWave(index);
  let size;
  if (index <= 3) size = r.int(T.sizeFirstMin, T.sizeFirstMax);
  else if (ph === MORNING) size = r.int(T.sizeMorningMin, T.sizeMorningMax);
  else if (ph === NOON) size = r.int(T.sizeNoonMin, T.sizeNoonMax);
  else if (ph === DUSK) size = r.int(T.sizeDuskMin, T.sizeDuskMax);
  else size = r.int(T.sizeNightMin, T.sizeNightMax);
  const crowd = index >= T.crowdFromWave && r.chance(T.crowdChance);
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
        bugs.push({ species: s, entry: { x: fromLeft ? -30 : g.w + 30, y: y0 }, target: { x: fromLeft ? g.w + 40 : -40, y: y1 }, linger: 0, landsInTrap: false, groupOffset: base });
      } else {
        const cl = r.chance(0.5), cb = r.chance(0.5);
        const tx = cl ? r.range(30, 90) : g.w - r.range(30, 90);
        const ty = cb ? r.range(30, 90) : g.h - r.range(30, 90);
        const target = { x: tx, y: ty };
        const entry = edgeEntry(target, g, r);
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

// MARK: TrapSession
const A_ARR = 'arriving', A_WALK = 'walking', A_SIP = 'sipping', A_HOP = 'hopping', A_LEAVE = 'leaving', A_CAUGHT = 'caught', A_ESC = 'escaped', A_REL = 'released';
const M = { approach: 0, hover: 1, sip: 2, pause: 3, dash: 4, hop: 5, cross: 6, leave: 7, escape: 8, release: 9, caught: 10 };

class Session {
  constructor(seed, opts, mode) {
    this.seed = u64(BigInt(seed)); this.opts = opts; this.mode = mode || 'feed';
    this.g = new Geo(SCENE.w, SCENE.h);
    this.time = 0; this.phase = 'playing'; this.tiredElapsed = 0; this.tiredAt = 0;
    this.bugs = []; this.nextID = 1; this.pending = [];
    this.wave = 0; this.nextWaveAt = T.firstWaveTime; this.lastWaveAt = 0; this.dayPhase = MORNING;
    this.nectar = []; this.nextDropID = 0; this.reservedBy = new Map(); this.retiring = new Set();
    this.installNectar(0);
    this.snapsLeft = clamp(opts.startSnaps == null ? T.startSnaps : opts.startSnaps, 1, T.maxSnaps); this.score = 0; this.chain = 0;
    this.hunger = 0; this.hungrySent = false;
    this.prevArmed = true; this.prevClosure = 0;
    this.stats = { snaps: 0, caught: 0, stings: 0, feasts: 0, dry: 0, bestBite: 0, biggest: 0, longestChain: 0, spared: 0, wilts: 0 };
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
    if (this.phase === 'playing') {
      if (input.snap) this.bite(input.snap);
      if (input.creeping && this.phase === 'playing') this.creep(input.closure);
    }
    this.prevArmed = input.armed; this.prevClosure = input.closure;
    const n = Math.max(1, Math.ceil(d / T.maxSubstep - 1e-9));
    const h = d / n;
    for (let i = 0; i < n; i++) { this.tick(h); if (this.phase === 'finished') break; }
  }
  tick(h) {
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
    if (this.phase === 'playing' && this.opts.snapsRunOut && this.opts.hunger !== false) {
      const w = wiltSeconds(this.dayPhase);
      this.hunger += h / w;
      if (!this.hungrySent && (1 - this.hunger) * w <= T.hungryWarning) this.hungrySent = true;
      if (this.hunger >= 1) {
        this.hunger = 0; this.hungrySent = false; this.stats.wilts += 1;
        this.snapsLeft = Math.max(this.snapsLeft - 1, 0);
        if (this.snapsLeft === 0) this.becomeTired();
      }
    }
    if (this.phase === 'tired') {
      this.tiredElapsed += h;
      if (this.tiredElapsed >= T.tiredSeconds) this.phase = 'finished';
    }
  }
  becomeTired() {
    this.phase = 'tired'; this.tiredElapsed = 0; this.tiredAt = this.time; this.pending = [];
    for (const b of this.bugs) { if (b.mode === M.caught || b.mode === M.leave || b.mode === M.escape || b.mode === M.release) continue; this.takeOff(b, M.leave); }
  }
  startWave() {
    this.wave += 1;
    const idx = this.wave;
    if (idx > 1 && (idx - 1) % T.nectarReseedWaves === 0) this.installNectar(Math.floor((idx - 1) / T.nectarReseedWaves));
    const recipe = this.mode === 'attract' ? ((idx - 1) % (T.nightWave + 5)) + 1 : idx;
    const spec = makeWave(this.seed, recipe, this.g, this.nectar);
    this.dayPhase = spec.phase;
    const at = this.nextWaveAt;
    for (const s of spec.bugs) this.pending.push({ at: at + s.groupOffset, spec: s });
    this.lastWaveAt = at;
    this.nextWaveAt = at + waveDelay(this.seed, recipe + 1);
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
  clampIn(p, maxR) {
    const r = this.g.nr(p);
    if (r <= maxR || r === 0) return p;
    const k = maxR / r;
    return { x: this.g.cx + (p.x - this.g.cx) * k, y: this.g.cy + (p.y - this.g.cy) * k };
  }
  findSpot(b, x, y, dMin, dMax, maxR) {
    let best = this.clampIn({ x, y }, maxR);
    let bestScore = dMin <= 0 ? this.spotScore(b, best) : -Infinity;
    if (bestScore >= 0) return best;
    for (let i = 0; i < T.spotTries; i++) {
      const t = b.rng.range(0, 2 * Math.PI);
      // R2: the search reaches at least this bug's own spacing need (radii are x1.8)
      const dd = b.rng.range(Math.max(dMin, 8), Math.max(dMax, 20, b.info.radius * 2 + T.landSpacing + 10));
      const p = this.clampIn({ x: x + Math.cos(t) * dd, y: y + Math.sin(t) * dd }, maxR);
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
    return this.findSpot(b, b.tx, b.ty, 0, 50, T.landMaxRadius);
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
      const p = this.findSpot(b, want.x, want.y, 0, 40, T.landMaxRadius);
      b.mode = M.hop; b.fx = b.x; b.fy = b.y; b.tx = p.x; b.ty = p.y; b.el = 0; b.hovering = false;
      const dist = Math.hypot(p.x - b.x, p.y - b.y);
      b.dur = darter ? T.dartTime : clamp(dist / T.hopSpeed, T.hopTimeMin, T.hopTimeMax);
      return;
    }
    if (b.wantsNectar && b.dropID === null) {
      let best = null, bd = T.nectarSeekRadius;
      for (const d of this.nectar) {
        if (this.retiring.has(d.id) || this.reservedBy.has(d.id)) continue;
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
    const p = this.findSpot(b, want.x, want.y, 0, 30, T.landMaxRadius);
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
  creep(closure) {
    for (const b of this.bugs) {
      if (!this.inTrap(b)) continue;
      if (b.mode === M.leave) continue;
      if (b.info.nerve <= closure) {
        b.restless = 1;
        this.takeOff(b, M.leave);
      }
    }
  }
  bite(snap) {
    const d = snap.duration;
    const caught = [], stingers = []; let escaped = 0;
    for (const b of this.bugs) {
      if (!this.inTrap(b)) continue;
      const a = this.activityOf(b);
      const flying = a === A_ARR || a === A_HOP;
      if (a === A_ARR && b.height >= T.catchableHeight) continue;
      if (!(a === A_ARR || a === A_WALK || a === A_SIP || a === A_HOP)) continue;
      const r = reaction(b.info, a === A_SIP, flying, onRimBody(this.g, b, b.info.radius), this.wave);
      if (d <= r) {
        if (isProtected(b.species)) { stingers.push(b.species); this.takeOff(b, M.release); }
        else { caught.push(b.species); this.freeDrop(b); b.timer = b.height; b.mode = M.caught; b.el = 0; b.fx = b.x; b.fy = b.y; }
      } else {
        escaped += 1; this.takeOff(b, M.escape);
      }
    }
    this.stats.snaps += 1;
    if (caught.length >= 1) { this.hunger = 0; this.hungrySent = false; }
    const n = caught.length;
    let sum = 0; for (const s of caught) sum += info(s).points;
    const mult = chainMultiplier(this.chain);
    const points = Math.round(sum * n * mult);
    let back = 0;
    if (n >= T.bigFeastCount) back += T.bigFeastRefund; else if (n >= T.feastCount) back += T.feastRefund;
    for (const s of caught) { if (s === 'goldenScarab') back += T.scarabRefund; if (s === 'ladybird') back += T.ladybirdRefund; }
    let lost = 0;
    if (this.opts.stingCosts) for (const s of stingers) lost += s === 'wasp' ? T.waspCost : T.beeCost;
    this.score += points;
    this.stats.caught += n; this.stats.stings += stingers.length;
    if (n >= T.feastCount) this.stats.feasts += 1;
    if (n === 0 && stingers.length === 0) this.stats.dry += 1;
    this.stats.bestBite = Math.max(this.stats.bestBite, points); this.stats.biggest = Math.max(this.stats.biggest, n);
    // R2 chain rule: a clean bite of >= 2 adds a step, a clean 1-bug bite holds it, a dry snap or a stinger breaks it.
    if (n >= T.chainMinBite && stingers.length === 0) { this.chain += 1; this.stats.longestChain = Math.max(this.stats.longestChain, this.chain); }
    else if (!(n >= 1 && stingers.length === 0)) this.chain = 0;
    if (this.opts.snapsRunOut) {
      this.snapsLeft = clamp(this.snapsLeft - T.snapCost - lost + back, 0, T.maxSnaps);
      if (this.snapsLeft === 0) this.becomeTired();
    }
  }
  snapshot() {
    const bugs = this.bugs.map((b) => {
      const a = this.activityOf(b);
      const inT = this.inTrap(b);
      return { id: b.id, species: b.species, x: b.x, y: b.y, activity: a, height: b.height, inTrap: inT, onRim: inT && onRimBody(this.g, b, b.info.radius), restless: b.restless };
    });
    return { phase: this.phase, time: this.time, bugs, snapsLeft: this.snapsLeft, wave: this.wave, score: this.score, hunger: this.hunger, dayPhase: this.dayPhase };
  }
}

// MARK: TrapPilot
const PROFILE = {
  novice: { dmin: 0.22, dmax: 0.40, delayMin: 0.35, delayMax: 0.6, beeMiss: T.noviceBeeMiss },
  casual: { dmin: 0.14, dmax: 0.24, delayMin: 0.25, delayMax: 0.45, beeMiss: T.casualBeeMiss },
  expert: { dmin: 0.10, dmax: 0.15, delayMin: 0.15, delayMax: 0.3, beeMiss: T.expertBeeMiss },
  perfect: { dmin: 0.08, dmax: 0.08, delayMin: 0.1, delayMax: 0.1, beeMiss: 0 },
};
class Pilot {
  constructor(skill, seed) {
    this.skill = skill; this.p = PROFILE[skill]; this.rng = new SeededRandom(seed);
    this.stage = 0; // 0 idle, 1 down, 2 hold, 3 up
    this.closure = 0; this.armed = true; this.el = 0; this.d = 0.2; this.creepy = false; this.peak = 0;
    this.t4 = null; this.t6 = null; this.decideAt = null; this.beeSince = null; this.missed = new Map(); this.lastSnap = 0; this.plannedD = this.p.dmin;
  }
  planDuration() {
    // R2: a casual hand sometimes fumbles a snap (slow), which is what breaks its chains besides the bees.
    if (this.skill === 'casual' && this.rng.chance(T.casualFumbleChance)) return this.rng.range(T.casualFumbleMin, T.casualFumbleMax);
    return this.p.dmin === this.p.dmax ? this.p.dmin : this.rng.range(this.p.dmin, this.p.dmax);
  }
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
      const r = reaction(inf, a === A_SIP, a === A_ARR || a === A_HOP, b.onRim, snap.wave);
      if (d <= r) { n += 1; sum += inf.points; }
    }
    return { landed, maxPts, n, value: sum * n, arriving, restless };
  }
  wants(snap, time) {
    const v = this.view(snap, this.plannedD);
    const waited = time - this.lastSnap;
    let want = false;
    switch (this.skill) {
      case 'novice': want = v.landed >= 1; break;
      case 'casual': want = v.landed >= 3 || (v.landed >= 2 && v.arriving === 0) || (v.landed >= 1 && v.maxPts >= 20) || (v.landed >= 1 && waited >= T.casualPatience); break;
      case 'expert': want = v.n >= 3 || (v.n >= 1 && v.value >= T.expertValue) || (v.n >= 2 && v.restless >= T.expertRestless) || (v.n >= 1 && waited >= T.expertPatience); break;
      default: want = v.n >= 5 || (v.n >= 3 && v.arriving === 0) || (v.n >= 3 && v.restless >= T.perfectRestless) || v.value >= T.perfectValue || (v.n >= 1 && waited >= T.perfectPatience); break;
    }
    if (!want) return false;
    return !this.beeBlocks(snap);
  }
  step(dt, time, snap) {
    let fired = null;
    const prev = this.closure;
    if (this.stage === 0) {
      this.closure = 0;
      if (snap.phase === 'playing' && this.armed) {
        // shoo: expert / perfect clear a bee that has sat in the trap too long with a slow creep (no snap)
        const shooAfter = this.skill === 'perfect' ? T.perfectShooAfter : (this.skill === 'expert' ? T.expertShooAfter : 0);
        if (this.beeSitting(snap)) { if (this.beeSince === null) this.beeSince = time; } else this.beeSince = null;
        if (shooAfter > 0 && this.beeSince !== null && time - this.beeSince >= shooAfter) {
          this.stage = 4; this.el = 0; this.peak = T.shooDepth; this.decideAt = null; this.beeSince = null;
        } else if (this.decideAt === null) {
          if (this.wants(snap, time)) { this.decideAt = time + (this.p.delayMin === this.p.delayMax ? this.p.delayMin : this.rng.range(this.p.delayMin, this.p.delayMax)); }
        } else if (time >= this.decideAt) {
          this.decideAt = null;
          if (this.wants(snap, time)) {
            this.stage = 1; this.el = 0; this.d = this.plannedD; this.t4 = null;
            this.creepy = this.skill === 'novice' && this.rng.chance(T.noviceCreepChance);
            this.peak = SNAP_DEPTH + T.pilotOvershoot;
            this.plannedD = this.planDuration();
          }
        }
      }
    } else if (this.stage === 4) {
      // shoo down: a slow close to shooDepth, held until the creep has shown for shooHold
      this.el += dt;
      this.closure = Math.min(this.peak, this.peak * this.el / T.shooTime);
      if (this.t6 !== null && time - this.t6 >= CREEP_DWELL + T.shooHold) { this.stage = 3; this.el = 0; }
    } else if (this.stage === 1) {
      this.el += dt;
      const rate = (SNAP_DEPTH - SNAP_START) / this.d;
      if (this.creepy && this.closure < T.noviceCreepDepth && this.el <= T.noviceCreepTime) {
        this.closure = Math.min(T.noviceCreepDepth, T.noviceCreepDepth * this.el / T.noviceCreepTime);
      } else {
        this.closure = Math.min(this.peak, this.closure + rate * dt);
      }
      if (this.t4 === null && this.closure >= SNAP_START) this.t4 = time - dt + dt * (SNAP_START - prev) / Math.max(1e-9, this.closure - prev);
      if (this.armed && this.closure >= SNAP_DEPTH) {
        const t22 = time - dt + dt * (SNAP_DEPTH - prev) / Math.max(1e-9, this.closure - prev);
        fired = { duration: Math.max(0, t22 - (this.t4 === null ? t22 : this.t4)), time };
        this.armed = false; this.lastSnap = time;
      }
      if (this.closure >= this.peak) { this.stage = 2; this.el = 0; }
    } else if (this.stage === 2) {
      this.el += dt;
      if (this.el >= T.pilotHold) { this.stage = 3; this.el = 0; }
    } else {
      this.el += dt;
      this.closure = Math.max(0, this.peak * (1 - this.el / T.pilotReopen));
      if (!this.armed && this.closure <= this.peak - REARM_RISE) this.armed = true;
      if (this.closure <= 0) { this.stage = 0; this.closure = 0; this.armed = true; }
    }
    if (this.closure > CREEP_DEPTH && this.armed) { if (this.t6 === null) this.t6 = time; } else this.t6 = null;
    const creeping = this.t6 !== null && this.armed && time - this.t6 >= CREEP_DWELL;
    return { closure: this.closure, armed: this.armed, creeping, snap: fired, angle: T.pilotIdleAngle - this.closure };
  }
}

// MARK: SnapDetector (mirror of Snap/Core/SnapDetector.swift; not used by the balance runs, checked by detector=1)
const D = { snapDepth: 22, snapStartDepth: 4, snapCancelDepth: 2, creepDepth: 6, creepDwell: 0.45, rearmRise: 16,
  rearmAngle: 150, rearmMinRise: 4, refWindow: 0.6, refFallRate: 25, creepWindow: 3.0, creepRefFallRate: 6,
  tooFlatAngle: 174, settleWindow: 0.6, attemptWindow: 0.25 };
class RollingMax {
  constructor(window, fall) { this.window = window; this.fall = fall; this.samples = []; this.value = 0; this.last = 0; }
  reset(t, a) { this.samples = [{ t, a }]; this.value = a; this.last = t; }
  add(t, a) { this.samples.push({ t, a }); this.update(t); }
  update(t) {
    while (this.samples.length > 1 && this.samples[0].t < t - this.window) this.samples.shift();
    let w = -Infinity; for (const s of this.samples) w = Math.max(w, s.a);
    const dt = Math.max(0, t - this.last); this.last = Math.max(this.last, t);
    if (w >= this.value) this.value = w; else this.value = Math.max(w, this.value - this.fall * dt);
  }
}
class SnapDetector {
  constructor() {
    this.fast = new RollingMax(D.refWindow, D.refFallRate); this.slow = new RollingMax(D.creepWindow, D.creepRefFallRate);
    this.has = false; this.angle = 0; this.lastC = 0; this.prevTime = 0; this.armed = true; this.attempt = false; this.ts = 0;
    this.lowest = 0; this.snapRef = 0; this.pending = null; this.creepSince = null;
    this.recent = []; this.settling = false; this.settlePeak = 0; this.settleUntil = 0;
  }
  startSettle(t, a) { this.settling = true; this.settlePeak = a; this.settleUntil = t + D.settleWindow; }
  recentRise(c) { return this.recent.length > 0 ? c - this.recent[0].c : c; }
  static cross(t0, c0, t1, c1, thr) { if (c1 <= c0) return t1; return clamp(t0 + (t1 - t0) * (thr - c0) / (c1 - c0), t0, t1); }
  ingest(angle, time) {
    if (!isFinite(angle) || !isFinite(time)) return null;
    if (!this.has) {
      this.has = true; this.fast.reset(time, angle); this.slow.reset(time, angle);
      this.angle = angle; this.lastC = 0; this.prevTime = time; this.recent = [{ t: time, c: 0 }]; this.startSettle(time, angle); return null;
    }
    this.fast.add(time, angle); this.slow.add(time, angle);
    let c = this.fast.value - angle;
    let fired = null;
    if (this.armed) {
      this.recent.push({ t: time, c });
      while (this.recent.length >= 2 && this.recent[1].t <= time - D.attemptWindow) this.recent.shift();
      if (!this.attempt) {
        if (c >= D.snapStartDepth) { this.attempt = true; this.ts = SnapDetector.cross(this.prevTime, this.lastC, time, c, D.snapStartDepth); }
      } else if (c < D.snapCancelDepth) this.attempt = false;
      else if (c < D.snapDepth && this.recentRise(c) < D.snapStartDepth) this.ts = time; // QA-1 #6: not snapping (a drift or a hold): restart the clock
      if (this.attempt && c >= D.snapDepth) {
        const tc = SnapDetector.cross(this.prevTime, this.lastC, time, c, D.snapDepth);
        fired = { duration: Math.max(0, tc - this.ts), time };
        this.pending = fired; this.armed = false; this.attempt = false; this.lowest = angle; this.snapRef = this.fast.value;
        this.creepSince = null; this.recent = [];
      }
    } else {
      this.lowest = Math.min(this.lowest, angle);
      const rise = angle - this.lowest;
      if (rise >= D.rearmRise || (angle >= D.rearmAngle && rise >= D.rearmMinRise)) {
        this.armed = true; this.attempt = false; this.fast.reset(time, angle); this.slow.reset(time, angle); c = 0;
        this.creepSince = null; this.recent = [{ t: time, c: 0 }]; this.startSettle(time, angle);
      }
    }
    // QA-1 #5: after a re-arm (or the first sample, or while flat) the creep reference follows the hand while it opens
    // and for settleWindow after its peak, so an overshoot that settles back never reads as a creep.
    if (angle >= D.tooFlatAngle) { if (!this.settling) this.startSettle(time, angle); this.settleUntil = Math.max(this.settleUntil, time + D.settleWindow); }
    if (this.settling) {
      if (angle > this.settlePeak) { this.settlePeak = angle; this.settleUntil = time + D.settleWindow; }
      if (time <= this.settleUntil) this.slow.reset(time, angle); else this.settling = false;
    }
    this.lastC = c; this.prevTime = time; this.angle = angle;
    this.updateCreep(time);
    return fired;
  }
  creepDepthNow() { return this.has ? Math.max(0, this.slow.value - this.angle) : 0; }
  updateCreep(time) {
    if (!this.has) return;
    if (this.armed && this.creepDepthNow() > D.creepDepth) { if (this.creepSince === null) this.creepSince = time; }
    else this.creepSince = null;
  }
  input(time) {
    if (this.has) { this.fast.update(time); this.slow.update(time); this.updateCreep(time); }
    let closure = this.has ? Math.max(0, this.fast.value - this.angle) : 0;
    if (this.has && !this.armed) closure = Math.max(closure, this.snapRef - this.angle);
    const creeping = this.creepSince !== null && time - this.creepSince > D.creepDwell;
    if (creeping) closure = Math.max(closure, this.creepDepthNow());
    const snap = this.pending; this.pending = null;
    return { closure, armed: this.armed, creeping, snap, tooFlat: this.has && this.angle >= D.tooFlatAngle, angle: this.has ? this.angle : null };
  }
}
function detectorChecks() {
  const out = [];
  { // 25 degrees in 0.12 s at 30 Hz fires once, on the crossing sample
    const d = new SnapDetector(); let fires = 0, dur = 0, at = -1;
    for (let i = 0; i <= 30; i++) { if (d.ingest(160, i / 30)) fires += 1; }
    for (let i = 1; i <= 8; i++) { const t = 1 + i / 30; const a = 160 - Math.min(25, 25 * (i / 30) / 0.12); const r = d.ingest(a, t); if (r) { fires += 1; dur = r.duration; at = i; } }
    out.push([`fast snap fires once (fires=${fires}, d=${dur.toFixed(3)}, sample=${at})`, fires === 1 && dur >= 0.08 && dur <= 0.16 && at === 4]);
  }
  { // 160 -> 128 over 3 s: creeps within ~1 s, closure >= 15 at the end, never snaps
    const d = new SnapDetector(); let fires = 0, creepAt = -1, endClosure = 0;
    for (let i = 0; i <= 30; i++) d.ingest(160, i / 30);
    for (let i = 1; i <= 90; i++) {
      const t = 1 + i / 30; if (d.ingest(160 - 32 * i / 90, t)) fires += 1;
      const inp = d.input(t + 0.001); if (inp.snap) fires += 1; if (inp.creeping && creepAt < 0) creepAt = t - 1; endClosure = inp.closure;
    }
    out.push([`slow close creeps (at ${creepAt.toFixed(2)} s, end closure ${endClosure.toFixed(1)}, fires ${fires})`, fires === 0 && creepAt > 0 && creepAt <= 1.2 && endClosure >= 15]);
  }
  { // resting jitter +-1.5 never snaps or creeps
    const d = new SnapDetector(); const r = new SeededRandom(5); let bad = 0;
    for (let i = 0; i < 600; i++) { const t = i / 30; if (d.ingest(160 + r.range(-1.5, 1.5), t)) bad += 1; const inp = d.input(t); if (inp.creeping || inp.snap) bad += 1; }
    out.push([`jitter never snaps or creeps (bad=${bad})`, bad === 0]);
  }
  { // re-arm after rising 16 from the lowest point
    const d = new SnapDetector(); let fires = 0, rearmAt = null;
    for (let i = 0; i <= 30; i++) d.ingest(160, i / 30);
    const path = [154, 146, 138, 130, 126, 126, 130, 134, 138, 142, 146];
    path.forEach((a, k) => { const t = 1 + (k + 1) / 30; if (d.ingest(a, t)) fires += 1; if (rearmAt === null && d.armed && fires === 1) rearmAt = a; });
    out.push([`re-arms 16 above the lowest (fires=${fires}, at ${rearmAt})`, fires === 1 && rearmAt === 142]);
  }
  { // QA-1 #5: a reopen that overshoots (172) and settles (165) never creeps
    const d = new SnapDetector(); let creeps = 0, fires = 0; let t = 0;
    for (let i = 0; i <= 30; i++) { t = i / 30; d.ingest(165, t); }
    const path = [155, 145, 138, 135, 140, 148, 156, 164, 170, 172, 171, 169, 167, 166, 165];
    for (const a of path) { t += 1 / 30; if (d.ingest(a, t)) fires += 1; }
    for (let i = 0; i < 150; i++) { t += 1 / 30; d.ingest(165 + (i % 2 ? 0.4 : -0.4), t); const inp = d.input(t); if (inp.creeping) creeps += 1; }
    out.push([`overshoot then settle never creeps (creeping frames=${creeps}, fires=${fires})`, creeps === 0 && fires === 1 && d.armed]);
  }
  { // QA-1 #6: a steady 8 deg/s drift then a quick snap is timed from the snap, not the drift
    const d = new SnapDetector(); let t = 0, dur = -1;
    for (let i = 0; i <= 30; i++) { t = i / 30; d.ingest(165, t); }
    let a = 165;
    for (let i = 0; i < 60; i++) { t += 1 / 30; a -= 8 / 30; d.ingest(a, t); }
    for (let i = 0; i < 4; i++) { t += 1 / 30; a -= 25 / 3; const r = d.ingest(a, t); if (r && dur < 0) dur = r.duration; }
    out.push([`snap after a drift is timed from the snap (d=${dur.toFixed(3)})`, dur >= 0 && dur <= 0.15]);
  }
  return out;
}

// MARK: Runs
function runOne(skill, seed) {
  const s = new Session(seed, { snapsRunOut: true, waves: true, stingCosts: true }, 'feed');
  const pilot = new Pilot(skill, u64(BigInt(seed) * 7n + 1n));
  const dt = 1 / 60; let t = 0; let frames = 0;
  while (s.phase !== 'finished' && frames < 60 * 600) {
    const input = pilot.step(dt, t, s.snapshot());
    s.step(dt, input);
    t += dt; frames += 1;
  }
  return { score: s.score, seconds: s.phase === 'finished' ? s.tiredAt : s.time, snaps: s.stats.snaps, caught: s.stats.caught,
    stings: s.stats.stings, feasts: s.stats.feasts, dry: s.stats.dry, waves: s.wave, chain: s.stats.longestChain,
    biggest: s.stats.biggest, spared: s.stats.spared, wilts: s.stats.wilts, capped: s.phase !== 'finished' };
}
function pct(a, p) { if (a.length === 0) return 0; const s = a.slice().sort((x, y) => x - y); const pos = (s.length - 1) * p; const lo = Math.floor(pos); const hi = Math.min(s.length - 1, lo + 1); return s[lo] + (s[hi] - s[lo]) * (pos - lo); }
const KEYS = ['score', 'seconds', 'snaps', 'caught', 'stings', 'feasts', 'dry', 'waves', 'chain', 'biggest', 'spared', 'wilts'];
function medians(runs) {
  const m = {};
  for (const k of KEYS) m[k] = pct(runs.map((r) => r[k]), 0.5);
  m.maxStings = Math.max(...runs.map((r) => r.stings));
  m.capped = runs.filter((r) => r.capped).length;
  return m;
}
// MARK: Targets (mirror of SnapTests/BalanceTests.swift)
function checks(med) {
  const out = [];
  const c = med.casual, n = med.novice, e = med.expert, p = med.perfect;
  if (c) {
    out.push([`casual seconds 100-240 (${c.seconds.toFixed(1)})`, c.seconds >= 100 && c.seconds <= 240]);
    out.push([`casual snaps 18-45 (${c.snaps})`, c.snaps >= 18 && c.snaps <= 45]);
    out.push([`casual longest chain 3-6 (${c.chain})`, c.chain >= 3 && c.chain <= 6]);
  }
  if (p) out.push([`perfect seconds 240-420 (${p.seconds.toFixed(1)})`, p.seconds >= 240 && p.seconds <= 420]);
  if (n) out.push([`novice stings >= 1 (${n.stings})`, n.stings >= 1]);
  if (p) out.push([`perfect never stung (max ${p.maxStings})`, p.maxStings === 0]);
  if (n && c) out.push([`novice < casual (${n.score} < ${c.score})`, n.score < c.score]);
  if (c && e) out.push([`casual < expert (${c.score} < ${e.score})`, c.score < e.score]);
  if (e && p) out.push([`expert <= perfect (${e.score} <= ${p.score})`, e.score <= p.score]);
  for (const sk of ['novice', 'casual', 'expert', 'perfect']) if (med[sk]) out.push([`${sk} never capped (${med[sk].capped})`, med[sk].capped === 0]);
  return out;
}
function main() {
  const seeds = Number(args.seeds || 16);
  const base = Number(args.base || 1000), stride = Number(args.stride || 7919);
  const skills = (args.skills || 'novice,casual,expert,perfect').split(',');
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
      const bad = checks(med).filter(([, ok]) => !ok);
      if (bad.length) { fails += 1; for (const [name] of bad) { const k = name.replace(/ \(.*\)$/, ''); failNames[k] = (failNames[k] || 0) + 1; } }
      console.log(`window ${w}: ` + skills.map((sk) => `${sk} ${med[sk].score}/${med[sk].seconds.toFixed(0)}s/${med[sk].snaps}sn/${med[sk].stings}st`).join(' | '));
    }
    console.log(`windows failing a check: ${fails}/${nw}`, JSON.stringify(failNames));
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
    console.log(`SNAP-BAL skill=${sk} score=${m.score} p10=${pct(runs.map((r) => r.score), 0.1).toFixed(0)} p90=${pct(runs.map((r) => r.score), 0.9).toFixed(0)} seconds=${m.seconds.toFixed(1)} snaps=${m.snaps} caught=${m.caught} stings=${m.stings} maxStings=${m.maxStings} feasts=${m.feasts} dry=${m.dry} waves=${m.waves} chain=${m.chain} biggest=${m.biggest} spared=${m.spared} wilts=${m.wilts} capped=${m.capped} n=${runs.length}`);
  }
  for (const [name, ok] of checks(med)) console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`);
}
main();
