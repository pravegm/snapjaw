import Foundation

// MARK: - Deterministic RNG (SplitMix64)
//
// The same seed gives the same sequence on every device and every run. Everything random in Core (the waves, the
// nectar, every bug's wobble and wander, the pilot) draws from one of these, never from the system RNG.
// tools/balance-sim.js has the same generator (BigInt), so the sim deals the same waves.

struct SeededRandom {
    private(set) var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double {
        return Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    /// Uniform in [lower, upper) (always draws, even for an empty range).
    mutating func range(_ r: ClosedRange<Double>) -> Double {
        return r.lowerBound + (r.upperBound - r.lowerBound) * unit()
    }

    /// Uniform in [a, b) without building a ClosedRange (so a > b can never trap). Same draw as `range(a...b)`.
    mutating func between(_ a: Double, _ b: Double) -> Double {
        return a + (b - a) * unit()
    }

    /// Uniform integer in the closed range. A single-value range returns it without drawing.
    mutating func int(_ r: ClosedRange<Int>) -> Int {
        if r.upperBound <= r.lowerBound { return r.lowerBound }
        let span: UInt64 = UInt64(r.upperBound - r.lowerBound) + 1
        return r.lowerBound + Int(next() % span)
    }

    /// True with probability p (always draws).
    mutating func chance(_ p: Double) -> Bool {
        return unit() < p
    }
}
