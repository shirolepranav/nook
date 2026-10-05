// swift-tools-version: 6.2
import PackageDescription

// Design tokens and components. Depends on nothing (04 §1).
let package = Package(
    name: "NookUI",
    platforms: [.iOS("27.0")],
    products: [.library(name: "NookUI", targets: ["NookUI"])],
    targets: [
        .target(name: "NookUI", resources: [.process("Resources")]),
        .testTarget(name: "NookUITests", dependencies: ["NookUI"]),
    ]
)
