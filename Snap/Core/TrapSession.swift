import CoreGraphics
import Foundation

// MARK: - Session options per mode

struct SessionOptions: Equatable {
    /// false: attract, lesson (snapsLeft never changes, the run never tires).
    var snapsRunOut: Bool = true
    /// false: the lesson spawns by script only.
    var waves: Bool = true
    /// false: the lesson (a stinger costs nothing; the chain still breaks).
    var stingCosts: Bool = true
    /// Demo `wave=<n>`: the first wave of the run (1 = the normal start). The nectar block and day follow it.
    var firstWave: Int = 1
    /// R2 (REVIEW-1 #24): the snaps a run starts with (nil = Tuning.startSnaps). The App passes 12 while the plant
    /// rank is Sprout. Clamped to 1…Tuning.maxSnaps.
    var startSnaps: Int? = nil
    /// R2 hunger (GAME-DESIGN §5): snaps wilt without a catching bite. Only runs whose snaps run out ever wilt, so
    /// the lesson and attract never do; false switches it off for a feed run too (tests, tools).
    /// R3 (REVIEW-2 #9): the App passes false for a Sprout's first run ("Sprout run 1 never wilts").
    var hunger: Bool = true
    /// R3 (REVIEW-2 #9): the run's first bite with a stinger in it costs no extra snap (its `stung` events carry
    /// cost 0 and its BiteReport.snapsLost is 0; the bite still scores ×1, refunds nothing and breaks the chain).
    /// The App passes true for a Sprout's first run and shows "Bees cost a snap!" on that `stung(cost: 0)`.
    var freeFirstSting: Bool = false
    /// R4 (REVIEW-3 #11, QA-2 #11, founder call): a Sprout's first Feed run. The run starts with Tuning.firstRunSnaps
    /// (14, whatever `startSnaps` says), never wilts, its first stinger bite is free (as `freeFirstSting`), and its
    /// first Tuning.firstRunCalmWaves waves are crowds with Tuning.firstRunWaveGap × the usual gap after each.
    /// Feed only: a session of any other mode ignores it, so a Daily always plays by the standard rules (if a player's
    /// first ever run is the Daily, it is standard and their first Feed run still gets the perks). The App decides
    /// "first Feed run" on a Feed-only count.
    /// R5: this is now `sproutRun == 1` (setting it true sets sproutRun to 1; false clears only a run-1 taper).
    var firstRun: Bool {
        get { return sproutRun == 1 }
        set {
            if newValue {
                sproutRun = 1
            } else if sproutRun == 1 {
                sproutRun = 0
            }
        }
    }
    /// R5 (REVIEW-4 #8, founder call): the Sprout taper's Feed run (1, 2 or 3; 0 = none; anything past
    /// Tuning.sproutTaperRuns plays standard). See SproutPerks.forFeedRun. Feed only, like `firstRun`: a session of any
    /// other mode ignores it. Build it with `SessionOptions.sprout(feedRun:)`.
    var sproutRun: Int = 0
    /// R8 (ROUND-8 §4): false: no snap refunds (no Feast, scarab or ladybird snaps back): a level's bite limit is
    /// literal.
    var refunds: Bool = true

    init(snapsRunOut: Bool = true, waves: Bool = true, stingCosts: Bool = true) {
        self.snapsRunOut = snapsRunOut
        self.waves = waves
        self.stingCosts = stingCosts
    }

    /// R5 (REVIEW-4 #8): Feed options for a Sprout's Feed run number `feedRun` (1-based: 1 is the player's first Feed
    /// run, so pass the count of finished Feed runs + 1). Runs 1–3 carry the taper (sproutRun); run 4 on, and
    /// anything ≤ 0, are the standard Feed options. `startSnaps` stays nil: the taper's snaps override it anyway.
    static func sprout(feedRun: Int) -> SessionOptions {
        var o: SessionOptions = SessionOptions.for(.feed)
        o.sproutRun = SproutPerks.forFeedRun(feedRun) == nil ? 0 : feedRun
        return o
    }

    /// R5: the taper perks a session of this mode gets (Feed only; nil for the Daily, attract, the lesson and runs 4+).
    func sproutPerks(for mode: RunMode) -> SproutPerks? {
        switch mode {
        case .feed: return SproutPerks.forFeedRun(sproutRun)
        case .daily, .attract, .lesson, .zen, .level: return nil
        }
    }

    static func `for`(_ mode: RunMode) -> SessionOptions {
        switch mode {
        case .feed, .daily:
            return SessionOptions()
        case .attract:
            return SessionOptions(snapsRunOut: false, waves: true, stingCosts: true)
        case .lesson:
            return SessionOptions(snapsRunOut: false, waves: false, stingCosts: false)
        case .zen:
            // R6 Zen Bog: snaps never run out, no hunger (so no wilts), and a stinger costs no snap (the chain still
            // breaks). The day loops every Tuning.zenDayWaves waves and the late-night ramp never starts (paceWave).
            var o = SessionOptions(snapsRunOut: false, waves: true, stingCosts: false)
            o.hunger = false
            return o
        case .level(let id):
            // R8 (ROUND-8 §4): LevelBook.options (no waves, hunger or refunds; the bite limit). An unknown id plays as
            // a scripted session with no bugs and no limits.
            if let l = LevelBook.level(id) { return LevelBook.options(l) }
            var o = SessionOptions(snapsRunOut: false, waves: false, stingCosts: false)
            o.hunger = false
            o.refunds = false
            return o
        }
    }

    /// R4: does `firstRun` apply to a session of this mode (Feed only; the Daily stays standard)?
    func firstRunApplies(to mode: RunMode) -> Bool {
        guard firstRun else { return false }
        switch mode {
        case .feed: return true
        case .daily, .attract, .lesson, .zen, .level: return false
        }
    }
}

// MARK: - R5 (REVIEW-4 #8, founder call): the Sprout taper

/// What a Sprout's first Feed runs get. Run 1: 14 snaps, no wilting, a free first sting and the calm morning. Run 2:
/// 13 snaps, a free first sting and the calm morning (it wilts). Run 3: 12 snaps and the calm morning. Run 4 on: none
/// (the standard rules, with whatever `startSnaps` the App passes).
struct SproutPerks: Equatable {
    /// 1…Tuning.sproutTaperRuns.
    var run: Int
    /// The run starts with this many, whatever SessionOptions.startSnaps says.
    var startSnaps: Int
    /// The run never wilts.
    var noWilt: Bool
    /// Its first stinger bite costs no extra snap (as SessionOptions.freeFirstSting).
    var freeSting: Bool
    /// Waves 1…Tuning.firstRunCalmWaves are crowds, each followed by Tuning.firstRunWaveGap × the usual gap.
    var calmMorning: Bool

    static func forFeedRun(_ run: Int) -> SproutPerks? {
        guard run >= 1 && run <= Tuning.sproutTaperRuns else { return nil }
        switch run {
        case 1:
            return SproutPerks(run: 1, startSnaps: Tuning.firstRunSnaps, noWilt: true, freeSting: true,
                               calmMorning: true)
        case 2:
            return SproutPerks(run: 2, startSnaps: Tuning.sproutRun2Snaps, noWilt: false, freeSting: true,
                               calmMorning: true)
        default:
            return SproutPerks(run: run, startSnaps: Tuning.sproutRun3Snaps, noWilt: false, freeSting: false,
                               calmMorning: true)
        }
    }
}

// MARK: - One run (GAME-DESIGN §4–§6, ARCHITECTURE "TrapSession behaviour", ROUND-1 "Movement")
//
// Deterministic: the same seed, geometry and inputs give the same run. `step` handles the frame's input first (the
// bite on `input.snap`, then the creep), then sub-steps the world at ≤ Tuning.maxSubstep.
// Bug life: approach (a wobbly decelerating arc, height 1 → 0.5) → hover (0.3–0.6 s, 0.5 → 0) → land → sip at its
// drop, or pause/dash (walk in short dashes around its spot, claiming a drop that frees up), hoppers hop, darters
// dart and hover → linger over → leave toward the nearest edge. Ants walk in from the bottom in single file and walk
// out again (always catchable while in the trap). Linger counts from landing. One bug per drop; landed bugs keep
// radius + radius + 4 pt apart.
// R2: bug radii are ×1.8 (BugCatalog.scaled) and the rim test uses the bug's outer edge (TrapRules.onRim). Hunger:
// with no catching bite for the phase's wilt time (Tuning.wilt*), a snap wilts (`wilted`), and `hungry` fires
// Tuning.hungryWarning s before. Chain: a clean bite of ≥ 2 adds a step, a clean 1-bug bite holds, a dry snap or a
// stinger breaks it.
// R3 (design/notes/core-R3.md): no bug rests within creaseHalfWidth + radius + 16 pt of the midrib line (findSpot →
// TrapRules.offCrease; nectar drops sit ≥ 80 pt off it). The hunger clock (18/16/14/12 s) runs only from the first
// in-trap landing of a catchable bug after a catching bite (and after the start). A bite with a stinger scores ×1 and
// refunds nothing. SessionOptions.freeFirstSting waives the first stinger bite's cost (Sprout run 1).
// R4 (design/notes/core-R4.md): the hunger clock ticks only while a catchable bug has landed in the trap and no
// protected bug has (night wilt 14 s); SessionOptions.firstRun (Feed only: 14 snaps, no wilting, the first sting free,
// a calm first morning); ground moves and the hover keep to the bug's own lobe and a walker walks in on its spot's
// side, so nothing walks, rests or hovers low within creaseHalfWidth + radius of the midrib (Tuning.creaseAirHeight).
// R5 (design/notes/core-R5.md): a protected bug pauses the hunger clock from its final approach (in the zone and below
// creaseAirHeight); the Sprout taper (SessionOptions.sproutRun / sprout(feedRun:), SproutPerks: runs 1–3).
// R6 (design/notes/core-R6.md): the Zen Bog (SessionOptions.for(.zen); its day loops and never speeds up), the late
// night telegraphed (TrapRules.nightCue) and the last light (Feed and the Daily: from Tuning.lastLightWave the hunger clock ticks
// even with an empty or bee-held trap, so every run whose snaps run out ends), no newBest in Zen, and no "hungry" hint while a
// protected bug's halo touches the trap.
// R7 (design/notes/core-R7.md): one scoring function, TrapRules.bitePoints, with the FEAST multiplier (×2) inside a
// clean bite of ≥ Tuning.bigFeastCount.
// R8 (design/notes/core-R8.md, ROUND-8 §1–§2): the lid is the jaw. `step` reads the input's continuous closure first
// (fear: a close starts at Tuning.closeStart; each catchable bug in the trap startles at its nerve and flees after its
// reaction time), then the bite at the shut (exposure = max(real, TrapRules.modelExposure)), then the reopen (`rearmed`).
// Shut (from the bite until the input is armed again) and a round waiting for its first close freeze the clock: only
// bugs already caught, escaping, released or leaving move. BiteReport.catchRatio; any miss breaks the chain.
// Mirrored by Session in tools/balance-sim.js (minus events, hints, telemetry and results).

