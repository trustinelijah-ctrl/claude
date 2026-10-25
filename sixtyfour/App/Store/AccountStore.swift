import Foundation
import Observation

/// Whether the welcome has been seen. There are no accounts in 64: everything stays on this
/// device, so nobody has to sign up or sign in.
@MainActor
@Observable
final class AccountStore {
    private let defaults: UserDefaults

    /// Whether the welcome has been seen through to the end.
    private(set) var hasOnboarded: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: "onboarded")
    }

    /// Called when the welcome's "Start playing" is tapped.
    func continueAsGuest() {
        hasOnboarded = true
        defaults.set(true, forKey: "onboarded")
    }

    /// Shows the welcome again from the start.
    func replayWelcome() {
        hasOnboarded = false
        defaults.set(false, forKey: "onboarded")
    }
}
