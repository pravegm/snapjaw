import CoreGraphics
import Foundation

// MARK: - Waves (GAME-DESIGN §6)

/// One wave's recipe. Deterministic: the same (seed, index) gives the same wave.
struct WaveSpec: Equatable {
    /// 1-based (wave 1 is the first wave of the run).
    var index: Int
    var phase: DayPhase
    /// Seconds after the previous wave (wave 1: Tuning.firstWaveTime after the session began).
    var delay: Double
    var bugs: [SpawnSpec]
    /// R2: a crowd wave (its flyers land together, near one nectar cluster).
    var crowd: Bool = false
}

struct SpawnSpec: Equatable {
    var species: BugSpecies
    /// Scene space, on or just off an edge.
    var entry: CGPoint
    /// The landing spot (a nectar drop's position, or a spot), scene space. Crossers: a point off the far edge.
    var target: CGPoint
    /// Seconds it stays after landing (0 for crossers).
    var linger: Double
    /// false: it crosses the screen high, or sits on the bog outside the trap.
    var landsInTrap: Bool
    /// Seconds after the wave start that it enters (swarms, lines and trickles).
    var groupOffset: Double
}

/// The wave table. Every draw happens in the same order as `makeWave` in tools/balance-sim.js.
enum WaveFactory {

    static func phase(forWave index: Int) -> DayPhase {
        let i: Int = max(index, 1)
        if i >= Tuning.nightWave { return .night }
        if i >= Tuning.duskWave { return .dusk }
        if i >= Tuning.noonWave { return .noon }
        return .morning
    }

    /// The seed of wave `index`'s own generator.
    static func waveSeed(seed: UInt64, index: Int) -> UInt64 {
        var r = SeededRandom(seed: seed ^ (UInt64(truncatingIfNeeded: index) &* 0x9E37_79B9_7F4A_7C15) ^ 0x5741_5645)
        return r.next()
    }

    /// Seconds between wave index−1 and wave `index` (wave ≤ 1: Tuning.firstWaveTime).
    static func delay(seed: UInt64, index: Int) -> Double {
        if index <= 1 { return Tuning.firstWaveTime }
        var r = SeededRandom(seed: waveSeed(seed: seed, index: index) ^ 0xD11A)
        return r.between(Tuning.waveDelayMin, Tuning.waveDelayMax)
    }

    /// The nectar generator's seed for a 6-wave block (block 0 = waves 1–6).
    static func nectarSeed(seed: UInt64, block: Int) -> UInt64 {
        return seed ^ (UInt64(truncatingIfNeeded: block) &* 0xBF58_476D_1CE4_E5B9) ^ 0x4E_4543
    }