final class TrapSession {

    let mode: RunMode
    let seed: UInt64
    let best: Int
    let geometry: TrapGeometry
    let options: SessionOptions
    /// R4: options.firstRun, for a Feed session (SessionOptions.firstRunApplies). R5: sproutPerks?.run == 1.
    let firstRunPerks: Bool
    /// R5 (REVIEW-4 #8): the Sprout taper this session plays (SessionOptions.sproutPerks(for:); nil = standard).
    let sproutPerks: SproutPerks?
    /// R8 (ROUND-8 §4): the level this session plays (mode .level(id) with a known id), else nil.
    let levelSpec: LevelSpec?
    /// R8: why the level ended (nil until it has, and outside levels).
    private(set) var levelEnd: LevelEnd? = nil

    fileprivate enum Mode: Equatable {
        case approach, hover, sip, pause, dash, hop, cross, leave, escape, release, caught
    }

    fileprivate final class Bug {
        let id: Int
        let species: BugSpecies
        let info: BugInfo
        let motion: BugMotion
        var rng: SeededRandom
        var x: Double
        var y: Double
        var heading: Double = 0
        var height: Double
        var mode: Mode
        /// The current leg: from (fx, fy) to (tx, ty), control point (cx, cy) for the approach arc.
        var fx: Double
        var fy: Double
        var tx: Double
        var ty: Double
        var cx: Double = 0
        var cy: Double = 0
        var el: Double = 0
        var dur: Double = 1
        /// Leaving: distance travelled so far, and the height it took off from.
        var travelled: Double = 0
        var startHeight: Double = 0
        var age: Double = 0
        var timer: Double = 0
        var linger: Double
        var lingerTotal: Double
        let landsInTrap: Bool
        var dropID: Int? = nil
        var wantsNectar: Bool = false
        var homeX: Double
        var homeY: Double
        var wobblePhase: Double = 0
        var landed: Bool = false
        var landedInTrap: Bool = false
        var sparedSent: Bool = false
        var hovering: Bool = false
        var spooked: Bool = false
        var restless: Double = 0
        var sip: Double = 0
        var gone: Bool = false
        /// R8: the session time it startled in the current close (closure passed its nerve), if it has.
        var startledAt: Double? = nil

        init(id: Int, spec: SpawnSpec, seed: UInt64) {
            self.id = id
            self.species = spec.species
            self.info = BugCatalog.info(spec.species)
            let mo: BugMotion = BugCatalog.motion(spec.species)
            self.motion = mo
            self.rng = SeededRandom(seed: seed)
            self.x = Double(spec.entry.x)
            self.y = Double(spec.entry.y)
            self.height = mo.style == .walker ? 0 : 1
            self.mode = .approach
            self.fx = Double(spec.entry.x)
            self.fy = Double(spec.entry.y)
            self.tx = Double(spec.target.x)
            self.ty = Double(spec.target.y)
            self.linger = spec.linger
            self.lingerTotal = spec.linger
            self.landsInTrap = spec.landsInTrap
            self.homeX = Double(spec.target.x)
            self.homeY = Double(spec.target.y)
        }

        var point: CGPoint { return CGPoint(x: x, y: y) }
    }

    fileprivate struct PendingSpawn {
        var at: Double
        var spec: SpawnSpec
    }

    private var phase: RunPhase = .playing
    private var time: Double = 0
    private var tiredAt: Double = 0
    private var bugs: [Bug] = []
    private var nextID: Int = 1
    private var pending: [PendingSpawn] = []
    private var wave: Int = 0
    private var nextWaveAt: Double = Tuning.firstWaveTime
    private var lastWaveAt: Double = 0
    private var dayPhase: DayPhase = .morning
    private var nectar: [NectarDrop] = []
    private var nectarBlock: Int = 0
    private var nextDropID: Int = 0
    private var reservedBy: [Int: Int] = [:]
    private var retiring: Set<Int> = []

    private var snapsLeft: Int = Tuning.startSnaps
    /// R2 hunger: 0 just fed … 1 a snap wilts. Grows by dt / (the current phase's wilt time).
    private var hunger: Double = 0
    private var hungrySent: Bool = false
    /// R4 (QA-2 #1, REVIEW-3 #12): the hunger clock ticked on the last tick (hungerTicks()): a catchable bug has landed
    /// in the trap and no protected bug has. Empty, bee-only and bee-plus-flies traps never get hungrier.
    private var hungerLive: Bool = false
    /// R3 (REVIEW-2 #9): SessionOptions.freeFirstSting has been spent.
    private var freeStingUsed: Bool = false
    private var score: Int = 0
    private var chain: Int = 0
    private var lastInput: TrapInput = TrapInput()
    private var prevClosure: Double = 0
    /// R8: the session time of the previous step's input (for the closure crossings).
    private var prevTime: Double = 0
    /// R8 (ROUND-8 §1): a close is under way (closure passed Tuning.closeStart while armed, or a bite arrived).
    private var closing: Bool = false
    private var closeStartAt: Double = 0
    /// R8: the catchable bugs in the trap at any moment of the current close (the catch ratio's denominator).
    private var closeBugs: Set<Int> = []
    /// R8: bugs that fled the current close before the shut (they count as escaped in its bite).
    private var fled: Int = 0
    /// R8: shut = digesting, from a bite until the input is armed again (TrapSnapshot.shut). The clock is frozen.
    private var shut: Bool = false
    /// R8: wall seconds stepped while shut (the "Open it again" hint).
    private var shutElapsed: Double = 0
    /// R8 (founder rule 3): every round starts closed (TrapSnapshot.waitingForClose).
    private var waitingForClose: Bool = true
    private var lastBite: BiteReport? = nil
    private var lastBiteTime: Double = 0
    private var newBestSent: Bool = false
    private var out: [TrapEvent] = []

    // Run stats
    private var snapsMade: Int = 0
    private var bugsCaught: Int = 0
    private var caughtBySpecies: [String: Int] = [:]
    private var sparedBySpecies: [String: Int] = [:]
    private var bestBitePoints: Int = 0
    private var biggestBite: Int = 0
    private var longestChain: Int = 0
    private var beesSpared: Int = 0
    private var stings: Int = 0
    private var feasts: Int = 0
    private var drySnaps: Int = 0
    private var fastestSnap: Double = 0
    /// R8: bugs that escaped a bite or fled a close (RunResult.escapes).
    private var escapesTotal: Int = 0
    /// R8: seconds a level has had nothing left to catch.
    private var levelIdle: Double = 0

    private(set) var result: RunResult? = nil

    /// R7 (SCORE-R6 #4): rects where no bug may rest, in the session's own coordinates (scene space: the
    /// geometry.sceneSize the session was built with, the space of SpawnSpec, BugState.position and NectarDrop; y = 0
    /// is the bottom edge, the walkers' edge). The Scene sets it from its hudKeepOut (HUD rects, Home buttons, edges);
    /// empty (the default) changes nothing. Every resting spot (a landing, a wander, walk, hop or dart target, a sip
    /// at a nectar drop, a bog sitter's perch) keeps its centre TrapRules.keepOutClearance(radius:protected:) from
    /// every rect: spots are pushed out across the nearest edge (as offCrease pushes them off the midrib), and drops
    /// that are too close are never picked. Set it before the bugs arrive (a change applies to the next spot chosen).
    var keepOut: [CGRect] = []

    init(mode: RunMode, seed: UInt64, best: Int, geometry: TrapGeometry, options: SessionOptions) {
        self.mode = mode
        self.seed = seed
        self.best = best
        self.geometry = geometry
        self.options = options
        let perks: SproutPerks? = options.sproutPerks(for: mode)
        self.sproutPerks = perks
        self.firstRunPerks = perks?.run == 1
        let first: Int = max(1, options.firstWave)
        self.wave = first - 1
        self.dayPhase = WaveFactory.phase(forWave: first)
        self.nectarBlock = (first - 1) / Tuning.nectarReseedWaves
        let start: Int = perks?.startSnaps ?? (options.startSnaps ?? Tuning.startSnaps)
        self.snapsLeft = min(max(start, 1), Tuning.maxSnaps)
        // R8 (ROUND-8 §4): a level: its pace wave and scripted bugs (session time 0 is the round's opening).
        var spec: LevelSpec? = nil
        if case .level(let id) = mode { spec = LevelBook.level(id) }
        self.levelSpec = spec
        installNectar(block: nectarBlock)
        bugs.reserveCapacity(Tuning.maxBugsOnScreen)
        if let l = spec {
            wave = l.paceWave
            dayPhase = WaveFactory.phase(forWave: l.paceWave)
            for b in l.bugs {
                pending.append(PendingSpawn(at: b.at, spec: LevelBook.spawnSpec(b, geometry: geometry, nectar: nectar)))
            }
        }
    }

    // MARK: Public state

