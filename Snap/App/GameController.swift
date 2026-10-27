import Combine
import QuartzCore
import SpriteKit
import SwiftUI
import UIKit

/// The hub of the frame loop (ARCHITECTURE "The frame loop"): BogScene.update → advance(dt:now:) → trap source (hinge,
/// touch, pilot, fixed) → TrapSession.step → FeedbackDirector → HUD. Owns the session, the scene, the sources, the
/// app's route, the First Bite lesson and the Duo states (pose card, closing pause, shut).
///
/// Pauses (no stepping): the phone closing (θ < `Tuning.closingAngle` for `Tuning.closingDwell`, Feel's
/// `HingeTrapSource.isClosing`), the app inactive or in the background, the pause menu, and a pose card (portrait, the
/// cover display). The closing pause lifts once the hinge is open again past `AppRules.resumeAngle` (never near 90°).
/// The "tired" ending plays out under a closing or pose pause, so a finished run always reaches Results.
@MainActor
final class GameController: ObservableObject, SceneDriver {
    private enum PauseReason: String, Hashable { case menu, closing, background, pose }

    // MARK: Tuning (named so they're easy to find)

    /// HUD publishing cap.
    static let hudInterval: Double = 1.0 / 15.0
    /// `SNAP-T trap …` at 10 Hz.
    static let trapLogInterval: Double = 0.1
    /// The Duo counts as shut (cover display) at or below this hinge angle, and open again from the release angle.
    static let shutBelow: Double = 10
    static let shutReleaseAbove: Double = 15
    /// The Results card follows the end of Core's tired moment after this beat.
    static let resultsDelay: Double = 0.6
    /// The run-start line's life (session s).
    static let bannerSeconds: Double = 2.6
    static let toastSeconds: Double = 2.4
    /// If the tired moment hasn't finished this long after it began (the scene stopped drawing: the cover display),
    /// the run is finished headless and Results shown.
    static let endWatchSeconds: Double = 3.4
    /// An event freeze also pauses the scene this long after it lands (CI: the moment stays on screen).
    static let sceneHoldDelay: Double = 0.4
    /// Home's title trap: a touch chomp on phones.
    static let homeTouchClosure: Double = 22

    // MARK: Published state (the HUD lives in `hud`, Home's trap in `homeTrap`)

    @Published private(set) var route: AppRoute = .home
    @Published private(set) var scene: BogScene?
    @Published private(set) var sceneGeneration = 0
    /// A hinge has reported this launch (or on an earlier launch of this Duo).
    @Published private(set) var hingeSeen = false
    /// The Duo is shut (hinge ≤ 10°, released at ≥ 15°).
    @Published private(set) var isShut = false
    @Published private(set) var input: AppInputKind = .touch
    @Published private(set) var isMenuOpen = false
    /// "Open it a little to carry on".
    @Published private(set) var isClosingPaused = false
    @Published private(set) var summary: ResultSummary?
    @Published private(set) var lessonDisplay: LessonDisplay?
    @Published private(set) var pose: AppPose = .play
    /// Demo `screen=pose|cover` forces a pose.
    @Published private(set) var forcedPose: AppPose?
    /// Demo `screen=icon`: the app icon full screen (and rendered to Documents).
    @Published private(set) var showsIcon = false
    @Published private(set) var mode: RunMode = .feed
    /// A short line over the screen ("Sign in to Game Center in Settings").
    @Published private(set) var toast: String?
    @Published private(set) var reduceMotion = false
    /// Demo event freezes: the scene is paused too, so the moment stays on screen.
    @Published private(set) var sceneHeld = false

    let hud = HUDState()
    let homeTrap = HomeTrapState()
    let store: ProgressStore
    let settings: SettingsStore
    let hinge = HingeTrapSource()
    /// The tap source: a fresh one each run.
    private(set) var touch = TouchTrapSource()
    /// Home's title trap on an iPhone without a hinge.
    private let homeTouch = TouchTrapSource()
    private let fixedSource = FixedTrapSource()
    private let feedback = FeedbackDirector.shared
    let demo: DemoMode?

