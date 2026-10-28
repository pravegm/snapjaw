import CoreGraphics
import Foundation
import QuartzCore
import UIKit

/// Audio + haptics for Snapjaw (GAME-DESIGN §10). The App calls `start()` once at launch, sets the toggles from its
/// SettingsStore, then calls `handle(_:telemetry:)` every game frame (and `homeTrap(closure:snapped:)` every Home
/// frame). Everything audible is synthesised in real time (`FeelSynth`, stereo); every touch is Core Haptics
/// (`FeelHaptics`).
///
/// Per frame it builds one small value (`FeelBed`: the creep groan, the bog, the marimba loop) and up to eight buzz
/// slots (`FeelBuzzMixer`: the bugs on screen, panned to where they are), pushes them into a lock-free queue (≤ 60 Hz)
/// and steers the looping creep texture (≤ 30 Hz). Events map to short recipes from `FeelSoundBook` and
/// `FeelHapticBook`. The bite frame is choreographed: the CHOMP first, each caught bug's crunch inside it, escapes'
/// whiffs, the stings' "Bzzt!" after the teeth, then the Feast sparkle and pop, the chain chime after the gulp.
///
/// R2: hunger speaks too (`hungry`: a stomach rumble and its haptic; `wilted`: a soft droop and a weak haptic), and
/// every haptic cue of one frame plays as one merged pattern.
///
/// R3: a sting's verdict follows its "Bzzt!": a sting that cost snaps (`stung` cost ≥ 1) plays the descending
/// two-note loss blip with a heavier sting haptic; a free one (every sting of the frame cost 0: the first bee of
/// Sprout's run 1) plays a gentle "oops" instead. The chain's first `chainUp` at ×5 flares once (a bright rising
/// chord), and the wilt's droop is two sad little sighs.
///
/// Battery: with `idle` set (menus), or after `idleDelay` s with no play and no events, the engines idle by themselves
/// (the haptic player stops, the audio engine naps once quiet). A playing frame, an event, a menu sound or Home's
/// creaking trap wakes them. If the frames stop without a `silence()` (the app went away), a watchdog fades the
/// continuous layers after `staleAfter` s, so nothing can be left buzzing.
@MainActor
final class FeedbackDirector: FeedbackSink {
    static let shared = FeedbackDirector()

    /// Seconds without play (and without events) before the engines idle.
    static let idleDelay: Double = 3
    /// The bog is kept up this long after play stops (the tired moment, results), then fades.
    static let ambienceHold: Double = 3
    /// Seconds without a `handle` or `homeTrap` call after which the continuous layers fade by themselves.
    static let staleAfter: Double = 0.25
    /// Minimum gaps (s) between repeats of the small sounds (a burst of events never machine-guns).
    static let landingSoundGap: Double = 0.025
    static let sipGap: Double = 0.08
    static let hopGap: Double = 0.05
    static let maxSpooksPerFrame = 3
    static let maxWhiffsPerFrame = 4
    static let maxStingsPerFrame = 2
    /// Home's title trap chomps at most this often (s), however long the App holds `snapped`.
    static let homeChompRefractory: Double = 0.3
    /// After the bite (s): the whiffs of escaped bugs, the chain broken "bwoop", the warnings.
    static let whiffAt: Float = 0.03
    static let chainBrokenAt: Float = 0.45
    static let warnAt: Float = 0.75
    static let tiredAt: Float = 0.9
    static let newBestAt: Float = 0.6
    /// After a wilt (s): the last-snap knocks or the tired yawn wait for the droop (R3: its two sighs).
    static let afterWiltAt: Float = FeelSoundBook.wiltLength
    /// Caught bugs past this many get the light crunch (QA-1 #4: voices for the reward sounds).
    static let fullCrunches = 4

    var soundOn: Bool = true {
        didSet {
            guard oldValue != soundOn else { return }
            audio.enabled = soundOn
            audio.setBed(FeelSoundBook.idleBed(master: master))
        }
    }

