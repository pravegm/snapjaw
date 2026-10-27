import Foundation

/// The `SNAP-T …` lines CI greps (design/ROUND-1.md "Log lines"). They print only in DEBUG builds launched with
/// `-snapDemo` (or with `SNAP_ICON=1` in the environment, the icon render). One `print` + `fflush` per line. In Release
/// `enabled` is false and `t(_:)` does nothing, so it can be called from anywhere without `#if` guards.
enum AppTrace {
    static let enabled: Bool = {
        #if DEBUG
        let info = ProcessInfo.processInfo
        return info.arguments.contains("-snapDemo") || info.environment["SNAP_ICON"] == "1"
        #else
        return false
        #endif
    }()

    /// Prints one trace line (DEBUG + demo only), flushed so CI sees lines in order.
    static func t(_ line: @autoclosure () -> String) {
        #if DEBUG
        guard enabled else { return }
        print(line())
        fflush(stdout)
        #endif
    }

    /// A finite Double with `places` decimals (0 for NaN / infinity), for log lines.
    static func fixed(_ value: Double, _ places: Int) -> String {
        guard value.isFinite else { return String(format: "%.\(places)f", 0.0) }
        return String(format: "%.\(places)f", value)
    }

    static func phaseName(_ p: DayPhase) -> String {
        switch p {
        case .morning: return "morning"
        case .noon: return "noon"
        case .dusk: return "dusk"
        case .night: return "night"
        }
    }

    /// `SNAP-T trap closure <deg 1dp> armed <0|1> creep <0|1> angle <θ 1dp|-> ref <θ 1dp|->`. Pure; tested.
    static func trapLine(_ input: TrapInput, reference: Double?) -> String {
        let a = input.angle.map { fixed($0, 1) } ?? "-"
        let r = reference.map { fixed($0, 1) } ?? "-"
        return "SNAP-T trap closure \(fixed(input.closure, 1)) armed \(input.armed ? 1 : 0) "
            + "creep \(input.creeping ? 1 : 0) angle \(a) ref \(r)"
    }

    /// The rest reference from one input: closure = ref − θ, so ref = θ + closure (nil without a hinge angle).
    static func reference(_ input: TrapInput) -> Double? {
        guard let a = input.angle, a.isFinite, input.closure.isFinite else { return nil }
        return a + input.closure
    }

    /// The part after `SNAP-T event ` for a TrapEvent: the enum case name, then details. Pure; tested.
    static func describe(_ event: TrapEvent) -> String {
        switch event {
        case let .waveStarted(index, phase):
            return "waveStarted index=\(index) phase=\(phaseName(phase))"
        case let .dayPhaseChanged(phase):
            return "dayPhaseChanged phase=\(phaseName(phase))"
        case let .bugArrived(id, species):
            return "bugArrived id=\(id) species=\(species.rawValue)"
        case let .bugLanded(id, species, position, inTrap):
            return "bugLanded id=\(id) species=\(species.rawValue) x=\(Int(position.x.rounded())) "
                + "y=\(Int(position.y.rounded())) inTrap=\(inTrap ? 1 : 0)"
        case let .bugSipping(id, species):
            return "bugSipping id=\(id) species=\(species.rawValue)"
        case let .bugHopped(id, species):
            return "bugHopped id=\(id) species=\(species.rawValue)"
        case let .bugLeft(id, species):
            return "bugLeft id=\(id) species=\(species.rawValue)"
        case let .bugSpooked(id, species):
            return "bugSpooked id=\(id) species=\(species.rawValue)"
        case .snapStarted:
            return "snapStarted"
        case let .snapped(report):
            return "snapped caught=\(report.caught.count) escaped=\(report.escaped) stingers=\(report.stingers.count) "
                + "points=\(report.points) d=\(fixed(report.duration, 3))"
        case let .bugCaught(id, species, _):
            return "bugCaught id=\(id) species=\(species.rawValue)"
        case let .bugEscaped(id, species):
            return "bugEscaped id=\(id) species=\(species.rawValue)"
        case let .stung(id, species, cost):
            return "stung id=\(id) species=\(species.rawValue) cost=\(cost)"
        case .drySnap:
            return "drySnap"
        case let .feast(count, snapsBack):
            return "feast count=\(count) snapsBack=\(snapsBack)"
        case let .luckySnap(species):
            return "luckySnap species=\(species.rawValue)"
        case let .chainUp(count, multiplier):
            return "chainUp count=\(count) multiplier=\(fixed(multiplier, 1))"
        case let .chainBroken(count):
            return "chainBroken count=\(count)"
        case .rearmed:
            return "rearmed"
        case let .beeSpared(species):
            return "beeSpared species=\(species.rawValue)"
        case .lastSnap:
            return "lastSnap"
        case .tired:
            return "tired"
        case .newBest:
            return "newBest"
        case .finished:
            return "finished"
        }
    }
}