    /// R2 (REVIEW-1 #19): 6–8 drops in clusters of 2–3 (each cluster's drops evenly spaced on a ring of
    /// Tuning.nectarRingMin…Max, 24–30 pt since R3), the clusters alternating between the lobes, at least
    /// Tuning.nectarCreaseClearance (80 pt, R3) off the midrib line. Ids 0…n−1, cluster by cluster.
    static func nectar(seed: UInt64, geometry: TrapGeometry) -> [NectarDrop] {
        var r = SeededRandom(seed: seed ^ 0x4E45_4354)
        let n: Int = r.int(Tuning.nectarMin...Tuning.nectarMax)
        let kMin: Int = (n + Tuning.nectarClusterMax - 1) / Tuning.nectarClusterMax
        let kMax: Int = max(kMin, n / Tuning.nectarClusterMin)
        let k: Int = r.int(kMin...kMax)
        let extra: Int = n - Tuning.nectarClusterMin * k
        let firstLeft: Bool = r.chance(0.5)
        var centres: [CGPoint] = []
        var out: [NectarDrop] = []
        let cx: Double = Double(geometry.center.x)
        var c: Int = 0
        while c < k {
            let size: Int = Tuning.nectarClusterMin + (c < extra ? 1 : 0)
            let left: Bool = (c % 2 == 0) == firstLeft
            // A lobe with two clusters puts its first in the upper half and its second in the lower half.
            let inLobe: Int = c % 2 == 0 ? (k + 1) / 2 : k / 2
            let half: Int = inLobe < 2 ? 0 : (c / 2 == 0 ? 1 : -1)
            let margin: Double = Tuning.nectarArcMargin
            var lo: Double = left ? Double.pi / 2 + margin : -Double.pi / 2 + margin
            var hi: Double = left ? 3 * Double.pi / 2 - margin : Double.pi / 2 - margin
            if half == 1 {
                if left { hi = Double.pi - Tuning.nectarHalfGap } else { lo = Tuning.nectarHalfGap }
            }
            if half == -1 {
                if left { lo = Double.pi + Tuning.nectarHalfGap } else { hi = -Tuning.nectarHalfGap }
            }
            let ring: Double = r.between(Tuning.nectarRingMin, Tuning.nectarRingMax)
            // The candidate furthest from the other centres (and off the crease) wins; the first one clear of them
            // all ends the search.
            var p: CGPoint = geometry.center
            var best: Double = -Double.infinity
            var tries: Int = 0
            while tries < Tuning.nectarTries {
                let t: Double = r.between(lo, hi)
                let rr: Double = r.between(Tuning.nectarClusterInner, Tuning.nectarClusterOuter)
                let cand: CGPoint = geometry.point(angle: t, radius: rr)
                var gap: Double = 1e6
                for q in centres {
                    gap = min(gap, hypot(Double(q.x - cand.x), Double(q.y - cand.y)))
                }
                let clear: Bool = abs(Double(cand.x) - cx) >= Tuning.nectarCreaseClearance + ring
                let score: Double = clear ? gap : gap - 1e9
                if score > best {
                    best = score
                    p = cand
                }
                if clear && gap >= Tuning.nectarClusterGap { break }
                tries += 1
            }
            centres.append(p)
            let spin: Double = r.between(0, 2 * Double.pi)
            var j: Int = 0
            while j < size {
                let ang: Double = spin + 2 * Double.pi * Double(j) / Double(size)
                let radius: Double = r.between(Tuning.nectarRadiusMin, Tuning.nectarRadiusMax)
                let pos = CGPoint(x: Double(p.x) + cos(ang) * ring, y: Double(p.y) + sin(ang) * ring)
                out.append(NectarDrop(id: out.count, position: pos, radius: CGFloat(radius)))
                j += 1
            }
            c += 1
        }
        return out
    }

    // MARK: The recipe

    private struct Weighted {
        var species: BugSpecies
        var weight: Double
    }

    static func lingerRange(phase ph: DayPhase, index: Int) -> (Double, Double) {
        switch ph {
        case .morning: return (Tuning.lingerMorningMin, Tuning.lingerMorningMax)
        case .noon: return (Tuning.lingerNoonMin, Tuning.lingerNoonMax)
        case .dusk: return (Tuning.lingerDuskMin, Tuning.lingerDuskMax)
        case .night:
            var k: Double = 1
            if index > Tuning.lateWaveStart {
                k = max(Tuning.lateLingerFloor, pow(Tuning.lateLingerDecay, Double(index - Tuning.lateWaveStart)))
            }
            return (Tuning.lingerNightMin * k, Tuning.lingerNightMax * k)
        }
    }

