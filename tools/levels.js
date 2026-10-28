// Snapjaw levels (R8, ROUND-8 §4): THE source of the 30 hand-made levels. tools/balance-sim.js plays them
// (`node tools/balance-sim.js levels=1`) and tools/levels-gen.js writes Snap/Core/LevelData.swift from this file:
//   node tools/levels-gen.js
// Never edit LevelData.swift by hand.
//
// Each level:
//   id, world (1 Morning Bog, 2 Dusk, 3 Night), title, goalText (what the intro card says),
//   goal: { kind: 'catch', n }                 catch n bugs (any)
//         { kind: 'species', species: [...], n } catch n of these species
//         { kind: 'bite', n }                  one bite of n or more bugs
//         { kind: 'spare', n, catchN }         spare n bees (protected bugs leave the trap uneaten) and catch catchN
//   noSting: true = biting a bee, bumblebee or wasp fails the level at once
//   bites: the bite limit (null = none), time: the time limit in session seconds (null = none)
//   stars: [two, three]: 2 stars at most `two` bites used, 3 stars at most `three` (passing is 1 star)
//   clean3: true = 3 stars also need a clean level (no bug escaped a bite or fled a close)
//   pace: the wave the bugs' reactions use (TrapRules.lateFactor: < 7 the sleepy morning x1.3, 7..30 x1, then faster)
//   bugs: [ { s: species, at: seconds after the round opens, u, v: the spot (-1..1 across / up the trap; |u| >= 0.3
//           keeps off the midrib), linger: seconds it stays after landing, sip: true = it sips the nearest nectar } ]
'use strict';

const B = (s, at, u, v, linger, sip) => ({ s, at, u, v, linger, sip: !!sip });

