import Foundation

// MARK: - The Daily Bog's seed (GAME-DESIGN §7): the same bog for everyone on a UTC day
//
// Founder R1: the day number is counted on the UTC Gregorian calendar by default, so the Daily Bog changes at
// 00:00 UTC for everyone and matches the recurring `snap.daily` leaderboard (docs/appstore/achievements.md).

enum DailySeed {

    /// A Gregorian calendar fixed to UTC (the default for `dayNumber`).
    static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? c.timeZone
        return c
    }

    /// Days since 2026-01-01 (day 0) in `calendar` (UTC by default). Negative before then.
    static func dayNumber(for date: Date, calendar: Calendar = DailySeed.utcCalendar) -> Int {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 1
        comps.hour = 12
        guard let epoch = calendar.date(from: comps) else { return 0 }
        let a: Date = calendar.startOfDay(for: epoch)
        let b: Date = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// The run seed for a day number (deterministic, well mixed: neighbouring days are unrelated).
    static func seed(day: Int) -> UInt64 {
        var rng = SeededRandom(seed: 0x534E_4150_DA11_0000 ^ UInt64(bitPattern: Int64(day)))
        return rng.next()
    }
}
