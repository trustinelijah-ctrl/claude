import Foundation
import TelemetryDeck

/// A handful of anonymous signals (TelemetryDeck: no personal data, IDs hashed on device),
/// so it is possible to see where people open the Pro page and whether they buy.
/// Nothing is sent until an App ID is set, and never from test runs.
enum Analytics {
    /// The TelemetryDeck App ID (Dashboard ▸ Set Up App). Empty: analytics stay off.
    static let appID = ""

    private static var started = false

    static func start() {
        guard !appID.isEmpty, !ProcessInfo.processInfo.arguments.contains("-onboarded") else { return }
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        started = true
    }

    static func signal(_ name: String, _ parameters: [String: String] = [:]) {
        guard started else { return }
        TelemetryDeck.signal(name, parameters: parameters)
    }
}
