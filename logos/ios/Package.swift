// swift-tools-version:5.9
// The app's model layer as a package, so it builds and is tested with
// `swift test` on any machine (including Linux CI). The Xcode app compiles
// these same files directly.
import PackageDescription

let package = Package(
    name: "LogosCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "LogosCore", targets: ["LogosCore"])],
    dependencies: [
        // Linux only: API-identical stand-in for CryptoKit, used by sync.
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"4.0.0"),
    ],
    targets: [
        .target(name: "LogosCore",
                dependencies: [.product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux]))],
                path: "Logos/Core"),
        .testTarget(name: "LogosCoreTests", dependencies: ["LogosCore"], path: "Tests/LogosCoreTests"),
    ]
)
