import Foundation

/// Which channel this build came from (Settings › About shows the version line, and the channel in test builds).
enum BuildChannel {
    enum Kind: String, Equatable {
        case debug, testFlight, appStore

        var label: String {
            switch self {
            case .debug: return "Debug"
            case .testFlight: return "TestFlight"
            case .appStore: return "App Store"
            }
        }
    }

    /// Pure; tested.
    static func kind(isDebug: Bool, receiptName: String?) -> Kind {
        if isDebug { return .debug }
        return receiptName == "sandboxReceipt" ? .testFlight : .appStore
    }

    static var current: Kind {
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        return kind(isDebug: debug, receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent)
    }

    /// "1.0 (12)".
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
