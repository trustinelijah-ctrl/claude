import Foundation

/// When to ask for an App Store rating: right after a good moment (a win, a third solved
/// puzzle), never more than once per version of the app.
enum ReviewPrompt {
    private static let key = "review.askedVersion"

    static var mayAsk: Bool {
        // Test runs launch with arguments; a real launch never does.
        guard !ProcessInfo.processInfo.arguments.contains("-onboarded") else { return false }
        return UserDefaults.standard.string(forKey: key) != version
    }

    static func asked() {
        UserDefaults.standard.set(version, forKey: key)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
