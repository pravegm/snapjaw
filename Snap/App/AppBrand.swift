import Foundation

/// The product name players see. It comes from the name check (`CFBundleDisplayName`, set by project.yml), so Swift
/// never hard-codes it: everything reads `AppBrand.name`. The fallback below is the one literal allowed in Swift.
enum AppBrand {
    static let name: String = {
        let info = Bundle.main.infoDictionary
        if let display = info?["CFBundleDisplayName"] as? String, !display.isEmpty { return display }
        if let bundle = info?["CFBundleName"] as? String, !bundle.isEmpty, bundle != "Snap" { return bundle }
        return "Snapjaw"
    }()

    /// The store line (GAME-DESIGN §1).
    static let tagline = "Feed the flytrap. Spare bees."
}
