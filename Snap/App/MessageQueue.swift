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
struct MessageQueue: Equatable {
    struct Item: Equatable {
        var message: HUDMessage
        var seconds: Double
        var interrupt: Bool
    }

    private(set) var current: Item?
    private(set) var until: Double = -1
    private(set) var pending: [Item] = []
    private var lastNow: Double?

    init() {}

    /// Nothing waiting or showing.
    var isIdle: Bool { current == nil && pending.isEmpty }

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
            current = item
            until = now + s
            return
        }
        if interrupt {
            // A tag replaces a tag; a toast goes back to the front of the line to show in full afterwards.
            if !shown.interrupt { pending.insert(shown, at: 0) }
            current = item
            until = now + s
        } else {
            pending.append(item)
        }
    }

    /// The message to show at `now`. `hint`: Core's (or the App's state) hint, shown when the queue is empty;
    /// `warning`: that hint is a warning, so a waiting toast's clock stands still under it.
    mutating func shown(now: Double, hint: HUDHint?, warning: Bool = false) -> HUDMessage? {
        let dt = max(now - (lastNow ?? now), 0)
        lastNow = now
        if let c = current, !c.interrupt, let h = hint, warning {
            // The warning shows; the toast keeps its time.
            until += dt
            return .plate(h)
        }
        while current != nil && now >= until {
            if pending.isEmpty {
                current = nil
            } else {
                let next = pending.removeFirst()
                current = next
                until = now + next.seconds
            }
        }
        if let c = current { return c.message }
        return hint.map { HUDMessage.plate($0) }
    }

    /// Drops everything (a new run, Home).
    mutating func clear() {
        current = nil
        until = -1
        pending = []
        lastNow = nil
    }
}
