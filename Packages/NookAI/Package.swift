// swift-tools-version: 6.2
import PackageDescription

// CapabilityRouter and both engines. The only package allowed to import
// FoundationModels or Vision (CLAUDE.md hard rules). Depends on NookKit (04 §1).
let package = Package(
    name: "NookAI",
    platforms: [.iOS("27.0")],
    products: [.library(name: "NookAI", targets: ["NookAI"])],
    dependencies: [.package(path: "../NookKit")],
    targets: [
        .target(name: "NookAI", dependencies: ["NookKit"]),
        .testTarget(name: "NookAITests", dependencies: ["NookAI"]),
    ]
)