    private var session: TrapSession?
    private var pilot: TrapPilot?
    private var lessonScript: LessonScript?
    private var lessonReplay = false
    private var layout: ScreenLayout?
    private var lastCanvasSize: CGSize = .zero
    private var lastCanvasFold = false
    /// The layout the session was built for (its trap geometry).
    private var sessionLayout = ScreenLayout(hasFold: false)
    private var pauseReasons: Set<PauseReason> = []
    private var tally = RunTally()
    private var frames = 0
    private var lastHUD: TimeInterval = -1
    private var lastTrapLog: TimeInterval = -1
    private var lastHint: TrapHint?
    private var recorded = false
    private var checkpointSaved = false
    private var resultsTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var endWatchTask: Task<Void, Never>?
    /// Session seconds stepped this run (the demo freeze-after key).
    private var playTime: Double = 0
    /// Demo freeze: the session no longer steps (the scene keeps drawing the held frame).
    private(set) var frozen = false
    private var freezePendingAt: Double?
    private var freezePendingTag: DemoMode.Freeze?
    private var systemReduceMotion = false
    private var homeTicker: AppFrameTicker?
    private var lastCanvasLine = ""
    private var bannerText: String?
    private var passedBest = false
    private var appActive = true

    init(store: ProgressStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.demo = DemoMode.current
        // `snap.hasHinge` comes back with a backup restored onto another iPhone: believe it only on a Duo-shaped screen.
        let stored = UserDefaults.standard.bool(forKey: OrientationLock.hingeKey)
        let trusted = OrientationLock.trustsStoredHinge(stored, screen: UIScreen.main.bounds.size)
        if stored && !trusted { UserDefaults.standard.removeObject(forKey: OrientationLock.hingeKey) }
        self.hingeSeen = trusted
        self.reduceMotion = settings.reduceMotion
    }

    // MARK: - Derived state

    var isDemo: Bool { demo != nil }
    var hasHinge: Bool { hinge.hasHinge }
    var isPaused: Bool { !pauseReasons.isEmpty }
    var hudOnLeft: Bool { demo?.hudLeft ?? settings.hudOnLeft }
    var demoFold: Bool { demo?.fold ?? false }
    /// No hinge drives the trap: the copy says "tap".
    var touchWording: Bool { input == .touch }
    /// A run is in play (not finished) on a play route.
    var isLiveRun: Bool {
        guard route.isPlay, let session else { return false }
        return !session.isFinished
    }
    var isScoredDaily: Bool {
        if case let .daily(_, scored) = mode { return scored }
        return false
    }
    var today: Int { DailySeed.dayNumber(for: Date()) }
    var dailyScoredAvailable: Bool { store.canPlayScoredDaily(today: today) }
    var lessonReplaying: Bool { lessonReplay }
    /// "Daily Bog · 27 Oct" for the run's day (nil outside a Daily).
    var dailyMarker: String? {
        guard case let .daily(day, scored) = mode else { return nil }
        return scored ? AppRules.dailyTitle(day: day) : "Daily practice · " + AppRules.dailyDate(day: day)
    }
    var restartLabel: String { isScoredDaily ? "Restart as practice" : "Restart" }

    // MARK: - SceneDriver

    func advance(dt: TimeInterval, now: TimeInterval) -> (TrapSnapshot, [TrapEvent]) {
        frames += 1
        if frames == 120 { AppTrace.t("SNAP-T frame 120") }
        guard let session else { return (TrapSnapshot(), []) }
        guard route.isPlay, !session.isFinished else { return (session.snapshot, []) }
        checkClosing(now: now, phase: session.snapshot.phase)
        let width = sessionLayout.size.width
        if frozen {
            feedback.handle([], telemetry: AppRules.telemetry(session.snapshot, sceneWidth: width, playing: false))
            return (session.snapshot, [])
        }
        if isPaused && !stepsThroughPause(session.snapshot.phase) {
            // No stepping. The hinge keeps its own state; a snap made while paused is dropped, never played later.
            if input == .hinge { _ = hinge.input(at: now) }
            let s = session.snapshot
            feedback.handle([], telemetry: AppRules.telemetry(s, sceneWidth: width, playing: false))
            publishHUD(s, now: now, force: false)
            return (s, [])
        }
        // A frame-sized step (clamped at 1/30 s), never the time the game was paused or not drawn.
        let step = AppRules.clampStep(dt)
        guard step > 0 else { return (session.snapshot, []) }

        let trap = currentInput(now: now, step: step, session: session)
        let events = session.step(dt: step, input: trap)
        playTime += step

        if var script = lessonScript {
            let actions = script.update(lessonInput(session.snapshot, events: events))
            lessonScript = script
            for action in actions {
                switch action {
                case let .spawn(species, slot, linger):
                    let spot = AppRules.lessonSpot(slot: slot, geometry: sessionLayout.geometry)
                    session.spawnScripted(species, entry: spot.entry, target: spot.target, linger: linger)
                }
            }
            publishLesson(script)
        }

        let snapshot = session.snapshot
        let live = AppRules.isLive(snapshot.phase)
        feedback.handle(events, telemetry: AppRules.telemetry(snapshot, sceneWidth: width, playing: live))
        var snapped = false
        for event in events {
            tally.note(event)
            switch event {
            case .snapped: snapped = true
            case .tired: watchTheEnd()
            case .newBest: passedBest = true
            default: break
            }
            AppTrace.t("SNAP-T event " + AppTrace.describe(event))
        }
        if AppTrace.enabled && now - lastTrapLog >= Self.trapLogInterval {
            lastTrapLog = now
            let ref = input == .hinge ? hinge.reference : AppTrace.reference(trap)
            AppTrace.t(AppTrace.trapLine(trap, reference: ref))
        }
        publishHUD(snapshot, now: now, force: snapped)
        demoAfterStep(snapshot, events: events)
        if session.isFinished { handleFinished(immediate: false) }
        return (snapshot, events)
    }

