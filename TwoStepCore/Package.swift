// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwoStepCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "TwoStepCore", targets: ["TwoStepCore"])
    ],
    targets: [
        .target(name: "TwoStepCore"),
        .testTarget(name: "TwoStepCoreTests", dependencies: ["TwoStepCore"])
    ]
)
