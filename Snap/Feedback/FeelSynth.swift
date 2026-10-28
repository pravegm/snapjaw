import Foundation
import Synchronization

// MARK: - Commands (main thread → audio thread)
//
// Every payload is a plain value (Floats, Ints, enums without payloads), so copying a command never touches ARC and
// the audio thread can read it from the lock-free queue without allocating or locking. Ported from Hush's and
// Swoop's FeelSynth, made stereo (each voice has a pan) for Snapjaw's panned bug buzz.

enum FeelFilterMode: Sendable, Equatable {
    case lowPass, bandPass, highPass
}

/// Partial tables for struck resonators.
enum FeelRingKind: Sendable, Equatable {
    /// A soft, nearly pure bell (harmonic partials 1, 2, 3, 4.2 … rolled off hard).
    case chime
    /// Inharmonic church-bell partials (prime, hum an octave down, minor-third tierce, quint, nominal).
    case bell
    /// A marimba bar (1, 3.93, 9.3 …): the bog loop, soft UI notes.
    case marimba
    /// A wooden tick: UI clicks, the teeth clack, landings.
    case wood
    /// Glassy, sparse, bright: sparkles, dew.
    case glass
    /// A plucked string (harmonic, a touch stiff): the re-arm pluck.
    case pluck
}

/// A one-shot filtered-noise burst (thwacks, slaps, whiffs, breaths), optionally sweeping its cutoff.
struct FeelNoiseSpec: Sendable, Equatable {
    var mode: FeelFilterMode
    var cutoff: Float
    var cutoffEnd: Float
    var sweep: Float
    var q: Float
    var attack: Float
    /// Exponential decay time constant (s).
    var decay: Float
    var gain: Float
    var delay: Float
    /// −1 left … 1 right.
    var pan: Float

    init(_ mode: FeelFilterMode, cutoff: Float, to cutoffEnd: Float? = nil, sweep: Float = 0, q: Float = 0.8,
         attack: Float = 0.002, decay: Float, gain: Float, delay: Float = 0, pan: Float = 0) {
        self.mode = mode
        self.cutoff = cutoff
        self.cutoffEnd = cutoffEnd ?? cutoff
        self.sweep = sweep
        self.q = q
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
        self.pan = pan
    }
}

/// A pitched tone with a glide, vibrato and a 1/n harmonic stack (all harmonics: saw-like; `odd`: square-like).
struct FeelToneSpec: Sendable, Equatable {
    var start: Float
    var end: Float
    var glide: Float
    var duration: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var harmonics: Int
    var vibratoRate: Float
    var vibratoDepth: Float
    var delay: Float
    /// Only odd harmonics (1, 3, 5 …): a hollow, buzzy square (the bee's "Bzzt!").
    var odd: Bool
    var pan: Float

    init(start: Float, end: Float? = nil, glide: Float = 0.1, duration: Float, attack: Float = 0.01, decay: Float,
         gain: Float, harmonics: Int = 1, vibratoRate: Float = 0, vibratoDepth: Float = 0, delay: Float = 0,
         odd: Bool = false, pan: Float = 0) {
        self.start = start
        self.end = end ?? start
        self.glide = glide
        self.duration = duration
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.harmonics = harmonics
        self.vibratoRate = vibratoRate
        self.vibratoDepth = vibratoDepth
        self.delay = delay
        self.odd = odd
        self.pan = pan
    }
}

/// A struck modal resonator: up to `FeelSynth.maxPartials` decaying sinusoids.
struct FeelRingSpec: Sendable, Equatable {
    var kind: FeelRingKind
    var fundamental: Float
    var partials: Int
    /// Decay time constant of the first partial (s); higher partials decay faster.
    var decay: Float
    /// Amplitude roll-off per partial, 0…1 (higher = brighter).
    var brightness: Float
    var gain: Float
    var delay: Float
    /// Seeds a ±1.5 % partial detune so two strikes never sound identical.
    var seed: UInt32
    var pan: Float

    init(_ kind: FeelRingKind, fundamental: Float, partials: Int = 4, decay: Float, brightness: Float = 0.5,
         gain: Float, delay: Float = 0, seed: UInt32 = 1, pan: Float = 0) {
        self.kind = kind
        self.fundamental = fundamental
        self.partials = partials
        self.decay = decay
        self.brightness = brightness
        self.gain = gain
        self.delay = delay
        self.seed = seed
        self.pan = pan
    }
}

/// A water droplet (Minnaert bubble): a decaying sine whose pitch chirps (bog drips, sips, the "pop").
struct FeelDropSpec: Sendable, Equatable {
    var frequency: Float
    /// Pitch ratio reached by the end of the pop (> 1 rises).
    var chirp: Float
    var decay: Float
    var gain: Float
    var delay: Float
    var pan: Float

    init(frequency: Float, chirp: Float = 1.5, decay: Float, gain: Float, delay: Float = 0, pan: Float = 0) {
        self.frequency = frequency
        self.chirp = chirp
        self.decay = decay
        self.gain = gain
        self.delay = delay
        self.pan = pan
    }
}

/// A two-operator FM tone: a sine carrier phase-modulated by a sine at `ratio` × the carrier, whose index decays
/// faster than the tone (frog croaks).
struct FeelFMSpec: Sendable, Equatable {
    var carrier: Float
    var ratio: Float
    /// Peak modulation index (radians).
    var index: Float
    /// Time constant (s) of the index's decay.
    var indexDecay: Float
    var attack: Float
    var decay: Float
    var gain: Float
    var delay: Float
    var pan: Float

    init(carrier: Float, ratio: Float, index: Float, indexDecay: Float, attack: Float = 0.0008, decay: Float,
         gain: Float, delay: Float = 0, pan: Float = 0) {
        self.carrier = carrier
        self.ratio = ratio
        self.index = index
        self.indexDecay = indexDecay
        self.attack = attack
        self.decay = decay
        self.gain = gain
        self.delay = delay
        self.pan = pan
    }
}

/// The CHOMP's wet tail: granular noise. Tiny band-passed noise grains (1.5–5.5 ms, each at its own random centre
/// between `low` and `high` Hz) fire at `grainRate` per second; a share (`bubbles`) of them also pop a little rising
/// bubble. Over the whole voice an exponential envelope lasting about `duration` s.
struct FeelSquelchSpec: Sendable, Equatable {
    var duration: Float
    var grainRate: Float
    var low: Float
    var high: Float
    /// 0…1: the share of grains that also pop a bubble.
    var bubbles: Float
    var gain: Float
    var delay: Float
    var pan: Float

    init(duration: Float, grainRate: Float = 420, low: Float = 380, high: Float = 2600, bubbles: Float = 0.3,
         gain: Float, delay: Float = 0, pan: Float = 0) {
        self.duration = duration
        self.grainRate = grainRate
        self.low = low
        self.high = high
        self.bubbles = bubbles
        self.gain = gain
        self.delay = delay
        self.pan = pan
    }
}

/// The voice of one bug in the buzz layer (GAME-DESIGN §10). Per-species timbres.
enum FeelBuzzTimbre: Int, Sendable, Equatable, CaseIterable {
    case silent
    /// Housefly: a sawtooth ~190 Hz with wingbeat AM.
    case fly
    /// Gnat, fruit fly: thin and high.
    case gnat
    /// Bluebottle: fat, low, loud.
    case bluebottle
    /// Mosquito: a ~600 Hz whine.
    case mosquito
    /// Bee: a warm 220 Hz hum with vibrato.
    case bee
    /// Bumblebee: 110 Hz, round and slow.
    case bumblebee
    /// Wasp: a nasal, nasty 255 Hz.
    case wasp
    /// Dragonfly: rattling wings.
    case dragonfly
    /// Moth: a soft flutter of noise.
    case moth
    /// Cricket on the ground: chirps.
    case cricket
    /// Ladybird, firefly, scarab in flight: a low beetle drone.
    case beetle
    /// Grasshopper or cricket in a hop: a crackly wing rattle.
    case hopper
}

/// One buzz slot's target (sent at most every frame; the synth glides level and pan, and swaps timbres only through
/// silence, so a slot never clicks).
struct FeelBuzz: Sendable, Equatable {
    var timbre: FeelBuzzTimbre
    /// 0…1.
    var level: Float
    /// −1 left … 1 right.
    var pan: Float
    /// Pitch multiplier (each bug its own, ±6 %).
    var pitch: Float

