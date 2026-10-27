import CoreGraphics
import Foundation

/// Tiny deterministic RNG for sound variation (main thread). Named to avoid clashing with Core's `SeededRandom`.
struct FeelDice {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0…1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    /// Uniform in lower…upper.
    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }

    /// Uniform in lower…upper, as a Float.
    mutating func float(_ lower: Float, _ upper: Float) -> Float {
        Float(range(Double(lower), Double(upper)))
    }

    mutating func seed32() -> UInt32 {
        UInt32(truncatingIfNeeded: next()) | 1
    }
}

/// Snapjaw's sound design (GAME-DESIGN §10, ROUND-1 "Feel engineer"), as pure data: every recipe returns synth
/// commands and the continuous bed is a pure function of the telemetry, so it is all unit-tested and nothing here
/// touches audio hardware.
///
/// Mix intent: a sunny bog. The bed (wind in the reeds, frogs, drips; crickets at night) and the marimba loop sit low;
/// the bugs' buzz is panned to where they are, so you can hear the crowd gathering and a bee drifting in. Small
/// sounds are small (a landing "tik", a sip, a whiff). **The CHOMP is the hero**: the biggest, wettest, most physical
/// sound in the game, different every time, and bigger with every bug in the bite.
enum FeelSoundBook {
    // MARK: Pitches (C major pentatonic)

    static let c5: Float = 523.25
    static let d5: Float = 587.33
    static let e5: Float = 659.26
    static let g5: Float = 783.99
    static let a5: Float = 880
    static let c6: Float = 1046.5
    static let d6: Float = 1174.66
    static let e6: Float = 1318.51
    static let g6: Float = 1567.98
    static let a6: Float = 1760
    static let c7: Float = 2093
    static let d7: Float = 2349.32
    static let e7: Float = 2637.02

    // MARK: The CHOMP (the hero)

    /// Every CHOMP's pitch varies by up to ±4 % and its two teeth clicks' spacing by ±3 ms around 18 ms, so it never
    /// feels canned (ROUND-1).
    static let chompPitchJitter: Float = 0.04
    static let clackGap: Float = 0.018
    static let clackJitter: Float = 0.003
    /// The first tooth click lands this long after the thwack's leading edge.
    static let clackAt: Float = 0.004
    /// The "mm" gulp lands this long after the bite.
    static let gulpAt: Float = 0.3
    /// Home's title trap chomps a little smaller than a real bite.
    static let homeChompScale: Float = 0.8

    /// The squelch tail's length: 120 ms + 60 ms per bug caught (ROUND-1), capped at 8 bugs.
    static func squelchLength(caught: Int) -> Float {
        0.12 + 0.06 * Float(min(max(caught, 0), 8))
    }

