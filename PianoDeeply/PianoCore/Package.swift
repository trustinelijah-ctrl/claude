// swift-tools-version:5.9
// Pure-Swift logic for Piano, Deeply. No UI, no persistence, no Apple-only
// frameworks, so the tests also run on Linux CI.
import PackageDescription

let package = Package(
    name: "PianoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PianoCore", targets: ["PianoCore"]),
    ],
    targets: [
        .target(name: "PianoCore"),
        .testTarget(name: "PianoCoreTests", dependencies: ["PianoCore"]),
    ]
)
