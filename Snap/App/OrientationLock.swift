import SwiftUI
import UIKit

/// A landscape side of the interface.
enum InterfaceSide: String, Equatable {
    case landscapeLeft, landscapeRight
}

/// Orientation policy (ported from Swoop: play is LANDSCAPE, the book pose).
///
/// Info.plist lists every orientation but upside down, so iOS never runs the app as a letterboxed column on the Duo's
/// portrait (tabletop) inner display. The app itself decides what it supports:
/// - an iPhone Duo (a hinge reported on this device, or the screen already looks foldable: both Duo displays are ~0.7
///   short-to-long, other iPhones ~0.46): portrait and both landscapes, so the inner display follows the way the phone
///   is held. Landscape (book pose) plays; portrait shows the "Hold it open like a book" card (PoseCards);
/// - every other iPhone: landscape only, so the UI turns sideways by itself.
/// Never upside down (full-screen apps are refused it).
@MainActor
enum OrientationLock {
    static let hingeKey = "snap.hasHinge"

    /// A hinge reported in this run, before `snap.hasHinge` was ever saved.
    private(set) static var hingeSeen = false

    static func mask(screen: CGSize) -> UIInterfaceOrientationMask {
        let stored = trustsStoredHinge(UserDefaults.standard.bool(forKey: hingeKey), screen: screen)
        return mask(hasHinge: stored || hingeSeen, screen: screen)
    }

    /// Pure rule (tested): portrait and landscapes on a Duo, landscape only elsewhere.
    nonisolated static func mask(hasHinge: Bool, screen: CGSize) -> UIInterfaceOrientationMask {
        allowsPortrait(hasHinge: hasHinge, screen: screen) ? .allButUpsideDown : .landscape
    }

    /// Pure rule (tested): portrait only on a device with a hinge, or one whose screen looks like a Duo's.
    nonisolated static func allowsPortrait(hasHinge: Bool, screen: CGSize) -> Bool {
        if hasHinge { return true }
        guard screen.width > 0, screen.height > 0 else { return false }
        return min(screen.width, screen.height) / max(screen.width, screen.height) > 0.6
    }

    /// `snap.hasHinge` travels in backups, so a saved "this device has a hinge" is only believed on a screen shaped
    /// like a Duo's. Pure; tested.
    nonisolated static func trustsStoredHinge(_ stored: Bool, screen: CGSize) -> Bool {
        stored && allowsPortrait(hasHinge: false, screen: screen)
    }

    /// A hinge just reported: let the windows rotate freely from now on.
    static func hingeArrived() {
        guard !hingeSeen else { return }
        hingeSeen = true
        refreshSupportedOrientations()
    }

    static func refreshSupportedOrientations() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    /// Asks the window scene for landscape (a phone held upright at launch).
    static func requestLandscape() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                AppTrace.t("SNAP-T orient request error: \(error.localizedDescription)")
            }
        }
    }

    /// The key window's real safe-area insets (Dynamic Island, rounded corners, the Duo's inner camera cut-out).
    static func windowSafeArea() -> EdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else {
            return EdgeInsets()
        }
        let i = window.safeAreaInsets
        return EdgeInsets(top: i.top, leading: i.left, bottom: i.bottom, trailing: i.right)
    }

    /// The window scene's landscape orientation (nil in portrait or before a scene connects).
    static func interfaceSide() -> InterfaceSide? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let o = scenes.first?.interfaceOrientation else { return nil }
        switch o {
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }

    /// The main screen's size in points (zero before the first scene connects).
    static func screenSize() -> CGSize {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let scene = scenes.first { return scene.screen.bounds.size }
        return .zero
    }
}

/// Supplies the orientation policy (`OrientationLock`) to UIKit.
@MainActor
final class SnapAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask(screen: window?.windowScene?.screen.bounds.size ?? OrientationLock.screenSize())
    }
}