    /// Haptics on/off (Settings). Turning it on restores the last profile, or the device default.
    var hapticsOn: Bool {
        get { profile != .off }
        set {
            if !newValue {
                applyProfile(.off)
            } else if profile == .off {
                applyProfile(profileChosen ? lastOnProfile : FeelHapticProfile.defaultFor(hasFold: deviceHasFold))
            }
        }
    }

    /// Additive (Swoop's/Hush's Strong profile): Normal or Strong haptics. Setting it counts as the player's choice;
    /// until then the profile follows the device (`deviceHasFold`: Strong on a Duo, whose Taptic Engine is weak).
    var hapticProfile: FeelHapticProfile {
        get { profile }
        set {
            profileChosen = true
            applyProfile(newValue)
        }
    }

    /// Additive: the App sets this once a hinge has been seen (a Duo). It moves an unchosen profile to Strong.
    var deviceHasFold: Bool = false {
        didSet {
            guard oldValue != deviceHasFold, !profileChosen, profile != .off else { return }
            applyProfile(FeelHapticProfile.defaultFor(hasFold: deviceHasFold))
        }
    }

    /// `.ambient` (silenced by the switch) instead of `.playback` + `.mixWithOthers`.
    var respectSilentSwitch: Bool = false {
        didSet {
            guard oldValue != respectSilentSwitch else { return }
            audio.respectSilentSwitch = respectSilentSwitch
        }
    }

    /// Menus: the engines may nap once quiet. A menu sound or Home's creaking trap still plays (it wakes them).
    var idle: Bool = false {
        didSet {
            guard oldValue != idle else { return }
            refreshIdle(now: CACurrentMediaTime())
        }
    }

    /// Additive: the scene width (points) the events' positions are panned across. The App sets it from
    /// `ScreenLayout.size.width` (wider phones have a wider scene); the Duo's 952 by default.
    var sceneWidth: Double = Double(ScreenLayout.canvasWidth)

    private let audio = FeelAudioEngine()
    private let haptics = FeelHaptics()
    private var started = false
    private var activationObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var dice = FeelDice(seed: 0x534E_4150_4A41_5721)
    private var profile: FeelHapticProfile = .normal
    private var lastOnProfile: FeelHapticProfile = .normal
    private var profileChosen = false

    private var mixer = FeelBuzzMixer()
    private var sentBuzz: [FeelBuzz] = Array(repeating: FeelBuzz(), count: FeelSynth.buzzSlots)
    /// The last pan seen for each bug id (events carry an id but not always a position).
    private var pans: [Int: Double] = [:]
    private var stretch = FeelStretchMeter()

    private var lastBedSend: CFTimeInterval = 0
    private var lastHeal: CFTimeInterval = 0
    private var lastActive: CFTimeInterval = -Double.infinity
    private var lastPlaying: CFTimeInterval = -Double.infinity
    private var lastFrame: CFTimeInterval = -Double.infinity
    private var lastHomeCreak: CFTimeInterval = -Double.infinity
    private var lastHomeChomp: CFTimeInterval = -Double.infinity
    private var lastLandingSound: CFTimeInterval = -Double.infinity
    private var lastLandingHaptic: CFTimeInterval = -Double.infinity
    private var lastSip: CFTimeInterval = -Double.infinity
    private var lastHop: CFTimeInterval = -Double.infinity
    private var audioIdle = false
    private var hapticIdle = false
    private var wasPlaying = false
    private var continuousLive = false
    private var watchdogPending = false

    /// CHOMPs played (bites with a catch, and Home's chomps), for diagnostics and tests.
    private(set) var chomps = 0
    /// Hunger cues played (rumbles, droops), for diagnostics and tests.
    private(set) var rumbles = 0
    private(set) var droops = 0
    /// R3 moments played: the loss blips (stings that cost snaps), the free first bee's "oops", the chain's ×5 flare.
    private(set) var lossBlips = 0
    private(set) var oopses = 0
    private(set) var flares = 0
    /// The multiplier of the last `chainUp` (1 after a break), so the ×5 flare plays once per climb.
    private var lastChainMultiplier: Double = 1
    /// Haptic patterns built (one per frame with cues, after merging), for diagnostics and tests.
    private(set) var hapticPatterns = 0

