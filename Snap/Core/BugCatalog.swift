import CoreGraphics
import Foundation

// MARK: - The Bug Book (GAME-DESIGN §6): 16 species in BugSpecies.allCases order

enum BugCatalog {

    /// R2 (REVIEW-1 #4): the R1 art radius × Tuning.bugRadiusScale (1.8). The Scene draws at BugInfo.radius, and the
    /// rules (spacing, the rim test, landing spots) use the same number, so art and rules agree.
    static func scaled(_ base: Double) -> CGFloat {
        return CGFloat(base * Tuning.bugRadiusScale)
    }

    static let all: [BugInfo] = [
        BugInfo(species: .housefly, name: "Housefly", joke: "Has never once wiped its feet.",
                points: 10, reaction: 0.24, nerve: 7, radius: BugCatalog.scaled(14), firstPhase: .morning),
        BugInfo(species: .gnat, name: "Gnat", joke: "Travels in a cloud of five. Thinks for none.",
                points: 3, reaction: 0.32, nerve: 10, radius: BugCatalog.scaled(7), firstPhase: .morning),
        BugInfo(species: .fruitFly, name: "Fruit Fly", joke: "Came for the banana. Stayed for the nectar.",
                points: 6, reaction: 0.28, nerve: 9, radius: BugCatalog.scaled(9), firstPhase: .morning),
        BugInfo(species: .bluebottle, name: "Bluebottle", joke: "Shiny, loud, and in a terrible hurry.",
                points: 25, reaction: 0.16, nerve: 5, radius: BugCatalog.scaled(16), firstPhase: .noon),
        BugInfo(species: .ant, name: "Ant", joke: "Walks in single file. Will not be taking questions.",
                points: 8, reaction: 0.60, nerve: 15, radius: BugCatalog.scaled(10), firstPhase: .noon),
        BugInfo(species: .ladybird, name: "Ladybird", joke: "Lucky for you. Less so for her.",
                points: 15, reaction: 0.30, nerve: 10, radius: BugCatalog.scaled(14), firstPhase: .noon),
        BugInfo(species: .grasshopper, name: "Grasshopper", joke: "Treats the midrib like a long jump pit.",
                points: 20, reaction: 0.22, nerve: 7, radius: BugCatalog.scaled(18), firstPhase: .noon),
        BugInfo(species: .moth, name: "Moth", joke: "Mistook your trap for a very romantic lamp.",
                points: 20, reaction: 0.30, nerve: 9, radius: BugCatalog.scaled(18), firstPhase: .dusk),
        BugInfo(species: .mosquito, name: "Mosquito", joke: "Nobody will miss this one. Nobody.",
                points: 12, reaction: 0.14, nerve: 4, radius: BugCatalog.scaled(9), firstPhase: .dusk),
        BugInfo(species: .dragonfly, name: "Dragonfly", joke: "Four wings, zero patience, one sharp snap.",
                points: 50, reaction: 0.12, nerve: 4, radius: BugCatalog.scaled(24), firstPhase: .dusk),
        BugInfo(species: .firefly, name: "Firefly", joke: "Brought its own night light. Brave.",
                points: 35, reaction: 0.26, nerve: 8, radius: BugCatalog.scaled(13), firstPhase: .night),
        BugInfo(species: .cricket, name: "Cricket", joke: "Chirps loudest right before dinner.",
                points: 25, reaction: 0.34, nerve: 11, radius: BugCatalog.scaled(17), firstPhase: .night),
        BugInfo(species: .goldenScarab, name: "Golden Scarab", joke: "Rare, regal, and surprisingly crunchy.",
                points: 150, reaction: 0.40, nerve: 12, radius: BugCatalog.scaled(20), firstPhase: .noon),
        BugInfo(species: .bee, name: "Bee", joke: "Busy. Important. Absolutely not on the menu.",
                points: 0, reaction: 1.0, nerve: 8, radius: BugCatalog.scaled(16), firstPhase: .morning),
        BugInfo(species: .bumblebee, name: "Bumblebee", joke: "A fuzzy tank with a flight plan. Spare it.",
                points: 0, reaction: 1.0, nerve: 10, radius: BugCatalog.scaled(22), firstPhase: .noon),
        BugInfo(species: .wasp, name: "Wasp", joke: "Bites back. Literally. Leave it be.",
                points: 0, reaction: 1.0, nerve: 6, radius: BugCatalog.scaled(16), firstPhase: .dusk),
    ]