    var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    private var isPlaying: Bool {
        if case .playing = phase { return true }
        return false
    }

    /// R2: does this run wilt (feed and daily; never the lesson or attract)? R4: never a first run either. R5: never
    /// a taper run with noWilt (run 1).
    private var wilts: Bool {
        return options.snapsRunOut && options.hunger && !(sproutPerks?.noWilt ?? false)
    }

    /// R4: is the first stinger bite free (SessionOptions.freeFirstSting, or a first run)? R5: or Sprout run 2.
    private var freeSting: Bool {
        return options.freeFirstSting || (sproutPerks?.freeSting ?? false)
    }

    /// R6 (#19, REVIEW-5 P2-5): the last light applies to this run (Feed or the Daily with wilting on; never Zen,
    /// attract or the lesson).
    private var lastLightApplies: Bool {
        return wilts && TrapRules.lastLightApplies(to: mode)
    }

    /// R6: the run is in the last light (wave ≥ Tuning.lastLightWave): the hunger clock ticks whatever is in the trap.
    var inLastLight: Bool {
        return lastLightApplies && wave >= Tuning.lastLightWave
    }

    /// R4/R5: the calm morning (Sprout runs 1–3).
    private var calmMorning: Bool {
        return sproutPerks?.calmMorning ?? false
    }

    /// R2: seconds without a catching bite before a snap wilts, in this day phase.
    static func wiltSeconds(_ ph: DayPhase) -> Double {
        switch ph {
        case .morning: return Tuning.wiltMorning
        case .noon: return Tuning.wiltNoon
        case .dusk: return Tuning.wiltDusk
        case .night: return Tuning.wiltNight
        }
    }

    var snapshot: TrapSnapshot {
        var states: [BugState] = []
        states.reserveCapacity(bugs.count)
        for b in bugs {
            let a: BugActivity = activity(of: b)
            let inT: Bool = inTrap(b)
            states.append(BugState(id: b.id, species: b.species, position: b.point, heading: b.heading, activity: a,
                                   height: b.height, sipProgress: b.mode == .sip ? b.sip : 0, inTrap: inT,
                                   onRim: inT && TrapRules.onRim(geometry, b.point, radius: b.info.radius),
                                   restless: b.restless))
        }
        var drops: [NectarDrop] = nectar
        var k: Int = 0
        while k < drops.count {
            var occ: Int? = nil
            for b in bugs where b.mode == .sip && b.dropID == drops[k].id { occ = b.id }
            drops[k].occupant = occ
            k += 1
        }
        return TrapSnapshot(phase: phase, mode: mode, time: time, bugs: states, nectar: drops,
                            closure: lastInput.closure, armed: lastInput.armed, creeping: lastInput.creeping,
                            snapsLeft: snapsLeft, snapsMax: Tuning.maxSnaps, score: score, best: best, chain: chain,
                            chainMultiplier: TrapRules.chainMultiplier(chain), wave: wave, dayPhase: dayPhase,
                            dayClock: dayClock, lastBite: lastBite, hint: currentHint(), bugsCaught: bugsCaught,
                            beesSpared: beesSpared, hunger: wilts ? hunger : 0, shut: shut,
                            waitingForClose: waitingForClose)
    }

    /// The continuous feedback state for this frame.
    var telemetry: TrapTelemetry {
        var buzzers: [Buzzer] = []
        let half: Double = max(1, Double(geometry.sceneSize.width) / 2)
        let cx: Double = Double(geometry.center.x)
        for b in bugs where b.mode != .caught {
            let pan: Double = min(max((b.x - cx) / half, -1), 1)
            var flying: Bool
            switch b.mode {
            case .approach: flying = b.motion.style != .walker
            case .hover, .cross, .hop, .escape, .release: flying = true
            case .leave: flying = b.motion.style != .walker
            case .pause: flying = b.hovering
            case .sip, .dash, .caught: flying = false
            }
            if b.motion.style == .walker { flying = false }
            buzzers.append(Buzzer(id: b.id, species: b.species, pan: pan, height: b.height, flying: flying))
        }
        return TrapTelemetry(closure: lastInput.closure, creeping: lastInput.creeping, buzzers: buzzers, chain: chain,
                             dayClock: dayClock, playing: isPlaying)
    }

    /// 0 … 4 through the day: 0 morning (wave 1), 1 noon (7), 2 dusk (15), 3 night (23), 4 deep night (31+).
    var dayClock: Double {
        if wave <= 0 { return 0 }
        let gap: Double = nextWaveAt - lastWaveAt
        let frac: Double = gap > 0 ? min(max((time - lastWaveAt) / gap, 0), 1) : 0
        let idx: Int = recipeIndex(wave)
        let w: Double = Double(idx) + (options.waves ? frac : 0)
        let noon: Double = Double(Tuning.noonWave)
        let dusk: Double = Double(Tuning.duskWave)
        let night: Double = Double(Tuning.nightWave)
        let deep: Double = Double(Tuning.deepNightWave)
        if w < noon { return max(0, (w - 1) / (noon - 1)) }
        if w < dusk { return 1 + (w - noon) / (dusk - noon) }
        if w < night { return 2 + (w - dusk) / (night - dusk) }
        return min(4, 3 + (w - night) / (deep - night))
    }

    /// The result so far (an abandoned run). Once finished, exactly `result`.
    func partialResult() -> RunResult {
        if let r = result { return r }
        return makeResult(seconds: time)
    }

    // MARK: Stepping

    /// One frame. Returns this step's events in order.
    func step(dt: Double, input: TrapInput) -> [TrapEvent] {
        if isFinished { return [] }
        // `out` may already hold events from spawnScripted calls made between steps: they come first.
        let d: Double = dt.isFinite ? max(0, dt) : 0
        var inp: TrapInput = input
        if !inp.closure.isFinite { inp.closure = 0 }
        inp.closure = max(0, inp.closure)
        inp.tooFlat = false
        lastInput = inp
        if isPlaying {
            // R8 (founder rule 3): the round starts once the input is first armed (a bite counts too).
            if waitingForClose && (inp.armed || inp.snap != nil) { waitingForClose = false }
            fear(inp)
        }
        if isPlaying, let s = inp.snap {
            bite(s, hinge: inp.angle != nil, armedAfter: inp.armed)
        } else if shut && inp.armed {
            // R8: reopened: the shut is over and the clock runs again.
            shut = false
            shutElapsed = 0
            out.append(.rearmed)
        }
        prevClosure = inp.closure
        prevTime = time
        let n: Int = max(1, Int((d / Tuning.maxSubstep - 1e-9).rounded(.up)))
        let h: Double = d / Double(n)
        var i: Int = 0
        while i < n {
            tick(h)
            if isFinished { break }
            i += 1
        }
        let events: [TrapEvent] = out
        out = []
        return events
    }

    /// The lesson: put one bug in now (it flies in from `entry` and lands on `target`). `linger` .infinity = stays.
    /// A target on a free nectar drop's position (snapshot.nectar) makes it sip there. Returns its id (−1 if the
    /// screen is full).
    @discardableResult
    func spawnScripted(_ species: BugSpecies, entry: CGPoint, target: CGPoint, linger: Double) -> Int {
        let l: Double = linger.isNaN ? 0 : max(0, linger)
        let spec = SpawnSpec(species: species, entry: entry, target: target, linger: l, landsInTrap: true,
                             groupOffset: 0)
        return spawn(spec)
    }

    private func tick(_ h: Double) {
        if isPlaying && (shut || waitingForClose) {
            // R8: shut = digesting, and a round waiting for its first close: the clock is frozen (no waves, spawns,
            // lingers or hunger). Bugs already caught, escaping, released or leaving finish their moves.
            if shut { shutElapsed += h }
            for b in bugs {
                switch b.mode {
                case .caught, .leave, .escape, .release: updateBug(b, h)
                case .approach, .hover, .sip, .pause, .dash, .hop, .cross: break
                }
            }
            bugs.removeAll { (b: Bug) -> Bool in b.gone }
            return
        }
        time += h
        if isPlaying && options.waves {
            while time >= nextWaveAt { startWave() }
        }
        if isPlaying && !pending.isEmpty {
            var keep: [PendingSpawn] = []
            for p in pending {
                if p.at <= time { _ = spawn(p.spec) } else { keep.append(p) }
            }
            pending = keep
        }
        for b in bugs { updateBug(b, h) }
        bugs.removeAll { (b: Bug) -> Bool in b.gone }
        // R4 (QA-2 #1): the clock ticks only while there is food in the trap and no bee in it. R6 (#19): in the last
        // light it ticks whatever is in the trap, so a patient hand's run ends too.
        hungerLive = isPlaying && wilts && (inLastLight || hungerTicks())
        if hungerLive { tickHunger(h) }
        if levelSpec != nil && isPlaying { checkLevel(h) }
        if case .tired(let e) = phase {
            let ne: Double = e + h
            if ne >= Tuning.tiredSeconds {
                phase = .finished
                let r: RunResult = makeResult(seconds: tiredAt)
                result = r
                out.append(.finished)
            } else {
                phase = .tired(elapsed: ne)
            }
        }
    }

    /// R2 hunger (GAME-DESIGN §5): no catching bite for the phase's wilt time wilts one snap and restarts the timer;
    /// `hungry` fires once per cycle Tuning.hungryWarning s before. A wilt can tire the trap. R4: only called while
    /// hungerTicks(); a pause keeps the level (only a catch resets it), and after a wilt it goes on while food sits.
    private func tickHunger(_ h: Double) {
        let w: Double = TrapSession.wiltSeconds(dayPhase)
        hunger += h / w
        if !hungrySent && (1 - hunger) * w <= Tuning.hungryWarning {
            hungrySent = true
            out.append(.hungry(secondsLeft: max(0, (1 - hunger) * w)))
        }
        if hunger >= 1 {
            hunger = 0
            hungrySent = false
            let before: Int = snapsLeft
            snapsLeft = max(snapsLeft - 1, 0)
            out.append(.wilted(snapsLeft: snapsLeft))
            if snapsLeft == 1 && before != 1 { out.append(.lastSnap) }
            if snapsLeft == 0 { becomeTired() }
        }
    }

