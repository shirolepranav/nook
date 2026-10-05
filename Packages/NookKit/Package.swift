// swift-tools-version: 6.2
import PackageDescription

// Models, store and services. Depends on nothing (04 §1).
// macOS is listed only so `swift test` runs without a simulator.
let package = Package(
    name: "NookKit",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [.library(name: "NookKit", targets: ["NookKit"])],
    targets: [
        .target(name: "NookKit"),
        .testTarget(name: "NookKitTests", dependencies: ["NookKit"]),
    ]
)
