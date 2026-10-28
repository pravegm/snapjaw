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
    /// R2: the Scene freezes the bite for a 50 ms hit-stop. The impact (rims, thwack, thump, knock, clack) lands at 0;
    /// the wet tail (the squelch and the crunches) waits out the hit-stop, so the bite reads as one heavy slam, a held
    /// beat, then the squelch.
    static let hitStop: Float = 0.05
    /// The "mm" gulp lands this long after the bite.
    static let gulpAt: Float = 0.34
    /// Home's title trap chomps a little smaller than a real bite.
    static let homeChompScale: Float = 0.8
    /// R3: bites of up to this many bugs get the small-bite "nom" (sound) and a firmer floor (haptic).
    static let smallBite = 2

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
    /// 3. the **thump**: a sine dropping 90 → 45 Hz in 70 ms, with a 1/n harmonic stack (to 540 Hz) so a phone speaker
    ///    carries its weight; R2: longer and heavier, with a 160 → 70 Hz **knock** and a low-passed body **whump** on
    ///    top (the mass of two lobes meeting);
    /// 4. the **teeth clack**: two short woody clicks (~1.8 and ~2.3 kHz resonant impulses) 18 ± 3 ms apart;
    /// 5. after the 50 ms **hit-stop** (`hitStop`), the **squelch**: granular wet noise with little bubbles, 120 ms +
    ///    60 ms per bug, denser and wetter with more bugs (a big bite adds a low slosh);
    /// 6. the **gulp** 0.34 s later: a nasal "mm", a 140 → 90 Hz formant blip, and a swallow.
    /// Weight grows with the bite (thump and thwack +5 % per extra bug). Everything shifts by the same ±4 % pitch.
    /// R3: a 1–2 bug bite adds a "nom" after the hit-stop (`smallBite`), so a small bite still has weight.
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
                                             gain: 0.17 * s)))
        // 2. The wet thwack, and the leaf slap.
        let thwackGain: Float = min(0.29 * s * weight, 0.4)
        commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 2400 * k, to: 300 * k, sweep: 0.06, q: 1.3,
                                             attack: 0.0008, decay: 0.045, gain: thwackGain)))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 650 * k, q: 2.2, attack: 0.0005, decay: 0.016,
                                             gain: 0.22 * s)))
        // 3. The thump (the only tone at 0), the knock and the body whump.
        let thumpGain: Float = min(0.34 * s * weight, 0.4)
        commands.append(.tone(FeelToneSpec(start: 90 * k, end: 45 * k, glide: 0.07, duration: 0.3, attack: 0.0015,
                                           decay: 0.09, gain: thumpGain, harmonics: 6)))
        commands.append(.tone(FeelToneSpec(start: 160 * k, end: 70 * k, glide: 0.04, duration: 0.12, attack: 0.001,
                                           decay: 0.03, gain: min(0.1 * s * weight, 0.2), harmonics: 4,
                                           delay: 0.002)))
        commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 420 * k, to: 120 * k, sweep: 0.05, q: 1.6,
                                             attack: 0.001, decay: 0.045, gain: min(0.1 * s * weight, 0.2))))
        // 4. The teeth clack.
        commands.append(contentsOf: clack(pitch: k, gap: gap, scale: s, dice: &dice))
        // 5. The squelch.
        let wet: Float = Float(min(n, 6))
        let squelchGain: Float = min(0.26 * s * (1 + 0.04 * Float(n)), 0.38)
        commands.append(.squelch(FeelSquelchSpec(duration: squelchLength(caught: n), grainRate: 380 + 50 * wet,
                                                 low: 380 * k, high: 2600 * k, bubbles: 0.25 + 0.03 * wet,
                                                 gain: squelchGain, delay: hitStop)))
        if n >= 3 {
            commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 700 * k, to: 250 * k, sweep: 0.15, q: 1,
                                                 attack: 0.01, decay: 0.08, gain: 0.12 * s, delay: hitStop + 0.02)))
        }
        // R3: a small bite still has weight. A 1–2 bug bite gets a "nom" right after the hit-stop: a 230 → 150 Hz
        // harmonic-rich body in the band a phone speaker really plays, so a single fly lands as a proper mouthful.
        if n <= smallBite {
            commands.append(.tone(FeelToneSpec(start: 230 * k, end: 150 * k, glide: 0.06, duration: 0.14,
                                               attack: 0.003, decay: 0.045, gain: 0.13 * s, harmonics: 5,
                                               delay: hitStop)))
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

    /// R5 (REVIEW-4 #10): the dry snap's hollow "clop" (the two empty lobes knocking together, like a coconut shell)
    /// lands this long after the rims meet, at about `clopPitch` Hz.
    static let clopAt: Float = 0.003
    static let clopPitch: Float = 480
    /// Its wooden body rings this long (time constant): ~5 × the teeth clicks', so it reads as hollow, not a tick.
    static let clopRing: Float = 0.05

    /// The empty clap (nothing caught). R5 (REVIEW-4 #10, the dry snap read as silent): a hollow "clop", with no
    /// squelch, no wet thwack and no gulp. In order:
    /// 1. the rims' bright tick;
    /// 2. the **clop**: a hollow wooden knock (`clopPitch`, ringing `clopRing`), a square-ish (odd-harmonic) body
    ///    falling 380 → 300 Hz in 30 ms, and a narrow band of air at ~800 Hz (the empty cavity between the lobes);
    /// 3. the teeth clack, lighter;
    /// 4. a small dry knock (no deep thump: nothing was squashed);
    /// 5. two soft falling marimba notes ("nothing…"), under the Scene's "Missed!" puff.
    /// Smaller than any CHOMP, and drier.
    static func drySnap(dice: inout FeelDice, scale: Float = 1) -> [FeelSynthCommand] {
        let s: Float = scale.isFinite ? min(max(scale, 0), 1.2) : 1
        let k = dice.float(1 - chompPitchJitter, 1 + chompPitchJitter)
        let gap = clackGap + dice.float(-clackJitter, clackJitter)
        var commands: [FeelSynthCommand] = []
        // 1. The rims meet.
        commands.append(.noise(FeelNoiseSpec(.highPass, cutoff: 3000 * k, q: 0.7, attack: 0.0003, decay: 0.002,
                                             gain: 0.13 * s)))
        // 2. The clop: a hollow wooden knock, its square-ish body and the empty cavity's air.
        commands.append(.ring(FeelRingSpec(.wood, fundamental: clopPitch * k, partials: 3, decay: clopRing,
                                           brightness: 0.35, gain: 0.24 * s, delay: clopAt, seed: dice.seed32())))
        commands.append(.tone(FeelToneSpec(start: 380 * k, end: 300 * k, glide: 0.03, duration: 0.09, attack: 0.001,
                                           decay: 0.035, gain: 0.14 * s, harmonics: 5, delay: clopAt, odd: true)))
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 800 * k, q: 5, attack: 0.0008, decay: 0.022,
                                             gain: 0.12 * s, delay: clopAt)))
        // 3. The teeth.
        commands.append(contentsOf: clack(pitch: k, gap: gap, scale: 0.6 * s, dice: &dice))
        // 4. A small dry knock (no thump).
        commands.append(.tone(FeelToneSpec(start: 150 * k, end: 110 * k, glide: 0.03, duration: 0.07, attack: 0.001,
                                           decay: 0.025, gain: 0.08 * s, harmonics: 3)))
        // 5. "Nothing…".
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: 392 * k, partials: 3, decay: 0.12, brightness: 0.3,
                                           gain: 0.05 * s, delay: 0.24, seed: dice.seed32())))
        commands.append(.ring(FeelRingSpec(.marimba, fundamental: 329.63 * k, partials: 3, decay: 0.16,
                                           brightness: 0.3, gain: 0.045 * s, delay: 0.36, seed: dice.seed32())))
        return commands
    }

    /// When the `index`th caught bug's crunch lands (s after the bite), inside the squelch (after the hit-stop).
    static let crunchStart: Float = 0.058
    static let crunchSpacing: Float = 0.024
    static func crunchDelay(index: Int) -> Float {
        crunchStart + crunchSpacing * Float(min(max(index, 0), 10))
    }

    /// One caught bug (with the CHOMP, one per `bugCaught`): a tiny crackle of shell where it was, so a big bite has
    /// countable crunches. Panned to the bug. `light` (QA-1 #4, bugs past the 4th): two crackles and no shell ring, so
    /// a huge Feast still has voices left for its sparkle, scarab and chain.
    /// R6 `cascade` (the FEAST CHOMP): the crunch lands on the FEAST's cascade instead (`cascadeDelay`: after the
    /// longer hit-stop, `cascadeSpacing` apart, so every bug is its own countable "crk"), and its shell ring climbs
    /// `cascadeRise` per bug, so the run of crunches rises like a drum roll.
    static func crunch(index: Int, pan: Float, light: Bool = false, cascade: Bool = false,
                       dice: inout FeelDice) -> [FeelSynthCommand] {
        let start = cascade ? cascadeDelay(index: index) : crunchDelay(index: index)
        var commands: [FeelSynthCommand] = []
        var t = start
        for k in 0..<(light ? 2 : 3) {
            let gain: Float = 0.13 - 0.03 * Float(k)
            commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: dice.float(2600, 4200), q: 2, attack: 0.0002,
                                                 decay: 0.0025, gain: gain, delay: t, pan: pan)))
            t += dice.float(0.005, 0.008)
        }
        if light { return commands }
        let shell: Float
        if cascade {
            let rung = Float(min(max(index, 0), 10))
            shell = cascadeShell * (1 + cascadeRise * rung) * dice.float(0.97, 1.03)
        } else {
            shell = dice.float(1200, 1600)
        }
        commands.append(.ring(FeelRingSpec(.wood, fundamental: shell, partials: 2, decay: 0.006,
                                           brightness: 0.45, gain: 0.08, delay: start, seed: dice.seed32(),
                                           pan: pan)))
        return commands
    }

    // MARK: R6: the FEAST CHOMP (a bite of 5+ bugs, or one at ×4+ chain)

    /// R6 (ROUND-6 decision 5, SCORE-R5 D4 #1): a bite that caught at least this many bugs (Core's
    /// `Tuning.bigFeastCount`), or that scored at this chain multiplier or more, is a FEAST: it plays `feastChomp`
    /// and `FeelHapticBook.feastChomp`. A 3–4 bug Feast keeps the plain CHOMP (and the Feast sparkle).
    static let feastChompCount: Int = Tuning.bigFeastCount
    static let feastChompChain: Double = 4

    /// Pure: is this bite a FEAST CHOMP? Only a bite that caught something. The Scene's FEAST treatment uses the same
    /// rule (keep them in step: design/notes/feel-R6.md).
    static func isFeastChomp(_ report: BiteReport) -> Bool {
        let count = report.caught.count
        // R6 founder rule: a bite with a stinger is never a FEAST (matches Scene's FeastEvent.isBig).
        guard count > 0, report.stingers.isEmpty else { return false }
        if count >= feastChompCount { return true }
        let chain = report.chainMultiplier.isFinite ? report.chainMultiplier : 1
        return chain >= feastChompChain - 1e-6
    }

    /// The Scene's FEAST hit-stop (ROUND-6: 80 ms, against a plain bite's 50 ms `hitStop`). The slam lands at 0; the
    /// wet tail and the crunch cascade wait it out.
    static let feastHitStop: Float = 0.08
    /// The crunch cascade: the first crunch `cascadeLead` after the hit-stop, then one every `cascadeSpacing` (wider
    /// than a plain bite's `crunchSpacing`, so each bug is its own countable "crk"), capped at 11 rungs.
    static let cascadeLead: Float = 0.008
    static let cascadeSpacing: Float = 0.038
    /// The cascade's shell ring starts near `cascadeShell` Hz and climbs `cascadeRise` per bug (a rising drum roll).
    static let cascadeShell: Float = 1250
    static let cascadeRise: Float = 0.06
    /// The sting (choir + marimba) and the burp land here (s after the bite), after the cascade, the Feast sparkle,
    /// the chain chime and the snaps' pops. The marimba run's notes are `feastStingStep` apart.
    static let feastStingAt: Float = 0.74
    static let feastStingStep: Float = 0.045
    static let burpAt: Float = 1.12
    /// The burp's lip "pop" comes this long after the burp; the whole burp is over after `burpLength`.
    static let burpPopAfter: Float = 0.22
    static let burpLength: Float = 0.4
    /// When the FEAST CHOMP is over (s after the bite).
    static let feastChompLength: Float = burpAt + burpLength

    /// When the `index`th caught bug's crunch lands in a FEAST (s after the bite).
    static func cascadeDelay(index: Int) -> Float {
        feastHitStop + cascadeLead + cascadeSpacing * Float(min(max(index, 0), 10))
    }

    /// R6: the FEAST CHOMP. In order:
    /// 1. the plain CHOMP's slam for the bite (rims, wet thwack, thump, knock, whump, teeth), at 0;
    /// 2. a **deeper body** under it: a sub "thoom" falling 64 → 30 Hz (an 8-harmonic stack, so a phone speaker carries
    ///    its weight) and a dark low-passed chest of air;
    /// 3. after the 80 ms FEAST hit-stop (`feastHitStop`), the CHOMP's squelch (and its low slosh);
    /// 4. the **crunch cascade**, one crunch per caught bug (`crunch(cascade: true)`, played by the director per
    ///    `bugCaught`, `cascadeSpacing` apart and rising);
    /// 5. at `feastStingAt`, the bright **sting** (`feastSting`): a marimba run over a soft "aah" choir;
    /// 6. at `burpAt`, a cute **burp** (`burp`) instead of the plain gulp.
    /// The impact stays within a quarter of the plain 8-bug CHOMP's, and the limiter holds the whole frame under the
    /// master's peak (tested).
    static func feastChomp(caught: Int, dice: inout FeelDice) -> [FeelSynthCommand] {
        let n = min(max(caught, 1), 8)
        let lag: Float = feastHitStop - hitStop
        var commands: [FeelSynthCommand] = []
        // 1 and 3: the plain CHOMP's slam at 0; its wet tail waits out the longer hit-stop; its "mm" gulp gives way to
        // the burp.
        for command in chomp(caught: n, dice: &dice) {
            let at = command.delay
            if at >= gulpAt - 1e-6 { continue }
            commands.append(at >= hitStop - 1e-6 ? command.delayed(by: lag) : command)
        }
        // 2. The deeper body.
        let k = dice.float(1 - chompPitchJitter, 1 + chompPitchJitter)
        commands.append(.tone(FeelToneSpec(start: 64 * k, end: 30 * k, glide: 0.12, duration: 0.5, attack: 0.002,
                                           decay: 0.15, gain: 0.26, harmonics: 8, delay: 0.003)))
        commands.append(.noise(FeelNoiseSpec(.lowPass, cutoff: 260 * k, to: 70 * k, sweep: 0.12, q: 1.8,
                                             attack: 0.002, decay: 0.1, gain: 0.1, delay: 0.002)))
        // 5 and 6.
        commands.append(contentsOf: feastSting(delay: feastStingAt, dice: &dice))
        commands.append(contentsOf: burp(delay: burpAt, dice: &dice))
        return commands
    }

    /// R6: the FEAST's sting. A bright marimba run up C6–E6–G6–C7 (`feastStingStep` apart, spreading left to right)
    /// with a glass glint at the top, over a soft "aah" choir: C5, E5, G5 and C6 held, each with its own slow
    /// vibrato and a hair of detune, and a breathy band of air at the vowel's ~1.1 kHz. Bright, light voices.
    static func feastSting(delay: Float = FeelSoundBook.feastStingAt, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        var commands: [FeelSynthCommand] = []
        let run: [Float] = [c6, e6, g6, c7]
        for (index, f) in run.enumerated() {
            let last = index == run.count - 1
            commands.append(.ring(FeelRingSpec(.marimba, fundamental: f, partials: 3, decay: last ? 0.5 : 0.2,
                                               brightness: 0.4, gain: last ? 0.07 : 0.06,
                                               delay: at + feastStingStep * Float(index), seed: dice.seed32(),
                                               pan: -0.3 + 0.2 * Float(index))))
        }
        let top = at + feastStingStep * Float(run.count - 1)
        commands.append(.ring(FeelRingSpec(.glass, fundamental: e7, partials: 2, decay: 0.3, brightness: 0.3,
                                           gain: 0.035, delay: top + 0.02, seed: dice.seed32())))
        let choir: [Float] = [c5, e5, g5, c6]
        for (index, f) in choir.enumerated() {
            let detune = dice.float(0.997, 1.003)
            commands.append(.tone(FeelToneSpec(start: f * detune, duration: 0.8, attack: 0.05, decay: 0.32,
                                               gain: 0.03, harmonics: 4, vibratoRate: 5.2 + 0.35 * Float(index),
                                               vibratoDepth: 0.007, delay: at, pan: -0.24 + 0.16 * Float(index))))
        }
        commands.append(.noise(FeelNoiseSpec(.bandPass, cutoff: 1100, q: 2.2, attack: 0.04, decay: 0.22, gain: 0.03,
                                             delay: at)))
        return commands
    }

    /// R6: the FEAST's cute "burp": a short raspy little belch falling 210 → 140 Hz (a fast, wide vibrato is the
    /// rasp; its harmonics carry it on a phone speaker), a puff of air at its vowel, then a tiny lip "pop" and a
    /// contented glint.
    static func burp(delay: Float = FeelSoundBook.burpAt, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        let k = dice.float(0.96, 1.04)
        return [
            .tone(FeelToneSpec(start: 210 * k, end: 140 * k, glide: 0.16, duration: 0.22, attack: 0.012, decay: 0.07,
                               gain: 0.12, harmonics: 7, vibratoRate: 32, vibratoDepth: 0.07, delay: at)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 520 * k, q: 2.5, attack: 0.008, decay: 0.06, gain: 0.06,
                                 delay: at)),
            .drop(FeelDropSpec(frequency: 760 * k, chirp: 1.8, decay: 0.018, gain: 0.06, delay: at + burpPopAfter)),
            .ring(FeelRingSpec(.glass, fundamental: g6, partials: 2, decay: 0.2, brightness: 0.3, gain: 0.025,
                               delay: at + burpPopAfter + 0.04, seed: dice.seed32())),
        ]
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
    static let chainAt: Float = 0.46

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

    /// R3: the chain's top step (×5 at step 8) flares once: `chainUp` with a multiplier at or above this.
    static let flareMultiplier: Double = 5
    /// The flare starts this long after the chain's own two-note step.
    static let flareAfter: Float = 0.1

    /// The chain reached ×5: a bright rising chord, once. A fast C6–E6–G6–C7 chime roll spreading left to right over a
    /// soft held C major shimmer, and two glints at the top. Bright but light: it lands after the gulp, never on the
    /// CHOMP's impact, and each voice stays small.
    static func chainFlare(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        let roll: [Float] = [c6, e6, g6, c7]
        var commands: [FeelSynthCommand] = []
        for (index, f) in roll.enumerated() {
            let last = index == roll.count - 1
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 3, decay: last ? 0.9 : 0.55,
                                               brightness: 0.4, gain: last ? 0.055 : 0.045,
                                               delay: at + 0.035 * Float(index), seed: dice.seed32(),
                                               pan: -0.3 + 0.2 * Float(index))))
        }
        let shimmer: [Float] = [c5, e5, g5]
        for (index, f) in shimmer.enumerated() {
            commands.append(.tone(FeelToneSpec(start: f, duration: 0.8, attack: 0.04, decay: 0.35, gain: 0.022,
                                               harmonics: 2, vibratoRate: 5.5 + 0.4 * Float(index),
                                               vibratoDepth: 0.006, delay: at)))
        }
        commands.append(.ring(FeelRingSpec(.glass, fundamental: e7, partials: 2, decay: 0.3, brightness: 0.3,
                                           gain: 0.03, delay: at + 0.16, seed: dice.seed32(), pan: 0.3)))
        commands.append(.ring(FeelRingSpec(.glass, fundamental: d7, partials: 2, decay: 0.25, brightness: 0.3,
                                           gain: 0.022, delay: at + 0.24, seed: dice.seed32(), pan: -0.3)))
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
        let zaps = stingZaps(species)
        switch species {
        case .wasp:
            base = 300
            harmonics = 9
        case .bumblebee:
            base = 160
            harmonics = 7
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .firefly, .cricket, .goldenScarab, .bee:
            base = 220
            harmonics = 7
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

    /// How many "Bzzt!"s a protected bug zaps (a wasp twice).
    static func stingZaps(_ species: BugSpecies) -> Int {
        switch species {
        case .wasp: return 2
        case .housefly, .gnat, .fruitFly, .bluebottle, .ant, .ladybird, .grasshopper, .moth, .mosquito, .dragonfly,
             .firefly, .cricket, .goldenScarab, .bee, .bumblebee:
            return 1
        }
    }

    /// R3: the sting's verdict (the loss blip or the "oops") lands this long after the spit.
    static let verdictAfterSpit: Float = 0.1

    /// When a sting that starts at `delay` is over (its "ptoo" spat): the verdict lands here.
    static func stingVerdictAt(_ species: BugSpecies, delay: Float) -> Float {
        let start: Float = delay.isFinite ? max(delay, 0) : 0
        return start + spitAfter + 0.14 * Float(stingZaps(species) - 1) + verdictAfterSpit
    }

    /// R4 (QA-2 #9): when the HUD numeral drops for a costly sting (s after the bite): the Scene's 50 ms hit-stop
    /// (`BogScene.hitStopTime`), then `BogEconomy.crackLead` (0.15 s) while the glyph cracks. The loss blip and its
    /// haptic land here, so the sound and the number agree. Keep in step with the Scene (design/notes/feel-R4.md).
    static let numeralDropAt: Float = 0.2

    /// The loss blip's two notes, `lostSpacing` apart; the whole blip is over after `lostLength`.
    static let lostSpacing: Float = 0.12
    static let lostLength: Float = 0.32

    /// R5: when a frame's costly-sting loss blip plays (s after the frame): with the numeral's drop on a bite frame,
    /// the hit-stop earlier on a frame without one. Pure.
    static func lossAt(biting: Bool) -> Float {
        biting ? numeralDropAt : numeralDropAt - hitStop
    }

    /// When the frame's loss blip is over (0 when no sting cost snaps): the chain's "bwoop", the warnings and the yawn
    /// wait for it. Pure.
    static func afterLoss(biting: Bool, stingCost: Int) -> Float {
        stingCost > 0 ? lossAt(biting: biting) + lostLength : 0
    }

    /// R5 (REVIEW-4 #4): the run's last bite says, in order, the numeral's drop (and a costly sting's blip, at
    /// `numeralDropAt`), then "Your trap is tired" and its yawn, at least this long after the bite. The App's tired
    /// banner waits the same beat (`AppRules.tiredBannerDelay`), so the yawn and the banner arrive together.
    static let tiredAfterBite: Float = 0.45
    /// The chain-broken "bwoop" is over this long after it starts (its two notes and the knock at +0.2 s).
    static let chainBrokenLength: Float = 0.25

    /// R5 (REVIEW-4 #4): when the tired yawn plays (s after its frame). On a bite frame `tiredAfterBite` at the
    /// earliest; after a wilt, once the droop is over (`wiltLength`); otherwise at once. Never before the frame's loss
    /// blip is over, nor over a chain-broken "bwoop" that starts at `bwoopAt`. Pure; tested.
    static func tiredDelay(biting: Bool, wilting: Bool, stingCost: Int, bwoopAt: Float? = nil) -> Float {
        var at: Float = biting ? tiredAfterBite : (wilting ? wiltLength : 0)
        at = max(at, afterLoss(biting: biting, stingCost: stingCost))
        if let bwoop = bwoopAt, bwoop.isFinite {
            at = max(at, max(bwoop, 0) + chainBrokenLength)
        }
        return at
    }

    /// R3: a sting that cost snaps says "you lost something": a short descending two-note blip (R4: at `numeralDropAt`).
    /// Hollow square-ish blips (odd harmonics) doubled on the marimba, A5 then a fourth down to E5; a wasp's two
    /// snaps fall a fifth, to D5. Clear and small, never louder than the CHOMP.
    static func snapLost(cost: Int = 1, delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        let k = dice.float(0.99, 1.01)
        let low: Float = cost >= 2 ? d5 : e5
        let notes: [Float] = [a5 * k, low * k]
        var commands: [FeelSynthCommand] = []
        for (index, f) in notes.enumerated() {
            let last = index == notes.count - 1
            let t = at + lostSpacing * Float(index)
            commands.append(.tone(FeelToneSpec(start: f, end: f * 0.97, glide: 0.06, duration: last ? 0.16 : 0.09,
                                               attack: 0.002, decay: last ? 0.06 : 0.035, gain: 0.07, harmonics: 2,
                                               delay: t, odd: true)))
            commands.append(.ring(FeelRingSpec(.marimba, fundamental: f, partials: 3, decay: last ? 0.2 : 0.1,
                                               brightness: 0.35, gain: 0.05, delay: t, seed: dice.seed32())))
        }
        return commands
    }

    /// R3: the free first bee (cost 0, "Bees cost a snap!"): a gentle "oops" after the usual "Bzzt!". A soft round
    /// scoop up a fifth (a little gasp), then a light marimba note and a glint that end high: a warning, nothing lost.
    static func oops(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        let k = dice.float(0.98, 1.02)
        return [
            .tone(FeelToneSpec(start: 392 * k, end: 587.33 * k, glide: 0.07, duration: 0.13, attack: 0.012,
                               decay: 0.05, gain: 0.05, harmonics: 2, vibratoRate: 7, vibratoDepth: 0.01,
                               delay: at)),
            .ring(FeelRingSpec(.marimba, fundamental: d6 * k, partials: 3, decay: 0.16, brightness: 0.3, gain: 0.045,
                               delay: at + 0.11, seed: dice.seed32())),
            .ring(FeelRingSpec(.glass, fundamental: g6 * k, partials: 2, decay: 0.12, brightness: 0.3, gain: 0.02,
                               delay: at + 0.13, seed: dice.seed32())),
        ]
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

    // MARK: Hunger (R2, GAME-DESIGN §5 "Hunger")

    /// Hungry (3 s before a snap wilts): the trap's tummy rumbles. A low growl (a 72 → 58 Hz stack with a 9 Hz wobble;
    /// its harmonics carry it on a phone speaker), a resonant low-passed gurgle, a second rising "grrr", and three
    /// small low bubbles. Centred and soft: a nudge, never an alarm.
    static func hungry(dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.95, 1.05)
        var commands: [FeelSynthCommand] = [
            .tone(FeelToneSpec(start: 72 * k, end: 58 * k, glide: 0.5, duration: 0.75, attack: 0.08, decay: 0.3,
                               gain: 0.1, harmonics: 7, vibratoRate: 9, vibratoDepth: 0.09)),
            .noise(FeelNoiseSpec(.lowPass, cutoff: 320 * k, to: 160 * k, sweep: 0.5, q: 3, attack: 0.06, decay: 0.22,
                                 gain: 0.08)),
            .tone(FeelToneSpec(start: 96 * k, end: 120 * k, glide: 0.2, duration: 0.4, attack: 0.05, decay: 0.15,
                               gain: 0.06, harmonics: 6, vibratoRate: 13, vibratoDepth: 0.1, delay: 0.42)),
        ]
        for index in 0..<3 {
            let at: Float = 0.25 + 0.14 * Float(index) + dice.float(0, 0.05)
            commands.append(.drop(FeelDropSpec(frequency: dice.float(170, 260), chirp: 1.4, decay: 0.03, gain: 0.05,
                                               delay: at)))
        }
        return commands
    }

    /// When the wilt's second sigh starts, and when the whole droop has settled (s after the wilt).
    static let wiltSecondSigh: Float = 0.24
    static let wiltLength: Float = 0.9

    /// A snap wilted ("Too slow! −1 snap"). R3: clearer and sadder, still cute: a tiny sad two-note "aww-www". A short
    /// G4 that sags a little, then a longer E4 sliding down to B3 with a wobbly vibrato (the leaf flopping), a leafy
    /// rustle settling under it, a little falling drip off the leaf tip, and one soft low marimba plop at the bottom.
    /// Softer than the last-snap knocks.
    static func wilted(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let k = dice.float(0.98, 1.02)
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        let second = at + wiltSecondSigh
        return [
            .tone(FeelToneSpec(start: 392 * k, end: 370 * k, glide: 0.18, duration: 0.22, attack: 0.02, decay: 0.09,
                               gain: 0.06, harmonics: 3, vibratoRate: 5, vibratoDepth: 0.008, delay: at)),
            .tone(FeelToneSpec(start: 329.63 * k, end: 246.94 * k, glide: 0.42, duration: 0.6, attack: 0.03,
                               decay: 0.26, gain: 0.065, harmonics: 3, vibratoRate: 6, vibratoDepth: 0.02,
                               delay: second)),
            .noise(FeelNoiseSpec(.bandPass, cutoff: 1400 * k, to: 350 * k, sweep: 0.6, q: 0.9, attack: 0.04,
                                 decay: 0.2, gain: 0.035, delay: at)),
            .drop(FeelDropSpec(frequency: 700 * k, chirp: 0.6, decay: 0.03, gain: 0.035, delay: second + 0.38)),
            .ring(FeelRingSpec(.marimba, fundamental: 130.81 * k, partials: 3, decay: 0.3, brightness: 0.3, gain: 0.05,
                               delay: second + 0.46, seed: dice.seed32())),
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

    // MARK: R6: goals and the Garden

    /// A goal ticked by a bite waits for that bite's sounds: a plain bite's chain chime and Feast pops are over by
    /// `goalAfterBite`; a FEAST CHOMP's burp by `feastChompLength`.
    static let goalAfterBite: Float = 0.62

    /// Pure: how long (s) a goal chime waits when it is asked for `sinceBite` s after the last bite (`feast`: that bite
    /// was a FEAST CHOMP). 0 once the bite's sounds are over, or with no bite (`sinceBite` infinite or NaN).
    static func goalDelay(sinceBite: Double, feast: Bool) -> Float {
        guard sinceBite.isFinite else { return 0 }
        let end: Float = feast ? feastChompLength : goalAfterBite
        let since = Float(max(sinceBite, 0))
        return max(end - since, 0)
    }

    /// The goal chime's second note lands this long after its first.
    static let goalStep: Float = 0.1

    /// R6: a goal completed (the live toast). A checkbox "tick" (a small wooden click) and a bright two-note
    /// "ding-ding" up a fourth, G6 → C7, on the chime, with a glass glint. `bonus` (three goals at once) adds a third
    /// note up to E7 and a soft held C major shimmer. Small and bright: under the CHOMP, never on its impact.
    static func goalChime(bonus: Bool = false, delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        var commands: [FeelSynthCommand] = [
            .ring(FeelRingSpec(.wood, fundamental: 1700, partials: 2, decay: 0.008, brightness: 0.4, gain: 0.07,
                               delay: at, seed: dice.seed32())),
            .ring(FeelRingSpec(.chime, fundamental: g6, partials: 3, decay: 0.3, brightness: 0.35, gain: 0.065,
                               delay: at + 0.01, seed: dice.seed32(), pan: -0.15)),
            .ring(FeelRingSpec(.chime, fundamental: c7, partials: 3, decay: bonus ? 0.4 : 0.6, brightness: 0.35,
                               gain: 0.07, delay: at + 0.01 + goalStep, seed: dice.seed32(), pan: 0.15)),
            .ring(FeelRingSpec(.glass, fundamental: e7, partials: 2, decay: 0.2, brightness: 0.3, gain: 0.025,
                               delay: at + 0.03 + goalStep, seed: dice.seed32())),
        ]
        guard bonus else { return commands }
        commands.append(.ring(FeelRingSpec(.chime, fundamental: e7, partials: 3, decay: 0.8, brightness: 0.35,
                                           gain: 0.065, delay: at + 0.01 + 2 * goalStep, seed: dice.seed32())))
        let shimmer: [Float] = [c5, e5, g5]
        for (index, f) in shimmer.enumerated() {
            commands.append(.tone(FeelToneSpec(start: f, duration: 0.7, attack: 0.04, decay: 0.3, gain: 0.02,
                                               harmonics: 2, vibratoRate: 5.5 + 0.4 * Float(index),
                                               vibratoDepth: 0.006, delay: at + 2 * goalStep)))
        }
        return commands
    }

    /// The variety fanfare's three calls ("ta-ta-taaa") and when they land (s after its start).
    static let fanfareCalls: [Float] = [g5, g5, c6]
    static let fanfareCallTimes: [Float] = [0, 0.12, 0.24]

    /// R6: a new trap variety in the Garden: a proud little fanfare, about 1.4 s. Three brassy calls (6-harmonic
    /// saw-like stacks scooping up into pitch; the last held with a touch of vibrato) "ta-ta-taaa" on G5, G5, C6,
    /// doubled on the marimba; under the held call a soft C major chord swells; then a chime run up E6–G6–C7–E7 spreading
    /// left to right, and three glints. Bigger than a goal's chime, light beside the CHOMP.
    static func varietyFanfare(delay: Float = 0, dice: inout FeelDice) -> [FeelSynthCommand] {
        let at: Float = delay.isFinite ? max(delay, 0) : 0
        var commands: [FeelSynthCommand] = []
        let calls = min(fanfareCalls.count, fanfareCallTimes.count)
        for index in 0..<calls {
            let last = index == calls - 1
            let f = fanfareCalls[index]
            let t = at + fanfareCallTimes[index]
            commands.append(.tone(FeelToneSpec(start: f * 0.985, end: f, glide: 0.025, duration: last ? 0.6 : 0.1,
                                               attack: 0.008, decay: last ? 0.28 : 0.05, gain: 0.05, harmonics: 6,
                                               vibratoRate: last ? 5.5 : 0, vibratoDepth: last ? 0.008 : 0,
                                               delay: t)))
            commands.append(.ring(FeelRingSpec(.marimba, fundamental: f, partials: 3, decay: last ? 0.35 : 0.12,
                                               brightness: 0.4, gain: 0.05, delay: t, seed: dice.seed32())))
        }
        let held = at + (fanfareCallTimes.last ?? 0)
        let chord: [Float] = [c5, e5, g5]
        for (index, f) in chord.enumerated() {
            commands.append(.tone(FeelToneSpec(start: f, duration: 1.0, attack: 0.08, decay: 0.4, gain: 0.025,
                                               harmonics: 3, vibratoRate: 5 + 0.4 * Float(index), vibratoDepth: 0.006,
                                               delay: held)))
        }
        let run: [Float] = [e6, g6, c7, e7]
        for (index, f) in run.enumerated() {
            let last = index == run.count - 1
            commands.append(.ring(FeelRingSpec(.chime, fundamental: f, partials: 3, decay: last ? 0.8 : 0.35,
                                               brightness: 0.35, gain: last ? 0.055 : 0.045,
                                               delay: held + 0.18 + 0.06 * Float(index), seed: dice.seed32(),
                                               pan: -0.3 + 0.2 * Float(index))))
        }
        for index in 0..<3 {
            commands.append(.ring(FeelRingSpec(.glass, fundamental: dice.float(2800, 4200), partials: 2, decay: 0.15,
                                               brightness: 0.3, gain: 0.025, delay: held + 0.5 + 0.1 * Float(index),
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

    /// R8 (the phone IS the trap): a close runs from Core's close start (8°) to about 120° of closure before the
    /// shut (Scene's `cueFull`), so the leaf's groan and its texture stretch over the whole close.
    static let closeFrom: Double = 8
    static let closeFull: Double = 120

    /// The slow-close groan's level: 0 unless closing slowly (Core's `creeping`); 0.55 at the close's start rising to
    /// 1 near the shut.
    static func groanLevel(closure: Double, creeping: Bool) -> Double {
        guard creeping, closure.isFinite else { return 0 }
        return 0.55 + 0.45 * FeelMath.clamp01((closure - closeFrom) / (closeFull - closeFrom))
    }

    /// The groan's pitch (Hz): 70 open … 140 near the shut.
    static func groanHz(closure: Double) -> Double {
        70 + 70 * FeelMath.clamp01(closure / closeFull)
    }

    /// The marimba voices for a chain: 1, then one more at chains of 2, 4 and 6, and (R3) a fifth, the bright chime
    /// double, at 8 (the ×5 top step).
    static func musicVoices(chain: Int) -> Float {
        var voices: Float = 1
        if chain >= 2 { voices += 1 }
        if chain >= 4 { voices += 1 }
        if chain >= 6 { voices += 1 }
        if chain >= 8 { voices += 1 }
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

    // MARK: R6: the Zen Bog's gentle bed

    /// Zen (`FeedbackDirector.zen`): the marimba loop plays at this share, with at most `zenMaxMusicVoices` voices (the
    /// chain still adds them up to there); the bog (wind, frogs, crickets) at `zenAmbienceShare`, the drips sparser
    /// still; the creep groan, which still tells you the bugs feel it, at `zenGroanShare`. The buzz layer is unchanged
    /// (a bee's hum is still the choice).
    static let zenMusicShare: Double = 0.55
    static let zenMaxMusicVoices: Float = 3
    static let zenAmbienceShare: Double = 0.75
    static let zenDripShare: Double = 0.6
    static let zenGroanShare: Double = 0.7

    /// Pure: whether a run in `mode` gets the Zen feel (the gentle bed, no hunger or warning sounds).
    static func isZen(_ mode: RunMode) -> Bool {
        switch mode {
        case .zen: return true
        case .feed, .daily, .attract, .lesson, .level: return false
        }
    }

    /// The continuous layers for one game frame. `ambience` (0…1) is the bog's level: the director keeps it up
    /// through the result moments and lets it fade in menus. R6 `zen`: the Zen Bog's softer bed (see `zenMusicShare`).
    static func playBed(telemetry: TrapTelemetry, master: Float, ambience: Double, zen: Bool = false) -> FeelBed {
        var bed = idleBed(master: master, glide: frameGlide)
        if telemetry.playing {
            let groan = groanLevel(closure: telemetry.closure, creeping: telemetry.creeping)
            bed.groan = Float(zen ? groan * zenGroanShare : groan)
            bed.groanHz = Float(groanHz(closure: telemetry.closure))
            bed.music = Float(zen ? zenMusicShare : 1)
            let voices = musicVoices(chain: telemetry.chain)
            bed.musicVoices = zen ? min(voices, zenMaxMusicVoices) : voices
        }
        let air = FeelMath.clamp01(ambience) * (zen ? zenAmbienceShare : 1)
        if air > 0 {
            let clock = telemetry.dayClock
            bed.wind = Float(air * windShare(dayClock: clock))
            bed.frogs = Float(air * frogShare(dayClock: clock))
            bed.dripRate = Float(dripRate * air * (zen ? zenDripShare : 1))
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
/// keeps its slot for its whole visit (QA-1 #15: a newcomer must be `hysteresis` × louder to take a seat from a bug
/// already sounding, so the 8th and 9th bugs at similar heights never swap every few frames); a slot whose bug has
/// gone fades to silence and is free again only after `reuseAfter` (the synth's ~80 ms fade), so a new bug never takes
/// over a voice mid-sound.
struct FeelBuzzMixer {
    static let slots = FeelSynth.buzzSlots
    static let reuseAfter = 0.12
    /// A bug already in a slot ranks this much louder when the eight are chosen.
    static let hysteresis = 1.3

    /// One candidate for a slot this frame.
    struct Want {
        var id: Int
        var buzz: FeelBuzz
        var rank: Float
    }

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
        var wanted: [FeelBuzzMixer.Want] = []
        for buzzer in buzzers {
            let target = FeelSoundBook.buzz(for: buzzer, share: share)
            if target.timbre != .silent && target.level > 0.001 {
                let held = ids.contains(where: { $0 == buzzer.id })
                let rank: Float = held ? target.level * Float(Self.hysteresis) : target.level
                wanted.append(FeelBuzzMixer.Want(id: buzzer.id, buzz: target, rank: rank))
            }
        }
        wanted.sort { (a: FeelBuzzMixer.Want, b: FeelBuzzMixer.Want) -> Bool in
            if a.rank != b.rank { return a.rank > b.rank }
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

extension FeelSynthCommand {
    /// R6: the same one-shot `offset` s later (the FEAST CHOMP's tail waits out the longer hit-stop). A negative or NaN
    /// offset never moves a voice before 0. The continuous commands (`bed`, `buzz`, `stopAll`) are unchanged.
    func delayed(by offset: Float) -> FeelSynthCommand {
        let shift: Float = offset.isFinite ? offset : 0
        switch self {
        case .noise(var spec):
            spec.delay = max(spec.delay + shift, 0)
            return .noise(spec)
        case .tone(var spec):
            spec.delay = max(spec.delay + shift, 0)
            return .tone(spec)
        case .ring(var spec):
            spec.delay = max(spec.delay + shift, 0)
            return .ring(spec)
        case .drop(var spec):
            spec.delay = max(spec.delay + shift, 0)
            return .drop(spec)
        case .fm(var spec):
            spec.delay = max(spec.delay + shift, 0)
            return .fm(spec)
        case .squelch(var spec):
            spec.delay = max(spec.delay + shift, 0)
            return .squelch(spec)
        case .bed, .buzz, .stopAll:
            return self
        }
    }
}