    init(timbre: FeelBuzzTimbre = .silent, level: Float = 0, pan: Float = 0, pitch: Float = 1) {
        self.timbre = timbre
        self.level = level
        self.pan = pan
        self.pitch = pitch
    }
}

/// The continuous layers (sent every frame, glided per sample on the audio thread).
struct FeelBed: Sendable, Equatable {
    /// Master gain (0 = silent; sound off goes through here).
    var master: Float = 0
    /// Time constant (s) of the glide from the current layers to this bed (frames: ~0.05; silence: ~0.35).
    var glide: Float = 0.05

    // The creep groan: the rubbery leaf stretch.
    /// 0…1 level.
    var groan: Float = 0
    /// Its pitch (Hz), 70…140, following the closure.
    var groanHz: Float = 90

    // The bog.
    /// 0…1: wind in the reeds.
    var wind: Float = 0
    /// 0…1: frog croaks (every 3–9 s while > 0).
    var frogs: Float = 0
    /// Water drips per second.
    var dripRate: Float = 0
    /// 0…1: the night crickets.
    var crickets: Float = 0

    // Music: the plucked-marimba loop (96 bpm, C major pentatonic).
    /// 0…1 level.
    var music: Float = 0
    /// 1…5: how many voices play (the chain adds them at 2, 4, 6 and, R3, 8).
    var musicVoices: Float = 1

    /// True when any continuous layer is audible (the engine stays awake for it).
    var hasLayers: Bool {
        let zero: Float = 0
        if groan > zero || wind > zero || frogs > zero { return true }
        return dripRate > zero || crickets > zero || music > zero
    }

    mutating func approach(_ target: FeelBed, _ k: Float) {
        master += (target.master - master) * k
        groan += (target.groan - groan) * k
        groanHz += (target.groanHz - groanHz) * k
        wind += (target.wind - wind) * k
        frogs += (target.frogs - frogs) * k
        dripRate += (target.dripRate - dripRate) * k
        crickets += (target.crickets - crickets) * k
        music += (target.music - music) * k
        musicVoices += (target.musicVoices - musicVoices) * k
    }
}

enum FeelSynthCommand: Sendable, Equatable {
    case bed(FeelBed)
    case buzz(slot: Int, buzz: FeelBuzz)
    case noise(FeelNoiseSpec)
    case tone(FeelToneSpec)
    case ring(FeelRingSpec)
    case drop(FeelDropSpec)
    case fm(FeelFMSpec)
    case squelch(FeelSquelchSpec)
    /// Stop every one-shot voice and every buzz slot now (sound switched off, an interruption, a nap).
    case stopAll

    /// Peak gain parameter (0 for `bed`/`buzz`/`stopAll`), for tests.
    var gain: Float {
        switch self {
        case .noise(let spec): return spec.gain
        case .tone(let spec): return spec.gain
        case .ring(let spec): return spec.gain
        case .drop(let spec): return spec.gain
        case .fm(let spec): return spec.gain
        case .squelch(let spec): return spec.gain
        case .bed, .buzz, .stopAll: return 0
        }
    }

    /// When the voice starts (s after the command), for tests.
    var delay: Float {
        switch self {
        case .noise(let spec): return spec.delay
        case .tone(let spec): return spec.delay
        case .ring(let spec): return spec.delay
        case .drop(let spec): return spec.delay
        case .fm(let spec): return spec.delay
        case .squelch(let spec): return spec.delay
        case .bed, .buzz, .stopAll: return 0
        }
    }

    /// The voice's pan (0 for the continuous commands), for tests.
    var pan: Float {
        switch self {
        case .noise(let spec): return spec.pan
        case .tone(let spec): return spec.pan
        case .ring(let spec): return spec.pan
        case .drop(let spec): return spec.pan
        case .fm(let spec): return spec.pan
        case .squelch(let spec): return spec.pan
        case .bed, .buzz, .stopAll: return 0
        }
    }
}

// MARK: - DSP building blocks (audio thread)

/// Topology-preserving state-variable filter (Zavalishin), from Squish/Brim/Swoop/Hush. Band-pass normalised to 0 dB
/// at centre.
private struct FeelSVF {
    var a1: Float = 0, a2: Float = 0, a3: Float = 0, k: Float = 1
    var ic1: Float = 0, ic2: Float = 0

    mutating func tune(cutoff: Float, q: Float, sampleRate: Float) {
        let f = min(max(cutoff, 20), sampleRate * 0.45)
        let g = tan(Float.pi * f / sampleRate)
        k = 1 / max(q, 0.1)
        a1 = 1 / (1 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
    }

    mutating func process(_ x: Float, _ mode: FeelFilterMode) -> Float {
        let v3 = x - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        switch mode {
        case .lowPass: return v2
        case .bandPass: return v1 * k
        case .highPass: return x - k * v1 - v2
        }
    }
}

private enum FeelVoiceKind {
    case noise, tone, ring, drop, fm, squelch
}

private struct FeelVoice {
    var active = false
    /// The synth's start counter when this voice started (steal order: the smallest goes first).
    var stamp: UInt64 = 0
    /// R4 (QA-2 #16): the synth's sample clock when this voice started; it can't be stolen for `protectWindow` after.
    var born: UInt64 = 0
    /// R4 (QA-2 #16): samples left in a steal fade-out (0: not fading).
    var fadeLeft = 0
    /// R4 (QA-2 #16): the command that takes this slot once the fade-out ends.
    var next: FeelSynthCommand?
    /// The magnitude of this voice's last output sample (the size of the step if it stopped here).
    var last: Float = 0
    var kind: FeelVoiceKind = .noise
    var delay = 0
    var age = 0
    var attack = 1
    var length = 0
    var decayRate: Float = 1
    var level: Float = 1
    var gain: Float = 0
    var gainL: Float = 1
    var gainR: Float = 1
    // Noise and squelch.
    var filter = FeelSVF()
    var mode: FeelFilterMode = .bandPass
    var q: Float = 1
    var cutoff: Float = 1000
    var cutoffEnd: Float = 1000
    var sweepSamples = 0
    // Tone, drop and FM.
    var phase: Float = 0
    var frequency: Float = 0
    var startFrequency: Float = 0
    var endFrequency: Float = 0
    var glide = 1
    var harmonics = 1
    var odd = false
    var vibratoPhase: Float = 0
    var vibratoRate: Float = 0
    var vibratoDepth: Float = 0
    var chirpPerSample: Float = 1
    // FM.
    var modPhase: Float = 0
    var modRatio: Float = 1
    var index: Float = 0
    var indexRate: Float = 1
    // Squelch.
    var grainChance: Float = 0
    var grainEnv: Float = 0
    var grainDecay: Float = 0.99
    var low: Float = 400
    var high: Float = 2600
    var bubbleChance: Float = 0
    var bubbleEnv: Float = 0
    var bubblePhase: Float = 0
    var bubbleFrequency: Float = 600
    // Ring (its partial state lives in the synth's bank at this voice's slot).
    var partialCount = 0
}

/// The audio-thread state of one buzz slot.
private struct FeelBuzzState {
    /// The latest command for the slot.
    var want = FeelBuzz()
    /// What is sounding now (changes only through silence).
    var timbre: FeelBuzzTimbre = .silent
    var pitch: Float = 1
    var level: Float = 0
    var pan: Float = 0
    var phase: Float = 0
    var amPhase: Float = 0
    var vibratoPhase: Float = 0
    var wander: Float = 0
    var wanderTarget: Float = 0
    var wanderCountdown = 0
    var burst: Float = 0
    var chirpClock: Float = 0
    var gate: Float = 0
    var filter = FeelSVF()
    var filter2 = FeelSVF()
}

/// The fixed character of a tonal buzz timbre.
private struct FeelBuzzTone {
    var hz: Float
    var amRate: Float
    var amDepth: Float
    var vibratoRate: Float
    var vibratoDepth: Float
    var wander: Float
    var gain: Float
    var cutoff: Float
    var q: Float
    var bandPass: Bool
}

// MARK: - Synth

/// Snapjaw's real-time synth, rendered inside an `AVAudioSourceNode` (stereo Float32, or mono). Ported from Hush's and
/// Swoop's `FeelSynth` (lock-free command queue, voice pool, modal bank, limiter), made stereo, with Snapjaw's layers:
/// the 8-slot bug buzz, the creep groan, the bog (wind, frogs, drips, night crickets) and the marimba loop, and the
/// squelch voice for the CHOMP.
///
/// Threading: the main thread calls `send` (single producer); the audio thread calls `render` (single consumer).
/// Commands cross through a fixed-capacity single-producer/single-consumer ring whose two indices are atomics
/// (acquire/release), so the render path takes no locks, never allocates and never touches ARC.
/// Master chain per channel: DC blocker → a linked peak-follower limiter (ceiling 0.9) → tanh soft clip, so the output
/// can never clip.
final class FeelSynth: @unchecked Sendable {
    let sampleRate: Float