    /// R4 (QA-2 #1, REVIEW-3 #12, founder call): at least one catchable bug has landed in the trap (and is still in
    /// it: not leaving, escaping, released or caught) and no protected bug is in it.
    /// R5 (REVIEW-4 #5, founder call): a protected bug counts as in the trap from its final approach: inside the zone
    /// and landed, or below Tuning.creaseAirHeight (its hover down, with the halo drawn). Higher arrivals don't count,
    /// so the deep night's always-arriving bees still leave the clock running.
    private func hungerTicks() -> Bool {
        var food: Bool = false
        for b in bugs where inTrap(b) {
            if b.species.isProtected {
                if TrapSession.protectedCountsAsIn(landed: b.landed, height: b.height) { return false }
            } else if b.landed {
                food = true
            }
        }
        return food
    }

    /// R5 (REVIEW-4 #5): a protected bug inside the zone pauses the hunger clock once it has landed or is lower than
    /// Tuning.creaseAirHeight (its final approach). Pure; tested.
    static func protectedCountsAsIn(landed: Bool, height: Double) -> Bool {
        return landed || height < Tuning.creaseAirHeight
    }

    /// Snaps reached 0: "Your trap is tired." Every bug still about takes off.
    private func becomeTired() {
        if levelSpec != nil && levelEnd == nil { levelEnd = .bites }
        out.append(.tired)
        phase = .tired(elapsed: 0)
        tiredAt = time
        pending = []
        for b in bugs {
            switch b.mode {
            case .caught, .leave, .escape, .release: continue
            case .approach, .hover, .sip, .pause, .dash, .hop, .cross: takeOff(b, .leave)
            }
        }
    }

    private func recipeIndex(_ idx: Int) -> Int {
        switch mode {
        case .attract: return ((idx - 1) % Tuning.attractDayWaves) + 1
        // R6: the Zen Bog's day loops too (morning … night, then morning again).
        case .zen: return ((idx - 1) % Tuning.zenDayWaves) + 1
        case .feed, .daily, .lesson, .level: return idx
        }
    }

    private func startWave() {
        wave += 1
        let idx: Int = wave
        let block: Int = (idx - 1) / Tuning.nectarReseedWaves
        if block != nectarBlock {
            nectarBlock = block
            installNectar(block: block)
        }
        let recipe: Int = recipeIndex(idx)
        let spec: WaveSpec = WaveFactory.wave(seed: seed, index: recipe, geometry: geometry, nectar: nectar,
                                              calm: calmMorning)
        out.append(.waveStarted(index: idx, phase: spec.phase))
        if spec.phase != dayPhase {
            dayPhase = spec.phase
            out.append(.dayPhaseChanged(spec.phase))
        }
        let at: Double = nextWaveAt
        for s in spec.bugs { pending.append(PendingSpawn(at: at + s.groupOffset, spec: s)) }
        lastWaveAt = at
        var gap: Double = WaveFactory.delay(seed: seed, index: recipe + 1)
        // R4 (REVIEW-3 #11): a first run's calm morning. R5 (REVIEW-4 #8): Sprout runs 1–3.
        if calmMorning && idx <= Tuning.firstRunCalmWaves { gap *= Tuning.firstRunWaveGap }
        nextWaveAt = at + gap
    }

    // MARK: Nectar

    private func installNectar(block: Int) {
        let drops: [NectarDrop] = WaveFactory.nectar(seed: WaveFactory.nectarSeed(seed: seed, block: block),
                                                     geometry: geometry)
        let kept: [NectarDrop] = nectar.filter { (d: NectarDrop) -> Bool in reservedBy[d.id] != nil }
        for d in kept { retiring.insert(d.id) }
        var fresh: [NectarDrop] = []
        for d in drops {
            var clash: Bool = false
            for k in kept {
                if hypot(Double(k.position.x - d.position.x), Double(k.position.y - d.position.y))
                    < Tuning.nectarKeptClearance { clash = true }
            }
            if clash { continue }
            fresh.append(NectarDrop(id: nextDropID, position: d.position, radius: d.radius))
            nextDropID += 1
        }
        nectar = kept + fresh
    }

    private func freeDrop(_ b: Bug) {
        guard let id = b.dropID else { return }
        b.dropID = nil
        if reservedBy[id] == b.id { reservedBy[id] = nil }
        if retiring.contains(id) && reservedBy[id] == nil {
            retiring.remove(id)
            nectar.removeAll { (d: NectarDrop) -> Bool in d.id == id }
        }
    }

    private func dropAt(_ p: CGPoint) -> NectarDrop? {
        for d in nectar where !retiring.contains(d.id) {
            if abs(Double(d.position.x - p.x)) < 1.5 && abs(Double(d.position.y - p.y)) < 1.5 { return d }
        }
        return nil
    }

    private func isAtDrop(_ b: Bug) -> Bool {
        guard let id = b.dropID else { return false }
        for d in nectar where d.id == id {
            return hypot(Double(d.position.x) - b.x, Double(d.position.y) - b.y) <= 2
        }
        return false
    }

    // MARK: Spawning and spacing

    private func bugSeed(_ id: Int) -> UInt64 {
        return seed ^ (UInt64(truncatingIfNeeded: id) &* 0xA24B_AED4_963E_E407) ^ 0x4255_4753
    }

    private func spawn(_ spec: SpawnSpec) -> Int {
        if bugs.count >= Tuning.maxBugsOnScreen { return -1 }
        let id: Int = nextID
        nextID += 1
        let b = Bug(id: id, spec: spec, seed: bugSeed(id))
        let m: BugMotion = b.motion
        b.wobblePhase = b.rng.between(0, 2 * Double.pi)
        let bend: Double = b.rng.between(-Tuning.arcBend, Tuning.arcBend)
        if !spec.landsInTrap && !geometry.contains(spec.target) && spec.linger == 0 {
            b.mode = .cross
        } else if spec.landsInTrap {
            let d: NectarDrop? = m.nectarChance > 0 ? dropAt(spec.target) : nil
            // R7 (#4): a drop too close to a keep-out rect is never sipped; the bug lands near it instead.
            if let drop = d, reservedBy[drop.id] == nil, !keptOut(Double(drop.position.x), Double(drop.position.y), b) {
                reservedBy[drop.id] = id
                b.dropID = drop.id
                b.wantsNectar = true
            } else {
                if d != nil { b.wantsNectar = true }
                let spot: (Double, Double) = findSpot(b, Double(spec.target.x), Double(spec.target.y),
                                                      d != nil ? 30 : 0, d != nil ? 70 : 40, Tuning.landMaxRadius)
                b.tx = spot.0
                b.ty = spot.1
            }
            b.homeX = b.tx
            b.homeY = b.ty
            // R4 (REVIEW-3 #14): a walker walks in on its spot's side of the crease (it never crosses it on foot).
            if m.style == .walker {
                let sd: Double = sideOf(b.tx)
                let gap: Double = TrapRules.creaseGap(radius: b.info.radius)
                let cx: Double = Double(geometry.center.x)
                if (b.fx - cx) * sd < gap {
                    b.fx = cx + sd * max(abs(b.fx - cx), gap)
                    b.x = b.fx
                }
            }
        }
        let dx: Double = b.tx - b.fx
        let dy: Double = b.ty - b.fy
        let dist: Double = hypot(dx, dy)
        b.cx = (b.fx + b.tx) / 2 - dy * bend
        b.cy = (b.fy + b.ty) / 2 + dx * bend
        if m.style == .walker {
            b.mode = .dash
            b.dur = max(0.1, dist / m.walkSpeed)
        } else {
            b.dur = max(Tuning.minFlightTime, dist * Tuning.approachPathFactor / m.speed)
        }
        b.heading = atan2(dy, dx)
        bugs.append(b)
        out.append(.bugArrived(id: id, species: spec.species))
        return id
    }

    private func spotOf(_ o: Bug) -> (Double, Double)? {
        switch o.mode {
        case .approach, .hover, .dash, .hop: return (o.tx, o.ty)
        case .sip, .pause: return (o.x, o.y)
        case .cross, .leave, .escape, .release, .caught: return nil
        }
    }

    private func spotScore(_ b: Bug, _ px: Double, _ py: Double) -> Double {
        var worst: Double = Double.infinity
        for o in bugs {
            if o.id == b.id || !o.landsInTrap { continue }
            guard let q = spotOf(o) else { continue }
            let need: Double = Double(b.info.radius + o.info.radius) + Tuning.landSpacing
            worst = min(worst, hypot(q.0 - px, q.1 - py) - need)
        }
        // R7 (#4): a spot too close to a keep-out rect loses to any spot clear of them all.
        if keptOut(px, py, b) { return min(worst, 0) - 1e6 }
        return worst
    }

    // MARK: Keep-out (R7, SCORE-R6 #4)

    /// R7: is (x, y) too close to a keep-out rect for this bug to rest there?
    private func keptOut(_ x: Double, _ y: Double, _ b: Bug) -> Bool {
        if keepOut.isEmpty { return false }
        let c: Double = TrapRules.keepOutClearance(radius: b.info.radius, protected: b.species.isProtected)
        return TrapRules.touchesKeepOut(keepOut, x, y, clearance: c)
    }