    /// While `react` runs, haptic cues are collected here and played as one pattern (QA-1 #18).
    private var frameCues: [FeelHapticCue]?

    init() {
        // Menus play before any game frame: start from an audible, empty bed (a master of 0 mutes one-shots too).
        audio.setBed(FeelSoundBook.idleBed(master: master))
    }

    private var master: Float { soundOn ? FeelAudioEngine.masterGain : 0 }

    /// True while the engines idle (menus, a long pause).
    var idling: Bool { audioIdle }

    /// Audio session + engines. Safe to call more than once; also called lazily by the first sound.
    func start() {
        guard !started else { return }
        started = true
        audio.enabled = soundOn
        audio.respectSilentSwitch = respectSilentSwitch
        haptics.enabled = profile != .off
        if profile != .off { haptics.profile = profile }
        audio.start()
        haptics.start()
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.audio.resume()
                self?.haptics.resume()
            }
        }
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.audio.enterBackground()
            }
        }
    }

    // MARK: - Per frame

    func handle(_ events: [TrapEvent], telemetry: TrapTelemetry) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastFrame = now
        if telemetry.playing || !events.isEmpty { lastActive = now }
        if telemetry.playing { lastPlaying = now }
        refreshIdle(now: now)
        heal(now: now)
        rememberPans(telemetry.buzzers)

        // The continuous layers. Leaving play glides slowly instead of cutting.
        let leavingPlay = wasPlaying && !telemetry.playing
        if now - lastBedSend >= 1.0 / 60 || leavingPlay {
            lastBedSend = now
            let ambience = now - lastPlaying <= Self.ambienceHold ? 1.0 : 0.0
            var bed = FeelSoundBook.playBed(telemetry: telemetry, master: master, ambience: ambience)
            if !telemetry.playing { bed.glide = FeelSoundBook.fadeGlide }
            audio.setBed(bed)
            let share = telemetry.playing ? 1.0 : FeelSoundBook.buzzRestShare * ambience
            sendBuzz(mixer.update(buzzers: telemetry.buzzers, share: share, now: now), force: leavingPlay)
            continuousLive = true
        }
        wasPlaying = telemetry.playing
        let creeping = telemetry.playing && telemetry.creeping
        haptics.update(level: FeelHapticBook.creepLevel(closure: telemetry.closure, creeping: creeping,
                                                        profile: profile), now: now)

        react(to: events, now: now)
        scheduleWatchdog()
    }

    /// Home's title trap follows the hinge and chomps too (ARCHITECTURE "Feedback API"). Call every Home frame with
    /// the trap source's closure (degrees) and `snapped` true on the frame a snap fired. Closing the hinge stretches
    /// the leaf (the groan and its texture follow how fast it closes); a snap plays a slightly smaller CHOMP (at most
    /// once per 0.3 s).
    func homeTrap(closure: Double, snapped: Bool) {
        ensureStarted()
        let now = CACurrentMediaTime()
        lastFrame = now
        let level = stretch.update(closure: closure, at: now)
        if level > 0 {
            lastActive = now
            lastHomeCreak = now
        }
        var chomp = false
        if snapped && now - lastHomeChomp >= Self.homeChompRefractory {
            lastHomeChomp = now
            lastActive = now
            chomp = true
        }
        refreshIdle(now: now)
        heal(now: now)
        if chomp {
            chomps += 1
            audio.play(FeelSoundBook.chomp(caught: 1, dice: &dice, scale: FeelSoundBook.homeChompScale))
            playHaptic(FeelHapticBook.chomp(caught: 1))
        }
        if now - lastBedSend >= 1.0 / 60 {
            lastBedSend = now
            audio.setBed(FeelSoundBook.homeBed(stretch: level, closure: closure, master: master))
            sendBuzz(mixer.update(buzzers: [], share: 0, now: now), force: false)
            continuousLive = true
        }
        wasPlaying = false
        haptics.update(level: FeelHapticBook.stretchLevel(level, profile: profile), now: now)
        scheduleWatchdog()
    }

    /// Fade the continuous layers out (pause, menus). One-shots already ringing play out; the engines idle after
    /// `idleDelay` s unless play resumes.
    func silence() {
        let now = CACurrentMediaTime()
        audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
        mixer.releaseAll(now: now)
        sendBuzz(mixer.targets, force: true)
        haptics.quiet(now: now)
        wasPlaying = false
        continuousLive = false
        // Count the quiet from now (a pause right after a game frame still waits the full delay).
        lastActive = now
        lastPlaying = -Double.infinity
        scheduleIdleCheck()
    }

    // MARK: - Menu sounds

    func uiTap() {
        ensureStarted()
        heal(now: CACurrentMediaTime())
        audio.play(FeelSoundBook.uiTap())
        playHaptic(FeelHapticBook.uiTap)
    }

    func uiConfirm() {
        ensureStarted()
        heal(now: CACurrentMediaTime())
        audio.play(FeelSoundBook.uiConfirm())
        playHaptic(FeelHapticBook.uiConfirm)
    }

    /// Rank up, a new Bug Book page, a new best on the results card: a rising pentatonic arpeggio with glints.
    func celebrate() {
        ensureStarted()
        audio.play(FeelSoundBook.celebrate(dice: &dice))
        playHaptic(FeelHapticBook.celebrate)
    }

    // MARK: - Events

    private func react(to events: [TrapEvent], now: CFTimeInterval) {
        guard !events.isEmpty else { return }
        // The bite frame: `snapped` comes first, then the per-bug events, then the feast/lucky/chain/… (ARCHITECTURE).
        var biting = false
        var stung = false
        var wilting = false
        var stingCost = 0
        for event in events {
            switch event {
            case .snapped: biting = true
            case .stung(_, _, let cost):
                stung = true
                stingCost += max(cost, 0)
            case .wilted: wilting = true
            default: break
            }
        }
        // R3: the sting's verdict (the loss blip or the "oops") waits for the last "Bzzt!" played to be spat out.
        var verdictAt: Float = 0
        if stung {
            var index = 0
            for event in events {
                guard case .stung(_, let species, _) = event else { continue }
                guard index < Self.maxStingsPerFrame else { break }
                let delay: Float = biting ? FeelSoundBook.stingAt + 0.12 * Float(index) : 0
                verdictAt = max(verdictAt, FeelSoundBook.stingVerdictAt(species, delay: delay))
                index += 1
            }
        }
        // A costly sting's blip must be over before the chain's "bwoop" (and the warnings) speak.
        let afterLoss: Float = stingCost > 0 ? verdictAt + FeelSoundBook.lostLength : 0
        frameCues = []
        defer { flushHaptics() }
        var caught = 0
        var escaped = 0
        var stings = 0
        var spooks = 0
        for event in events {
            switch event {
            case .waveStarted, .bugArrived, .bugLeft, .drySnap, .finished:
                // The buzz layer says arrivals and departures; `snapped` already played the empty clap.
                break
            case .dayPhaseChanged(let phase):
                audio.play(FeelSoundBook.dayChime(phase, dice: &dice))
            case .bugLanded(_, let species, let position, let inTrap):
                landed(species, x: Double(position.x), inTrap: inTrap, now: now)
            case .bugSipping(let id, _):
                if now - lastSip >= Self.sipGap {
                    lastSip = now
                    audio.play(FeelSoundBook.sip(pan: pan(of: id), dice: &dice))
                }
            case .bugHopped(let id, _):
                if now - lastHop >= Self.hopGap {
                    lastHop = now
                    audio.play(FeelSoundBook.hop(pan: pan(of: id), dice: &dice))
                }
            case .bugSpooked(let id, _):
                if spooks < Self.maxSpooksPerFrame {
                    audio.play(FeelSoundBook.spooked(pan: pan(of: id), dice: &dice))
                }
                spooks += 1
            case .snapStarted:
                // On the bite's own frame the CHOMP speaks; otherwise the lobes whoosh in.
                if !biting { audio.play(FeelSoundBook.snapWhoosh(dice: &dice)) }
            case .snapped(let report):
                let count = report.caught.count
                if count > 0 {
                    chomps += 1
                    playHaptic(FeelHapticBook.chomp(caught: count))
                    audio.play(FeelSoundBook.chomp(caught: count, dice: &dice))
                } else {
                    playHaptic(FeelHapticBook.drySnap)
                    audio.play(FeelSoundBook.drySnap(dice: &dice))
                }
            case .bugCaught(_, _, let position):
                audio.play(FeelSoundBook.crunch(index: caught, pan: pan(x: Double(position.x)),
                                                light: caught >= Self.fullCrunches, dice: &dice))
                caught += 1
            case .bugEscaped(let id, _):
                if escaped < Self.maxWhiffsPerFrame {
                    let delay: Float = biting ? Self.whiffAt + 0.02 * Float(escaped) : 0
                    audio.play(FeelSoundBook.whiff(pan: pan(of: id), delay: delay, dice: &dice))
                }
                escaped += 1
            case .stung(let id, let species, let cost):
                if stings < Self.maxStingsPerFrame {
                    let delay: Float = biting ? FeelSoundBook.stingAt + 0.12 * Float(stings) : 0
                    audio.play(FeelSoundBook.sting(species, pan: pan(of: id), delay: delay, dice: &dice))
                    playHaptic(FeelHapticBook.sting(at: Double(delay), heavy: cost > 0))
                }
                stings += 1
            case .feast(let count, let snapsBack):
                audio.play(FeelSoundBook.feast(count: count, snapsBack: snapsBack, dice: &dice))
                playHaptic(FeelHapticBook.feast)
            case .luckySnap(let species):
                let delay: Float = biting ? FeelSoundBook.luckyAt : 0
                audio.play(FeelSoundBook.lucky(species, delay: delay, dice: &dice))
                playHaptic(FeelHapticBook.lucky(at: Double(delay)))
            case .chainUp(let count, let multiplier):
                let delay: Float = biting ? FeelSoundBook.chainAt : 0
                audio.play(FeelSoundBook.chainUp(count: count, delay: delay, dice: &dice))
                // R3: the first step at ×5 flares once (a one-off per climb; a break or a lower step re-arms it).
                let value = multiplier.isFinite ? multiplier : 1
                let top = FeelSoundBook.flareMultiplier - 1e-6
                if value >= top && lastChainMultiplier < top {
                    flares += 1
                    let at = delay + FeelSoundBook.flareAfter
                    audio.play(FeelSoundBook.chainFlare(delay: at, dice: &dice))
                    playHaptic(FeelHapticBook.chainFlare(at: Double(at)))
                }
                lastChainMultiplier = value
            case .chainBroken:
                lastChainMultiplier = 1
                var delay: Float = biting ? Self.chainBrokenAt : 0
                if biting && stung { delay += 0.3 }
                delay = max(delay, afterLoss)
                audio.play(FeelSoundBook.chainBroken(delay: delay, dice: &dice))
            case .rearmed:
                audio.play(FeelSoundBook.rearmPluck(dice: &dice))
                playHaptic(FeelHapticBook.rearm)
            case .beeSpared(let species):
                audio.play(FeelSoundBook.spared(species, dice: &dice))
                playHaptic(FeelHapticBook.spared)
            case .lastSnap:
                var delay: Float = biting ? Self.warnAt : (wilting ? Self.afterWiltAt : 0)
                delay = max(delay, afterLoss)
                audio.play(FeelSoundBook.lastSnap(delay: delay))
                playHaptic(FeelHapticBook.lastSnap(at: Double(delay)))
            case .hungry:
                // The trap's tummy rumbles (3 s before a snap wilts; once per hunger cycle).
                rumbles += 1
                audio.play(FeelSoundBook.hungry(dice: &dice))
                playHaptic(FeelHapticBook.hungry)
            case .wilted:
                // A snap wilted: a soft droop and a weak haptic.
                droops += 1
                audio.play(FeelSoundBook.wilted(dice: &dice))
                playHaptic(FeelHapticBook.wilted())
            case .tired:
                var delay: Float = biting ? Self.tiredAt : (wilting ? Self.afterWiltAt : 0)
                delay = max(delay, afterLoss)
                audio.play(FeelSoundBook.tired(delay: delay))
                playHaptic(FeelHapticBook.tired(at: Double(delay)))
            case .newBest:
                let delay: Float = biting ? Self.newBestAt : 0
                audio.play(FeelSoundBook.newBest(delay: delay))
                playHaptic(FeelHapticBook.newBest(at: Double(delay)))
            }
        }
        // R3: the sting's verdict, once per frame, after the last "Bzzt!".
        if stung {
            if stingCost > 0 {
                lossBlips += 1
                audio.play(FeelSoundBook.snapLost(cost: stingCost, delay: verdictAt, dice: &dice))
                playHaptic(FeelHapticBook.snapLost(at: Double(verdictAt)))
            } else {
                oopses += 1
                audio.play(FeelSoundBook.oops(delay: verdictAt, dice: &dice))
                playHaptic(FeelHapticBook.oops(at: Double(verdictAt)))
            }
        }
    }

    private func landed(_ species: BugSpecies, x: Double, inTrap: Bool, now: CFTimeInterval) {
        if now - lastLandingSound >= Self.landingSoundGap {
            lastLandingSound = now
            audio.play(FeelSoundBook.landingTik(species, inTrap: inTrap, pan: pan(x: x), dice: &dice))
        }
        if inTrap && now - lastLandingHaptic >= FeelHapticBook.landingGap {
            lastLandingHaptic = now
            playHaptic(FeelHapticBook.landing(species))
        }
    }

    // MARK: - Helpers

    private func pan(x: Double) -> Float {
        FeelSoundBook.pan(x: x, width: sceneWidth)
    }

    private func pan(of id: Int) -> Float {
        guard let value = pans[id] else { return 0 }
        return FeelSoundBook.pan(buzzer: value)
    }

    private func rememberPans(_ buzzers: [Buzzer]) {
        if pans.count > 128 { pans.removeAll(keepingCapacity: true) }
        for buzzer in buzzers {
            pans[buzzer.id] = buzzer.pan
        }
    }

    /// Forward the slots that changed audibly (or all of them, `force`).
    private func sendBuzz(_ targets: [FeelBuzz], force: Bool) {
        let count = min(targets.count, sentBuzz.count)
        for slot in 0..<count {
            let next = targets[slot]
            let last = sentBuzz[slot]
            let changed = next.timbre != last.timbre || abs(next.pitch - last.pitch) > 0.0005
                || abs(next.level - last.level) > 0.01 || abs(next.pan - last.pan) > 0.02
            guard force || changed else { continue }
            sentBuzz[slot] = next
            audio.setBuzz(slot: slot, next)
        }
    }

    private func ensureStarted() {
        if !started { start() }
    }

    /// Inside `react` the cue joins the frame's single pattern; elsewhere it plays at once.
    private func playHaptic(_ cue: FeelHapticCue) {
        let adapted = FeelHapticBook.adapt(cue, to: profile)
        if frameCues != nil {
            frameCues?.append(adapted)
            return
        }
        hapticPatterns += 1
        haptics.play(adapted)
    }

    /// The frame's cues as one pattern (QA-1 #18).
    private func flushHaptics() {
        let cues = frameCues ?? []
        frameCues = nil
        for cue in FeelHapticBook.merge(cues) {
            hapticPatterns += 1
            haptics.play(cue)
        }
    }

    private func applyProfile(_ newProfile: FeelHapticProfile) {
        profile = newProfile
        if newProfile != .off {
            lastOnProfile = newProfile
            haptics.profile = newProfile
        }
        haptics.enabled = newProfile != .off
    }

    private func heal(now: CFTimeInterval) {
        guard now - lastHeal > 1 else { return }
        lastHeal = now
        // QA-1 #13: audio heals in menus too (`heal()` itself leaves a napping engine alone).
        audio.heal()
        if !hapticIdle { haptics.heal() }
    }

    /// Menus (`idle`) or a long quiet idle the engines; Home's creaking trap keeps the haptic player up while it lasts.
    private func refreshIdle(now: CFTimeInterval) {
        let quiet = now - lastActive > Self.idleDelay
        let wantAudioIdle = idle || quiet
        let homeCreaking = now - lastHomeCreak < 1.0
        let wantHapticIdle = wantAudioIdle && !homeCreaking
        if wantAudioIdle != audioIdle {
            audioIdle = wantAudioIdle
            audio.idle = wantAudioIdle
        }
        if wantHapticIdle != hapticIdle {
            hapticIdle = wantHapticIdle
            if wantHapticIdle { haptics.quiet(now: now) }
            haptics.idle = wantHapticIdle
        }
    }

    /// After `silence()` no frames may come (a pause card, the menus): idle once the delay has passed.
    private func scheduleIdleCheck() {
        let delay = Self.idleDelay + 0.05
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.refreshIdle(now: CACurrentMediaTime())
        }
    }

    /// Frames stopped without a `silence()`: fade the continuous layers so nothing is left buzzing or groaning.
    private func scheduleWatchdog() {
        guard !watchdogPending else { return }
        watchdogPending = true
        let delay = Self.staleAfter
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.watchdog()
        }
    }

    private func watchdog() {
        watchdogPending = false
        guard continuousLive else { return }
        let now = CACurrentMediaTime()
        if now - lastFrame >= Self.staleAfter {
            continuousLive = false
            wasPlaying = false
            audio.setBed(FeelSoundBook.idleBed(master: master, glide: FeelSoundBook.fadeGlide))
            mixer.releaseAll(now: now)
            sendBuzz(mixer.targets, force: true)
            haptics.quiet(now: now)
            refreshIdle(now: now)
            // QA-1 #14: nothing else will re-check, so idle the engines once the quiet delay has passed.
            scheduleIdleCheck()
        } else {
            scheduleWatchdog()
        }
    }
}

