import Foundation
import Observation
import AuthenticationServices

/// Who is at the table: a guest, or someone signed in with Apple. Either way everything is
/// kept on this iPad; signing in only attaches a name and an Apple ID to the record.
@MainActor
@Observable
final class AccountStore {
    enum Kind: String { case none, guest, apple }

    private let defaults: UserDefaults

    private(set) var kind: Kind
    private(set) var name: String?
    /// Whether the welcome has been seen through to the end.
    var hasOnboarded: Bool { kind != .none }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.bool(forKey: "onboarded") {
            kind = Kind(rawValue: defaults.string(forKey: "account.kind") ?? "") ?? .guest
        } else {
            kind = .none
        }
        name = defaults.string(forKey: "account.name")
    }

    func continueAsGuest() {
        kind = .guest
        save()
    }

    func signedIn(_ credential: ASAuthorizationAppleIDCredential) {
        kind = .apple
        defaults.set(credential.user, forKey: "account.appleUser")
        // Apple only sends the name the first time; keep what we were given.
        if let given = credential.fullName?.givenName, !given.isEmpty { name = given }
        save()
    }

    func signOut() {
        kind = .guest
        name = nil
        defaults.removeObject(forKey: "account.appleUser")
        save()
    }

    /// Shows the welcome again from the start.
    func replayWelcome() {
        kind = .none
        defaults.set(false, forKey: "onboarded")
    }

    /// The Apple ID may have been disconnected from TABLE in Settings since last launch.
    func checkAppleCredential() async {
        guard kind == .apple, let user = defaults.string(forKey: "account.appleUser") else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: user)
        if state == .revoked || state == .notFound { signOut() }
    }

    private func save() {
        defaults.set(true, forKey: "onboarded")
        defaults.set(kind.rawValue, forKey: "account.kind")
        defaults.set(name, forKey: "account.name")
    }
}