    /// CHOMP: the bite with at least one bug in it (`caught` ≥ 1; 0 plays the empty clap, `drySnap`).
    ///
    /// Built like the real thing, in the order your ear meets it:
    /// 1. a 2.5 ms bright tick: the instant the rims meet (the leading edge);
    /// 2. the **wet thwack**: a noise burst through a low-pass sweeping 2.4 kHz → 300 Hz in 60 ms, with a short 650 Hz
    ///    band for the slap of wet leaf on leaf;
    /// 3. the **thump**: a sine dropping 90 → 45 Hz in 70 ms, with a 1/n harmonic stack (to 450 Hz) so a phone speaker
    ///    carries its weight;
    /// 4. the **teeth clack**: two short woody clicks (~1.8 and ~2.3 kHz resonant impulses) 18 ± 3 ms apart;
    /// 5. the **squelch**: granular wet noise with little bubbles, 120 ms + 60 ms per bug, denser and wetter with more
    ///    bugs (a big bite adds a low slosh);
    /// 6. the **gulp** 0.3 s later: a nasal "mm", a 140 → 90 Hz formant blip, and a swallow.
    /// Weight grows with the bite (thump and thwack +5 % per extra bug). Everything shifts by the same ±4 % pitch.
    static func chomp(caught: Int, dice: inout FeelDice, scale: Float = 1) -> [FeelSynthCommand] {
        let n = min(max(caught, 0), 8)
        guard n > 0 else { return drySnap(dice: &dice, scale: scale) }
        let s: Float = scale.isFinite ? min(max(scale, 0), 1.2) : 1
        let k = dice.float(1 - chompPitchJitter, 1 + chompPitchJitter)
        let gap = clackGap + dice.float(-clackJitter, clackJitter)
        let weight: Float = 1 + 0.05 * Float(n - 1)
        var commands: [FeelSynthCommand] = []
        // 1. The rims meet.
        commands.append(.noise(FeelNoiseSpec(.highPass, cutoff: 3200 * k, q: 0.7, attack: 0.0003, decay: 0.0025,
                                             gain: 0.2 * s)))
        // 2. The wet thwack, and the leaf slap.
        let thwackGain: Float = min(0.32 * s * weight, 0.4)
        commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 2400 * k, to: 300 * k, sweep: 0.06, q: 1.3,
                                             attack: 0.0008, decay: 0.045, gain: thwackGain)))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 650 * k, q: 2.2, attack: 0.0005, decay: 0.016,
                                             gain: 0.26 * s)))
        // 3. The thump.
        let thumpGain: Float = min(0.3 * s * weight, 0.4)
        commands.append(.tone(FeelToneSpec(start: 90 * k, end: 45 * k, glide: 0.07, duration: 0.26, attack: 0.0015,
                                           decay: 0.075, gain: thumpGain, harmonics: 5)))
        // 4. The teeth clack.
        commands.append(contentsOf: clack(pitch: k, gap: gap, scale: s, dice: &dice))
        // 5. The squelch.
        let wet: Float = Float(min(n, 6))
        let squelchGain: Float = min(0.26 * s * (1 + 0.04 * Float(n)), 0.38)
        commands.append(.squelch(FeelSquelchSpec(duration: squelchLength(caught: n), grainRate: 380 + 50 * wet,
                                                 low: 380 * k, high: 2600 * k, bubbles: 0.25 + 0.03 * wet,
                                                 gain: squelchGain, delay: 0.012)))
        if n >= 3 {
            commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 700 * k, to: 250 * k, sweep: 0.15, q: 1,
                                                 attack: 0.01, decay: 0.08, gain: 0.12 * s, delay: 0.03)))
        }
        // 6. The gulp.
        commands.append(.tone(FeelToneSpec(start: 140 * k, end: 90 * k, glide: 0.09, duration: 0.17, attack: 0.012,
                                           decay: 0.06, gain: 0.15 * s, harmonics: 3, delay: gulpAt)))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 280 * k, q: 3, attack: 0.01, decay: 0.05,
                                             gain: 0.07 * s, delay: gulpAt)))
        commands.append(.drop(FeelDropSpec(frequency: 300 * k, chirp: 0.6, decay: 0.03, gain: 0.06 * s,
                                           delay: gulpAt + 0.07)))
        return commands
    }

    /// The two teeth clicks: resonant woody impulses at ~1.8 and ~2.3 kHz (× `pitch`), `gap` s apart.
    static func clack(pitch: Float, gap: Float, scale: Float, dice: inout FeelDice) -> [FeelSynthCommand] {
        let second = clackAt + max(gap, 0.005)
        var commands: [FeelSynthCommand] = []
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 1800 * pitch, partials: 3, decay: 0.011,
                                           brightness: 0.55, gain: 0.24 * scale, delay: clackAt,
                                           seed: dice.seed32())))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 1800 * pitch, q: 6, attack: 0.0002, decay: 0.004,
                                             gain: 0.16 * scale, delay: clackAt)))
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 2300 * pitch, partials: 3, decay: 0.009,
                                           brightness: 0.55, gain: 0.2 * scale, delay: second, seed: dice.seed32())))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 2300 * pitch, q: 6, attack: 0.0002, decay: 0.0035,
                                             gain: 0.13 * scale, delay: second)))
        return commands
    }

    /// The empty clap (nothing caught): the rims and the teeth, a lighter thwack and thump, a puff of empty air, then
    /// two soft falling marimba notes ("nothing…"). Smaller and drier than any CHOMP.
    static func drySnap(dice: inout FeelDice, scale: Float = 1) -> [FeelSynthCommand] {
        let s: Float = scale.isFinite ? min(max(scale, 0), 1.2) : 1
        let k = dice.float(1 - chompPitchJitter, 1 + chompPitchJitter)
        let gap = clackGap + dice.float(-clackJitter, clackJitter)
        var commands: [FeelSynthCommand] = []
        commands.append(.noise(FeelNoiseSpec(.highPass, cutoff: 3000 * k, q: 0.7, attack: 0.0003, decay: 0.002,
                                             gain: 0.15 * s)))
        commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 1800 * k, to: 400 * k, sweep: 0.05, q: 1,
                                             attack: 0.0008, decay: 0.03, gain: 0.2 * s)))
        commands.append(.tone(FeelToneSpec(start: 110 * k, end: 60 * k, glide: 0.05, duration: 0.16, attack: 0.0015,
                                           decay: 0.05, gain: 0.2 * s, harmonics: 4)))
        commands.append(contentsOf: clack(pitch: k, gap: gap, scale: 0.85 * s, dice: &dice))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 900, q: 0.7, attack: 0.004, decay: 0.05,
                                             gain: 0.07 * s, delay: 0.01)))
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: 392 * k, partials: 3, decay: 0.12, brightness: 0.3,
                                           gain: 0.05 * s, delay: 0.24, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: 329.63 * k, partials: 3, decay: 0.16,
                                           brightness: 0.3, gain: 0.045 * s, delay: 0.36, seed: dice.seed32())))
        return commands
    }

    /// When the `index`th caught bug's crunch lands (s after the bite), inside the squelch.
    static let crunchStart: Float = 0.02
    static let crunchSpacing: Float = 0.024
    static func crunchDelay(index: Int) -> Float {
        crunchStart + crunchSpacing * Float(min(max(index, 0), 10))
    }

    /// One caught bug (with the CHOMP, one per `bugCaught`): a tiny crackle of shell where it was, so a big bite has
    /// countable crunches. Panned to the bug.
    static func crunch(index: Int, pan: Float, dice: inout FeelDice) -> [FeelSynthCommand] {
        let start = crunchDelay(index: index)
        var commands: [FeelSynthCommand] = []
        var t = start
        for k in 0..<3 {
            let gain: Float = 0.13 - 0.03 * Float(k)
            commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: dice.float(2600, 4200), q: 2, attack: 0.0002,
                                                 decay: 0.0025, gain: gain, delay: t, pan: pan)))
            t += dice.float(0.005, 0.008)
        }
        commands.append(.ring(FeelRingSpec(.wood, fundamental: dice.float(1200, 1600), partials: 2, decay: 0.006,
                                           brightness: 0.45, gain: 0.08, delay: start, seed: dice.seed32(),
                                           pan: pan)))
        return commands
    }

    // MARK: Feast, refunds, chain

    /// The Feast sparkle starts here (s after the bite), and the "pop" of the snap coming back here.
    static let feastAt: Float = 0.16
    static let popAt: Float = 0.5
    static let feastNotes: [Float] = [c6, d6, e6, g6, a6]

    /// Feast (≥ 3 caught): a rising pentatonic sparkle (4 notes, 5 for a 5+ bite), then one cheerful "pop" per snap
    /// that comes back.
    static func feast(count: Int, snapsBack: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let notes = count >= 5 ? 5 : 4
        var commands: [FeelSynthCommand] = []
        for index in 0..<notes {
            let last = index == notes - 1
            let f = feastNotes[index]
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 3, decay: last ? 0.7 : 0.3,
                                               brightness: 0.35, gain: last ? 0.08 : 0.065,
                                               delay: feastAt + 0.06 * Float(index), seed: dice.seed32())))
        }
        let top = feastAt + 0.06 * Float(notes - 1)
        commands.append(.ring(FeelRingSpec(.glass, fundamental: feastNotes[notes - 1] * 2, partials: 2, decay: 0.25,
                                           brightness: 0.3, gain: 0.035, delay: top + 0.02, seed: dice.seed32())))
        let pops = min(max(snapsBack, 0), 2)
        for index in 0..<pops {
            let pitch: Float = index == 0 ? 1 : 1.335
            commands.append(contentsOf: pop(delay: popAt + 0.12 * Float(index), pitch: pitch, dice: &dice))
        }
        return commands
    }

    /// A snap coming back: a bright rising bubble pop, a tiny tick, a glint.
    static func pop(delay: Float, pitch: Float = 1, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = []
        commands.append(.drop(FeelDropSpec(frequency: 480 * pitch, chirp: 2.6, decay: 0.028, gain: 0.2,
                                           delay: delay)))
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 2100 * pitch, partials: 2, decay: 0.008,
                                           brightness: 0.4, gain: 0.08, delay: delay + 0.004, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: c7 * pitch, partials: 2, decay: 0.2, brightness: 0.3,
                                           gain: 0.04, delay: delay + 0.02, seed: dice.seed32())))
        return commands
    }

    /// The lucky refunds land here (s after the bite).
    static let luckyAt: Float = 0.3

    /// A lucky catch: a ladybird rings two bright bells and pops; the Golden Scarab plays a golden glissando over a
    /// soft chord and pops twice.
    static func lucky(_ species: BugSpecies, delay: Float = FeelSoundBook.luckyAt,
                      dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = []
        switch species {
        case .goldenScarab:
            let run: [Float] = [c6, d6, e6, g6, a6, c7, d7]
            for (index, f) in run.enumerated() {
                let last = index == run.count - 1
                commands.append(.ring(FeelRingSpec(.glass, fundamental: f, partials: 2, decay: last ? 0.6 : 0.2,
                                                   brightness: 0.3, gain: last ? 0.06 : 0.045,
                                                   delay: delay + 0.045 * Float(index), seed: dice.seed32())))
            }
            let chord: [Float] = [g5 / 2, c5, e5]
            for (index, f) in chord.enumerated() {
                commands.append(.tone(FeelToneSpec(start: f, duration: 1.1, attack: 0.2, decay: 0.4, gain: 0.03,
                                                   harmonics: 2, vibratoRate: 6.5 + 0.5 * Float(index),
                                                   vibratoDepth: 0.008, delay: delay + 0.1)))
            }
            commands.append(contentsOf: pop(delay: delay + 0.4, pitch: 1, dice: &dice))
            commands.append(contentsOf: pop(delay: delay + 0.52, pitch: 1.335, dice: &dice))
        case .ladybird:
            commands.append(.ring(FeelRingSpec(.bell, fundamental: e6, partials: 5, decay: 0.5, brightness: 0.4,
                                               gain: 0.07, delay: delay, seed: dice.seed32())))
            commands.append(.ring(FeelRingSpec(.bell, fundamental: a6, partials: 5, decay: 0.6, brightness: 0.4,
                                               gain: 0.065, delay: delay + 0.07, seed: dice.seed32())))
            commands.append(contentsOf: pop(delay: delay + 0.25, pitch: 1.5, dice: &dice))
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .grasshopper, .moth, .mosquito, .dragonfly, .firefly,
             .cricket, .bee, .bumblebee, .wasp:
            commands.append(.ring(FeelRingSpec(.bell, fundamental: e6, partials: 5, decay: 0.5, brightness: 0.4,
                                               gain: 0.06, delay: delay, seed: dice.seed32())))
        }
        return commands
    }

    /// The chain's ladder: C major pentatonic from C6 (each productive snap climbs one rung).
    static let chainLadder: [Float] = [c6, d6, e6, g6, a6, c7, d7, e7]
    /// The chain chime lands after the gulp (s after the bite).
    static let chainAt: Float = 0.42

    /// The ladder rung (0…7) for a chain of `count`.
    static func chainRung(count: Int) -> Int {
        min(max(count, 1), chainLadder.count) - 1
    }

    /// The chain grew: a quick two-note marimba step up to the chain's rung, with a glint.
    static func chainUp(count: Int, delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let rung = chainRung(count: count)
        var commands: [FeelSynthCommand] = []
        if rung > 0 {
            commands.append(.ring(FeelRingSpec(.marimba, fundamental: chainLadder[rung - 1], partials: 3, decay: 0.2,
                                               brightness: 0.35, gain: 0.055, delay: delay, seed: dice.seed32())))
        }
        let top = delay + (rung > 0 ? 0.07 : 0)
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: chainLadder[rung], partials: 3, decay: 0.35,
                                           brightness: 0.35, gain: 0.07, delay: top, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: chainLadder[rung] * 2, partials: 2, decay: 0.15,
                                           brightness: 0.3, gain: 0.025, delay: top + 0.02, seed: dice.seed32())))
        return commands
    }

    /// The chain broke: a falling two-note "bwoop" on the marimba and a soft wooden thud.
    static func chainBroken(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        var commands: [FeelSynthCommand] = []
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: g5, partials: 3, decay: 0.15, brightness: 0.35,
                                           gain: 0.055, delay: delay, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: c5, partials: 3, decay: 0.3, brightness: 0.35,
                                           gain: 0.055, delay: delay + 0.11, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 220, partials: 3, decay: 0.03, brightness: 0.4,
                                           gain: 0.08, delay: delay + 0.2, seed: dice.seed32())))
        return commands
    }

    // MARK: Bees and wasps

    /// The "Bzzt!" lands this long after the bite (after the teeth).
    static let stingAt: Float = 0.06
    /// The trap's "ptoo" (spitting the bee out) this long after the "Bzzt!".
    static let spitAfter: Float = 0.3

    /// A protected bug in the bite: a harsh, cross "Bzzt!" (a square burst with angry vibrato; 220 Hz for a bee,
    /// lower for a bumblebee; a wasp is higher, nastier and zaps twice), then the trap's little "ptoo" spit.
    static func sting(_ species: BugSpecies, pan: Float = 0, delay: Float = 0,
                      dice: inout FeelDice) -> [FeelSynthCommand] {
        let base: Float
        let harmonics: Int
        let zaps: Int
        switch species {
        case .wasp:
            base = 300
            harmonics = 9
            zaps = 2
        case .bumblebee:
            base = 160
            harmonics = 7
            zaps = 1
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .firefly, .cricket, .goldenScarab, .bee:
            base = 220
            harmonics = 7
            zaps = 1
        }
        let k = dice.float(0.97, 1.03)
        var commands: [FeelSynthCommand] = []
        for zap in 0..<zaps {
            let at = delay + 0.14 * Float(zap)
            commands.append(.tone(FeelToneSpec(start: base * 1.05 * k, end: base * 0.95 * k, glide: 0.2,
                                               duration: 0.24, attack: 0.004, decay: 0.12, gain: 0.14,
                                               harmonics: harmonics, vibratoRate: 32, vibratoDepth: 0.06, delay: at,
                                               odd: true, pan: pan)))
            commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: base * 5 * k, q: 1.5, attack: 0.004, decay: 0.08,
                                                 gain: 0.05, delay: at, pan: pan)))
        }
        if species == .wasp {
            commands.append(.ring(FeelRingSpec(.glass, fundamental: 2800 * k, partials: 2, decay: 0.08,
                                               brightness: 0.4, gain: 0.05, delay: delay, seed: dice.seed32(),
                                               pan: pan)))
        }
        let spit = delay + spitAfter + 0.14 * Float(zaps - 1)
        commands.append(.noise(FeelNoiseSpec(.highPass, cutoff: 2500, q: 0.7, attack: 0.0005, decay: 0.01, gain: 0.1,
                                             delay: spit, pan: pan)))
        commands.append(.tone(FeelToneSpec(start: 520, end: 170, glide: 0.06, duration: 0.09, attack: 0.003,
                                           decay: 0.035, gain: 0.09, harmonics: 2, delay: spit + 0.005, pan: pan)))
        commands.append(.drop(FeelDropSpec(frequency: 900, chirp: 0.5, decay: 0.025, gain: 0.05, delay: spit + 0.02,
                                           pan: pan)))
        return commands
    }

    /// A bee (bumblebee, wasp) left the trap uneaten: a happy little rising hum and a soft chime. Kindness rewarded.
    static func spared(_ species: BugSpecies, pan: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let pitch: Float
        switch species {
        case .bumblebee: pitch = 0.6
        case .wasp: pitch = 1.15
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .firefly, .cricket, .goldenScarab, .bee:
            pitch = 1
        }
        let k = dice.float(0.98, 1.02) * pitch
        var commands: [FeelSynthCommand] = []
        commands.append(.tone(FeelToneSpec(start: 220 * k, end: 262 * k, glide: 0.25, duration: 0.4, attack: 0.06,
                                           decay: 0.15, gain: 0.045, harmonics: 4, vibratoRate: 6, vibratoDepth: 0.02,
                                           pan: pan)))
        commands.append(.ring(FeelRingSpec(.chime, fundamental: e6, partials: 3, decay: 0.4, brightness: 0.3,
                                           gain: 0.04, delay: 0.2, seed: dice.seed32())))
        return commands
    }

    // MARK: Small bug sounds

    /// A bug's art radius (pt), ROUND-1's table: gnat 7 … dragonfly 24. Feel's own copy, so Feedback doesn't depend on
    /// `BugCatalog`'s values.
    static func size(_ species: BugSpecies) -> Double {
        switch species {
        case .gnat: return 7
        case .fruitFly, .mosquito: return 9
        case .ant: return 10
        case .firefly: return 13
        case .housefly, .ladybird: return 14
        case .bluebottle, .bee, .wasp: return 16
        case .cricket: return 17
        case .moth, .grasshopper: return 18
        case .goldenScarab: return 20
        case .bumblebee: return 22
        case .dragonfly: return 24
        }
    }

    /// 0 (a gnat) … 1 (a dragonfly).
    static func sizeUnit(_ species: BugSpecies) -> Double {
        FeelMath.clamp01((size(species) - 7) / 17)
    }

    /// A bug touches down: a soft "tik" pitched by its size (3.4 kHz for a gnat … 1.9 kHz for a dragonfly), with a
    /// little "pat" for the big ones. Half as loud on the bog (outside the trap).
    static func landingTik(_ species: BugSpecies, inTrap: Bool, pan: Float,
                           dice: inout FeelDice) -> [FeelSynthCommand] {
        let u = Float(sizeUnit(species))
        let share: Float = inTrap ? 1 : 0.5
        let f = (3400 - 1500 * u) * dice.float(0.95, 1.05)
        var commands: [FeelSynthCommand] = []
        commands.append(.ring(FeelRingSpec(.wood, fundamental: f, partials: 2, decay: 0.005 + 0.004 * u,
                                           brightness: 0.4, gain: (0.05 + 0.05 * u) * share, seed: dice.seed32(),
                                           pan: pan)))
        if u > 0.5 {
            commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 500, q: 0.8, attack: 0.001, decay: 0.01,
                                                 gain: 0.06 * u * share, pan: pan)))
        }
        return commands
    }

    /// A bug starts sipping nectar: a tiny wet "slp" (two little drops).
    static func sip(pan: Float, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.92, 1.08)
        return [
            .drop(FeelDropSpec(frequency: 1500 * k, chirp: 1.6, decay: 0.012, gain: 0.03, pan: pan)),
            .drop(FeelDropSpec(frequency: 1250 * k, chirp: 1.5, decay: 0.01, gain: 0.022, delay: 0.05, pan: pan)),
        ]
    }

    /// A grasshopper or cricket hops: a tiny rising "boing" and a tick.
    static func hop(pan: Float, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.93, 1.07)
        return [
            .tone(FeelToneSpec(start: 300 * k, end: 700 * k, glide: 0.05, duration: 0.08, attack: 0.002, decay: 0.03,
                               gain: 0.035, harmonics: 2, pan: pan)),
            .ring(FeelRingSpec(.wood, fundamental: 1900 * k, partials: 2, decay: 0.004, brightness: 0.4, gain: 0.04,
                               pan: pan)),
        ]
    }

    /// An airy "whiff": a bug that got away.
    static func whiff(pan: Float, delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.9, 1.1)
        return [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 1200 * k, to: 4500 * k, sweep: 0.07, q: 1.2, attack: 0.006,
                                 decay: 0.035, gain: 0.09, delay: delay, pan: pan)),
        ]
    }

    /// A twitchy bug noticed the creep and bolted: a startled rising "zip" and a small whiff.
    static func spooked(pan: Float, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.92, 1.08)
        var commands: [FeelSynthCommand] = [
            .tone(FeelToneSpec(start: 260 * k, end: 720 * k, glide: 0.08, duration: 0.12, attack: 0.003, decay: 0.05,
                               gain: 0.045, harmonics: 3, pan: pan)),
        ]
        for command in whiff(pan: pan, delay: 0.02, dice: &dice) {
            if case .noise(var spec) = command {
                spec.gain *= 0.6
                commands.append(.noise(spec))
            }
        }
        return commands
    }

    // MARK: The trap

    /// The snap started (closure passed 4°): a soft whoosh of the lobes swinging in.
    static func snapWhoosh(dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.92, 1.08)
        return [
            .noise(FeelNoiseSpec(.bandPass, cutoff: 500 * k, to: 1800 * k, sweep: 0.08, q: 0.9, attack: 0.015,
                                 decay: 0.05, gain: 0.06)),
        ]
    }

    /// Re-armed (the trap is open again): a soft, low pluck.
    static func rearmPluck(dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.98, 1.02)
        return [
            .ring(FeelRingSpec(.pluck, fundamental: 196 * k, partials: 5, decay: 0.18, brightness: 0.4, gain: 0.08,
                               seed: dice.seed32())),
            .ring(FeelRingSpec(.marimba, fundamental: 392 * k, partials: 2, decay: 0.1, brightness: 0.3, gain: 0.025,
                               seed: dice.seed32())),
        ]
    }

    /// The last snap left: two low wooden knocks and a low marimba note.
    static func lastSnap(delay: Float = 0) -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.wood, fundamental: 300, partials: 3, decay: 0.03, brightness: 0.45, gain: 0.12,
                               delay: delay, seed: 5)),
            .ring(FeelRingSpec(.wood, fundamental: 290, partials: 3, decay: 0.03, brightness: 0.45, gain: 0.1,
                               delay: delay + 0.16, seed: 7)),
            .ring(FeelRingSpec(.marimba, fundamental: 220, partials: 3, decay: 0.35, brightness: 0.35, gain: 0.06,
                               delay: delay + 0.3, seed: 9)),
        ]
    }

    /// "Your trap is tired": a sleepy, sinking yawn and a low pluck. The marimba loop has already stopped.
    static func tired(delay: Float = 0) -> [FeelSynthCommand] {
        [
            .tone(FeelToneSpec(start: 330, end: 150, glide: 0.7, duration: 0.9, attack: 0.1, decay: 0.35, gain: 0.08,
                               harmonics: 4, vibratoRate: 5, vibratoDepth: 0.01, delay: delay)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 700, to: 300, sweep: 0.6, q: 0.9, attack: 0.15, decay: 0.3,
                                 gain: 0.04, delay: delay)),
            .ring(FeelRingSpec(.pluck, fundamental: 130.81, partials: 5, decay: 0.5, brightness: 0.4, gain: 0.07,
                               delay: delay + 0.85, seed: 13)),
        ]
    }

    /// Passing the personal best: a bright rising four-note chime.
    static func newBest(delay: Float = 0) -> [FeelSynthCommand] {
        let notes: [Float] = [e6, g6, a6, c7]
        var commands: [FeelSynthCommand] = []
        for (index, f) in notes.enumerated() {
            let last = index == notes.count - 1
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: last ? 0.9 : 0.5,
                                               brightness: 0.35, gain: last ? 0.1 : 0.08,
                                               delay: delay + 0.085 * Float(index), seed: UInt32(index + 3))))
        }
        return commands
    }

    /// The day moves on: a soft dawn chime (morning), a bright glint (noon), a warm low bell (dusk), an owl (night).
    static func dayChime(_ phase: DayPhase, dice: inout FeelDice) -> [FeelSynthCommand] {
        switch phase {
        case .morning:
            return [
                .ring(FeelRingSpec(.chime, fundamental: c6, partials: 3, decay: 0.6, brightness: 0.3, gain: 0.04,
                                   seed: dice.seed32())),
                .ring(FeelRingSpec(.chime, fundamental: e6, partials: 3, decay: 0.7, brightness: 0.3, gain: 0.035,
                                   delay: 0.12, seed: dice.seed32())),
            ]
        case .noon:
            return [
                .ring(FeelRingSpec(.glass, fundamental: g6, partials: 2, decay: 0.35, brightness: 0.3, gain: 0.04,
                                   seed: dice.seed32())),
                .ring(FeelRingSpec(.glass, fundamental: c7, partials: 2, decay: 0.45, brightness: 0.3, gain: 0.035,
                                   delay: 0.09, seed: dice.seed32())),
            ]
        case .dusk:
            return [
                .ring(FeelRingSpec(.bell, fundamental: 392, partials: 5, decay: 1.2, brightness: 0.35, gain: 0.045,
                                   seed: dice.seed32())),
                .ring(FeelRingSpec(.bell, fundamental: c5, partials: 5, decay: 1.3, brightness: 0.35, gain: 0.035,
                                   delay: 0.15, seed: dice.seed32())),
            ]
        case .night:
            return [
                .tone(FeelToneSpec(start: 360, end: 345, glide: 0.2, duration: 0.35, attack: 0.06, decay: 0.12,
                                   gain: 0.05, harmonics: 2, pan: -0.4)),
                .tone(FeelToneSpec(start: 340, end: 320, glide: 0.25, duration: 0.45, attack: 0.06, decay: 0.15,
                                   gain: 0.045, harmonics: 2, delay: 0.45, pan: -0.4)),
            ]
        }
    }

    // MARK: Menus

    /// A soft wooden click.
    static func uiTap() -> [FeelSynthCommand] {
        [
            .ring(FeelRingSpec(.wood, fundamental: 1500, partials: 3, decay: 0.012, brightness: 0.4, gain: 0.12)),
            .noise(FeelNoiseSpec(.highPass, cutoff: 3000, q: 0.7, attack: 0.0005, decay: 0.003, gain: 0.05)),
        ]
    }

    /// Two wooden clicks, the second higher.
    static func uiConfirm() -> [FeelSynthCommand] {
        var commands = uiTap()
        commands.append(.ring(FeelRingSpec(.wood, fundamental: 2000, partials: 3, decay: 0.014, brightness: 0.4,
                                           gain: 0.12, delay: 0.06)))
        return commands
    }

    /// Rank up, a new Bug Book page: a rising C pentatonic marimba-and-chime arpeggio over a soft chord, with glints.
    static func celebrate(dice: inout FeelDice) -> [FeelSynthCommand] {
        let notes: [Float] = [c5, e5, g5, c6, e6]
        var commands: [FeelSynthCommand] = []
        for (index, f) in notes.enumerated() {
            let last = index == notes.count - 1
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 4, decay: last ? 0.9 : 0.4,
                                               brightness: 0.35, gain: last ? 0.1 : 0.08,
                                               delay: 0.09 * Float(index), seed: UInt32(index + 7))))
            commands.append(.ring(FeelRingSpec(.marimba, fundamental: f / 2, partials: 3, decay: 0.25,
                                               brightness: 0.35, gain: 0.04, delay: 0.09 * Float(index),
                                               seed: UInt32(index + 17))))
        }
        let chord: [Float] = [261.63, 329.63, 392]
        for f in chord {
            commands.append(.tone(FeelToneSpec(start: f, duration: 1.2, attack: 0.05, decay: 0.5, gain: 0.03,
                                               harmonics: 2)))
        }
        for index in 0..<4 {
            commands.append(.ring(FeelRingSpec(.glass, fundamental: dice.float(2600, 4200), partials: 2, decay: 0.15,
                                               brightness: 0.3, gain: 0.03, delay: 0.12 + 0.11 * Float(index),
                                               seed: dice.seed32(), pan: dice.float(-0.6, 0.6))))
        }
        return commands
    }

    // MARK: The bed (everything continuous)

    /// Glide (s) of the frame-by-frame bed, and of a fade to quiet (pause, menus).
    static let frameGlide: Float = 0.05
    static let fadeGlide: Float = 0.35
    /// Drips per second at full ambience.
    static let dripRate = 0.22
    /// The buzz layer's share during the result moments (the bog still lives, a little softer).
    static let buzzRestShare = 0.6
    /// Home's groan share (the title trap creaks a little softer than play).
    static let homeGroanShare = 0.7

    /// No continuous layers, master kept: menus, pause cards and one-shots stay audible.
    static func idleBed(master: Float, glide: Float = fadeGlide) -> FeelBed {
        var bed = FeelBed()
        bed.master = master
        bed.glide = glide
        return bed
    }

    /// The creep groan's level: 0 unless creeping; 0.55 at the creep line rising to 1 at the snap depth.
    static func groanLevel(closure: Double, creeping: Bool) -> Double {
        guard creeping, closure.isFinite else { return 0 }
        let span = max(Tuning.snapDepth - Tuning.creepDepth, 1)
        return 0.55 + 0.45 * FeelMath.clamp01((closure - Tuning.creepDepth) / span)
    }

    /// The groan's pitch (Hz): 70 open … 140 at the snap depth.
    static func groanHz(closure: Double) -> Double {
        70 + 70 * FeelMath.clamp01(closure / Tuning.snapDepth)
    }

    /// The marimba voices for a chain: 1, then one more at chains of 2, 4 and 6.
    static func musicVoices(chain: Int) -> Float {
        var voices: Float = 1
        if chain >= 2 { voices += 1 }
        if chain >= 4 { voices += 1 }
        if chain >= 6 { voices += 1 }
        return voices
    }

    /// Wind in the reeds: full by day, half at night.
    static func windShare(dayClock: Double) -> Double {
        let clock = dayClock.isFinite ? dayClock : 0
        return 1 - 0.5 * FeelMath.clamp01(clock - 2)
    }

    /// Frogs: always about, loudest at dusk.
    static func frogShare(dayClock: Double) -> Double {
        let clock = dayClock.isFinite ? dayClock : 0
        return 0.6 + 0.4 * FeelMath.clamp01(1 - abs(clock - 2.5))
    }

    /// The night crickets: in from `dayClock` 2.75, full by 3.25 (night).
    static func cricketShare(dayClock: Double) -> Double {
        let clock = dayClock.isFinite ? dayClock : 0
        return FeelMath.smoothstep((clock - 2.75) / 0.5)
    }

    /// The continuous layers for one game frame. `ambience` (0…1) is the bog's level: the director keeps it up
    /// through the result moments and lets it fade in menus.
    static func playBed(telemetry: TrapTelemetry, master: Float, ambience: Double) -> FeelBed {
        var bed = idleBed(master: master, glide: frameGlide)
        if telemetry.playing {
            bed.groan = Float(groanLevel(closure: telemetry.closure, creeping: telemetry.creeping))
            bed.groanHz = Float(groanHz(closure: telemetry.closure))
            bed.music = 1
            bed.musicVoices = musicVoices(chain: telemetry.chain)
        }
        let air = FeelMath.clamp01(ambience)
        if air > 0 {
            let clock = telemetry.dayClock
            bed.wind = Float(air * windShare(dayClock: clock))
            bed.frogs = Float(air * frogShare(dayClock: clock))
            bed.dripRate = Float(dripRate * air)
            bed.crickets = Float(air * cricketShare(dayClock: clock))
        }
        return bed
    }

    /// Home's title trap: the groan follows the hinge's closing stretch (`FeelStretchMeter`), nothing else.
    static func homeBed(stretch: Double, closure: Double, master: Float) -> FeelBed {
        var bed = idleBed(master: master, glide: frameGlide)
        bed.groan = Float(FeelMath.clamp01(stretch) * homeGroanShare)
        bed.groanHz = Float(groanHz(closure: closure))
        return bed
    }

    // MARK: The buzz layer

    /// How wide the buzz and the bug sounds spread across the two speakers (1 = hard left/right at the edges).
    static let stereoWidth: Float = 0.8

    /// The pan for a scene x (0 … `width`), scaled by `stereoWidth`. NaN → centre.
    static func pan(x: Double, width: Double) -> Float {
        guard x.isFinite, width.isFinite, width > 1 else { return 0 }
        let p = FeelMath.clamp(x / width * 2 - 1, -1, 1)
        return Float(p) * stereoWidth
    }

    /// The pan for a `Buzzer.pan` (−1…1), scaled by `stereoWidth`.
    static func pan(buzzer value: Double) -> Float {
        guard value.isFinite else { return 0 }
        return Float(FeelMath.clamp(value, -1, 1)) * stereoWidth
    }

    /// A species' buzz timbre, flying or on the ground (`silent`: no sound in that state).
    static func timbre(_ species: BugSpecies, flying: Bool) -> FeelBuzzTimbre {
        switch species {
        case .housefly: return .fly
        case .gnat, .fruitFly: return .gnat
        case .bluebottle: return .bluebottle
        case .ant: return .silent
        case .ladybird, .firefly, .goldenScarab: return flying ? .beetle : .silent
        case .grasshopper: return flying ? .hopper : .silent
        case .cricket: return flying ? .hopper : .cricket
        case .moth: return .moth
        case .mosquito: return .mosquito
        case .dragonfly: return .dragonfly
        case .bee: return .bee
        case .bumblebee: return .bumblebee
        case .wasp: return .wasp
        }
    }

    /// The species' pitch within its timbre (the fruit fly is a lower gnat, the scarab a deeper beetle …).
    static func speciesPitch(_ species: BugSpecies) -> Float {
        switch species {
        case .fruitFly: return 0.72
        case .ladybird: return 1.1
        case .firefly: return 1.25
        case .goldenScarab: return 0.75
        case .housefly, .gnat, .bluebottle, .ant, .grasshopper, .moth, .mosquito, .dragonfly, .cricket, .bee,
             .bumblebee, .wasp:
            return 1
        }
    }

    /// Each bug's own pitch: ±6 % from its id (stable for its whole visit).
    static func bugPitch(id: Int) -> Float {
        var z = UInt64(bitPattern: Int64(id)) &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        let u = Float(z % 10_000) / 10_000
        return 0.94 + 0.12 * u
    }

    /// Loudness on the ground (0 = silent there): a bee hums softly while it sips (that's the trap's dilemma), a
    /// cricket chirps, a fly is a faint presence.
    static func landedLevel(_ species: BugSpecies) -> Double {
        switch species {
        case .bee: return 0.2
        case .bumblebee: return 0.24
        case .wasp: return 0.14
        case .cricket: return 0.5
        case .housefly, .gnat, .fruitFly, .bluebottle: return 0.06
        case .moth: return 0.08
        case .mosquito: return 0.05
        case .dragonfly: return 0.1
        case .ant, .ladybird, .grasshopper, .firefly, .goldenScarab: return 0
        }
    }

    /// A buzzer's loudness 0…1: flying 0.45 high … 1.0 low (close to the screen), or its landed level.
    static func buzzLevel(_ species: BugSpecies, flying: Bool, height: Double) -> Double {
        if flying {
            let h = FeelMath.clamp01(height)
            return 0.45 + 0.55 * (1 - h)
        }
        return landedLevel(species)
    }

    /// The buzz slot target for one buzzer at `share` (0…1).
    static func buzz(for buzzer: Buzzer, share: Double) -> FeelBuzz {
        let voice = FeelSoundBook.timbre(buzzer.species, flying: buzzer.flying)
        guard voice != .silent else { return FeelBuzz() }
        let loudness = FeelSoundBook.buzzLevel(buzzer.species, flying: buzzer.flying, height: buzzer.height)
        let level = loudness * FeelMath.clamp01(share)
        let side = FeelSoundBook.pan(buzzer: buzzer.pan)
        let pitch = FeelSoundBook.speciesPitch(buzzer.species) * FeelSoundBook.bugPitch(id: buzzer.id)
        return FeelBuzz(timbre: voice, level: Float(level), pan: side, pitch: pitch)
    }
}