    /// R7: (x, y) moved out of the keep-out rects, the way offCrease moves a spot off the midrib: straight out across
    /// the nearest edge of the rect it touches, to the bug's clearance beyond it. A candidate must be clear of every
    /// rect and, in the trap (`maxR` non-nil), inside `maxR`, off the crease (TrapRules.creaseGap) and on `side`
    /// (±1; 0 any); outside it (a bog sitter's perch), inside the scene. The nearest such candidate wins; with none,
    /// (x, y) comes back unchanged and spotScore rejects it. No random draws, so an empty keepOut changes nothing.
    private func pushedOut(_ x: Double, _ y: Double, _ b: Bug, maxR: Double?, side: Double) -> (Double, Double) {
        if !keptOut(x, y, b) { return (x, y) }
        let c: Double = TrapRules.keepOutClearance(radius: b.info.radius, protected: b.species.isProtected) + 0.01
        let w: Double = Double(geometry.sceneSize.width)
        let h: Double = Double(geometry.sceneSize.height)
        let cx: Double = Double(geometry.center.x)
        let gap: Double = TrapRules.creaseGap(radius: b.info.radius)
        var found: (Double, Double)? = nil
        var foundD: Double = Double.infinity
        for raw in keepOut where !raw.isNull {
            let r: CGRect = raw.standardized
            if !TrapRules.touchesKeepOut([r], x, y, clearance: c - 0.01) { continue }
            let cands: [(Double, Double)] = [(Double(r.minX) - c, y), (Double(r.maxX) + c, y),
                                             (x, Double(r.minY) - c), (x, Double(r.maxY) + c)]
            for q in cands {
                if keptOut(q.0, q.1, b) { continue }
                if let lim = maxR {
                    if geometry.normalizedRadius(CGPoint(x: q.0, y: q.1)) > lim + 1e-9 { continue }
                    if abs(q.0 - cx) < gap - 1e-9 { continue }
                    if side != 0 && sideOf(q.0) != side { continue }
                } else if q.0 < 0 || q.0 > w || q.1 < 0 || q.1 > h {
                    continue
                }
                let d: Double = hypot(q.0 - x, q.1 - y)
                if d < foundD {
                    foundD = d
                    found = q
                }
            }
        }
        return found ?? (x, y)
    }

    /// R4: +1 right of the midrib line (or on it), −1 left.
    private func sideOf(_ x: Double) -> Double {
        return x >= Double(geometry.center.x) ? 1 : -1
    }

    /// Inside `maxR`, then (R3, REVIEW-2 #5) off the crease by TrapRules.creaseGap(radius:). R4 (REVIEW-3 #14): a
    /// `side` of ±1 keeps the spot on that lobe (a point across the line is mirrored back first); 0 leaves it free.
    private func clampIn(_ px0: Double, _ py: Double, _ maxR: Double, _ radius: CGFloat,
                         _ side: Double) -> (Double, Double) {
        let cx0: Double = Double(geometry.center.x)
        let px: Double = side != 0 && (px0 - cx0) * side < 0 ? 2 * cx0 - px0 : px0
        let r: Double = geometry.normalizedRadius(CGPoint(x: px, y: py))
        var qx: Double = px
        var qy: Double = py
        if r > maxR && r != 0 {
            let k: Double = maxR / r
            let cx: Double = Double(geometry.center.x)
            let cy: Double = Double(geometry.center.y)
            qx = cx + (px - cx) * k
            qy = cy + (py - cy) * k
        }
        return TrapRules.offCrease(geometry, qx, qy, maxR: maxR, radius: radius, side: side)
    }

    /// R7 (#4): clampIn (inside `maxR`, off the crease), then out of the keep-out rects (pushedOut).
    private func clampClear(_ b: Bug, _ x: Double, _ y: Double, _ maxR: Double, _ side: Double) -> (Double, Double) {
        let p: (Double, Double) = clampIn(x, y, maxR, b.info.radius, side)
        if keepOut.isEmpty { return p }
        let sd: Double = side != 0 ? side : sideOf(p.0)
        return pushedOut(p.0, p.1, b, maxR: maxR, side: sd)
    }

    /// A spot near (x, y), `dMin`…`dMax` away, inside `maxR` and off the crease, as clear of the other bugs as it can
    /// find. Every resting spot (landing, wander, hop, dart) comes from here or is a nectar drop. R4: `side` ±1 keeps
    /// it on that lobe (ground moves and the hover), 0 leaves it free (a spawn's spot: it flies in).
    private func findSpot(_ b: Bug, _ x: Double, _ y: Double, _ dMin: Double, _ dMax: Double,
                          _ maxR: Double, side: Double = 0) -> (Double, Double) {
        var best: (Double, Double) = clampClear(b, x, y, maxR, side)
        var bestScore: Double = dMin <= 0 ? spotScore(b, best.0, best.1) : -Double.infinity
        if bestScore >= 0 { return best }
        var i: Int = 0
        while i < Tuning.spotTries {
            let t: Double = b.rng.between(0, 2 * Double.pi)
            // R2: the search reaches at least this bug's own spacing need (radii are ×1.8).
            let reach: Double = Double(b.info.radius) * 2 + Tuning.landSpacing + 10
            let dd: Double = b.rng.between(max(dMin, 8), max(dMax, 20, reach))
            let p: (Double, Double) = clampClear(b, x + cos(t) * dd, y + sin(t) * dd, maxR, side)
            let s: Double = spotScore(b, p.0, p.1)
            if s > bestScore {
                bestScore = s
                best = p
            }
            if s >= 0 { break }
            i += 1
        }
        return best
    }

    // MARK: Activity

    private func activity(of b: Bug) -> BugActivity {
        switch b.mode {
        case .approach: return b.motion.style == .walker ? .walking : .arriving
        case .hover, .cross: return .arriving
        case .sip: return .sipping
        case .pause: return b.hovering ? .arriving : .walking
        case .dash: return .walking
        case .hop: return .hopping
        case .leave: return b.motion.style == .walker ? .walking : .leaving
        case .escape: return .escaped
        case .release: return .released
        case .caught: return .caught(elapsed: b.el)
        }
    }

    private func inTrap(_ b: Bug) -> Bool {
        switch activity(of: b) {
        case .leaving, .caught, .escaped, .released: return false
        case .arriving, .walking, .sipping, .hopping: return geometry.contains(b.point)
        }
    }

    // MARK: Movement

    private func updateBug(_ b: Bug, _ h: Double) {
        b.age += h
        let px: Double = b.x
        let py: Double = b.y
        let m: BugMotion = b.motion
        switch b.mode {
        case .approach, .cross:
            b.el += h
            let u: Double = min(1, b.el / b.dur)
            let s: Double = 1 - (1 - u) * (1 - u)
            let bx: Double = (1 - s) * (1 - s) * b.fx + 2 * (1 - s) * s * b.cx + s * s * b.tx
            let by: Double = (1 - s) * (1 - s) * b.fy + 2 * (1 - s) * s * b.cy + s * s * b.ty
            let dx: Double = b.tx - b.fx
            let dy: Double = b.ty - b.fy
            let len: Double = max(1, hypot(dx, dy))
            let w: Double = m.wobbleAmp * sin(2 * Double.pi * m.wobbleHz * b.age + b.wobblePhase) * (1 - s)
            b.x = bx + (-dy / len) * w
            b.y = by + (dx / len) * w
            if b.mode == .cross {
                b.height = Tuning.crossHeight
            } else if m.style == .walker {
                b.height = 0
            } else {
                b.height = 1 - Tuning.approachHeightDrop * s * s
            }
            if u >= 1 {
                if b.mode == .cross {
                    b.gone = true
                    out.append(.bugLeft(id: b.id, species: b.species))
                } else if m.style == .walker {
                    land(b)
                } else {
                    let sp: (Double, Double) = landingSpot(b)
                    b.tx = sp.0
                    b.ty = sp.1
                    b.mode = .hover
                    b.el = 0
                    b.dur = b.rng.between(Tuning.hoverMin, Tuning.hoverMax)
                    b.fx = b.x
                    b.fy = b.y
                }
            }
        case .hover:
            b.el += h
            let v: Double = min(1, b.el / b.dur)
            let om: Double = 2 * Double.pi * 1.5 * b.age
            let ex: Double = b.fx + (b.tx - b.fx) * v
            let ey: Double = b.fy + (b.ty - b.fy) * v
            b.x = ex + cos(om) * Tuning.hoverCircle * (1 - v)
            b.y = ey + sin(om) * Tuning.hoverCircle * (1 - v)
            b.height = Tuning.hoverHeight * (1 - v)
            if v >= 1 { land(b) }
        case .sip:
            tickLinger(b, h)
            if b.mode == .sip {
                b.sip = (b.lingerTotal.isFinite && b.lingerTotal > 0) ? min(1, 1 - b.linger / b.lingerTotal) : 0
            }
        case .pause:
            tickLinger(b, h)
            if b.mode == .pause {
                b.timer -= h
                if b.timer <= 0 { nextGroundMove(b) }
            }
        case .dash:
            var still: Bool = true
            if b.landed {
                tickLinger(b, h)
                still = b.mode == .dash
            }
            if still {
                b.el += h
                let u: Double = min(1, b.el / b.dur)
                let e: Double = b.landed ? u * u * (3 - 2 * u) : u
                let dx: Double = b.tx - b.fx
                let dy: Double = b.ty - b.fy
                let len: Double = max(1, hypot(dx, dy))
                let w: Double = m.style == .walker
                    ? m.wobbleAmp * sin(2 * Double.pi * m.wobbleHz * b.age + b.wobblePhase) : 0
                b.x = b.fx + dx * e + (-dy / len) * w
                b.y = b.fy + dy * e + (dx / len) * w
                b.height = 0
                if u >= 1 {
                    if !b.landed {
                        land(b)
                    } else if let id = b.dropID, reservedBy[id] == b.id, isAtDrop(b) {
                        startSip(b)
                    } else {
                        startPause(b)
                    }
                }
            }
        case .hop:
            tickLinger(b, h)
            if b.mode == .hop {
                b.el += h
                let u: Double = min(1, b.el / b.dur)
                b.x = b.fx + (b.tx - b.fx) * u
                b.y = b.fy + (b.ty - b.fy) * u
                b.height = m.style == .darter ? Tuning.dartHeight : Tuning.hopHeight * sin(Double.pi * u)
                if u >= 1 {
                    b.height = m.style == .darter ? Tuning.dartHeight : 0
                    startPause(b)
                }
            }
        case .leave, .escape, .release:
            b.el += h
            let walker: Bool = m.style == .walker
            var factor: Double = Tuning.releaseSpeedFactor
            if b.mode == .leave {
                factor = Tuning.leaveSpeedFactor
            } else if b.mode == .escape {
                factor = walker ? Tuning.walkerEscapeFactor : Tuning.escapeSpeedFactor
            }
            let speed: Double = (walker ? m.walkSpeed : m.speed) * factor
            let ramp: Double = walker ? 1 : min(1, 0.3 + b.el / Tuning.takeoffTime)
            let dx: Double = b.tx - b.fx
            let dy: Double = b.ty - b.fy
            let len: Double = max(1, hypot(dx, dy))
            b.travelled += speed * ramp * h
            let tr: Double = min(b.travelled, len)
            let w: Double = walker ? 0
                : m.wobbleAmp * 0.5 * sin(2 * Double.pi * m.wobbleHz * b.age + b.wobblePhase)
                    * min(1, b.el / Tuning.takeoffTime)
            b.x = b.fx + dx / len * tr + (-dy / len) * w
            b.y = b.fy + dy / len * tr + (dx / len) * w
            b.height = walker ? 0 : min(1, b.startHeight + b.el / Tuning.takeoffTime * (1 - b.startHeight))
            if b.travelled >= len || offscreen(b) {
                b.gone = true
                if b.mode == .leave && !b.spooked { out.append(.bugLeft(id: b.id, species: b.species)) }
            }
        case .caught:
            b.el += h
            let u: Double = min(1, b.el / Tuning.caughtSeconds)
            let e: Double = u * u * (3 - 2 * u)
            b.x = b.fx + (Double(geometry.center.x) - b.fx) * e
            b.y = b.fy
            // R2 (QA-1 #21): eases down from the height it was caught at (a hopper caught mid-hop no longer drops).
            b.height = b.startHeight * (1 - e)
            if b.el >= Tuning.caughtSeconds { b.gone = true }
        }
        let mx: Double = b.x - px
        let my: Double = b.y - py
        if mx * mx + my * my > 0.01 && b.mode != .caught { b.heading = atan2(my, mx) }
    }