    /// A tap anywhere on the scene: snaps when there is no hinge (ignored otherwise).
    func sceneTapped(at point: CGPoint, time: TimeInterval) {
        guard route.isPlay, input == .touch, !isPaused, !frozen, let session, !session.isFinished else { return }
        guard AppRules.isLive(session.snapshot.phase) else { return }
        touch.tap(at: time)
    }

    /// The tired ending keeps stepping under a closing or pose pause (never under the menu or the background).
    private func stepsThroughPause(_ phase: RunPhase) -> Bool {
        guard AppRules.isTired(phase) else { return false }
        return !pauseReasons.contains(.menu) && !pauseReasons.contains(.background)
    }

    private func currentInput(now: TimeInterval, step: Double, session: TrapSession) -> TrapInput {
        switch input {
        case .hinge:
            return hinge.input(at: now)
        case .touch:
            return touch.input(at: now)
        case .fixed:
            return fixedSource.input(at: now)
        case .pilot:
            guard var p = pilot else { return fixedSource.input(at: now) }
            let out = p.step(dt: step, time: now, snapshot: session.snapshot)
            pilot = p
            return out.input
        }
    }

    private func chooseInput() -> AppInputKind {
        if demo?.pilot != nil { return .pilot }
        if demo?.closure != nil { return .fixed }
        if hinge.hasHinge || hingeSeen { return .hinge }
        return .touch
    }

    private func setInput(_ kind: AppInputKind, force: Bool = false) {
        let changed = input != kind
        if changed { input = kind }
        if changed || force { AppTrace.t("SNAP-T input \(kind.rawValue)") }
    }

    /// The first hinge sample of a launch re-chooses the input; a live touch run moves onto the hinge.
    func refreshInput() {
        let kind = chooseInput()
        guard kind != input else { return }
        setInput(kind)
        refreshIdleTimer()
    }

    // MARK: - Lifecycle hooks from RootView

    func launch() {
        if let demo {
            launchDemo(demo)
            return
        }
        // A run killed in the background is filed as left early (its bugs and achievements are kept).
        if let recovered = store.recoverPendingRun(today: today) {
            GameCenterManager.shared.report(result: recovered.0, outcome: recovered.1, progress: store.data)
        }
        if store.data.lessonDone {
            goHome()
        } else {
            // First launch: the First Bite (GAME-DESIGN §8).
            startLesson(replay: false)
        }
    }

    /// The play canvas changed (fold, size, HUD side). The scene is built once and then re-laid out.
    func updateCanvas(_ size: CGSize, hasFold: Bool) {
        guard size.width > 10, size.height > 10 else { return }
        lastCanvasSize = size
        lastCanvasFold = hasFold
        let newLayout = ScreenLayout.make(viewSize: size, hasFold: hasFold, hudOnLeft: hudOnLeft)
        let line = "SNAP-T canvas \(Int(size.width.rounded()))x\(Int(size.height.rounded())) "
            + "fold=\(hasFold ? 1 : 0) hudLeft=\(hudOnLeft ? 1 : 0)"
        if line != lastCanvasLine {
            lastCanvasLine = line
            AppTrace.t(line)
        }
        guard newLayout != layout || scene == nil else { return }
        layout = newLayout
        // Feel pans event sounds across the scene's width (wider phones have a wider scene).
        feedback.sceneWidth = Double(newLayout.size.width)
        if hingeSeen && !feedback.deviceHasFold { feedback.deviceHasFold = true }
        if session == nil { sessionLayout = newLayout }
        if let scene {
            scene.layout = newLayout
        } else {
            makeScene(newLayout)
        }
    }

    /// Settings › HUD on the left changed.
    func refreshLayout() {
        guard lastCanvasSize.width > 10 else { return }
        updateCanvas(lastCanvasSize, hasFold: lastCanvasFold)
    }

