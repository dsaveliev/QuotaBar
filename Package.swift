// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuotaBarKit", targets: ["QuotaBarKit"]),
        .executable(name: "quotabar", targets: ["QuotaBar"]),
    ],
    targets: [
        .target(name: "QuotaBarKit"),
        .executableTarget(name: "QuotaBar", dependencies: ["QuotaBarKit"]),
        // Not a `.testTarget`: this toolchain ships neither XCTest nor the
        // swift-testing module, so `swift test` cannot run here. The suite is
        // an ordinary executable that reports and exits non-zero on failure.
        .executableTarget(name: "QuotaBarKitTests", dependencies: ["QuotaBarKit"]),
    ]
)