    /// R7 (SCORE-R6 #14): at night the day bugs thin out (× Tuning.nightDayBugWeight) and fireflies and crickets
    /// lead (Tuning.nightFireflyWeight, nightCricketWeight). Same entries in the same order, so the same draws.
    private static func pool(_ ph: DayPhase, _ index: Int) -> [Weighted] {
        let k: Double = ph >= .night ? Tuning.nightDayBugWeight : 1
        var out: [Weighted] = [Weighted(species: .housefly, weight: 6 * k), Weighted(species: .fruitFly, weight: 3 * k)]
        if index >= Tuning.gnatFromWave { out.append(Weighted(species: .gnat, weight: 2 * k)) }
        if ph >= .noon {
            out.append(Weighted(species: .bluebottle, weight: 3 * k))
            out.append(Weighted(species: .grasshopper, weight: 2 * k))
        }
        // Ants and ladybirds are day bugs: they go home at dusk.
        if ph == .noon {
            out.append(Weighted(species: .ant, weight: 2))
            out.append(Weighted(species: .ladybird, weight: 2))
        }
        if ph >= .dusk {
            out.append(Weighted(species: .moth, weight: 3))
            out.append(Weighted(species: .mosquito, weight: 3))
            out.append(Weighted(species: .dragonfly, weight: 1.5))
        }
        if ph >= .night {
            out.append(Weighted(species: .firefly, weight: Tuning.nightFireflyWeight))
            out.append(Weighted(species: .cricket, weight: Tuning.nightCricketWeight))
        }
        return out
    }

    private static func pick(_ p: [Weighted], _ r: inout SeededRandom) -> BugSpecies {
        var total: Double = 0
        for w in p { total += w.weight }
        var x: Double = r.unit() * total
        for w in p {
            if x < w.weight { return w.species }
            x -= w.weight
        }
        return p[p.count - 1].species
    }

    private static func groupSize(_ s: BugSpecies, _ r: inout SeededRandom) -> Int {
        switch s {
        case .gnat: return r.int(4...5)
        case .ant: return r.int(3...5)
        case .fruitFly: return 2
        default: return 1
        }
    }

    private static func groupStep(_ s: BugSpecies) -> Double {
        switch s {
        case .gnat: return 0.08
        case .ant: return 0.6
        case .fruitFly: return 0.25
        default: return 0
        }
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        return min(max(v, lo), hi)
    }

    /// An entry point on (just off) an edge, biased to the target's side.
    private static func edgeEntry(_ target: CGPoint, _ g: TrapGeometry, _ r: inout SeededRandom) -> CGPoint {
        let left: Bool = Double(target.x) < Double(g.center.x)
        let x: Double = r.unit()
        let w: Double = Double(g.sceneSize.width)
        let h: Double = Double(g.sceneSize.height)
        if x < 0.6 {
            let near: Bool = x < 0.4
            let sideLeft: Bool = near ? left : !left
            let y: Double = clamp(Double(target.y) + r.between(-200, 200), 40, h - 40)
            return CGPoint(x: sideLeft ? -30 : w + 30, y: y)
        }
        let xx: Double = clamp(Double(target.x) + r.between(-260, 260), 40, w - 40)
        return CGPoint(x: xx, y: x < 0.9 ? h + 30 : -30)
    }

    /// R5 (REVIEW-4 #15): a protected bug never enters under a Duo thumb. An entry within Tuning.thumbBandWidth of
    /// either outer edge (including just off it) whose y lies strictly inside the band (thumbBandLow…thumbBandHigh of
    /// the height) has its y mirrored across the band's nearer edge: the band's lower half goes below it, its upper
    /// half above it. Same side, same spread, no draws (the draw order never changes). Pure; tested.
    static func thumbSafeEntry(_ e: CGPoint, sceneSize: CGSize) -> CGPoint {
        if !inThumbBand(e, sceneSize: sceneSize) { return e }
        let h: Double = Double(sceneSize.height)
        let y: Double = Double(e.y)
        let lo: Double = h * Tuning.thumbBandLow
        let hi: Double = h * Tuning.thumbBandHigh
        let ny: Double = y < (lo + hi) / 2 ? 2 * lo - y : 2 * hi - y
        return CGPoint(x: Double(e.x), y: ny)
    }

    /// R5: is `p` in a thumb band (within Tuning.thumbBandWidth of an outer edge, or past it, with y strictly inside
    /// thumbBandLow…thumbBandHigh of the height)? Pure; tested.
    static func inThumbBand(_ p: CGPoint, sceneSize: CGSize) -> Bool {
        let w: Double = Double(sceneSize.width)
        let h: Double = Double(sceneSize.height)
        let x: Double = Double(p.x)
        let y: Double = Double(p.y)
        let outer: Bool = x < Tuning.thumbBandWidth || x > w - Tuning.thumbBandWidth
        return outer && y > h * Tuning.thumbBandLow && y < h * Tuning.thumbBandHigh
    }