    private func makeScene(_ layout: ScreenLayout) {
        let newScene = BogScene(layout: layout)
        newScene.scaleMode = .aspectFill
        newScene.reduceMotion = reduceMotion
        newScene.driver = self
        scene = newScene
        sceneGeneration += 1
        newScene.reset()
    }

    /// Only `.background` opens the pause menu (folding shut may pass through `.inactive` on hardware, and then every
    /// close would end on the menu). Inactive (Control Centre, a call banner) pauses quietly.
    func setScenePhase(_ phase: ScenePhase) {
        if phase == .active {
            appActive = true
            // A fresh snap detector from the last reading: a stale reference can't make the first frames snap.
            if hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }
            if checkpointSaved {
                checkpointSaved = false
                store.clearCheckpoint()
            }
            setPause(.background, false)
            if route == .home { startHomeTicker() }
            return
        }
        appActive = false
        let background = phase == .background
        if background, isLiveRun, !isDemo, let session, !recorded {
            // A kill in the background must not lose the run: keep its result so far until we're back.
            let partial = tally.result(mode: session.mode, seed: session.seed, snapshot: session.snapshot)
            if ProgressRules.worthRecording(partial) {
                store.saveCheckpoint(partial)
                checkpointSaved = true
            }
            if !isShut { openMenu() }
        }
        setPause(.background, true)
        homeTicker?.stop()
        feedback.silence()
    }

    /// The display's pose changed (portrait card, the cover display). Logs `SNAP-T pose <pose>`.
    func setPose(_ newPose: AppPose) {
        guard newPose != pose else { return }
        pose = newPose
        AppTrace.t("SNAP-T pose \(newPose.rawValue)")
        setPause(.pose, newPose != .play)
    }

    func setSystemReduceMotion(_ on: Bool) {
        systemReduceMotion = on
        refreshMotion()
    }

    func refreshMotion() {
        let on = systemReduceMotion || settings.reduceMotion
        if reduceMotion != on { reduceMotion = on }
        scene?.reduceMotion = on
    }

    // MARK: - Hinge

    func hingeSample(angle: Double, time: TimeInterval) {
        guard angle.isFinite else { return }
        hinge.ingest(angleDegrees: angle, at: time)
        if !hingeSeen {
            hingeSeen = true
            if !isDemo { UserDefaults.standard.set(true, forKey: OrientationLock.hingeKey) }
            OrientationLock.hingeArrived()
        }
        if !feedback.deviceHasFold { feedback.deviceHasFold = true }
        if isShut {
            if angle >= Self.shutReleaseAbove { isShut = false }
        } else if angle <= Self.shutBelow {
            isShut = true
        }
        refreshInput()
    }

    /// After a hinge has been seen, a nil is a display handover, never "no hinge" (Brim research).
    func hingeUnavailable() {}

    /// The closing pause: Feel's gate (θ < `Tuning.closingAngle` for `Tuning.closingDwell`) pauses; it lifts once the
    /// hinge is open past `AppRules.resumeAngle` and not shut. Only while the trap is in play (the tired moment plays
    /// out).
    private func checkClosing(now: TimeInterval, phase: RunPhase) {
        guard input == .hinge, route.isPlay, session != nil else {
            if isClosingPaused { setClosing(false) }
            return
        }
        if isClosingPaused {
            if AppRules.mayResume(angle: hinge.angle, isClosing: hinge.isClosing, isShut: isShut) {
                setClosing(false)
            }
        } else if hinge.isClosing && AppRules.isLive(phase) {
            setClosing(true)
            #if DEBUG
            // A literal of its own, DEBUG only: a TestFlight guard may grep the Release binary for it.
            if AppTrace.enabled {
                print("SNAP-T paused closing")
                fflush(stdout)
            }
            #endif
        }
    }

    private func setClosing(_ on: Bool) {
        if isClosingPaused != on { isClosingPaused = on }
        setPause(.closing, on)
    }

    // MARK: - Home's title trap

    /// Home on an iPhone without a hinge: a tap on the title trap chomps it.
    func homeTrapTapped() {
        guard route == .home, !hinge.hasHinge else { return }
        homeTouch.tap(at: CACurrentMediaTime())
    }

    private func startHomeTicker() {
        if homeTicker == nil {
            homeTicker = AppFrameTicker { [weak self] now in self?.tickHome(now) }
        }
        homeTicker?.start()
    }

    private func tickHome(_ now: TimeInterval) {
        guard route == .home, appActive else {
            homeTicker?.stop()
            return
        }
        let trap: TrapInput
        if let held = demo?.closure {
            trap = TrapInput(closure: held, armed: true)
        } else if hinge.hasHinge {
            trap = hinge.input(at: now)
        } else {
            trap = homeTouch.input(at: now)
        }
        let chomped = trap.snap != nil
        feedback.homeTrap(closure: trap.closure, snapped: chomped)
        let c01 = trap.closure.isFinite ? trap.closure / max(Tuning.snapDepth, 1) : 0
        homeTrap.update(closure01: min(max(c01, 0), 1), chomped: chomped)
    }

    // MARK: - Navigation

    func show(_ newRoute: AppRoute) {
        guard !newRoute.isPlay else { return }
        feedback.uiTap()
        if newRoute == .home {
            goHome()
            return
        }
        setRoute(newRoute)
    }

    func play() {
        feedback.uiConfirm()
        start(.feed)
    }

    func playDaily() {
        feedback.uiConfirm()
        start(.daily(day: today, scored: true))
    }

    func practiseDaily() {
        feedback.uiConfirm()
        start(.daily(day: today, scored: false))
    }

    /// Results' Again (a Daily is always practised: `AppRules.againMode`).
    func again() {
        feedback.uiConfirm()
        start(summary.map { AppRules.againMode($0.result.mode) } ?? .feed)
    }

    func openMenu() {
        guard route.isPlay, !isMenuOpen else { return }
        feedback.uiTap()
        isMenuOpen = true
        setPause(.menu, true)
    }

    func resume() {
        guard isMenuOpen else { return }
        feedback.uiTap()
        isMenuOpen = false
        setPause(.menu, false)
    }

    /// The pause menu's Restart: a scored Daily restarts as practice (one scored try a day).
    func restart() {
        feedback.uiTap()
        switch mode {
        case .lesson:
            startLesson(replay: lessonReplay)
        case let .daily(day, _):
            start(.daily(day: day, scored: false))
        case .feed, .attract:
            start(mode)
        }
    }

    func goHome() {
        abandonLiveRun()
        resultsTask?.cancel()
        endWatchTask?.cancel()
        session = nil
        pilot = nil
        lessonScript = nil
        lessonDisplay = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        scene?.isPaused = false
        feedback.silence()
        hud.update(HUDValues())
        setRoute(.home)
        refreshIdleTimer()
    }

    func showGameCenter() {
        switch GameCenterManager.shared.showDashboard() {
        case .shown, .signingIn: break
        case .signedOut: showToast("Sign in to Game Center in Settings")
        }
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.toastSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func setRoute(_ newRoute: AppRoute) {
        if newRoute != route {
            route = newRoute
            AppTrace.t("SNAP-T screen \(newRoute.rawValue)")
        }
        if newRoute == .home && appActive { startHomeTicker() } else { homeTicker?.stop() }
        feedback.idle = !newRoute.isPlay
    }

    // MARK: - The First Bite lesson

    func startLesson(replay: Bool, at step: LessonScript.Step = .pose) {
        lessonReplay = replay
        start(.lesson)
        let script = LessonScript(start: step, replay: replay)
        lessonScript = script
        publishLesson(script)
    }

    func replayLesson() {
        feedback.uiConfirm()
        startLesson(replay: true)
    }

    /// Skip (offered after step 2): the lesson counts as done.
    func skipLesson() {
        store.markLessonDone()
        goHome()
    }

    /// The final card's "Start feeding": the first run.
    func finishLesson() {
        store.markLessonDone()
        feedback.uiConfirm()
        start(.feed)
    }

    func finishLessonHome() {
        store.markLessonDone()
        goHome()
    }

    private func lessonInput(_ s: TrapSnapshot, events: [TrapEvent]) -> LessonScript.Input {
        var flies = 0
        var bees = 0
        for b in s.bugs {
            switch b.activity {
            case .leaving, .caught, .escaped, .released:
                continue
            case .arriving, .walking, .sipping, .hopping:
                if b.species.isProtected { bees += 1 } else { flies += 1 }
            }
        }
        // A Duo's first hinge report can lag the first frame: a fold layout keeps the pose step (real runs). Demo
        // `lessonStep=1` on a phone sim keeps it on screen too (a frame of it).
        let foldLayout = (layout?.hasFold ?? false) && !isDemo
        let hingeLike = input == .hinge || foldLayout || demo?.lessonStep == 1
        return LessonScript.Input(time: s.time, angle: input == .hinge ? hinge.angle : nil, hasHinge: hingeLike,
                                  armed: s.armed, events: events, liveFlies: flies, liveBees: bees)
    }

    private func publishLesson(_ script: LessonScript) {
        let display = script.display(touch: touchWording)
        guard display != lessonDisplay else { return }
        if display.step != lessonDisplay?.step || display.praise != lessonDisplay?.praise
            || display.warning != lessonDisplay?.warning {
            AppTrace.t("SNAP-T lesson step \(display.step) '\(display.praise ?? display.warning ?? display.line)'")
        }
        lessonDisplay = display
    }

    // MARK: - Runs

    private func start(_ newMode: RunMode) {
        abandonLiveRun()
        resultsTask?.cancel()
        endWatchTask?.cancel()
        summary = nil
        clearRunPauses()
        frozen = false
        sceneHeld = false
        scene?.isPaused = false
        freezePendingAt = nil
        freezePendingTag = nil
        var m = newMode
        if case let .daily(day, scored) = m, scored {
            if store.canPlayScoredDaily(today: day) {
                store.startDaily(day: day)
            } else {
                m = .daily(day: day, scored: false)
            }
        }
        mode = m
        if layout == nil {
            // Not laid out yet (a portrait launch): the trap is built for the screen as it will be held.
            var screen = OrientationLock.screenSize()
            if screen.width < 1 { screen = UIScreen.main.bounds.size }
            layout = ScreenLayout.make(viewSize: screen, hasFold: false, hudOnLeft: hudOnLeft)
        }
        sessionLayout = layout ?? ScreenLayout(hasFold: false, hudOnLeft: hudOnLeft)
        let runSeed = seed(for: m)
        var options: SessionOptions = m == .lesson
            ? SessionOptions(snapsRunOut: false, waves: false, stingCosts: false)
            : SessionOptions.`for`(m)
        // Demo `wave=`: Core starts the run at that wave (its nectar block and day follow).
        if m != .lesson, let wave = demo?.wave, wave > 1 { options.firstWave = wave }
        let newSession = TrapSession(mode: m, seed: runSeed, best: store.best(for: m), geometry: sessionLayout.geometry,
                                     options: options)
        session = newSession
        touch = TouchTrapSource()
        fixedSource.closure = demo?.closure ?? 0
        pilot = demo?.pilot.map { TrapPilot(skill: $0, seed: runSeed &+ 101) }
        if m != .lesson {
            lessonScript = nil
            lessonDisplay = nil
        }
        setInput(chooseInput(), force: true)
        tally = RunTally(hingeTiming: input == .hinge || input == .pilot)
        recorded = false
        playTime = 0
        passedBest = false
        lastHUD = -1
        lastHint = nil
        bannerText = AppRules.startBanner(m, touch: touchWording)
        scene?.reset()
        setRoute(m == .lesson ? .lesson : .playing)
        publishHUD(newSession.snapshot, now: CACurrentMediaTime(), force: true)
        refreshIdleTimer()
    }

    private func seed(for mode: RunMode) -> UInt64 {
        switch mode {
        case .feed:
            if let s = demo?.seed { return s }
            if isDemo { return DemoMode.defaultSeed }
            return UInt64.random(in: 1...UInt64.max)
        case let .daily(day, _):
            return DailySeed.seed(day: day)
        case .attract:
            return demo?.seed ?? DemoMode.defaultSeed
        case .lesson:
            return 1
        }
    }

    /// Leaving a live run (Home, Restart, a new run) files its result so far: its bugs into the Bug Book, its catches
    /// into the rank, and a scored Daily's score as the day's score (plus the Game Center boards).
    private func abandonLiveRun() {
        guard let session, !recorded, !session.isFinished else { return }
        recorded = true
        checkpointSaved = false
        let partial = tally.result(mode: session.mode, seed: session.seed, snapshot: session.snapshot)
        guard ProgressRules.worthRecording(partial) else {
            store.clearCheckpoint()
            return
        }
        let outcome = store.recordAbandoned(partial, today: today)
        GameCenterManager.shared.report(result: partial, outcome: outcome, progress: store.data)
        AppTrace.t("SNAP-T abandoned score=\(partial.score) bugs=\(partial.bugsCaught)")
    }

    /// The tired moment normally finishes in 2.2 s of drawn frames. If the scene stopped drawing (the Duo was folded
    /// onto the cover display), finish the run headless so Results never wait on the hinge.
    private func watchTheEnd() {
        endWatchTask?.cancel()
        endWatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.endWatchSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finishIfStuck()
        }
    }

    private func finishIfStuck() {
        guard let session, !recorded, !session.isFinished, route.isPlay, !frozen, freezePendingAt == nil else { return }
        guard AppRules.isTired(session.snapshot.phase) else { return }
        var steps = 0
        let open = TrapInput()
        while !session.isFinished && steps < 600 {
            for e in session.step(dt: AppRules.maxStep, input: open) { tally.note(e) }
            steps += 1
        }
        AppTrace.t("SNAP-T ending finished headless steps=\(steps)")
        if session.isFinished { handleFinished(immediate: true) }
    }

    private func handleFinished(immediate: Bool) {
        guard !recorded, let session, let result = session.result else { return }
        recorded = true
        checkpointSaved = false
        endWatchTask?.cancel()
        let outcome = store.record(result, today: today)
        GameCenterManager.shared.report(result: result, outcome: outcome, progress: store.data)
        AppTrace.t("SNAP-T run score=\(result.score) bugs=\(result.bugsCaught) snaps=\(result.snaps) "
                   + "seconds=\(Int(result.seconds.isFinite ? result.seconds : 0))")
        summary = makeSummary(result, outcome: outcome)
        refreshIdleTimer()
        resultsTask?.cancel()
        if immediate {
            showResults()
        } else {
            resultsTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(GameController.resultsDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.showResults()
            }
        }
    }

    private func showResults() {
        guard let summary else { return }
        clearRunPauses()
        feedback.silence()
        setRoute(.results)
        if summary.outcome.rankedUp || !summary.outcome.newSpecies.isEmpty || summary.outcome.showsNewBest {
            feedback.celebrate()
        }
        if demo?.freezeOn == .results { AppTrace.t("SNAP-T freeze results") }
    }

    private func makeSummary(_ result: RunResult, outcome: RecordOutcome) -> ResultSummary {
        let title: String
        let again: String
        switch result.mode {
        case .feed:
            title = "Your trap is tired"
            again = "Again"
        case let .daily(day, scored):
            title = scored ? AppRules.dailyTitle(day: day) : "Daily practice · " + AppRules.dailyDate(day: day)
            again = "Practise this bog"
        case .attract:
            title = "Demo run"
            again = "Again"
        case .lesson:
            title = "First Bite"
            again = "Feed"
        }
        let rank = outcome.rankAfter
        let next = rank + 1 < PlantRanks.count ? PlantRanks.title(rank + 1) : nil
        let before = outcome.rankedUp ? 0 : ProgressRules.rankProgress(lifetime: outcome.lifetimeBefore, rank: rank)
        let after = ProgressRules.rankProgress(lifetime: outcome.lifetimeAfter, rank: rank)
        return ResultSummary(result: result, outcome: outcome, title: title, story: AppRules.story(result),
                             rankTitle: PlantRanks.title(rank), nextRankTitle: next, rankProgressBefore: before,
                             rankProgressAfter: after, againLabel: again,
                             nearMiss: AppRules.nearMiss(score: result.score, best: outcome.best,
                                                         newBest: outcome.isNewBest))
    }

    // MARK: - HUD

    private func publishHUD(_ s: TrapSnapshot, now: TimeInterval, force: Bool) {
        var hint = s.hint
        if route == .lesson || isPaused || frozen { hint = nil }
        if let h = hint, AppRules.hintText(h, touch: touchWording) == nil { hint = nil }
        if !AppRules.isLive(s.phase) { hint = nil }
        var values = HUDValues()
        values.score = s.score
        values.best = s.best
        values.snapsLeft = s.snapsLeft
        values.snapsMax = s.snapsMax
        values.chain = s.chain
        values.chainMultiplier = s.chainMultiplier
        values.hint = hint
        values.banner = hint == nil && s.time < Self.bannerSeconds && !isPaused ? bannerText : nil
        values.tired = AppRules.isTired(s.phase)
        values.passedBest = passedBest
        values.dayPhase = s.dayPhase
        values.lesson = route == .lesson
        let urgent = force || hint != lastHint || values.tired != hud.values.tired
        guard urgent || now - lastHUD >= Self.hudInterval else { return }
        lastHUD = now
        lastHint = hint
        hud.update(values)
    }

    // MARK: - Pauses

    private func setPause(_ reason: PauseReason, _ on: Bool) {
        let was = isPaused
        if on {
            let inserted = pauseReasons.insert(reason).inserted
            if inserted && route.isPlay && reason != .closing { AppTrace.t("SNAP-T paused \(reason.rawValue)") }
        } else {
            pauseReasons.remove(reason)
        }
        if isPaused && !was {
            feedback.silence()
        } else if !isPaused && was && route.isPlay {
            // Every resume: a fresh detector, so the reopening stroke never reads as a snap or a creep.
            if input == .hinge && hinge.hasHinge { hinge.reset(at: CACurrentMediaTime()) }
            AppTrace.t("SNAP-T resumed")
        }
        if isPaused != was { refreshIdleTimer() }
    }

    private func clearRunPauses() {
        pauseReasons.remove(.menu)
        pauseReasons.remove(.closing)
        if isMenuOpen { isMenuOpen = false }
        if isClosingPaused { isClosingPaused = false }
    }

    /// The screen may sleep while paused (a Duo left half-closed), never mid-run.
    private func refreshIdleTimer() {
        let keepAwake = !isDemo && isLiveRun && !isPaused
        if UIApplication.shared.isIdleTimerDisabled != keepAwake { UIApplication.shared.isIdleTimerDisabled = keepAwake }
    }

    // MARK: - Demo

    private func launchDemo(_ d: DemoMode) {
        AppTrace.t("SNAP-T demo '\(d.raw)' starts")
        let day = today
        store.replace(DemoPresets.progress(d.progress, today: day))
        if !d.sound { settings.muted = true }
        switch d.effectiveScreen {
        case .home:
            goHome()
        case .play:
            start(d.runMode(today: day))
            if let wave = d.wave, wave > 1 { AppTrace.t("SNAP-T start wave \(wave)") }
        case .results:
            start(d.runMode(today: day))
            if let session {
                var t = tally
                DemoRunner.playToEnd(session, skill: d.pilot ?? .casual, seed: session.seed, onEvent: { e in t.note(e) })
                tally = t
                if session.isFinished {
                    handleFinished(immediate: true)
                } else {
                    goHome()
                }
            }
        case .book:
            goHome()
            setRoute(.book)
        case .settings:
            goHome()
            setRoute(.settings)
        case .daily:
            goHome()
            setRoute(.daily)
        case .lesson:
            let step = LessonScript.Step(rawValue: d.lessonStep ?? 1) ?? .pose
            startLesson(replay: false, at: step)
        case .pose:
            forcedPose = .pose
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .cover:
            forcedPose = .cover
            if d.mode != nil { start(d.runMode(today: day)) } else { goHome() }
        case .icon:
            showsIcon = true
            goHome()
        }
    }

    private func demoAfterStep(_ s: TrapSnapshot, events: [TrapEvent]) {
        guard let demo, !frozen else { return }
        if let at = freezePendingAt {
            if playTime >= at { freeze(freezePendingTag?.rawValue ?? "after", holdScene: freezePendingTag != nil) }
            return
        }
        if let after = demo.holdAfter, playTime < after { return }
        if let tag = demo.freezeOn {
            guard tag != .results, Self.matches(tag, s, events: events) else { return }
            if tag.isEvent {
                freezePendingAt = playTime + tag.holdDelay
                freezePendingTag = tag
            } else {
                freeze(tag.rawValue, holdScene: false)
            }
        } else if demo.holdAfter != nil {
            freeze("after", holdScene: false)
        }
    }

    /// Whether this frame is the demo freeze moment `tag`. Pure; tested.
    nonisolated static func matches(_ tag: DemoMode.Freeze, _ s: TrapSnapshot, events: [TrapEvent]) -> Bool {
        switch tag {
        case .landed:
            return s.bugs.contains { $0.activity == .sipping && $0.inTrap }
        case .crowd:
            return s.bugs.filter { $0.activity == .sipping && $0.inTrap && !$0.species.isProtected }.count >= 3
        case .bee:
            return s.bugs.contains { $0.activity == .sipping && $0.inTrap && $0.species.isProtected }
        case .snap:
            return events.contains { e in
                if case .snapped = e { return true }
                return false
            }
        case .feast:
            return events.contains { e in
                if case .feast = e { return true }
                return false
            }
        case .sting:
            return events.contains { e in
                if case .stung = e { return true }
                return false
            }
        case .dusk:
            return s.dayPhase >= .dusk
        case .night:
            return s.dayPhase >= .night
        case .lastSnap:
            return events.contains(.lastSnap)
        case .tired:
            return AppRules.isTired(s.phase)
        case .results:
            return false
        }
    }

    /// Stops stepping. An event freeze also pauses the scene after a beat, so the CHOMP, "Bzzt!" and the score pop
    /// are still on screen when CI's shot lands.
    private func freeze(_ tag: String, holdScene: Bool) {
        frozen = true
        freezePendingAt = nil
        feedback.silence()
        AppTrace.t("SNAP-T freeze \(tag)")
        guard holdScene else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(GameController.sceneHoldDelay * 1_000_000_000))
            guard let self, self.frozen else { return }
            self.sceneHeld = true
            self.scene?.isPaused = true
        }
    }
}
