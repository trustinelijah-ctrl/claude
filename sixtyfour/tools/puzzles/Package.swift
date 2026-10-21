// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "gen", platforms: [.macOS(.v14)],
  dependencies: [.package(path: "../../ChessCore")],
  targets: [.executableTarget(name: "gen", dependencies: ["ChessCore"])])
