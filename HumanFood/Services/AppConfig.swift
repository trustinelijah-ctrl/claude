import Foundation

/// Values injected at build time from Config/HumanFood.xcconfig (+ optional
/// Config/Secrets.xcconfig, which is git-ignored).
struct AppConfig: Sendable {
    /// e.g. "abcd1234.supabase.co" — the Human Food backend that caches verdicts.
    var backendHost: String?
    var backendAnonKey: String?
    /// DEBUG-only direct Gemini access for local development. Never ship a key in the app.
    var geminiDevKey: String?
    var geminiModel: String

    static let current: AppConfig = {
        func value(_ key: String) -> String? {
            guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
        }
        #if DEBUG
        let devKey = value("HFGeminiDevKey")
        #else
        let devKey: String? = nil
        #endif
        return AppConfig(backendHost: value("HFBackendHost"),
                         backendAnonKey: value("HFBackendAnonKey"),
                         geminiDevKey: devKey,
                         geminiModel: value("HFGeminiModel") ?? "gemini-3.5-flash-lite")
    }()

    var backendBaseURL: URL? {
        guard let backendHost else { return nil }
        return URL(string: "https://\(backendHost)/functions/v1/human-food")
    }

    var hasAI: Bool { backendBaseURL != nil || geminiDevKey != nil }
}

enum PreferenceKeys {
    static let haptics = "hf.haptics"
    static let onboarded = "hf.onboarded"
    static let lens = "hf.lens"
    static let allergens = "hf.allergens"
    static let streakDays = "hf.streak.days"
    static let streakLastDay = "hf.streak.last"
    static let bestStreak = "hf.streak.best"
}
