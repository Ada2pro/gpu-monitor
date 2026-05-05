// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GPUMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GPUMonitor",
            targets: ["GPUMonitor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "GPUMonitor",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"])
            ]
        ),
        .testTarget(
            name: "GPUMonitorTests",
            dependencies: ["GPUMonitor"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