    private static func clampToRadius(_ g: TrapGeometry, _ p: CGPoint, _ maxR: Double) -> CGPoint {
        let rr: Double = g.normalizedRadius(p)
        if rr <= maxR || rr == 0 { return p }
        let k: Double = maxR / rr
        let cx: Double = Double(g.center.x)
        let cy: Double = Double(g.center.y)
        return CGPoint(x: cx + (Double(p.x) - cx) * k, y: cy + (Double(p.y) - cy) * k)
    }

    /// R2: the approach flight time the session will give this spawn (nil: walkers, and bugs that never land in the
    /// trap). The session's spacing check can still move a random spot a little before landing.
    static func flightTime(_ spec: SpawnSpec) -> Double? {
        let m: BugMotion = BugCatalog.motion(spec.species)
        if !spec.landsInTrap || m.style == .walker { return nil }
        let dist: Double = hypot(Double(spec.target.x - spec.entry.x), Double(spec.target.y - spec.entry.y))
        return max(Tuning.minFlightTime, dist * Tuning.approachPathFactor / m.speed)
    }

    private static func randomSpot(_ g: TrapGeometry, _ r: inout SeededRandom, _ maxR: Double) -> CGPoint {
        let t: Double = r.between(0, 2 * Double.pi)
        let rr: Double = r.unit().squareRoot() * maxR
        return g.point(angle: t, radius: rr)
    }

    private static func protectedCount(_ index: Int, _ ph: DayPhase, _ r: inout SeededRandom) -> Int {
        var n: Int = 0
        switch ph {
        case .morning: n = (index >= Tuning.beeFromWave && r.chance(Tuning.beeChanceMorning)) ? 1 : 0
        case .noon: n = r.chance(Tuning.beeChanceNoon) ? 1 : 0
        case .dusk: n = r.chance(Tuning.beeChanceDusk) ? 1 : 0
        case .night:
            let a: Int = r.chance(Tuning.beeChanceNight) ? 1 : 0
            let b: Int = r.chance(Tuning.beeChanceNight2) ? 1 : 0
            n = a + b
        }
        if index > Tuning.lateWaveStart { n += (index - Tuning.lateWaveStart) / Tuning.extraBeeEvery }
        return min(n, Tuning.maxProtectedPerWave)
    }

    private static func protectedSpecies(_ ph: DayPhase, _ r: inout SeededRandom) -> BugSpecies {
        let u: Double = r.unit()
        switch ph {
        case .morning: return .bee
        case .noon: return u < 0.75 ? .bee : .bumblebee
        case .dusk, .night:
            if u < 0.5 { return .bee }
            return u < 0.72 ? .bumblebee : .wasp
        }
    }