    static func info(_ s: BugSpecies) -> BugInfo {
        switch s {
        case .housefly: return all[0]
        case .gnat: return all[1]
        case .fruitFly: return all[2]
        case .bluebottle: return all[3]
        case .ant: return all[4]
        case .ladybird: return all[5]
        case .grasshopper: return all[6]
        case .moth: return all[7]
        case .mosquito: return all[8]
        case .dragonfly: return all[9]
        case .firefly: return all[10]
        case .cricket: return all[11]
        case .goldenScarab: return all[12]
        case .bee: return all[13]
        case .bumblebee: return all[14]
        case .wasp: return all[15]
        }
    }

    /// How a species moves (ROUND-1 "Movement"). Speeds in pt/s.
    static func motion(_ s: BugSpecies) -> BugMotion {
        switch s {
        case .housefly: return BugMotion(.fly, 230, 60, 18, 2.2, 0.7, 1.0, 0.4, 1.2)
        case .gnat: return BugMotion(.swarm, 170, 40, 10, 4.0, 0.0, 1.0, 0.3, 0.9)
        case .fruitFly: return BugMotion(.fly, 190, 45, 12, 3.0, 0.9, 1.25, 0.5, 1.4)
        case .bluebottle: return BugMotion(.fly, 300, 80, 16, 2.6, 0.7, 0.7, 0.3, 0.8)
        case .ant: return BugMotion(.walker, 42, 42, 3, 1.5, 0.5, 1.0, 0.3, 0.8)
        case .ladybird: return BugMotion(.fly, 170, 35, 10, 1.6, 0.5, 1.0, 0.6, 1.5)
        case .grasshopper: return BugMotion(.hopper, 220, 0, 8, 1.0, 0.0, 1.0, 1.0, 2.2)
        case .moth: return BugMotion(.flutter, 160, 30, 34, 1.4, 0.0, 1.0, 0.6, 1.5)
        case .mosquito: return BugMotion(.fly, 260, 70, 22, 5.0, 0.4, 0.9, 0.3, 0.9)
        case .dragonfly: return BugMotion(.darter, 320, 0, 10, 0.8, 0.0, 1.0, 0.6, 1.4)
        case .firefly: return BugMotion(.flutter, 160, 30, 20, 0.9, 0.3, 1.0, 0.6, 1.5)
        case .cricket: return BugMotion(.hopper, 200, 0, 6, 1.0, 0.0, 1.0, 1.0, 2.2)
        case .goldenScarab: return BugMotion(.fly, 170, 30, 8, 1.2, 0.5, 1.1, 0.6, 1.5)
        case .bee: return BugMotion(.fly, 200, 40, 14, 1.8, 0.85, 1.0, 0.5, 1.3)
        case .bumblebee: return BugMotion(.fly, 160, 30, 12, 1.2, 0.85, 1.3, 0.6, 1.5)
        case .wasp: return BugMotion(.fly, 250, 70, 20, 3.4, 0.5, 0.9, 0.2, 0.6)
        }
    }
}

/// How a species gets around.
enum BugStyle: Equatable {
    /// Flies in on a wobbly arc, hovers, lands; walks in short dashes and pauses; seeks nectar.
    case fly
    /// Gnats: like a fly, but a loose cloud that never claims nectar first.
    case swarm
    /// Ants: walk in from the bottom edge in single file and never fly.
    case walker
    /// Grasshoppers, crickets: hop 0.5–1.2 s arcs between spots (across the fold too).
    case hopper
    /// Dragonflies: hover (flying) or perch, and dart.
    case darter
    /// Moths, fireflies: a big slow flutter.
    case flutter
}

struct BugMotion: Equatable {
    var style: BugStyle
    /// Flight speed (pt/s).
    var speed: Double
    /// Walking speed on the lobe (pt/s).
    var walkSpeed: Double
    /// Wobble across the flight path (pt) and its frequency (Hz).
    var wobbleAmp: Double
    var wobbleHz: Double
    /// Chance the wave sends it to a nectar drop (0 = never seeks nectar).
    var nectarChance: Double
    var lingerFactor: Double
    /// Pause between walking dashes / hops (s).
    var pauseMin: Double
    var pauseMax: Double

    init(_ style: BugStyle, _ speed: Double, _ walkSpeed: Double, _ wobbleAmp: Double, _ wobbleHz: Double,
         _ nectarChance: Double, _ lingerFactor: Double, _ pauseMin: Double, _ pauseMax: Double) {
        self.style = style
        self.speed = speed
        self.walkSpeed = walkSpeed
        self.wobbleAmp = wobbleAmp
        self.wobbleHz = wobbleHz
        self.nectarChance = nectarChance
        self.lingerFactor = lingerFactor
        self.pauseMin = pauseMin
        self.pauseMax = pauseMax
    }
}