    private func offscreen(_ b: Bug) -> Bool {
        let w: Double = Double(geometry.sceneSize.width)
        let h: Double = Double(geometry.sceneSize.height)
        let m: Double = Tuning.exitMargin + 20
        return b.x < -m || b.x > w + m || b.y < -m || b.y > h + m
    }

    /// Re-checks the spacing just before landing (others may have landed since the spawn).
    private func landingSpot(_ b: Bug) -> (Double, Double) {
        // R7 (#4): a bog sitter's perch (outside the trap) is pushed out of the keep-out rects too.
        if !b.landsInTrap { return pushedOut(b.tx, b.ty, b, maxR: nil, side: 0) }
        if b.dropID != nil {
            if !keptOut(b.tx, b.ty, b) { return (b.tx, b.ty) }
            // R7: keepOut was set after this drop was reserved: let it go and land near it instead.
            freeDrop(b)
        }
        if spotScore(b, b.tx, b.ty) >= 0 { return (b.tx, b.ty) }
        // R4: the hover never drifts low across the crease.
        return findSpot(b, b.tx, b.ty, 0, 50, Tuning.landMaxRadius, side: sideOf(b.tx))
    }

    private func tickLinger(_ b: Bug, _ h: Double) {
        if b.linger.isFinite {
            b.linger -= h
            let f: Double = b.lingerTotal > 0 ? 1 - b.linger / b.lingerTotal : 1
            let tell: Double = min(max((f - Tuning.restlessFrom) / (1 - Tuning.restlessFrom), 0), 1)
            b.restless = max(b.restless * exp(-3 * h), tell)
            if b.linger <= 0 { takeOff(b, .leave) }
        } else {
            b.restless = b.restless * exp(-3 * h)
        }
    }

    private func land(_ b: Bug) {
        b.landed = true
        b.height = 0
        b.el = 0
        b.landedInTrap = b.landsInTrap && geometry.contains(b.point)
        out.append(.bugLanded(id: b.id, species: b.species, position: b.point, inTrap: b.landedInTrap))
        if !b.landsInTrap || b.motion.style == .darter {
            startPause(b)
            return
        }
        if b.dropID != nil && isAtDrop(b) {
            startSip(b)
            return
        }
        startPause(b)
    }

    private func startSip(_ b: Bug) {
        b.mode = .sip
        b.hovering = false
        b.height = 0
        out.append(.bugSipping(id: b.id, species: b.species))
    }

    private func startPause(_ b: Bug) {
        b.mode = .pause
        b.el = 0
        b.timer = b.rng.between(b.motion.pauseMin, b.motion.pauseMax)
        b.hovering = b.motion.style == .darter && b.rng.chance(Tuning.darterHoverChance)
        b.height = b.hovering ? Tuning.dartHeight : 0
    }

    private func nextGroundMove(_ b: Bug) {
        if !b.landsInTrap {
            startPause(b)
            return
        }
        let st: BugStyle = b.motion.style
        if st == .hopper || st == .darter {
            let darter: Bool = st == .darter
            let t: Double = b.rng.between(0, 2 * Double.pi)
            let dd: Double = darter ? b.rng.between(Tuning.dartMin, Tuning.dartMax)
                                    : b.rng.between(Tuning.hopMin, Tuning.hopMax)
            let wantX: Double = b.x + cos(t) * dd
            let wantY: Double = b.y + sin(t) * dd
            // R4: hops and darts stay on the bug's own lobe.
            let p: (Double, Double) = findSpot(b, wantX, wantY, 0, 40, Tuning.landMaxRadius, side: sideOf(b.x))
            b.mode = .hop
            b.fx = b.x
            b.fy = b.y
            b.tx = p.0
            b.ty = p.1
            b.el = 0
            b.hovering = false
            let dist: Double = hypot(p.0 - b.x, p.1 - b.y)
            b.dur = darter ? Tuning.dartTime : min(max(dist / Tuning.hopSpeed, Tuning.hopTimeMin), Tuning.hopTimeMax)
            out.append(.bugHopped(id: b.id, species: b.species))
            return
        }
        if b.wantsNectar && b.dropID == nil {
            var best: NectarDrop? = nil
            var bd: Double = Tuning.nectarSeekRadius
            for d in nectar {
                if retiring.contains(d.id) || reservedBy[d.id] != nil { continue }
                // R4 (REVIEW-3 #14): never a walk across the crease to a drop on the other lobe.
                if sideOf(Double(d.position.x)) != sideOf(b.x) { continue }
                // R7 (#4): never a walk to a drop too close to a keep-out rect.
                if keptOut(Double(d.position.x), Double(d.position.y), b) { continue }
                let dd: Double = hypot(Double(d.position.x) - b.x, Double(d.position.y) - b.y)
                if dd < bd {
                    bd = dd
                    best = d
                }
            }
            if let d = best {
                reservedBy[d.id] = b.id
                b.dropID = d.id
                startDash(b, Double(d.position.x), Double(d.position.y))
                return
            }
        }
        let t: Double = b.rng.between(0, 2 * Double.pi)
        let dd: Double = b.rng.between(Tuning.wanderMin, Tuning.wanderMax)
        let p: (Double, Double) = findSpot(b, b.homeX + cos(t) * dd, b.homeY + sin(t) * dd, 0, 30,
                                           Tuning.landMaxRadius, side: sideOf(b.x))
        startDash(b, p.0, p.1)
    }

    private func startDash(_ b: Bug, _ x: Double, _ y: Double) {
        b.mode = .dash
        b.fx = b.x
        b.fy = b.y
        b.tx = x
        b.ty = y
        b.el = 0
        b.hovering = false
        let dist: Double = hypot(x - b.x, y - b.y)
        b.dur = max(0.15, dist / max(1, b.motion.walkSpeed))
    }

    /// Off toward the nearest edge (walkers never toward the top). `kind` is .leave, .escape or .release.
    private func takeOff(_ b: Bug, _ kind: Mode) {
        freeDrop(b)
        // R2 (QA-1 #12): a protected bug that escapes a slow bite left the trap uneaten too, so it counts as spared.
        if (kind == .leave || kind == .escape) && b.species.isProtected && b.landedInTrap && !b.sparedSent {
            b.sparedSent = true
            beesSpared += 1
            sparedBySpecies[b.species.rawValue, default: 0] += 1
            out.append(.beeSpared(species: b.species))
        }
        let w: Double = Double(geometry.sceneSize.width)
        let h: Double = Double(geometry.sceneSize.height)
        let dl: Double = b.x
        let dr: Double = w - b.x
        let db: Double = b.y
        let dtp: Double = h - b.y
        var ex: Double = b.x
        var ey: Double = b.y
        let walker: Bool = b.motion.style == .walker
        let mn: Double = walker ? min(dl, dr, db) : min(dl, dr, db, dtp)
        if mn == dl {
            ex = -Tuning.exitMargin
        } else if mn == dr {
            ex = w + Tuning.exitMargin
        } else if mn == db {
            ey = -Tuning.exitMargin
        } else {
            ey = h + Tuning.exitMargin
        }
        b.startHeight = b.height
        b.mode = kind
        b.fx = b.x
        b.fy = b.y
        b.tx = ex
        b.ty = ey
        b.el = 0
        b.travelled = 0
        b.hovering = false
        b.sip = 0
    }

    // MARK: Creep and bite

    /// A bug's reaction (flee) time now: its species, activity, the rim and the pace wave.
    private func reactionNow(_ b: Bug, _ a: BugActivity) -> Double {
        var sipping: Bool = false
        if case .sipping = a { sipping = true }
        return TrapRules.reaction(b.info, sipping: sipping, flying: TrapRules.isFlying(a),
                                  onRim: TrapRules.onRim(geometry, b.point, radius: b.info.radius),
                                  wave: TrapRules.paceWave(wave, mode: mode))
    }

