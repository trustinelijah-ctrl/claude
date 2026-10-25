import Foundation

/// The places where 64 would send an anonymous usage signal. Version 1.0 sends nothing and
/// collects no data; a privacy-friendly service (TelemetryDeck) can be wired in here later,
/// together with matching privacy-manifest and App Store privacy declarations.
enum Analytics {
    static func start() {}

    static func signal(_ name: String, _ parameters: [String: String] = [:]) {}
}