const LEVELS = [
  // ---- World 1: Morning Bog (teaches) ----
  { id: 1, world: 1, title: 'First Bite', goalText: 'Shut the phone on the fly',
    goal: { kind: 'catch', n: 1 }, noSting: false, bites: 3, time: null, stars: [2, 1], pace: 1,
    bugs: [B('housefly', 0.8, -0.45, 0.1, 60, true)] },
  { id: 2, world: 1, title: 'Fast!', goalText: 'Catch 2 flies. Shut it fast',
    goal: { kind: 'catch', n: 2 }, noSting: false, bites: 4, time: null, stars: [3, 2], pace: 1,
    bugs: [B('housefly', 0.8, -0.5, 0.25, 60, true), B('fruitFly', 4.5, 0.5, -0.2, 60, true)] },
  { id: 3, world: 1, title: 'Wait for Two', goalText: 'One bite, 2 bugs',
    goal: { kind: 'bite', n: 2 }, noSting: false, bites: 3, time: null, stars: [2, 1], pace: 1,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 60, true), B('housefly', 3.5, 0.5, 0.1, 60, true)] },
  { id: 4, world: 1, title: 'Bee!', goalText: 'Catch 2 flies. Never bite the bee',
    goal: { kind: 'catch', n: 2 }, noSting: true, bites: 4, time: null, stars: [2, 1], pace: 1,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 60, true), B('bee', 1.6, 0.45, 0.15, 3, true),
      B('fruitFly', 2.2, 0.5, -0.3, 60, true)] },
  { id: 5, world: 1, title: 'A Crowd', goalText: 'One bite, 3 bugs: the Feast',
    goal: { kind: 'bite', n: 3 }, noSting: false, bites: 3, time: null, stars: [2, 1], pace: 1,
    bugs: [B('housefly', 0.8, -0.5, 0.25, 60, true), B('fruitFly', 1.0, -0.45, -0.2, 60, true),
      B('housefly', 1.2, 0.5, 0.1, 60, true)] },
  { id: 6, world: 1, title: 'Marching Ants', goalText: 'Catch 4 ants',
    goal: { kind: 'species', species: ['ant'], n: 4 }, noSting: false, bites: 4, time: null, stars: [4, 4], pace: 1,
    bugs: [B('ant', 0.5, -0.45, -0.3, 30), B('ant', 1.1, -0.5, -0.1, 30), B('ant', 1.7, 0.45, -0.25, 30),
      B('ant', 2.3, 0.5, -0.05, 30), B('housefly', 3, 0.55, 0.4, 12, true)] },
  { id: 7, world: 1, title: 'Gnat Cloud', goalText: 'One bite, 4 bugs',
    goal: { kind: 'bite', n: 4 }, noSting: false, bites: 4, time: null, stars: [2, 1], pace: 1,
    bugs: [B('gnat', 0.8, -0.5, 0.2, 14), B('gnat', 0.9, -0.42, 0.3, 14), B('gnat', 1.0, -0.55, 0.05, 14),
      B('gnat', 1.1, -0.4, -0.1, 14), B('gnat', 1.2, -0.6, 0.35, 14), B('housefly', 6, 0.5, 0, 20, true),
      B('housefly', 6.5, 0.45, 0.3, 20, true), B('fruitFly', 7, 0.55, -0.25, 20, true), B('fruitFly', 7.4, 0.4, -0.05, 20, true)] },
  { id: 8, world: 1, title: 'Lucky Ladybird', goalText: 'Catch the ladybird and 3 more',
    goal: { kind: 'catch', n: 4, must: ['ladybird'] }, noSting: false, bites: 4, time: null, stars: [3, 2], pace: 1,
    bugs: [B('ladybird', 1.0, 0.45, 0.2, 10, true), B('housefly', 1.2, -0.5, 0.2, 25, true),
      B('fruitFly', 3, -0.45, -0.25, 25, true), B('housefly', 5, 0.5, -0.2, 25, true), B('gnat', 7, -0.5, 0.35, 15),
      B('gnat', 7.1, -0.4, 0.4, 15)] },
  { id: 9, world: 1, title: 'Bee in the Crowd', goalText: 'Catch 4. Wait for the bee to go',
    goal: { kind: 'catch', n: 4 }, noSting: true, bites: 4, time: null, stars: [2, 1], pace: 3,
    bugs: [B('housefly', 1.0, -0.5, 0.2, 20, true), B('fruitFly', 1.1, -0.42, -0.2, 20, true),
      B('bee', 1.4, -0.45, 0.0, 4, true), B('housefly', 1.6, 0.5, 0.15, 20, true), B('fruitFly', 1.8, 0.45, -0.25, 20, true),
      B('housefly', 9, 0.5, 0.3, 14, true)] },
  { id: 10, world: 1, title: 'Morning Exam', goalText: '8 bugs in 5 bites',
    goal: { kind: 'catch', n: 8 }, noSting: true, bites: 5, time: null, stars: [4, 3], pace: 5,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 14, true), B('fruitFly', 1.0, -0.45, -0.25, 14, true),
      B('housefly', 3.5, 0.5, 0.2, 14, true), B('bee', 4, 0.45, -0.1, 3, true), B('fruitFly', 4.2, 0.55, -0.3, 14, true),
      B('gnat', 7, -0.5, 0.3, 12), B('gnat', 7.1, -0.42, 0.38, 12), B('gnat', 7.2, -0.58, 0.22, 12),
      B('housefly', 10, 0.5, 0.1, 12, true), B('fruitFly', 10.3, 0.42, -0.2, 12, true), B('housefly', 13, -0.5, -0.1, 10, true)] },

  // ---- World 2: Dusk ----
  { id: 11, world: 2, title: 'The Moth', goalText: 'Catch the moth before it leaves',
    goal: { kind: 'species', species: ['moth'], n: 1 }, noSting: false, bites: 3, time: null, stars: [2, 1], pace: 15,
    bugs: [B('housefly', 0.8, 0.5, 0.2, 10, true), B('moth', 2.0, -0.4, 0.1, 5), B('fruitFly', 2.6, 0.45, -0.25, 10, true)] },
  { id: 12, world: 2, title: 'Whine', goalText: 'Catch 2 mosquitoes',
    goal: { kind: 'species', species: ['mosquito'], n: 2 }, noSting: false, bites: 5, time: null, stars: [3, 2], pace: 15,
    bugs: [B('mosquito', 0.8, -0.5, 0.2, 9, true), B('mosquito', 1.0, -0.42, -0.2, 9, true),
      B('mosquito', 4.5, 0.5, 0.15, 9, true), B('mosquito', 4.8, 0.45, -0.25, 9, true), B('mosquito', 8, -0.5, 0.0, 10, true), B('housefly', 6, -0.5, 0.3, 9, true)] },
  { id: 13, world: 2, title: 'Wasp Watch', goalText: 'Catch 5. Never bite the wasp',
    goal: { kind: 'catch', n: 5 }, noSting: true, bites: 5, time: null, stars: [3, 2], pace: 15,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 12, true), B('moth', 1.0, -0.35, -0.3, 10), B('wasp', 1.5, -0.45, 0.0, 3, true),
      B('fruitFly', 1.8, 0.5, 0.2, 12, true), B('housefly', 4.5, 0.45, -0.2, 12, true), B('mosquito', 5, 0.55, 0.35, 10, true),
      B('wasp', 7, 0.5, 0.05, 3, true), B('housefly', 8, -0.5, 0.3, 10, true)] },
  { id: 14, world: 2, title: 'Here Be Dragons', goalText: 'Catch the dragonfly',
    goal: { kind: 'species', species: ['dragonfly'], n: 1 }, noSting: false, bites: 4, time: null, stars: [2, 1], pace: 15,
    bugs: [B('dragonfly', 1.0, -0.45, 0.15, 12), B('housefly', 1.5, 0.5, 0.2, 12, true), B('dragonfly', 6, 0.45, -0.2, 10)] },
  { id: 15, world: 2, title: 'Hoppers', goalText: 'Catch 3 grasshoppers',
    goal: { kind: 'species', species: ['grasshopper'], n: 3 }, clean3: true, noSting: false, bites: 5, time: null, stars: [4, 3], pace: 15,
    bugs: [B('grasshopper', 0.8, -0.5, 0.2, 12), B('grasshopper', 1.2, 0.5, -0.2, 12), B('grasshopper', 4, -0.45, -0.3, 12),
      B('grasshopper', 4.5, 0.45, 0.3, 12), B('housefly', 5, 0.5, 0.0, 10, true)] },
  { id: 16, world: 2, title: 'Rush Hour', goalText: '10 bugs in 40 seconds',
    goal: { kind: 'catch', n: 10 }, clean3: true, noSting: false, bites: null, time: 40, stars: [5, 4], pace: 16,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 8, true), B('fruitFly', 1.0, -0.45, -0.2, 8, true), B('moth', 1.2, -0.35, 0.0, 8),
      B('housefly', 5, 0.5, 0.2, 8, true), B('fruitFly', 5.2, 0.45, -0.25, 8, true), B('housefly', 5.4, 0.55, -0.05, 8, true),
      B('mosquito', 10, -0.5, 0.3, 8, true), B('moth', 10.2, -0.4, -0.1, 8), B('housefly', 10.4, -0.55, -0.3, 8, true),
      B('fruitFly', 15, 0.5, 0.1, 8, true), B('housefly', 15.2, 0.45, 0.35, 8, true), B('moth', 15.4, 0.35, -0.2, 8),
      B('housefly', 20, -0.5, 0.1, 8, true), B('fruitFly', 20.2, -0.45, -0.3, 8, true), B('housefly', 25, 0.5, 0.0, 8, true),
      B('fruitFly', 25.2, 0.45, -0.3, 8, true)] },
  { id: 17, world: 2, title: 'Busy Bees', goalText: 'Catch 6. Bees everywhere',
    goal: { kind: 'catch', n: 6 }, noSting: true, bites: 5, time: null, stars: [3, 2], pace: 17,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 12, true), B('bee', 1.0, -0.42, -0.15, 3, true), B('fruitFly', 1.2, -0.55, -0.35, 12, true),
      B('moth', 1.4, -0.35, 0.35, 10), B('bumblebee', 5, 0.45, 0.1, 3, true), B('housefly', 5.2, 0.5, -0.25, 12, true),
      B('fruitFly', 5.4, 0.55, 0.35, 12, true), B('bee', 9, -0.5, 0.0, 3, true), B('housefly', 9.5, -0.45, 0.3, 10, true),
      B('mosquito', 9.8, -0.55, -0.3, 10, true)] },
  { id: 18, world: 2, title: 'Bluebottles', goalText: 'Catch 3 bluebottles',
    goal: { kind: 'species', species: ['bluebottle'], n: 3 }, noSting: false, bites: 5, time: null, stars: [3, 2], pace: 15,
    bugs: [B('bluebottle', 0.8, -0.5, 0.2, 9, true), B('bluebottle', 1.0, -0.45, -0.2, 9, true),
      B('bluebottle', 4.5, 0.5, 0.2, 9, true), B('bluebottle', 4.7, 0.45, -0.25, 9, true), B('bluebottle', 9, -0.5, 0.0, 9, true)] },
  { id: 19, world: 2, title: 'Pure Gold', goalText: 'Catch the golden scarab',
    goal: { kind: 'species', species: ['goldenScarab'], n: 1 }, noSting: true, bites: 3, time: null, stars: [2, 1], pace: 18,
    bugs: [B('bee', 0.8, 0.45, 0.1, 4, true), B('goldenScarab', 1.6, 0.5, -0.15, 6, true), B('housefly', 1.8, -0.5, 0.2, 8, true)] },
  { id: 20, world: 2, title: 'Dusk Exam', goalText: '12 bugs in 6 bites. No stings',
    goal: { kind: 'catch', n: 12 }, clean3: true, noSting: true, bites: 6, time: null, stars: [5, 4], pace: 20,
    bugs: [B('housefly', 0.8, -0.5, 0.2, 10, true), B('moth', 1.0, -0.35, -0.3, 10), B('fruitFly', 1.2, -0.55, -0.1, 10, true),
      B('wasp', 4, 0.5, 0.0, 3, true), B('housefly', 4.3, 0.45, 0.3, 10, true), B('mosquito', 4.5, 0.55, -0.3, 10, true),
      B('fruitFly', 4.7, 0.4, -0.1, 10, true), B('gnat', 8, -0.5, 0.3, 9), B('gnat', 8.1, -0.42, 0.38, 9),
      B('gnat', 8.2, -0.58, 0.22, 9), B('moth', 8.4, -0.35, -0.2, 9), B('bee', 12, 0.5, 0.1, 3, true),
      B('housefly', 12.4, 0.45, -0.2, 9, true), B('fruitFly', 12.6, 0.55, 0.3, 9, true), B('housefly', 16, -0.5, 0.0, 8, true),
      B('moth', 16.2, -0.4, 0.3, 8)] },

  // ---- World 3: Night ----
  { id: 21, world: 3, title: 'Fireflies', goalText: 'Catch 4 fireflies',
    goal: { kind: 'species', species: ['firefly'], n: 4 }, noSting: false, bites: 4, time: null, stars: [3, 2], pace: 30,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 8, true), B('firefly', 1.0, -0.42, -0.2, 8, true), B('firefly', 4, 0.5, 0.2, 8, true),
      B('firefly', 4.2, 0.45, -0.25, 8, true), B('firefly', 8, -0.5, 0.0, 7, true)] },
  { id: 22, world: 3, title: 'Cricket Song', goalText: 'One bite, 3 crickets',
    goal: { kind: 'bite', n: 3 }, noSting: false, bites: 4, time: null, stars: [2, 1], pace: 31,
    bugs: [B('cricket', 0.8, -0.5, 0.2, 9), B('cricket', 1.0, -0.42, -0.2, 9), B('cricket', 1.2, -0.55, 0.0, 9),
      B('cricket', 6, 0.5, 0.2, 8), B('cricket', 6.2, 0.45, -0.2, 8), B('cricket', 6.4, 0.55, 0.0, 8)] },
  { id: 23, world: 3, title: 'Night Shift', goalText: 'Catch 6. Spare the wasps',
    goal: { kind: 'catch', n: 6 }, noSting: true, bites: 5, time: null, stars: [3, 2], pace: 32,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 7, true), B('cricket', 1.0, -0.42, -0.25, 7), B('wasp', 1.2, -0.45, 0.0, 3, true),
      B('firefly', 4, 0.5, 0.2, 7, true), B('moth', 4.2, 0.35, -0.2, 7), B('cricket', 4.4, 0.55, -0.35, 7),
      B('wasp', 8, 0.45, 0.0, 3, true), B('firefly', 8.3, -0.5, 0.3, 7, true), B('cricket', 8.5, -0.45, -0.3, 7)] },
  { id: 24, world: 3, title: 'Moonlit Feast', goalText: 'One bite, 5 bugs',
    goal: { kind: 'bite', n: 5 }, noSting: false, bites: 4, time: null, stars: [2, 1], pace: 33,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 8, true), B('cricket', 0.9, -0.42, -0.25, 8), B('moth', 1.0, -0.35, 0.0, 8),
      B('firefly', 1.1, 0.5, 0.2, 8, true), B('cricket', 1.2, 0.45, -0.2, 8), B('housefly', 1.3, 0.55, 0.0, 8, true),
      B('firefly', 7, -0.5, 0.1, 7, true), B('cricket', 7.1, -0.45, -0.3, 7), B('moth', 7.2, 0.35, 0.3, 7),
      B('firefly', 7.3, 0.5, -0.2, 7, true), B('cricket', 7.4, 0.55, 0.2, 7)] },
  { id: 25, world: 3, title: 'Midnight Rush', goalText: '10 bugs in 35 seconds',
    goal: { kind: 'catch', n: 10 }, clean3: true, noSting: false, bites: null, time: 35, stars: [5, 4], pace: 34,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 6, true), B('cricket', 1.0, -0.45, -0.2, 6), B('moth', 1.2, -0.35, 0.0, 6),
      B('firefly', 5, 0.5, 0.2, 6, true), B('cricket', 5.2, 0.45, -0.25, 6), B('firefly', 5.4, 0.55, -0.05, 6, true),
      B('moth', 10, -0.4, 0.3, 6), B('cricket', 10.2, -0.5, -0.1, 6), B('firefly', 10.4, -0.55, -0.3, 6, true),
      B('cricket', 15, 0.5, 0.1, 6), B('firefly', 15.2, 0.45, 0.35, 6, true), B('moth', 15.4, 0.35, -0.2, 6),
      B('firefly', 20, -0.5, 0.1, 6, true), B('cricket', 20.2, -0.45, -0.3, 6)] },
  { id: 26, world: 3, title: 'Dragon Night', goalText: 'Catch a dragonfly',
    goal: { kind: 'species', species: ['dragonfly'], n: 1 }, noSting: false, bites: 5, time: null, stars: [3, 2], pace: 30,
    bugs: [B('dragonfly', 0.8, -0.45, 0.15, 14), B('firefly', 1.0, 0.5, 0.2, 8, true), B('dragonfly', 4, 0.45, -0.2, 14), B('dragonfly', 4.5, -0.5, 0.35, 14),
      B('dragonfly', 8, -0.5, -0.1, 14), B('cricket', 8.2, 0.5, 0.3, 8)] },
  { id: 27, world: 3, title: 'Bee Patrol', goalText: 'Catch 5, spare 2 bees',
    goal: { kind: 'spare', n: 2, catchN: 5 }, noSting: true, bites: 5, time: null, stars: [3, 2], pace: 35,
    bugs: [B('bee', 0.8, -0.45, 0.0, 3, true), B('firefly', 1.0, -0.5, 0.25, 9, true), B('cricket', 1.2, -0.42, -0.3, 9),
      B('bumblebee', 4.5, 0.45, 0.0, 3, true), B('firefly', 4.7, 0.5, 0.3, 9, true), B('moth', 4.9, 0.35, -0.25, 9),
      B('bee', 9, -0.5, 0.1, 3, true), B('cricket', 9.2, -0.45, -0.3, 8), B('firefly', 9.4, -0.55, 0.35, 8, true),
      B('firefly', 13, 0.5, 0.0, 8, true)] },
  { id: 28, world: 3, title: 'Witching Hour', goalText: '6 bugs in 4 bites',
    goal: { kind: 'catch', n: 6 }, noSting: true, bites: 4, time: null, stars: [3, 2], pace: 36,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 7, true), B('cricket', 0.9, -0.42, -0.25, 7), B('moth', 1.0, -0.35, 0.05, 7),
      B('firefly', 1.1, -0.55, -0.05, 7, true), B('wasp', 5, 0.45, 0.0, 3, true), B('firefly', 5.2, 0.5, 0.3, 7, true),
      B('cricket', 5.4, 0.55, -0.3, 7), B('moth', 5.6, 0.35, -0.1, 7), B('firefly', 9, -0.5, 0.2, 6, true),
      B('cricket', 9.2, -0.45, -0.25, 6), B('firefly', 9.4, -0.55, 0.0, 6, true)] },
  { id: 29, world: 3, title: 'Deep Night', goalText: '7 bugs in 5 bites. No stings',
    goal: { kind: 'catch', n: 7 }, clean3: true, noSting: true, bites: 5, time: null, stars: [4, 3], pace: 38,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 6, true), B('cricket', 0.9, -0.42, -0.25, 6), B('moth', 1.0, -0.35, 0.05, 6),
      B('bee', 3.5, 0.45, 0.0, 3, true), B('firefly', 4.0, 0.5, 0.3, 6, true), B('cricket', 4.2, 0.55, -0.3, 6),
      B('firefly', 4.4, 0.4, -0.1, 6, true), B('mosquito', 8, -0.5, 0.3, 6, true), B('firefly', 8.2, -0.45, -0.2, 6, true),
      B('cricket', 8.4, -0.55, 0.0, 6), B('wasp', 12, 0.5, 0.1, 3, true), B('firefly', 12.5, 0.45, -0.25, 6, true),
      B('cricket', 12.7, 0.55, 0.3, 6), B('moth', 12.9, 0.35, 0.0, 6), B('firefly', 16, -0.5, 0.1, 5, true)] },
  { id: 30, world: 3, title: 'Last Light', goalText: '7 bugs in 6 bites. No stings',
    goal: { kind: 'catch', n: 7 }, noSting: true, bites: 6, time: null, stars: [5, 4], pace: 40,
    bugs: [B('firefly', 0.8, -0.5, 0.2, 6, true), B('cricket', 0.9, -0.42, -0.25, 6), B('moth', 1.0, -0.35, 0.05, 6),
      B('firefly', 1.1, -0.55, -0.05, 6, true), B('wasp', 4, 0.45, 0.0, 3, true), B('firefly', 4.3, 0.5, 0.3, 6, true),
      B('cricket', 4.5, 0.55, -0.3, 6), B('mosquito', 4.7, 0.4, -0.1, 6, true), B('firefly', 8, -0.5, 0.3, 5, true),
      B('cricket', 8.2, -0.45, -0.2, 5), B('dragonfly', 8.4, -0.55, 0.0, 5), B('bee', 12, 0.5, 0.1, 3, true),
      B('firefly', 12.4, 0.45, -0.25, 5, true), B('cricket', 12.6, 0.55, 0.3, 5), B('moth', 12.8, 0.35, 0.0, 5),
      B('firefly', 16, -0.5, 0.1, 5, true), B('cricket', 16.2, -0.45, -0.3, 5), B('firefly', 16.4, -0.55, 0.3, 5, true)] },
];

// The goal in LevelGoal's form (Snap/Core/Levels.swift): every non-zero part must be met.
//   catchAny: bugs caught; species + speciesCount: caught of those species; biteOf: the biggest bite; spare: bees spared.
function goalOf(l) {
  const g = l.goal;
  const out = { catchAny: 0, species: [], speciesCount: 0, biteOf: 0, spare: 0 };
  if (g.kind === 'catch') { out.catchAny = g.n; if (g.must) { out.species = g.must; out.speciesCount = g.must.length; } }
  else if (g.kind === 'species') { out.species = g.species; out.speciesCount = g.n; }
  else if (g.kind === 'bite') out.biteOf = g.n;
  else if (g.kind === 'spare') { out.spare = g.n; out.catchAny = g.catchN || 0; }
  else throw new Error('goal kind ' + g.kind);
  return out;
}

module.exports = { LEVELS, goalOf };