    /// R8 (ROUND-8 §1): bug fear from continuous closure. A close starts when the closure passes Tuning.closeStart
    /// while the trap is open (armed, not shut, the round started); every catchable bug in the trap feels it: once the
    /// closure passes its nerve (startle depth) it startles, and after its reaction time it flees (`bugSpooked`, then
    /// it escapes fast). A close abandoned (closure under Tuning.closeCancel) calms the startled bugs that stayed.
    private func fear(_ inp: TrapInput) {
        let now: Double = time
        let c: Double = inp.closure
        let open: Bool = inp.armed && !shut && !waitingForClose
        if !closing {
            let starts: Bool = open && c >= Tuning.closeStart
            if starts || inp.snap != nil {
                closing = true
                fled = 0
                closeBugs.removeAll()
                closeStartAt = starts ? SnapDetector.crossing(prevTime, prevClosure, now, c, Tuning.closeStart) : now
                out.append(.snapStarted)
            }
        } else if c < Tuning.closeCancel && inp.snap == nil {
            closing = false
            for b in bugs { b.startledAt = nil }
            return
        }
        if !closing { return }
        for b in bugs {
            if !inTrap(b) { continue }
            let a: BugActivity = activity(of: b)
            if !TrapRules.isCandidate(a, height: b.height) { continue }
            if !b.species.isProtected { closeBugs.insert(b.id) }
            let nerve: Double = b.info.nerve
            if b.startledAt == nil && c >= nerve {
                b.startledAt = prevClosure < nerve ? SnapDetector.crossing(prevTime, prevClosure, now, c, nerve) : now
            }
            guard let since = b.startledAt, inp.snap == nil else { continue }
            if now - since >= reactionNow(b, a) {
                fled += 1
                b.restless = 1
                takeOff(b, .escape)
                out.append(.bugSpooked(id: b.id, species: b.species))
            }
        }
    }

    /// R8 (ROUND-8 §1): the bite at the shut. A catchable bug still in the trap is caught unless it has been fleeing
    /// longer than its reaction time: its exposure is the larger of the real time since it startled in this close and
    /// TrapRules.modelExposure(nerve:duration:). Bugs that fled the close count as escaped.
    private func bite(_ snap: SnapTrigger, hinge: Bool, armedAfter: Bool) {
        let d: Double = snap.duration.isFinite ? max(0, snap.duration) : 0
        let now: Double = time
        var caught: [BugSpecies] = []
        var stingers: [BugSpecies] = []
        var escaped: Int = fled
        var lost: Int = 0
        var perBug: [TrapEvent] = []
        for b in bugs {
            if !inTrap(b) { continue }
            let a: BugActivity = activity(of: b)
            if !TrapRules.isCandidate(a, height: b.height) { continue }
            if !b.species.isProtected { closeBugs.insert(b.id) }
            var exposure: Double = TrapRules.modelExposure(nerve: b.info.nerve, duration: d)
            if let since = b.startledAt { exposure = max(exposure, now - since) }
            let r: Double = reactionNow(b, a)
            if exposure <= r {
                if b.species.isProtected {
                    stingers.append(b.species)
                    let cost: Int = options.stingCosts ? (b.species == .wasp ? Tuning.waspCost : Tuning.beeCost) : 0
                    lost += cost
                    perBug.append(.stung(id: b.id, species: b.species, cost: cost))
                    takeOff(b, .release)
                } else {
                    caught.append(b.species)
                    perBug.append(.bugCaught(id: b.id, species: b.species, position: b.point))
                    freeDrop(b)
                    b.startHeight = b.height
                    b.mode = .caught
                    b.el = 0
                    b.fx = b.x
                    b.fy = b.y
                }
            } else {
                escaped += 1
                perBug.append(.bugEscaped(id: b.id, species: b.species))
                takeOff(b, .escape)
            }
        }
        for b in bugs { b.startledAt = nil }
        // R8 (ROUND-8 §2, the skill readout): caught ÷ the catchable bugs in the trap during the close.
        let denominator: Int = closeBugs.count
        let ratio: Double = denominator > 0 ? min(1, Double(caught.count) / Double(denominator)) : 0
        closing = false
        fled = 0
        closeBugs.removeAll()
        // R8: shut = digesting until the input is armed again (a source that stays armed never shuts).
        shut = !armedAfter
        shutElapsed = 0
        snapsMade += 1
        lastBiteTime = time
        let n: Int = caught.count
        let stung: Bool = !stingers.isEmpty
        // R2 hunger: any catch feeds the trap (a dry snap or a bee-only bite does not). R4: the clock then ticks again
        // only while food sits in the trap with no bee.
        if n >= 1 {
            hunger = 0
            hungrySent = false
        }
        // R3 (REVIEW-2 #9): the first stinger bite of a run with freeFirstSting (R4: or a first run) costs nothing extra.
        if stung && freeSting && !freeStingUsed {
            freeStingUsed = true
            lost = 0
            var k: Int = 0
            while k < perBug.count {
                if case .stung(let id, let sp, _) = perBug[k] { perBug[k] = .stung(id: id, species: sp, cost: 0) }
                k += 1
            }
        }
        // R3 (REVIEW-2 #8): a bite with a stinger in it scores ×1 and refunds nothing (no Feast, scarab or ladybird
        // snaps); the sting cost stays. Eating a bee is never the best move. R7 (#3): TrapRules.bitePoints is the one
        // scoring function (a clean FEAST of ≥ Tuning.bigFeastCount scores × Tuning.feastMultiplier).
        let mult: Double = stung ? 1 : TrapRules.chainMultiplier(chain)
        let points: Int = TrapRules.bitePoints(caught, chain: chain, stung: stung)
        var feastBack: Int = 0
        if !stung {
            if n >= Tuning.bigFeastCount {
                feastBack = Tuning.bigFeastRefund
            } else if n >= Tuning.feastCount {
                feastBack = Tuning.feastRefund
            }
        }
        var lucky: [BugSpecies] = []
        var luckyBack: Int = 0
        if !stung {
            for s in caught {
                if s == .goldenScarab {
                    luckyBack += Tuning.scarabRefund
                    lucky.append(s)
                } else if s == .ladybird {
                    luckyBack += Tuning.ladybirdRefund
                    lucky.append(s)
                }
            }
        }
        // R8 (ROUND-8 §4): a level refunds nothing (its bite limit is literal).
        if !options.refunds {
            feastBack = 0
            luckyBack = 0
            lucky.removeAll()
        }
        let back: Int = feastBack + luckyBack
        escapesTotal += escaped
        score += points
        bugsCaught += n
        for s in caught { caughtBySpecies[s.rawValue, default: 0] += 1 }
        stings += stingers.count
        // R3: a Feast is a clean bite of ≥ feastCount (a stung bite gets no Feast, so no `feast` event either).
        let feast: Bool = n >= Tuning.feastCount && !stung
        if feast { feasts += 1 }
        if n == 0 && stingers.isEmpty { drySnaps += 1 }
        bestBitePoints = max(bestBitePoints, points)
        biggestBite = max(biggestBite, n)
        if hinge && (fastestSnap == 0 || d < fastestSnap) { fastestSnap = d }

        let report = BiteReport(caught: caught, escaped: escaped, stingers: stingers, points: points,
                                countMultiplier: n, chainMultiplier: mult, snapsBack: back, snapsLost: lost,
                                duration: d, time: time, catchRatio: ratio)
        lastBite = report
        out.append(.snapped(report))
        out.append(contentsOf: perBug)
        if feast { out.append(.feast(count: n, snapsBack: feastBack)) }
        for s in lucky { out.append(.luckySnap(species: s)) }
        // R2 chain rule (GAME-DESIGN §5): a clean bite of ≥ 2 adds a step; a clean 1-bug bite holds the chain (no
        // event); a dry snap or a stinger breaks it.
        // R8 (ROUND-8 §2): any miss (a bug escaped the bite or fled its close) breaks it too.
        let clean: Bool = n >= 1 && stingers.isEmpty
        let missed: Bool = Tuning.missBreaksChain && escaped > 0
        if clean && !missed && n >= Tuning.chainMinBite {
            chain += 1
            longestChain = max(longestChain, chain)
            out.append(.chainUp(count: chain, multiplier: TrapRules.chainMultiplier(chain)))
        } else if !clean || missed {
            if chain >= 2 { out.append(.chainBroken(count: chain)) }
            chain = 0
        }
        if n == 0 && stingers.isEmpty { out.append(.drySnap) }
        // R8 (ROUND-8 §2): a dry bite costs Tuning.dryBiteCost more (0 since the R8 balance pass).
        let dryCost: Int = (n == 0 && stingers.isEmpty) ? Tuning.dryBiteCost : 0
        if options.snapsRunOut {
            let before: Int = snapsLeft
            snapsLeft = min(max(snapsLeft - Tuning.snapCost - lost - dryCost + back, 0), Tuning.maxSnaps)
            if snapsLeft == 1 && before != 1 { out.append(.lastSnap) }
            if snapsLeft == 0 { becomeTired() }
        }
        // R6: the Zen Bog has no best and no leaderboard, so it never fires newBest.
        if !newBestSent && best > 0 && score > best && TrapRules.keepsBest(mode) {
            newBestSent = true
            out.append(.newBest)
        }
        if levelSpec != nil && isPlaying { checkLevel(0) }
    }

    // MARK: Levels (R8, ROUND-8 §4)

    /// A level ends at once when its goal is met or a bee is bitten in a no-sting level; when its time is up; and when
    /// nothing is left to catch (nothing pending, no bug that isn't leaving) for Tuning.levelIdleEnd s. Out of bites
    /// ends it too (becomeTired). Mirrored by Session.checkLevel in tools/balance-sim.js.
    private func checkLevel(_ h: Double) {
        guard let l = levelSpec, isPlaying else { return }
        if l.noSting && stings > 0 {
            endLevel(.stung)
            return
        }
        if l.goal.met(caught: bugsCaught, bySpecies: caughtBySpecies, biggestBite: biggestBite, spared: beesSpared) {
            endLevel(.goal)
            return
        }
        if let t = l.timeLimit, time >= t {
            endLevel(.time)
            return
        }
        var active: Bool = !pending.isEmpty
        for b in bugs {
            switch b.mode {
            case .leave, .escape, .release, .caught, .cross: break
            case .approach, .hover, .sip, .pause, .dash, .hop: active = true
            }
        }
        if active {
            levelIdle = 0
        } else {
            levelIdle += h
            if levelIdle >= Tuning.levelIdleEnd { endLevel(.empty) }
        }
    }

