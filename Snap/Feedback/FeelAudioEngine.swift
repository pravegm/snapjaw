import AVFoundation
import Foundation
import os
import QuartzCore
import UIKit

/// Pure rules of the audio engine's self-repair (Swoop QA-FINAL P2-2, P2-3), outside the main actor so tests can read
/// them.
enum FeelAudioRules {
    /// `AVAudioSession.InterruptionReason.appWasSuspended`, by value: the name is deprecated, and the notice it marks
    /// is stale (the app was suspended earlier; no `.ended` follows).
    static let appWasSuspendedReason: UInt = 1
    /// The older `AVAudioSessionInterruptionWasSuspendedKey` (deprecated name), by value.
    static let wasSuspendedKey = "AVAudioSessionInterruptionWasSuspendedKey"
    /// A menu sound retries a stopped engine at most this often (s).
    static let soundRetryGap: Double = 0.5
    /// `heal()` treats an interruption with no `.ended` as over after this long (s), if the app is active and no
    /// other audio is playing.
    static let staleInterruption: Double = 3

    /// True for a `.began` that really starts an interruption. A late "app was suspended" notice is stale: it must
    /// never switch self-repair off for the session.
    static func isLiveInterruption(began: Bool, reason: UInt?, wasSuspended: Bool) -> Bool {
        began && !wasSuspended && reason != appWasSuspendedReason
    }
}

/// Owns the audio session and the AVAudioEngine that hosts `FeelSynth` (Swoop's hardened `FeelAudioEngine`, with
/// Hush's "an audible bed wakes a napping engine" for Home's creaking title trap). Snapjaw renders **stereo** (the bugs'
/// buzz is panned to where they are); a mono route gets the sum.
///
/// Session: `.playback` + `.mixWithOthers` by default, so the game is heard even with the silent switch on (the
/// founder's rule since Squish); `.ambient` when the player turns on "Respect silent switch".
/// Self-healing: interruptions, route changes, engine configuration changes and media-services resets all restart or
/// rebuild it; `heal()` (called ~1/s by the director) restarts a stopped engine. Every failure is logged and the game
/// simply goes silent: nothing here can crash.
@MainActor
final class FeelAudioEngine {
    /// Master trim applied to everything (the bed's master).
    static let masterGain: Float = 1.25
    /// Seconds of quiet while idle before the engine naps (lets a tap or a chime ring out).
    static let napAfter: Double = 6
    /// The preferred IO buffer (s): 10 ms (Swoop QA-FINAL P2-6), far under every glide in the bed.
    static let ioBufferDuration: Double = 0.01

    private static let log = Logger(subsystem: "com.pravegm.snapjaw", category: "audio")

