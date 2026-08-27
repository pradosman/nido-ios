// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NidoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NidoCore", targets: ["NidoCore"]),
    ],
    targets: [
        .target(name: "NidoCore", path: "Nido/Core"),
        .testTarget(name: "NidoCoreTests", dependencies: ["NidoCore"], path: "Tests/NidoCoreTests"),
    ]
)