    private func endLevel(_ why: LevelEnd) {
        levelEnd = why
        becomeTired()
    }

    // MARK: Hints and results

    private func currentHint() -> TrapHint? {
        guard isPlaying else { return nil }
        // R8 (founder rules 2, 3): no pose hint ever; a round waiting for its first close shows the App's own line.
        if waitingForClose { return nil }
        // R8: shut (the cover display) for over Tuning.openUpDelay: "Open it again".
        if shut { return shutElapsed > Tuning.openUpDelay ? .openUp : nil }
        if lastInput.creeping { return .quick }
        // R4: only while the clock is ticking (a paused clock is not about to wilt a snap). R6 (#15, REVIEW-5 P2-1):
        // never while a protected bug's halo touches the trap ("Hungry… bite!" next to a haloed bee reads as "bite it").
        if wilts && hungrySent && hungerLive && !protectedHaloOnTrap() { return .hungry }
        if !lastInput.armed && snapsMade > 0 && time - lastBiteTime > Tuning.openUpDelay { return .openUp }
        var beeLanded: Bool = false
        var beeAny: Bool = false
        var sipping: Int = 0
        for b in bugs where inTrap(b) {
            let a: BugActivity = activity(of: b)
            if b.species.isProtected {
                beeAny = true
                switch a {
                case .sipping, .walking: beeLanded = true
                case .arriving, .hopping, .leaving, .caught, .escaped, .released: break
                }
            } else if case .sipping = a {
                sipping += 1
            }
        }
        if beeLanded { return .beeInside }
        if options.snapsRunOut && snapsLeft == 1 { return .lastSnap }
        if sipping >= Tuning.crowdHintCount && !beeAny { return .crowd }
        return nil
    }

    /// R6 (#15, REVIEW-5 P2-1): a protected bug sits or hovers low just outside the trap (its centre outside the zone,
    /// landed or below Tuning.creaseAirHeight, not leaving) with its halo (Tuning.haloScale × radius + Tuning.haloPad,
    /// as the Scene draws it) reaching into the zone. Bees inside the zone keep R5's rule (the clock decides), so a
    /// high arrival over the trap still shows "Hungry… bite!".
    private func protectedHaloOnTrap() -> Bool {
        for b in bugs where b.species.isProtected {
            switch b.mode {
            case .leave, .escape, .release, .caught, .cross: continue
            case .approach, .hover, .sip, .pause, .dash, .hop: break
            }
            if geometry.contains(b.point) { continue }
            if !TrapSession.protectedCountsAsIn(landed: b.landed, height: b.height) { continue }
            if TrapRules.haloTouchesTrap(geometry, b.point, radius: b.info.radius) { return true }
        }
        return false
    }

    private func makeResult(seconds: Double) -> RunResult {
        return RunResult(mode: mode, seed: seed, score: score, seconds: seconds, snaps: snapsMade,
                         bugsCaught: bugsCaught, caughtBySpecies: caughtBySpecies, sparedBySpecies: sparedBySpecies,
                         bestBitePoints: bestBitePoints, biggestBite: biggestBite, longestChain: longestChain,
                         beesSpared: beesSpared, stings: stings, feasts: feasts, waves: wave, drySnaps: drySnaps,
                         fastestSnap: fastestSnap, escapes: escapesTotal)
    }
}

// MARK: - R6: modes, the late night's telegraph, the last light and the halo rule

/// R6 (#19, REVIEW-5 P2-5): what the HUD says as the late night closes in. Core picks the wave; the UI owns the words
/// (suggested: "The night gets fast…" and "Last light…"). The App shows it on the `.waveStarted(index:)` whose index
/// `TrapRules.nightCue(wave:mode:)` maps to a cue (see design/NEEDS.md: a contract event would be tidier).
enum NightCue: String, Equatable, Sendable {
    /// The first wave whose bugs react faster (Tuning.lateWaveStart + 1): Feed and the Daily.
    case nightGetsFast
    /// Tuning.lastLightWave: from here the trap gets hungry even when it is empty (Feed and the Daily).
    case lastLight
}

extension TrapRules {

    /// R7 (SCORE-R6 #3, #10): THE scoring function, used by every mode (Feed, the Daily, the Zen Bog, attract, the
    /// lesson): the species points summed × the bug count × the chain multiplier × feastBonus(count:stung:), rounded.
    /// A bite with a stinger scores × 1 whatever the chain. BiteReport.points is this; snapshot.score and
    /// RunResult.score are the sum of the run's BiteReport.points, so play and Results always agree.
    static func bitePoints(_ caught: [BugSpecies], chain: Int, stung: Bool) -> Int {
        let n: Int = caught.count
        var sum: Int = 0
        for s in caught { sum += BugCatalog.info(s).points }
        let mult: Double = stung ? 1 : chainMultiplier(chain)
        let raw: Double = Double(sum * n) * mult * feastBonus(count: n, stung: stung)
        return Int(raw.rounded())
    }

    /// R7 (#3, founder call): the FEAST multiplier inside a bite's points: Tuning.feastMultiplier (×2) for a clean
    /// bite of ≥ Tuning.bigFeastCount bugs, else 1. At the same chain 5 bugs then out-score 4 bugs whose mean points
    /// per bug are up to 3.1× higher.
    static func feastBonus(count: Int, stung: Bool) -> Double {
        if stung || count < Tuning.bigFeastCount { return 1 }
        return Tuning.feastMultiplier
    }

    /// R7 (SCORE-R6 #4): how far (pt) a resting bug's centre keeps from every TrapSession.keepOut rect: its radius
    /// (a protected bug: its halo as the Scene draws it, radius × Tuning.haloScale + Tuning.haloPad) plus
    /// Tuning.keepOutMargin.
    static func keepOutClearance(radius: CGFloat, protected: Bool) -> Double {
        let r: Double = Double(radius)
        let body: Double = protected ? r * Tuning.haloScale + Tuning.haloPad : r
        return body + Tuning.keepOutMargin
    }

    /// R7 (#4): does a circle of `clearance` round (x, y) reach into any of `rects` (closer than `clearance` to one,
    /// or inside it)? Null rects are ignored.
    static func touchesKeepOut(_ rects: [CGRect], _ x: Double, _ y: Double, clearance: Double) -> Bool {
        for raw in rects where !raw.isNull {
            let r: CGRect = raw.standardized
            let qx: Double = min(max(x, Double(r.minX)), Double(r.maxX))
            let qy: Double = min(max(y, Double(r.minY)), Double(r.maxY))
            if hypot(x - qx, y - qy) < clearance { return true }
        }
        return false
    }

    /// R6: the wave the bite rule's late factor uses. The Zen Bog's loops never reach the late night (its recipe wave,
    /// 1…Tuning.zenDayWaves); every other mode uses the real wave, as before.
    static func paceWave(_ wave: Int, mode: RunMode) -> Int {
        switch mode {
        case .zen: return ((max(wave, 1) - 1) % Tuning.zenDayWaves) + 1
        case .feed, .daily, .attract, .lesson, .level: return wave
        }
    }

    /// R6: does a run of this mode keep a personal best (and fire `newBest`)? Not the Zen Bog (no best, no
    /// leaderboard); attract and the lesson are given best 0 by the App anyway.
    static func keepsBest(_ mode: RunMode) -> Bool {
        switch mode {
        case .feed, .daily, .attract, .lesson: return true
        // R8: a level keeps its stars, not a score best (the App persists them).
        case .zen, .level: return false
        }
    }

    /// R6 (#19, founder call): the last light is a Feed-rules rule, so Feed and the Daily (Zen, attract and the lesson
    /// never wilt). TrapSession also needs wilting on (no Sprout run 1, no `hunger = false`).
    static func lastLightApplies(to mode: RunMode) -> Bool {
        switch mode {
        case .feed, .daily: return true
        case .attract, .lesson, .zen, .level: return false
        }
    }

    /// R6 (#19): the cue for the wave that just started (`.waveStarted(index:)`), if any. Nil in Zen, attract and the
    /// lesson; `.lastLight` where the last light applies (Feed and the Daily).
    static func nightCue(wave: Int, mode: RunMode) -> NightCue? {
        switch mode {
        case .zen, .attract, .lesson, .level: return nil
        case .feed, .daily: break
        }
        if wave == Tuning.lateWaveStart + 1 { return .nightGetsFast }
        if wave == Tuning.lastLightWave && lastLightApplies(to: mode) { return .lastLight }
        return nil
    }

    /// R6 (#15, REVIEW-5 P2-1): the halo the Scene draws round a protected bug (radius × Tuning.haloScale +
    /// Tuning.haloPad, TrapArt.protectedRingScale) reaches into the trap zone: the halo's nearest point to the trap's
    /// centre is inside it. A bug whose centre is inside always counts.
    static func haloTouchesTrap(_ g: TrapGeometry, _ p: CGPoint, radius: CGFloat) -> Bool {
        if g.contains(p) { return true }
        let dx: Double = Double(p.x - g.center.x)
        let dy: Double = Double(p.y - g.center.y)
        let len: Double = hypot(dx, dy)
        if len < 1e-6 { return true }
        let halo: Double = Double(radius) * Tuning.haloScale + Tuning.haloPad
        let k: Double = max(0, len - halo) / len
        let q = CGPoint(x: Double(g.center.x) + dx * k, y: Double(g.center.y) + dy * k)
        return g.contains(q)
    }
}
