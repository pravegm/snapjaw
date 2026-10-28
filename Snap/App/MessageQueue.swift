import Foundation

/// R6 (#6, SCORE-R5 D2 #1): what the HUD says at the snaps row ("+1 snap", "−2 snaps").
enum HUDTag: Equatable {
    case gain(String)
    case loss(String)
}

/// R6 (#6): the one App message on screen: a plate (a hint or a toast) or a tag at the row.
enum HUDMessage: Equatable {
    case plate(HUDHint)
    case tag(HUDTag)
}

/// R6 (#6): one message at a time. Every App toast (the free sting, the chain explainer, a goal done) and every tag
/// at the snaps row goes through this one queue; Core's hints (states, not moments) show only while the queue is
/// empty. A moment that belongs to its bite (`interrupt`: a tag, the free sting) takes the screen at once and puts a
/// waiting toast back at the front; a toast waits its turn, and its clock stands still while a warning shows (so
/// "Bee! Wait…" is never hidden, and a goal toast is never missed). Session time. Pure; tested.
///
/// R7 (SCORE-R6 #5: three pops at once in 19, 42, 46): messages are at least `gap` s apart. When one ends, nothing
/// (not the next toast, not Core's state hint) shows for `gap` s; only a warning, or a moment that interrupts, may
/// cut the quiet short. And a plate that has nowhere to go without covering its bugs (`hold`) keeps its clock still,
/// for at most `maxHold` s, so a toast waits for a clear spot instead of landing on the flies.
struct MessageQueue: Equatable {
    struct Item: Equatable {
        var message: HUDMessage
        var seconds: Double
        var interrupt: Bool
    }

    /// R7 (#5): the quiet between two messages (session s).
    static let gap: Double = 0.4
    /// R7 (#5): the longest a plate's clock stands still while it has no clear spot (session s).
    static let maxHold: Double = 2.0

    private(set) var current: Item?
    private(set) var until: Double = -1
    private(set) var pending: [Item] = []
    /// R7: nothing but a warning or an interrupt shows before this (the gap after the last message).
    private(set) var quietUntil: Double = -1
    /// R7: how long the current message's clock has stood still for want of a clear spot.
    private(set) var heldFor: Double = 0
    private var lastNow: Double?

    init() {}

    /// Nothing waiting or showing.
    var isIdle: Bool { current == nil && pending.isEmpty }

    /// R7: the current plate has waited as long as it may for a clear spot (it may now show where it must).
    var holdSpent: Bool { current != nil && heldFor >= Self.maxHold - 1e-9 }

    /// Queues `message` for `seconds`. The same message already showing or waiting is not queued twice.
    mutating func post(_ message: HUDMessage, seconds: Double, now: Double, interrupt: Bool = false) {
        let s = seconds.isFinite ? max(seconds, 0.1) : 1
        let item = Item(message: message, seconds: s, interrupt: interrupt)
        if current?.message == message {
            until = max(until, now + s)
            return
        }
        if pending.contains(where: { $0.message == message }) { return }
        guard let shown = current else {
            if interrupt || now >= quietUntil {
                start(item, now: now)
            } else {
                // R7: in the quiet after a message, it waits for the gap.
                pending.append(item)
            }
            return
        }
        if interrupt {
            // A tag replaces a tag; a toast goes back to the front of the line to show in full afterwards.
            if !shown.interrupt { pending.insert(shown, at: 0) }
            start(item, now: now)
        } else {
            pending.append(item)
        }
    }

    /// The message to show at `now`. `hint`: Core's (or the App's state) hint, shown when the queue is empty and the
    /// gap is over; `warning`: that hint is a warning, so it shows at once and a waiting toast's clock stands still
    /// under it; `hold`: the current plate has no clear spot this frame (its clock stands still, up to `maxHold`).
    mutating func shown(now: Double, hint: HUDHint?, warning: Bool = false, hold: Bool = false) -> HUDMessage? {
        let dt = max(now - (lastNow ?? now), 0)
        lastNow = now
        if let c = current, !c.interrupt, let h = hint, warning {
            // The warning shows; the toast keeps its time.
            until += dt
            return .plate(h)
        }
        if hold, let c = current, case .plate = c.message, heldFor < Self.maxHold {
            let step = min(dt, Self.maxHold - heldFor)
            heldFor += step
            until += step
        }
        if current != nil && now >= until {
            current = nil
            quietUntil = until + Self.gap
        }
        if current == nil && !pending.isEmpty && now >= quietUntil {
            start(pending.removeFirst(), now: now)
        }
        if let c = current { return c.message }
        if now < quietUntil && !warning { return nil }
        return hint.map { HUDMessage.plate($0) }
    }

    /// Drops everything (a new run, Home).
    mutating func clear() {
        current = nil
        until = -1
        pending = []
        quietUntil = -1
        heldFor = 0
        lastNow = nil
    }

    private mutating func start(_ item: Item, now: Double) {
        current = item
        until = now + item.seconds
        heldFor = 0
    }
}