    /// Sound on/off. Off pauses the engine (no battery spent); on starts it again.
    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled {
                if isStarted { ensureRunning(reason: "sound switched on") } else if wantsStart { start() }
            } else {
                synth?.send(.stopAll)
                if engine.isRunning { engine.pause() }
            }
        }
    }

    /// Menus and long pauses: while idle the engine naps (`AVAudioEngine.pause()`, no render callbacks) once nothing
    /// has played for `napAfter` seconds; a one-shot (a menu tap) or an audible bed wakes it. Off: awake at once.
    var idle = false {
        didSet {
            guard oldValue != idle else { return }
            if idle {
                scheduleNap()
            } else {
                napTask?.cancel()
                napTask = nil
                wake(reason: "game")
            }
        }
    }

    var respectSilentSwitch = false {
        didSet {
            guard oldValue != respectSilentSwitch, isStarted else { return }
            configureSession()
            activateSession()
            ensureRunning(reason: "silent-switch setting changed")
        }
    }

    private var engine = AVAudioEngine()
    private(set) var synth: FeelSynth?
    private var sourceNode: AVAudioSourceNode?
    private var observers: [NSObjectProtocol] = []
    private var engineObserver: NSObjectProtocol?
    private(set) var isStarted = false
    private var wantsStart = false
    private(set) var lastError: String?
    private var startFailures = 0
    private var lastRebuild: CFTimeInterval = -Double.infinity
    private var lastBed = FeelBed()
    private var lastBuzz: [FeelBuzz] = Array(repeating: FeelBuzz(), count: FeelSynth.buzzSlots)
    /// Paused on purpose (see `idle`): nothing restarts it except a sound or leaving idle.
    private(set) var isNapping = false
    private var napTask: Task<Void, Never>?
    private var lastSoundTime: CFTimeInterval = -Double.infinity
    /// An interruption (a call, Siri) is in progress: `heal()` leaves the engine alone until it ends.
    private var interrupted = false
    private var interruptedAt: CFTimeInterval = -Double.infinity
    /// The app is in the background. The engine is paused on purpose and nothing restarts it there; `resume()` does.
    private(set) var inBackground = false
    private var lastSoundRetry: CFTimeInterval = -Double.infinity

    init() {}

    var isRunning: Bool { engine.isRunning }

    /// Session, graph, engine. Lazy: does nothing until sound is on. Idempotent.
    func start() {
        wantsStart = true
        guard enabled, !isStarted else { return }
        isStarted = true
        configureSession()
        activateSession()
        buildGraph()
        startEngine(reason: "launch")
        observeSystem()
    }

    /// Queue one-shot sounds. Dropped while sound is off, the engine never came up, or it is stopped (an
    /// interruption): queued sounds would otherwise burst out together when it restarts. A napping engine wakes.
    func play(_ commands: [FeelSynthCommand]) {
        guard enabled, isStarted, !inBackground, !commands.isEmpty else { return }
        if isNapping {
            wake(reason: "sound")
        } else if !engine.isRunning && !interrupted {
            // A failed start is retried from a menu too (`heal()` only runs with frames), at most 2/s.
            let now = CACurrentMediaTime()
            if now - lastSoundRetry >= FeelAudioRules.soundRetryGap {
                lastSoundRetry = now
                ensureRunning(reason: "sound")
            }
        }
        guard let synth, engine.isRunning else { return }
        lastSoundTime = CACurrentMediaTime()
        for command in commands { synth.send(command) }
        if idle { scheduleNap() }
    }

    /// The continuous layers (forwarded only while the engine runs). Remembered, so a synth built later or an engine
    /// started again starts from it: every successful start applies it. An audible bed (Home's creaking title trap
    /// while the App has set `idle`) counts as sound: it wakes a napping engine and holds off the next nap.
    func setBed(_ bed: FeelBed) {
        lastBed = bed
        if bed.hasLayers && bed.master > 0 && enabled && isStarted && !inBackground {
            lastSoundTime = CACurrentMediaTime()
            if idle && napTask == nil { scheduleNap() }
            if isNapping {
                wake(reason: "continuous sound") // the start applies `lastBed`
                return
            }
        }
        guard !isNapping, engine.isRunning else { return }
        synth?.send(.bed(bed))
    }

    /// One buzz slot's target (forwarded only while the engine runs; remembered like the bed).
    func setBuzz(slot: Int, _ buzz: FeelBuzz) {
        guard slot >= 0, slot < lastBuzz.count else { return }
        lastBuzz[slot] = buzz
        guard !isNapping, engine.isRunning else { return }
        synth?.send(.buzz(slot: slot, buzz: buzz))
    }

    /// The app became active again (calls, Siri, background). Also ends a tracked interruption (`.ended` isn't
    /// guaranteed to arrive).
    func resume() {
        inBackground = false
        interrupted = false
        guard isStarted, enabled, !isNapping else { return }
        activateSession()
        ensureRunning(reason: "app active again")
    }

    /// The app went to the background: pause at once, with nothing left ringing to resume mid-note.
    func enterBackground() {
        inBackground = true
        guard isStarted else { return }
        synth?.send(.stopAll)
        if engine.isRunning { engine.pause() }
    }

    /// Cheap check from the frame loop (the director calls it about once a second).
    func heal() {
        guard isStarted, enabled, !isNapping, !inBackground, synth != nil, !engine.isRunning else { return }
        guard UIApplication.shared.applicationState != .background else { return }
        if interrupted {
            // A `.began` that no `.ended` follows must never switch self-repair off for the session.
            guard UIApplication.shared.applicationState == .active,
                  CACurrentMediaTime() - interruptedAt >= FeelAudioRules.staleInterruption,
                  !AVAudioSession.sharedInstance().isOtherAudioPlaying else { return }
            interrupted = false
        }
        ensureRunning(reason: "found stopped")
    }

    // MARK: - Naps (battery)

    private func scheduleNap() {
        napTask?.cancel()
        let delay: Double = Self.napAfter
        napTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            self?.napIfQuiet()
        }
    }

    private func napIfQuiet() {
        napTask = nil
        guard idle, !isNapping else { return }
        if CACurrentMediaTime() - lastSoundTime < Self.napAfter - 0.05 {
            scheduleNap()
            return
        }
        isNapping = true
        // Nothing may be left ringing (or queued) to burst out on waking.
        synth?.send(.stopAll)
        if engine.isRunning { engine.pause() }
    }

    private func interruptionBegan() {
        interrupted = true
        interruptedAt = CACurrentMediaTime()
        // Whatever was queued must not burst out when the call ends.
        synth?.send(.stopAll)
    }

    /// `.ended`: restart, unless the app is in the background (then `resume()` does it when the app is active).
    private func interruptionEnded() {
        interrupted = false
        guard !inBackground else { return }
        guard isStarted, enabled, !isNapping else { return }
        activateSession()
        ensureRunning(reason: "interruption ended")
    }

    /// The bed is applied by the start itself (`startEngine`).
    private func wake(reason: String) {
        guard isNapping else { return }
        isNapping = false
        ensureRunning(reason: reason)
    }

    // MARK: - Session and graph

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if respectSilentSwitch {
                try session.setCategory(.ambient, mode: .default, options: [])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
        } catch {
            record("Couldn't set the audio category", error)
        }
        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(Self.ioBufferDuration)
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            record("Couldn't activate the audio session", error)
        }
    }

    /// Source node → main mixer → output, stereo (non-interleaved) Float32 at the session rate (the mixer converts on
    /// route changes, and down-mixes for a mono route).
    private func buildGraph() {
        let session = AVAudioSession.sharedInstance()
        let sampleRate = session.sampleRate > 0 ? session.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            lastError = "Couldn't make a \(Int(sampleRate)) Hz format"
            Self.log.error("Couldn't make an audio format")
            return
        }
        let synth = FeelSynth(sampleRate: Float(sampleRate))
        let node = AVAudioSourceNode(format: format, renderBlock: Self.renderBlock(for: synth))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        engine.prepare()
        self.synth = synth
        sourceNode = node

        if let engineObserver { NotificationCenter.default.removeObserver(engineObserver) }
        engineObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hardwareChanged()
            }
        }
    }

    /// The hardware format changed (headphones in or out, a 44.1 kHz Bluetooth headset). Renegotiate the mixer →
    /// output format first, then restart.
    private func hardwareChanged() {
        reconnectOutput()
        ensureRunning(reason: "audio hardware changed")
    }

    /// Lets the mixer → output connection renegotiate the hardware format. Only on a stopped engine.
    private func reconnectOutput() {
        guard !engine.isRunning else { return }
        engine.disconnectNodeOutput(engine.mainMixerNode)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
    }

    /// Built outside the main actor on purpose: the block runs on the real-time audio thread and touches only the
    /// synth (an `@unchecked Sendable` object whose render path is lock-free and allocation-free). Two buffers: left
    /// and right; one buffer: the mono sum; more: copies of the left.
    private nonisolated static func renderBlock(for synth: FeelSynth) -> AVAudioSourceNodeRenderBlock {
        return { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let first = buffers.first, let left = first.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let frames = Int(frameCount)
            if buffers.count > 1, let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
                synth.render(frames: frames, left: left, right: right)
                if buffers.count > 2 {
                    for index in 2..<buffers.count {
                        buffers[index].mData?.copyMemory(from: left, byteCount: Int(first.mDataByteSize))
                    }
                }
            } else {
                synth.render(frames: frames, left: left, right: nil)
            }
            return noErr
        }
    }

    private func startEngine(reason: String) {
        guard sourceNode != nil, enabled, !inBackground else { return }
        do {
            try engine.start()
            startFailures = 0
            applyState()
        } catch {
            startFailures += 1
            record("Couldn't start the audio engine (\(reason), try \(startFailures))", error)
            if startFailures == 2 {
                // Let the mixer → output connection renegotiate the hardware format, then try once more.
                reconnectOutput()
                do {
                    try engine.start()
                    startFailures = 0
                    applyState()
                } catch {
                    startFailures += 1
                    record("Couldn't start the audio engine after reconnecting", error)
                }
            } else if startFailures >= 4 {
                let now = CACurrentMediaTime()
                if now - lastRebuild > 5 {
                    lastRebuild = now
                    startFailures = 0
                    rebuild()
                }
            }
        }
    }

    /// The latest bed (with its master) and buzz slots reach the synth whenever the engine runs again.
    private func applyState() {
        guard let synth else { return }
        synth.send(.bed(lastBed))
        for (slot, buzz) in lastBuzz.enumerated() {
            synth.send(.buzz(slot: slot, buzz: buzz))
        }
    }

    private func ensureRunning(reason: String) {
        // A napping engine stays paused through route and configuration changes; a sound wakes it. In the background
        // nothing starts it (`resume()` does, in the foreground).
        guard isStarted, enabled, !isNapping, !inBackground else { return }
        if synth == nil {
            rebuild()
            return
        }
        guard !engine.isRunning else { return }
        activateSession()
        startEngine(reason: reason)
    }

    /// The audio server restarted (or the engine kept failing): every audio object is dead, so start from scratch.
    private func rebuild() {
        guard isStarted else { return }
        if let engineObserver {
            NotificationCenter.default.removeObserver(engineObserver)
            self.engineObserver = nil
        }
        engine = AVAudioEngine()
        synth = nil
        sourceNode = nil
        configureSession()
        activateSession()
        buildGraph()
        if !isNapping { startEngine(reason: "rebuild") }
    }

    private func observeSystem() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main) { [weak self] notification in
            let info = notification.userInfo
            let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt
            let type = raw.flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let ended = type == .ended
            // A late "app was suspended" `.began` (no `.ended` ever follows) is ignored.
            let reason = info?[AVAudioSessionInterruptionReasonKey] as? UInt
            let wasSuspended = (info?[FeelAudioRules.wasSuspendedKey] as? Bool) ?? false
            let began = FeelAudioRules.isLiveInterruption(began: type == .began, reason: reason,
                                                          wasSuspended: wasSuspended)
            MainActor.assumeIsolated {
                if began { self?.interruptionBegan() }
                if ended { self?.interruptionEnded() }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureRunning(reason: "route changed")
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil,
                                            queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuild()
            }
        })
    }

    private func record(_ what: String, _ error: Error) {
        let nsError = error as NSError
        let message = "\(what): \(nsError.localizedDescription) (code \(nsError.code))"
        lastError = message
        Self.log.error("\(message, privacy: .public)")
    }
}
