import Foundation

extension Bundle {
    /// The app's version ("0.1.0").
    var version: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