// MARK: - Shared rules (the session and the pilot both use these)

enum TrapRules {

    /// Reactions × this after Tuning.lateWaveStart (GAME-DESIGN §6).
    static func lateFactor(wave: Int) -> Double {
        if wave <= Tuning.lateWaveStart { return 1 }
        return max(Tuning.lateReactionFloor, pow(Tuning.lateReactionDecay, Double(wave - Tuning.lateWaveStart)))
    }

    /// GAME-DESIGN §4: species.reaction × (sipping 1.35) × (flying 0.55) × (on the rim 0.6), × the late factor.
    static func reaction(_ info: BugInfo, sipping: Bool, flying: Bool, onRim: Bool, wave: Int) -> Double {
        var r: Double = info.reaction
        if !info.species.isProtected { r *= lateFactor(wave: wave) }
        if sipping { r *= Tuning.sipReactionFactor }
        if flying { r *= Tuning.flyingReactionFactor }
        if onRim { r *= Tuning.rimReactionFactor }
        return r
    }

    /// R2: on the rim when the bug's outer edge (its centre pushed out from the trap centre by its radius) reaches
    /// the rim band, and its centre is in the trap. A bug at the very centre is never on the rim.
    static func onRim(_ g: TrapGeometry, _ p: CGPoint, radius: CGFloat) -> Bool {
        if g.normalizedRadius(p) > 1 { return false }
        let dx: Double = Double(p.x - g.center.x)
        let dy: Double = Double(p.y - g.center.y)
        let len: Double = hypot(dx, dy)
        if len < 1e-6 { return false }
        let r: Double = Double(radius)
        let q = CGPoint(x: Double(p.x) + dx / len * r, y: Double(p.y) + dy / len * r)
        return g.normalizedRadius(q) >= TrapGeometry.rimStart
    }

    /// The multiplier a productive clean snap gets after `chain` of them in a row.
    static func chainMultiplier(_ chain: Int) -> Double {
        return min(Tuning.chainMaxMultiplier, 1 + Tuning.chainStep * Double(max(0, chain)))
    }

    /// The chain length whose NEXT clean bite is scored at `multiplier` (×4 → 6, ×5 → 8), capped at the max.
    static func chainSteps(toReach multiplier: Double) -> Int {
        let m: Double = min(max(multiplier, 1), Tuning.chainMaxMultiplier)
        return Int(((m - 1) / Tuning.chainStep - 1e-9).rounded(.up))
    }

    /// R3 (REVIEW-2 #5): how far (pt) a resting bug's centre must sit from the midrib line: the crease band's half
    /// width, the bug's radius and Tuning.creaseClearance (housefly 61.2, bumblebee 75.6).
    static func creaseGap(radius: CGFloat) -> Double {
        return Double(ScreenLayout.creaseHalfWidth) + Double(radius) + Tuning.creaseClearance
    }

    /// R3: (x, y) moved straight out sideways to `creaseGap(radius:)` if it is closer to the midrib line (a point on
    /// the line goes right); if that leaves the normalised radius `maxR`, y is pulled toward the centre line.
    static func offCrease(_ g: TrapGeometry, _ x: Double, _ y: Double, maxR: Double,
                          radius: CGFloat) -> (Double, Double) {
        let gap: Double = creaseGap(radius: radius)
        let cx: Double = Double(g.center.x)
        let cy: Double = Double(g.center.y)
        let dx: Double = x - cx
        if abs(dx) >= gap { return (x, y) }
        let nx: Double = cx + (dx >= 0 ? gap : -gap)
        let ux: Double = gap / Double(g.a)
        let lim: Double = maxR * maxR - ux * ux
        var ny: Double = y
        if lim <= 0 {
            ny = cy
        } else {
            let ymax: Double = Double(g.b) * lim.squareRoot()
            ny = min(max(y, cy - ymax), cy + ymax)
        }
        return (nx, ny)
    }

    /// Is this activity in the bite (GAME-DESIGN §4: arriving low, walking, sipping, hopping)?
    static func isCandidate(_ activity: BugActivity, height: Double) -> Bool {
        switch activity {
        case .arriving: return height < Tuning.catchableHeight
        case .walking, .sipping, .hopping: return true
        case .leaving, .caught, .escaped, .released: return false
        }
    }

    /// Flying for the reaction formula (arriving or hopping).
    static func isFlying(_ activity: BugActivity) -> Bool {
        switch activity {
        case .arriving, .hopping: return true
        case .walking, .sipping, .leaving, .caught, .escaped, .released: return false
        }
    }
}