    /// QA-1 #4: 128 voices (an 8-bug Feast with a scarab issues ~76 commands). Render cost follows the active voices.
    static let voiceCount = 128
    /// A ring voice ends after this many decay time constants (e^−5 ≈ 0.7 %), so long bells don't hold a slot.
    static let ringLengthTaus: Float = 5
    static let maxPartials = 6
    static let queueCapacity = 1024
    static let buzzSlots = 8
    static let ceiling: Float = 0.9
    private static let partialStride = 5 // re, im, cos, sin, decay
    /// Below this a continuous layer is skipped entirely.
    private static let quiet: Float = 0.00002
    /// The bog loop: 96 bpm, eighth notes, a 32-step loop (4 bars), C major pentatonic.
    static let musicBPM: Float = 96
    static let musicSteps = 32
    /// The loop's voices (R3: a fifth, the chime double, joins at a chain of 8).
    static let musicVoiceCount = 5
    /// Buzz slot glides: the level's time constant (≈ 80 ms to fade in or out) and the pan's.
    static let buzzLevelTau: Float = 0.027
    static let buzzPanTau: Float = 0.06
    /// R4 (QA-2 #16): a stolen voice fades out over this long (≥ 5 ms, a smoothstep) before the new command takes its
    /// slot, so a steal never cuts a ringing voice dead. The new command's delay absorbs the wait.
    static let stealFade: Float = 0.006
    /// R4 (QA-2 #16): a voice is never stolen this soon after it starts, so a bite whose commands straddle two render
    /// callbacks (10 ms buffers; about 23 ms if iOS ignores the preference) never takes voices from its own first half.
    static let protectWindow: Float = 0.03

    private let queue: UnsafeMutablePointer<FeelSynthCommand>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)
    private let peakBits = Atomic<UInt32>(0)
    private let renderCount = Atomic<Int>(0)
    private let stolenCount = Atomic<Int>(0)
    private let droppedCount = Atomic<Int>(0)
    private let loudestEndBits = Atomic<UInt32>(0)

    // Audio-thread-only state below.
    private let voices: UnsafeMutablePointer<FeelVoice>
    private let bank: UnsafeMutablePointer<Float>
    private let buzz: UnsafeMutablePointer<FeelBuzzState>
    private var bed = FeelBed()
    private var target = FeelBed()
    private var glideK: Float = 0
    private var noiseState: UInt32 = 0x2545_F491
    private var retuneCounter = 0
    /// Monotonic voice start counter (each start takes the next stamp).
    private var startCounter: UInt64 = 0
    /// R4: samples rendered so far (a voice's age for the steal protection).
    private var clock: UInt64 = 0

    // Groan.
    private var groanPhase: Float = 0
    private var groanSlip: Float = 0.8
    private var groanJitter: Float = 1
    private var groanVibrato: Float = 0
    private var squeakPhase: Float = 0
    private var wobbleValue: Float = 0
    private var wobbleTarget: Float = 0
    private var wobbleCountdown = 0
    private var groanFilter = FeelSVF()
    private var groanFormant = FeelSVF()
    // Wind.
    private var windLFO: Float = 0
    private var windLFO2: Float = 0
    private var windFilterL = FeelSVF()
    private var windFilterR = FeelSVF()
    private var reedFilter = FeelSVF()
    // Frogs.
    private var frogCountdown = 0
    // Night crickets.
    private var nightClockA: Float = 0
    private var nightClockB: Float = 0.3
    private var nightPhaseA: Float = 0
    private var nightPhaseB: Float = 0
    private var nightGateA: Float = 0
    private var nightGateB: Float = 0
    // Music.
    private var musicCountdown = 0
    private var musicStep = -1
    // Master (per channel).
    private var dcInL: Float = 0
    private var dcOutL: Float = 0
    private var dcInR: Float = 0
    private var dcOutR: Float = 0
    private var envelope: Float = 0

    private let wobbleStep: Float
    private let wanderStep: Float
    private let buzzLevelK: Float
    private let buzzPanK: Float
    private let gateStep: Float
    private let burstDecay: Float
    private let hopperDecay: Float
    private let envelopeRelease: Float
    private let dcCoefficient: Float
    private let musicStepSamples: Int
    private let bubbleDecay: Float
    private let bubbleChirp: Float
    private let fadeSamples: Int
    private let protectSamples: UInt64

    init(sampleRate: Float) {
        let rate: Float = sampleRate > 1000 ? sampleRate : 48_000
        self.sampleRate = rate
        queue = UnsafeMutablePointer<FeelSynthCommand>.allocate(capacity: FeelSynth.queueCapacity)
        queue.initialize(repeating: .stopAll, count: FeelSynth.queueCapacity)
        voices = UnsafeMutablePointer<FeelVoice>.allocate(capacity: FeelSynth.voiceCount)
        voices.initialize(repeating: FeelVoice(), count: FeelSynth.voiceCount)
        let bankSize = FeelSynth.voiceCount * FeelSynth.maxPartials * FeelSynth.partialStride
        bank = UnsafeMutablePointer<Float>.allocate(capacity: bankSize)
        bank.initialize(repeating: 0, count: bankSize)
        buzz = UnsafeMutablePointer<FeelBuzzState>.allocate(capacity: FeelSynth.buzzSlots)
        buzz.initialize(repeating: FeelBuzzState(), count: FeelSynth.buzzSlots)
        glideK = 1 - exp(-1 / (0.05 * rate))
        wobbleStep = 1 - exp(-1 / (0.05 * rate))
        wanderStep = 1 - exp(-1 / (0.04 * rate))
        buzzLevelK = 1 - exp(-1 / (FeelSynth.buzzLevelTau * rate))
        buzzPanK = 1 - exp(-1 / (FeelSynth.buzzPanTau * rate))
        gateStep = 1 - exp(-1 / (0.002 * rate))
        burstDecay = exp(-1 / (0.0035 * rate))
        hopperDecay = exp(-1 / (0.002 * rate))
        envelopeRelease = exp(-1 / (0.08 * rate))
        dcCoefficient = 1 - 2 * Float.pi * 30 / rate
        musicStepSamples = max(Int(rate * 60 / FeelSynth.musicBPM / 2), 1)
        bubbleDecay = exp(-1 / (0.006 * rate))
        bubbleChirp = pow(1.8, 1 / (0.012 * rate))
        frogCountdown = Int(rate * 2)
        fadeSamples = max(Int((FeelSynth.stealFade * rate).rounded(.up)), 1)
        protectSamples = UInt64(max(Int(FeelSynth.protectWindow * rate), 1))
        tuneFixedFilters()
        retuneContinuous()
    }

    deinit {
        queue.deinitialize(count: FeelSynth.queueCapacity)
        queue.deallocate()
        voices.deinitialize(count: FeelSynth.voiceCount)
        voices.deallocate()
        buzz.deinitialize(count: FeelSynth.buzzSlots)
        buzz.deallocate()
        bank.deallocate()
    }

    // MARK: Main thread

    /// Queue a command (main thread only). Returns false if the queue is full (the command is dropped, never blocks).
    @discardableResult
    func send(_ command: FeelSynthCommand) -> Bool {
        let write = writeIndex.load(ordering: .relaxed)
        let next = (write + 1) % FeelSynth.queueCapacity
        guard next != readIndex.load(ordering: .acquiring) else { return false }
        queue[write] = command
        writeIndex.store(next, ordering: .releasing)
        return true
    }

    /// Loudest output sample so far (linear, either channel), for tests and diagnostics.
    var peak: Float { Float(bitPattern: peakBits.load(ordering: .relaxed)) }

    /// Render callbacks so far: if it stops climbing, the engine isn't pulling audio.
    var renderCallbacks: Int { renderCount.load(ordering: .relaxed) }

    /// One-shot commands that took over the oldest playing voice (all 128 busy; the old voice fades out first), for
    /// tests and diagnostics.
    var stolenVoices: Int { stolenCount.load(ordering: .relaxed) }

    /// One-shot commands dropped because every voice was too young to steal (or already fading), for tests and
    /// diagnostics.
    var droppedVoices: Int { droppedCount.load(ordering: .relaxed) }

