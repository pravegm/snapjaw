import Foundation
import QuartzCore
import SwiftUI

/// Reads the iPhone Duo hinge (iOS 27.1+) and reports `(angleDegrees, time)`: 180 = flat, time = `CACurrentMediaTime()`
/// on receipt (samples carry no timestamp of their own). On devices without a hinge (or below iOS 27.1) it calls
/// `onUnavailable` instead. R8: it also passes the hinge status through (`onSample`, `TrapHingeStatus`); Core trusts
/// `.closed` only at a low angle (it reads `.closed` at ~85° on hardware). The old two-argument `onUpdate` still works.
/// Copied from Hush/Swoop (`Input/HingeReader.swift`, itself from Brim), battle-tested on a real Duo.
///
/// Lifecycle trap (Squish, real Duo): back from the background with the phone open and still, iOS may send no hinge
/// change at all. On every scene activation the subscription is switched off and on again, which delivers the current
/// state. After a hinge has been seen, a transient nil (display handover) must not demote the app to touch; that
/// policy belongs to the caller (`HingeTrapSource.hasHinge` never goes back to false).
///
/// Usage: `view.modifier(HingeReader(onSample: { angle, time, status in … }, onUnavailable: { … }))`
struct HingeReader: ViewModifier {
    let onSample: (Double, TimeInterval, TrapHingeStatus) -> Void
    let onUnavailable: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var enabled = true
    @State private var refresh = 0

    /// R8: each sample with the hinge status.
    init(onSample: @escaping (Double, TimeInterval, TrapHingeStatus) -> Void,
         onUnavailable: @escaping () -> Void = {}) {
        self.onSample = onSample
        self.onUnavailable = onUnavailable
    }

    /// The R1–R7 form (no status: `.unknown`).
    init(onUpdate: @escaping (Double, TimeInterval) -> Void, onUnavailable: @escaping () -> Void = {}) {
        self.onSample = { angle, time, _ in onUpdate(angle, time) }
        self.onUnavailable = onUnavailable
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content
                .onHingeChange(isEnabled: enabled) { _, newContext in
                    if let hinge = newContext.hinge {
                        let time = CACurrentMediaTime()
                        let degrees = hinge.angle.degrees
                        // `DeviceHinge.Status` is a struct with .closed / .partiallyOpen / .fullyOpen
                        // (Squish design/research/APPLE-DUO-GUIDE.md); anything else is .unknown.
                        let raw = hinge.status
                        let status: TrapHingeStatus = raw == .closed ? .closed
                            : (raw == .partiallyOpen ? .partiallyOpen : (raw == .fullyOpen ? .fullyOpen : .unknown))
                        FeelHingeLog.record(angle: degrees, at: time)
                        onSample(degrees, time, status)
                    } else {
                        onUnavailable()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    refresh &+= 1
                    let ticket = refresh
                    enabled = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(30))
                        guard ticket == refresh else { return }
                        enabled = true
                    }
                }
        } else {
            content.onAppear(perform: onUnavailable)
        }
    }
}

/// `SNAP-H <t> <angle>` stdout lines for CI (`ci/duo.sh` greps them), only in DEBUG with the `-snapDemo` launch
/// argument, at most 10 per second. Don't rename the prefix. Called on the main thread only (hinge callbacks).
enum FeelHingeLog {
    static let isEnabled: Bool = FeelDemoLog.isEnabled
    nonisolated(unsafe) private static var lastLine: TimeInterval = -.infinity

    static func record(angle: Double, at time: TimeInterval) {
        guard isEnabled, time - lastLine >= 0.1 else { return }
        lastLine = time
        print(String(format: "SNAP-H %.3f %.1f", time, angle))
        fflush(stdout)
    }
}