    /// Builds wave `index` (1-based) for this run seed, aiming bugs at `nectar` (the drops at the wave's start).
    /// R4 (REVIEW-3 #11): `calm` (a Sprout's first Feed run, SessionOptions.firstRun) makes waves up to
    /// Tuning.firstRunCalmWaves crowds. The crowd chance is still drawn, so the draw order never changes.
    static func wave(seed: UInt64, index: Int, geometry: TrapGeometry, nectar: [NectarDrop],
                     calm: Bool = false) -> WaveSpec {
        var r = SeededRandom(seed: waveSeed(seed: seed, index: index))
        let ph: DayPhase = phase(forWave: index)
        var size: Int
        if index <= 3 {
            size = r.int(Tuning.sizeFirstMin...Tuning.sizeFirstMax)
        } else {
            switch ph {
            case .morning: size = r.int(Tuning.sizeMorningMin...Tuning.sizeMorningMax)
            case .noon: size = r.int(Tuning.sizeNoonMin...Tuning.sizeNoonMax)
            case .dusk: size = r.int(Tuning.sizeDuskMin...Tuning.sizeDuskMax)
            case .night: size = r.int(Tuning.sizeNightMin...Tuning.sizeNightMax)
            }
        }
        let crowd: Bool = (index >= Tuning.crowdFromWave && r.chance(Tuning.crowdChance))
            || (calm && index <= Tuning.firstRunCalmWaves)
        if crowd { size = max(size, 3) }
        let p: [Weighted] = pool(ph, index)
        // Shuffled drop order (Fisher–Yates).
        var order: [Int] = Array(0..<nectar.count)
        var i: Int = order.count - 1
        while i > 0 {
            let j: Int = r.int(0...i)
            order.swapAt(i, j)
            i -= 1
        }
        // R2: a crowd goes to one cluster: the drops nearest a random anchor drop first, its spots near the anchor.
        var anchor: CGPoint? = nil
        if crowd && !order.isEmpty {
            let ap: CGPoint = nectar[order[0]].position
            anchor = ap
            func dist(_ k: Int) -> Double {
                return hypot(Double(nectar[k].position.x - ap.x), Double(nectar[k].position.y - ap.y))
            }
            order.sort { (x: Int, y: Int) -> Bool in
                let dx: Double = dist(x)
                let dy: Double = dist(y)
                if dx != dy { return dx < dy }
                return x < y
            }
        }
        var nextDrop: Int = 0
        var bugs: [SpawnSpec] = []
        let lr: (Double, Double) = lingerRange(phase: ph, index: index)
        let lmin: Double = lr.0
        let lmax: Double = lr.1
        let w: Double = Double(geometry.sceneSize.width)
        let h: Double = Double(geometry.sceneSize.height)
        let cx: Double = Double(geometry.center.x)
        let cy: Double = Double(geometry.center.y)

        func addGroup(_ s: BugSpecies, _ count: Int, _ base: Double) {
            let m: BugMotion = BugCatalog.motion(s)
            let prot: Bool = s.isProtected
            let canPass: Bool = (m.style == .fly || m.style == .flutter) && count == 1
            if canPass && r.chance(prot ? Tuning.beePasserChance : Tuning.passerChance) {
                let cross: Bool = r.chance(0.5)
                if cross {
                    let fromLeft: Bool = r.chance(0.5)
                    let y0: Double = r.between(120, h - 120)
                    let y1: Double = r.between(120, h - 120)
                    let e0 = CGPoint(x: fromLeft ? -30 : w + 30, y: y0)
                    // R5 (REVIEW-4 #15): never under a thumb.
                    let ce: CGPoint = prot ? thumbSafeEntry(e0, sceneSize: geometry.sceneSize) : e0
                    bugs.append(SpawnSpec(species: s, entry: ce,
                                          target: CGPoint(x: fromLeft ? w + 40 : -40, y: y1), linger: 0,
                                          landsInTrap: false, groupOffset: base))
                } else {
                    let cl: Bool = r.chance(0.5)
                    let cb: Bool = r.chance(0.5)
                    let tx: Double = cl ? r.between(30, 90) : w - r.between(30, 90)
                    let ty: Double = cb ? r.between(30, 90) : h - r.between(30, 90)
                    let target = CGPoint(x: tx, y: ty)
                    let e0: CGPoint = edgeEntry(target, geometry, &r)
                    let entry: CGPoint = prot ? thumbSafeEntry(e0, sceneSize: geometry.sceneSize) : e0
                    let lg: Double = r.between(lmin, lmax) * m.lingerFactor * (prot ? Tuning.beeLingerFactor : 1)
                    bugs.append(SpawnSpec(species: s, entry: entry, target: target, linger: lg, landsInTrap: false,
                                          groupOffset: base))
                }
                return
            }
            let target: CGPoint
            if s == .moth {
                let ox: Double = r.between(-80, 80)
                let oy: Double = r.between(-180, 180)
                target = CGPoint(x: cx + ox, y: cy + oy)
            } else if m.nectarChance > 0 && nextDrop < order.count && r.chance(m.nectarChance) {
                target = nectar[order[nextDrop]].position
                nextDrop += 1
            } else if let ap = anchor {
                let t: Double = r.between(0, 2 * Double.pi)
                let dd: Double = r.between(Tuning.crowdNearMin, Tuning.crowdNearMax)
                target = clampToRadius(geometry, CGPoint(x: Double(ap.x) + cos(t) * dd, y: Double(ap.y) + sin(t) * dd),
                                       Tuning.spotRadius)
            } else {
                target = randomSpot(geometry, &r, Tuning.spotRadius)
            }
            var entry: CGPoint
            if m.style == .walker {
                entry = CGPoint(x: clamp(Double(target.x) + r.between(-120, 120), 40, w - 40), y: -20)
            } else {
                entry = edgeEntry(target, geometry, &r)
            }
            // R5 (REVIEW-4 #15): a bee, bumblebee or wasp never enters under a thumb.
            if prot { entry = thumbSafeEntry(entry, sceneSize: geometry.sceneSize) }
            var k: Int = 0
            while k < count {
                var t: CGPoint = target
                var e: CGPoint = entry
                if s == .gnat {
                    let tx: Double = r.between(-45, 45)
                    let ty: Double = r.between(-35, 35)
                    t = CGPoint(x: Double(target.x) + tx, y: Double(target.y) + ty)
                    let ex: Double = r.between(-30, 30)
                    let ey: Double = r.between(-30, 30)
                    e = CGPoint(x: Double(entry.x) + ex, y: Double(entry.y) + ey)
                } else if s == .fruitFly && k > 0 {
                    if nextDrop < order.count && r.chance(0.6) {
                        t = nectar[order[nextDrop]].position
                        nextDrop += 1
                    } else {
                        let tx: Double = r.between(-50, 50)
                        let ty: Double = r.between(-40, 40)
                        t = CGPoint(x: Double(target.x) + tx, y: Double(target.y) + ty)
                    }
                }
                let lg: Double = r.between(lmin, lmax) * m.lingerFactor * (prot ? Tuning.beeLingerFactor : 1)
                bugs.append(SpawnSpec(species: s, entry: e, target: t, linger: lg, landsInTrap: true,
                                      groupOffset: base + Double(k) * groupStep(s)))
                k += 1
            }
        }

        var slot: Int = 0
        var nonProtected: Int = 0
        while nonProtected < size && bugs.count < Tuning.maxWaveBugs {
            let s: BugSpecies = pick(p, &r)
            let gsz: Int = min(groupSize(s, &r), Tuning.maxWaveBugs - bugs.count)
            let base: Double = crowd ? r.between(0, Tuning.crowdSpread)
                                     : Double(slot) * r.between(Tuning.trickleMin, Tuning.trickleMax)
            addGroup(s, gsz, base)
            nonProtected += gsz
            slot += 1
        }
        if index >= Tuning.scarabFromWave && r.chance(Tuning.scarabChance) {
            let base: Double = crowd ? r.between(0, Tuning.crowdSpread)
                                     : Double(slot) * r.between(Tuning.trickleMin, Tuning.trickleMax)
            addGroup(.goldenScarab, 1, base)
            slot += 1
        }
        // R2: a crowd lands together: each flyer starts late by how much quicker its flight is than the slowest one's.
        if crowd {
            var flights: [Double?] = []
            var maxF: Double = 0
            for x in bugs {
                let f: Double? = flightTime(x)
                flights.append(f)
                if let v = f { maxF = max(maxF, v) }
            }
            var q: Int = 0
            while q < bugs.count {
                if let v = flights[q] { bugs[q].groupOffset += maxF - v }
                q += 1
            }
        }
        let np: Int = protectedCount(index, ph, &r)
        var b: Int = 0
        while b < np {
            let s: BugSpecies = protectedSpecies(ph, &r)
            let base: Double = r.between(0, Tuning.beeSpread)
            addGroup(s, 1, base)
            b += 1
        }
        return WaveSpec(index: index, phase: ph, delay: delay(seed: seed, index: index), bugs: bugs, crowd: crowd)
    }
}