    /// R4 (QA-2 #16): the loudest step any one-shot voice left when it stopped (its last sample's magnitude, before
    /// the pan and the master; `stopAll` aside), for tests: a voice that ends, fades or is stolen never clicks.
    var loudestVoiceEnd: Float { Float(bitPattern: loudestEndBits.load(ordering: .relaxed)) }

    /// R4 (QA-2 #16): the steal fade's gain, 1 → 0 as `x` (the share of the fade left) goes 1 → 0. A smoothstep, so
    /// both ends are flat. Pure.
    static func fadeCurve(_ x: Float) -> Float {
        let t = x.isFinite ? min(max(x, 0), 1) : 0
        return t * t * (3 - 2 * t)
    }

    /// Equal-power pan gains, normalised so the centre is 1 on each side: (√(1 − p), √(1 + p)). Pure.
    static func panGains(_ pan: Float) -> (left: Float, right: Float) {
        let p = pan.isFinite ? min(max(pan, -1), 1) : 0
        return ((1 - p).squareRoot(), (1 + p).squareRoot())
    }

    // MARK: Audio thread

    /// Mono: both channels summed into `out` (tests, and a mono route).
    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        render(frames: frames, left: out, right: nil)
    }

    /// Stereo into `left` and `right`; with `right` nil, the mono sum into `left`.
    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>?) {
        drain()
        let twoPi = 2 * Float.pi
        var blockPeak: Float = 0
        var blockEnd: Float = 0
        for frame in 0..<frames {
            bed.approach(target, glideK)
            retuneCounter += 1
            if retuneCounter >= 32 {
                retuneCounter = 0
                retuneContinuous()
            }

            var mid: Float = 0
            var l: Float = 0
            var r: Float = 0
            if bed.groan > FeelSynth.quiet {
                mid += renderGroan()
            }
            if bed.wind > FeelSynth.quiet {
                windLFO += twoPi * 0.11 / sampleRate
                if windLFO > twoPi { windLFO -= twoPi }
                windLFO2 += twoPi * 0.037 / sampleRate
                if windLFO2 > twoPi { windLFO2 -= twoPi }
                let swell: Float = 0.55 + 0.3 * sin(windLFO) + 0.15 * sin(windLFO2)
                let gust = swell * swell
                let reeds = reedFilter.process(nextNoise(), .highPass) * 0.18 * gust
                let level = 0.08 * bed.wind * swell
                l += (windFilterL.process(nextNoise(), .bandPass) + reeds) * level
                r += (windFilterR.process(nextNoise(), .bandPass) + reeds) * level
            }
            if bed.frogs > FeelSynth.quiet {
                frogCountdown -= 1
                if frogCountdown <= 0 {
                    frogCountdown = Int(sampleRate * (3 + 6 * unitNoise()))
                    croak()
                }
            }
            if bed.dripRate > 0.001, unitNoise() < bed.dripRate / sampleRate {
                let f: Float = 1300 + 1500 * unitNoise()
                let gain: Float = 0.03 + 0.03 * unitNoise()
                let pan: Float = 1.4 * unitNoise() - 0.7
                start(.drop(FeelDropSpec(frequency: f, chirp: 1.7, decay: 0.02 + 0.015 * unitNoise(), gain: gain,
                                         pan: pan)), mayTake: false)
            }
            if bed.crickets > FeelSynth.quiet {
                let pair = renderNightCrickets()
                l += pair.left
                r += pair.right
            }
            if bed.music > FeelSynth.quiet {
                runMusic()
            } else {
                musicCountdown = 0
            }
            for slot in 0..<FeelSynth.buzzSlots {
                let value = renderBuzzSlot(&buzz[slot])
                if value != 0 {
                    let gains = FeelSynth.panGains(buzz[slot].pan)
                    l += value * gains.left
                    r += value * gains.right
                }
            }
            for index in 0..<FeelSynth.voiceCount where voices[index].active {
                let before = voices[index].last
                var value = renderVoice(&voices[index], slot: index)
                // QA-2 #16: a stolen voice fades out, then hands its slot to the command that took it.
                let fading = voices[index].fadeLeft
                if fading > 0 {
                    value *= FeelSynth.fadeCurve(Float(fading) / Float(fadeSamples))
                    voices[index].fadeLeft = fading - 1
                    if fading == 1 { voices[index].active = false }
                }
                let size = abs(value)
                voices[index].last = size
                l += value * voices[index].gainL
                r += value * voices[index].gainR
                if !voices[index].active {
                    blockEnd = max(blockEnd, max(before, size))
                    if let next = voices[index].next {
                        launch(next, slot: index, late: fadeSamples)
                    }
                }
            }
            l = (l + mid) * bed.master
            r = (r + mid) * bed.master

            // DC blocker (30 Hz), then a linked peak follower that keeps the drive at or below the ceiling, then tanh.
            let blockedL = l - dcInL + dcCoefficient * dcOutL
            dcInL = l
            dcOutL = blockedL
            let blockedR = r - dcInR + dcCoefficient * dcOutR
            dcInR = r
            dcOutR = blockedR
            let magnitude = max(abs(blockedL), abs(blockedR))
            envelope = max(magnitude, envelope * envelopeRelease)
            let drive = envelope > FeelSynth.ceiling ? FeelSynth.ceiling / envelope : 1
            var outL = tanh(blockedL * drive)
            var outR = tanh(blockedR * drive)
            if !outL.isFinite || !outR.isFinite {
                outL = 0
                outR = 0
                resetFilters()
            }
            outL = min(max(outL, -0.98), 0.98)
            outR = min(max(outR, -0.98), 0.98)
            if let right {
                left[frame] = outL
                right[frame] = outR
                blockPeak = max(blockPeak, max(abs(outL), abs(outR)))
            } else {
                let mono = (outL + outR) * 0.5
                left[frame] = mono
                blockPeak = max(blockPeak, abs(mono))
            }
            clock &+= 1
        }
        let previous = Float(bitPattern: peakBits.load(ordering: .relaxed))
        if blockPeak > previous { peakBits.store(blockPeak.bitPattern, ordering: .relaxed) }
        let previousEnd = Float(bitPattern: loudestEndBits.load(ordering: .relaxed))
        if blockEnd > previousEnd { loudestEndBits.store(blockEnd.bitPattern, ordering: .relaxed) }
        renderCount.store(renderCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
    }

    // MARK: The creep groan

    /// The rubbery leaf stretch (GAME-DESIGN §10: "it warns you you're slow"). A stick-slip saw at 70–140 Hz (each
    /// period its own slip strength and a ±3 % jitter, a 6.5 Hz rubber vibrato, a slow random wobble) through a
    /// resonant low-pass at ~4.5× its pitch, a leafy 720 Hz formant, and a thin rubber squeak at 7.2× the pitch.
    private func renderGroan() -> Float {
        let twoPi = 2 * Float.pi
        wobbleCountdown -= 1
        if wobbleCountdown <= 0 {
            wobbleTarget = 2 * unitNoise() - 1
            wobbleCountdown = Int(sampleRate * (0.05 + 0.1 * unitNoise())) + 1
        }
        wobbleValue += (wobbleTarget - wobbleValue) * wobbleStep
        groanVibrato += twoPi * 6.5 / sampleRate
        if groanVibrato > twoPi { groanVibrato -= twoPi }
        let pitch = min(max(bed.groanHz, 40), 400) * (1 + 0.05 * wobbleValue) * (1 + 0.012 * sin(groanVibrato))
        let dt = min(pitch * groanJitter / sampleRate, 0.25)
        groanPhase += dt
        if groanPhase >= 1 {
            groanPhase -= 1
            groanSlip = 0.65 + 0.35 * unitNoise()
            groanJitter = 1 + 0.03 * (2 * unitNoise() - 1)
        }
        let saw = (2 * groanPhase - 1 - FeelSynth.polyBlep(groanPhase, dt)) * groanSlip
        let body = groanFilter.process(saw, .lowPass) * 0.1
        let leaf = groanFormant.process(saw, .bandPass) * 0.05
        squeakPhase += twoPi * min(pitch * 7.2, sampleRate * 0.4) / sampleRate
        if squeakPhase > twoPi { squeakPhase -= twoPi }
        let squeak = sin(squeakPhase) * 0.016 * groanSlip
        return (body + leaf + squeak) * bed.groan
    }

    /// Band-limited step correction for the saw (PolyBLEP), so the saws don't alias.
    private static func polyBlep(_ t: Float, _ dt: Float) -> Float {
        guard dt > 0 else { return 0 }
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        }
        if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    // MARK: The bog

    /// A frog, somewhere in the bog: 70 % a tree frog's "rib-bit" (two quick FM blips), else a bullfrog's low,
    /// rough "brrum". Randomly panned.
    private func croak() {
        let level = min(max(bed.frogs, 0), 1)
        let pan: Float = 1.4 * unitNoise() - 0.7
        if unitNoise() < 0.7 {
            let f: Float = 380 + 160 * unitNoise()
            start(.fm(FeelFMSpec(carrier: f, ratio: 0.5, index: 2.2, indexDecay: 0.025, attack: 0.004, decay: 0.035,
                                 gain: 0.05 * level, pan: pan)), mayTake: false)
            start(.fm(FeelFMSpec(carrier: f * 1.06, ratio: 0.5, index: 2.0, indexDecay: 0.025, attack: 0.004,
                                 decay: 0.04, gain: 0.045 * level, delay: 0.085, pan: pan)), mayTake: false)
        } else {
            let f: Float = 100 + 22 * unitNoise()
            start(.tone(FeelToneSpec(start: f, end: f * 0.88, glide: 0.25, duration: 0.34, attack: 0.03, decay: 0.12,
                                     gain: 0.055 * level, harmonics: 6, vibratoRate: 28, vibratoDepth: 0.05,
                                     pan: pan)), mayTake: false)
        }
    }

    /// Two distant crickets at night: 4.7 and 4.1 kHz chirps (three 24 ms pulses each), on their own periods.
    private func renderNightCrickets() -> (left: Float, right: Float) {
        let twoPi = 2 * Float.pi
        let step = 1 / sampleRate
        nightClockA += step
        if nightClockA >= 0.71 { nightClockA -= 0.71 }
        nightClockB += step
        if nightClockB >= 0.83 { nightClockB -= 0.83 }
        let pulseA: Float = FeelSynth.chirpGate(nightClockA)
        let pulseB: Float = FeelSynth.chirpGate(nightClockB)
        nightGateA += (pulseA - nightGateA) * gateStep
        nightGateB += (pulseB - nightGateB) * gateStep
        nightPhaseA += twoPi * 4700 / sampleRate
        if nightPhaseA > twoPi { nightPhaseA -= twoPi }
        nightPhaseB += twoPi * 4100 / sampleRate
        if nightPhaseB > twoPi { nightPhaseB -= twoPi }
        let a = sin(nightPhaseA) * nightGateA * 0.016 * bed.crickets
        let b = sin(nightPhaseB) * nightGateB * 0.014 * bed.crickets
        // A at the left, B at the right (fixed gains: pan −0.55 and +0.6).
        return (a * 1.245 + b * 0.632, a * 0.671 + b * 1.265)
    }

    /// A cricket's chirp gate at `t` s into its period: three 24 ms pulses, 16 ms apart, then quiet.
    static func chirpGate(_ t: Float) -> Float {
        guard t >= 0, t < 0.12 else { return 0 }
        return t.truncatingRemainder(dividingBy: 0.04) < 0.024 ? 1 : 0
    }

    // MARK: The marimba loop

    /// Semitones from C5 (523.25 Hz) for voice `voice` (0 melody, 1 bass, 2 counter, 3 sparkle, 4 the R3 chime
    /// double) at step `step` of the 32-step loop (four bars: C, Am, Dm, G), or nil for a rest. Every note is in C
    /// major pentatonic (C D E G A).
    /// A switch, not an array: no lazy global initialisation on the audio thread.
    static func musicNote(voice: Int, step: Int) -> Int? {
        switch voice {
        case 0:
            switch step {
            case 0: return 4      // E5
            case 2: return 7      // G5
            case 4: return 9      // A5
            case 6: return 7      // G5
            case 8: return 9      // A5
            case 10: return 4     // E5
            case 12: return 0     // C5
            case 13: return 2     // D5
            case 14: return 4     // E5
            case 16: return 2     // D5
            case 18: return 9     // A5
            case 20: return 7     // G5
            case 22: return 4     // E5
            case 24: return 2     // D5
            case 26: return -5    // G4
            case 28: return -3    // A4
            case 30: return 0     // C5
            case 31: return 2     // D5
            default: return nil
            }
        case 1:
            // Bass, two octaves down: C, A, D, G on beats 1 and 3.
            guard step % 4 == 0 else { return nil }
            switch step / 8 {
            case 0: return -24    // C3
            case 1: return -27    // A2
            case 2: return -22    // D3
            default: return -29   // G2
            }
        case 2:
            // The counter: the off-beats of beats 2 and 4, an octave up.
            guard step % 8 == 3 || step % 8 == 7 else { return nil }
            switch step / 8 {
            case 0: return step % 8 == 3 ? 7 : 12     // G5, C6
            case 1: return step % 8 == 3 ? 9 : 16     // A5, E6
            case 2: return step % 8 == 3 ? 14 : 9     // D6, A5
            default: return step % 8 == 3 ? 14 : 7    // D6, G5
            }
        case 3:
            // The sparkle: a glassy tick on every odd eighth, two octaves up.
            guard step % 2 == 1 else { return nil }
            switch (step / 2) % 4 {
            case 0: return 24     // C7
            case 1: return 28     // E7
            case 2: return 31     // G7
            default: return 26    // D7
            }
        case 4:
            // R3, the ×5 top step: the melody doubled an octave up on a bright chime (always pentatonic).
            guard let melody = musicNote(voice: 0, step: step) else { return nil }
            return melody + 12
        default:
            return nil
        }
    }

    private func runMusic() {
        musicCountdown -= 1
        guard musicCountdown <= 0 else { return }
        musicCountdown = musicStepSamples
        musicStep = (musicStep + 1) % FeelSynth.musicSteps
        let level = min(max(bed.music, 0), 1)
        let voicesOn = bed.musicVoices
        for voice in 0..<FeelSynth.musicVoiceCount {
            guard voicesOn >= Float(voice) + 0.5 else { break }
            guard let note = FeelSynth.musicNote(voice: voice, step: musicStep) else { continue }
            let f = 523.25 * pow(2, Float(note) / 12)
            let downbeat = musicStep % 8 == 0
            switch voice {
            case 0:
                start(.ring(FeelRingSpec(.marimba, fundamental: f, partials: 4, decay: 0.22, brightness: 0.35,
                                         gain: (downbeat ? 0.05 : 0.04) * level, seed: UInt32(musicStep * 7 + 3))))
            case 1:
                start(.ring(FeelRingSpec(.marimba, fundamental: f, partials: 3, decay: 0.32, brightness: 0.45,
                                         gain: 0.06 * level, seed: UInt32(musicStep * 5 + 1))))
            case 2:
                start(.ring(FeelRingSpec(.marimba, fundamental: f, partials: 3, decay: 0.18, brightness: 0.3,
                                         gain: 0.03 * level, seed: UInt32(musicStep * 3 + 2), pan: 0.3)))
            case 4:
                start(.ring(FeelRingSpec(.chime, fundamental: f, partials: 3, decay: 0.2, brightness: 0.3,
                                         gain: 0.018 * level, seed: UInt32(musicStep * 11 + 5))))
            default:
                start(.ring(FeelRingSpec(.glass, fundamental: f, partials: 2, decay: 0.06, brightness: 0.25,
                                         gain: 0.012 * level, seed: UInt32(musicStep + 11), pan: -0.3)))
            }
        }
    }

    // MARK: The buzz layer

    /// One slot per sample: glide the level and pan, swap the timbre only through silence, render.
    private func renderBuzzSlot(_ s: inout FeelBuzzState) -> Float {
        let want = s.want
        let same = want.timbre == s.timbre && abs(want.pitch - s.pitch) < 0.0005
        if !same && s.level < 0.0008 {
            s.timbre = want.timbre
            s.pitch = want.pitch
            s.level = 0
            s.pan = want.pan
            s.phase = 0
            s.chirpClock = 0
            s.gate = 0
            s.burst = 0
            tuneBuzz(&s)
        }
        let matches = want.timbre == s.timbre && abs(want.pitch - s.pitch) < 0.0005
        let goal: Float = matches ? want.level : 0
        s.level += (goal - s.level) * buzzLevelK
        s.pan += (want.pan - s.pan) * buzzPanK
        if s.timbre == .silent { return 0 }
        if s.level < 0.00005 && goal <= 0 { return 0 }
        return buzzVoice(&s) * s.level
    }

    private static func buzzTone(_ timbre: FeelBuzzTimbre) -> FeelBuzzTone {
        switch timbre {
        case .fly:
            return FeelBuzzTone(hz: 190, amRate: 11, amDepth: 0.35, vibratoRate: 0, vibratoDepth: 0, wander: 0.04,
                                gain: 0.055, cutoff: 1500, q: 1.1, bandPass: false)
        case .gnat:
            return FeelBuzzTone(hz: 420, amRate: 19, amDepth: 0.4, vibratoRate: 0, vibratoDepth: 0, wander: 0.05,
                                gain: 0.03, cutoff: 3000, q: 0.9, bandPass: false)
        case .bluebottle:
            return FeelBuzzTone(hz: 150, amRate: 7, amDepth: 0.25, vibratoRate: 0, vibratoDepth: 0, wander: 0.035,
                                gain: 0.065, cutoff: 1100, q: 2, bandPass: false)
        case .mosquito:
            return FeelBuzzTone(hz: 610, amRate: 3, amDepth: 0.1, vibratoRate: 6, vibratoDepth: 0.02, wander: 0.025,
                                gain: 0.04, cutoff: 1220, q: 2.5, bandPass: true)
        case .bee:
            return FeelBuzzTone(hz: 220, amRate: 4, amDepth: 0.1, vibratoRate: 5.5, vibratoDepth: 0.015,
                                wander: 0.015, gain: 0.055, cutoff: 900, q: 1.4, bandPass: false)
        case .bumblebee:
            return FeelBuzzTone(hz: 110, amRate: 3, amDepth: 0.15, vibratoRate: 4, vibratoDepth: 0.01, wander: 0.01,
                                gain: 0.065, cutoff: 620, q: 1.8, bandPass: false)
        case .wasp:
            return FeelBuzzTone(hz: 255, amRate: 13, amDepth: 0.25, vibratoRate: 9, vibratoDepth: 0.025,
                                wander: 0.03, gain: 0.05, cutoff: 1700, q: 1.4, bandPass: true)
        case .beetle:
            return FeelBuzzTone(hz: 130, amRate: 6, amDepth: 0.2, vibratoRate: 0, vibratoDepth: 0, wander: 0.02,
                                gain: 0.05, cutoff: 700, q: 1.5, bandPass: false)
        case .silent, .dragonfly, .moth, .cricket, .hopper:
            return FeelBuzzTone(hz: 200, amRate: 0, amDepth: 0, vibratoRate: 0, vibratoDepth: 0, wander: 0, gain: 0,
                                cutoff: 1000, q: 1, bandPass: false)
        }
    }

    private func tuneBuzz(_ s: inout FeelBuzzState) {
        switch s.timbre {
        case .fly, .gnat, .bluebottle, .mosquito, .bee, .bumblebee, .wasp, .beetle:
            let tone = FeelSynth.buzzTone(s.timbre)
            s.filter.tune(cutoff: tone.cutoff * min(max(s.pitch, 0.5), 2), q: tone.q, sampleRate: sampleRate)
        case .dragonfly:
            s.filter.tune(cutoff: 900, q: 1.3, sampleRate: sampleRate)
            s.filter2.tune(cutoff: 300, q: 0.9, sampleRate: sampleRate)
        case .moth:
            s.filter.tune(cutoff: 520, q: 0.8, sampleRate: sampleRate)
        case .hopper:
            s.filter.tune(cutoff: 2600, q: 1.6, sampleRate: sampleRate)
        case .cricket, .silent:
            break
        }
    }

    private func buzzVoice(_ s: inout FeelBuzzState) -> Float {
        let twoPi = 2 * Float.pi
        // A slow random wander: flight is never a steady tone.
        s.wanderCountdown -= 1
        if s.wanderCountdown <= 0 {
            s.wanderTarget = 2 * unitNoise() - 1
            s.wanderCountdown = Int(sampleRate * (0.06 + 0.12 * unitNoise())) + 1
        }
        s.wander += (s.wanderTarget - s.wander) * wanderStep
        let pitch = min(max(s.pitch, 0.5), 2)
        switch s.timbre {
        case .silent:
            return 0
        case .fly, .gnat, .bluebottle, .mosquito, .bee, .bumblebee, .wasp, .beetle:
            let tone = FeelSynth.buzzTone(s.timbre)
            var f = tone.hz * pitch * (1 + tone.wander * s.wander)
            if tone.vibratoDepth > 0 {
                s.vibratoPhase += twoPi * tone.vibratoRate / sampleRate
                if s.vibratoPhase > twoPi { s.vibratoPhase -= twoPi }
                f *= 1 + tone.vibratoDepth * sin(s.vibratoPhase)
            }
            s.amPhase += twoPi * tone.amRate / sampleRate
            if s.amPhase > twoPi { s.amPhase -= twoPi }
            let am = 1 - tone.amDepth * (0.5 + 0.5 * sin(s.amPhase))
            let dt = min(f / sampleRate, 0.25)
            s.phase += dt
            if s.phase >= 1 { s.phase -= 1 }
            let saw = 2 * s.phase - 1 - FeelSynth.polyBlep(s.phase, dt)
            var out = s.filter.process(saw, tone.bandPass ? .bandPass : .lowPass)
            if s.timbre == .mosquito { out = out * 0.6 + sin(twoPi * s.phase) * 0.4 }
            return out * am * tone.gain
        case .dragonfly:
            // Rattling wings: a noise burst on every wingbeat (~36 Hz), over a low whirr.
            s.amPhase += 36 * pitch * (1 + 0.1 * s.wander) / sampleRate
            if s.amPhase >= 1 {
                s.amPhase -= 1
                s.burst = 0.6 + 0.4 * unitNoise()
            }
            s.burst *= burstDecay
            let rattle = s.filter.process(nextNoise() * s.burst, .bandPass)
            let dt = min(38 * pitch / sampleRate, 0.25)
            s.phase += dt
            if s.phase >= 1 { s.phase -= 1 }
            let saw = 2 * s.phase - 1 - FeelSynth.polyBlep(s.phase, dt)
            let whirr = s.filter2.process(saw, .lowPass)
            return (rattle * 1.4 + whirr * 0.3) * 0.07
        case .moth:
            // A soft flutter: low noise gated by the wingbeat (~13 Hz).
            s.amPhase += twoPi * 13 * pitch * (1 + 0.15 * s.wander) / sampleRate
            if s.amPhase > twoPi { s.amPhase -= twoPi }
            let flap = abs(sin(s.amPhase))
            return s.filter.process(nextNoise(), .lowPass) * flap * flap * 0.09
        case .hopper:
            // A crackly wing rattle (~24 Hz bursts, bright and dry).
            s.amPhase += 24 * pitch * (1 + 0.2 * s.wander) / sampleRate
            if s.amPhase >= 1 {
                s.amPhase -= 1
                s.burst = 0.5 + 0.5 * unitNoise()
            }
            s.burst *= hopperDecay
            return s.filter.process(nextNoise() * s.burst, .bandPass) * 0.15
        case .cricket:
            // Chirps: three 24 ms pulses of a 4.4 kHz tone every ~0.62 s.
            let period: Float = 0.62 / pitch
            s.chirpClock += 1 / sampleRate
            if s.chirpClock >= period { s.chirpClock -= period }
            let pulse = FeelSynth.chirpGate(s.chirpClock)
            s.gate += (pulse - s.gate) * gateStep
            s.phase += min(4400 * pitch, sampleRate * 0.4) / sampleRate
            if s.phase >= 1 { s.phase -= 1 }
            return sin(twoPi * s.phase) * s.gate * 0.035
        }
    }

    // MARK: Plumbing

    private func tuneFixedFilters() {
        groanFormant.tune(cutoff: 720, q: 3, sampleRate: sampleRate)
        windFilterL.tune(cutoff: 650, q: 0.6, sampleRate: sampleRate)
        windFilterR.tune(cutoff: 800, q: 0.6, sampleRate: sampleRate)
        reedFilter.tune(cutoff: 3500, q: 0.7, sampleRate: sampleRate)
    }

    private func retuneContinuous() {
        let pitch = min(max(bed.groanHz, 40), 400) * (1 + 0.05 * wobbleValue)
        groanFilter.tune(cutoff: pitch * 4.5, q: 4, sampleRate: sampleRate)
    }

    private func drain() {
        var read = readIndex.load(ordering: .relaxed)
        let write = writeIndex.load(ordering: .acquiring)
        var handled = 0
        while read != write && handled < 256 {
            let command = queue[read]
            read = (read + 1) % FeelSynth.queueCapacity
            handled += 1
            apply(command)
        }
        readIndex.store(read, ordering: .releasing)
    }

    private func apply(_ command: FeelSynthCommand) {
        switch command {
        case .bed(let params):
            target = FeelSynth.sanitised(params)
            let glide = params.glide.isFinite ? min(max(params.glide, 0.004), 10) : 0.05
            glideK = 1 - exp(-1 / (glide * sampleRate))
        case .buzz(let slot, let wanted):
            guard slot >= 0, slot < FeelSynth.buzzSlots else { return }
            var clean = wanted
            clean.level = clean.level.isFinite ? min(max(clean.level, 0), 1) : 0
            clean.pan = clean.pan.isFinite ? min(max(clean.pan, -1), 1) : 0
            clean.pitch = clean.pitch.isFinite ? min(max(clean.pitch, 0.5), 2) : 1
            buzz[slot].want = clean
        case .stopAll:
            for index in 0..<FeelSynth.voiceCount { voices[index] = FeelVoice() }
            for slot in 0..<FeelSynth.buzzSlots {
                buzz[slot].want = FeelBuzz()
                buzz[slot].level = 0
                buzz[slot].timbre = .silent
            }
        case .noise, .tone, .ring, .drop, .fm, .squelch:
            start(command)
        }
    }

    /// QA-1 #16: every bed field finite and in range (one NaN would otherwise latch the synth silent).
    static func sanitised(_ bed: FeelBed) -> FeelBed {
        func unit(_ value: Float) -> Float { value.isFinite ? min(max(value, 0), 1) : 0 }
        var clean = bed
        clean.master = bed.master.isFinite ? min(max(bed.master, 0), 4) : 0
        clean.glide = bed.glide.isFinite ? min(max(bed.glide, 0.004), 10) : 0.05
        clean.groan = unit(bed.groan)
        clean.groanHz = bed.groanHz.isFinite ? min(max(bed.groanHz, 40), 400) : 90
        clean.wind = unit(bed.wind)
        clean.frogs = unit(bed.frogs)
        clean.dripRate = bed.dripRate.isFinite ? min(max(bed.dripRate, 0), 50) : 0
        clean.crickets = unit(bed.crickets)
        clean.music = unit(bed.music)
        let mostVoices = Float(FeelSynth.musicVoiceCount)
        clean.musicVoices = bed.musicVoices.isFinite ? min(max(bed.musicVoices, 1), mostVoices) : 1
        return clean
    }

    private func resetFilters() {
        // QA-1 #16: the glided bed restarts from silence (it glides back up to the sanitised target), and every
        // oscillator phase restarts, so no NaN can survive a reset.
        bed = FeelBed()
        groanPhase = 0
        groanSlip = 0.8
        groanJitter = 1
        groanVibrato = 0
        squeakPhase = 0
        wobbleValue = 0
        wobbleTarget = 0
        windLFO = 0
        windLFO2 = 0
        nightPhaseA = 0
        nightPhaseB = 0
        nightGateA = 0
        nightGateB = 0
        groanFilter = FeelSVF()
        groanFormant = FeelSVF()
        windFilterL = FeelSVF()
        windFilterR = FeelSVF()
        reedFilter = FeelSVF()
        tuneFixedFilters()
        retuneContinuous()
        envelope = 0
        dcInL = 0
        dcOutL = 0
        dcInR = 0
        dcOutR = 0
        for index in 0..<FeelSynth.voiceCount { voices[index] = FeelVoice() }
        for slot in 0..<FeelSynth.buzzSlots {
            let wanted = buzz[slot].want
            buzz[slot] = FeelBuzzState()
            buzz[slot].want = wanted
        }
    }

    private func nextNoise() -> Float {
        noiseState ^= noiseState << 13
        noiseState ^= noiseState >> 17
        noiseState ^= noiseState << 5
        return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
    }

    private func unitNoise() -> Float {
        (nextNoise() + 1) * 0.5
    }

    /// QA-1 #4 and R4 (QA-2 #16): a free voice, else the voice that started first (the smallest stamp), but never one
    /// younger than `protectWindow` (a bite's own commands never take each other's voices, even across two render
    /// callbacks) and never one already fading out for another command; if none is left, the command is dropped.
    /// The taken voice fades out over `stealFade` and the command then starts in its slot (a voice still waiting out
    /// its delay is silent, so it is replaced at once). `mayTake: false` (the bog's drips and frogs) only ever uses a
    /// free voice. 128 voices make stealing rare; the oldest voice has usually decayed to almost nothing.
    private func start(_ command: FeelSynthCommand, mayTake: Bool = true) {
        var free = -1
        var oldest = -1
        var oldestStamp = UInt64.max
        for index in 0..<FeelSynth.voiceCount {
            if !voices[index].active {
                free = index
                break
            }
            if voices[index].fadeLeft > 0 { continue }
            if clock &- voices[index].born < protectSamples { continue }
            let stamp = voices[index].stamp
            if stamp < oldestStamp {
                oldestStamp = stamp
                oldest = index
            }
        }
        if free >= 0 {
            launch(command, slot: free, late: 0)
            return
        }
        guard mayTake else { return }
        guard oldest >= 0 else {
            droppedCount.store(droppedCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
            return
        }
        stolenCount.store(stolenCount.load(ordering: .relaxed) &+ 1, ordering: .relaxed)
        if voices[oldest].delay > 0 {
            launch(command, slot: oldest, late: 0)
        } else {
            voices[oldest].fadeLeft = fadeSamples
            voices[oldest].next = command
        }
    }

    /// Starts `command` in `slot` now. `late`: samples it has already waited (a steal fade), taken off its delay.
    private func launch(_ command: FeelSynthCommand, slot: Int, late: Int) {
        startCounter &+= 1
        var voice = FeelVoice()
        voice.active = true
        voice.stamp = startCounter
        voice.born = clock
        let gains = FeelSynth.panGains(command.pan)
        voice.gainL = gains.left
        voice.gainR = gains.right
        switch command {
        case .noise(let spec):
            voice.kind = .noise
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.mode = spec.mode
            voice.q = spec.q
            voice.cutoff = spec.cutoff
            voice.cutoffEnd = spec.cutoffEnd
            voice.sweepSamples = abs(spec.cutoffEnd - spec.cutoff) > 1 ? max(Int(spec.sweep * sampleRate), 1) : 0
            voice.filter.tune(cutoff: spec.cutoff, q: spec.q, sampleRate: sampleRate)
        case .tone(let spec):
            voice.kind = .tone
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.length = max(Int(spec.duration * sampleRate), voice.attack + 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.gain = spec.gain
            voice.startFrequency = spec.start
            voice.endFrequency = spec.end
            voice.glide = max(Int(spec.glide * sampleRate), 1)
            voice.harmonics = min(max(spec.harmonics, 1), 9)
            voice.odd = spec.odd
            voice.vibratoRate = spec.vibratoRate
            voice.vibratoDepth = spec.vibratoDepth
        case .drop(let spec):
            voice.kind = .drop
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0015 * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 6)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.frequency, 40), sampleRate * 0.4)
            voice.chirpPerSample = pow(max(spec.chirp, 0.25), 1 / Float(max(voice.length, 1)))
        case .fm(let spec):
            voice.kind = .fm
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(spec.attack * sampleRate), 1)
            voice.decayRate = exp(-1 / max(spec.decay * sampleRate, 1))
            voice.length = voice.attack + Int(spec.decay * sampleRate * 7)
            voice.gain = spec.gain
            voice.frequency = min(max(spec.carrier, 40), sampleRate * 0.42)
            voice.modRatio = max(spec.ratio, 0.01)
            voice.index = max(spec.index, 0)
            voice.indexRate = exp(-1 / max(spec.indexDecay * sampleRate, 1))
        case .squelch(let spec):
            voice.kind = .squelch
            let duration = min(max(spec.duration, 0.02), 2)
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.004 * sampleRate), 1)
            voice.decayRate = exp(-1 / max(duration * 0.38 * sampleRate, 1))
            voice.length = voice.attack + Int(duration * 1.5 * sampleRate)
            voice.gain = spec.gain
            voice.grainChance = min(max(spec.grainRate, 0), 4000) / sampleRate
            voice.low = min(max(spec.low, 60), sampleRate * 0.4)
            voice.high = min(max(spec.high, voice.low + 1), sampleRate * 0.42)
            voice.bubbleChance = min(max(spec.bubbles, 0), 1)
            voice.filter.tune(cutoff: voice.low, q: 3, sampleRate: sampleRate)
        case .ring(let spec):
            voice.kind = .ring
            voice.delay = Int(max(spec.delay, 0) * sampleRate)
            voice.attack = max(Int(0.0005 * sampleRate), 1)
            voice.decayRate = 1
            voice.length = max(min(Int(spec.decay * sampleRate * FeelSynth.ringLengthTaus), Int(sampleRate * 6)), 1)
            voice.gain = 1
            configureRing(spec, slot: slot, voice: &voice)
        case .bed, .buzz, .stopAll:
            return
        }
        voice.delay = max(voice.delay - max(late, 0), 0)
        voices[slot] = voice
    }

    private static func ratio(_ kind: FeelRingKind, _ n: Int) -> Float {
        switch kind {
        case .chime:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.0
            case 3: return 4.2
            case 4: return 5.4
            default: return 6.8
            }
        case .bell:
            switch n {
            case 0: return 1      // prime
            case 1: return 0.5    // hum
            case 2: return 1.19   // tierce (minor third)
            case 3: return 1.5    // quint
            case 4: return 2.0    // nominal
            default: return 2.66
            }
        case .marimba:
            switch n {
            case 0: return 1
            case 1: return 3.93
            case 2: return 9.3
            case 3: return 12.0
            case 4: return 15.2
            default: return 18.6
            }
        case .wood:
            switch n {
            case 0: return 1
            case 1: return 2.6
            case 2: return 3.9
            case 3: return 5.4
            case 4: return 6.9
            default: return 8.6
            }
        case .glass:
            switch n {
            case 0: return 1
            case 1: return 2.32
            case 2: return 4.25
            case 3: return 6.63
            case 4: return 9.38
            default: return 12.1
            }
        case .pluck:
            switch n {
            case 0: return 1
            case 1: return 2.0
            case 2: return 3.005
            case 3: return 4.015
            case 4: return 5.03
            default: return 6.05
            }
        }
    }

    private func configureRing(_ spec: FeelRingSpec, slot: Int, voice: inout FeelVoice) {
        let count = min(max(spec.partials, 1), FeelSynth.maxPartials)
        voice.partialCount = count
        let brightness = min(max(spec.brightness, 0.05), 0.98)
        var total: Float = 0
        for n in 0..<count { total += pow(brightness, Float(n)) }
        var jitter = spec.seed | 1
        let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
        for n in 0..<count {
            jitter ^= jitter << 13
            jitter ^= jitter >> 17
            jitter ^= jitter << 5
            let detune: Float = n == 0 ? 1 : 1 + 0.015 * (Float(jitter % 2001) / 1000 - 1)
            let frequency = spec.fundamental * FeelSynth.ratio(spec.kind, n) * detune
            let offset = base + n * FeelSynth.partialStride
            guard frequency > 20, frequency < sampleRate * 0.45 else {
                bank[offset] = 0
                bank[offset + 1] = 0
                bank[offset + 2] = 1
                bank[offset + 3] = 0
                bank[offset + 4] = 0
                continue
            }
            var tau = spec.decay / (1 + 0.7 * Float(n))
            // A bell's hum (an octave under the prime) is what lingers in a real bell.
            if spec.kind == .bell && n == 1 { tau = spec.decay * 1.3 }
            if frequency > 2500 && frequency < 4500 && n > 0 { tau *= 0.5 } // no lingering screech in the ear's peak
            let omega = 2 * Float.pi * frequency / sampleRate
            bank[offset] = spec.gain * pow(brightness, Float(n)) / total * 1.6
            bank[offset + 1] = 0
            bank[offset + 2] = cos(omega)
            bank[offset + 3] = sin(omega)
            bank[offset + 4] = exp(-1 / max(tau * sampleRate, 1))
        }
    }

    private func renderVoice(_ voice: inout FeelVoice, slot: Int) -> Float {
        if voice.delay > 0 {
            voice.delay -= 1
            return 0
        }
        let age = voice.age
        voice.age += 1
        if age >= voice.length {
            voice.active = false
            return 0
        }
        let envelope: Float
        if age < voice.attack {
            envelope = Float(age) / Float(voice.attack)
        } else {
            voice.level *= voice.decayRate
            envelope = voice.level
        }
        if envelope < 0.0003 && age > voice.attack {
            voice.active = false
            return 0
        }
        // A gentle release over the last 30 ms so nothing ever clicks off.
        let left = voice.length - age
        let release = min(Float(left) / (0.03 * sampleRate), 1)
        let twoPi = 2 * Float.pi
        switch voice.kind {
        case .noise:
            if voice.sweepSamples > 0 && age % 32 == 0 {
                let progress = min(Float(age) / Float(voice.sweepSamples), 1)
                let cutoff = voice.cutoff * pow(voice.cutoffEnd / max(voice.cutoff, 1), progress)
                voice.filter.tune(cutoff: cutoff, q: voice.q, sampleRate: sampleRate)
            }
            return voice.filter.process(nextNoise(), voice.mode) * envelope * voice.gain * release
        case .tone:
            let progress = min(Float(age) / Float(voice.glide), 1)
            var frequency = voice.startFrequency + (voice.endFrequency - voice.startFrequency) * progress
            if voice.vibratoDepth > 0 {
                voice.vibratoPhase += twoPi * voice.vibratoRate / sampleRate
                if voice.vibratoPhase > twoPi { voice.vibratoPhase -= twoPi }
                frequency *= 1 + voice.vibratoDepth * sin(voice.vibratoPhase)
            }
            voice.phase += twoPi * frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            var value: Float = 0
            let limit = sampleRate * 0.45
            let harmonicStep = voice.odd ? 2 : 1
            var harmonic = 1
            var count = 0
            while count < voice.harmonics {
                if frequency * Float(harmonic) < limit {
                    value += sin(voice.phase * Float(harmonic)) / Float(harmonic)
                }
                harmonic += harmonicStep
                count += 1
            }
            return value * envelope * voice.gain * release
        case .drop:
            voice.frequency *= voice.chirpPerSample
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            return sin(voice.phase) * envelope * voice.gain * release
        case .fm:
            voice.modPhase += twoPi * voice.frequency * voice.modRatio / sampleRate
            if voice.modPhase > twoPi { voice.modPhase -= twoPi }
            voice.phase += twoPi * voice.frequency / sampleRate
            if voice.phase > twoPi { voice.phase -= twoPi }
            voice.index *= voice.indexRate
            return sin(voice.phase + voice.index * sin(voice.modPhase)) * envelope * voice.gain * release
        case .squelch:
            if unitNoise() < voice.grainChance {
                voice.grainEnv = 0.4 + 0.6 * unitNoise()
                voice.grainDecay = exp(-1 / ((0.0015 + 0.004 * unitNoise()) * sampleRate))
                let centre = voice.low * pow(voice.high / voice.low, unitNoise())
                voice.filter.tune(cutoff: centre, q: 3, sampleRate: sampleRate)
                if unitNoise() < voice.bubbleChance {
                    voice.bubbleEnv = 1
                    voice.bubbleFrequency = 350 + 700 * unitNoise()
                }
            }
            voice.grainEnv *= voice.grainDecay
            let grain = voice.filter.process(nextNoise() * voice.grainEnv, .bandPass) * 1.6
            var bubble: Float = 0
            if voice.bubbleEnv > 0.001 {
                voice.bubbleFrequency = min(voice.bubbleFrequency * bubbleChirp, sampleRate * 0.4)
                voice.bubblePhase += twoPi * voice.bubbleFrequency / sampleRate
                if voice.bubblePhase > twoPi { voice.bubblePhase -= twoPi }
                voice.bubbleEnv *= bubbleDecay
                bubble = sin(voice.bubblePhase) * voice.bubbleEnv * 0.5
            }
            return (grain + bubble) * envelope * voice.gain * release
        case .ring:
            let base = slot * FeelSynth.maxPartials * FeelSynth.partialStride
            var sum: Float = 0
            for n in 0..<voice.partialCount {
                let o = base + n * FeelSynth.partialStride
                let re = bank[o]
                let im = bank[o + 1]
                let c = bank[o + 2]
                let s = bank[o + 3]
                let d = bank[o + 4]
                let newIm = (re * s + im * c) * d
                bank[o] = (re * c - im * s) * d
                bank[o + 1] = newIm
                sum += newIm
            }
            return sum * envelope * release
        }
    }
}