/// The buzz layer's slot keeper (pure, testable): up to `FeelSynth.buzzSlots` bugs at once, the loudest first. A bug
/// keeps its slot for its whole visit; a slot whose bug has gone fades to silence and is free again only after
/// `reuseAfter` (the synth's ~80 ms fade), so a new bug never takes over a voice mid-sound.
struct FeelBuzzMixer {
    static let slots = FeelSynth.buzzSlots
    static let reuseAfter = 0.12

    /// The bug id in each slot (nil: free or fading).
    private(set) var ids: [Int?]
    private var releasedAt: [Double]
    /// The latest target per slot.
    private(set) var targets: [FeelBuzz]

    init() {
        ids = Array(repeating: nil, count: FeelBuzzMixer.slots)
        releasedAt = Array(repeating: -Double.infinity, count: FeelBuzzMixer.slots)
        targets = Array(repeating: FeelBuzz(), count: FeelBuzzMixer.slots)
    }

    /// This frame's buzzers at `share` (0…1) at time `now`; returns every slot's target.
    mutating func update(buzzers: [Buzzer], share: Double, now: Double) -> [FeelBuzz] {
        var wanted: [(id: Int, buzz: FeelBuzz)] = []
        for buzzer in buzzers {
            let target = FeelSoundBook.buzz(for: buzzer, share: share)
            if target.timbre != .silent && target.level > 0.001 {
                wanted.append((id: buzzer.id, buzz: target))
            }
        }
        wanted.sort { (a: (id: Int, buzz: FeelBuzz), b: (id: Int, buzz: FeelBuzz)) -> Bool in
            if a.buzz.level != b.buzz.level { return a.buzz.level > b.buzz.level }
            return a.id < b.id
        }
        if wanted.count > Self.slots { wanted.removeLast(wanted.count - Self.slots) }
        // Release the slots whose bug is gone (or no longer among the loudest): they fade out.
        for slot in 0..<Self.slots {
            guard let id = ids[slot] else { continue }
            if !wanted.contains(where: { $0.id == id }) {
                ids[slot] = nil
                releasedAt[slot] = now
                targets[slot].level = 0
            }
        }
        for item in wanted {
            if let slot = ids.firstIndex(where: { $0 == item.id }) {
                targets[slot] = item.buzz
                continue
            }
            var free: Int?
            for slot in 0..<Self.slots where ids[slot] == nil && now - releasedAt[slot] >= Self.reuseAfter {
                free = slot
                break
            }
            if let slot = free {
                ids[slot] = item.id
                targets[slot] = item.buzz
            }
        }
        return targets
    }

    /// Everything fades out at once (pause, menus).
    mutating func releaseAll(now: Double) {
        for slot in 0..<Self.slots {
            if ids[slot] != nil { releasedAt[slot] = now }
            ids[slot] = nil
            targets[slot].level = 0
        }
    }
}