/// Home's title trap: how fast the hinge is closing it, as a 0…1 "stretch" (pure, with explicit times). Opening is
/// silent; holding still fades out (τ 80 ms); closing faster than `quietSpeed` stretches, full at `fullSpeed`,
/// louder the deeper the closure.
struct FeelStretchMeter {
    static let tau = 0.08
    /// Closing speeds (°/s): silent at or below `quietSpeed`, full at `fullSpeed`.
    static let quietSpeed = 6.0
    static let fullSpeed = 70.0

    private(set) var level = 0.0
    private(set) var speed = 0.0
    private var last: (closure: Double, time: Double)?

    init() {}

    /// Feed this frame's closure (degrees) at `time`; returns the stretch 0…1. NaN resets to silence.
    mutating func update(closure: Double, at time: Double) -> Double {
        guard closure.isFinite, time.isFinite else {
            reset()
            return 0
        }
        let c = max(closure, 0)
        guard let previous = last else {
            last = (closure: c, time: time)
            level = 0
            return 0
        }
        guard time > previous.time else { return level }
        let elapsed = time - previous.time
        let raw = max((c - previous.closure) / max(elapsed, 1e-3), 0)
        speed += (raw - speed) * (1 - exp(-min(elapsed, 0.1) / Self.tau))
        last = (closure: c, time: time)
        let moving = FeelMath.smoothstep((speed - Self.quietSpeed) / (Self.fullSpeed - Self.quietSpeed))
        level = moving * (0.4 + 0.6 * FeelMath.clamp01(c / Tuning.snapDepth))
        return level
    }

    mutating func reset() {
        level = 0
        speed = 0
        last = nil
    }
}
