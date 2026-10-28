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
    var hunger: Bool = true

    init(snapsRunOut: Bool = true, waves: Bool = true, stingCosts: Bool = true) {
        self.snapsRunOut = snapsRunOut
        self.waves = waves
        self.stingCosts = stingCosts
    }

    static func `for`(_ mode: RunMode) -> SessionOptions {
        switch mode {
        case .feed, .daily:
            return SessionOptions()
        case .attract:
            return SessionOptions(snapsRunOut: false, waves: true, stingCosts: true)
        case .lesson:
            return SessionOptions(snapsRunOut: false, waves: false, stingCosts: false)
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
// Mirrored by Session in tools/balance-sim.js (minus events, hints, telemetry and results).

final class TrapSession {

    let mode: RunMode
    let seed: UInt64
    let best: Int
    let geometry: TrapGeometry
    let options: SessionOptions

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
    private var score: Int = 0
    private var chain: Int = 0
    private var lastInput: TrapInput = TrapInput()
    private var prevArmed: Bool = true
    private var prevClosure: Double = 0
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

    private(set) var result: RunResult? = nil

    init(mode: RunMode, seed: UInt64, best: Int, geometry: TrapGeometry, options: SessionOptions) {
        self.mode = mode
        self.seed = seed
        self.best = best
        self.geometry = geometry
        self.options = options
        let first: Int = max(1, options.firstWave)
        self.wave = first - 1
        self.dayPhase = WaveFactory.phase(forWave: first)
        self.nectarBlock = (first - 1) / Tuning.nectarReseedWaves
        self.snapsLeft = min(max(options.startSnaps ?? Tuning.startSnaps, 1), Tuning.maxSnaps)
        installNectar(block: nectarBlock)
        bugs.reserveCapacity(Tuning.maxBugsOnScreen)
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

    /// R2: does this run wilt (feed and daily; never the lesson or attract)?
    private var wilts: Bool {
        return options.snapsRunOut && options.hunger
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
                            beesSpared: beesSpared, hunger: wilts ? hunger : 0)
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
        lastInput = inp
        if isPlaying {
            if prevArmed && prevClosure < Tuning.snapStartDepth
                && (inp.closure >= Tuning.snapStartDepth || inp.snap != nil) {
                out.append(.snapStarted)
            }
            if let s = inp.snap { bite(s, hinge: inp.angle != nil) }
            if inp.creeping && isPlaying { creep(inp.closure) }
            if inp.armed && !prevArmed { out.append(.rearmed) }
        }
        prevArmed = inp.armed
        prevClosure = inp.closure
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
        if isPlaying && wilts { tickHunger(h) }
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
    /// `hungry` fires once per cycle Tuning.hungryWarning s before. A wilt can tire the trap.
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

    /// Snaps reached 0: "Your trap is tired." Every bug still about takes off.
    private func becomeTired() {
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
        if case .attract = mode { return ((idx - 1) % Tuning.attractDayWaves) + 1 }
        return idx
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
        let spec: WaveSpec = WaveFactory.wave(seed: seed, index: recipe, geometry: geometry, nectar: nectar)
        out.append(.waveStarted(index: idx, phase: spec.phase))
        if spec.phase != dayPhase {
            dayPhase = spec.phase
            out.append(.dayPhaseChanged(spec.phase))
        }
        let at: Double = nextWaveAt
        for s in spec.bugs { pending.append(PendingSpawn(at: at + s.groupOffset, spec: s)) }
        lastWaveAt = at
        nextWaveAt = at + WaveFactory.delay(seed: seed, index: recipe + 1)
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
            if let drop = d, reservedBy[drop.id] == nil {
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
        return worst
    }

    private func clampIn(_ px: Double, _ py: Double, _ maxR: Double) -> (Double, Double) {
        let r: Double = geometry.normalizedRadius(CGPoint(x: px, y: py))
        if r <= maxR || r == 0 { return (px, py) }
        let k: Double = maxR / r
        let cx: Double = Double(geometry.center.x)
        let cy: Double = Double(geometry.center.y)
        return (cx + (px - cx) * k, cy + (py - cy) * k)
    }

    /// A spot near (x, y), `dMin`…`dMax` away, inside `maxR`, as clear of the other bugs as it can find.
    private func findSpot(_ b: Bug, _ x: Double, _ y: Double, _ dMin: Double, _ dMax: Double,
                          _ maxR: Double) -> (Double, Double) {
        var best: (Double, Double) = clampIn(x, y, maxR)
        var bestScore: Double = dMin <= 0 ? spotScore(b, best.0, best.1) : -Double.infinity
        if bestScore >= 0 { return best }
        var i: Int = 0
        while i < Tuning.spotTries {
            let t: Double = b.rng.between(0, 2 * Double.pi)
            // R2: the search reaches at least this bug's own spacing need (radii are ×1.8).
            let reach: Double = Double(b.info.radius) * 2 + Tuning.landSpacing + 10
            let dd: Double = b.rng.between(max(dMin, 8), max(dMax, 20, reach))
            let p: (Double, Double) = clampIn(x + cos(t) * dd, y + sin(t) * dd, maxR)
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
        if !b.landsInTrap { return (b.tx, b.ty) }
        if b.dropID != nil { return (b.tx, b.ty) }
        if spotScore(b, b.tx, b.ty) >= 0 { return (b.tx, b.ty) }
        return findSpot(b, b.tx, b.ty, 0, 50, Tuning.landMaxRadius)
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
            let p: (Double, Double) = findSpot(b, wantX, wantY, 0, 40, Tuning.landMaxRadius)
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
                                           Tuning.landMaxRadius)
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

    private func creep(_ closure: Double) {
        for b in bugs {
            if !inTrap(b) || b.mode == .leave { continue }
            if b.info.nerve <= closure {
                b.restless = 1
                b.spooked = true
                takeOff(b, .leave)
                out.append(.bugSpooked(id: b.id, species: b.species))
            }
        }
    }

    private func bite(_ snap: SnapTrigger, hinge: Bool) {
        let d: Double = snap.duration.isFinite ? max(0, snap.duration) : 0
        var caught: [BugSpecies] = []
        var stingers: [BugSpecies] = []
        var escaped: Int = 0
        var lost: Int = 0
        var perBug: [TrapEvent] = []
        for b in bugs {
            if !inTrap(b) { continue }
            let a: BugActivity = activity(of: b)
            if !TrapRules.isCandidate(a, height: b.height) { continue }
            var sipping: Bool = false
            if case .sipping = a { sipping = true }
            let r: Double = TrapRules.reaction(b.info, sipping: sipping, flying: TrapRules.isFlying(a),
                                               onRim: TrapRules.onRim(geometry, b.point, radius: b.info.radius),
                                               wave: wave)
            if d <= r {
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
        snapsMade += 1
        lastBiteTime = time
        let n: Int = caught.count
        // R2 hunger: any catch feeds the trap (a dry snap or a bee-only bite does not).
        if n >= 1 {
            hunger = 0
            hungrySent = false
        }
        var sum: Int = 0
        for s in caught { sum += BugCatalog.info(s).points }
        let mult: Double = TrapRules.chainMultiplier(chain)
        let points: Int = Int((Double(sum * n) * mult).rounded())
        var feastBack: Int = 0
        if n >= Tuning.bigFeastCount {
            feastBack = Tuning.bigFeastRefund
        } else if n >= Tuning.feastCount {
            feastBack = Tuning.feastRefund
        }
        var lucky: [BugSpecies] = []
        var luckyBack: Int = 0
        for s in caught {
            if s == .goldenScarab {
                luckyBack += Tuning.scarabRefund
                lucky.append(s)
            } else if s == .ladybird {
                luckyBack += Tuning.ladybirdRefund
                lucky.append(s)
            }
        }
        let back: Int = feastBack + luckyBack
        score += points
        bugsCaught += n
        for s in caught { caughtBySpecies[s.rawValue, default: 0] += 1 }
        stings += stingers.count
        if n >= Tuning.feastCount { feasts += 1 }
        if n == 0 && stingers.isEmpty { drySnaps += 1 }
        bestBitePoints = max(bestBitePoints, points)
        biggestBite = max(biggestBite, n)
        if hinge && (fastestSnap == 0 || d < fastestSnap) { fastestSnap = d }

        let report = BiteReport(caught: caught, escaped: escaped, stingers: stingers, points: points,
                                countMultiplier: n, chainMultiplier: mult, snapsBack: back, snapsLost: lost,
                                duration: d, time: time)
        lastBite = report
        out.append(.snapped(report))
        out.append(contentsOf: perBug)
        if n >= Tuning.feastCount { out.append(.feast(count: n, snapsBack: feastBack)) }
        for s in lucky { out.append(.luckySnap(species: s)) }
        // R2 chain rule (GAME-DESIGN §5): a clean bite of ≥ 2 adds a step; a clean 1-bug bite holds the chain (no
        // event); a dry snap or a stinger breaks it.
        let clean: Bool = n >= 1 && stingers.isEmpty
        if clean && n >= Tuning.chainMinBite {
            chain += 1
            longestChain = max(longestChain, chain)
            out.append(.chainUp(count: chain, multiplier: TrapRules.chainMultiplier(chain)))
        } else if !clean {
            if chain >= 2 { out.append(.chainBroken(count: chain)) }
            chain = 0
        }
        if n == 0 && stingers.isEmpty { out.append(.drySnap) }
        if options.snapsRunOut {
            let before: Int = snapsLeft
            snapsLeft = min(max(snapsLeft - Tuning.snapCost - lost + back, 0), Tuning.maxSnaps)
            if snapsLeft == 1 && before != 1 { out.append(.lastSnap) }
            if snapsLeft == 0 { becomeTired() }
        }
        if !newBestSent && best > 0 && score > best {
            newBestSent = true
            out.append(.newBest)
        }
    }

    // MARK: Hints and results

    private func currentHint() -> TrapHint? {
        guard isPlaying else { return nil }
        if lastInput.tooFlat { return .bendALittle }
        if lastInput.creeping { return .quick }
        if wilts && hungrySent { return .hungry }
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

    private func makeResult(seconds: Double) -> RunResult {
        return RunResult(mode: mode, seed: seed, score: score, seconds: seconds, snaps: snapsMade,
                         bugsCaught: bugsCaught, caughtBySpecies: caughtBySpecies, sparedBySpecies: sparedBySpecies,
                         bestBitePoints: bestBitePoints, biggestBite: biggestBite, longestChain: longestChain,
                         beesSpared: beesSpared, stings: stings, feasts: feasts, waves: wave, drySnaps: drySnaps,
                         fastestSnap: fastestSnap)
    }
}
